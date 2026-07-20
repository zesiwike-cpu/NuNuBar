import IOKit.hid
import Testing
@testable import AgentLightHID

@Test("HID failures expose useful macOS error descriptions")
func localizedHIDError() {
    #expect(NuPhyHIDError.deviceNotConnected.localizedDescription
            == "未找到已连接的 NuNuBar 兼容 NuPhy 键盘")
    #expect(NuPhyHIDError.permissionDenied.localizedDescription
            == "需要允许 NuNuBar 访问键盘 HID 接口")
}

@Test("the HID manager enumerates BLE, Raw HID, and official Air V3 control interfaces")
func scopedDeviceMatching() {
    let matchers = NuPhyHIDTransport.deviceMatchingProperties
    let bluetooth = matchers.first {
        $0[kIOHIDTransportKey as String] as? String == "Bluetooth Low Energy"
    }
    let usb = matchers.filter { $0[kIOHIDTransportKey as String] as? String == "USB" }

    #expect(matchers.count == 7)
    #expect(bluetooth?[kIOHIDDeviceUsagePageKey as String] as? Int == 1)
    #expect(bluetooth?[kIOHIDDeviceUsageKey as String] as? Int == 6)
    #expect(Set(usb.compactMap { $0[kIOHIDProductIDKey as String] as? Int }) == [0x1028, 0x102B, 0x3255, 0x3246, 0x3266, 0x32F5])
    #expect(usb.allSatisfy { $0[kIOHIDVendorIDKey as String] as? Int == 0x19F5 })
    let airV3 = usb.filter { [0x1028, 0x102B].contains($0[kIOHIDProductIDKey as String] as? Int) }
    #expect(airV3.count == 2)
    #expect(airV3.allSatisfy { $0[kIOHIDDeviceUsagePageKey as String] as? Int == 1 })
    #expect(airV3.allSatisfy { $0[kIOHIDDeviceUsageKey as String] as? Int == 0 })
    #expect(airV3.allSatisfy { $0[kIOHIDMaxInputReportSizeKey as String] as? Int == 64 })
    #expect(airV3.allSatisfy { $0[kIOHIDMaxOutputReportSizeKey as String] as? Int == 64 })
    let rawHID = usb.filter { ![0x1028, 0x102B].contains($0[kIOHIDProductIDKey as String] as? Int) }
    #expect(rawHID.allSatisfy { $0[kIOHIDDeviceUsagePageKey as String] as? Int == 0xFF60 })
    #expect(rawHID.allSatisfy { $0[kIOHIDDeviceUsageKey as String] as? Int == 0x61 })
}

@Test("only exact wired Air V3 official control interfaces are accepted")
func compatibleAirV3OfficialInterfaces() {
    for (name, productID) in [("Air65 V3", 0x102B), ("Air75 V3", 0x1028)] {
        #expect(NuPhyHIDTransport.deviceProtocol(
            productName: name,
            transport: "USB",
            vendorID: 0x19F5,
            productID: productID,
            usagePage: 1,
            usage: 0,
            maxOutputReportSize: 64,
            maxInputReportSize: 64
        ) == .airV3Official)
        #expect(NuPhyHIDTransport.connectionTransport(
            productName: name,
            transport: "USB",
            vendorID: 0x19F5,
            productID: productID,
            usagePage: 1,
            usage: 0,
            maxOutputReportSize: 64,
            maxInputReportSize: 64
        ) == .usb)
    }

    for mismatch in [
        (0x2620, 1, 0, 64),
        (0x102B, 1, 6, 64),
        (0x102B, 1, 0, 63),
    ] {
        #expect(NuPhyHIDTransport.deviceProtocol(
            productName: "Air65 V3",
            transport: "USB",
            vendorID: 0x19F5,
            productID: mismatch.0,
            usagePage: mismatch.1,
            usage: mismatch.2,
            maxOutputReportSize: mismatch.3,
            maxInputReportSize: 64
        ) == nil)
    }

    #expect(NuPhyHIDTransport.deviceProtocol(
        productName: "Air75 V3",
        transport: "USB",
        vendorID: 0x19F5,
        productID: 0x1028,
        usagePage: 1,
        usage: 0,
        maxOutputReportSize: 64,
        maxInputReportSize: 63
    ) == nil)

    #expect(NuPhyHIDTransport.deviceProtocol(
        productName: "Air65 V3",
        transport: "USB",
        vendorID: 0x19F5,
        productID: 0x1028,
        usagePage: 1,
        usage: 0,
        maxOutputReportSize: 64,
        maxInputReportSize: 64
    ) == nil)
}

@Test("compatible BLE NuPhy models retain the standard LED report path")
func compatibleNuPhyKeyboards() {
    #expect(NuPhyHIDTransport.isCompatible(
        productName: "NuPhy Air60 V2-1",
        transport: "Bluetooth Low Energy",
        vendorID: nil,
        productID: nil,
        usagePage: 1,
        usage: 6,
        maxOutputReportSize: 2
    ))
    #expect(NuPhyHIDTransport.isCompatible(
        productName: "NuPhy Halo75 V2",
        transport: "Bluetooth Low Energy",
        vendorID: nil,
        productID: nil,
        usagePage: 1,
        usage: 6,
        maxOutputReportSize: 8
    ))
    #expect(!NuPhyHIDTransport.isCompatible(
        productName: "Apple Internal Keyboard / Trackpad",
        transport: "Bluetooth Low Energy",
        vendorID: nil,
        productID: nil,
        usagePage: 1,
        usage: 6,
        maxOutputReportSize: 2
    ))
    #expect(!NuPhyHIDTransport.isCompatible(
        productName: "NuPhy Air60 V2-1",
        transport: "USB",
        vendorID: 0x19F5,
        productID: 0x3266,
        usagePage: 1,
        usage: 6,
        maxOutputReportSize: 2
    ))
    #expect(!NuPhyHIDTransport.isCompatible(
        productName: "NuPhy Air60 V2-1",
        transport: "Bluetooth Low Energy",
        vendorID: nil,
        productID: nil,
        usagePage: 1,
        usage: 6,
        maxOutputReportSize: 1
    ))
}

@Test("only whitelisted NuPhy QMK Raw HID interfaces are accepted over USB")
func compatibleNuPhyV2USBInterfaces() {
    for (name, productID) in [
        ("NuPhy Air60 V2", 0x3255),
        ("NuPhy Air75 V2", 0x3246),
        ("NuPhy Air96 V2", 0x3266),
        ("NuPhy Halo75 V2", 0x32F5),
    ] {
        #expect(NuPhyHIDTransport.connectionTransport(
            productName: name,
            transport: "USB",
            vendorID: 0x19F5,
            productID: productID,
            usagePage: 0xFF60,
            usage: 0x61,
            maxOutputReportSize: 32
        ) == .usb)
    }
    #expect(NuPhyHIDTransport.connectionTransport(
        productName: "NuPhy Air96 V2",
        transport: "USB",
        vendorID: 0x19F5,
        productID: 0x3299,
        usagePage: 0xFF60,
        usage: 0x61,
        maxOutputReportSize: 32
    ) == nil)
    #expect(NuPhyHIDTransport.connectionTransport(
        productName: "NuPhy Air96 V2",
        transport: "USB",
        vendorID: 0x19F5,
        productID: 0x3266,
        usagePage: 0xFF60,
        usage: 0x61,
        maxOutputReportSize: 31
    ) == nil)
}

@Test("Air V3 brightness maps percentages to each model's hardware range")
func airV3BrightnessMapping() {
    #expect(NuPhyHIDTransport.airV3HardwareBrightness(percent: 0, productID: 0x1028) == 0)
    #expect(NuPhyHIDTransport.airV3HardwareBrightness(percent: 42, productID: 0x1028) == 42)
    #expect(NuPhyHIDTransport.airV3HardwareBrightness(percent: 100, productID: 0x1028) == 100)

    #expect(NuPhyHIDTransport.airV3HardwareBrightness(percent: 0, productID: 0x102B) == 0)
    #expect(NuPhyHIDTransport.airV3HardwareBrightness(percent: 50, productID: 0x102B) == 12)
    #expect(NuPhyHIDTransport.airV3HardwareBrightness(percent: 100, productID: 0x102B) == 24)
    #expect(NuPhyHIDTransport.airV3HardwareBrightness(percent: 255, productID: 0x1028) == 100)
}

@Test("HID recovery backs off and stays bounded until a report succeeds")
func boundedReconnectBackoff() {
    var backoff = HIDReconnectBackoff()

    #expect((0..<6).map { _ in backoff.nextDelay() } == [1, 2, 5, 10, 30, 30])

    backoff.reset()
    #expect(backoff.nextDelay() == 1)
}

@Test("report recovery does not pretend the keyboard was disconnected")
func recoveryKeepsKeyboardPresence() {
    let state = NuPhyHIDConnectionState.connected(
        productName: "NuPhy Air60 V2-1",
        transport: .bluetoothLowEnergy,
        delivery: .recovering(.reportFailed(kIOReturnNotPermitted))
    )

    guard case .connected(
        let productName,
        let transport,
        .recovering(let error)
    ) = state else {
        Issue.record("expected a connected keyboard with a recovering report channel")
        return
    }
    #expect(productName == "NuPhy Air60 V2-1")
    #expect(transport == .bluetoothLowEnergy)
    #expect(error == .reportFailed(kIOReturnNotPermitted))
}

@Test("proactive HID session rebuilding keeps the keyboard present")
func rebuildingKeepsKeyboardPresence() {
    let state = NuPhyHIDConnectionState.connected(
        productName: "NuPhy Air60 V2-1",
        transport: .usb,
        delivery: .rebuilding
    )

    guard case .connected(let productName, let transport, .rebuilding) = state else {
        Issue.record("expected a connected keyboard with a rebuilding report channel")
        return
    }
    #expect(productName == "NuPhy Air60 V2-1")
    #expect(transport == .usb)
}
