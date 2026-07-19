import Foundation
import SwiftUI

enum AppText {
    case settings
    case quit
    case window
    case closeWindow
    case agentTab
    case keyboardTab
    case lightsTab
    case aboutTab
    case agentIntegrations
    case codexSync
    case otherAgents
    case codexHooksExplanation
    case codexApprovalRequired
    case unavailable
    case connect
    case pending
    case remove
    case connected
    case connectionStatus
    case lightStatus
    case lightSettings
    case agentSettings
    case setupNewKeyboard
    case customStatusColors
    case statusDurations
    case completionDuration
    case errorDuration
    case workingTimeout
    case waitingTimeout
    case secondsUnit
    case minutesUnit
    case timingHint
    case usbColorHint
    case restoreDefaults
    case usbRequiredForCustomColors
    case idleBehavior
    case previewColor
    case effectStyle
    case solidEffect
    case breatheEffect
    case blinkEffect
    case workingColor
    case waitingColor
    case completeColor
    case idleColor
    case notConnected
    case bluetoothConnected
    case usbConnected
    case checkAgain
    case allowAccess
    case nuphyKeyboard
    case checkingKeyboard
    case accessRequired
    case keyboardNotFound
    case working
    case blueFlow
    case waiting
    case amberFlash
    case taskComplete
    case greenBreath
    case idle
    case factoryEffect
    case language
    case launchAtLogin
    case launchAtLoginApproval
    case launchAtLoginFailed
    case aboutDescription
}

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "appLanguage"

    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static var current: AppLanguage {
        guard let rawValue = UserDefaults.standard.string(forKey: storageKey),
              let language = AppLanguage(rawValue: rawValue) else {
            return .simplifiedChinese
        }
        return language
    }

    func text(_ key: AppText) -> String {
        switch (self, key) {
        case (.simplifiedChinese, .settings): "设置"
        case (.english, .settings): "Settings"
        case (.simplifiedChinese, .quit): "退出"
        case (.english, .quit): "Quit"
        case (.simplifiedChinese, .window): "窗口"
        case (.english, .window): "Window"
        case (.simplifiedChinese, .closeWindow): "关闭窗口"
        case (.english, .closeWindow): "Close Window"
        case (.simplifiedChinese, .agentTab): "Agent"
        case (.english, .agentTab): "Agent"
        case (.simplifiedChinese, .keyboardTab): "键盘"
        case (.english, .keyboardTab): "Keyboard"
        case (.simplifiedChinese, .lightsTab): "灯光"
        case (.english, .lightsTab): "Lights"
        case (.simplifiedChinese, .aboutTab): "关于"
        case (.english, .aboutTab): "About"
        case (.simplifiedChinese, .agentIntegrations): "Agent 接入"
        case (.english, .agentIntegrations): "Agent Integrations"
        case (.simplifiedChinese, .codexSync): "Codex 自动同步"
        case (.english, .codexSync): "Codex Sync"
        case (.simplifiedChinese, .otherAgents): "其他 Agent"
        case (.english, .otherAgents): "Other Agents"
        case (.simplifiedChinese, .codexHooksExplanation):
            "接入后会备份并合并 ~/.codex/hooks.json，同时在 ~/.codex/config.toml 中启用 Hooks；其他配置不会被覆盖。"
        case (.english, .codexHooksExplanation):
            "Connecting backs up and merges ~/.codex/hooks.json and enables Hooks in ~/.codex/config.toml without replacing unrelated settings."
        case (.simplifiedChinese, .codexApprovalRequired):
            "打开 Codex 设置中的 Hooks 待审核项，批准命令路径以 NuNuBar.app/Contents/Helpers/agent-light 结尾的四个 Hooks，然后回到这里重新检测。"
        case (.english, .codexApprovalRequired):
            "In Codex Settings, review pending Hooks and approve the four commands whose path ends in NuNuBar.app/Contents/Helpers/agent-light, then return and check again."
        case (.simplifiedChinese, .unavailable): "未检测到"
        case (.english, .unavailable): "Not Found"
        case (.simplifiedChinese, .connect): "接入"
        case (.english, .connect): "Connect"
        case (.simplifiedChinese, .pending): "待确认"
        case (.english, .pending): "Pending"
        case (.simplifiedChinese, .remove): "移除"
        case (.english, .remove): "Remove"
        case (.simplifiedChinese, .connected): "已接入"
        case (.english, .connected): "Connected"
        case (.simplifiedChinese, .connectionStatus): "连接状态"
        case (.english, .connectionStatus): "Connection"
        case (.simplifiedChinese, .lightStatus): "灯光状态"
        case (.english, .lightStatus): "Light Status"
        case (.simplifiedChinese, .lightSettings): "灯光设置…"
        case (.english, .lightSettings): "Light Settings…"
        case (.simplifiedChinese, .agentSettings): "Agent 接入…"
        case (.english, .agentSettings): "Agent Integrations…"
        case (.simplifiedChinese, .setupNewKeyboard): "设置新键盘…"
        case (.english, .setupNewKeyboard): "Set Up New Keyboard…"
        case (.simplifiedChinese, .customStatusColors): "状态灯光"
        case (.english, .customStatusColors): "Status Lights"
        case (.simplifiedChinese, .statusDurations): "状态显示时间"
        case (.english, .statusDurations): "Status Durations"
        case (.simplifiedChinese, .completionDuration): "任务完成"
        case (.english, .completionDuration): "Complete"
        case (.simplifiedChinese, .errorDuration): "错误提示"
        case (.english, .errorDuration): "Error"
        case (.simplifiedChinese, .workingTimeout): "工作中最长保留"
        case (.english, .workingTimeout): "Working Timeout"
        case (.simplifiedChinese, .waitingTimeout): "需要确认最长保留"
        case (.english, .waitingTimeout): "Confirmation Timeout"
        case (.simplifiedChinese, .secondsUnit): "秒"
        case (.english, .secondsUnit): "sec"
        case (.simplifiedChinese, .minutesUnit): "分钟"
        case (.english, .minutesUnit): "min"
        case (.simplifiedChinese, .timingHint): "工作中和需要确认会随新状态自动续期；待机持续到下一个任务。"
        case (.english, .timingHint): "Working and confirmation timers renew on new events. Idle lasts until the next task."
        case (.simplifiedChinese, .usbColorHint): "颜色或灯效变更后会在键盘上预览 3 秒"
        case (.english, .usbColorHint): "Changes preview on the keyboard for 3 seconds"
        case (.simplifiedChinese, .restoreDefaults): "恢复默认"
        case (.english, .restoreDefaults): "Restore Defaults"
        case (.simplifiedChinese, .usbRequiredForCustomColors): "自定义颜色、灯效和待机显示需要兼容的 NuPhy 固件并通过 USB 有线连接；蓝牙继续使用固件默认灯光。"
        case (.english, .usbRequiredForCustomColors): "Custom colors, effects, and idle lighting require compatible NuPhy firmware over USB. Bluetooth keeps the firmware defaults."
        case (.simplifiedChinese, .idleBehavior): "空闲状态"
        case (.english, .idleBehavior): "Idle Behavior"
        case (.simplifiedChinese, .previewColor): "在键盘上预览"
        case (.english, .previewColor): "Preview on Keyboard"
        case (.simplifiedChinese, .effectStyle): "灯效"
        case (.english, .effectStyle): "Effect"
        case (.simplifiedChinese, .solidEffect): "常亮"
        case (.english, .solidEffect): "Solid"
        case (.simplifiedChinese, .breatheEffect): "呼吸"
        case (.english, .breatheEffect): "Breathe"
        case (.simplifiedChinese, .blinkEffect): "闪烁"
        case (.english, .blinkEffect): "Blink"
        case (.simplifiedChinese, .workingColor): "工作中颜色…"
        case (.english, .workingColor): "Working Color…"
        case (.simplifiedChinese, .waitingColor): "需要确认颜色…"
        case (.english, .waitingColor): "Needs Confirmation Color…"
        case (.simplifiedChinese, .completeColor): "完成颜色…"
        case (.english, .completeColor): "Complete Color…"
        case (.simplifiedChinese, .idleColor): "待机颜色…"
        case (.english, .idleColor): "Idle Color…"
        case (.simplifiedChinese, .notConnected): "键盘未连接"
        case (.english, .notConnected): "Keyboard Not Connected"
        case (.simplifiedChinese, .bluetoothConnected): "蓝牙已连接"
        case (.english, .bluetoothConnected): "Bluetooth Connected"
        case (.simplifiedChinese, .usbConnected): "USB 有线已连接"
        case (.english, .usbConnected): "USB Connected"
        case (.simplifiedChinese, .checkAgain): "重新检测"
        case (.english, .checkAgain): "Check Again"
        case (.simplifiedChinese, .allowAccess): "允许访问"
        case (.english, .allowAccess): "Allow Access"
        case (.simplifiedChinese, .nuphyKeyboard): "NuPhy 键盘"
        case (.english, .nuphyKeyboard): "NuPhy Keyboard"
        case (.simplifiedChinese, .checkingKeyboard): "正在检查键盘…"
        case (.english, .checkingKeyboard): "Checking keyboard…"
        case (.simplifiedChinese, .accessRequired): "需要键盘访问权限"
        case (.english, .accessRequired): "Keyboard access required"
        case (.simplifiedChinese, .keyboardNotFound): "未找到兼容的 NuPhy 键盘"
        case (.english, .keyboardNotFound): "No compatible NuPhy keyboard found"
        case (.simplifiedChinese, .working): "工作中"
        case (.english, .working): "Working"
        case (.simplifiedChinese, .blueFlow): "橙色流光"
        case (.english, .blueFlow): "Orange Flow"
        case (.simplifiedChinese, .waiting): "等待操作"
        case (.english, .waiting): "Waiting"
        case (.simplifiedChinese, .amberFlash): "红色闪烁"
        case (.english, .amberFlash): "Red Flash"
        case (.simplifiedChinese, .taskComplete): "任务完成"
        case (.english, .taskComplete): "Complete"
        case (.simplifiedChinese, .greenBreath): "绿色常亮"
        case (.english, .greenBreath): "Solid Green"
        case (.simplifiedChinese, .idle): "待机"
        case (.english, .idle): "Idle"
        case (.simplifiedChinese, .factoryEffect): "恢复原厂灯效"
        case (.english, .factoryEffect): "Factory Effect"
        case (.simplifiedChinese, .language): "语言"
        case (.english, .language): "Language"
        case (.simplifiedChinese, .launchAtLogin): "开机时自动启动"
        case (.english, .launchAtLogin): "Launch at Login"
        case (.simplifiedChinese, .launchAtLoginApproval): "需要在系统设置的登录项中允许 NuNuBar"
        case (.english, .launchAtLoginApproval): "Allow NuNuBar in System Settings > Login Items"
        case (.simplifiedChinese, .launchAtLoginFailed): "无法更改开机自启："
        case (.english, .launchAtLoginFailed): "Could not change launch at login:"
        case (.simplifiedChinese, .aboutDescription): "让 NuPhy 侧灯显示本机 Agent 状态"
        case (.english, .aboutDescription): "Show local Agent status on your NuPhy side lights"
        }
    }

    func integrationSaved(providerName: String) -> String {
        switch self {
        case .simplifiedChinese: "更改已保存，请重新打开 \(providerName) 任务。"
        case .english: "Changes saved. Reopen your \(providerName) task."
        }
    }
}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppLanguage.simplifiedChinese
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}

extension Notification.Name {
    static let nuphyBarLanguageDidChange = Notification.Name("NuphyBarLanguageDidChange")
    static let nuphyBarOpenKeyboardSetup = Notification.Name("NuphyBarOpenKeyboardSetup")
}
