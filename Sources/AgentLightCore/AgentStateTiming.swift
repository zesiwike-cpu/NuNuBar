import Foundation

public struct AgentStateTiming: Codable, Equatable, Sendable {
    public static let completionRange: ClosedRange<Int64> = 1...60
    public static let errorRange: ClosedRange<Int64> = 1...60
    public static let activeRange: ClosedRange<Int64> = 60...(60 * 60)

    public static let `default` = AgentStateTiming(
        completionSeconds: 15,
        errorSeconds: 15,
        workingTimeoutSeconds: 15 * 60,
        waitingTimeoutSeconds: 15 * 60
    )

    public private(set) var completionSeconds: Int64
    public private(set) var errorSeconds: Int64
    public private(set) var workingTimeoutSeconds: Int64
    public private(set) var waitingTimeoutSeconds: Int64

    public init(
        completionSeconds: Int64,
        errorSeconds: Int64,
        workingTimeoutSeconds: Int64,
        waitingTimeoutSeconds: Int64
    ) {
        self.completionSeconds = Self.clamp(completionSeconds, to: Self.completionRange)
        self.errorSeconds = Self.clamp(errorSeconds, to: Self.errorRange)
        self.workingTimeoutSeconds = Self.clamp(workingTimeoutSeconds, to: Self.activeRange)
        self.waitingTimeoutSeconds = Self.clamp(waitingTimeoutSeconds, to: Self.activeRange)
    }

    public mutating func setCompletionSeconds(_ seconds: Int64) {
        completionSeconds = Self.clamp(seconds, to: Self.completionRange)
    }

    public mutating func setErrorSeconds(_ seconds: Int64) {
        errorSeconds = Self.clamp(seconds, to: Self.errorRange)
    }

    public mutating func setWorkingTimeoutSeconds(_ seconds: Int64) {
        workingTimeoutSeconds = Self.clamp(seconds, to: Self.activeRange)
    }

    public mutating func setWaitingTimeoutSeconds(_ seconds: Int64) {
        waitingTimeoutSeconds = Self.clamp(seconds, to: Self.activeRange)
    }

    public func retention(for status: AgentSessionStatus) -> Int64? {
        switch status {
        case .idle: nil
        case .complete: completionSeconds
        case .error: errorSeconds
        case .working: workingTimeoutSeconds
        case .waiting: waitingTimeoutSeconds
        }
    }

    private enum CodingKeys: String, CodingKey {
        case completionSeconds
        case errorSeconds
        case workingTimeoutSeconds
        case waitingTimeoutSeconds
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.default
        self.init(
            completionSeconds: try values.decodeIfPresent(Int64.self, forKey: .completionSeconds)
                ?? defaults.completionSeconds,
            errorSeconds: try values.decodeIfPresent(Int64.self, forKey: .errorSeconds)
                ?? defaults.errorSeconds,
            workingTimeoutSeconds: try values.decodeIfPresent(Int64.self, forKey: .workingTimeoutSeconds)
                ?? defaults.workingTimeoutSeconds,
            waitingTimeoutSeconds: try values.decodeIfPresent(Int64.self, forKey: .waitingTimeoutSeconds)
                ?? defaults.waitingTimeoutSeconds
        )
    }

    private static func clamp(_ value: Int64, to range: ClosedRange<Int64>) -> Int64 {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

public struct AgentStateTimingStore: Sendable {
    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "AgentLight", directoryHint: .isDirectory)
            .appending(path: "timing.json")
    }

    public let url: URL

    public init(url: URL = Self.defaultURL) {
        self.url = url
    }

    public func load() -> AgentStateTiming {
        guard let data = try? Data(contentsOf: url),
              let timing = try? JSONDecoder().decode(AgentStateTiming.self, from: data) else {
            return .default
        }
        return timing
    }

    public func save(_ timing: AgentStateTiming) {
        guard let data = try? JSONEncoder().encode(timing) else { return }
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            return
        }
    }

    public func reset() {
        try? FileManager.default.removeItem(at: url)
    }
}
