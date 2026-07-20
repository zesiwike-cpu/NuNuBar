import AppKit
import Foundation

enum Air65FnShortcutStatus: Equatable, Sendable {
    case checking
    case karabinerNotInstalled
    case karabinerSetupRequired
    case mappingMissing
    case ready
}

enum Air65MappingAction: String, CaseIterable, Identifiable, Sendable {
    case fnGlobe
    case escape
    case returnOrEnter
    case deleteOrBackspace
    case pageUp
    case pageDown
    case home
    case end
    case playPause
    case mute
    case volumeDown
    case volumeUp
    case codexNewTask
    case codexToggleSidebar
    case codexToggleBottomPanel
    case codexToggleFileTree
    case codexToggleReviewPanel
    case codexOpenTerminal
    case codexOpenBrowserTab
    case codexPreviousTask
    case codexNextTask
    case codexKeyboardShortcuts
    case codexSettings

    var id: String { rawValue }

    static let systemActions: [Self] = [
        .fnGlobe, .escape, .returnOrEnter, .deleteOrBackspace,
        .pageUp, .pageDown, .home, .end,
        .playPause, .mute, .volumeDown, .volumeUp,
    ]

    static let codexActions: [Self] = [
        .codexNewTask, .codexToggleSidebar, .codexToggleBottomPanel,
        .codexToggleFileTree, .codexToggleReviewPanel, .codexOpenTerminal,
        .codexOpenBrowserTab, .codexPreviousTask, .codexNextTask,
        .codexKeyboardShortcuts, .codexSettings,
    ]

    var isCodexAction: Bool { Self.codexActions.contains(self) }

    fileprivate var karabinerOutput: [String: Any] {
        switch self {
        case .fnGlobe:
            ["apple_vendor_top_case_key_code": "keyboard_fn"]
        case .escape:
            ["key_code": "escape"]
        case .returnOrEnter:
            ["key_code": "return_or_enter"]
        case .deleteOrBackspace:
            ["key_code": "delete_or_backspace"]
        case .pageUp:
            ["key_code": "page_up"]
        case .pageDown:
            ["key_code": "page_down"]
        case .home:
            ["key_code": "home"]
        case .end:
            ["key_code": "end"]
        case .playPause:
            ["key_code": "play_or_pause"]
        case .mute:
            ["key_code": "mute"]
        case .volumeDown:
            ["key_code": "volume_decrement"]
        case .volumeUp:
            ["key_code": "volume_increment"]
        case .codexNewTask:
            ["key_code": "n", "modifiers": ["left_command"]]
        case .codexToggleSidebar:
            ["key_code": "b", "modifiers": ["left_command"]]
        case .codexToggleBottomPanel:
            ["key_code": "j", "modifiers": ["left_command"]]
        case .codexToggleFileTree:
            ["key_code": "e", "modifiers": ["left_command", "left_shift"]]
        case .codexToggleReviewPanel:
            ["key_code": "b", "modifiers": ["left_command", "left_option"]]
        case .codexOpenTerminal:
            ["key_code": "grave_accent_and_tilde", "modifiers": ["left_control"]]
        case .codexOpenBrowserTab:
            ["key_code": "t", "modifiers": ["left_command"]]
        case .codexPreviousTask:
            ["key_code": "open_bracket", "modifiers": ["left_command", "left_shift"]]
        case .codexNextTask:
            ["key_code": "close_bracket", "modifiers": ["left_command", "left_shift"]]
        case .codexKeyboardShortcuts:
            ["key_code": "slash", "modifiers": ["left_command"]]
        case .codexSettings:
            ["key_code": "comma", "modifiers": ["left_command"]]
        }
    }

    fileprivate static func parse(_ output: [String: Any]) -> Self? {
        if output["apple_vendor_top_case_key_code"] as? String == "keyboard_fn" {
            return .fnGlobe
        }
        guard let keyCode = output["key_code"] as? String else { return nil }
        let modifiers = (output["modifiers"] as? [String] ?? []).sorted()
        return allCases.first { action in
            let candidate = action.karabinerOutput
            return candidate["key_code"] as? String == keyCode
                && (candidate["modifiers"] as? [String] ?? []).sorted() == modifiers
        }
    }
}

struct Air65KeyMapping: Identifiable, Equatable, Sendable {
    let keyID: String
    let inputKeyCode: String
    let action: Air65MappingAction

    var id: String { keyID }

    static let verifiedYellowKey = Air65KeyMapping(
        keyID: Air65KeyboardLayout.yellowShortcutKeyID,
        inputKeyCode: "f24",
        action: .fnGlobe
    )
}

enum Air65FnShortcutError: LocalizedError, Equatable {
    case configurationMissing
    case invalidConfiguration
    case profileMissing
    case backupAlreadyExists
    case unsupportedKey

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            "Open Karabiner-Elements once before changing NuPhy keyboard mappings."
        case .invalidConfiguration:
            "Karabiner configuration has an unsupported structure and was not changed."
        case .profileMissing:
            "Karabiner configuration does not contain a profile and was not changed."
        case .backupAlreadyExists:
            "The proposed Karabiner backup already exists. Refresh and try again."
        case .unsupportedKey:
            "This NuPhy control cannot be mapped as a standard keyboard event yet."
        }
    }
}

struct Air65FnShortcutService: @unchecked Sendable {
    static let managedRuleDescription = "NuNuBar Air65 V3: F24 to fn (globe)"
    static let managedRulePrefix = "NuNuBar Air65 V3 Mapping: "
    static let vendorID = 0x19F5
    static let productID = 0x102B
    static let codexBundleIdentifierPattern = "^com\\.openai\\.codex$"
    static let karabinerDownloadURL = URL(string: "https://karabiner-elements.pqrs.org/")!

    static func nuphyIOURL(languageCode: String) -> URL {
        var components = URLComponents(string: "https://drive.nuphy.io/")!
        components.queryItems = [URLQueryItem(name: "lang", value: languageCode)]
        return components.url!
    }

    let fileManager: FileManager
    let configURL: URL
    let karabinerAppURL: URL
    let eventViewerAppURL: URL
    let karabinerCLIURL: URL
    let profile: NuPhyKeyboardMappingProfile

    init(
        profile: NuPhyKeyboardMappingProfile = .air65V3,
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        applicationsDirectory: URL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    ) {
        self.profile = profile
        self.fileManager = fileManager
        configURL = homeDirectory
            .appending(path: ".config/karabiner/karabiner.json")
        karabinerAppURL = applicationsDirectory
            .appending(path: "Karabiner-Elements.app", directoryHint: .isDirectory)
        eventViewerAppURL = applicationsDirectory
            .appending(path: "Karabiner-EventViewer.app", directoryHint: .isDirectory)
        karabinerCLIURL = URL(
            fileURLWithPath: "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
        )
    }

    func status() -> Air65FnShortcutStatus {
        guard fileManager.fileExists(atPath: karabinerAppURL.path) else {
            return .karabinerNotInstalled
        }
        guard let data = try? Data(contentsOf: configURL),
              (try? Self.mappings(in: data)) != nil
        else {
            return .karabinerSetupRequired
        }
        guard karabinerEngineIsReady() else {
            return .karabinerSetupRequired
        }
        return Self.containsManagedRule(in: data, profile: profile) ? .ready : .mappingMissing
    }

    func configuredMappings() throws -> [Air65KeyMapping] {
        guard fileManager.fileExists(atPath: configURL.path) else {
            throw Air65FnShortcutError.configurationMissing
        }
        return try Self.mappings(in: Data(contentsOf: configURL), profile: profile)
    }

    func proposedBackupURL(now: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stem = "karabiner.json.nunubar-before-\(profile.backupName)-mapping-\(formatter.string(from: now))"
        let directory = configURL.deletingLastPathComponent()

        var candidate = directory.appending(path: "\(stem).bak")
        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appending(path: "\(stem)-\(suffix).bak")
            suffix += 1
        }
        return candidate
    }

    func installMapping(_ mapping: Air65KeyMapping, backupURL: URL) throws {
        guard profile.key(id: mapping.keyID)?.inputKeyCode != nil else {
            throw Air65FnShortcutError.unsupportedKey
        }
        try updateConfiguration(backupURL: backupURL) { original in
            try Self.configurationByUpsertingMapping(mapping, in: original, profile: profile)
        }
    }

    func installMapping(backupURL: URL) throws {
        try installMapping(.verifiedYellowKey, backupURL: backupURL)
    }

    func removeMapping(for keyID: String, backupURL: URL) throws {
        try updateConfiguration(backupURL: backupURL) { original in
            try Self.configurationByRemovingMapping(for: keyID, in: original, profile: profile)
        }
    }

    func removeMapping(backupURL: URL) throws {
        try removeMapping(for: Air65KeyboardLayout.yellowShortcutKeyID, backupURL: backupURL)
    }

    private func updateConfiguration(
        backupURL: URL,
        transform: (Data) throws -> Data
    ) throws {
        guard fileManager.fileExists(atPath: configURL.path) else {
            throw Air65FnShortcutError.configurationMissing
        }
        guard !fileManager.fileExists(atPath: backupURL.path) else {
            throw Air65FnShortcutError.backupAlreadyExists
        }

        let original = try Data(contentsOf: configURL)
        let updated = try transform(original)
        guard updated != original else { return }

        let attributes = try? fileManager.attributesOfItem(atPath: configURL.path)
        try fileManager.copyItem(at: configURL, to: backupURL)
        try updated.write(to: configURL, options: .atomic)
        if let permissions = attributes?[.posixPermissions] {
            try fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: configURL.path)
        }
    }

    @MainActor
    func openKarabiner() {
        NSWorkspace.shared.open(karabinerAppURL)
    }

    @MainActor
    func openEventViewer() {
        NSWorkspace.shared.open(eventViewerAppURL)
    }

    static func containsManagedRule(
        in data: Data,
        profile: NuPhyKeyboardMappingProfile = .air65V3
    ) -> Bool {
        guard let mappings = try? mappings(in: data, profile: profile) else { return false }
        return !mappings.isEmpty
    }

    static func mappings(
        in data: Data,
        profile: NuPhyKeyboardMappingProfile = .air65V3
    ) throws -> [Air65KeyMapping] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profiles = root["profiles"] as? [[String: Any]]
        else {
            throw Air65FnShortcutError.invalidConfiguration
        }
        guard !profiles.isEmpty else {
            throw Air65FnShortcutError.profileMissing
        }

        let selectedIndex = profiles.firstIndex { ($0["selected"] as? Bool) == true } ?? 0
        let selectedProfile = profiles[selectedIndex]
        guard let complex = selectedProfile["complex_modifications"] as? [String: Any] else {
            if selectedProfile["complex_modifications"] != nil {
                throw Air65FnShortcutError.invalidConfiguration
            }
            return []
        }
        guard let rules = complex["rules"] as? [[String: Any]] else {
            if complex["rules"] != nil {
                throw Air65FnShortcutError.invalidConfiguration
            }
            return []
        }

        var byKey: [String: Air65KeyMapping] = [:]
        for rule in rules {
            if let mapping = mapping(from: rule, profile: profile) {
                byKey[mapping.keyID] = mapping
            }
        }
        return byKey.values.sorted { $0.keyID < $1.keyID }
    }

    static func configurationByInstallingManagedRule(in data: Data) throws -> Data {
        try configurationByUpsertingMapping(.verifiedYellowKey, in: data)
    }

    static func configurationByUpsertingMapping(
        _ mapping: Air65KeyMapping,
        in data: Data,
        profile: NuPhyKeyboardMappingProfile = .air65V3
    ) throws -> Data {
        guard profile.key(id: mapping.keyID)?.inputKeyCode != nil else {
            throw Air65FnShortcutError.unsupportedKey
        }
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var profiles = root["profiles"] as? [[String: Any]]
        else {
            throw Air65FnShortcutError.invalidConfiguration
        }
        guard !profiles.isEmpty else {
            throw Air65FnShortcutError.profileMissing
        }

        let selectedIndex = profiles.firstIndex { ($0["selected"] as? Bool) == true } ?? 0
        var selectedProfile = profiles[selectedIndex]
        if let value = selectedProfile["complex_modifications"], !(value is [String: Any]) {
            throw Air65FnShortcutError.invalidConfiguration
        }
        var complex = selectedProfile["complex_modifications"] as? [String: Any] ?? [:]
        if let value = complex["rules"], !(value is [[String: Any]]) {
            throw Air65FnShortcutError.invalidConfiguration
        }

        var rules = complex["rules"] as? [[String: Any]] ?? []
        rules.removeAll { ownedKeyID(from: $0, profile: profile) == mapping.keyID }
        rules.append(managedRule(for: mapping, profile: profile))
        complex["rules"] = rules
        selectedProfile["complex_modifications"] = complex
        profiles[selectedIndex] = selectedProfile
        root["profiles"] = profiles

        return try serializedConfiguration(root)
    }

    static func configurationByRemovingManagedRule(in data: Data) throws -> Data {
        try configurationByRemovingMapping(
            for: Air65KeyboardLayout.yellowShortcutKeyID,
            in: data
        )
    }

    static func configurationByRemovingMapping(
        for keyID: String,
        in data: Data,
        profile: NuPhyKeyboardMappingProfile = .air65V3
    ) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var profiles = root["profiles"] as? [[String: Any]]
        else {
            throw Air65FnShortcutError.invalidConfiguration
        }
        guard !profiles.isEmpty else {
            throw Air65FnShortcutError.profileMissing
        }

        for index in profiles.indices {
            var selectedProfile = profiles[index]
            guard var complex = selectedProfile["complex_modifications"] as? [String: Any] else {
                if selectedProfile["complex_modifications"] != nil {
                    throw Air65FnShortcutError.invalidConfiguration
                }
                continue
            }
            guard var rules = complex["rules"] as? [[String: Any]] else {
                if complex["rules"] != nil {
                    throw Air65FnShortcutError.invalidConfiguration
                }
                continue
            }
            rules.removeAll { ownedKeyID(from: $0, profile: profile) == keyID }
            complex["rules"] = rules
            selectedProfile["complex_modifications"] = complex
            profiles[index] = selectedProfile
        }
        root["profiles"] = profiles

        return try serializedConfiguration(root)
    }

    private func karabinerEngineIsReady() -> Bool {
        guard fileManager.isExecutableFile(atPath: karabinerCLIURL.path) else { return false }

        let process = Process()
        let output = Pipe()
        process.executableURL = karabinerCLIURL
        process.arguments = ["--list-connected-devices"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return false
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let devices = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return false }

        let physicalKeyboard = devices.contains { device in
            guard let identifiers = device["device_identifiers"] as? [String: Any] else {
                return false
            }
            return identifiers["vendor_id"] as? Int == Self.vendorID
                && identifiers["product_id"] as? Int == profile.productID
                && identifiers["is_keyboard"] as? Bool == true
        }
        let virtualKeyboard = devices.contains { device in
            guard let identifiers = device["device_identifiers"] as? [String: Any] else {
                return false
            }
            return identifiers["is_keyboard"] as? Bool == true
                && identifiers["is_virtual_device"] as? Bool == true
        }
        return physicalKeyboard && virtualKeyboard
    }

    private static func mapping(
        from rule: [String: Any],
        profile: NuPhyKeyboardMappingProfile
    ) -> Air65KeyMapping? {
        guard let keyID = ownedKeyID(from: rule, profile: profile),
              let manipulators = rule["manipulators"] as? [[String: Any]],
              manipulators.count == 1,
              let manipulator = manipulators.first,
              manipulator["type"] as? String == "basic",
              let from = manipulator["from"] as? [String: Any],
              let inputKeyCode = from["key_code"] as? String,
              let to = manipulator["to"] as? [[String: Any]],
              to.count == 1,
              let output = to.first,
              let action = Air65MappingAction.parse(output),
              hasExactDeviceCondition(manipulator, profile: profile),
              !action.isCodexAction || hasCodexFrontmostCondition(manipulator)
        else { return nil }

        return Air65KeyMapping(
            keyID: keyID,
            inputKeyCode: inputKeyCode,
            action: action
        )
    }

    private static func ownedKeyID(
        from rule: [String: Any],
        profile: NuPhyKeyboardMappingProfile
    ) -> String? {
        guard let description = rule["description"] as? String else { return nil }
        if description == profile.legacyRuleDescription {
            return Air65KeyboardLayout.yellowShortcutKeyID
        }
        guard description.hasPrefix(profile.managedRulePrefix) else { return nil }
        let keyID = String(description.dropFirst(profile.managedRulePrefix.count))
        return keyID.isEmpty ? nil : keyID
    }

    private static func hasExactDeviceCondition(
        _ manipulator: [String: Any],
        profile: NuPhyKeyboardMappingProfile
    ) -> Bool {
        guard let conditions = manipulator["conditions"] as? [[String: Any]] else {
            return false
        }
        return conditions.contains { condition in
            guard condition["type"] as? String == "device_if",
                  let identifiers = condition["identifiers"] as? [[String: Any]]
            else { return false }
            return identifiers.contains { identifier in
                identifier["vendor_id"] as? Int == vendorID
                    && identifier["product_id"] as? Int == profile.productID
                    && identifier["is_keyboard"] as? Bool == true
            }
        }
    }

    private static func hasCodexFrontmostCondition(_ manipulator: [String: Any]) -> Bool {
        guard let conditions = manipulator["conditions"] as? [[String: Any]] else {
            return false
        }
        return conditions.contains { condition in
            guard condition["type"] as? String == "frontmost_application_if",
                  let bundleIdentifiers = condition["bundle_identifiers"] as? [String]
            else { return false }
            return bundleIdentifiers.contains(codexBundleIdentifierPattern)
        }
    }

    private static func managedRule(
        for mapping: Air65KeyMapping,
        profile: NuPhyKeyboardMappingProfile
    ) -> [String: Any] {
        var conditions: [[String: Any]] = [
            [
                "identifiers": [
                    [
                        "is_keyboard": true,
                        "product_id": profile.productID,
                        "vendor_id": vendorID,
                    ],
                ],
                "type": "device_if",
            ],
        ]
        if mapping.action.isCodexAction {
            conditions.append([
                "bundle_identifiers": [codexBundleIdentifierPattern],
                "type": "frontmost_application_if",
            ])
        }

        return [
            "description": "\(profile.managedRulePrefix)\(mapping.keyID)",
            "manipulators": [
                [
                    "conditions": conditions,
                    "from": [
                        "key_code": mapping.inputKeyCode,
                        "modifiers": ["optional": ["any"]],
                    ],
                    "to": [mapping.action.karabinerOutput],
                    "type": "basic",
                ],
            ],
        ]
    }

    private static func serializedConfiguration(_ root: [String: Any]) throws -> Data {
        guard JSONSerialization.isValidJSONObject(root) else {
            throw Air65FnShortcutError.invalidConfiguration
        }
        var output = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        output.append(0x0A)
        return output
    }
}
