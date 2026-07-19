import AgentLightCore
import AppKit
import SwiftUI

enum KeyboardSetupLaunchDecision: Equatable {
    case skip
    case migrateLegacyUser
    case present
}

enum KeyboardSetupLaunchPolicy {
    static func decision(completed: Bool, seen: Bool, legacyFirstRun: Bool) -> KeyboardSetupLaunchDecision {
        if completed { return .skip }
        if !seen, legacyFirstRun { return .migrateLegacyUser }
        return .present
    }
}

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate, NSWindowDelegate {
    private static let settingsFrameName = NSWindow.FrameAutosaveName("NuphyBar.SettingsWindow.v9")
    private static let legacyFirstRunKey = "hasPresentedFirstRunSetup.v1"
    private static let setupSeenKey = "hasSeenKeyboardSetup.v1"
    private static let setupCompletedKey = "hasCompletedKeyboardSetup.v1"

    private let model: AppModel
    private let statusItem: NSStatusItem
    private let contextMenu = NSMenu()
    private var settingsWindowController: NSWindowController?
    private var setupWindowController: NSWindowController?
    private var setupModel: KeyboardSetupModel?
    private var selectedColorRole: AgentLightColorRole?

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureStatusButton()
        contextMenu.delegate = self
        statusItem.menu = contextMenu
        configureContextMenu()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange(_:)),
            name: .nuphyBarLanguageDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openKeyboardSetup(_:)),
            name: .nuphyBarOpenKeyboardSetup,
            object: nil
        )
        presentFirstRunSetupIfNeeded()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.image = menuBarIcon
        button.imagePosition = .imageOnly
        button.toolTip = "NuNuBar"
    }

    private func configureContextMenu() {
        let language = AppLanguage.current
        contextMenu.removeAllItems()

        let connection = NSMenuItem(
            title: connectionTitle(language: language),
            action: nil,
            keyEquivalent: ""
        )
        connection.isEnabled = false
        connection.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        contextMenu.addItem(connection)

        let state = NSMenuItem(
            title: stateTitle(language: language),
            action: nil,
            keyEquivalent: ""
        )
        state.isEnabled = false
        state.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
        contextMenu.addItem(state)
        contextMenu.addItem(.separator())

        addColorItem(.working, title: language.text(.workingColor))
        addColorItem(.complete, title: language.text(.completeColor))
        addColorItem(.waiting, title: language.text(.waitingColor))
        addColorItem(.idle, title: language.text(.idleColor))

        let lightSettings = NSMenuItem(
            title: language.text(.lightSettings),
            action: #selector(handleLightSettingsMenuItem(_:)),
            keyEquivalent: ","
        )
        lightSettings.keyEquivalentModifierMask = .command
        lightSettings.target = self
        lightSettings.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: nil)
        contextMenu.addItem(lightSettings)

        let agentSettings = NSMenuItem(
            title: language.text(.agentSettings),
            action: #selector(handleAgentSettingsMenuItem(_:)),
            keyEquivalent: ""
        )
        agentSettings.target = self
        agentSettings.image = NSImage(
            systemSymbolName: "point.3.connected.trianglepath.dotted",
            accessibilityDescription: nil
        )
        contextMenu.addItem(agentSettings)

        let keyboardSetup = NSMenuItem(
            title: language.text(.setupNewKeyboard),
            action: #selector(handleKeyboardSetupMenuItem(_:)),
            keyEquivalent: ""
        )
        keyboardSetup.target = self
        keyboardSetup.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        contextMenu.addItem(keyboardSetup)
        contextMenu.addItem(.separator())

        let settings = NSMenuItem(
            title: language.text(.settings),
            action: #selector(handleSettingsMenuItem(_:)),
            keyEquivalent: ""
        )
        settings.target = self
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        contextMenu.addItem(settings)

        let launchAtLogin = LaunchAtLoginController()
        let launch = NSMenuItem(
            title: language.text(.launchAtLogin),
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launch.target = self
        launch.state = launchAtLogin.status.isOn ? .on : .off
        launch.isEnabled = launchAtLogin.status != .unavailable
        contextMenu.addItem(launch)

        let quit = NSMenuItem(
            title: language.text(.quit),
            action: #selector(quitApplication),
            keyEquivalent: ""
        )
        quit.target = self
        contextMenu.addItem(quit)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        configureContextMenu()
    }

    @objc private func languageDidChange(_ notification: Notification) {
        configureContextMenu()
    }

    @objc private func handleSettingsMenuItem(_ sender: NSMenuItem) {
        showSettings()
    }

    @objc private func handleLightSettingsMenuItem(_ sender: NSMenuItem) {
        presentPreferencesWindow(section: .lights)
    }

    @objc private func handleAgentSettingsMenuItem(_ sender: NSMenuItem) {
        presentPreferencesWindow(section: .agents)
    }

    @objc private func handleKeyboardSetupMenuItem(_ sender: NSMenuItem) {
        showKeyboardSetup()
    }

    @objc private func openKeyboardSetup(_ notification: Notification) {
        showKeyboardSetup()
    }

    @objc private func handleColorMenuItem(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let role = AgentLightColorRole(rawValue: rawValue) else { return }
        selectedColorRole = role
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.color = model.lightPalette.color(for: role).nsColor
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelDidChange(_:)))
        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            panel.orderFrontRegardless()
        }
    }

    @objc private func colorPanelDidChange(_ sender: NSColorPanel) {
        guard let selectedColorRole else { return }
        model.updateLightColor(AgentLightRGBColor(sender.color), for: selectedColorRole)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let launchAtLogin = LaunchAtLoginController()
        do {
            try launchAtLogin.setEnabled(!launchAtLogin.status.isOn)
            sender.state = launchAtLogin.status.isOn ? .on : .off
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "NuNuBar"
            alert.informativeText = "\(AppLanguage.current.text(.launchAtLoginFailed)) \(error.localizedDescription)"
            alert.runModal()
        }
    }

    func showSettings() {
        presentPreferencesWindow(section: model.settingsSection)
    }

    func showKeyboardSetup() {
        if setupWindowController == nil {
            let setupModel = KeyboardSetupModel(appModel: model) { [weak self] in
                self?.completeKeyboardSetup()
            }
            let window = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: KeyboardSetupLayout.windowWidth,
                    height: KeyboardSetupLayout.windowHeight
                ),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = AppLanguage.current.text(.setupNewKeyboard).replacingOccurrences(of: "…", with: "")
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NuphyBarTheme.windowBackgroundColor
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentViewController = NSHostingController(
                rootView: KeyboardSetupView(setup: setupModel)
            )
            window.setContentSize(NSSize(
                width: KeyboardSetupLayout.windowWidth,
                height: KeyboardSetupLayout.windowHeight
            ))
            window.center()
            self.setupModel = setupModel
            setupWindowController = NSWindowController(window: window)
        } else if setupModel?.stage == .complete {
            setupModel?.restart()
        }

        NSApp.activate(ignoringOtherApps: true)
        if let window = setupWindowController?.window {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.orderFrontRegardless()
            window.makeKey()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === setupWindowController?.window else { return true }
        if setupModel?.isCriticalOperation == true {
            NSSound.beep()
            return false
        }
        return true
    }

    private func presentPreferencesWindow(section: SettingsSection) {
        model.settingsSection = section
        model.refreshConnection()
        model.refreshIntegrations()

        if settingsWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: SettingsLayout.windowWidth,
                    height: SettingsLayout.windowHeight
                ),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "NuNuBar"
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = true
            window.isOpaque = true
            window.backgroundColor = NuphyBarTheme.windowBackgroundColor
            window.isMovableByWindowBackground = false
            window.animationBehavior = .none
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(
                rootView: SettingsView(model: model)
            )
            window.setContentSize(
                NSSize(width: SettingsLayout.windowWidth, height: SettingsLayout.windowHeight)
            )
            let windowController = NSWindowController(window: window)
            windowController.shouldCascadeWindows = false
            let restoredFrame = window.setFrameUsingName(Self.settingsFrameName, force: true)
            _ = window.setFrameAutosaveName(Self.settingsFrameName)
            if !restoredFrame {
                center(window)
            }
            settingsWindowController = windowController
        }

        NSApp.activate(ignoringOtherApps: true)
        if let window = settingsWindowController?.window {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.orderFrontRegardless()
            window.makeKey()
        }
    }

    private func center(_ window: NSWindow) {
        guard let screen = statusItem.button?.window?.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let windowFrame = window.frame
        window.setFrame(
            NSRect(
                origin: NSPoint(
                    x: visibleFrame.midX - windowFrame.width / 2,
                    y: visibleFrame.midY - windowFrame.height / 2
                ),
                size: windowFrame.size
            ),
            display: true,
            animate: false
        )
    }

    private func presentFirstRunSetupIfNeeded() {
        let defaults = UserDefaults.standard
        let decision = KeyboardSetupLaunchPolicy.decision(
            completed: defaults.bool(forKey: Self.setupCompletedKey),
            seen: defaults.bool(forKey: Self.setupSeenKey),
            legacyFirstRun: defaults.bool(forKey: Self.legacyFirstRunKey)
        )
        switch decision {
        case .skip:
            return
        case .migrateLegacyUser:
            defaults.set(true, forKey: Self.setupCompletedKey)
            return
        case .present:
            break
        }

        if !defaults.bool(forKey: Self.setupSeenKey) {
            defaults.set(true, forKey: Self.setupSeenKey)
            defaults.set(true, forKey: Self.legacyFirstRunKey)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.showKeyboardSetup()
        }
    }

    private func completeKeyboardSetup() {
        UserDefaults.standard.set(true, forKey: Self.setupCompletedKey)
        setupWindowController?.close()
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    private func addColorItem(_ role: AgentLightColorRole, title: String) {
        let item = NSMenuItem(
            title: title,
            action: #selector(handleColorMenuItem(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = role.rawValue
        item.image = colorSwatch(model.lightPalette.color(for: role))
        contextMenu.addItem(item)
    }

    private func connectionTitle(language: AppLanguage) -> String {
        guard let keyboardModel = model.keyboardModel else {
            return language.text(.notConnected)
        }
        let transport = model.keyboardTransport == .usb
            ? language.text(.usbConnected)
            : language.text(.bluetoothConnected)
        return "\(keyboardModel) · \(transport)"
    }

    private func stateTitle(language: AppLanguage) -> String {
        switch model.activeAgentCommand {
        case .working: language.text(.working)
        case .waiting, .error: language.text(.waiting)
        case .complete: language.text(.taskComplete)
        case .idle: language.text(.idle)
        }
    }

    private func colorSwatch(_ color: AgentLightRGBColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 14, height: 14))
        image.lockFocus()
        color.nsColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 10, height: 10)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private var menuBarIcon: NSImage {
        guard let url = Bundle.main.url(
            forResource: "NuphyBarMenuBarIcon",
            withExtension: "png"
        ), let image = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "keyboard", accessibilityDescription: "NuNuBar")!
        }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}

private extension AgentLightRGBColor {
    var nsColor: NSColor {
        NSColor(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }

    init(_ color: NSColor) {
        let resolved = color.usingColorSpace(.deviceRGB) ?? .white
        self.init(
            red: UInt8((max(0, min(1, resolved.redComponent)) * 255).rounded()),
            green: UInt8((max(0, min(1, resolved.greenComponent)) * 255).rounded()),
            blue: UInt8((max(0, min(1, resolved.blueComponent)) * 255).rounded())
        )
    }
}
