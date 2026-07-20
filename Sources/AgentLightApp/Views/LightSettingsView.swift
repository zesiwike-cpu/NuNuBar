import AgentLightCore
import AppKit
import SwiftUI

struct LightSettingsView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var model: AppModel

    var body: some View {
        SettingsPage {
            SettingsGroup(title: language.text(.customStatusColors)) {
                TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    VStack(spacing: 0) {
                        lightRow(.working, time: time)
                        lightRow(.waiting, time: time)
                        lightRow(.complete, time: time)
                        lightRow(.idle, time: time)
                    }
                }
            }

            HStack {
                Text(language.text(.usbColorHint))
                    .font(.system(size: SettingsLayout.secondaryTextSize))
                    .foregroundStyle(NuphyBarTheme.secondaryText)

                Spacer()

                Button {
                    model.resetLightSettings()
                } label: {
                    Label(language.text(.restoreDefaults), systemImage: "arrow.counterclockwise")
                }
                .font(.system(size: SettingsLayout.actionTextSize))
                .controlSize(.small)
                .disabled(model.lightSettingsAreDefault)
            }
            .padding(.horizontal, 2)

            SettingsGroup(title: language.text(.statusDurations)) {
                timingRow(
                    title: language.text(.completionDuration),
                    value: completionDurationBinding,
                    range: Int(AgentStateTiming.completionRange.lowerBound)...Int(AgentStateTiming.completionRange.upperBound),
                    unit: language.text(.secondsUnit)
                )
                Divider().padding(.leading, 2)
                timingRow(
                    title: language.text(.errorDuration),
                    value: errorDurationBinding,
                    range: Int(AgentStateTiming.errorRange.lowerBound)...Int(AgentStateTiming.errorRange.upperBound),
                    unit: language.text(.secondsUnit)
                )
                Divider().padding(.leading, 2)
                timingRow(
                    title: language.text(.workingTimeout),
                    value: workingTimeoutBinding,
                    range: 1...60,
                    unit: language.text(.minutesUnit)
                )
                Divider().padding(.leading, 2)
                timingRow(
                    title: language.text(.waitingTimeout),
                    value: waitingTimeoutBinding,
                    range: 1...60,
                    unit: language.text(.minutesUnit)
                )
            }

            SettingsNotice(text: language.text(.timingHint))

            if model.keyboardTransport != .usb {
                SettingsNotice(text: language.text(.usbRequiredForCustomColors))
            } else if let officialAirV3ModelName {
                SettingsNotice(text: language == .simplifiedChinese
                    ? "\(officialAirV3ModelName) 使用该型号自己的官方常亮和呼吸模式；闪烁由 NuNuBar 在有线连接下以 500ms 开关帧实现。"
                    : "\(officialAirV3ModelName) uses its model-specific official solid and breathe modes; NuNuBar renders blink with 500 ms acknowledged wired frames.")
            }
        }
    }

    private func lightRow(_ role: AgentLightColorRole, time: TimeInterval) -> some View {
        let color = model.lightPalette.color(for: role)
        let effect = model.lightPalette.effect(for: role)
        let brightness = model.lightPalette.brightness(for: role)
        return HStack(spacing: 9) {
            pairedPreview(
                effect: effect,
                color: color,
                brightness: brightness,
                time: time
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: role))
                    .font(.system(size: SettingsLayout.primaryTextSize))
                Text(color.hexString)
                    .font(.system(size: SettingsLayout.secondaryTextSize, design: .monospaced))
                    .foregroundStyle(NuphyBarTheme.secondaryText)
            }

            Spacer()

            Button {
                model.previewLight(role)
            } label: {
                Image(systemName: "play.fill")
                    .frame(width: 13, height: 13)
            }
            .buttonStyle(.borderless)
            .help(language.text(.previewColor))
            .disabled(model.keyboardTransport != .usb)

            Picker(language.text(.effectStyle), selection: effectBinding(for: role)) {
                ForEach(AgentLightEffect.allCases, id: \.self) { effect in
                    Text(title(for: effect)).tag(effect)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 66)

            ColorPicker(
                title(for: role),
                selection: colorBinding(for: role),
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(width: 30)

            Image(systemName: "sun.max")
                .font(.system(size: 10))
                .foregroundStyle(NuphyBarTheme.secondaryText)
                .accessibilityHidden(true)

            Slider(
                value: brightnessBinding(for: role),
                in: 0...Double(AgentLightPalette.maximumBrightness),
                step: 1
            )
            .controlSize(.mini)
            .frame(width: 46)
            .accessibilityLabel(language.text(.brightness))
            .help("\(language.text(.brightness)): \(brightness)%")

            Text("\(brightness)%")
                .font(.system(size: SettingsLayout.secondaryTextSize, design: .monospaced))
                .foregroundStyle(NuphyBarTheme.secondaryText)
                .frame(width: 32, alignment: .trailing)
        }
        .frame(height: 50)
    }

    private func pairedPreview(
        effect: AgentLightEffect,
        color: AgentLightRGBColor,
        brightness: UInt8,
        time: TimeInterval
    ) -> some View {
        HStack(spacing: 4) {
            LightStripPreview(
                effect: effect,
                time: time,
                baseColor: color,
                brightnessPercent: brightness,
                size: CGSize(width: 7, height: 30)
            )
            LightStripPreview(
                effect: effect,
                time: time,
                baseColor: color,
                brightnessPercent: brightness,
                size: CGSize(width: 7, height: 30)
            )
        }
        .frame(width: 24)
    }

    private func timingRow(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        unit: String
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: SettingsLayout.primaryTextSize))
            Spacer()
            Text("\(value.wrappedValue) \(unit)")
                .font(.system(size: SettingsLayout.secondaryTextSize, design: .monospaced))
                .foregroundStyle(NuphyBarTheme.secondaryText)
                .frame(width: 58, alignment: .trailing)
            Stepper("", value: value, in: range)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
        }
        .frame(height: 34)
    }

    private var completionDurationBinding: Binding<Int> {
        Binding(
            get: { Int(model.stateTiming.completionSeconds) },
            set: { model.updateCompletionDuration(seconds: Int64($0)) }
        )
    }

    private var errorDurationBinding: Binding<Int> {
        Binding(
            get: { Int(model.stateTiming.errorSeconds) },
            set: { model.updateErrorDuration(seconds: Int64($0)) }
        )
    }

    private var workingTimeoutBinding: Binding<Int> {
        Binding(
            get: { Int(model.stateTiming.workingTimeoutSeconds / 60) },
            set: { model.updateWorkingTimeout(minutes: Int64($0)) }
        )
    }

    private var waitingTimeoutBinding: Binding<Int> {
        Binding(
            get: { Int(model.stateTiming.waitingTimeoutSeconds / 60) },
            set: { model.updateWaitingTimeout(minutes: Int64($0)) }
        )
    }

    private func colorBinding(for role: AgentLightColorRole) -> Binding<Color> {
        Binding(
            get: { model.lightPalette.color(for: role).swiftUIColor },
            set: { model.updateLightColor(AgentLightRGBColor($0), for: role) }
        )
    }

    private func effectBinding(for role: AgentLightColorRole) -> Binding<AgentLightEffect> {
        Binding(
            get: { model.lightPalette.effect(for: role) },
            set: { model.updateLightEffect($0, for: role) }
        )
    }

    private func brightnessBinding(for role: AgentLightColorRole) -> Binding<Double> {
        Binding(
            get: { Double(model.lightPalette.brightness(for: role)) },
            set: { model.updateLightBrightness(UInt8($0.rounded()), for: role) }
        )
    }

    private func title(for role: AgentLightColorRole) -> String {
        switch role {
        case .working: language.text(.working)
        case .waiting: language.text(.waiting)
        case .complete: language.text(.taskComplete)
        case .idle: language.text(.idle)
        }
    }

    private func title(for effect: AgentLightEffect) -> String {
        switch effect {
        case .solid: language.text(.solidEffect)
        case .breathe: language.text(.breatheEffect)
        case .blink: language.text(.blinkEffect)
        }
    }

    private var officialAirV3ModelName: String? {
        guard model.keyboardTransport == .usb,
              let keyboardModel = model.keyboardModel,
              SupportedOfficialNuPhyKeyboard.models.contains(where: {
                  keyboardModel.caseInsensitiveCompare($0.productName) == .orderedSame
              }) else { return nil }
        return keyboardModel
    }
}

extension AgentLightRGBColor {
    var swiftUIColor: Color {
        Color(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255
        )
    }

    init(_ color: Color) {
        let resolved = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        self.init(
            red: UInt8((max(0, min(1, resolved.redComponent)) * 255).rounded()),
            green: UInt8((max(0, min(1, resolved.greenComponent)) * 255).rounded()),
            blue: UInt8((max(0, min(1, resolved.blueComponent)) * 255).rounded())
        )
    }

    var hexString: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }
}
