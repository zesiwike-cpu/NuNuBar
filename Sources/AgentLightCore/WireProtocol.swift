public enum AgentLightCommand: Equatable, Sendable {
    case idle
    case working
    case waiting
    case complete
    case error
}

public enum AgentLightStatusEncoder {
    public static func encode(_ command: AgentLightCommand) -> UInt8 {
        switch command {
        case .idle: return 0x00
        case .working: return 0x01
        case .waiting, .error: return 0x04
        case .complete: return 0x05
        }
    }
}

public enum DirectStatusEncoder {
    private static let capsLock: UInt8 = 0x02

    public static func encode(_ command: AgentLightCommand, capsLockOn: Bool) -> UInt8 {
        let caps = capsLockOn ? capsLock : 0
        return caps | AgentLightStatusEncoder.encode(command)
    }
}

public enum USBStatusReportEncoder {
    public static let reportSize = 32
    public static let reportID = 0

    private static let magic: [UInt8] = [0x4E, 0x42, 0x41, 0x52] // "NBAR"
    private static let colorProtocolVersion: UInt8 = 0x02
    private static let effectProtocolVersion: UInt8 = 0x03
    private static let setStatusCommand: UInt8 = 0x01

    public static func encodeLegacy(_ command: AgentLightCommand) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: reportSize)
        report.replaceSubrange(0..<magic.count, with: magic)
        report[4] = 0x01
        report[5] = setStatusCommand
        report[6] = AgentLightStatusEncoder.encode(command)
        report[7] = report[0..<7].reduce(UInt8(0)) { $0 ^ $1 }
        return report
    }

    public static func encodeColorV2(
        _ command: AgentLightCommand,
        palette: AgentLightPalette = .default
    ) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: reportSize)
        let color = palette.brightnessAdjustedColor(for: command)
        report.replaceSubrange(0..<magic.count, with: magic)
        report[4] = colorProtocolVersion
        report[5] = setStatusCommand
        report[6] = AgentLightStatusEncoder.encode(command)
        report[7] = color.red
        report[8] = color.green
        report[9] = color.blue
        report[10] = report[0..<10].reduce(UInt8(0)) { $0 ^ $1 }
        return report
    }

    public static func encode(
        _ command: AgentLightCommand,
        palette: AgentLightPalette = .default
    ) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: reportSize)
        let color = palette.brightnessAdjustedColor(for: command)
        report.replaceSubrange(0..<magic.count, with: magic)
        report[4] = effectProtocolVersion
        report[5] = setStatusCommand
        report[6] = AgentLightStatusEncoder.encode(command)
        report[7] = color.red
        report[8] = color.green
        report[9] = color.blue
        report[10] = palette.effect(for: command).wireValue
        report[11] = report[0..<11].reduce(UInt8(0)) { $0 ^ $1 }
        return report
    }
}
