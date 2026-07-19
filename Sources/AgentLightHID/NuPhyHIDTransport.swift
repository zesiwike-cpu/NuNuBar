import AgentLightCore
import CoreGraphics
import Foundation
import IOKit.hid
import IOKit.hidsystem

public enum NuPhyHIDAccessState: Equatable, Sendable {
    case granted
    case denied
    case unknown
}

public enum NuPhyHIDConnectionTransport: String, Equatable, Sendable {
    case bluetoothLowEnergy = "Bluetooth Low Energy"
    case usb = "USB"

    fileprivate var selectionPriority: Int {
        switch self {
        case .usb: return 0
        case .bluetoothLowEnergy: return 1
        }
    }
}

enum NuPhyHIDDeviceProtocol: Equatable, Sendable {
    case bluetoothStatusLED
    case nbarRawHID
    case air65V3Official

    var transport: NuPhyHIDConnectionTransport {
        switch self {
        case .bluetoothStatusLED: .bluetoothLowEnergy
        case .nbarRawHID, .air65V3Official: .usb
        }
    }
}

public enum NuPhyHIDError: LocalizedError, CustomStringConvertible, Equatable, Sendable {
    case permissionDenied
    case managerOpenFailed(IOReturn)
    case deviceNotConnected
    case reportFailed(IOReturn)
    case protocolFailed(String)

    public var description: String {
        switch self {
        case .permissionDenied: return "keyboard HID access has not been granted"
        case .managerOpenFailed(let status): return "could not open the HID manager (\(hex(status)))"
        case .deviceNotConnected: return "no compatible NuPhy keyboard is connected"
        case .reportFailed(let status): return "sending a keyboard report failed (\(hex(status)))"
        case .protocolFailed(let reason): return "keyboard protocol failed (\(reason))"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .permissionDenied: return "需要允许 NuNuBar 访问键盘 HID 接口"
        case .managerOpenFailed: return "无法访问 macOS HID 设备管理器"
        case .deviceNotConnected: return "未找到已连接的 NuNuBar 兼容 NuPhy 键盘"
        case .reportFailed: return "无法向 NuPhy 键盘发送灯光状态"
        case .protocolFailed: return "无法建立 Air65 V3 灯光控制连接"
        }
    }

    private func hex(_ status: IOReturn) -> String {
        "0x" + String(UInt32(bitPattern: status), radix: 16)
    }
}

public enum NuPhyHIDDeliveryState: Equatable, Sendable {
    case ready
    case rebuilding
    case recovering(NuPhyHIDError)
}

public enum NuPhyHIDConnectionState: Equatable, Sendable {
    case disconnected
    case connected(
        productName: String,
        transport: NuPhyHIDConnectionTransport,
        delivery: NuPhyHIDDeliveryState
    )
    case unavailable(NuPhyHIDError)
}

public struct NuPhyHIDDiagnostics: Equatable, Sendable {
    public let acknowledgedAir65Reports: Int
    public let air65ReportTimeouts: Int
    public let air65SessionRecoveries: Int
    public let air65CurrentMode: UInt8?

    public init(
        acknowledgedAir65Reports: Int,
        air65ReportTimeouts: Int,
        air65SessionRecoveries: Int,
        air65CurrentMode: UInt8?
    ) {
        self.acknowledgedAir65Reports = acknowledgedAir65Reports
        self.air65ReportTimeouts = air65ReportTimeouts
        self.air65SessionRecoveries = air65SessionRecoveries
        self.air65CurrentMode = air65CurrentMode
    }
}

public final class NuPhyHIDTransport: @unchecked Sendable {
    static let nuphyVendorID = 0x19F5
    static let air65V3ProductID = 0x102B
    static let supportedUSBProductIDs: Set<Int> = [
        0x3255, // Air60 V2 ANSI
        0x3246, // Air75 V2 ANSI
        0x3266, // Air96 V2 ANSI
        0x32F5, // Halo75 V2 ANSI
    ]
    static let rawHIDUsagePage = 0xFF60
    static let rawHIDUsage = 0x61
    static let air65V3UsagePage = 0x0001
    static let air65V3Usage = 0x0000

    static var deviceMatchingProperties: [[String: Any]] {
        let bluetoothMatcher: [String: Any] =
            [
                kIOHIDTransportKey as String: NuPhyHIDConnectionTransport.bluetoothLowEnergy.rawValue,
                kIOHIDDeviceUsagePageKey as String: 1,
                kIOHIDDeviceUsageKey as String: 6,
            ]
        let usbMatchers = supportedUSBProductIDs.sorted().map { productID in
            [
                kIOHIDTransportKey as String: NuPhyHIDConnectionTransport.usb.rawValue,
                kIOHIDVendorIDKey as String: nuphyVendorID,
                kIOHIDProductIDKey as String: productID,
                kIOHIDDeviceUsagePageKey as String: rawHIDUsagePage,
                kIOHIDDeviceUsageKey as String: rawHIDUsage,
            ]
        }
        let air65V3Matcher: [String: Any] = [
            kIOHIDTransportKey as String: NuPhyHIDConnectionTransport.usb.rawValue,
            kIOHIDVendorIDKey as String: nuphyVendorID,
            kIOHIDProductIDKey as String: air65V3ProductID,
            kIOHIDDeviceUsagePageKey as String: air65V3UsagePage,
            kIOHIDDeviceUsageKey as String: air65V3Usage,
            kIOHIDMaxInputReportSizeKey as String: Air65V3ProtocolEncoder.reportSize,
            kIOHIDMaxOutputReportSizeKey as String: Air65V3ProtocolEncoder.reportSize,
        ]
        return [bluetoothMatcher] + usbMatchers + [air65V3Matcher]
    }

    public let connectionStates: AsyncStream<NuPhyHIDConnectionState>

    private let preparesAir65Session: Bool
    private let queue = DispatchQueue(label: "com.maige.NuphyBar.HID")
    private let queueIdentity = DispatchSpecificKey<UInt8>()
    private let stateContinuation: AsyncStream<NuPhyHIDConnectionState>.Continuation
    private var manager: IOHIDManager?
    private var activeSessionID: UUID?
    private var cancellingSessionID: UUID?
    private var currentDevice: IOHIDDevice?
    private var currentConnectionTransport: NuPhyHIDConnectionTransport?
    private var currentDeviceProtocol: NuPhyHIDDeviceProtocol?
    private var recoveryDevice: RecoveryDevice?
    private var currentState: NuPhyHIDConnectionState?
    private var reconnectBackoff = HIDReconnectBackoff()
    private var restartWorkItem: DispatchWorkItem?
    private var pendingRestartDelay: TimeInterval?
    private var isStopped = false
    private var managerContext: ManagerCallbackContext?
    private var air65Challenge: [UInt8]?
    private var air65SessionKey: UInt8?
    private var air65CurrentMode: UInt8?
    private var air65HandshakeContinuation: CheckedContinuation<Void, Error>?
    private var air65HandshakeTimeout: DispatchWorkItem?
    private var air65BaseTimeout: DispatchWorkItem?
    private var air65Transaction: Air65ReportTransaction?
    private var queuedAir65Transactions: [Air65ReportTransaction] = []
    private var air65BlinkGeneration: UUID?
    private var air65BlinkWorkItem: DispatchWorkItem?
    private var acknowledgedAir65Reports = 0
    private var air65ReportTimeouts = 0
    private var air65SessionRecoveries = 0

    public init(preparesAir65Session: Bool = true) {
        self.preparesAir65Session = preparesAir65Session
        let stream = AsyncStream<NuPhyHIDConnectionState>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        connectionStates = stream.stream
        stateContinuation = stream.continuation
        queue.setSpecific(key: queueIdentity, value: 1)
        queue.sync { startManager() }
    }

    deinit {
        stateContinuation.finish()
        let cleanup = { [self] in
            self.isStopped = true
            self.restartWorkItem?.cancel()
            self.restartWorkItem = nil
            self.pendingRestartDelay = nil
            self.cancelManager()
        }
        if DispatchQueue.getSpecific(key: self.queueIdentity) != nil {
            cleanup()
        } else {
            self.queue.sync(execute: cleanup)
        }
    }

    public static var accessState: NuPhyHIDAccessState {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied: return .denied
        default: return .unknown
        }
    }

    @discardableResult
    public static func requestAccess() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static func isCompatible(
        productName: String?,
        transport: String?,
        vendorID: Int?,
        productID: Int?,
        usagePage: Int?,
        usage: Int?,
        maxOutputReportSize: Int?,
        maxInputReportSize: Int? = nil
    ) -> Bool {
        connectionTransport(
            productName: productName,
            transport: transport,
            vendorID: vendorID,
            productID: productID,
            usagePage: usagePage,
            usage: usage,
            maxOutputReportSize: maxOutputReportSize,
            maxInputReportSize: maxInputReportSize
        ) != nil
    }

    static func connectionTransport(
        productName: String?,
        transport: String?,
        vendorID: Int?,
        productID: Int?,
        usagePage: Int?,
        usage: Int?,
        maxOutputReportSize: Int?,
        maxInputReportSize: Int? = nil
    ) -> NuPhyHIDConnectionTransport? {
        deviceProtocol(
            productName: productName,
            transport: transport,
            vendorID: vendorID,
            productID: productID,
            usagePage: usagePage,
            usage: usage,
            maxOutputReportSize: maxOutputReportSize,
            maxInputReportSize: maxInputReportSize
        )?.transport
    }

    static func deviceProtocol(
        productName: String?,
        transport: String?,
        vendorID: Int?,
        productID: Int?,
        usagePage: Int?,
        usage: Int?,
        maxOutputReportSize: Int?,
        maxInputReportSize: Int? = nil
    ) -> NuPhyHIDDeviceProtocol? {
        guard let productName, let maxOutputReportSize else { return nil }

        if transport == NuPhyHIDConnectionTransport.usb.rawValue,
           productName.caseInsensitiveCompare("Air65 V3") == .orderedSame,
           vendorID == nuphyVendorID,
           productID == air65V3ProductID,
           usagePage == air65V3UsagePage,
           usage == air65V3Usage,
           maxInputReportSize == Air65V3ProtocolEncoder.reportSize,
           maxOutputReportSize == Air65V3ProtocolEncoder.reportSize {
            return .air65V3Official
        }

        guard productName.range(
            of: "NuPhy",
            options: [.anchored, .caseInsensitive]
        ) != nil else { return nil }

        if transport == NuPhyHIDConnectionTransport.bluetoothLowEnergy.rawValue,
           usagePage == 1,
           usage == 6,
           maxOutputReportSize >= 2 {
            return .bluetoothStatusLED
        }

        if transport == NuPhyHIDConnectionTransport.usb.rawValue,
           vendorID == nuphyVendorID,
           productID.map(supportedUSBProductIDs.contains) == true,
           usagePage == rawHIDUsagePage,
           usage == rawHIDUsage,
           maxOutputReportSize >= USBStatusReportEncoder.reportSize {
            return .nbarRawHID
        }

        return nil
    }

    public func refresh() {
        queue.async { [weak self] in
            self?.refreshManager()
        }
    }

    public func rebuildSession() {
        queue.async { [weak self] in
            self?.rebuildManagerSession()
        }
    }

    public func describe() throws -> String {
        try queue.sync {
            guard let device = currentDevice,
                  let connectionTransport = currentConnectionTransport,
                  let deviceProtocol = currentDeviceProtocol else {
                throw NuPhyHIDError.deviceNotConnected
            }
            let name = productName(of: device) ?? "NuPhy keyboard"
            let maxOutput = maxOutputReportSize(of: device)
            let outputReport = switch deviceProtocol {
            case .bluetoothStatusLED: "1 (keyboard LED)"
            case .nbarRawHID: "0 (NuNuBar Raw HID)"
            case .air65V3Official: "0 (Air65 V3 official control HID)"
            }
            return [
                "Device: \(name)",
                "Transport: \(connectionTransport.rawValue)",
                "Output report: \(outputReport)",
                "Max output report size: \(maxOutput.map(String.init) ?? "unknown") bytes",
                deviceProtocol == .air65V3Official
                    ? "Air65 V3 mode: \(air65CurrentMode.map(String.init) ?? (preparesAir65Session ? "negotiating" : "not queried"))"
                    : nil,
            ].compactMap { $0 }.joined(separator: "\n")
        }
    }

    public func diagnostics() -> NuPhyHIDDiagnostics {
        queue.sync {
            NuPhyHIDDiagnostics(
                acknowledgedAir65Reports: acknowledgedAir65Reports,
                air65ReportTimeouts: air65ReportTimeouts,
                air65SessionRecoveries: air65SessionRecoveries,
                air65CurrentMode: air65CurrentMode
            )
        }
    }

    public func send(
        _ command: AgentLightCommand,
        palette: AgentLightPalette = .default
    ) async throws {
        try await AgentLightTransmissionLock().withAsyncLock {
            let capsLockOn = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
            let mask = DirectStatusEncoder.encode(command, capsLockOn: capsLockOn)

            let requiresAir65Transaction = try queue.sync {
                guard Self.accessState == .granted else {
                    refreshManager()
                    throw NuPhyHIDError.permissionDenied
                }
                guard let currentDevice,
                      let currentConnectionTransport,
                      let currentDeviceProtocol else {
                    throw NuPhyHIDError.deviceNotConnected
                }

                cancelAir65Blink()
                if currentDeviceProtocol == .air65V3Official {
                    return true
                }

                do {
                    switch currentDeviceProtocol {
                    case .bluetoothStatusLED:
                        try setBluetoothOutputReport(mask, on: currentDevice)
                    case .nbarRawHID:
                        try setUSBOutputReport(command, palette: palette, on: currentDevice)
                    case .air65V3Official:
                        preconditionFailure("Air65 V3 reports use the acknowledged transaction path")
                    }
                    reconnectBackoff.reset()
                    return false
                } catch let error as NuPhyHIDError {
                    recoverFromReportFailure(
                        error,
                        productName: productName(of: currentDevice),
                        transport: currentConnectionTransport
                    )
                    throw error
                }
            }

            guard requiresAir65Transaction else { return }
            let shouldBlink = palette.effect(for: command) == .blink
            try await negotiateAir65V3Session()
            try await performAir65V3Transaction(
                command,
                palette: palette,
                brightness: 24,
                effectOverride: shouldBlink ? .solid : nil
            )
            if shouldBlink {
                queue.async { [weak self] in
                    self?.startAir65Blink(command: command, palette: palette)
                }
            }
        }
    }

    private func startManager() {
        guard !isStopped, manager == nil, cancellingSessionID == nil else { return }
        guard Self.accessState == .granted else {
            publish(.unavailable(.permissionDenied))
            return
        }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(
            manager,
            Self.deviceMatchingProperties as CFArray
        )
        let status = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard status == kIOReturnSuccess else {
            publish(.unavailable(.managerOpenFailed(status)))
            scheduleManagerStart(after: reconnectBackoff.nextDelay())
            return
        }

        let sessionID = UUID()
        let context = ManagerCallbackContext(owner: self, manager: manager, sessionID: sessionID)
        let contextPointer = Unmanaged.passUnretained(context).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            Self.deviceMatchedCallback,
            contextPointer
        )
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            Self.deviceRemovedCallback,
            contextPointer
        )
        IOHIDManagerRegisterInputReportCallback(
            manager,
            Self.air65InputReportCallback,
            contextPointer
        )
        IOHIDManagerSetDispatchQueue(manager, queue)
        IOHIDManagerSetCancelHandler(manager) { [context] in
            _ = IOHIDManagerClose(context.manager, IOOptionBits(kIOHIDOptionsTypeNone))
            context.owner?.managerDidCancel(sessionID: context.sessionID)
        }

        self.manager = manager
        managerContext = context
        activeSessionID = sessionID
        IOHIDManagerActivate(manager)
        selectConnectedDevice(from: manager, sessionID: sessionID)
    }

    private func refreshManager() {
        guard Self.accessState == .granted else {
            recoveryDevice = nil
            currentDevice = nil
            currentConnectionTransport = nil
            currentDeviceProtocol = nil
            resetAir65Session()
            reconnectBackoff.reset()
            pendingRestartDelay = nil
            restartWorkItem?.cancel()
            restartWorkItem = nil
            cancelManager()
            publish(.unavailable(.permissionDenied))
            return
        }

        reconnectBackoff.reset()
        if cancellingSessionID != nil {
            pendingRestartDelay = 0
        } else if let manager, let activeSessionID {
            selectConnectedDevice(from: manager, sessionID: activeSessionID)
        } else {
            restartWorkItem?.cancel()
            restartWorkItem = nil
            startManager()
        }
    }

    private func rebuildManagerSession() {
        guard !isStopped else { return }
        guard Self.accessState == .granted else {
            refreshManager()
            return
        }

        restartWorkItem?.cancel()
        restartWorkItem = nil
        reconnectBackoff.reset()

        let connectedDevice = currentDevice.flatMap { device -> RecoveryDevice? in
            guard let transport = currentConnectionTransport else { return nil }
            return RecoveryDevice(
                productName: productName(of: device) ?? "NuPhy 键盘",
                transport: transport
            )
        }
        if let device = connectedDevice ?? recoveryDevice {
            currentDevice = nil
            currentConnectionTransport = nil
            currentDeviceProtocol = nil
            resetAir65Session()
            recoveryDevice = device
            publish(.connected(
                productName: device.productName,
                transport: device.transport,
                delivery: .rebuilding
            ))
        }

        if cancellingSessionID != nil {
            pendingRestartDelay = 0
            return
        } else if manager != nil {
            pendingRestartDelay = 0
            cancelManager()
        } else {
            pendingRestartDelay = nil
            startManager()
        }
    }

    private func selectConnectedDevice(from manager: IOHIDManager, sessionID: UUID) {
        guard activeSessionID == sessionID else { return }
        guard let candidate = preferredDevice(from: manager) else {
            currentDevice = nil
            currentConnectionTransport = nil
            currentDeviceProtocol = nil
            resetAir65Session()
            recoveryDevice = nil
            publish(.disconnected)
            return
        }

        if let currentDevice,
           CFEqual(currentDevice, candidate.device),
           currentConnectionTransport == candidate.transport,
           currentDeviceProtocol == candidate.deviceProtocol {
            return
        }

        resetAir65Session()
        let wasRecovering = recoveryDevice != nil
        currentDevice = candidate.device
        currentConnectionTransport = candidate.transport
        currentDeviceProtocol = candidate.deviceProtocol
        recoveryDevice = nil
        if !wasRecovering {
            reconnectBackoff.reset()
        }
        let name = productName(of: candidate.device) ?? "NuPhy 键盘"
        if candidate.deviceProtocol == .air65V3Official,
           preparesAir65Session {
            publish(.connected(
                productName: name,
                transport: candidate.transport,
                delivery: .rebuilding
            ))
            beginAir65V3Session(on: candidate.device, sessionID: sessionID)
        } else {
            publish(.connected(
                productName: name,
                transport: candidate.transport,
                delivery: .ready
            ))
        }
    }

    private func handleMatchedDevice(_: IOHIDDevice, sessionID: UUID) {
        guard activeSessionID == sessionID, let manager else { return }
        selectConnectedDevice(from: manager, sessionID: sessionID)
    }

    private func handleRemovedDevice(_ device: IOHIDDevice, sessionID: UUID) {
        guard activeSessionID == sessionID,
              let currentDevice,
              CFEqual(currentDevice, device) else { return }
        self.currentDevice = nil
        currentConnectionTransport = nil
        currentDeviceProtocol = nil
        resetAir65Session()
        recoveryDevice = nil
        reconnectBackoff.reset()
        guard let manager else {
            publish(.disconnected)
            return
        }
        selectConnectedDevice(from: manager, sessionID: sessionID)
    }

    private func recoverFromReportFailure(
        _ error: NuPhyHIDError,
        productName: String?,
        transport: NuPhyHIDConnectionTransport
    ) {
        if currentDeviceProtocol == .air65V3Official
            || productName?.caseInsensitiveCompare("Air65 V3") == .orderedSame {
            air65SessionRecoveries += 1
        }
        let device = RecoveryDevice(
            productName: productName ?? "NuPhy 键盘",
            transport: transport
        )
        recoveryDevice = device
        currentDevice = nil
        currentConnectionTransport = nil
        currentDeviceProtocol = nil
        resetAir65Session(error: error)
        publish(.connected(
            productName: device.productName,
            transport: device.transport,
            delivery: .recovering(error)
        ))
        pendingRestartDelay = reconnectBackoff.nextDelay()
        cancelManager()
    }

    private func cancelManager() {
        guard let manager, let activeSessionID else { return }
        self.manager = nil
        self.activeSessionID = nil
        cancellingSessionID = activeSessionID
        IOHIDManagerCancel(manager)
    }

    private func managerDidCancel(sessionID: UUID) {
        guard cancellingSessionID == sessionID else { return }
        cancellingSessionID = nil
        if managerContext?.sessionID == sessionID {
            managerContext = nil
        }
        guard let delay = pendingRestartDelay, !isStopped else { return }
        pendingRestartDelay = nil
        scheduleManagerStart(after: delay)
    }

    private func scheduleManagerStart(after delay: TimeInterval) {
        guard !isStopped else { return }
        restartWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.restartWorkItem = nil
            self.startManager()
        }
        restartWorkItem = workItem
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func publish(_ state: NuPhyHIDConnectionState) {
        guard state != currentState else { return }
        currentState = state
        stateContinuation.yield(state)
    }

    private func preferredDevice(from manager: IOHIDManager) -> DeviceCandidate? {
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return nil
        }
        return devices.compactMap { device -> DeviceCandidate? in
            guard let deviceProtocol = deviceProtocol(of: device) else { return nil }
            return DeviceCandidate(
                device: device,
                transport: deviceProtocol.transport,
                deviceProtocol: deviceProtocol
            )
        }.min { lhs, rhs in
            lhs.transport.selectionPriority < rhs.transport.selectionPriority
        }
    }

    private func deviceProtocol(of device: IOHIDDevice) -> NuPhyHIDDeviceProtocol? {
        Self.deviceProtocol(
            productName: productName(of: device),
            transport: transport(of: device),
            vendorID: integerProperty(kIOHIDVendorIDKey, of: device),
            productID: integerProperty(kIOHIDProductIDKey, of: device),
            usagePage: integerProperty(kIOHIDPrimaryUsagePageKey, of: device),
            usage: integerProperty(kIOHIDPrimaryUsageKey, of: device),
            maxOutputReportSize: maxOutputReportSize(of: device),
            maxInputReportSize: maxInputReportSize(of: device)
        )
    }

    private func productName(of device: IOHIDDevice) -> String? {
        IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String
    }

    private func transport(of device: IOHIDDevice) -> String? {
        IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String
    }

    private func maxOutputReportSize(of device: IOHIDDevice) -> Int? {
        integerProperty(kIOHIDMaxOutputReportSizeKey, of: device)
    }

    private func maxInputReportSize(of device: IOHIDDevice) -> Int? {
        integerProperty(kIOHIDMaxInputReportSizeKey, of: device)
    }

    private func integerProperty(_ key: String, of device: IOHIDDevice) -> Int? {
        IOHIDDeviceGetProperty(device, key as CFString)
            .flatMap { $0 as? NSNumber }?.intValue
    }

    private func setBluetoothOutputReport(_ mask: UInt8, on device: IOHIDDevice) throws {
        var report: [UInt8] = [1, mask]
        let reportCount = report.count
        let status = report.withUnsafeMutableBytes { bytes in
            IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeOutput,
                1,
                bytes.bindMemory(to: UInt8.self).baseAddress!,
                reportCount
            )
        }
        guard status == kIOReturnSuccess else {
            throw NuPhyHIDError.reportFailed(status)
        }
    }

    private func setUSBOutputReport(
        _ command: AgentLightCommand,
        palette: AgentLightPalette,
        on device: IOHIDDevice
    ) throws {
        try setUSBOutputReport(
            USBStatusReportEncoder.encodeLegacy(command),
            on: device
        )
        try setUSBOutputReport(
            USBStatusReportEncoder.encodeColorV2(command, palette: palette),
            on: device
        )
        try setUSBOutputReport(
            USBStatusReportEncoder.encode(command, palette: palette),
            on: device
        )
    }

    private func setUSBOutputReport(_ encodedReport: [UInt8], on device: IOHIDDevice) throws {
        try setOutputReport(encodedReport, reportID: USBStatusReportEncoder.reportID, on: device)
    }

    private func performAir65V3Transaction(
        _ command: AgentLightCommand,
        palette: AgentLightPalette,
        brightness: UInt8,
        effectOverride: AgentLightEffect?
    ) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: NuPhyHIDError.deviceNotConnected)
                    return
                }
                self.enqueueAir65V3Transaction(
                    command,
                    palette: palette,
                    brightness: brightness,
                    effectOverride: effectOverride
                ) { result in
                    continuation.resume(with: result.mapError { $0 as Error })
                }
            }
        }
    }

    private func enqueueAir65V3Transaction(
        _ command: AgentLightCommand,
        palette: AgentLightPalette,
        brightness: UInt8,
        effectOverride: AgentLightEffect?,
        completion: @escaping @Sendable (Result<Void, NuPhyHIDError>) -> Void
    ) {
        guard let air65SessionKey,
              let air65CurrentMode,
              currentDeviceProtocol == .air65V3Official,
              currentDevice != nil else {
            completion(.failure(.protocolFailed("Air65 V3 session is not ready")))
            return
        }

        let reports: [[UInt8]]
        do {
            reports = try Air65V3ProtocolEncoder.statusReports(
                command,
                palette: palette,
                sessionKey: air65SessionKey,
                currentMode: air65CurrentMode,
                brightness: brightness,
                effectOverride: effectOverride
            )
        } catch {
            completion(.failure(.protocolFailed(String(describing: error))))
            return
        }

        let transaction = Air65ReportTransaction(
            reports: reports,
            completion: completion
        )
        if air65Transaction == nil {
            air65Transaction = transaction
            sendCurrentAir65Report()
        } else {
            queuedAir65Transactions.append(transaction)
        }
    }

    private func sendCurrentAir65Report() {
        guard let transaction = air65Transaction,
              transaction.reportIndex < transaction.reports.count,
              let currentDevice,
              currentDeviceProtocol == .air65V3Official else {
            failAir65TransactionAndRecover(
                .protocolFailed("Air65 V3 report channel disappeared")
            )
            return
        }

        do {
            try setOutputReport(
                transaction.reports[transaction.reportIndex],
                reportID: 0,
                on: currentDevice
            )
        } catch let error as NuPhyHIDError {
            failAir65TransactionAndRecover(error)
            return
        } catch {
            failAir65TransactionAndRecover(
                .protocolFailed(String(describing: error))
            )
            return
        }

        let transactionID = transaction.id
        let timeout = DispatchWorkItem { [weak self] in
            self?.handleAir65AcknowledgementTimeout(transactionID: transactionID)
        }
        transaction.timeout = timeout
        queue.asyncAfter(deadline: .now() + 0.75, execute: timeout)
    }

    private func handleAir65AcknowledgementTimeout(transactionID: UUID) {
        guard let transaction = air65Transaction,
              transaction.id == transactionID else { return }
        transaction.timeout = nil
        air65ReportTimeouts += 1
        failAir65TransactionAndRecover(
            .protocolFailed(
                "Air65 V3 acknowledgement timed out for report \(transaction.reportIndex + 1)"
            )
        )
    }

    private func completeAir65Transaction(
        _ result: Result<Void, NuPhyHIDError>
    ) {
        guard let transaction = air65Transaction else { return }
        transaction.timeout?.cancel()
        transaction.timeout = nil
        air65Transaction = nil
        transaction.completion(result)

        switch result {
        case .success:
            guard !queuedAir65Transactions.isEmpty else { return }
            air65Transaction = queuedAir65Transactions.removeFirst()
            sendCurrentAir65Report()
        case .failure(let error):
            let queued = queuedAir65Transactions
            queuedAir65Transactions.removeAll()
            for transaction in queued {
                transaction.completion(.failure(error))
            }
        }
    }

    private func failAir65TransactionAndRecover(_ error: NuPhyHIDError) {
        let name = currentDevice.flatMap(productName(of:))
        completeAir65Transaction(.failure(error))
        recoverFromReportFailure(
            error,
            productName: name,
            transport: .usb
        )
    }

    private func startAir65Blink(
        command: AgentLightCommand,
        palette: AgentLightPalette
    ) {
        guard currentDeviceProtocol == .air65V3Official,
              air65SessionKey != nil,
              air65CurrentMode != nil else { return }
        cancelAir65Blink()
        let generation = UUID()
        air65BlinkGeneration = generation
        scheduleAir65BlinkFrame(
            generation: generation,
            command: command,
            palette: palette,
            isOn: false
        )
    }

    private func scheduleAir65BlinkFrame(
        generation: UUID,
        command: AgentLightCommand,
        palette: AgentLightPalette,
        isOn: Bool
    ) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.air65BlinkGeneration == generation else { return }
            self.air65BlinkWorkItem = nil
            Task { [weak self] in
                await self?.sendAir65BlinkFrame(
                    generation: generation,
                    command: command,
                    palette: palette,
                    isOn: isOn
                )
            }
        }
        air65BlinkWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func sendAir65BlinkFrame(
        generation: UUID,
        command: AgentLightCommand,
        palette: AgentLightPalette,
        isOn: Bool
    ) async {
        do {
            try await AgentLightTransmissionLock().withAsyncLock {
                let isActive = queue.sync {
                    air65BlinkGeneration == generation
                        && currentDeviceProtocol == .air65V3Official
                        && air65SessionKey != nil
                        && air65CurrentMode != nil
                }
                guard isActive else { return }
                try await self.negotiateAir65V3Session()
                try await performAir65V3Transaction(
                    command,
                    palette: palette,
                    brightness: isOn ? 24 : 0,
                    effectOverride: .solid
                )
            }
        } catch {
            return
        }

        queue.async { [weak self] in
            guard let self,
                  self.air65BlinkGeneration == generation else { return }
            self.scheduleAir65BlinkFrame(
                generation: generation,
                command: command,
                palette: palette,
                isOn: !isOn
            )
        }
    }

    private func cancelAir65Blink() {
        air65BlinkWorkItem?.cancel()
        air65BlinkWorkItem = nil
        air65BlinkGeneration = nil
    }

    private func setOutputReport(
        _ encodedReport: [UInt8],
        reportID: CFIndex,
        on device: IOHIDDevice
    ) throws {
        var report = encodedReport
        let reportCount = report.count
        let status = report.withUnsafeMutableBytes { bytes in
            IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeOutput,
                reportID,
                bytes.bindMemory(to: UInt8.self).baseAddress!,
                reportCount
            )
        }
        guard status == kIOReturnSuccess else {
            throw NuPhyHIDError.reportFailed(status)
        }
    }

    private func negotiateAir65V3Session() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: NuPhyHIDError.deviceNotConnected)
                    return
                }
                guard let device = self.currentDevice,
                      self.currentDeviceProtocol == .air65V3Official,
                      let sessionID = self.activeSessionID else {
                    continuation.resume(throwing: NuPhyHIDError.deviceNotConnected)
                    return
                }

                if self.air65SessionKey != nil,
                   self.air65CurrentMode != nil {
                    continuation.resume()
                    return
                }
                if self.air65Challenge != nil
                    || (self.air65SessionKey != nil && self.air65CurrentMode == nil) {
                    if let previous = self.air65HandshakeContinuation {
                        previous.resume(throwing: NuPhyHIDError.protocolFailed(
                            "Air65 V3 handshake waiter was superseded"
                        ))
                    }
                    self.air65HandshakeContinuation = continuation
                    return
                }

                self.air65HandshakeContinuation = continuation
                self.air65HandshakeTimeout?.cancel()
                self.air65HandshakeTimeout = nil
                self.beginAir65V3Session(on: device, sessionID: sessionID)
            }
        }
    }

    private func beginAir65V3Session(on device: IOHIDDevice, sessionID: UUID) {
        guard let context = managerContext, context.sessionID == sessionID else { return }
        let challenge = (0..<Air65V3ProtocolEncoder.payloadSize).map { _ in UInt8.random(in: .min ... .max) }
        air65Challenge = challenge

        do {
            try setOutputReport(
                Air65V3ProtocolEncoder.handshake(challenge: challenge),
                reportID: 0,
                on: device
            )
        } catch let error as NuPhyHIDError {
            recoverFromReportFailure(
                error,
                productName: productName(of: device),
                transport: .usb
            )
            return
        } catch {
            recoverFromReportFailure(
                .protocolFailed(String(describing: error)),
                productName: productName(of: device),
                transport: .usb
            )
            return
        }

        let timeout = DispatchWorkItem { [weak self] in
            guard let self,
                  self.activeSessionID == sessionID,
                  self.air65SessionKey == nil else { return }
            self.recoverFromReportFailure(
                .protocolFailed("Air65 V3 handshake timed out"),
                productName: self.currentDevice.flatMap(self.productName(of:)),
                transport: .usb
            )
        }
        air65HandshakeTimeout = timeout
        queue.asyncAfter(deadline: .now() + 1, execute: timeout)
    }

    private func beginAir65V3BaseQuery(on device: IOHIDDevice, sessionID: UUID) {
        guard let context = managerContext,
              context.sessionID == sessionID,
              let air65SessionKey else { return }

        do {
            try setOutputReport(
                Air65V3ProtocolEncoder.baseRequest(sessionKey: air65SessionKey),
                reportID: 0,
                on: device
            )
        } catch let error as NuPhyHIDError {
            recoverFromReportFailure(
                error,
                productName: productName(of: device),
                transport: .usb
            )
            return
        } catch {
            recoverFromReportFailure(
                .protocolFailed(String(describing: error)),
                productName: productName(of: device),
                transport: .usb
            )
            return
        }

        let timeout = DispatchWorkItem { [weak self] in
            guard let self,
                  self.activeSessionID == sessionID,
                  self.air65CurrentMode == nil else { return }
            self.recoverFromReportFailure(
                .protocolFailed("Air65 V3 mode query timed out"),
                productName: self.currentDevice.flatMap(self.productName(of:)),
                transport: .usb
            )
        }
        air65BaseTimeout = timeout
        queue.asyncAfter(deadline: .now() + 1, execute: timeout)
    }

    private func handleAir65InputReport(
        result: IOReturn,
        report: UnsafeMutablePointer<UInt8>,
        reportLength: CFIndex,
        sessionID: UUID
    ) {
        guard result == kIOReturnSuccess,
              activeSessionID == sessionID,
              currentDeviceProtocol == .air65V3Official,
              reportLength == Air65V3ProtocolEncoder.reportSize else { return }

        let response = Array(UnsafeBufferPointer(
            start: report,
            count: Air65V3ProtocolEncoder.reportSize
        ))
        guard response[0] == 0xAA else { return }

        if response[1] == 0xD6,
           air65SessionKey != nil,
           air65CurrentMode != nil {
            guard let transaction = air65Transaction else { return }
            do {
                try Air65V3ProtocolEncoder.validateAcknowledgement(response)
            } catch {
                failAir65TransactionAndRecover(
                    .protocolFailed(String(describing: error))
                )
                return
            }

            acknowledgedAir65Reports += 1
            transaction.timeout?.cancel()
            transaction.timeout = nil
            transaction.reportIndex += 1
            if transaction.reportIndex == transaction.reports.count {
                reconnectBackoff.reset()
                completeAir65Transaction(.success(()))
            } else {
                sendCurrentAir65Report()
            }
            return
        }

        if response[1] == 0xA0,
           let air65SessionKey,
           air65CurrentMode == nil {
            do {
                air65CurrentMode = try Air65V3ProtocolEncoder.currentMode(
                    from: response,
                    sessionKey: air65SessionKey
                )
                air65BaseTimeout?.cancel()
                air65BaseTimeout = nil
                reconnectBackoff.reset()
                let continuation = air65HandshakeContinuation
                air65HandshakeContinuation = nil
                continuation?.resume()
                publish(.connected(
                    productName: currentDevice.flatMap(productName(of:)) ?? "Air65 V3",
                    transport: .usb,
                    delivery: .ready
                ))
            } catch {
                recoverFromReportFailure(
                    .protocolFailed(String(describing: error)),
                    productName: currentDevice.flatMap(productName(of:)),
                    transport: .usb
                )
            }
            return
        }

        guard response[1] == 0xEE,
              air65SessionKey == nil,
              let challenge = air65Challenge else { return }

        do {
            air65SessionKey = try Air65V3ProtocolEncoder.sessionKey(
                from: response,
                challenge: challenge
            )
            air65Challenge = nil
            air65HandshakeTimeout?.cancel()
            air65HandshakeTimeout = nil
            guard let currentDevice, let activeSessionID else {
                throw NuPhyHIDError.deviceNotConnected
            }
            beginAir65V3BaseQuery(on: currentDevice, sessionID: activeSessionID)
        } catch {
            recoverFromReportFailure(
                .protocolFailed(String(describing: error)),
                productName: currentDevice.flatMap(productName(of:)),
                transport: .usb
            )
        }
    }

    private func resetAir65Session(error: NuPhyHIDError = .deviceNotConnected) {
        cancelAir65Blink()
        if air65Transaction != nil {
            completeAir65Transaction(.failure(.deviceNotConnected))
        } else if !queuedAir65Transactions.isEmpty {
            let queued = queuedAir65Transactions
            queuedAir65Transactions.removeAll()
            for transaction in queued {
                transaction.completion(.failure(.deviceNotConnected))
            }
        }
        air65HandshakeTimeout?.cancel()
        air65HandshakeTimeout = nil
        air65BaseTimeout?.cancel()
        air65BaseTimeout = nil
        let continuation = air65HandshakeContinuation
        air65HandshakeContinuation = nil
        continuation?.resume(throwing: error)
        air65Challenge = nil
        air65SessionKey = nil
        air65CurrentMode = nil
    }

    private static let deviceMatchedCallback: IOHIDDeviceCallback = {
        context, result, _, device in
        guard result == kIOReturnSuccess, let context else { return }
        let callbackContext = Unmanaged<ManagerCallbackContext>
            .fromOpaque(context).takeUnretainedValue()
        callbackContext.owner?.handleMatchedDevice(
            device,
            sessionID: callbackContext.sessionID
        )
    }

    private static let deviceRemovedCallback: IOHIDDeviceCallback = {
        context, _, _, device in
        guard let context else { return }
        let callbackContext = Unmanaged<ManagerCallbackContext>
            .fromOpaque(context).takeUnretainedValue()
        callbackContext.owner?.handleRemovedDevice(
            device,
            sessionID: callbackContext.sessionID
        )
    }

    private static let air65InputReportCallback: IOHIDReportCallback = {
        context, result, _, _, _, report, reportLength in
        guard let context else { return }
        let callbackContext = Unmanaged<ManagerCallbackContext>
            .fromOpaque(context).takeUnretainedValue()
        callbackContext.owner?.handleAir65InputReport(
            result: result,
            report: report,
            reportLength: reportLength,
            sessionID: callbackContext.sessionID
        )
    }

    private final class ManagerCallbackContext: @unchecked Sendable {
        weak var owner: NuPhyHIDTransport?
        let manager: IOHIDManager
        let sessionID: UUID

        init(owner: NuPhyHIDTransport, manager: IOHIDManager, sessionID: UUID) {
            self.owner = owner
            self.manager = manager
            self.sessionID = sessionID
        }
    }

    private final class Air65ReportTransaction: @unchecked Sendable {
        let id = UUID()
        let reports: [[UInt8]]
        let completion: @Sendable (Result<Void, NuPhyHIDError>) -> Void
        var reportIndex = 0
        var timeout: DispatchWorkItem?

        init(
            reports: [[UInt8]],
            completion: @escaping @Sendable (Result<Void, NuPhyHIDError>) -> Void
        ) {
            self.reports = reports
            self.completion = completion
        }
    }

    private struct DeviceCandidate {
        let device: IOHIDDevice
        let transport: NuPhyHIDConnectionTransport
        let deviceProtocol: NuPhyHIDDeviceProtocol
    }

    private struct RecoveryDevice {
        let productName: String
        let transport: NuPhyHIDConnectionTransport
    }
}
