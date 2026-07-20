import AgentLightCore
import AgentLightHID
import AppKit
import Foundation
import Observation
import OSLog

private let hidLogger = Logger(subsystem: "com.maige.NuphyBar", category: "HID")
private let agentStateLogger = Logger(subsystem: "com.maige.NuphyBar", category: "AgentState")

@MainActor
@Observable
final class AppModel {
    var keyboardModel: String?
    var keyboardTransport: NuPhyHIDConnectionTransport?
    var isConnected = false
    var activeAgentCommand: AgentLightCommand = .idle
    var lightPalette: AgentLightPalette
    var stateTiming: AgentStateTiming
    var settingsSection: SettingsSection = .agents
    var keyboardError: String?
    var air65CurrentMode: UInt8?
    var airV3FirmwareVersion: OfficialFirmwareVersion?
    var airV3FirmwareError: String?
    var isKeyboardSelfTestRunning = false
    var hasCompletedKeyboardSelfTest = false
    var integrationError: String?
    var integrationStatuses: [AgentProvider: IntegrationStatus] = [:]
    var hidAccessState: NuPhyHIDAccessState = .unknown
    var integrationNoticeProvider: AgentProvider?

    private let keyboard = KeyboardController()
    private let integrations: IntegrationController
    private let paletteStore = AgentLightPaletteStore()
    private let timingStore = AgentStateTimingStore()
    @ObservationIgnored private var deliveryState = AgentCommandDeliveryState()
    @ObservationIgnored private var deliveryActivity = AgentDeliveryActivity()
    @ObservationIgnored private var agentStateObservation: AgentStateChangeObservation?
    @ObservationIgnored private var agentExpirationTask: Task<Void, Never>?
    @ObservationIgnored private var agentFallbackTask: Task<Void, Never>?
    @ObservationIgnored private var keyboardConnectionTask: Task<Void, Never>?
    @ObservationIgnored private var integrationNoticeTask: Task<Void, Never>?
    @ObservationIgnored private var lightAdjustmentPreviewTask: Task<Void, Never>?
    @ObservationIgnored private var lightPreviewTask: Task<Void, Never>?
    @ObservationIgnored private var systemWakeMonitor: SystemWakeMonitor?
    @ObservationIgnored private var isDeliveryReady = false
    @ObservationIgnored private var lightPreviewCommand: AgentLightCommand?
    @ObservationIgnored private var activeDeliveryRevision: UInt64?

    init() {
        lightPalette = paletteStore.load()
        stateTiming = timingStore.load()
        let helperPath = Bundle.main.bundleURL
            .appending(path: "Contents/Helpers/agent-light")
            .path
        integrations = IntegrationController(helperPath: helperPath)
        startKeyboardConnectionObserver()
        refreshConnection()
        refreshIntegrations()
        startAgentMonitor()
        startSystemWakeMonitor()
    }

    func refreshConnection() {
        hidAccessState = NuPhyHIDTransport.accessState
        if hidAccessState != .granted {
            isConnected = false
            isDeliveryReady = false
            keyboardModel = nil
            keyboardTransport = nil
            keyboardError = nil
            airV3FirmwareVersion = nil
            airV3FirmwareError = nil
        }

        Task {
            await keyboard.refresh()
        }
    }

    func requestHIDAccess() {
        _ = NuPhyHIDTransport.requestAccess()
        hidAccessState = NuPhyHIDTransport.accessState

        if hidAccessState == .granted {
            refreshConnection()
        } else {
            openInputMonitoringSettings()
        }
    }

    func openInputMonitoringSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    func refreshIntegrations() {
        Task {
            await refreshIntegrationStatuses()
        }
    }

    func refreshIntegrationStatuses() async {
        integrationStatuses = await integrations.statuses()
    }

    func toggleIntegration(_ provider: AgentProvider) {
        let shouldInstall = integrationStatuses[provider] == .available
        Task {
            do {
                _ = try await setIntegrationInstalled(shouldInstall, provider: provider)
            } catch {
                return
            }
        }
    }

    @discardableResult
    func setIntegrationInstalled(
        _ installed: Bool,
        provider: AgentProvider
    ) async throws -> IntegrationStatus {
        do {
            try await integrations.setInstalled(installed, provider: provider)
            integrationStatuses = await integrations.statuses()
            showIntegrationNotice(for: provider)
            integrationError = nil
            return integrationStatuses[provider] ?? .unavailable
        } catch {
            integrationError = "接入失败：\(error.localizedDescription)"
            throw error
        }
    }

    @discardableResult
    func installIntegration(_ provider: AgentProvider) async throws -> IntegrationStatus {
        if integrationStatuses[provider] == .installed
            || integrationStatuses[provider] == .needsReview {
            return integrationStatuses[provider] ?? .unavailable
        }
        return try await setIntegrationInstalled(true, provider: provider)
    }

    func updateLightColor(_ color: AgentLightRGBColor, for role: AgentLightColorRole) {
        guard lightPalette.color(for: role) != color else { return }
        lightPalette.setColor(color, for: role)
        paletteStore.save(lightPalette)
        scheduleLightAdjustmentPreview(role)
    }

    func updateLightEffect(_ effect: AgentLightEffect, for role: AgentLightColorRole) {
        guard lightPalette.effect(for: role) != effect else { return }
        lightPalette.setEffect(effect, for: role)
        paletteStore.save(lightPalette)
        previewLight(role)
    }

    func updateLightBrightness(_ brightness: UInt8, for role: AgentLightColorRole) {
        let normalized = min(brightness, AgentLightPalette.maximumBrightness)
        guard lightPalette.brightness(for: role) != normalized else { return }
        lightPalette.setBrightness(normalized, for: role)
        paletteStore.save(lightPalette)
        scheduleLightAdjustmentPreview(role)
    }

    func updateCompletionDuration(seconds: Int64) {
        stateTiming.setCompletionSeconds(seconds)
        saveStateTiming()
    }

    func updateErrorDuration(seconds: Int64) {
        stateTiming.setErrorSeconds(seconds)
        saveStateTiming()
    }

    func updateWorkingTimeout(minutes: Int64) {
        stateTiming.setWorkingTimeoutSeconds(minutes * 60)
        saveStateTiming()
    }

    func updateWaitingTimeout(minutes: Int64) {
        stateTiming.setWaitingTimeoutSeconds(minutes * 60)
        saveStateTiming()
    }

    var lightSettingsAreDefault: Bool {
        lightPalette == .default && stateTiming == .default
    }

    var canRunKeyboardSelfTest: Bool {
        hidAccessState == .granted
            && isConnected
            && isDeliveryReady
            && keyboardTransport == .usb
            && !isKeyboardSelfTestRunning
    }

    func resetLightSettings() {
        guard !lightSettingsAreDefault else { return }
        lightPalette = .default
        stateTiming = .default
        paletteStore.reset()
        timingStore.reset()
        cancelPendingLightAdjustmentPreview()
        lightPreviewTask?.cancel()
        lightPreviewTask = nil
        lightPreviewCommand = nil
        deliveryState.invalidate()
        applyAgentStateIfChanged()
    }

    private func saveStateTiming() {
        timingStore.save(stateTiming)
        applyAgentStateIfChanged()
    }

    func applyDefaultLightPreset() {
        lightPalette = .default
        paletteStore.save(lightPalette)
        cancelPendingLightAdjustmentPreview()
        lightPreviewTask?.cancel()
        lightPreviewTask = nil
        lightPreviewCommand = nil
        deliveryState.invalidate()
        applyDisplayedCommand(
            activeAgentCommand,
            deliveryRevision: activeDeliveryRevision
        )
    }

    func previewLight(_ role: AgentLightColorRole) {
        guard keyboardTransport == .usb else { return }
        cancelPendingLightAdjustmentPreview()
        let command = role.command
        lightPreviewTask?.cancel()
        lightPreviewCommand = command
        deliveryState.invalidate()
        applyDisplayedCommand(command)

        lightPreviewTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
            guard let self else { return }
            lightPreviewTask = nil
            lightPreviewCommand = nil
            deliveryState.invalidate()
            applyAgentStateIfChanged()
        }
    }

    @discardableResult
    func runKeyboardSelfTest() -> Bool {
        guard canRunKeyboardSelfTest else { return false }

        cancelPendingLightAdjustmentPreview()
        lightPreviewTask?.cancel()
        lightPreviewTask = nil
        lightPreviewCommand = nil
        isKeyboardSelfTestRunning = true
        hasCompletedKeyboardSelfTest = false
        keyboardError = nil
        let palette = lightPalette

        Task { [weak self] in
            guard let self else { return }
            do {
                for command: AgentLightCommand in [.working, .complete, .waiting] {
                    try await keyboard.send(command, palette: palette)
                    try await Task.sleep(for: .seconds(2))
                }
                hasCompletedKeyboardSelfTest = true
            } catch {
                keyboardError = error.localizedDescription
                hidLogger.error(
                    "Keyboard self-test failed: \(String(describing: error), privacy: .public)"
                )
            }

            isKeyboardSelfTestRunning = false
            deliveryState.invalidate()
            applyAgentStateIfChanged()
        }
        return true
    }

    private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        guard deliveryActivity.begin() else { return }
        keyboardError = nil
        Task {
            defer {
                if deliveryActivity.finish() {
                    applyAgentStateIfChanged()
                }
            }
            do {
                try await operation()
            } catch {
                if error is NuPhyHIDError {
                    deliveryState.markFailed()
                }
                keyboardError = error.localizedDescription
                hidLogger.error("Keyboard state send failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func startAgentMonitor() {
        do {
            agentStateObservation = try AgentStateChangeNotification.observe { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleAgentStateChange()
                }
            }
        } catch {
            agentStateLogger.error(
                "Could not register Agent state notifications: \(String(describing: error), privacy: .public)"
            )
        }
        startAgentFallbackMonitor()
        applyAgentStateIfChanged()
    }

    private func startAgentFallbackMonitor() {
        agentFallbackTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    return
                }
                self?.applyAgentStateIfChanged()
            }
        }
    }

    private func startKeyboardConnectionObserver() {
        keyboardConnectionTask = Task { [weak self] in
            guard let states = await self?.keyboard.connectionStates() else { return }
            for await state in states {
                guard !Task.isCancelled else { return }
                self?.handleKeyboardConnection(state)
            }
        }
    }

    private func startSystemWakeMonitor() {
        systemWakeMonitor = SystemWakeMonitor { [weak self] in
            self?.rebuildHIDSessionAfterWake()
        }
    }

    private func rebuildHIDSessionAfterWake() {
        isDeliveryReady = false
        hidLogger.info("Mac woke from sleep; rebuilding the NuPhy HID session")
        Task {
            await keyboard.rebuildSession()
        }
    }

    private func handleKeyboardConnection(_ state: NuPhyHIDConnectionState) {
        hidAccessState = NuPhyHIDTransport.accessState
        switch state {
        case .disconnected:
            isConnected = false
            isDeliveryReady = false
            keyboardModel = nil
            keyboardTransport = nil
            air65CurrentMode = nil
            airV3FirmwareVersion = nil
            airV3FirmwareError = nil
            hasCompletedKeyboardSelfTest = false
            keyboardError = NuPhyHIDError.deviceNotConnected.localizedDescription

        case .connected(let productName, let transport, .recovering(let error)):
            keyboardModel = productName
            keyboardTransport = transport
            isConnected = true
            isDeliveryReady = false
            air65CurrentMode = nil
            airV3FirmwareVersion = nil
            airV3FirmwareError = nil
            hasCompletedKeyboardSelfTest = false
            keyboardError = error.localizedDescription

        case .connected(let productName, let transport, .rebuilding):
            keyboardModel = productName
            keyboardTransport = transport
            isConnected = true
            isDeliveryReady = false
            air65CurrentMode = nil
            airV3FirmwareVersion = nil
            airV3FirmwareError = nil
            hasCompletedKeyboardSelfTest = false
            keyboardError = nil

        case .connected(let productName, let transport, .ready):
            let shouldReplayState = !isDeliveryReady
                || keyboardModel != productName
                || keyboardTransport != transport
            keyboardModel = productName
            keyboardTransport = transport
            isConnected = true
            isDeliveryReady = true
            keyboardError = nil
            if shouldReplayState {
                deliveryState.connectionRestored()
                hidLogger.info("NuPhy keyboard HID session is ready over \(transport.rawValue, privacy: .public)")
                applyAgentStateIfChanged()
            }
            if let profile = SupportedOfficialNuPhyKeyboard.models.first(where: {
                productName.caseInsensitiveCompare($0.productName) == .orderedSame
            }) {
                Task { [weak self] in
                    guard let self else { return }
                    air65CurrentMode = await keyboard.diagnostics().air65CurrentMode
                    await readOfficialFirmwareVersion(for: profile)
                }
            } else {
                air65CurrentMode = nil
                airV3FirmwareVersion = nil
                airV3FirmwareError = nil
            }

        case .unavailable(let error):
            isConnected = false
            isDeliveryReady = false
            keyboardModel = nil
            keyboardTransport = nil
            air65CurrentMode = nil
            airV3FirmwareVersion = nil
            airV3FirmwareError = nil
            hasCompletedKeyboardSelfTest = false
            keyboardError = error == .permissionDenied ? nil : error.localizedDescription
        }
    }

    private func readOfficialFirmwareVersion(for profile: OfficialKeyboardProfile) async {
        guard profile.minimumFirmwareVersion != nil else {
            airV3FirmwareVersion = nil
            airV3FirmwareError = nil
            return
        }

        do {
            let payload = try await keyboard.readAirV3FirmwareInfo()
            guard let version = OfficialFirmwareVersion(airV3Payload: payload) else {
                throw NuPhyHIDError.protocolFailed("unrecognized Air V3 firmware version")
            }
            guard keyboardModel?.caseInsensitiveCompare(profile.productName) == .orderedSame else {
                return
            }
            airV3FirmwareVersion = version
            airV3FirmwareError = nil
        } catch {
            guard keyboardModel?.caseInsensitiveCompare(profile.productName) == .orderedSame else {
                return
            }
            airV3FirmwareVersion = nil
            airV3FirmwareError = "无法读取官方固件版本，请重新检测键盘。"
        }
    }

    private func applyAgentStateIfChanged() {
        guard var state = try? AgentStateFile().load() else { return }
        let now = Int64(Date().timeIntervalSince1970)
        let presentation = state.presentation(now: now, timing: stateTiming)
        activeAgentCommand = presentation.command
        activeDeliveryRevision = state.deliveryRevision
        scheduleAgentExpiration(presentation.nextExpiration, now: now)

        applyDisplayedCommand(
            lightPreviewCommand ?? presentation.command,
            deliveryRevision: lightPreviewCommand == nil ? state.deliveryRevision : nil
        )
    }

    private func applyDisplayedCommand(
        _ command: AgentLightCommand,
        deliveryRevision: UInt64? = nil
    ) {
        guard hidAccessState == .granted,
              isConnected,
              isDeliveryReady,
              !isKeyboardSelfTestRunning else { return }
        let palette = lightPalette
        guard deliveryState.shouldSend(
            command,
            palette: palette,
            deliveryRevision: deliveryRevision
        ) else { return }
        if deliveryActivity.isSending {
            deliveryActivity.requestRefresh()
            return
        }
        deliveryState.markInFlight(
            command,
            palette: palette,
            deliveryRevision: deliveryRevision
        )

        perform {
            try await self.keyboard.send(command, palette: palette)
            self.deliveryState.markDelivered(
                command,
                palette: palette,
                deliveryRevision: deliveryRevision
            )
            let color = palette.color(for: command)
            let effect = palette.effect(for: command)
            let brightness = palette.brightness(for: command)
            hidLogger.info(
                "Delivered \(String(describing: command), privacy: .public) color rgb(\(color.red),\(color.green),\(color.blue)) effect \(effect.rawValue, privacy: .public) brightness \(brightness)% over NuPhy HID"
            )
        }
    }

    private func handleAgentStateChange() {
        cancelPendingLightAdjustmentPreview()
        lightPreviewTask?.cancel()
        lightPreviewTask = nil
        lightPreviewCommand = nil
        applyAgentStateIfChanged()
    }

    private func scheduleLightAdjustmentPreview(_ role: AgentLightColorRole) {
        lightAdjustmentPreviewTask?.cancel()
        lightAdjustmentPreviewTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            lightAdjustmentPreviewTask = nil
            previewLight(role)
        }
    }

    private func cancelPendingLightAdjustmentPreview() {
        lightAdjustmentPreviewTask?.cancel()
        lightAdjustmentPreviewTask = nil
    }

    private func scheduleAgentExpiration(_ expiration: Int64?, now: Int64) {
        agentExpirationTask?.cancel()
        guard let expiration else {
            agentExpirationTask = nil
            return
        }

        let delay = max(0, expiration - now)
        agentExpirationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard let self else { return }
            agentExpirationTask = nil
            handleAgentStateChange()
        }
    }

    private func showIntegrationNotice(for provider: AgentProvider) {
        integrationNoticeProvider = provider
        integrationNoticeTask?.cancel()
        integrationNoticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.integrationNoticeProvider = nil
        }
    }
}

struct AgentCommandDeliveryState {
    private var lastDeliveredPayload: AgentLightDeliveryPayload?
    private var inFlightPayload: AgentLightDeliveryPayload?
    private var canAttemptDelivery = true

    func shouldSend(
        _ command: AgentLightCommand,
        palette: AgentLightPalette = .default,
        deliveryRevision: UInt64? = nil
    ) -> Bool {
        let payload = AgentLightDeliveryPayload(
            command: command,
            palette: palette,
            deliveryRevision: deliveryRevision
        )
        return canAttemptDelivery
            && payload != lastDeliveredPayload
            && payload != inFlightPayload
    }

    mutating func markInFlight(
        _ command: AgentLightCommand,
        palette: AgentLightPalette = .default,
        deliveryRevision: UInt64? = nil
    ) {
        inFlightPayload = AgentLightDeliveryPayload(
            command: command,
            palette: palette,
            deliveryRevision: deliveryRevision
        )
    }

    mutating func markDelivered(
        _ command: AgentLightCommand,
        palette: AgentLightPalette = .default,
        deliveryRevision: UInt64? = nil
    ) {
        let payload = AgentLightDeliveryPayload(
            command: command,
            palette: palette,
            deliveryRevision: deliveryRevision
        )
        lastDeliveredPayload = payload
        inFlightPayload = nil
        canAttemptDelivery = true
    }

    mutating func markFailed() {
        lastDeliveredPayload = nil
        inFlightPayload = nil
        canAttemptDelivery = false
    }

    mutating func connectionRestored() {
        lastDeliveredPayload = nil
        inFlightPayload = nil
        canAttemptDelivery = true
    }

    mutating func invalidate() {
        lastDeliveredPayload = nil
        canAttemptDelivery = true
    }
}

private struct AgentLightDeliveryPayload: Equatable {
    let command: AgentLightCommand
    let palette: AgentLightPalette
    let deliveryRevision: UInt64?
}

extension AgentLightColorRole {
    var command: AgentLightCommand {
        switch self {
        case .idle: .idle
        case .working: .working
        case .waiting: .waiting
        case .complete: .complete
        }
    }
}

struct AgentDeliveryActivity {
    private(set) var isSending = false
    private var refreshPending = false

    mutating func begin() -> Bool {
        guard !isSending else { return false }
        isSending = true
        return true
    }

    mutating func requestRefresh() {
        if isSending {
            refreshPending = true
        }
    }

    mutating func finish() -> Bool {
        let shouldRefresh = refreshPending
        isSending = false
        refreshPending = false
        return shouldRefresh
    }
}
