import CryptoKit
import Foundation
import IOKit

enum FirmwareReleaseStatus: String, Codable, Equatable, Sendable {
    case verified
    case testing
}

enum FirmwareLightZone: String, Codable, Equatable, Sendable {
    case dualSideBars
    case halolight
}

struct BundledFirmwareManifest: Codable, Equatable, Sendable {
    let identifier: String
    let modelIdentifier: String
    let displayName: String
    let layout: String
    let firmwareVersion: String
    let protocolVersion: Int
    let releaseStatus: FirmwareReleaseStatus
    let lightZone: FirmwareLightZone
    let keyboardVendorID: Int
    let keyboardProductID: Int
    let dfuVendorID: Int
    let dfuProductID: Int
    let alternateInterface: Int
    let flashAddress: String
    let firmwareFile: String
    let firmwareSize: Int
    let firmwareSHA256: String

    var dfuDeviceID: String {
        String(format: "%04x:%04x", dfuVendorID, dfuProductID)
    }
}

struct BundledFirmwareCatalogManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let firmwares: [BundledFirmwareManifest]
}

struct BundledFirmware: Sendable {
    let manifest: BundledFirmwareManifest
    let firmwareURL: URL
    let dfuUtilURL: URL

    func validate() throws {
        try SupportedNuPhyFirmware.validate(manifest)

        guard FileManager.default.isExecutableFile(atPath: dfuUtilURL.path) else {
            throw FirmwareSetupError.missingResource("dfu-util")
        }
        guard let data = try? Data(contentsOf: firmwareURL), data.count == manifest.firmwareSize else {
            throw FirmwareSetupError.invalidFirmware
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == manifest.firmwareSHA256.lowercased() else {
            throw FirmwareSetupError.invalidFirmware
        }
    }
}

struct BundledFirmwareCatalog: Sendable {
    let firmwares: [BundledFirmware]

    static func load(from bundle: Bundle = .main) throws -> BundledFirmwareCatalog {
        guard let resourceURL = bundle.resourceURL else {
            throw FirmwareSetupError.missingResource("Resources")
        }
        let firmwareDirectory = resourceURL.appending(path: "Firmware", directoryHint: .isDirectory)
        let manifestURL = firmwareDirectory.appending(path: "manifest.json")
        guard let manifestData = try? Data(contentsOf: manifestURL),
              let catalogManifest = try? JSONDecoder().decode(BundledFirmwareCatalogManifest.self, from: manifestData)
        else {
            throw FirmwareSetupError.invalidManifest
        }

        guard catalogManifest.schemaVersion == 2,
              !catalogManifest.firmwares.isEmpty,
              Set(catalogManifest.firmwares.map(\.identifier)).count == catalogManifest.firmwares.count,
              Set(catalogManifest.firmwares.map(\.modelIdentifier)).count == catalogManifest.firmwares.count,
              Set(catalogManifest.firmwares.map(\.keyboardProductID)).count == catalogManifest.firmwares.count,
              Set(catalogManifest.firmwares.map(\.firmwareFile)).count == catalogManifest.firmwares.count
        else {
            throw FirmwareSetupError.invalidManifest
        }

        let dfuUtilURL = bundle.bundleURL.appending(path: "Contents/Helpers/dfu-util")
        let firmwares = catalogManifest.firmwares.map { manifest in
            BundledFirmware(
                manifest: manifest,
                firmwareURL: firmwareDirectory.appending(path: manifest.firmwareFile),
                dfuUtilURL: dfuUtilURL
            )
        }
        for firmware in firmwares {
            try firmware.validate()
        }
        return BundledFirmwareCatalog(firmwares: firmwares)
    }

    func firmware(modelIdentifier: String) -> BundledFirmware? {
        firmwares.first { $0.manifest.modelIdentifier == modelIdentifier }
    }
}

enum SupportedNuPhyFirmware {
    struct Model: Equatable, Sendable {
        let identifier: String
        let displayName: String
        let productID: Int
        let lightZone: FirmwareLightZone
        let hardwareVerified: Bool
    }

    static let vendorID = 0x19F5
    static let models = [
        Model(identifier: "air60-v2-ansi", displayName: "NuPhy Air60 V2 ANSI", productID: 0x3255, lightZone: .dualSideBars, hardwareVerified: false),
        Model(identifier: "air75-v2-ansi", displayName: "NuPhy Air75 V2 ANSI", productID: 0x3246, lightZone: .dualSideBars, hardwareVerified: false),
        Model(identifier: "air96-v2-ansi", displayName: "NuPhy Air96 V2 ANSI", productID: 0x3266, lightZone: .dualSideBars, hardwareVerified: true),
        Model(identifier: "halo75-v2-ansi", displayName: "NuPhy Halo75 V2 ANSI", productID: 0x32F5, lightZone: .halolight, hardwareVerified: false),
    ]

    static func model(identifier: String) -> Model? {
        models.first { $0.identifier == identifier }
    }

    static func validate(_ manifest: BundledFirmwareManifest) throws {
        guard let model = model(identifier: manifest.modelIdentifier),
              manifest.identifier.hasPrefix("nuphy-\(model.identifier)-nunubar-"),
              manifest.displayName == model.displayName,
              manifest.layout == "ANSI",
              !manifest.firmwareVersion.isEmpty,
              manifest.protocolVersion == 3,
              manifest.lightZone == model.lightZone,
              manifest.keyboardVendorID == vendorID,
              manifest.keyboardProductID == model.productID,
              manifest.dfuVendorID == 0x0483,
              manifest.dfuProductID == 0xDF11,
              manifest.alternateInterface == 0,
              manifest.flashAddress == "0x08000000",
              manifest.firmwareSize > 0,
              manifest.firmwareSHA256.range(of: #"^[0-9a-fA-F]{64}$"#, options: .regularExpression) != nil,
              URL(fileURLWithPath: manifest.firmwareFile).lastPathComponent == manifest.firmwareFile,
              !manifest.firmwareFile.isEmpty,
              model.hardwareVerified || manifest.releaseStatus == .testing
        else {
            throw FirmwareSetupError.invalidManifest
        }
    }
}

struct DFUTarget: Equatable, Sendable {
    let vendorID: Int
    let productID: Int
    let path: String
    let alternateInterface: Int
    let name: String
}

struct USBDeviceIdentity: Equatable, Sendable {
    let vendorID: Int
    let productID: Int
    let productName: String
}

struct OfficialKeyboardProfile: Equatable, Sendable {
    let modelIdentifier: String
    let displayName: String
    let vendorID: Int
    let productID: Int
    let productName: String
    let minimumFirmwareVersion: OfficialFirmwareVersion?
}

struct OfficialFirmwareVersion: Equatable, Comparable, CustomStringConvertible, Sendable {
    let major: Int
    let minor: Int
    let patch: Int
    let build: Int

    var description: String {
        "\(major).\(minor).\(patch).\(build)"
    }

    init(major: Int, minor: Int, patch: Int, build: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.build = build
    }

    init?(airV3Payload: [UInt8]) {
        guard airV3Payload.count >= 5, airV3Payload[3] == 0xAA else { return nil }
        self.init(
            major: Int(airV3Payload[2]),
            minor: Int(airV3Payload[1]),
            patch: Int(airV3Payload[0]),
            build: Int(airV3Payload[4])
        )
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch, lhs.build)
            < (rhs.major, rhs.minor, rhs.patch, rhs.build)
    }
}

enum SupportedOfficialNuPhyKeyboard {
    static let models = [
        OfficialKeyboardProfile(
            modelIdentifier: "air65-v3",
            displayName: "NuPhy Air65 V3",
            vendorID: 0x19F5,
            productID: 0x102B,
            productName: "Air65 V3",
            minimumFirmwareVersion: nil
        ),
        OfficialKeyboardProfile(
            modelIdentifier: "air75-v3",
            displayName: "NuPhy Air75 V3",
            vendorID: 0x19F5,
            productID: 0x1028,
            productName: "Air75 V3",
            minimumFirmwareVersion: OfficialFirmwareVersion(
                major: 1,
                minor: 0,
                patch: 14,
                build: 6
            )
        ),
    ]

    static func profile(matching device: USBDeviceIdentity) -> OfficialKeyboardProfile? {
        models.first {
            device.vendorID == $0.vendorID
                && device.productID == $0.productID
                && device.productName.caseInsensitiveCompare($0.productName) == .orderedSame
        }
    }
}

enum KeyboardSetupTarget: Sendable {
    case bundledFirmware(BundledFirmware)
    case officialFirmware(OfficialKeyboardProfile)

    var modelIdentifier: String {
        switch self {
        case .bundledFirmware(let firmware): firmware.manifest.modelIdentifier
        case .officialFirmware(let profile): profile.modelIdentifier
        }
    }

    var displayName: String {
        switch self {
        case .bundledFirmware(let firmware): firmware.manifest.displayName
        case .officialFirmware(let profile): profile.displayName
        }
    }

    var bundledFirmware: BundledFirmware? {
        guard case .bundledFirmware(let firmware) = self else { return nil }
        return firmware
    }

    var usesOfficialFirmware: Bool {
        if case .officialFirmware = self { return true }
        return false
    }

    var minimumOfficialFirmwareVersion: OfficialFirmwareVersion? {
        guard case .officialFirmware(let profile) = self else { return nil }
        return profile.minimumFirmwareVersion
    }
}

struct USBKeyboardSetupMatch: Sendable {
    let device: USBDeviceIdentity
    let target: KeyboardSetupTarget
}

enum USBKeyboardDetector {
    static func targetDevice(for manifest: BundledFirmwareManifest) -> USBDeviceIdentity? {
        connectedDevices().first { matches($0, manifest: manifest) }
    }

    static func matches(
        _ device: USBDeviceIdentity,
        manifest: BundledFirmwareManifest
    ) -> Bool {
        device.vendorID == manifest.keyboardVendorID
            && device.productID == manifest.keyboardProductID
    }

    static func matchingDevices(
        _ devices: [USBDeviceIdentity] = connectedDevices(),
        in catalog: BundledFirmwareCatalog
    ) -> [(device: USBDeviceIdentity, firmware: BundledFirmware)] {
        devices.compactMap { device in
            catalog.firmwares.first { matches(device, manifest: $0.manifest) }.map {
                (device: device, firmware: $0)
            }
        }
    }

    static func matchingSetupDevices(
        _ devices: [USBDeviceIdentity] = connectedDevices(),
        in catalog: BundledFirmwareCatalog?
    ) -> [USBKeyboardSetupMatch] {
        devices.compactMap { device in
            if let profile = SupportedOfficialNuPhyKeyboard.profile(matching: device) {
                return USBKeyboardSetupMatch(
                    device: device,
                    target: .officialFirmware(profile)
                )
            }
            guard let firmware = catalog?.firmwares.first(where: {
                matches(device, manifest: $0.manifest)
            }) else { return nil }
            return USBKeyboardSetupMatch(
                device: device,
                target: .bundledFirmware(firmware)
            )
        }
    }

    static func connectedDevices() -> [USBDeviceIdentity] {
        guard let matching = IOServiceMatching("IOUSBHostDevice") else { return [] }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var devices: [USBDeviceIdentity] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let vendorID = integerProperty("idVendor", service: service),
                  let productID = integerProperty("idProduct", service: service)
            else { continue }

            let productName = stringProperty("USB Product Name", service: service)
                ?? stringProperty("kUSBProductString", service: service)
                ?? "USB Keyboard"
            devices.append(USBDeviceIdentity(
                vendorID: vendorID,
                productID: productID,
                productName: productName
            ))
        }
        return devices
    }

    private static func integerProperty(_ key: String, service: io_service_t) -> Int? {
        guard let value = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber else { return nil }
        return value.intValue
    }

    private static func stringProperty(_ key: String, service: io_service_t) -> String? {
        IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String
    }
}

enum DFUListParser {
    private static let expression = try! NSRegularExpression(
        pattern: #"Found DFU: \[([0-9a-fA-F]{4}):([0-9a-fA-F]{4})\].*path=\"([^\"]+)\".*alt=([0-9]+), name=\"([^\"]+)\""#
    )

    static func parse(_ output: String) -> [DFUTarget] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let string = String(line)
            let range = NSRange(string.startIndex..<string.endIndex, in: string)
            guard let match = expression.firstMatch(in: string, range: range),
                  let vendorRange = Range(match.range(at: 1), in: string),
                  let productRange = Range(match.range(at: 2), in: string),
                  let pathRange = Range(match.range(at: 3), in: string),
                  let alternateRange = Range(match.range(at: 4), in: string),
                  let nameRange = Range(match.range(at: 5), in: string),
                  let vendorID = Int(string[vendorRange], radix: 16),
                  let productID = Int(string[productRange], radix: 16),
                  let alternateInterface = Int(string[alternateRange])
            else { return nil }

            return DFUTarget(
                vendorID: vendorID,
                productID: productID,
                path: String(string[pathRange]),
                alternateInterface: alternateInterface,
                name: String(string[nameRange])
            )
        }
    }
}

enum FirmwareFlashCommand {
    static func arguments(manifest: BundledFirmwareManifest, path: String, firmwareURL: URL) -> [String] {
        [
            "-d", manifest.dfuDeviceID,
            "-p", path,
            "-a", String(manifest.alternateInterface),
            "-s", "\(manifest.flashAddress):leave",
            "-D", firmwareURL.path,
        ]
    }

    static func completedSuccessfully(exitCode: Int32, output: String) -> Bool {
        exitCode == 0
            && output.contains("File downloaded successfully")
            && output.contains("Submitting leave request")
    }
}

struct FirmwareProcessResult: Sendable {
    let exitCode: Int32
    let output: String
}

struct FirmwareProcessRunner: Sendable {
    func run(executable: URL, arguments: [String]) async throws -> FirmwareProcessResult {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let standardOutput = Pipe()
            let standardError = Pipe()
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = standardOutput
            process.standardError = standardError
            var environment = ProcessInfo.processInfo.environment
            environment["LC_ALL"] = "C"
            environment["LANG"] = "C"
            environment["LC_CTYPE"] = "C"
            process.environment = environment

            do {
                try process.run()
            } catch {
                throw FirmwareSetupError.couldNotLaunchTool
            }
            process.waitUntilExit()

            let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
            let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: outputData + errorData, as: UTF8.self)
            return FirmwareProcessResult(exitCode: process.terminationStatus, output: output)
        }.value
    }
}

struct FirmwareSetupService: Sendable {
    let firmware: BundledFirmware
    private let runner = FirmwareProcessRunner()

    init(firmware: BundledFirmware) {
        self.firmware = firmware
    }

    func detectDFUTarget() async throws -> DFUTarget {
        try firmware.validate()
        let result = try await runner.run(executable: firmware.dfuUtilURL, arguments: ["-l"])
        guard result.exitCode == 0 else {
            throw FirmwareSetupError.scanFailed
        }
        return try Self.validatedTarget(
            from: DFUListParser.parse(result.output),
            manifest: firmware.manifest
        )
    }

    func flash() async throws -> String {
        try firmware.validate()
        let target = try await detectDFUTarget()
        let arguments = FirmwareFlashCommand.arguments(
            manifest: firmware.manifest,
            path: target.path,
            firmwareURL: firmware.firmwareURL
        )
        let result = try await runner.run(executable: firmware.dfuUtilURL, arguments: arguments)
        guard FirmwareFlashCommand.completedSuccessfully(
            exitCode: result.exitCode,
            output: result.output
        ) else {
            throw FirmwareSetupError.flashFailed
        }
        return result.output
    }

    static func validatedTarget(
        from targets: [DFUTarget],
        manifest: BundledFirmwareManifest
    ) throws -> DFUTarget {
        let matching = targets.filter {
            $0.vendorID == manifest.dfuVendorID
                && $0.productID == manifest.dfuProductID
        }
        let paths = Set(matching.map(\.path))
        guard !paths.isEmpty else { throw FirmwareSetupError.dfuNotFound }
        guard paths.count == 1, let path = paths.first else {
            throw FirmwareSetupError.multipleDFUDevices
        }
        guard matching.contains(where: {
            $0.path == path
                && $0.alternateInterface == 1
                && $0.name.contains("@Option Bytes")
        }), let internalFlash = matching.first(where: {
            $0.path == path
                && $0.alternateInterface == manifest.alternateInterface
                && $0.name.contains("@Internal Flash")
                && $0.name.contains(manifest.flashAddress)
        }) else {
            throw FirmwareSetupError.unexpectedDFULayout
        }
        return internalFlash
    }
}

enum FirmwareSetupError: LocalizedError, Equatable {
    case missingResource(String)
    case invalidManifest
    case invalidFirmware
    case couldNotLaunchTool
    case scanFailed
    case dfuNotFound
    case multipleDFUDevices
    case unexpectedDFULayout
    case flashFailed
    case keyboardDidNotReconnect

    var errorDescription: String? {
        switch self {
        case .missingResource(let name): "安装包缺少 \(name)"
        case .invalidManifest: "固件清单无效，已停止刷写"
        case .invalidFirmware: "固件校验失败，已停止刷写"
        case .couldNotLaunchTool: "无法启动内置刷写工具"
        case .scanFailed: "无法扫描 DFU 设备"
        case .dfuNotFound: "尚未检测到键盘 DFU 模式"
        case .multipleDFUDevices: "检测到多个 STM32 DFU 设备，请只连接目标键盘"
        case .unexpectedDFULayout: "DFU 内存布局与目标键盘不匹配，已停止刷写"
        case .flashFailed: "固件写入未完整成功，请不要拔线并重新检测"
        case .keyboardDidNotReconnect: "固件已写入，但键盘未在预期时间内重新连接"
        }
    }
}
