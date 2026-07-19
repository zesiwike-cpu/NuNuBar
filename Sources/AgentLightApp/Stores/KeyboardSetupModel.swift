import AgentLightCore
import AgentLightHID
import Foundation
import Observation

enum KeyboardSetupStage: Int, CaseIterable, Sendable {
    case welcome
    case keyboard
    case compatibility
    case confirmation
    case dfu
    case flashConfirmation
    case flashing
    case reconnecting
    case codex
    case complete
}

enum V2FirmwareCompatibility: String, CaseIterable, Sendable {
    case notChecked
    case compatible
    case needsFirmware
}

enum KeyboardSetupGate {
    static func canConfirmKeyboard(
        deviceDetected: Bool,
        hidAccessGranted: Bool
    ) -> Bool {
        deviceDetected && hidAccessGranted
    }

    static func canEnterDFU(
        modelConfirmed: Bool,
        viaBackedUp: Bool,
        recoveryFirmwareReady: Bool,
        requiresTestingConfirmation: Bool = false,
        testingFirmwareConfirmed: Bool = false
    ) -> Bool {
        modelConfirmed
            && viaBackedUp
            && recoveryFirmwareReady
            && (!requiresTestingConfirmation || testingFirmwareConfirmed)
    }
}

enum KeyboardSetupRoute {
    static func stageAfterKeyboard(usesOfficialFirmware: Bool) -> KeyboardSetupStage {
        usesOfficialFirmware ? .codex : .compatibility
    }

    static func stageAfterCompatibility(
        _ compatibility: V2FirmwareCompatibility
    ) -> KeyboardSetupStage? {
        switch compatibility {
        case .notChecked: nil
        case .compatible: .codex
        case .needsFirmware: .confirmation
        }
    }
}

@MainActor
@Observable
final class KeyboardSetupModel {
    let appModel: AppModel
    var stage: KeyboardSetupStage = .welcome
    var usbDevice: USBDeviceIdentity?
    var dfuTarget: DFUTarget?
    var modelConfirmed = false
    var viaBackedUp = false
    var recoveryFirmwareReady = false
    var testingFirmwareConfirmed = false
    var flashConfirmed = false
    var compatibility = V2FirmwareCompatibility.notChecked
    var compatibilityTestStarted = false
    var launchAtLogin = true
    var isBusy = false
    var errorMessage: String?
    var flashLog: String?

    @ObservationIgnored private let firmwareCatalog: BundledFirmwareCatalog?
    @ObservationIgnored private let firmwareLoadError: Error?
    private var selectedTarget: KeyboardSetupTarget?
    @ObservationIgnored private let completion: () -> Void
    @ObservationIgnored private var task: Task<Void, Never>?

    init(
        appModel: AppModel,
        bundle: Bundle = .main,
        completion: @escaping () -> Void
    ) {
        self.appModel = appModel
        self.completion = completion
        do {
            firmwareCatalog = try BundledFirmwareCatalog.load(from: bundle)
            firmwareLoadError = nil
        } catch {
            firmwareCatalog = nil
            firmwareLoadError = error
        }
    }

    var manifest: BundledFirmwareManifest? {
        selectedTarget?.bundledFirmware?.manifest
    }

    var selectedDisplayName: String? {
        selectedTarget?.displayName
    }

    var usesOfficialFirmware: Bool {
        selectedTarget?.usesOfficialFirmware == true
    }

    private var selectedFirmware: BundledFirmware? {
        selectedTarget?.bundledFirmware
    }

    var isTestingFirmware: Bool {
        manifest?.releaseStatus == .testing
    }

    var isCriticalOperation: Bool {
        stage == .flashing
    }

    var canGoBack: Bool {
        switch stage {
        case .keyboard, .compatibility, .confirmation, .dfu, .flashConfirmation:
            true
        case .codex:
            usesOfficialFirmware || compatibility == .compatible
        default:
            false
        }
    }

    var canAdvance: Bool {
        switch stage {
        case .welcome:
            true
        case .keyboard:
            KeyboardSetupGate.canConfirmKeyboard(
                deviceDetected: usbDevice != nil,
                hidAccessGranted: appModel.hidAccessState == .granted
            )
        case .compatibility:
            compatibilityTestCompleted && compatibility != .notChecked
        case .confirmation:
            KeyboardSetupGate.canEnterDFU(
                modelConfirmed: modelConfirmed,
                viaBackedUp: viaBackedUp,
                recoveryFirmwareReady: recoveryFirmwareReady,
                requiresTestingConfirmation: isTestingFirmware,
                testingFirmwareConfirmed: testingFirmwareConfirmed
            )
        case .dfu:
            !isBusy
        case .flashConfirmation:
            flashConfirmed && dfuTarget != nil && !isBusy
        case .flashing:
            false
        case .reconnecting:
            !isBusy
        case .codex, .complete:
            !isBusy
        }
    }

    var codexStatus: IntegrationStatus {
        appModel.integrationStatuses[.codex] ?? .unavailable
    }

    func advance() {
        errorMessage = nil
        switch stage {
        case .welcome:
            stage = .keyboard
            checkUSBConnection()
        case .keyboard:
            guard canAdvance else { return }
            stage = KeyboardSetupRoute.stageAfterKeyboard(
                usesOfficialFirmware: usesOfficialFirmware
            )
        case .compatibility:
            guard canAdvance,
                  let next = KeyboardSetupRoute.stageAfterCompatibility(compatibility)
            else { return }
            stage = next
        case .confirmation:
            guard canAdvance else { return }
            stage = .dfu
        case .dfu:
            detectDFU()
        case .flashConfirmation:
            startFlashing()
        case .flashing:
            break
        case .reconnecting:
            retryReconnect()
        case .codex:
            advanceCodexSetup()
        case .complete:
            finish()
        }
    }

    func goBack() {
        guard canGoBack else { return }
        errorMessage = nil
        switch stage {
        case .keyboard: stage = .welcome
        case .compatibility: stage = .keyboard
        case .confirmation: stage = .compatibility
        case .dfu: stage = .confirmation
        case .codex where usesOfficialFirmware: stage = .keyboard
        case .codex where compatibility == .compatible: stage = .compatibility
        case .flashConfirmation:
            flashConfirmed = false
            dfuTarget = nil
            stage = .dfu
        default: break
        }
    }

    func checkUSBConnection() {
        appModel.refreshConnection()
        let matches = USBKeyboardDetector.matchingSetupDevices(in: firmwareCatalog)
        guard matches.count <= 1 else {
            usbDevice = nil
            selectedTarget = nil
            errorMessage = "检测到多个受支持的 NuPhy 键盘。请只保留要设置的键盘通过 USB 连接。"
            return
        }
        guard let match = matches.first else {
            usbDevice = nil
            selectedTarget = nil
            errorMessage = "未检测到受支持的 NuPhy 键盘。请切到有线模式并重新插线。"
            return
        }

        if selectedTarget?.modelIdentifier != match.target.modelIdentifier {
            modelConfirmed = false
            viaBackedUp = false
            recoveryFirmwareReady = false
            testingFirmwareConfirmed = false
            flashConfirmed = false
            compatibility = .notChecked
            compatibilityTestStarted = false
        }
        usbDevice = match.device
        selectedTarget = match.target
        if appModel.hidAccessState != .granted {
            errorMessage = "需要先允许 NuNuBar 的输入监控权限，才能验证并控制键盘灯光。"
        } else {
            errorMessage = nil
        }
    }

    func requestHIDAccess() {
        appModel.requestHIDAccess()
        checkUSBConnection()
    }

    func restart() {
        task?.cancel()
        stage = .welcome
        usbDevice = nil
        selectedTarget = nil
        dfuTarget = nil
        modelConfirmed = false
        viaBackedUp = false
        recoveryFirmwareReady = false
        testingFirmwareConfirmed = false
        flashConfirmed = false
        compatibility = .notChecked
        compatibilityTestStarted = false
        isBusy = false
        errorMessage = nil
        flashLog = nil
    }

    func preview(_ role: AgentLightColorRole) {
        appModel.previewLight(role)
    }

    var compatibilityTestCompleted: Bool {
        compatibilityTestStarted
            && appModel.hasCompletedKeyboardSelfTest
            && !appModel.isKeyboardSelfTestRunning
    }

    func runCompatibilitySelfTest() {
        compatibility = .notChecked
        compatibilityTestStarted = appModel.runKeyboardSelfTest()
    }

    private func detectDFU() {
        guard let selectedFirmware else {
            errorMessage = firmwareLoadError?.localizedDescription
                ?? FirmwareSetupError.invalidManifest.localizedDescription
            return
        }
        let firmwareService = FirmwareSetupService(firmware: selectedFirmware)
        task?.cancel()
        isBusy = true
        errorMessage = nil
        task = Task { [weak self] in
            guard let self else { return }
            defer { isBusy = false }
            do {
                dfuTarget = try await firmwareService.detectDFUTarget()
                stage = .flashConfirmation
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startFlashing() {
        guard canAdvance, let selectedFirmware else { return }
        let firmwareService = FirmwareSetupService(firmware: selectedFirmware)
        task?.cancel()
        isBusy = true
        errorMessage = nil
        stage = .flashing
        task = Task { [weak self] in
            guard let self else { return }
            do {
                flashLog = try await firmwareService.flash()
                stage = .reconnecting
                try await waitForUSBReconnect()
                appModel.applyDefaultLightPreset()
                await appModel.refreshIntegrationStatuses()
                isBusy = false
                stage = .codex
            } catch is CancellationError {
                isBusy = false
            } catch {
                isBusy = false
                errorMessage = error.localizedDescription
                if stage == .flashing {
                    stage = .flashConfirmation
                }
            }
        }
    }

    private func retryReconnect() {
        task?.cancel()
        isBusy = true
        errorMessage = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await waitForUSBReconnect()
                appModel.applyDefaultLightPreset()
                await appModel.refreshIntegrationStatuses()
                isBusy = false
                stage = .codex
            } catch is CancellationError {
                isBusy = false
            } catch {
                isBusy = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func waitForUSBReconnect() async throws {
        guard let manifest else {
            throw FirmwareSetupError.invalidManifest
        }
        for _ in 0..<40 {
            try Task.checkCancellation()
            appModel.refreshConnection()
            if USBKeyboardDetector.targetDevice(for: manifest) != nil,
               appModel.isConnected,
               appModel.keyboardTransport == .usb {
                return
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        throw FirmwareSetupError.keyboardDidNotReconnect
    }

    private func advanceCodexSetup() {
        switch codexStatus {
        case .installed:
            stage = .complete
        case .available:
            installCodex()
        case .needsReview, .unavailable:
            refreshCodexStatus()
        }
    }

    private func installCodex() {
        task?.cancel()
        isBusy = true
        task = Task { [weak self] in
            guard let self else { return }
            defer { isBusy = false }
            do {
                _ = try await appModel.installIntegration(.codex)
            } catch {
                errorMessage = appModel.integrationError ?? error.localizedDescription
            }
        }
    }

    private func refreshCodexStatus() {
        task?.cancel()
        isBusy = true
        task = Task { [weak self] in
            guard let self else { return }
            await appModel.refreshIntegrationStatuses()
            isBusy = false
            if codexStatus == .installed {
                errorMessage = nil
            }
        }
    }

    private func finish() {
        if launchAtLogin {
            do {
                try LaunchAtLoginController().setEnabled(true)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        completion()
    }
}
