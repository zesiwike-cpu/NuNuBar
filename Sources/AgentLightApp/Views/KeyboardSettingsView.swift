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
            if let firmwareError = model.airV3FirmwareError {
                SettingsNotice(text: firmwareError, isError: true)
            }

            if let officialAirV3Profile {
                SettingsNotice(text: officialFirmwareSummary(officialAirV3Profile))
                if officialFirmwareNeedsUpdate(officialAirV3Profile) {
                    SettingsNotice(
                        text: language == .simplifiedChinese
                            ? "Air75 V3 需要升级到官方固件 \(officialAirV3Profile.minimumFirmwareVersion!) 或更高版本，才能可靠应用侧灯状态。"
                            : "Air75 V3 requires official firmware \(officialAirV3Profile.minimumFirmwareVersion!) or later to apply side-light states reliably.",
                        isError: true
                    )
                    Link(destination: URL(string: "https://drive.nuphy.io")!) {
                        Label(
                            language == .simplifiedChinese ? "打开 NuPhyIO 升级" : "Open NuPhyIO to update",
                            systemImage: "arrow.up.circle"
                        )
                    }
                    .font(.system(size: SettingsLayout.actionTextSize))
                }
            }

            if let mappingProfile {
                NuPhyKeyMappingSettings(profile: mappingProfile)
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

    private var mappingProfile: NuPhyKeyboardMappingProfile? {
        guard model.isConnected,
              model.keyboardTransport == .usb,
              let keyboardModel = model.keyboardModel else { return nil }
        return NuPhyKeyboardMappingProfile.allCases.first {
            keyboardModel.caseInsensitiveCompare($0.productName) == .orderedSame
        }
    }

    private var officialAirV3Profile: OfficialKeyboardProfile? {
        guard model.isConnected,
              model.keyboardTransport == .usb,
              let keyboardModel = model.keyboardModel else { return nil }
        return SupportedOfficialNuPhyKeyboard.models.first {
            keyboardModel.caseInsensitiveCompare($0.productName) == .orderedSame
        }
    }

    private func officialFirmwareNeedsUpdate(_ profile: OfficialKeyboardProfile) -> Bool {
        guard let minimum = profile.minimumFirmwareVersion,
              let installed = model.airV3FirmwareVersion else { return false }
        return installed < minimum
    }

    private func officialFirmwareSummary(_ profile: OfficialKeyboardProfile) -> String {
        let mode = model.air65CurrentMode.map(String.init) ?? (language == .simplifiedChinese ? "读取中" : "reading")
        let version = model.airV3FirmwareVersion?.description
            ?? (profile.minimumFirmwareVersion == nil ? nil : (language == .simplifiedChinese ? "读取中" : "reading"))
        if language == .simplifiedChinese {
            return "\(profile.productName) 使用官方有线控制接口。固件：\(version ?? "官方")；活动灯光配置：\(mode)。"
        }
        return "\(profile.productName) uses its official wired control interface. Firmware: \(version ?? "official"); active light profile: \(mode)."
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
