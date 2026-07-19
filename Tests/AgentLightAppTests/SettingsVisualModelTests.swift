@testable import AgentLightApp
import AgentLightCore
import AppKit
import SwiftUI
import Testing

@Test("every supported Agent has a visible brand mark")
@MainActor
func everySupportedAgentHasAVisibleBrandMark() throws {
    let providers: [AgentProvider] = [
        .codex,
        .claudeCode,
        .openCode,
        .grokBuild,
        .hermes,
        .openClaw,
        .antigravity,
    ]

    for provider in providers {
        let renderer = ImageRenderer(content: AgentBrandIcon(provider: provider, size: 96))
        renderer.scale = 1

        let image = try #require(renderer.nsImage)
        let bitmap = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init))
        let visiblePixels = (0..<bitmap.pixelsHigh).reduce(into: 0) { count, y in
            for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                count += 1
            }
        }

        #expect(visiblePixels > 80, "\(provider.rawValue) rendered an empty icon")
    }
}

@Test("light previews render solid, breathe, and blink modes")
func configurableLightEffectPreviews() {
    let orange = AgentLightRGBColor(red: 255, green: 80, blue: 0)
    let solid = LightStripModel.samples(effect: .solid, time: 0, count: 5, baseColor: orange)
    let breatheLow = LightStripModel.samples(effect: .breathe, time: 0, count: 5, baseColor: orange)
    let breatheHigh = LightStripModel.samples(effect: .breathe, time: 1, count: 5, baseColor: orange)
    let blinkOn = LightStripModel.samples(effect: .blink, time: 0, count: 5, baseColor: orange)
    let blinkOff = LightStripModel.samples(effect: .blink, time: 0.75, count: 5, baseColor: orange)

    #expect(solid.allSatisfy { $0.brightness == 1 })
    #expect(breatheLow.allSatisfy { $0.brightness < 0.2 })
    #expect(breatheHigh.allSatisfy { $0.brightness > 0.95 })
    #expect(blinkOn.allSatisfy { $0.brightness == 1 })
    #expect(blinkOff.allSatisfy { $0.brightness < 0.05 })
    #expect(solid.allSatisfy { abs($0.hue - 0.052) < 0.001 })
}

@Test("settings navigation exposes a dedicated light editor")
func settingsNavigationIncludesLightEditor() {
    #expect(SettingsSection.allCases.map { $0.title(in: .simplifiedChinese) } == ["Agent", "键盘", "灯光", "关于"])
    #expect(SettingsSection.allCases.map(\.systemImage) == [
        "point.3.connected.trianglepath.dotted",
        "keyboard",
        "lightbulb",
        "info.circle",
    ])
}

@Test("settings window matches the compact PopClip reference scale")
func settingsWindowMatchesCompactReferenceScale() {
    #expect(SettingsLayout.windowWidth == 440)
    #expect(SettingsLayout.windowHeight == 390)
    #expect(SettingsLayout.tabWidth == 56)
    #expect(SettingsLayout.tabHeight == 48)
    #expect(SettingsLayout.horizontalPadding <= 18)
}

@Test("about content is one compact, aligned settings group")
func aboutContentUsesCompactAlignedLayout() {
    #expect(SettingsLayout.aboutContentWidth == 280)
    #expect(SettingsLayout.aboutRowHeight <= 30)
    #expect(SettingsLayout.aboutSectionSpacing <= 24)
}

@Test("light strip preview uses a hairline shell")
func lightStripPreviewUsesAHairlineShell() {
    #expect(LightStripStyle.borderWidth <= 0.8)
}

@Test("settings typography and rows use compact Mac utility sizing")
func settingsTypographyUsesCompactUtilitySizing() {
    #expect(SettingsLayout.sectionTitleSize <= 11.5)
    #expect(SettingsLayout.primaryTextSize <= 12.5)
    #expect(SettingsLayout.secondaryTextSize <= 9.5)
    #expect(SettingsLayout.actionTextSize >= 11)
    #expect(SettingsLayout.agentRowHeight <= 36)
    #expect(SettingsLayout.lightRowHeight <= 34)
}

@Test("light strip shell stays softer than primary text")
func lightStripShellUsesASubtleSemanticTone() {
    #expect(LightStripStyle.shellOpacity < 0.3)
}

@Test("new Agent integrations use bundled official brand assets")
func newAgentsUseOfficialBrandAssets() {
    #expect(AgentBrandAsset.forProvider(.grokBuild) == .init(name: "GrokBuild", extension: "svg"))
    #expect(AgentBrandAsset.forProvider(.hermes) == .init(name: "Hermes", extension: "png"))
    #expect(AgentBrandAsset.forProvider(.openClaw) == .init(name: "OpenClaw", extension: "png"))
    #expect(AgentBrandAsset.forProvider(.antigravity) == .init(name: "Antigravity", extension: "png"))
}

@Test("the default idle preview is deterministically off")
func defaultIdlePreviewIsOff() {
    let samples = LightStripModel.samples(
        effect: AgentLightPalette.default.idleEffect,
        time: 123.45,
        count: 5,
        baseColor: AgentLightPalette.default.idle
    )

    #expect(samples.allSatisfy { $0.brightness == 0 })
    #expect(samples.allSatisfy { $0.saturation == 0 })
}
