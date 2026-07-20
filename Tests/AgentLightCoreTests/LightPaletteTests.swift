import Foundation
import Testing
@testable import AgentLightCore

@Test("light settings have deterministic defaults for every state")
func defaultLightPalette() {
    let palette = AgentLightPalette.default

    #expect(palette.idle == AgentLightRGBColor(red: 0, green: 0, blue: 0))
    #expect(palette.working == AgentLightRGBColor(red: 252, green: 84, blue: 0))
    #expect(palette.waiting == AgentLightRGBColor(red: 255, green: 0, blue: 0))
    #expect(palette.complete == AgentLightRGBColor(red: 0, green: 255, blue: 0))
    #expect(palette.idleEffect == .solid)
    #expect(palette.workingEffect == .breathe)
    #expect(palette.waitingEffect == .blink)
    #expect(palette.completeEffect == .solid)
    #expect(palette.idleBrightness == 100)
    #expect(palette.workingBrightness == 100)
    #expect(palette.waitingBrightness == 100)
    #expect(palette.completeBrightness == 100)
    #expect(palette.color(for: .error) == palette.waiting)
    #expect(palette.effect(for: .error) == palette.waitingEffect)
    #expect(palette.brightness(for: .error) == palette.waitingBrightness)
}

@Test("light settings persist in the shared application support file")
func persistedLightPalette() {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let url = directory.appending(path: "palette.json")
    let store = AgentLightPaletteStore(url: url, legacySuiteName: nil)
    defer { try? FileManager.default.removeItem(at: directory) }

    var palette = AgentLightPalette.default
    palette.setColor(AgentLightRGBColor(red: 4, green: 5, blue: 6), for: .idle)
    palette.setColor(AgentLightRGBColor(red: 7, green: 8, blue: 9), for: .working)
    palette.setEffect(.blink, for: .idle)
    palette.setEffect(.solid, for: .working)
    palette.setBrightness(42, for: .idle)
    palette.setBrightness(67, for: .working)
    store.save(palette)

    #expect(store.load() == palette)
    #expect((try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int) == 0o600)
    store.reset()
    #expect(store.load() == .default)
}

@Test("v2 color-only files migrate without losing existing choices")
func colorOnlyPaletteMigration() throws {
    let data = Data(#"{"waiting":{"blue":3,"green":2,"red":1},"working":{"red":4,"blue":6,"green":5},"complete":{"blue":9,"red":7,"green":8}}"#.utf8)
    let palette = try JSONDecoder().decode(AgentLightPalette.self, from: data)

    #expect(palette.working == AgentLightRGBColor(red: 4, green: 5, blue: 6))
    #expect(palette.waiting == AgentLightRGBColor(red: 1, green: 2, blue: 3))
    #expect(palette.complete == AgentLightRGBColor(red: 7, green: 8, blue: 9))
    #expect(palette.idle == AgentLightPalette.default.idle)
    #expect(palette.idleEffect == .solid)
    #expect(palette.workingEffect == .breathe)
    #expect(palette.waitingEffect == .blink)
    #expect(palette.completeEffect == .solid)
    #expect(palette.idleBrightness == 100)
    #expect(palette.workingBrightness == 100)
    #expect(palette.waitingBrightness == 100)
    #expect(palette.completeBrightness == 100)
}

@Test("brightness is clamped and scales legacy V2 colors")
func normalizedAndAdjustedBrightness() {
    var palette = AgentLightPalette.default
    palette.setBrightness(50, for: .working)

    #expect(palette.brightness(for: AgentLightColorRole.working) == 50)
    #expect(palette.brightnessAdjustedColor(for: .working) == AgentLightRGBColor(
        red: 126,
        green: 42,
        blue: 0
    ))

    palette.setBrightness(255, for: .working)
    #expect(palette.brightness(for: AgentLightColorRole.working) == 100)
}
