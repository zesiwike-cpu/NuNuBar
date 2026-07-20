public enum Air65V3ProtocolValidationError: Error, Equatable, Sendable {
    case invalidChallengeLength
    case invalidReportLength
    case invalidHeader
    case invalidChecksum
    case invalidHandshakeKey
    case invalidBaseResponse
    case payloadTooLarge
}

public struct AirV3SideLightModeMap: Equatable, Sendable {
    public let solid: UInt8
    public let breathe: UInt8
    public let customRGBFlag: UInt8

    public init(solid: UInt8, breathe: UInt8, customRGBFlag: UInt8) {
        self.solid = solid
        self.breathe = breathe
        self.customRGBFlag = customRGBFlag
    }

    public static let air65V3 = AirV3SideLightModeMap(
        solid: 2,
        breathe: 3,
        customRGBFlag: 0
    )
    public static let air75V3 = AirV3SideLightModeMap(
        solid: 2,
        breathe: 3,
        customRGBFlag: 0
    )
}

public enum Air65V3ProtocolEncoder {
    public static let reportSize = 64
    public static let payloadSize = reportSize - 8

    private static let handshakeCommand: UInt8 = 0xEE
    private static let getBaseCommand: UInt8 = 0xA0
    private static let getFirmwareInfoCommand: UInt8 = 0xA1
    private static let getLightStateCommand: UInt8 = 0xD5
    private static let setDataCommand: UInt8 = 0xD6
    private static let getAppDefineSizeCommand: UInt8 = 0xFA
    private static let getAppDefineCommand: UInt8 = 0xFB
    // These are the side-light slots used by the verified Air65 V3 live HID path.
    private static let sideLightOffset: UInt16 = 9
    private static let sideLightBrightnessOffset = sideLightOffset + 1

    public static func handshake(challenge: [UInt8]) throws -> [UInt8] {
        guard challenge.count == payloadSize else {
            throw Air65V3ProtocolValidationError.invalidChallengeLength
        }

        var report = [UInt8](repeating: 0, count: reportSize)
        report[0] = 0x55
        report[1] = handshakeCommand
        report.replaceSubrange(8..<reportSize, with: challenge)
        report[3] = checksum(report)
        return report
    }

    public static func sessionKey(
        from response: [UInt8],
        challenge: [UInt8]
    ) throws -> UInt8 {
        guard response.count == reportSize else {
            throw Air65V3ProtocolValidationError.invalidReportLength
        }
        guard challenge.count == payloadSize else {
            throw Air65V3ProtocolValidationError.invalidChallengeLength
        }
        guard response[0] == 0xAA, response[1] == handshakeCommand else {
            throw Air65V3ProtocolValidationError.invalidHeader
        }
        guard response[3] == checksum(response) else {
            throw Air65V3ProtocolValidationError.invalidChecksum
        }

        let key = response[4]
        guard response[5] == key, response[6] == key, response[7] == key else {
            throw Air65V3ProtocolValidationError.invalidHandshakeKey
        }
        guard zip(challenge, response[8...]).allSatisfy({ ($0 ^ $1) == key }) else {
            throw Air65V3ProtocolValidationError.invalidHandshakeKey
        }
        return key
    }

    public static func baseRequest(sessionKey: UInt8) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: reportSize)
        report[0] = 0x55
        report[1] = getBaseCommand
        report[4] = 8 ^ sessionKey
        report[5] = sessionKey
        report[6] = sessionKey
        report[7] = sessionKey
        report[3] = checksum(report)
        return report
    }

    public static func currentMode(
        from response: [UInt8],
        sessionKey: UInt8
    ) throws -> UInt8 {
        guard response.count == reportSize else {
            throw Air65V3ProtocolValidationError.invalidReportLength
        }
        guard response[0] == 0xAA, response[1] == getBaseCommand else {
            throw Air65V3ProtocolValidationError.invalidHeader
        }
        guard response[3] == checksum(response) else {
            throw Air65V3ProtocolValidationError.invalidChecksum
        }

        let length = response[4] ^ sessionKey
        let offsetLow = response[5] ^ sessionKey
        let offsetHigh = response[6] ^ sessionKey
        let handle = response[7] ^ sessionKey
        guard length == 8,
              offsetLow == 0,
              offsetHigh == 0,
              handle == 0 else {
            throw Air65V3ProtocolValidationError.invalidBaseResponse
        }
        return response[8] ^ sessionKey
    }

    public static func firmwareInfoRequest(sessionKey: UInt8) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: reportSize)
        report[0] = 0x55
        report[1] = getFirmwareInfoCommand
        report[4] = 8 ^ sessionKey
        report[5] = sessionKey
        report[6] = sessionKey
        report[7] = sessionKey
        report[3] = checksum(report)
        return report
    }

    public static func firmwareInfo(
        from response: [UInt8],
        sessionKey: UInt8
    ) throws -> [UInt8] {
        try readPayload(
            from: response,
            command: getFirmwareInfoCommand,
            length: 8,
            handle: 0,
            sessionKey: sessionKey
        )
    }

    public static func appDefineSizeRequest(sessionKey: UInt8) -> [UInt8] {
        dataRequest(
            command: getAppDefineSizeCommand,
            length: 10,
            sessionKey: sessionKey
        )
    }

    public static func appDefineSize(
        from response: [UInt8],
        sessionKey: UInt8
    ) throws -> UInt16 {
        let payload = try readPayload(
            from: response,
            command: getAppDefineSizeCommand,
            length: 10,
            handle: 0,
            sessionKey: sessionKey
        )
        return UInt16(payload[0]) << 8 | UInt16(payload[1])
    }

    public static func appDefineRequest(
        offset: UInt16,
        length: UInt8 = 56,
        sessionKey: UInt8
    ) throws -> [UInt8] {
        guard length <= payloadSize else {
            throw Air65V3ProtocolValidationError.payloadTooLarge
        }
        return dataRequest(
            command: getAppDefineCommand,
            length: length,
            offset: offset,
            sessionKey: sessionKey
        )
    }

    public static func appDefine(
        from response: [UInt8],
        offset: UInt16,
        length: UInt8 = 56,
        sessionKey: UInt8
    ) throws -> [UInt8] {
        try readPayload(
            from: response,
            command: getAppDefineCommand,
            length: length,
            offset: offset,
            handle: 0,
            sessionKey: sessionKey
        )
    }

    public static func statusReports(
        _ command: AgentLightCommand,
        palette: AgentLightPalette = .default,
        sessionKey: UInt8,
        currentMode: UInt8,
        brightness: UInt8 = 24,
        effectOverride: AgentLightEffect? = nil,
        sideLightModes: AirV3SideLightModeMap = .air65V3
    ) throws -> [[UInt8]] {
        let color = palette.color(for: command)
        let effect = sideEffect(
            for: effectOverride ?? palette.effect(for: command),
            modes: sideLightModes
        )
        let sidePayload: [UInt8] = [
            effect.identifier,
            brightness,
            effect.speed,
            sideLightModes.customRGBFlag,
            0,
            color.red,
            color.green,
            color.blue,
        ]

        return [
            try setDataReport(
                offset: sideLightOffset,
                payload: sidePayload,
                mode: currentMode,
                sessionKey: sessionKey
            ),
            try setDataReport(
                offset: sideLightBrightnessOffset,
                payload: [brightness],
                mode: currentMode,
                sessionKey: sessionKey
            ),
        ]
    }

    public static func lightStateRequest(
        sessionKey: UInt8,
        currentMode: UInt8
    ) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: reportSize)
        report[0] = 0x55
        report[1] = getLightStateCommand
        report[4] = 17 ^ sessionKey
        report[5] = sessionKey
        report[6] = sessionKey
        report[7] = currentMode ^ sessionKey
        report[3] = checksum(report)
        return report
    }

    public static func lightState(
        from response: [UInt8],
        sessionKey: UInt8,
        currentMode: UInt8
    ) throws -> [UInt8] {
        try readPayload(
            from: response,
            command: getLightStateCommand,
            length: 17,
            handle: currentMode,
            sessionKey: sessionKey
        )
    }

    public static func validateAcknowledgement(
        _ response: [UInt8],
        expectedCommand: UInt8 = 0xD6
    ) throws {
        guard response.count == reportSize else {
            throw Air65V3ProtocolValidationError.invalidReportLength
        }
        guard response[0] == 0xAA, response[1] == expectedCommand else {
            throw Air65V3ProtocolValidationError.invalidHeader
        }
        guard response[3] == checksum(response) else {
            throw Air65V3ProtocolValidationError.invalidChecksum
        }
    }

    public static func checksum(_ report: [UInt8]) -> UInt8 {
        report.dropFirst(4).reduce(UInt8(0), &+)
    }

    private static func setDataReport(
        offset: UInt16,
        payload: [UInt8],
        mode: UInt8,
        sessionKey: UInt8
    ) throws -> [UInt8] {
        guard payload.count <= payloadSize else {
            throw Air65V3ProtocolValidationError.payloadTooLarge
        }

        var report = [UInt8](repeating: 0, count: reportSize)
        report[0] = 0x55
        report[1] = setDataCommand
        report[4] = UInt8(payload.count) ^ sessionKey
        report[5] = UInt8(truncatingIfNeeded: offset) ^ sessionKey
        report[6] = UInt8(truncatingIfNeeded: offset >> 8) ^ sessionKey
        report[7] = mode ^ sessionKey
        for (index, byte) in payload.enumerated() {
            report[8 + index] = byte ^ sessionKey
        }
        report[3] = checksum(report)
        return report
    }

    private static func dataRequest(
        command: UInt8,
        length: UInt8,
        offset: UInt16 = 0,
        handle: UInt8 = 0,
        sessionKey: UInt8
    ) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: reportSize)
        report[0] = 0x55
        report[1] = command
        report[4] = length ^ sessionKey
        report[5] = UInt8(truncatingIfNeeded: offset) ^ sessionKey
        report[6] = UInt8(truncatingIfNeeded: offset >> 8) ^ sessionKey
        report[7] = handle ^ sessionKey
        report[3] = checksum(report)
        return report
    }

    private static func readPayload(
        from response: [UInt8],
        command: UInt8,
        length: UInt8,
        offset: UInt16 = 0,
        handle: UInt8,
        sessionKey: UInt8
    ) throws -> [UInt8] {
        guard response.count == reportSize else {
            throw Air65V3ProtocolValidationError.invalidReportLength
        }
        guard response[0] == 0xAA, response[1] == command else {
            throw Air65V3ProtocolValidationError.invalidHeader
        }
        guard response[3] == checksum(response) else {
            throw Air65V3ProtocolValidationError.invalidChecksum
        }
        guard response[4] ^ sessionKey == length,
              response[5] ^ sessionKey == UInt8(truncatingIfNeeded: offset),
              response[6] ^ sessionKey == UInt8(truncatingIfNeeded: offset >> 8),
              response[7] ^ sessionKey == handle else {
            throw Air65V3ProtocolValidationError.invalidBaseResponse
        }
        return response[8..<(8 + Int(length))].map { $0 ^ sessionKey }
    }

    private static func sideEffect(
        for effect: AgentLightEffect,
        modes: AirV3SideLightModeMap
    ) -> (identifier: UInt8, speed: UInt8) {
        switch effect {
        case .solid:
            return (identifier: modes.solid, speed: 2)
        case .breathe:
            return (identifier: modes.breathe, speed: 1)
        case .blink:
            // The transport renders blink with acknowledged solid on/off
            // frames because the official firmware has no discrete blink.
            return (identifier: modes.solid, speed: 2)
        }
    }
}
