import Foundation
import Testing
@testable import AgentLightApp

@Test("NuPhyIO button opens the current official 2.0 entry with App language")
func nuphyIOButtonUsesCurrentOfficialEntry() {
    #expect(
        Air65FnShortcutService.nuphyIOURL(languageCode: "zh-CN").absoluteString
            == "https://drive.nuphy.io/?lang=zh-CN"
    )
    #expect(
        Air65FnShortcutService.nuphyIOURL(languageCode: "en-US").absoluteString
            == "https://drive.nuphy.io/?lang=en-US"
    )
}

@Test("Air65 input diagnostics recognize F21 through F24 and Fn Globe")
func air65InputDiagnosticsRecognizeCarriers() throws {
    for number in 21...24 {
        let scalar = try #require(UnicodeScalar(0xF704 + number - 1))
        let observed = Air65ObservedInput.detect(
            characters: String(scalar),
            functionModifierIsDown: false
        )
        #expect(observed == .functionKey(number))
        #expect(observed?.keyCode == "f\(number)")
    }

    #expect(Air65ObservedInput.detect(
        characters: nil,
        functionModifierIsDown: true
    ) == .fnGlobe)
    #expect(Air65ObservedInput.detect(
        characters: "a",
        functionModifierIsDown: false
    ) == nil)
}

@Test("Air65 keyboard layout keeps the yellow shortcut at the physical PGDN position")
func air65KeyboardLayoutIdentifiesYellowShortcut() throws {
    let key = try #require(Air65KeyboardLayout.key(id: "pgdn"))

    #expect(key.legend == "PGDN")
    #expect(key.isYellowShortcut)
    #expect(key.inputKeyCode == "f24")
    #expect(Air65KeyboardLayout.rows.count == 5)
    #expect(Air65KeyboardLayout.key(id: "n")?.legend == "N")
}

@Test("Air65 keyboard layout exposes all three knob events")
func air65KeyboardLayoutExposesKnobEvents() throws {
    let left = try #require(Air65KeyboardLayout.key(id: Air65KeyboardLayout.knobLeftKeyID))
    let press = try #require(Air65KeyboardLayout.key(id: Air65KeyboardLayout.knobPressKeyID))
    let right = try #require(Air65KeyboardLayout.key(id: Air65KeyboardLayout.knobRightKeyID))

    #expect(left.inputKeyCode == "f21")
    #expect(press.inputKeyCode == "f22")
    #expect(right.inputKeyCode == "f23")
    #expect(left.isMappable)
    #expect(press.isMappable)
    #expect(right.isMappable)
}

@Test("Air75 keyboard layout matches the physical 75 percent ANSI arrangement")
func air75KeyboardLayoutMatchesPhysicalArrangement() throws {
    let profile = NuPhyKeyboardMappingProfile.air75V3

    #expect(profile.productName == "Air75 V3")
    #expect(profile.productID == 0x1028)
    #expect(profile.rows.count == 6)
    #expect(profile.rows[0].first?.id == "escape")
    #expect(profile.rows[0].last?.id == Air65KeyboardLayout.knobKeyID)
    #expect(profile.rows[1].last?.id == "page_up")
    #expect(profile.rows[2].last?.id == "page_down")
    #expect(profile.key(id: "f12")?.inputKeyCode == "f12")
    #expect(profile.key(id: "page_down")?.legend == "PGDN")
    #expect(profile.key(id: "fn")?.inputKeyCode == nil)
    #expect(profile.highlightedKeyID == nil)
}

@Test("Air75 keyboard layout exposes the three knob carrier events")
func air75KeyboardLayoutExposesKnobEvents() throws {
    let profile = NuPhyKeyboardMappingProfile.air75V3

    #expect(profile.key(id: Air65KeyboardLayout.knobLeftKeyID)?.inputKeyCode == "f21")
    #expect(profile.key(id: Air65KeyboardLayout.knobPressKeyID)?.inputKeyCode == "f22")
    #expect(profile.key(id: Air65KeyboardLayout.knobRightKeyID)?.inputKeyCode == "f23")
}

@Test("Air65 keyboard layout reports duplicate carrier assignments")
func air65KeyboardLayoutReportsDuplicateCarriers() {
    let duplicates = Air65KeyboardLayout.duplicateCarriers(in: [
        "pgdn": "F24",
        "n": "F24",
        "escape": "ESC",
    ])

    #expect(duplicates == ["F24": ["n", "pgdn"]])
    #expect(Air65KeyboardLayout.duplicateCarriers(in: ["pgdn": "F24"]).isEmpty)
}

@Test("Air65 mapping reader imports the verified legacy yellow-key rule")
func air65MappingReaderImportsLegacyRule() throws {
    let original = Data("{\"profiles\":[{\"name\":\"Default\",\"selected\":true}]}".utf8)
    let installed = try Air65FnShortcutService.configurationByInstallingManagedRule(in: original)
    let mappings = try Air65FnShortcutService.mappings(in: installed)

    #expect(mappings == [.verifiedYellowKey])
}

@Test("Air75 mapping rule is scoped to the exact keyboard and isolated from Air65")
func air75MappingRuleIsExactlyScoped() throws {
    let original = Data("{\"profiles\":[{\"name\":\"Default\",\"selected\":true}]}".utf8)
    let mapping = Air65KeyMapping(
        keyID: Air65KeyboardLayout.knobPressKeyID,
        inputKeyCode: "f22",
        action: .codexNewTask
    )
    let configured = try Air65FnShortcutService.configurationByUpsertingMapping(
        mapping,
        in: original,
        profile: .air75V3
    )

    #expect(try Air65FnShortcutService.mappings(in: configured, profile: .air75V3) == [mapping])
    #expect(try Air65FnShortcutService.mappings(in: configured, profile: .air65V3).isEmpty)

    let root = try #require(JSONSerialization.jsonObject(with: configured) as? [String: Any])
    let profiles = try #require(root["profiles"] as? [[String: Any]])
    let complex = try #require(profiles[0]["complex_modifications"] as? [String: Any])
    let rules = try #require(complex["rules"] as? [[String: Any]])
    #expect(rules[0]["description"] as? String == "NuNuBar Air75 V3 Mapping: knob_press")
    let manipulators = try #require(rules[0]["manipulators"] as? [[String: Any]])
    let conditions = try #require(manipulators[0]["conditions"] as? [[String: Any]])
    let identifiers = try #require(conditions[0]["identifiers"] as? [[String: Any]])
    #expect(identifiers[0]["vendor_id"] as? Int == 0x19F5)
    #expect(identifiers[0]["product_id"] as? Int == 0x1028)
}

@Test("Air65 and Air75 mappings coexist without replacing each other")
func air65AndAir75MappingsCoexist() throws {
    let original = Data("{\"profiles\":[{\"name\":\"Default\",\"selected\":true}]}".utf8)
    let air65 = Air65KeyMapping(keyID: "n", inputKeyCode: "n", action: .escape)
    let air75 = Air65KeyMapping(keyID: "n", inputKeyCode: "n", action: .codexNewTask)
    let withAir65 = try Air65FnShortcutService.configurationByUpsertingMapping(
        air65,
        in: original,
        profile: .air65V3
    )
    let configured = try Air65FnShortcutService.configurationByUpsertingMapping(
        air75,
        in: withAir65,
        profile: .air75V3
    )

    #expect(try Air65FnShortcutService.mappings(in: configured, profile: .air65V3) == [air65])
    #expect(try Air65FnShortcutService.mappings(in: configured, profile: .air75V3) == [air75])
}

@Test("Air65 mappings coexist and updating one key remains idempotent")
func air65MappingsCoexistAndUpdateOneKey() throws {
    let original = Data(
        """
        {
          "profiles": [
            {
              "name": "Default",
              "selected": true,
              "complex_modifications": {
                "rules": [{ "description": "Keep me", "manipulators": [] }]
              }
            }
          ]
        }
        """.utf8
    )
    let yellow = try Air65FnShortcutService.configurationByInstallingManagedRule(in: original)
    let nToEscape = Air65KeyMapping(keyID: "n", inputKeyCode: "n", action: .escape)
    let withN = try Air65FnShortcutService.configurationByUpsertingMapping(nToEscape, in: yellow)
    let nToVolume = Air65KeyMapping(keyID: "n", inputKeyCode: "n", action: .volumeUp)
    let updated = try Air65FnShortcutService.configurationByUpsertingMapping(nToVolume, in: withN)

    let mappings = try Air65FnShortcutService.mappings(in: updated)
    #expect(mappings.count == 2)
    #expect(mappings.contains(.verifiedYellowKey))
    #expect(mappings.contains(nToVolume))

    let root = try #require(JSONSerialization.jsonObject(with: updated) as? [String: Any])
    let profiles = try #require(root["profiles"] as? [[String: Any]])
    let complex = try #require(profiles[0]["complex_modifications"] as? [String: Any])
    let rules = try #require(complex["rules"] as? [[String: Any]])
    #expect(rules.count == 3)
    #expect(rules.contains { $0["description"] as? String == "Keep me" })
}

@Test("Air65 knob directions keep independent mappings")
func air65KnobMappingsCoexist() throws {
    let original = Data("{\"profiles\":[{\"name\":\"Default\",\"selected\":true}]}".utf8)
    let mappings = [
        Air65KeyMapping(
            keyID: Air65KeyboardLayout.knobLeftKeyID,
            inputKeyCode: "f21",
            action: .codexPreviousTask
        ),
        Air65KeyMapping(
            keyID: Air65KeyboardLayout.knobPressKeyID,
            inputKeyCode: "f22",
            action: .codexNewTask
        ),
        Air65KeyMapping(
            keyID: Air65KeyboardLayout.knobRightKeyID,
            inputKeyCode: "f23",
            action: .codexNextTask
        ),
    ]

    let configured = try mappings.reduce(original) { data, mapping in
        try Air65FnShortcutService.configurationByUpsertingMapping(mapping, in: data)
    }

    #expect(try Air65FnShortcutService.mappings(in: configured) == mappings)
}

@Test("Air65 Codex actions are scoped to the frontmost Codex app")
func air65CodexActionIsFrontmostScoped() throws {
    let original = Data("{\"profiles\":[{\"name\":\"Default\",\"selected\":true}]}".utf8)
    let mapping = Air65KeyMapping(
        keyID: Air65KeyboardLayout.knobPressKeyID,
        inputKeyCode: "f22",
        action: .codexNewTask
    )
    let configured = try Air65FnShortcutService.configurationByUpsertingMapping(mapping, in: original)

    let root = try #require(JSONSerialization.jsonObject(with: configured) as? [String: Any])
    let profiles = try #require(root["profiles"] as? [[String: Any]])
    let complex = try #require(profiles[0]["complex_modifications"] as? [String: Any])
    let rules = try #require(complex["rules"] as? [[String: Any]])
    let manipulators = try #require(rules[0]["manipulators"] as? [[String: Any]])
    let conditions = try #require(manipulators[0]["conditions"] as? [[String: Any]])
    let appCondition = try #require(conditions.first {
        $0["type"] as? String == "frontmost_application_if"
    })
    let bundleIdentifiers = try #require(appCondition["bundle_identifiers"] as? [String])
    let output = try #require(manipulators[0]["to"] as? [[String: Any]])

    #expect(bundleIdentifiers == [Air65FnShortcutService.codexBundleIdentifierPattern])
    #expect(output[0]["key_code"] as? String == "n")
    #expect(output[0]["modifiers"] as? [String] == ["left_command"])
    #expect(try Air65FnShortcutService.mappings(in: configured) == [mapping])
}

@Test("Air65 does not import an unscoped app shortcut as a safe Codex mapping")
func air65RejectsUnscopedCodexMapping() throws {
    let unsafe = Data(
        """
        {
          "profiles": [
            {
              "name": "Default",
              "selected": true,
              "complex_modifications": {
                "rules": [
                  {
                    "description": "NuNuBar Air65 V3 Mapping: knob_press",
                    "manipulators": [
                      {
                        "type": "basic",
                        "from": { "key_code": "f22" },
                        "to": [{ "key_code": "n", "modifiers": ["left_command"] }],
                        "conditions": [
                          {
                            "type": "device_if",
                            "identifiers": [
                              { "vendor_id": 6645, "product_id": 4139, "is_keyboard": true }
                            ]
                          }
                        ]
                      }
                    ]
                  }
                ]
              }
            }
          ]
        }
        """.utf8
    )

    #expect(try Air65FnShortcutService.mappings(in: unsafe).isEmpty)
}

@Test("Air65 system actions remain available outside Codex")
func air65SystemActionHasNoAppScope() throws {
    let original = Data("{\"profiles\":[{\"name\":\"Default\",\"selected\":true}]}".utf8)
    let mapping = Air65KeyMapping(keyID: "n", inputKeyCode: "n", action: .volumeUp)
    let configured = try Air65FnShortcutService.configurationByUpsertingMapping(mapping, in: original)

    let root = try #require(JSONSerialization.jsonObject(with: configured) as? [String: Any])
    let profiles = try #require(root["profiles"] as? [[String: Any]])
    let complex = try #require(profiles[0]["complex_modifications"] as? [String: Any])
    let rules = try #require(complex["rules"] as? [[String: Any]])
    let manipulators = try #require(rules[0]["manipulators"] as? [[String: Any]])
    let conditions = try #require(manipulators[0]["conditions"] as? [[String: Any]])

    #expect(!conditions.contains { $0["type"] as? String == "frontmost_application_if" })
}

@Test("Air65 mapping removal only removes the selected physical key")
func air65MappingRemovalOnlyRemovesSelectedKey() throws {
    let original = Data("{\"profiles\":[{\"name\":\"Default\",\"selected\":true}]}".utf8)
    let yellow = try Air65FnShortcutService.configurationByInstallingManagedRule(in: original)
    let nMapping = Air65KeyMapping(keyID: "n", inputKeyCode: "n", action: .home)
    let withN = try Air65FnShortcutService.configurationByUpsertingMapping(nMapping, in: yellow)
    let removed = try Air65FnShortcutService.configurationByRemovingMapping(for: "n", in: withN)

    #expect(try Air65FnShortcutService.mappings(in: removed) == [.verifiedYellowKey])
}

@Test("Air65 mapping refuses controls without a standard keyboard event")
func air65MappingRefusesUnsupportedControls() {
    let original = Data("{\"profiles\":[{\"name\":\"Default\",\"selected\":true}]}".utf8)
    let knob = Air65KeyMapping(keyID: "knob", inputKeyCode: "unknown", action: .mute)

    #expect(throws: Air65FnShortcutError.unsupportedKey) {
        try Air65FnShortcutService.configurationByUpsertingMapping(knob, in: original)
    }
}

@Test("Air65 shortcut merge preserves unrelated Karabiner profiles and rules")
func air65ShortcutMergePreservesConfiguration() throws {
    let original = Data(
        """
        {
          "global": { "show_in_menu_bar": true },
          "profiles": [
            { "name": "Other profile", "selected": false },
            {
              "name": "Default profile",
              "selected": true,
              "complex_modifications": {
                "rules": [
                  { "description": "Keep me", "manipulators": [] }
                ]
              }
            }
          ]
        }
        """.utf8
    )

    let updated = try Air65FnShortcutService.configurationByInstallingManagedRule(in: original)
    #expect(Air65FnShortcutService.containsManagedRule(in: updated))

    let root = try #require(JSONSerialization.jsonObject(with: updated) as? [String: Any])
    let global = try #require(root["global"] as? [String: Any])
    #expect(global["show_in_menu_bar"] as? Bool == true)
    let profiles = try #require(root["profiles"] as? [[String: Any]])
    #expect(profiles.count == 2)
    #expect(profiles[0]["name"] as? String == "Other profile")

    let complex = try #require(profiles[1]["complex_modifications"] as? [String: Any])
    let rules = try #require(complex["rules"] as? [[String: Any]])
    #expect(rules.count == 2)
    #expect(rules.contains { $0["description"] as? String == "Keep me" })
}

@Test("Air65 shortcut rule is exact-device scoped and idempotent")
func air65ShortcutRuleIsScopedAndIdempotent() throws {
    let original = Data("{\"profiles\":[{\"name\":\"Default\",\"selected\":true}]}".utf8)
    let first = try Air65FnShortcutService.configurationByInstallingManagedRule(in: original)
    let second = try Air65FnShortcutService.configurationByInstallingManagedRule(in: first)

    let root = try #require(JSONSerialization.jsonObject(with: second) as? [String: Any])
    let profiles = try #require(root["profiles"] as? [[String: Any]])
    let complex = try #require(profiles[0]["complex_modifications"] as? [String: Any])
    let rules = try #require(complex["rules"] as? [[String: Any]])
    #expect(rules.count == 1)

    let manipulators = try #require(rules[0]["manipulators"] as? [[String: Any]])
    let from = try #require(manipulators[0]["from"] as? [String: Any])
    let to = try #require(manipulators[0]["to"] as? [[String: Any]])
    let conditions = try #require(manipulators[0]["conditions"] as? [[String: Any]])
    let identifiers = try #require(conditions[0]["identifiers"] as? [[String: Any]])

    #expect(from["key_code"] as? String == "f24")
    #expect(to[0]["apple_vendor_top_case_key_code"] as? String == "keyboard_fn")
    #expect(identifiers[0]["vendor_id"] as? Int == 0x19F5)
    #expect(identifiers[0]["product_id"] as? Int == 0x102B)
    #expect(identifiers[0]["is_keyboard"] as? Bool == true)
}

@Test("Air65 shortcut installation writes a verified backup and keeps permissions")
func air65ShortcutInstallationBacksUpConfiguration() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory
        .appending(path: "NuNuBar-Air65Fn-\(UUID().uuidString)", directoryHint: .isDirectory)
    defer { try? fileManager.removeItem(at: root) }

    let configDirectory = root.appending(path: ".config/karabiner", directoryHint: .isDirectory)
    try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
    let configURL = configDirectory.appending(path: "karabiner.json")
    let original = Data("{\"profiles\":[{\"name\":\"Default\",\"selected\":true}]}".utf8)
    try original.write(to: configURL)
    try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)

    let applications = root.appending(path: "Applications", directoryHint: .isDirectory)
    try fileManager.createDirectory(at: applications, withIntermediateDirectories: true)
    let service = Air65FnShortcutService(
        fileManager: fileManager,
        homeDirectory: root,
        applicationsDirectory: applications
    )
    let backupURL = configDirectory.appending(path: "known-backup.json")

    try service.installMapping(backupURL: backupURL)

    #expect(try Data(contentsOf: backupURL) == original)
    #expect(Air65FnShortcutService.containsManagedRule(in: try Data(contentsOf: configURL)))
    let attributes = try fileManager.attributesOfItem(atPath: configURL.path)
    #expect(attributes[.posixPermissions] as? Int == 0o600)
}

@Test("Air65 shortcut refuses malformed Karabiner rules")
func air65ShortcutRejectsMalformedConfiguration() {
    let malformed = Data("{\"profiles\":[{\"complex_modifications\":{\"rules\":\"unsafe\"}}]}".utf8)
    #expect(throws: Air65FnShortcutError.invalidConfiguration) {
        try Air65FnShortcutService.configurationByInstallingManagedRule(in: malformed)
    }
}

@Test("Air65 shortcut removal keeps unrelated Karabiner rules")
func air65ShortcutRemovalIsScoped() throws {
    let original = Data(
        """
        {
          "profiles": [
            {
              "name": "Default",
              "selected": true,
              "complex_modifications": {
                "rules": [{ "description": "Keep me", "manipulators": [] }]
              }
            }
          ]
        }
        """.utf8
    )
    let installed = try Air65FnShortcutService.configurationByInstallingManagedRule(in: original)
    let removed = try Air65FnShortcutService.configurationByRemovingManagedRule(in: installed)

    #expect(!Air65FnShortcutService.containsManagedRule(in: removed))
    let root = try #require(JSONSerialization.jsonObject(with: removed) as? [String: Any])
    let profiles = try #require(root["profiles"] as? [[String: Any]])
    let complex = try #require(profiles[0]["complex_modifications"] as? [String: Any])
    let rules = try #require(complex["rules"] as? [[String: Any]])
    #expect(rules.count == 1)
    #expect(rules[0]["description"] as? String == "Keep me")
}
