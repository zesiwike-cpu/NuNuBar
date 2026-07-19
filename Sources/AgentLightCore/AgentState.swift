public enum AgentProvider: String, Codable, CaseIterable, Sendable {
    case codex
    case claudeCode = "claude-code"
    case openCode = "opencode"
    case grokBuild = "grok-build"
    case hermes
    case openClaw = "openclaw"
    case antigravity
}

public enum AgentSessionStatus: Codable, Equatable, Sendable {
    case idle
    case working
    case waiting
    case complete
    case error
}

public struct AgentSessionKey: Codable, Hashable, Sendable {
    public let provider: AgentProvider
    public let sessionID: String

    public init(provider: AgentProvider, sessionID: String) {
        self.provider = provider
        self.sessionID = sessionID
    }
}

public struct AgentEvent: Equatable, Sendable {
    public let provider: AgentProvider
    public let sessionID: String
    public let status: AgentSessionStatus
    public let forceDelivery: Bool

    public init(
        provider: AgentProvider,
        sessionID: String,
        status: AgentSessionStatus,
        forceDelivery: Bool = false
    ) {
        self.provider = provider
        self.sessionID = sessionID
        self.status = status
        self.forceDelivery = forceDelivery
    }
}

public struct AgentSessionRecord: Codable, Equatable, Sendable {
    public var status: AgentSessionStatus
    public var updatedAt: Int64
}

public struct AgentStatePresentation: Equatable, Sendable {
    public let command: AgentLightCommand
    public let nextExpiration: Int64?
}

public struct AgentState: Codable, Equatable, Sendable {
    public static let completionRetention = AgentStateTiming.default.completionSeconds
    public static let activeRetention = AgentStateTiming.default.workingTimeoutSeconds

    public var sessions: [AgentSessionKey: AgentSessionRecord]
    public var deliveryRevision: UInt64?

    public init(
        sessions: [AgentSessionKey: AgentSessionRecord] = [:],
        deliveryRevision: UInt64? = nil
    ) {
        self.sessions = sessions
        self.deliveryRevision = deliveryRevision
    }

    public mutating func apply(
        _ event: AgentEvent,
        now: Int64,
        timing: AgentStateTiming = .default
    ) {
        prune(now: now, timing: timing)
        let key = AgentSessionKey(provider: event.provider, sessionID: event.sessionID)
        if event.status == .idle {
            sessions.removeValue(forKey: key)
        } else {
            sessions[key] = AgentSessionRecord(status: event.status, updatedAt: now)
        }
        if event.forceDelivery {
            deliveryRevision = (deliveryRevision ?? 0) &+ 1
        }
    }

    public mutating func presentation(
        now: Int64,
        timing: AgentStateTiming = .default
    ) -> AgentStatePresentation {
        prune(now: now, timing: timing)
        let records = sessions.values
        let command: AgentLightCommand

        if records.contains(where: { $0.status == .error }) {
            command = .error
        } else if records.contains(where: { $0.status == .waiting }) {
            command = .waiting
        } else if records.contains(where: { $0.status == .working }) {
            command = .working
        } else if records.contains(where: { $0.status == .complete }) {
            command = .complete
        } else {
            command = .idle
        }

        return AgentStatePresentation(
            command: command,
            nextExpiration: records.compactMap { expiration(for: $0, timing: timing) }.min()
        )
    }

    public mutating func displayCommand(
        now: Int64,
        timing: AgentStateTiming = .default
    ) -> AgentLightCommand {
        presentation(now: now, timing: timing).command
    }

    private mutating func prune(now: Int64, timing: AgentStateTiming) {
        sessions = sessions.filter { _, record in
            let age = max(0, now - record.updatedAt)
            guard let retention = timing.retention(for: record.status) else { return false }
            return age <= retention
        }
    }

    private func expiration(
        for record: AgentSessionRecord,
        timing: AgentStateTiming
    ) -> Int64? {
        guard let retention = timing.retention(for: record.status) else { return nil }
        return record.updatedAt + retention + 1
    }
}
