import Foundation
import Testing
@testable import AgentLightApp

private let setupManifest = BundledFirmwareManifest(
    identifier: "nuphy-air96-v2-ansi-nunubar-7",
    modelIdentifier: "air96-v2-ansi",
    displayName: "NuPhy Air96 V2 ANSI",
    layout: "ANSI",
    firmwareVersion: "7",
    protocolVersion: 3,
    releaseStatus: .verified,
    lightZone: .dualSideBars,
    keyboardVendorID: 0x19F5,
    keyboardProductID: 0x3266,
    dfuVendorID: 0x0483,
    dfuProductID: 0xDF11,
    alternateInterface: 0,
    flashAddress: "0x08000000",
    firmwareFile: "firmware.bin",
    firmwareSize: 66_088,
    firmwareSHA256: String(repeating: "a", count: 64)
)

@Test("DFU listing parser keeps path, alternate interface, and memory name")
func dfuListingParser() {
    let output = """
    Found DFU: [0483:df11] ver=2200, devnum=1, cfg=1, intf=0, path="2-1", alt=1, name="@Option Bytes  /0x1FFFF800/01*016 e", serial="FFFFFFFEFFFF"
    Found DFU: [0483:df11] ver=2200, devnum=1, cfg=1, intf=0, path="2-1", alt=0, name="@Internal Flash  /0x08000000/064*0002Kg", serial="FFFFFFFEFFFF"
    """

    let targets = DFUListParser.parse(output)
    #expect(targets.count == 2)
    #expect(targets[0].path == "2-1")
    #expect(targets[0].alternateInterface == 1)
    #expect(targets[1].name.contains("0x08000000"))
}

@Test("only one matching keyboard internal flash target is accepted")
func validatedDFUTarget() throws {
    let targets = [
        DFUTarget(vendorID: 0x0483, productID: 0xDF11, path: "2-1", alternateInterface: 1, name: "@Option Bytes  /0x1FFFF800/01*016 e"),
        DFUTarget(vendorID: 0x0483, productID: 0xDF11, path: "2-1", alternateInterface: 0, name: "@Internal Flash  /0x08000000/064*0002Kg"),
    ]

    let target = try FirmwareSetupService.validatedTarget(from: targets, manifest: setupManifest)
    #expect(target.path == "2-1")
    #expect(target.alternateInterface == 0)
}

@Test("multiple physical DFU devices stop automatic flashing")
func multipleDFUDevicesAreRejected() {
    let targets = ["2-1", "3-2"].flatMap { path in
        [
            DFUTarget(vendorID: 0x0483, productID: 0xDF11, path: path, alternateInterface: 1, name: "@Option Bytes  /0x1FFFF800/01*016 e"),
            DFUTarget(vendorID: 0x0483, productID: 0xDF11, path: path, alternateInterface: 0, name: "@Internal Flash  /0x08000000/064*0002Kg"),
        ]
    }

    #expect(throws: FirmwareSetupError.multipleDFUDevices) {
        try FirmwareSetupService.validatedTarget(from: targets, manifest: setupManifest)
    }
}

@Test("option bytes can never be selected as the flash target")
func optionBytesAreRejected() {
    let targets = [
        DFUTarget(vendorID: 0x0483, productID: 0xDF11, path: "2-1", alternateInterface: 1, name: "@Option Bytes  /0x1FFFF800/01*016 e"),
    ]

    #expect(throws: FirmwareSetupError.unexpectedDFULayout) {
        try FirmwareSetupService.validatedTarget(from: targets, manifest: setupManifest)
    }
}

@Test("flash command is pinned to device path, alt zero, and internal flash")
func safeFlashArguments() {
    let arguments = FirmwareFlashCommand.arguments(
        manifest: setupManifest,
        path: "2-1",
        firmwareURL: URL(fileURLWithPath: "/tmp/firmware.bin")
    )

    #expect(arguments == [
        "-d", "0483:df11",
        "-p", "2-1",
        "-a", "0",
        "-s", "0x08000000:leave",
        "-D", "/tmp/firmware.bin",
    ])
}

@Test("successful flashing requires both download and leave confirmation")
func strictFlashCompletion() {
    #expect(FirmwareFlashCommand.completedSuccessfully(
        exitCode: 0,
        output: "File downloaded successfully\nSubmitting leave request..."
    ))
    #expect(!FirmwareFlashCommand.completedSuccessfully(
        exitCode: 0,
        output: "File downloaded successfully"
    ))
    #expect(!FirmwareFlashCommand.completedSuccessfully(
        exitCode: 1,
        output: "File downloaded successfully\nSubmitting leave request..."
    ))
}

@Test("USB setup only accepts an exact model identity")
func exactUSBKeyboardIdentity() {
    let air96 = USBDeviceIdentity(
        vendorID: 0x19F5,
        productID: 0x3266,
        productName: "NuPhy Air96 V2"
    )
    let anotherNuPhy = USBDeviceIdentity(
        vendorID: 0x19F5,
        productID: 0x3245,
        productName: "NuPhy Air75 V2"
    )

    #expect(USBKeyboardDetector.matches(air96, manifest: setupManifest))
    #expect(!USBKeyboardDetector.matches(anotherNuPhy, manifest: setupManifest))
}

@Test("Air65 V3 setup requires its exact official USB identity")
func exactAir65V3SetupIdentity() throws {
    let air65 = USBDeviceIdentity(
        vendorID: 0x19F5,
        productID: 0x102B,
        productName: "Air65 V3"
    )
    let wrongProductName = USBDeviceIdentity(
        vendorID: 0x19F5,
        productID: 0x102B,
        productName: "Another Keyboard"
    )
    let wrongProductID = USBDeviceIdentity(
        vendorID: 0x19F5,
        productID: 0x102C,
        productName: "Air65 V3"
    )

    let matches = USBKeyboardDetector.matchingSetupDevices([air65], in: nil)
    let match = try #require(matches.first)
    #expect(matches.count == 1)
    #expect(match.target.modelIdentifier == "air65-v3")
    #expect(match.target.displayName == "NuPhy Air65 V3")
    #expect(match.target.usesOfficialFirmware)
    #expect(match.target.bundledFirmware == nil)
    #expect(match.target.minimumOfficialFirmwareVersion == nil)
    #expect(USBKeyboardDetector.matchingSetupDevices([wrongProductName], in: nil).isEmpty)
    #expect(USBKeyboardDetector.matchingSetupDevices([wrongProductID], in: nil).isEmpty)
}

@Test("Air65 V3 setup skips every firmware and DFU stage")
func officialFirmwareSetupRoute() {
    #expect(KeyboardSetupRoute.stageAfterKeyboard(usesOfficialFirmware: true).rawValue
        == KeyboardSetupStage.codex.rawValue)
    #expect(KeyboardSetupRoute.stageAfterKeyboard(usesOfficialFirmware: false).rawValue
        == KeyboardSetupStage.compatibility.rawValue)
}

@Test("Air75 V3 setup uses its exact official USB identity without firmware")
func exactAir75V3SetupIdentity() throws {
    let air75 = USBDeviceIdentity(
        vendorID: 0x19F5,
        productID: 0x1028,
        productName: "Air75 V3"
    )
    let matches = USBKeyboardDetector.matchingSetupDevices([air75], in: nil)
    let match = try #require(matches.first)

    #expect(matches.count == 1)
    #expect(match.target.modelIdentifier == "air75-v3")
    #expect(match.target.displayName == "NuPhy Air75 V3")
    #expect(match.target.usesOfficialFirmware)
    #expect(match.target.bundledFirmware == nil)
    #expect(match.target.minimumOfficialFirmwareVersion?.description == "1.0.14.6")
}

@Test("Air75 V3 firmware payload decodes and compares official versions")
func air75FirmwareVersion() throws {
    let current = try #require(OfficialFirmwareVersion(
        airV3Payload: [0x0E, 0x00, 0x01, 0xAA, 0x06, 0x00, 0xBD, 0xBD]
    ))
    let older = try #require(OfficialFirmwareVersion(
        airV3Payload: [0x0D, 0x00, 0x01, 0xAA, 0x06, 0x00, 0xBD, 0xBD]
    ))

    #expect(current.description == "1.0.14.6")
    #expect(older < current)
    #expect(OfficialFirmwareVersion(airV3Payload: [0x0E, 0x00]) == nil)
}

@Test("V2 setup tests installed firmware before offering DFU")
func v2CompatibilityRoute() {
    #expect(KeyboardSetupRoute.stageAfterCompatibility(.notChecked) == nil)
    #expect(KeyboardSetupRoute.stageAfterCompatibility(.compatible) == .codex)
    #expect(KeyboardSetupRoute.stageAfterCompatibility(.needsFirmware) == .confirmation)
}

@Test("the supported model whitelist pins exact USB identities and light zones")
func supportedModelWhitelist() throws {
    #expect(SupportedNuPhyFirmware.models.map(\.productID) == [0x3255, 0x3246, 0x3266, 0x32F5])
    #expect(SupportedNuPhyFirmware.model(identifier: "halo75-v2-ansi")?.lightZone == .halolight)
    try SupportedNuPhyFirmware.validate(setupManifest)
}

@Test("the bundled catalog contains four valid model-specific firmware images")
func bundledFirmwareCatalog() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let firmwareDirectory = repositoryRoot
        .appending(path: "Sources/AgentLightApp/Resources/Firmware", directoryHint: .isDirectory)
    let data = try Data(contentsOf: firmwareDirectory.appending(path: "manifest.json"))
    let catalog = try JSONDecoder().decode(BundledFirmwareCatalogManifest.self, from: data)

    #expect(catalog.schemaVersion == 2)
    #expect(catalog.firmwares.map(\.modelIdentifier) == [
        "air60-v2-ansi",
        "air75-v2-ansi",
        "air96-v2-ansi",
        "halo75-v2-ansi",
    ])
    for manifest in catalog.firmwares {
        let firmware = BundledFirmware(
            manifest: manifest,
            firmwareURL: firmwareDirectory.appending(path: manifest.firmwareFile),
            dfuUtilURL: URL(fileURLWithPath: "/usr/bin/true")
        )
        try firmware.validate()
    }
}

@Test("unverified hardware cannot be presented as verified firmware")
func unverifiedFirmwareStatusIsRejected() {
    let air75 = BundledFirmwareManifest(
        identifier: "nuphy-air75-v2-ansi-nunubar-1",
        modelIdentifier: "air75-v2-ansi",
        displayName: "NuPhy Air75 V2 ANSI",
        layout: "ANSI",
        firmwareVersion: "1",
        protocolVersion: 3,
        releaseStatus: .verified,
        lightZone: .dualSideBars,
        keyboardVendorID: 0x19F5,
        keyboardProductID: 0x3246,
        dfuVendorID: 0x0483,
        dfuProductID: 0xDF11,
        alternateInterface: 0,
        flashAddress: "0x08000000",
        firmwareFile: "air75.bin",
        firmwareSize: 1,
        firmwareSHA256: String(repeating: "a", count: 64)
    )

    #expect(throws: FirmwareSetupError.invalidManifest) {
        try SupportedNuPhyFirmware.validate(air75)
    }
}

@Test("firmware setup keeps every human confirmation gate")
func setupConfirmationGates() {
    #expect(KeyboardSetupGate.canConfirmKeyboard(
        deviceDetected: true,
        hidAccessGranted: true
    ))
    #expect(!KeyboardSetupGate.canConfirmKeyboard(
        deviceDetected: true,
        hidAccessGranted: false
    ))
    #expect(KeyboardSetupGate.canEnterDFU(
        modelConfirmed: true,
        viaBackedUp: true,
        recoveryFirmwareReady: true
    ))
    #expect(!KeyboardSetupGate.canEnterDFU(
        modelConfirmed: true,
        viaBackedUp: false,
        recoveryFirmwareReady: true
    ))
    #expect(!KeyboardSetupGate.canEnterDFU(
        modelConfirmed: true,
        viaBackedUp: true,
        recoveryFirmwareReady: true,
        requiresTestingConfirmation: true,
        testingFirmwareConfirmed: false
    ))
    #expect(KeyboardSetupGate.canEnterDFU(
        modelConfirmed: true,
        viaBackedUp: true,
        recoveryFirmwareReady: true,
        requiresTestingConfirmation: true,
        testingFirmwareConfirmed: true
    ))
}

@Test("setup launch policy distinguishes fresh installs from upgrades")
func setupLaunchPolicy() {
    #expect(KeyboardSetupLaunchPolicy.decision(
        completed: false,
        seen: false,
        legacyFirstRun: false
    ) == .present)
    #expect(KeyboardSetupLaunchPolicy.decision(
        completed: false,
        seen: false,
        legacyFirstRun: true
    ) == .migrateLegacyUser)
    #expect(KeyboardSetupLaunchPolicy.decision(
        completed: false,
        seen: true,
        legacyFirstRun: true
    ) == .present)
    #expect(KeyboardSetupLaunchPolicy.decision(
        completed: true,
        seen: true,
        legacyFirstRun: true
    ) == .skip)
}
