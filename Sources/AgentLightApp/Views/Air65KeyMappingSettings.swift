import AppKit
import SwiftUI

struct NuPhyKeyMappingSettings: View {
    private enum PendingChange {
        case save(Air65KeyMapping)
        case remove(Air65KeyMapping)
    }

    @Environment(\.appLanguage) private var language
    @State private var selectedKeyID: String
    @State private var selectedKnobControlID: String
    @State private var selectedAction: Air65MappingAction
    @State private var mappings: [String: Air65KeyMapping] = [:]
    @State private var status = Air65FnShortcutStatus.checking
    @State private var proposedBackupURL: URL?
    @State private var pendingChange: PendingChange?
    @State private var showsMappingConfirmation = false
    @State private var notice: String?
    @State private var noticeIsError = false
    @State private var inputMonitor = Air65InputMonitor()
    @State private var isInputTestRunning = false
    @State private var observedInput: Air65ObservedInput?
    @State private var inputTestTimedOut = false

    let profile: NuPhyKeyboardMappingProfile
    private let service: Air65FnShortcutService

    init(profile: NuPhyKeyboardMappingProfile) {
        self.profile = profile
        service = Air65FnShortcutService(profile: profile)
        _selectedKeyID = State(initialValue: profile.initialKeyID)
        _selectedKnobControlID = State(initialValue: Air65KeyboardLayout.knobPressKeyID)
        _selectedAction = State(initialValue: .fnGlobe)
    }

    var body: some View {
        Group {
            SettingsGroup(title: language == .simplifiedChinese ? "按键映射" : "Key Mapping") {
                NuPhyKeyboardLayoutView(
                    profile: profile,
                    selection: $selectedKeyID,
                    mappedKeyIDs: mappedPhysicalKeyIDs
                )
                .padding(.top, 2)

                mappingEditor
            }

            if let notice {
                SettingsNotice(text: notice, isError: noticeIsError)
            }
        }
        .task { refresh() }
        .onChange(of: selectedKeyID) {
            stopInputTest()
            selectedAction = currentMapping?.action ?? .fnGlobe
            notice = nil
        }
        .onChange(of: selectedKnobControlID) {
            stopInputTest()
            selectedAction = currentMapping?.action ?? .fnGlobe
            notice = nil
        }
        .onDisappear { inputMonitor.stop() }
        .alert(confirmationTitle, isPresented: $showsMappingConfirmation) {
            Button(language == .simplifiedChinese ? "取消" : "Cancel", role: .cancel) {}
            Button(
                confirmationButtonTitle,
                role: isRemoving ? .destructive : nil
            ) {
                applyPendingChange()
            }
        } message: {
            Text(confirmationMessage)
        }
    }

    @ViewBuilder
    private var mappingEditor: some View {
        VStack(spacing: 4) {
            if selectedKeyID == Air65KeyboardLayout.knobKeyID {
                Picker(
                    language == .simplifiedChinese ? "旋钮动作" : "Knob Control",
                    selection: $selectedKnobControlID
                ) {
                    ForEach(profile.knobControls) { control in
                        Text(knobControlTitle(control.id)).tag(control.id)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.top, 6)
            }

            if let activeKey, let defaultInput = activeKey.inputKeyCode {
                editableMapping(for: activeKey, defaultInput: defaultInput)
            } else {
                unsupportedControl
            }
        }
    }

    private func editableMapping(
        for key: Air65KeyboardKey,
        defaultInput: String
    ) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 9) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(keyDisplayName(key.id))
                        .font(.system(size: SettingsLayout.primaryTextSize, weight: .semibold))
                    Text(mappingStateText)
                        .font(.system(size: SettingsLayout.secondaryTextSize))
                        .foregroundStyle(NuphyBarTheme.secondaryText)
                }

                Spacer(minLength: 8)

                Picker(language == .simplifiedChinese ? "映射为" : "Map to", selection: $selectedAction) {
                    Section(language == .simplifiedChinese ? "系统动作" : "System") {
                        ForEach(Air65MappingAction.systemActions) { action in
                            Text(actionTitle(action)).tag(action)
                        }
                    }
                    Section("Codex") {
                        ForEach(Air65MappingAction.codexActions) { action in
                            Text(actionTitle(action)).tag(action)
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 172)
                .controlSize(.small)

                mappingActionButton(defaultInput: defaultInput, keyID: key.id)
            }

            HStack(spacing: 8) {
                Label(mappingScopeText, systemImage: selectedAction.isCodexAction ? "app.badge" : "info.circle")
                    .font(.system(size: SettingsLayout.secondaryTextSize))
                    .foregroundStyle(NuphyBarTheme.secondaryText)

                Spacer()

                Text(inputEventText(currentMapping?.inputKeyCode ?? defaultInput))
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(NuphyBarTheme.tertiaryText)
                    .help(language == .simplifiedChinese ? "当前输入事件" : "Current input event")

                if isFunctionCarrier(currentMapping?.inputKeyCode ?? defaultInput) {
                    Button {
                        startInputTest()
                    } label: {
                        Image(systemName: isInputTestRunning ? "waveform" : "waveform.path.ecg")
                    }
                    .buttonStyle(.borderless)
                    .disabled(isInputTestRunning)
                    .help(language == .simplifiedChinese ? "实测当前输入事件" : "Test Current Input")
                }

                Button {
                    NSWorkspace.shared.open(Air65FnShortcutService.nuphyIOURL(
                        languageCode: language == .simplifiedChinese ? "zh-CN" : "en-US"
                    ))
                } label: {
                    Image(systemName: "keyboard.badge.ellipsis")
                }
                .buttonStyle(.borderless)
                .help(language == .simplifiedChinese ? "打开 NuPhyIO 2.0" : "Open NuPhyIO 2.0")

                if let currentMapping {
                    Button(role: .destructive) {
                        prepare(.remove(currentMapping))
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help(language == .simplifiedChinese ? "删除映射" : "Delete Mapping")
                }
            }

            if let inputTestStatus = inputTestStatus(expectedInput: currentMapping?.inputKeyCode ?? defaultInput) {
                HStack(spacing: 6) {
                    Image(systemName: inputTestStatus.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    Text(inputTestStatus.text)
                    Spacer(minLength: 0)
                }
                .font(.system(size: SettingsLayout.secondaryTextSize))
                .foregroundStyle(inputTestStatus.isSuccess ? Color.green : Color.orange)
            }
        }
        .padding(.vertical, 7)
    }

    private var unsupportedControl: some View {
        HStack(spacing: 9) {
            Image(systemName: "keyboard")
                .font(.system(size: 15))
                .foregroundStyle(NuphyBarTheme.secondaryText)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(selectedKey?.legend ?? "-")
                    .font(.system(size: SettingsLayout.primaryTextSize, weight: .medium))
                Text(language == .simplifiedChinese
                     ? "该控件目前不能作为标准按键事件创建映射"
                     : "This control cannot be mapped as a standard key event yet")
                    .font(.system(size: SettingsLayout.secondaryTextSize))
                    .foregroundStyle(NuphyBarTheme.secondaryText)
            }
            Spacer()
        }
        .frame(minHeight: 48)
    }

    @ViewBuilder
    private func mappingActionButton(defaultInput: String, keyID: String) -> some View {
        switch status {
        case .checking:
            ProgressView()
                .controlSize(.small)
                .frame(width: 62)
        case .karabinerNotInstalled:
            Button(language == .simplifiedChinese ? "安装组件" : "Install") {
                NSWorkspace.shared.open(Air65FnShortcutService.karabinerDownloadURL)
            }
            .controlSize(.small)
        case .karabinerSetupRequired:
            Button(language == .simplifiedChinese ? "完成授权" : "Authorize") {
                service.openKarabiner()
            }
            .controlSize(.small)
        case .mappingMissing, .ready:
            Button(currentMapping == nil
                   ? (language == .simplifiedChinese ? "创建" : "Create")
                   : (language == .simplifiedChinese ? "更新" : "Update")) {
                let input = currentMapping?.inputKeyCode ?? defaultInput
                prepare(.save(Air65KeyMapping(
                    keyID: keyID,
                    inputKeyCode: input,
                    action: selectedAction
                )))
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .disabled(currentMapping?.action == selectedAction)
        }
    }

    private var selectedKey: Air65KeyboardKey? {
        profile.key(id: selectedKeyID)
    }

    private var activeKey: Air65KeyboardKey? {
        if selectedKeyID == Air65KeyboardLayout.knobKeyID {
            return profile.key(id: selectedKnobControlID)
        }
        return selectedKey
    }

    private var activeKeyID: String {
        activeKey?.id ?? selectedKeyID
    }

    private var currentMapping: Air65KeyMapping? {
        mappings[activeKeyID]
    }

    private var mappedPhysicalKeyIDs: Set<String> {
        var result = Set(mappings.keys)
        if profile.knobControls.contains(where: { mappings[$0.id] != nil }) {
            result.insert(Air65KeyboardLayout.knobKeyID)
        }
        return result
    }

    private var mappingStateText: String {
        if let currentMapping {
            return language == .simplifiedChinese
                ? "当前映射：\(actionTitle(currentMapping.action))"
                : "Current: \(actionTitle(currentMapping.action))"
        }
        return language == .simplifiedChinese ? "尚未创建映射" : "No mapping"
    }

    private func actionTitle(_ action: Air65MappingAction) -> String {
        switch (language, action) {
        case (.simplifiedChinese, .fnGlobe): "Fn / 地球键"
        case (.english, .fnGlobe): "Fn / Globe"
        case (.simplifiedChinese, .escape): "Esc"
        case (.english, .escape): "Escape"
        case (.simplifiedChinese, .returnOrEnter): "回车"
        case (.english, .returnOrEnter): "Return"
        case (.simplifiedChinese, .deleteOrBackspace): "退格"
        case (.english, .deleteOrBackspace): "Backspace"
        case (.simplifiedChinese, .pageUp): "上一页"
        case (.english, .pageUp): "Page Up"
        case (.simplifiedChinese, .pageDown): "下一页"
        case (.english, .pageDown): "Page Down"
        case (.simplifiedChinese, .home): "Home"
        case (.english, .home): "Home"
        case (.simplifiedChinese, .end): "End"
        case (.english, .end): "End"
        case (.simplifiedChinese, .playPause): "播放 / 暂停"
        case (.english, .playPause): "Play / Pause"
        case (.simplifiedChinese, .mute): "静音"
        case (.english, .mute): "Mute"
        case (.simplifiedChinese, .volumeDown): "降低音量"
        case (.english, .volumeDown): "Volume Down"
        case (.simplifiedChinese, .volumeUp): "提高音量"
        case (.english, .volumeUp): "Volume Up"
        case (.simplifiedChinese, .codexNewTask): "Codex · 新建任务"
        case (.english, .codexNewTask): "Codex · New Task"
        case (.simplifiedChinese, .codexToggleSidebar): "Codex · 侧边栏"
        case (.english, .codexToggleSidebar): "Codex · Toggle Sidebar"
        case (.simplifiedChinese, .codexToggleBottomPanel): "Codex · 底部面板"
        case (.english, .codexToggleBottomPanel): "Codex · Bottom Panel"
        case (.simplifiedChinese, .codexToggleFileTree): "Codex · 文件树"
        case (.english, .codexToggleFileTree): "Codex · File Tree"
        case (.simplifiedChinese, .codexToggleReviewPanel): "Codex · Review 面板"
        case (.english, .codexToggleReviewPanel): "Codex · Review Panel"
        case (.simplifiedChinese, .codexOpenTerminal): "Codex · 终端"
        case (.english, .codexOpenTerminal): "Codex · Terminal"
        case (.simplifiedChinese, .codexOpenBrowserTab): "Codex · 浏览器"
        case (.english, .codexOpenBrowserTab): "Codex · Browser Tab"
        case (.simplifiedChinese, .codexPreviousTask): "Codex · 上一个任务"
        case (.english, .codexPreviousTask): "Codex · Previous Task"
        case (.simplifiedChinese, .codexNextTask): "Codex · 下一个任务"
        case (.english, .codexNextTask): "Codex · Next Task"
        case (.simplifiedChinese, .codexKeyboardShortcuts): "Codex · 快捷键"
        case (.english, .codexKeyboardShortcuts): "Codex · Shortcuts"
        case (.simplifiedChinese, .codexSettings): "Codex · 设置"
        case (.english, .codexSettings): "Codex · Settings"
        }
    }

    private var mappingScopeText: String {
        if selectedAction.isCodexAction {
            return language == .simplifiedChinese
                ? "仅在 Codex 位于前台时触发"
                : "Active only while Codex is frontmost"
        }
        return language == .simplifiedChinese
            ? "映射后会替代这颗键的原功能"
            : "Mapping replaces this key's original action"
    }

    private func knobControlTitle(_ keyID: String) -> String {
        switch (language, keyID) {
        case (.simplifiedChinese, Air65KeyboardLayout.knobLeftKeyID): "左旋"
        case (.english, Air65KeyboardLayout.knobLeftKeyID): "Left"
        case (.simplifiedChinese, Air65KeyboardLayout.knobPressKeyID): "按下"
        case (.english, Air65KeyboardLayout.knobPressKeyID): "Press"
        case (.simplifiedChinese, Air65KeyboardLayout.knobRightKeyID): "右旋"
        case (.english, Air65KeyboardLayout.knobRightKeyID): "Right"
        default: keyID
        }
    }

    private func keyDisplayName(_ keyID: String) -> String {
        if profile.knobControls.contains(where: { $0.id == keyID }) {
            return "KNOB · \(knobControlTitle(keyID))"
        }
        return profile.key(id: keyID)?.legend ?? keyID
    }

    private func inputEventText(_ input: String) -> String {
        language == .simplifiedChinese ? "输入：\(input.uppercased())" : "Input: \(input.uppercased())"
    }

    private func isFunctionCarrier(_ input: String) -> Bool {
        let value = input.lowercased()
        guard value.first == "f", let number = Int(value.dropFirst()) else { return false }
        return (1...35).contains(number)
    }

    private func startInputTest() {
        observedInput = nil
        inputTestTimedOut = false
        isInputTestRunning = true
        inputMonitor.start { observed in
            observedInput = observed
            isInputTestRunning = false
        } timeout: {
            inputTestTimedOut = true
            isInputTestRunning = false
        }
    }

    private func stopInputTest() {
        inputMonitor.stop()
        isInputTestRunning = false
        observedInput = nil
        inputTestTimedOut = false
    }

    private func inputTestStatus(expectedInput: String) -> (text: String, isSuccess: Bool)? {
        if isInputTestRunning {
            return (
                language == .simplifiedChinese
                    ? "等待 \(expectedInput.uppercased()) 输入"
                    : "Waiting for \(expectedInput.uppercased()) input",
                true
            )
        }
        if inputTestTimedOut {
            return (
                language == .simplifiedChinese ? "未检测到功能键输入" : "No function-key input detected",
                false
            )
        }
        guard let observedInput else { return nil }

        if observedInput.keyCode == expectedInput.lowercased() {
            return (
                language == .simplifiedChinese
                    ? "检测到 \(expectedInput.uppercased())，输入正确"
                    : "Detected \(expectedInput.uppercased()); input is correct",
                true
            )
        }
        if observedInput == .fnGlobe,
           expectedInput.caseInsensitiveCompare("f24") == .orderedSame,
           currentMapping?.action == .fnGlobe {
            return (
                language == .simplifiedChinese
                    ? "检测到 Fn / 地球键，映射已生效"
                    : "Detected Fn / Globe; mapping is active",
                true
            )
        }

        let observed = observedInput == .fnGlobe
            ? (language == .simplifiedChinese ? "Fn / 地球键" : "Fn / Globe")
            : observedInput.keyCode.uppercased()
        return (
            language == .simplifiedChinese
                ? "检测到 \(observed)，期望 \(expectedInput.uppercased())"
                : "Detected \(observed); expected \(expectedInput.uppercased())",
            false
        )
    }

    private var isRemoving: Bool {
        if case .remove = pendingChange { return true }
        return false
    }

    private var confirmationTitle: String {
        isRemoving
            ? (language == .simplifiedChinese ? "删除按键映射？" : "Delete Key Mapping?")
            : (language == .simplifiedChinese ? "保存按键映射？" : "Save Key Mapping?")
    }

    private var confirmationButtonTitle: String {
        isRemoving
            ? (language == .simplifiedChinese ? "删除" : "Delete")
            : (language == .simplifiedChinese ? "保存" : "Save")
    }

    private var confirmationMessage: String {
        let configPath = service.configURL.path
        let backupPath = proposedBackupURL?.path ?? "-"
        let operation: String
        switch pendingChange {
        case .save(let mapping):
            let key = keyDisplayName(mapping.keyID)
            operation = language == .simplifiedChinese
                ? "将 \(key) 映射为 \(actionTitle(mapping.action))。"
                : "Map \(key) to \(actionTitle(mapping.action))."
        case .remove(let mapping):
            let key = keyDisplayName(mapping.keyID)
            operation = language == .simplifiedChinese
                ? "删除 \(key) 的 NuNuBar 映射。"
                : "Delete the NuNuBar mapping for \(key)."
        case nil:
            operation = ""
        }
        if language == .simplifiedChinese {
            return "将修改：\(configPath)\n备份至：\(backupPath)\n\(operation)其他 Karabiner 配置保持不变。"
        }
        return "Modify: \(configPath)\nBackup: \(backupPath)\n\(operation) Other Karabiner settings are preserved."
    }

    private func refresh() {
        status = .checking
        let service = service
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                let status = service.status()
                let mappings = (try? service.configuredMappings()) ?? []
                return (status, mappings)
            }.value
            status = result.0
            mappings = Dictionary(uniqueKeysWithValues: result.1.map { ($0.keyID, $0) })
            selectedAction = currentMapping?.action ?? .fnGlobe
        }
    }

    private func prepare(_ change: PendingChange) {
        pendingChange = change
        proposedBackupURL = service.proposedBackupURL()
        showsMappingConfirmation = true
    }

    private func applyPendingChange() {
        guard let proposedBackupURL, let pendingChange else { return }
        do {
            switch pendingChange {
            case .save(let mapping):
                try service.installMapping(mapping, backupURL: proposedBackupURL)
                notice = language == .simplifiedChinese
                    ? "映射已保存并完成备份。"
                    : "Mapping saved with a backup."
            case .remove(let mapping):
                try service.removeMapping(for: mapping.keyID, backupURL: proposedBackupURL)
                notice = language == .simplifiedChinese
                    ? "映射已删除并完成备份。"
                    : "Mapping deleted with a backup."
            }
            noticeIsError = false
        } catch {
            notice = error.localizedDescription
            noticeIsError = true
        }
        self.pendingChange = nil
        refresh()
    }
}

struct Air65KeyMappingSettings: View {
    var body: some View {
        NuPhyKeyMappingSettings(profile: .air65V3)
    }
}
