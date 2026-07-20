import Testing
@testable import AgentLightCore

@Test("agent states preserve Caps Lock in the BLE LED report")
func directStatusReport() {
    #expect(DirectStatusEncoder.encode(.idle, capsLockOn: true) == 0x02)
    #expect(DirectStatusEncoder.encode(.working, capsLockOn: true) == 0x03)
    #expect(DirectStatusEncoder.encode(.waiting, capsLockOn: true) == 0x06)
    #expect(DirectStatusEncoder.encode(.complete, capsLockOn: true) == 0x07)
    #expect(DirectStatusEncoder.encode(.error, capsLockOn: false) == 0x04)
}

@Test("USB v3 reports carry color and effect in one fixed-size packet")
func usbStatusReport() {
    let report = USBStatusReportEncoder.encode(.complete)

    #expect(report.count == 32)
    #expect(Array(report[0..<4]) == [0x4E, 0x42, 0x41, 0x52])
    #expect(report[4] == 0x03)
    #expect(report[5] == 0x01)
    #expect(report[6] == 0x05)
    #expect(Array(report[7...9]) == [0, 255, 0])
    #expect(report[10] == AgentLightEffect.solid.wireValue)
    #expect(report[11] == report[0..<11].reduce(UInt8(0)) { $0 ^ $1 })
    #expect(report[12...].allSatisfy { $0 == 0 })
}

@Test("USB reports carry each selected color and effect")
func usbStatusReportCarriesCustomSettings() {
    let palette = AgentLightPalette(
        idle: AgentLightRGBColor(red: 1, green: 2, blue: 3),
        working: AgentLightRGBColor(red: 12, green: 34, blue: 56),
        waiting: AgentLightRGBColor(red: 78, green: 90, blue: 123),
        complete: AgentLightRGBColor(red: 145, green: 167, blue: 189),
        idleEffect: .blink,
        workingEffect: .solid,
        waitingEffect: .breathe,
        completeEffect: .blink,
        workingBrightness: 50
    )

    #expect(Array(USBStatusReportEncoder.encode(.idle, palette: palette)[7...9]) == [1, 2, 3])
    #expect(USBStatusReportEncoder.encode(.idle, palette: palette)[10] == AgentLightEffect.blink.wireValue)
    #expect(Array(USBStatusReportEncoder.encode(.working, palette: palette)[7...9]) == [6, 17, 28])
    #expect(USBStatusReportEncoder.encode(.working, palette: palette)[10] == AgentLightEffect.solid.wireValue)
    #expect(Array(USBStatusReportEncoder.encode(.waiting, palette: palette)[7...9]) == [78, 90, 123])
    #expect(USBStatusReportEncoder.encode(.waiting, palette: palette)[10] == AgentLightEffect.breathe.wireValue)
    #expect(Array(USBStatusReportEncoder.encode(.error, palette: palette)[7...9]) == [78, 90, 123])
    #expect(Array(USBStatusReportEncoder.encode(.complete, palette: palette)[7...9]) == [145, 167, 189])
}

@Test("USB reports retain v2 color compatibility for the current firmware")
func colorV2USBStatusReport() {
    let report = USBStatusReportEncoder.encodeColorV2(.working)

    #expect(report.count == 32)
    #expect(report[4] == 0x02)
    #expect(report[6] == 0x01)
    #expect(Array(report[7...9]) == [252, 84, 0])
    #expect(report[10] == report[0..<10].reduce(UInt8(0)) { $0 ^ $1 })
    #expect(report[11...].allSatisfy { $0 == 0 })
}

@Test("USB reports retain a legacy status packet for v5 firmware")
func legacyUSBStatusReport() {
    let report = USBStatusReportEncoder.encodeLegacy(.working)

    #expect(report.count == 32)
    #expect(report[4] == 0x01)
    #expect(report[5] == 0x01)
    #expect(report[6] == 0x01)
    #expect(report[7] == report[0..<7].reduce(UInt8(0)) { $0 ^ $1 })
    #expect(report[8...].allSatisfy { $0 == 0 })
}

@Test("USB status values match the existing BLE state bits")
func usbStatusValues() {
    #expect(USBStatusReportEncoder.encode(.idle)[6] == 0x00)
    #expect(USBStatusReportEncoder.encode(.working)[6] == 0x01)
    #expect(USBStatusReportEncoder.encode(.waiting)[6] == 0x04)
    #expect(USBStatusReportEncoder.encode(.error)[6] == 0x04)
    #expect(USBStatusReportEncoder.encode(.complete)[6] == 0x05)
}
