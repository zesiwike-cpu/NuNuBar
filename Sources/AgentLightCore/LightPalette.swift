import Foundation

public enum AgentLightColorRole: String, CaseIterable, Codable, Sendable {
    case working
    case waiting
    case complete
    case idle
}

public enum AgentLightEffect: String, CaseIterable, Codable, Sendable {
    case solid
    case breathe
    case blink

    public var wireValue: UInt8 {
        switch self {
        case .solid: 0x00
        case .breathe: 0x01
        case .blink: 0x02
        }
    }
}

public struct AgentLightRGBColor: Codable, Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public struct AgentLightPalette: Codable, Equatable, Sendable {
    public static let maximumBrightness: UInt8 = 100

    public static let `default` = AgentLightPalette(
        idle: AgentLightRGBColor(red: 0, green: 0, blue: 0),
        working: AgentLightRGBColor(red: 252, green: 84, blue: 0),
        waiting: AgentLightRGBColor(red: 255, green: 0, blue: 0),
        complete: AgentLightRGBColor(red: 0, green: 255, blue: 0),
        idleEffect: .solid,
        workingEffect: .breathe,
        waitingEffect: .blink,
        completeEffect: .solid,
        idleBrightness: maximumBrightness,
        workingBrightness: maximumBrightness,
        waitingBrightness: maximumBrightness,
        completeBrightness: maximumBrightness
    )

    public var idle: AgentLightRGBColor
    public var working: AgentLightRGBColor
    public var waiting: AgentLightRGBColor
    public var complete: AgentLightRGBColor
    public var idleEffect: AgentLightEffect
    public var workingEffect: AgentLightEffect
    public var waitingEffect: AgentLightEffect
    public var completeEffect: AgentLightEffect
    public var idleBrightness: UInt8
    public var workingBrightness: UInt8
    public var waitingBrightness: UInt8
    public var completeBrightness: UInt8

    public init(
        idle: AgentLightRGBColor = AgentLightRGBColor(red: 0, green: 0, blue: 0),
        working: AgentLightRGBColor,
        waiting: AgentLightRGBColor,
        complete: AgentLightRGBColor,
        idleEffect: AgentLightEffect = .solid,
        workingEffect: AgentLightEffect = .breathe,
        waitingEffect: AgentLightEffect = .blink,
        completeEffect: AgentLightEffect = .solid,
        idleBrightness: UInt8 = Self.maximumBrightness,
        workingBrightness: UInt8 = Self.maximumBrightness,
        waitingBrightness: UInt8 = Self.maximumBrightness,
        completeBrightness: UInt8 = Self.maximumBrightness
    ) {
        self.idle = idle
        self.working = working
        self.waiting = waiting
        self.complete = complete
        self.idleEffect = idleEffect
        self.workingEffect = workingEffect
        self.waitingEffect = waitingEffect
        self.completeEffect = completeEffect
        self.idleBrightness = min(idleBrightness, Self.maximumBrightness)
        self.workingBrightness = min(workingBrightness, Self.maximumBrightness)
        self.waitingBrightness = min(waitingBrightness, Self.maximumBrightness)
        self.completeBrightness = min(completeBrightness, Self.maximumBrightness)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.default
        idle = try values.decodeIfPresent(AgentLightRGBColor.self, forKey: .idle) ?? defaults.idle
        working = try values.decodeIfPresent(AgentLightRGBColor.self, forKey: .working) ?? defaults.working
        waiting = try values.decodeIfPresent(AgentLightRGBColor.self, forKey: .waiting) ?? defaults.waiting
        complete = try values.decodeIfPresent(AgentLightRGBColor.self, forKey: .complete) ?? defaults.complete
        idleEffect = try values.decodeIfPresent(AgentLightEffect.self, forKey: .idleEffect) ?? defaults.idleEffect
        workingEffect = try values.decodeIfPresent(AgentLightEffect.self, forKey: .workingEffect) ?? defaults.workingEffect
        waitingEffect = try values.decodeIfPresent(AgentLightEffect.self, forKey: .waitingEffect) ?? defaults.waitingEffect
        completeEffect = try values.decodeIfPresent(AgentLightEffect.self, forKey: .completeEffect) ?? defaults.completeEffect
        idleBrightness = min(
            try values.decodeIfPresent(UInt8.self, forKey: .idleBrightness) ?? defaults.idleBrightness,
            Self.maximumBrightness
        )
        workingBrightness = min(
            try values.decodeIfPresent(UInt8.self, forKey: .workingBrightness) ?? defaults.workingBrightness,
            Self.maximumBrightness
        )
        waitingBrightness = min(
            try values.decodeIfPresent(UInt8.self, forKey: .waitingBrightness) ?? defaults.waitingBrightness,
            Self.maximumBrightness
        )
        completeBrightness = min(
            try values.decodeIfPresent(UInt8.self, forKey: .completeBrightness) ?? defaults.completeBrightness,
            Self.maximumBrightness
        )
    }

    public func color(for command: AgentLightCommand) -> AgentLightRGBColor {
        switch command {
        case .idle: idle
        case .working: working
        case .waiting, .error: waiting
        case .complete: complete
        }
    }

    public func color(for role: AgentLightColorRole) -> AgentLightRGBColor {
        switch role {
        case .idle: idle
        case .working: working
        case .waiting: waiting
        case .complete: complete
        }
    }

    public func effect(for command: AgentLightCommand) -> AgentLightEffect {
        switch command {
        case .idle: idleEffect
        case .working: workingEffect
        case .waiting, .error: waitingEffect
        case .complete: completeEffect
        }
    }

    public func effect(for role: AgentLightColorRole) -> AgentLightEffect {
        switch role {
        case .idle: idleEffect
        case .working: workingEffect
        case .waiting: waitingEffect
        case .complete: completeEffect
        }
    }

    public func brightness(for command: AgentLightCommand) -> UInt8 {
        switch command {
        case .idle: idleBrightness
        case .working: workingBrightness
        case .waiting, .error: waitingBrightness
        case .complete: completeBrightness
        }
    }

    public func brightness(for role: AgentLightColorRole) -> UInt8 {
        switch role {
        case .idle: idleBrightness
        case .working: workingBrightness
        case .waiting: waitingBrightness
        case .complete: completeBrightness
        }
    }

    public func brightnessAdjustedColor(for command: AgentLightCommand) -> AgentLightRGBColor {
        let color = color(for: command)
        let percentage = Int(brightness(for: command))
        return AgentLightRGBColor(
            red: Self.scaled(color.red, percentage: percentage),
            green: Self.scaled(color.green, percentage: percentage),
            blue: Self.scaled(color.blue, percentage: percentage)
        )
    }

    public mutating func setColor(_ color: AgentLightRGBColor, for role: AgentLightColorRole) {
        switch role {
        case .idle: idle = color
        case .working: working = color
        case .waiting: waiting = color
        case .complete: complete = color
        }
    }

    public mutating func setEffect(_ effect: AgentLightEffect, for role: AgentLightColorRole) {
        switch role {
        case .idle: idleEffect = effect
        case .working: workingEffect = effect
        case .waiting: waitingEffect = effect
        case .complete: completeEffect = effect
        }
    }

    public mutating func setBrightness(_ brightness: UInt8, for role: AgentLightColorRole) {
        let normalized = min(brightness, Self.maximumBrightness)
        switch role {
        case .idle: idleBrightness = normalized
        case .working: workingBrightness = normalized
        case .waiting: waitingBrightness = normalized
        case .complete: completeBrightness = normalized
        }
    }

    private static func scaled(_ component: UInt8, percentage: Int) -> UInt8 {
        UInt8((Int(component) * percentage + 50) / 100)
    }
}

public struct AgentLightPaletteStore: Sendable {
    public static let defaultSuiteName = "com.maige.NuphyBar"
    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "AgentLight", directoryHint: .isDirectory)
            .appending(path: "palette.json")
    }

    private let url: URL
    private let legacySuiteName: String?
    private let legacyKey = "agentLightPalette.v1"

    public init(
        url: URL = Self.defaultURL,
        legacySuiteName: String? = Self.defaultSuiteName
    ) {
        self.url = url
        self.legacySuiteName = legacySuiteName
    }

    public func load() -> AgentLightPalette {
        if let data = try? Data(contentsOf: url),
           let palette = try? JSONDecoder().decode(AgentLightPalette.self, from: data) {
            return palette
        }
        if let legacySuiteName,
           let data = UserDefaults(suiteName: legacySuiteName)?.data(forKey: legacyKey),
           let palette = try? JSONDecoder().decode(AgentLightPalette.self, from: data) {
            return palette
        }
        return .default
    }

    public func save(_ palette: AgentLightPalette) {
        guard let data = try? JSONEncoder().encode(palette) else { return }
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
        if let legacySuiteName {
            UserDefaults(suiteName: legacySuiteName)?.removeObject(forKey: legacyKey)
        }
    }
}
