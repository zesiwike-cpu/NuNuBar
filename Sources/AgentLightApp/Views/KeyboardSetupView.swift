import AgentLightCore
import AgentLightHID
import SwiftUI

enum KeyboardSetupLayout {
    static let windowWidth: CGFloat = 680
    static let windowHeight: CGFloat = 500
    static let sidebarWidth: CGFloat = 174
}

struct KeyboardSetupView: View {
    @Bindable var setup: KeyboardSetupModel
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.simplifiedChinese.rawValue

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: KeyboardSetupLayout.sidebarWidth)
            Divider()
            VStack(spacing: 0) {
                header
                Divider()
                stageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Divider()
                footer
            }
        }
        .frame(width: KeyboardSetupLayout.windowWidth, height: KeyboardSetupLayout.windowHeight)
        .foregroundStyle(NuphyBarTheme.text)
        .background(NuphyBarTheme.background)
        .tint(NuphyBarTheme.accent)
        .environment(\.appLanguage, language)
        .environment(\.locale, language.locale)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text("NuNuBar")
                        .font(.system(size: 15, weight: .semibold))
                    Text(copy.setupAssistant)
                        .font(.system(size: 10.5))
                        .foregroundStyle(NuphyBarTheme.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 20)

            ForEach(Array(sidebarSteps.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 9) {
                    Image(systemName: item.icon)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 18)
                    Text(item.title)
                        .font(.system(size: 11.5, weight: index == currentPhase ? .semibold : .regular))
                    Spacer()
                    if index < currentPhase {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    }
                }
                .foregroundStyle(index <= currentPhase ? NuphyBarTheme.text : NuphyBarTheme.tertiaryText)
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(index == currentPhase ? NuphyBarTheme.accent.opacity(0.09) : .clear)
            }

            Spacer()
            Text(sidebarFirmwareSummary)
                .font(.system(size: 9.5))
                .foregroundStyle(NuphyBarTheme.tertiaryText)
                .lineLimit(2)
                .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(copy.title(for: setup.stage))
                .font(.system(size: 21, weight: .semibold))
            Text(copy.subtitle(for: setup.stage))
                .font(.system(size: 11.5))
                .foregroundStyle(NuphyBarTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 26)
        .padding(.vertical, 17)
    }

    @ViewBuilder
    private var stageContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch setup.stage {
                case .welcome:
                    welcomeContent
                case .keyboard:
                    keyboardContent
                case .compatibility:
                    compatibilityContent
                case .confirmation:
                    confirmationContent
                case .dfu:
                    dfuContent
                case .flashConfirmation:
                    flashConfirmationContent
                case .flashing:
                    flashingContent
                case .reconnecting:
                    reconnectingContent
                case .codex:
                    codexContent
                case .complete:
                    completeContent
                }

                if let errorMessage = setup.errorMessage {
                    SetupNotice(text: errorMessage, isError: true)
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
    }

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text(copy.welcomeBody)
                .font(.system(size: 13))
                .foregroundStyle(NuphyBarTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 20) {
                feature("keyboard", copy.usbSync)
                feature("paintpalette", copy.customLights)
                feature("bolt.horizontal", copy.localOnly)
            }
        }
    }

    private var keyboardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SetupStatusRow(
                icon: "keyboard",
                title: setup.usbDevice?.productName ?? copy.supportedKeyboard,
                detail: setup.usbDevice == nil ? copy.usbNotDetected : copy.usbDetected,
                color: setup.usbDevice == nil ? .orange : .green
            ) {
                Button {
                    setup.checkUSBConnection()
                } label: {
                    Label(copy.checkAgain, systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
            }

            Divider()

            SetupStatusRow(
                icon: "hand.raised",
                title: copy.inputMonitoring,
                detail: setup.appModel.hidAccessState == .granted ? copy.allowed : copy.permissionNeeded,
                color: setup.appModel.hidAccessState == .granted ? .green : .red
            ) {
                if setup.appModel.hidAccessState != .granted {
                    Button(copy.allow) { setup.requestHIDAccess() }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                }
            }

            SetupNotice(text: copy.inputPrivacy)
            if setup.usesOfficialFirmware {
                SetupNotice(text: copy.airV3OfficialFirmware)
                if let minimum = setup.minimumOfficialFirmwareVersion {
                    SetupStatusRow(
                        icon: "externaldrive.badge.checkmark",
                        title: copy.officialFirmwareVersion,
                        detail: setup.appModel.airV3FirmwareVersion?.description ?? copy.reading,
                        color: setup.officialFirmwareNeedsUpdate ? .red : (setup.officialFirmwareCheckPending ? .orange : .green)
                    ) { EmptyView() }
                    if setup.officialFirmwareNeedsUpdate {
                        SetupNotice(text: copy.air75FirmwareUpdateRequired(minimum), isError: true)
                        Link(destination: URL(string: "https://drive.nuphy.io")!) {
                            Label(copy.openNuPhyIO, systemImage: "arrow.up.circle")
                        }
                        .font(.system(size: 11.5))
                    }
                }
            }
        }
    }

    private var confirmationContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(copy.confirmModel(setup.selectedDisplayName), isOn: $setup.modelConfirmed)
                .toggleStyle(.checkbox)
            Toggle(copy.confirmBackup, isOn: $setup.viaBackedUp)
                .toggleStyle(.checkbox)
            Toggle(copy.confirmRecovery(setup.selectedDisplayName), isOn: $setup.recoveryFirmwareReady)
                .toggleStyle(.checkbox)
            if setup.isTestingFirmware {
                Toggle(copy.confirmTestingFirmware, isOn: $setup.testingFirmwareConfirmed)
                    .toggleStyle(.checkbox)
            }
            Link(destination: URL(string: "https://nuphy.com/pages/qmk-firmwares")!) {
                Label(copy.downloadRecovery, systemImage: "arrow.down.circle")
                    .font(.system(size: 11.5))
            }

            SetupNotice(
                text: copy.modelWarning(
                    setup.selectedDisplayName,
                    testing: setup.isTestingFirmware
                ),
                isError: true
            )
            if setup.manifest?.lightZone == .halolight {
                SetupNotice(text: copy.halolightDetail)
            }
        }
        .font(.system(size: 12.5))
    }

    private var compatibilityContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SetupStatusRow(
                icon: "lightbulb",
                title: setup.selectedDisplayName ?? copy.supportedKeyboard,
                detail: setup.compatibilityTestCompleted
                    ? copy.selfTestSent
                    : copy.firmwareVersionUnknown,
                color: setup.compatibilityTestCompleted ? .green : .orange
            ) {
                Button {
                    setup.runCompatibilitySelfTest()
                } label: {
                    if setup.appModel.isKeyboardSelfTestRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(copy.startSelfTest, systemImage: "play.fill")
                    }
                }
                .controlSize(.small)
                .disabled(!setup.appModel.canRunKeyboardSelfTest)
            }

            SetupNotice(text: copy.compatibilityDetail)

            if setup.compatibilityTestCompleted {
                Divider()
                Text(copy.selfTestQuestion)
                    .font(.system(size: 12.5, weight: .medium))
                Picker(copy.selfTestResult, selection: $setup.compatibility) {
                    Text(copy.lightsChanged)
                        .tag(V2FirmwareCompatibility.compatible)
                    Text(copy.noLightChange)
                        .tag(V2FirmwareCompatibility.needsFirmware)
                }
                .pickerStyle(.segmented)

                if setup.compatibility == .compatible {
                    SetupNotice(text: copy.keepExistingFirmware)
                } else if setup.compatibility == .needsFirmware {
                    SetupNotice(text: copy.prepareFirmware, isError: true)
                }
            }
        }
    }

    private var dfuContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            instruction(number: 1, text: copy.dfuStepOne)
            instruction(number: 2, text: copy.dfuStepTwo)
            instruction(number: 3, text: copy.dfuStepThree)
            SetupNotice(text: copy.dfuHint)
        }
    }

    private var flashConfirmationContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            setupDetail(copy.targetKeyboard, value: setup.selectedDisplayName ?? "-")
            setupDetail(copy.firmwareVersion, value: "NuNuBar v\(setup.manifest?.firmwareVersion ?? "-")")
            setupDetail(copy.releaseStatus, value: copy.releaseStatus(testing: setup.isTestingFirmware))
            setupDetail(copy.dfuPath, value: setup.dfuTarget?.path ?? "-")
            setupDetail("SHA-256", value: shortHash)
            Divider()
            Toggle(copy.finalFlashConfirmation(setup.selectedDisplayName), isOn: $setup.flashConfirmed)
                .toggleStyle(.checkbox)
                .font(.system(size: 12.5, weight: .medium))
            SetupNotice(text: copy.flashWarning, isError: true)
        }
    }

    private var flashingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(copy.doNotDisconnect)
                .font(.system(size: 13, weight: .medium))
            Text(copy.flashingDetail)
                .font(.system(size: 11.5))
                .foregroundStyle(NuphyBarTheme.secondaryText)
        }
    }

    private var reconnectingContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            SetupStatusRow(
                icon: "cable.connector",
                title: copy.waitingForKeyboard(setup.selectedDisplayName),
                detail: setup.appModel.isConnected && setup.appModel.keyboardTransport == .usb
                    ? copy.usbProtocolReady
                    : copy.reconnectHint,
                color: setup.appModel.isConnected && setup.appModel.keyboardTransport == .usb ? .green : .orange
            ) {
                if setup.isBusy {
                    ProgressView().controlSize(.small)
                }
            }
            SetupNotice(text: copy.reconnectDetail)
        }
    }

    private var codexContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                AgentBrandIcon(provider: .codex, size: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Codex")
                        .font(.system(size: 14, weight: .semibold))
                    HStack(spacing: 6) {
                        Circle()
                            .fill(codexStatusColor)
                            .frame(width: 7, height: 7)
                        Text(codexStatusText)
                            .font(.system(size: 11))
                            .foregroundStyle(NuphyBarTheme.secondaryText)
                    }
                }
                Spacer()
                if setup.isBusy {
                    ProgressView().controlSize(.small)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                instruction(number: 1, text: copy.codexStepInstall)
                instruction(number: 2, text: copy.codexStepApprove)
                instruction(number: 3, text: copy.codexStepVerify)
            }
            SetupNotice(text: copy.codexHookFiles)
            Text(codexGuidance)
                .font(.system(size: 12.5))
                .foregroundStyle(NuphyBarTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if setup.codexStatus == .needsReview {
                SetupNotice(text: copy.codexApproval)
            }
        }
    }

    private var completeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            lightRow(.idle, title: copy.idle)
            lightRow(.working, title: copy.working)
            lightRow(.waiting, title: copy.needsConfirmation)
            lightRow(.complete, title: copy.complete)
            Divider()
            Toggle(copy.launchAtLogin, isOn: $setup.launchAtLogin)
                .toggleStyle(.checkbox)
                .font(.system(size: 12.5))
            SetupNotice(text: copy.readyDetail)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if setup.canGoBack {
                Button(copy.back) { setup.goBack() }
                    .keyboardShortcut(.cancelAction)
            }
            Spacer()
            if setup.stage != .flashing {
                Button {
                    setup.advance()
                } label: {
                    Label(primaryButtonTitle, systemImage: primaryButtonIcon)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!setup.canAdvance)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 54)
    }

    private func feature(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(NuphyBarTheme.accent)
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
        }
    }

    private func instruction(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 21, height: 21)
                .background(NuphyBarTheme.accent, in: Circle())
            Text(text)
                .font(.system(size: 12.5))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func setupDetail(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(NuphyBarTheme.secondaryText)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
        .font(.system(size: 11.5))
    }

    private func lightRow(_ role: AgentLightColorRole, title: String) -> some View {
        let color = setup.appModel.lightPalette.color(for: role)
        let effect = setup.appModel.lightPalette.effect(for: role)
        return HStack(spacing: 10) {
            Circle()
                .fill(Color(red: Double(color.red) / 255, green: Double(color.green) / 255, blue: Double(color.blue) / 255))
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(.primary.opacity(0.15), lineWidth: 0.5))
            Text(title)
                .font(.system(size: 12.5))
            Spacer()
            Text(copy.effect(effect))
                .font(.system(size: 10.5))
                .foregroundStyle(NuphyBarTheme.secondaryText)
            Button {
                setup.preview(role)
            } label: {
                Image(systemName: "play.fill")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .help(copy.preview)
        }
        .frame(height: 28)
    }

    private var primaryButtonTitle: String {
        switch setup.stage {
        case .welcome, .keyboard, .confirmation: copy.continueText
        case .compatibility:
            setup.compatibility == .compatible ? copy.connectCodex : copy.continueFirmware
        case .dfu: copy.detectDFU
        case .flashConfirmation: copy.flashNow
        case .flashing: copy.flashing
        case .reconnecting: copy.checkReconnect
        case .codex:
            switch setup.codexStatus {
            case .available: copy.connectCodex
            case .needsReview, .unavailable: copy.checkAgain
            case .installed: copy.continueText
            }
        case .complete: copy.finish
        }
    }

    private var primaryButtonIcon: String {
        switch setup.stage {
        case .compatibility:
            setup.compatibility == .compatible
                ? "point.3.connected.trianglepath.dotted"
                : "externaldrive"
        case .dfu: "arrow.clockwise"
        case .flashConfirmation: "externaldrive.badge.exclamationmark"
        case .reconnecting: "cable.connector"
        case .codex: "point.3.connected.trianglepath.dotted"
        case .complete: "checkmark"
        default: "arrow.right"
        }
    }

    private var currentPhase: Int {
        if setup.usesOfficialFirmware {
            switch setup.stage {
            case .welcome: return 0
            case .keyboard: return 1
            case .codex: return 2
            case .complete: return 3
            default: return 1
            }
        }
        switch setup.stage {
        case .welcome: return 0
        case .keyboard, .compatibility: return 1
        case .confirmation: return 2
        case .dfu, .flashConfirmation, .flashing, .reconnecting: return 2
        case .codex: return 3
        case .complete: return 4
        }
    }

    private var sidebarSteps: [(title: String, icon: String)] {
        if setup.usesOfficialFirmware {
            return [
                (copy.start, "sparkles"),
                (copy.keyboard, "keyboard"),
                ("Codex", "point.3.connected.trianglepath.dotted"),
                (copy.complete, "checkmark.circle"),
            ]
        }
        return [
            (copy.start, "sparkles"),
            (copy.keyboard, "keyboard"),
            (copy.firmware, "externaldrive"),
            ("Codex", "point.3.connected.trianglepath.dotted"),
            (copy.complete, "checkmark.circle"),
        ]
    }

    private var shortHash: String {
        guard let hash = setup.manifest?.firmwareSHA256 else { return "-" }
        return "\(hash.prefix(12))…\(hash.suffix(8))"
    }

    private var sidebarFirmwareSummary: String {
        if setup.usesOfficialFirmware, let displayName = setup.selectedDisplayName {
            return "\(displayName.replacingOccurrences(of: "NuPhy ", with: ""))  •  \(copy.officialFirmware)"
        }
        if setup.stage == .keyboard || setup.stage == .compatibility,
           let displayName = setup.selectedDisplayName {
            return "\(displayName.replacingOccurrences(of: "NuPhy ", with: ""))  •  \(copy.checkExistingFirmware)"
        }
        guard let manifest = setup.manifest else { return copy.supportedModels }
        return "\(manifest.displayName.replacingOccurrences(of: "NuPhy ", with: ""))  •  v\(manifest.firmwareVersion)"
    }

    private var codexStatusColor: Color {
        switch setup.codexStatus {
        case .installed: .green
        case .available: .orange
        case .needsReview: .red
        case .unavailable: .gray
        }
    }

    private var codexStatusText: String {
        switch setup.codexStatus {
        case .installed: copy.connected
        case .available: copy.readyToConnect
        case .needsReview: copy.pendingApproval
        case .unavailable: copy.notDetected
        }
    }

    private var codexGuidance: String {
        switch setup.codexStatus {
        case .installed: copy.codexConnected
        case .available: copy.codexAvailable
        case .needsReview: copy.codexNeedsReview
        case .unavailable: copy.codexUnavailable
        }
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .simplifiedChinese
    }

    private var copy: KeyboardSetupCopy {
        KeyboardSetupCopy(language: language)
    }
}

private struct SetupStatusRow<Accessory: View>: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(NuphyBarTheme.secondaryText)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                HStack(spacing: 6) {
                    Circle().fill(color).frame(width: 7, height: 7)
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(NuphyBarTheme.secondaryText)
                }
            }
            Spacer()
            accessory
        }
    }
}

private struct SetupNotice: View {
    let text: String
    var isError = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "info.circle")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 10.5))
        .foregroundStyle(isError ? Color.red : NuphyBarTheme.secondaryText)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isError ? Color.red : NuphyBarTheme.accent).opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct KeyboardSetupCopy {
    let language: AppLanguage

    private func value(_ zh: String, _ en: String) -> String {
        language == .simplifiedChinese ? zh : en
    }

    var setupAssistant: String { value("键盘设置助手", "Keyboard Setup") }
    var welcomeBody: String { value("这个向导会识别键盘的精确型号，在需要时刷入对应固件，并让 Codex 状态自动显示在 NuPhy 状态灯上。", "This assistant identifies the exact keyboard model, installs matching firmware when required, and shows Codex status on the NuPhy status lights.") }
    var supportedKeyboard: String { value("受支持的 NuPhy 键盘", "Supported NuPhy keyboard") }
    var supportedModels: String { value("Air65 / Air75 V3 / Air60 / 75 / 96 / Halo75 V2 ANSI", "Air65 / Air75 V3 / Air60 / 75 / 96 / Halo75 V2 ANSI") }
    var officialFirmware: String { value("官方固件", "Official firmware") }
    var usbSync: String { value("USB 同步", "USB sync") }
    var customLights: String { value("自定义灯效", "Custom lights") }
    var localOnly: String { value("本地处理", "Local only") }
    var start: String { value("开始", "Start") }
    var keyboard: String { value("键盘", "Keyboard") }
    var firmware: String { value("固件", "Firmware") }
    var checkExistingFirmware: String { value("检查现有固件", "Check existing firmware") }
    var complete: String { value("完成", "Complete") }
    var checkAgain: String { value("重新检测", "Check Again") }
    var usbNotDetected: String { value("未检测到 USB 键盘", "USB keyboard not detected") }
    var usbDetected: String { value("USB 设备已确认", "USB device confirmed") }
    var inputMonitoring: String { value("输入监控权限", "Input Monitoring") }
    var allowed: String { value("已允许", "Allowed") }
    var permissionNeeded: String { value("需要允许", "Permission required") }
    var allow: String { value("允许访问", "Allow Access") }
    var inputPrivacy: String { value("NuNuBar 只使用 HID 输出接口向键盘发送状态，不读取或保存按键。", "NuNuBar only uses HID output to send status. It never reads or stores keystrokes.") }
    var airV3OfficialFirmware: String { value("Air V3 使用官方固件自带的有线灯光接口，不进入 DFU，也不会刷写键盘。", "Air V3 uses the wired lighting interface built into its official firmware. It never enters DFU or flashes the keyboard.") }
    var officialFirmwareVersion: String { value("官方固件版本", "Official firmware version") }
    var reading: String { value("读取中", "Reading") }
    var openNuPhyIO: String { value("打开 NuPhyIO 升级", "Open NuPhyIO to update") }
    func air75FirmwareUpdateRequired(_ version: OfficialFirmwareVersion) -> String {
        value(
            "Air75 V3 需要官方固件 \(version) 或更高版本。升级前 NuPhyIO 会备份并在重启后恢复键盘配置。",
            "Air75 V3 requires official firmware \(version) or later. NuPhyIO backs up and restores keyboard configuration during the update."
        )
    }
    var firmwareVersionUnknown: String { value("尚未验证现有固件的状态灯通道", "Existing firmware status-light support is not verified") }
    var startSelfTest: String { value("开始灯光自检", "Start Light Test") }
    var selfTestSent: String { value("橙、绿、红三种状态已发送", "Orange, green, and red states were sent") }
    var compatibilityDetail: String { value("NuNuBar 无法仅凭 USB 型号判断键盘是否已刷兼容固件。先观察现有固件能否显示三种状态；能用就保留，不重复刷写。", "USB identity alone cannot prove that compatible firmware is installed. Test the existing firmware first; keep it when all three states are visible.") }
    var selfTestQuestion: String { value("刚才键盘灯光是否依次显示橙色、绿色和红色？", "Did the keyboard lights show orange, green, and red in sequence?") }
    var selfTestResult: String { value("灯光自检结果", "Light test result") }
    var lightsChanged: String { value("看到了变化", "Lights Changed") }
    var noLightChange: String { value("没有变化", "No Change") }
    var keepExistingFirmware: String { value("现有固件已经兼容 NuNuBar。将跳过 DFU 和刷写，直接接入 Codex。", "The installed firmware is compatible. NuNuBar will skip DFU and flashing and connect Codex directly.") }
    var prepareFirmware: String { value("先排除 USB 与权限问题；仍无变化时，下一步才会准备准确型号的备份、恢复固件和 DFU。", "First rule out USB and permission issues. If lights still do not change, the next step prepares the exact model backup, recovery image, and DFU flow.") }
    var confirmBackup: String { value("我已导出或记录现有 VIA 键位配置", "I exported or recorded my current VIA layout") }
    var confirmTestingFirmware: String { value("我了解这是尚待对应实机验证的测试固件", "I understand this is test firmware awaiting verification on this model") }
    var downloadRecovery: String { value("打开 NuPhy 官方 QMK 固件页", "Open NuPhy's official QMK firmware page") }
    var halolightDetail: String { value("Halo75 V2 会用整圈 Halolight 显示状态，而不是 Air 系列的左右灯条。", "Halo75 V2 uses the full Halolight ring instead of the Air series side bars.") }
    var dfuStepOne: String { value("从 Mac 上拔掉键盘 USB 线。", "Unplug the keyboard's USB cable from the Mac.") }
    var dfuStepTwo: String { value("按住键盘左上角 Esc 键不放。", "Press and hold the top-left Esc key.") }
    var dfuStepThree: String { value("保持按住 Esc 并插回 USB，然后松开。", "Keep holding Esc while reconnecting USB, then release it.") }
    var dfuHint: String { value("进入 DFU 后键盘灯光可能熄灭，这是正常现象。", "The keyboard lights may turn off in DFU mode. This is expected.") }
    var targetKeyboard: String { value("目标键盘", "Target Keyboard") }
    var firmwareVersion: String { value("固件版本", "Firmware Version") }
    var releaseStatus: String { value("验证状态", "Validation") }
    var dfuPath: String { value("DFU 路径", "DFU Path") }
    var flashWarning: String { value("刷写开始后请不要拔线、关闭 App 或让 Mac 休眠。", "Once flashing begins, do not unplug, quit the app, or let the Mac sleep.") }
    var doNotDisconnect: String { value("正在写入固件，请不要拔线", "Writing firmware. Do not disconnect.") }
    var flashingDetail: String { value("NuNuBar 正在校验固件、锁定唯一 DFU 设备并写入 Internal Flash。", "NuNuBar is validating the image, pinning the only DFU device, and writing Internal Flash.") }
    var usbProtocolReady: String { value("USB 状态协议已就绪", "USB status protocol is ready") }
    var reconnectHint: String { value("如未自动恢复，请重新插拔 USB", "Reconnect USB if it does not return automatically") }
    var reconnectDetail: String { value("检测成功后会自动应用蓝、橙、红、绿四种状态预设。", "When detected, NuNuBar applies the blue, orange, red, and green status preset.") }
    var codexStepInstall: String { value("点击“接入 Codex”。NuNuBar 会备份并合并本地 Hooks，不覆盖其他配置。", "Click Connect Codex. NuNuBar backs up and merges its local Hooks without replacing other settings.") }
    var codexStepApprove: String { value("打开 Codex 设置中的 Hooks 待审核项，批准路径以 NuNuBar.app/Contents/Helpers/agent-light 结尾的四个命令。", "Open pending Hooks in Codex Settings and approve the four commands whose path ends in NuNuBar.app/Contents/Helpers/agent-light.") }
    var codexStepVerify: String { value("回到 NuNuBar 点击“重新检测”，看到“已接入”后再继续。", "Return to NuNuBar, click Check Again, and continue after Connected appears.") }
    var codexHookFiles: String { value("将修改 ~/.codex/hooks.json 和 ~/.codex/config.toml。Hooks 只记录任务状态、会话 ID 和时间，不读取提示词或回复。", "NuNuBar updates ~/.codex/hooks.json and ~/.codex/config.toml. Hooks record only task state, session ID, and time; they do not read prompts or responses.") }
    var codexApproval: String { value("Hooks 已写入但尚未获准。完成第 2 步后回到这里点击“重新检测”。", "Hooks are installed but not yet approved. Complete step 2, then return and click Check Again.") }
    var connected: String { value("已接入", "Connected") }
    var readyToConnect: String { value("可以接入", "Ready to connect") }
    var pendingApproval: String { value("等待 Codex 批准", "Waiting for Codex approval") }
    var notDetected: String { value("未检测到", "Not detected") }
    var codexConnected: String { value("Codex 任务状态已会通过本地 Hooks 发给 NuNuBar。", "Codex task status now reaches NuNuBar through local Hooks.") }
    var codexAvailable: String { value("点击“接入 Codex”安装 NuNuBar 管理的本地 Hooks。", "Click Connect Codex to install NuNuBar-managed local Hooks.") }
    var codexNeedsReview: String { value("Hooks 已写入，但 Codex 还需要你亲自批准。", "Hooks are installed, but Codex still needs your approval.") }
    var codexUnavailable: String { value("尚未找到 Codex 配置目录。请先启动一次 Codex。", "No Codex configuration was found. Launch Codex once first.") }
    var idle: String { value("待机", "Idle") }
    var working: String { value("工作中", "Working") }
    var needsConfirmation: String { value("需要确认", "Needs Confirmation") }
    var launchAtLogin: String { value("开机时自动启动 NuNuBar", "Launch NuNuBar at login") }
    var readyDetail: String { value("以后只要 NuNuBar 在运行，Codex 状态就会自动同步到 USB 连接的键盘。", "While NuNuBar is running, Codex status automatically syncs to the keyboard over USB.") }
    var preview: String { value("在键盘上预览", "Preview on Keyboard") }
    var back: String { value("上一步", "Back") }
    var continueText: String { value("继续", "Continue") }
    var detectDFU: String { value("检测 DFU", "Detect DFU") }
    var flashNow: String { value("确认刷入固件", "Confirm and Flash") }
    var flashing: String { value("正在刷写", "Flashing") }
    var checkReconnect: String { value("重新检测 USB", "Check USB Again") }
    var connectCodex: String { value("接入 Codex", "Connect Codex") }
    var continueFirmware: String { value("继续固件设置", "Continue Firmware Setup") }
    var finish: String { value("完成", "Done") }

    func confirmModel(_ displayName: String?) -> String {
        let name = displayName ?? supportedKeyboard
        return value("我确认键盘是 \(name)（美式配列）", "I confirm this is a \(name) keyboard")
    }

    func confirmRecovery(_ displayName: String?) -> String {
        let name = displayName ?? supportedKeyboard
        return value("我已下载 \(name) 的 NuPhy 官方恢复固件", "I downloaded NuPhy's official recovery firmware for \(name)")
    }

    func modelWarning(_ displayName: String?, testing: Bool) -> String {
        let name = displayName ?? supportedKeyboard
        if testing {
            return value(
                "该固件只适用于 \(name)，目前标记为测试版；其他型号或 ISO 配列不能继续。",
                "This test firmware is only for \(name). Other models and ISO layouts must not continue."
            )
        }
        return value(
            "该固件只适用于 \(name)。其他型号或 ISO 配列不能继续。",
            "This firmware is only for \(name). Other models and ISO layouts must not continue."
        )
    }

    func finalFlashConfirmation(_ displayName: String?) -> String {
        let name = displayName ?? supportedKeyboard
        return value("我确认现在刷入上述 \(name) 固件", "I confirm flashing the \(name) firmware shown above")
    }

    func waitingForKeyboard(_ displayName: String?) -> String {
        let name = displayName ?? supportedKeyboard
        return value("等待 \(name) 重新连接", "Waiting for \(name)")
    }

    func releaseStatus(testing: Bool) -> String {
        testing ? value("测试版（待实机验证）", "Testing (hardware verification pending)")
            : value("已在实机验证", "Hardware verified")
    }

    func title(for stage: KeyboardSetupStage) -> String {
        switch stage {
        case .welcome: value("设置新键盘", "Set Up a New Keyboard")
        case .keyboard: value("检查 USB 连接", "Check the USB Connection")
        case .compatibility: value("检查现有灯光通道", "Check Existing Light Support")
        case .confirmation: value("确认型号与备份", "Confirm Model and Backup")
        case .dfu: value("进入 DFU 模式", "Enter DFU Mode")
        case .flashConfirmation: value("最后确认", "Final Confirmation")
        case .flashing: value("正在刷入 NuNuBar 固件", "Installing NuNuBar Firmware")
        case .reconnecting: value("验证键盘", "Verify the Keyboard")
        case .codex: value("接入 Codex", "Connect Codex")
        case .complete: value("设置完成", "Setup Complete")
        }
    }

    func subtitle(for stage: KeyboardSetupStage) -> String {
        switch stage {
        case .welcome: value("适用于 Apple Silicon Mac、Air65 V3 和四款 NuPhy V2 ANSI 键盘", "For Apple Silicon Macs, Air65 V3, and four NuPhy V2 ANSI models")
        case .keyboard: value("确保键盘使用 USB 数据线并切到有线模式", "Use a USB data cable and switch the keyboard to wired mode")
        case .compatibility: value("能正常显示状态就保留现有固件，不重复刷写", "Keep the installed firmware when status lighting already works")
        case .confirmation: value("固件严格区分型号和配列", "Firmware is specific to the exact model and layout")
        case .dfu: value("这一步需要你在键盘上手动操作", "This step requires a manual action on the keyboard")
        case .flashConfirmation: value("检查目标、固件和 DFU 路径", "Review the target, firmware, and DFU path")
        case .flashing: value("写入期间窗口不能关闭", "The window cannot be closed while writing")
        case .reconnecting: value("验证自定义 USB 状态协议", "Verifying the custom USB status protocol")
        case .codex: value("仅在本机安装状态 Hooks，不读取对话内容", "Installs local status Hooks without reading conversation content")
        case .complete: value("你可以逐个预览四种状态", "Preview each of the four states")
        }
    }

    func effect(_ effect: AgentLightEffect) -> String {
        switch effect {
        case .solid: value("常亮", "Solid")
        case .breathe: value("呼吸", "Breathe")
        case .blink: value("闪烁", "Blink")
        }
    }
}
