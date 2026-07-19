import AgentLightHID
import SwiftUI

struct KeyboardSettingsView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var model: AppModel

    var body: some View {
        SettingsPage {
            SettingsGroup(title: language.text(.connectionStatus)) {
                HStack(spacing: 9) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(NuphyBarTheme.secondaryText)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(keyboardName)
                            .font(.system(size: SettingsLayout.primaryTextSize, weight: .medium))
                        HStack(spacing: 5) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 6, height: 6)
                            Text(statusText)
                                .font(.system(size: SettingsLayout.secondaryTextSize))
                                .foregroundStyle(NuphyBarTheme.secondaryText)
                        }
                    }

                    Spacer()

                    if model.hidAccessState == .granted {
                        Button(language.text(.checkAgain)) { model.refreshConnection() }
                            .font(.system(size: SettingsLayout.actionTextSize))
                            .controlSize(.small)
                    } else {
                        Button(language.text(.allowAccess)) { model.requestHIDAccess() }
                            .font(.system(size: SettingsLayout.actionTextSize))
                            .controlSize(.small)
                            .buttonStyle(.borderedProminent)
                    }
                }
                .frame(height: 44)
            }

            if let keyboardError = model.keyboardError {
                SettingsNotice(text: keyboardError, isError: true)
            }

            if isAir65V3Connected {
                SettingsNotice(text: language == .simplifiedChinese
                    ? "Air65 V3 使用官方有线控制接口，无需刷写固件。活动灯光配置：\(model.air65CurrentMode.map(String.init) ?? "读取中")。"
                    : "Air65 V3 uses its official wired control interface with no firmware flashing. Active light profile: \(model.air65CurrentMode.map(String.init) ?? "reading").")

                Air65KeyMappingSettings()
            }

            if model.keyboardTransport == .usb {
                SettingsGroup(title: language == .simplifiedChinese ? "灯光自检" : "Light self-test") {
                    HStack {
                        Text(language == .simplifiedChinese
                             ? "依次显示工作中、完成和需要确认"
                             : "Show working, complete, and waiting in sequence")
                            .font(.system(size: SettingsLayout.secondaryTextSize))
                            .foregroundStyle(NuphyBarTheme.secondaryText)
                        Spacer()
                        Button {
                            model.runKeyboardSelfTest()
                        } label: {
                            if model.isKeyboardSelfTestRunning {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label(language == .simplifiedChinese ? "开始" : "Start", systemImage: "play.fill")
                            }
                        }
                        .font(.system(size: SettingsLayout.actionTextSize))
                        .controlSize(.small)
                        .disabled(!model.canRunKeyboardSelfTest)
                    }
                    .frame(height: SettingsLayout.agentRowHeight)
                }
            }

            if model.hasCompletedKeyboardSelfTest {
                SettingsNotice(text: language == .simplifiedChinese
                    ? "三种状态已发送并恢复当前 Codex 状态，请确认键盘灯光均可见。"
                    : "All three states were sent and the current Codex state was restored. Confirm that each light was visible.")
            }

            SettingsGroup(title: language.text(.setupNewKeyboard)) {
                HStack {
                    Text(language == .simplifiedChinese
                         ? "检测兼容的 NuPhy 键盘、按型号完成设置并接入 Codex"
                         : "Detect a compatible NuPhy keyboard, finish model-specific setup, and connect Codex")
                        .font(.system(size: SettingsLayout.secondaryTextSize))
                        .foregroundStyle(NuphyBarTheme.secondaryText)
                    Spacer()
                    Button(language.text(.setupNewKeyboard)) {
                        NotificationCenter.default.post(name: .nuphyBarOpenKeyboardSetup, object: nil)
                    }
                    .font(.system(size: SettingsLayout.actionTextSize))
                    .controlSize(.small)
                }
                .frame(height: SettingsLayout.agentRowHeight)
            }
        }
    }

    private var keyboardName: String {
        model.keyboardModel ?? language.text(.nuphyKeyboard)
    }

    private var isAir65V3Connected: Bool {
        model.isConnected
            && model.keyboardTransport == .usb
            && model.keyboardModel?.caseInsensitiveCompare("Air65 V3") == .orderedSame
    }

    private var statusColor: Color {
        if model.isConnected { return .green }
        if model.hidAccessState == .granted { return .orange }
        return .red
    }

    private var statusText: String {
        if model.isConnected {
            return model.keyboardTransport == .usb
                ? language.text(.usbConnected)
                : language.text(.bluetoothConnected)
        }
        switch model.hidAccessState {
        case .unknown: return language.text(.checkingKeyboard)
        case .denied: return language.text(.accessRequired)
        case .granted: return language.text(.keyboardNotFound)
        }
    }
}
