import Testing
@testable import AgentLightCore

@Test("Air65 V3 handshake validates the official XOR session")
func air65V3Handshake() throws {
    let challenge = (0..<Air65V3ProtocolEncoder.payloadSize).map(UInt8.init)
    let request = try Air65V3ProtocolEncoder.handshake(challenge: challenge)

    #expect(request.count == 64)
    #expect(Array(request[0...2]) == [0x55, 0xEE, 0x00])
    #expect(Array(request[8...]) == challenge)
    #expect(request[3] == Air65V3ProtocolEncoder.checksum(request))

    let key: UInt8 = 0x65
    var response = [UInt8](repeating: 0, count: 64)
    response[0] = 0xAA
    response[1] = 0xEE
    response[4] = key
    response[5] = key
    response[6] = key
    response[7] = key
    for (index, byte) in challenge.enumerated() {
        response[8 + index] = byte ^ key
    }
    response[3] = Air65V3ProtocolEncoder.checksum(response)

    #expect(try Air65V3ProtocolEncoder.sessionKey(
        from: response,
        challenge: challenge
    ) == key)
}

@Test("Air65 V3 reads the active keyboard mode from GetBase")
func air65V3GetBase() throws {
    let key: UInt8 = 0x65
    let request = Air65V3ProtocolEncoder.baseRequest(sessionKey: key)

    #expect(request.count == 64)
    #expect(Array(request[0...2]) == [0x55, 0xA0, 0x00])
    #expect(request[4] == 8 ^ key)
    #expect(request[5] == key)
    #expect(request[6] == key)
    #expect(request[7] == key)
    #expect(request[3] == Air65V3ProtocolEncoder.checksum(request))

    for mode: UInt8 in [0, 1] {
        var response = [UInt8](repeating: 0, count: 64)
        response[0] = 0xAA
        response[1] = 0xA0
        response[4] = 8 ^ key
        response[5] = key
        response[6] = key
        response[7] = key
        response[8] = mode ^ key
        response[9] = 2 ^ key
        response[3] = Air65V3ProtocolEncoder.checksum(response)

        #expect(try Air65V3ProtocolEncoder.currentMode(
            from: response,
            sessionKey: key
        ) == mode)
    }
}

@Test("Air65 V3 reports carry NuNuBar colors and acknowledged blink frames")
func air65V3StatusReports() throws {
    let palette = AgentLightPalette(
        idle: AgentLightRGBColor(red: 1, green: 2, blue: 3),
        working: AgentLightRGBColor(red: 12, green: 34, blue: 56),
        waiting: AgentLightRGBColor(red: 78, green: 90, blue: 123),
        complete: AgentLightRGBColor(red: 145, green: 167, blue: 189),
        idleEffect: .solid,
        workingEffect: .breathe,
        waitingEffect: .blink,
        completeEffect: .solid
    )
    let key: UInt8 = 0x65

    let working = try Air65V3ProtocolEncoder.statusReports(
        .working,
        palette: palette,
        sessionKey: key,
        currentMode: 1
    )
    #expect(working.count == 2)
    #expect(working.allSatisfy { $0.count == 64 })
    #expect(Array(working[0][0...2]) == [0x55, 0xD6, 0x00])
    #expect(working[0][4] == 0x08 ^ key)
    #expect(working[0][5] == 9 ^ key)
    #expect(working[0][6] == 0 ^ key)
    #expect(working[0][7] == 1 ^ key)
    #expect(working[0][8] == 3 ^ key)
    #expect(working[0][10] == 1 ^ key)
    #expect(Array(working[0][13...15]) == [12 ^ key, 34 ^ key, 56 ^ key])
    #expect(working[0][3] == Air65V3ProtocolEncoder.checksum(working[0]))
    #expect(working[1][4] == 0x01 ^ key)
    #expect(working[1][5] == 10 ^ key)
    #expect(working[1][6] == 0 ^ key)
    #expect(working[1][7] == 1 ^ key)
    #expect(working[1][8] == 24 ^ key)

    let waiting = try Air65V3ProtocolEncoder.statusReports(
        .waiting,
        palette: palette,
        sessionKey: key,
        currentMode: 1
    )
    #expect(waiting[0][8] == 2 ^ key)
    #expect(waiting[0][10] == 2 ^ key)

    let blinkOff = try Air65V3ProtocolEncoder.statusReports(
        .waiting,
        palette: palette,
        sessionKey: key,
        currentMode: 1,
        brightness: 0,
        effectOverride: .solid
    )
    #expect(blinkOff[0][9] == 0 ^ key)
    #expect(blinkOff[1][8] == 0 ^ key)
}

@Test("Air65 V3 rejects malformed GetBase responses")
func air65V3GetBaseValidation() throws {
    let key: UInt8 = 0x65
    var response = [UInt8](repeating: 0, count: 64)
    response[0] = 0xAA
    response[1] = 0xA0
    response[4] = 8 ^ key
    response[5] = key
    response[6] = key
    response[7] = key
    response[8] = key
    response[3] = Air65V3ProtocolEncoder.checksum(response)

    response[4] = 7 ^ key
    response[3] = Air65V3ProtocolEncoder.checksum(response)
    #expect(throws: Air65V3ProtocolValidationError.invalidBaseResponse) {
        try Air65V3ProtocolEncoder.currentMode(from: response, sessionKey: key)
    }

    response[4] = 8 ^ key
    response[3] = Air65V3ProtocolEncoder.checksum(response)
    response[12] ^= 1
    #expect(throws: Air65V3ProtocolValidationError.invalidChecksum) {
        try Air65V3ProtocolEncoder.currentMode(from: response, sessionKey: key)
    }
}

@Test("Air65 V3 rejects malformed handshake responses")
func air65V3HandshakeValidation() throws {
    let challenge = [UInt8](repeating: 0x11, count: Air65V3ProtocolEncoder.payloadSize)
    var response = [UInt8](repeating: 0, count: 64)
    response[0] = 0xAA
    response[1] = 0xEE
    response[4] = 0x65
    response[5] = 0x65
    response[6] = 0x65
    response[7] = 0x65
    response[8...] = ArraySlice(challenge.map { $0 ^ 0x65 })
    response[3] = Air65V3ProtocolEncoder.checksum(response)
    response[12] ^= 1

    #expect(throws: Air65V3ProtocolValidationError.invalidChecksum) {
        try Air65V3ProtocolEncoder.sessionKey(from: response, challenge: challenge)
    }
}
