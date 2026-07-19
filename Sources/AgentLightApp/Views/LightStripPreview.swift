import AgentLightCore
import SwiftUI

enum LightStripStyle {
    static let borderWidth: CGFloat = 0.75
    static let shellOpacity = 0.18
}

struct LightStripSample: Equatable {
    let hue: Double
    let saturation: Double
    let brightness: Double
    let opacity: Double

    var color: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
            .opacity(opacity)
    }
}

enum LightStripModel {
    static func samples(
        effect: AgentLightEffect,
        time: TimeInterval,
        count: Int,
        baseColor: AgentLightRGBColor
    ) -> [LightStripSample] {
        guard count > 0 else { return [] }
        let color = colorSample(baseColor)
        let level = brightnessLevel(effect: effect, time: time)
        let sample = LightStripSample(
            hue: color.hue,
            saturation: color.saturation,
            brightness: color.brightness * level,
            opacity: 1
        )
        return [LightStripSample](repeating: sample, count: count)
    }

    private static func brightnessLevel(effect: AgentLightEffect, time: TimeInterval) -> Double {
        switch effect {
        case .solid:
            return 1
        case .breathe:
            let phase = positiveRemainder(time * 0.5, modulus: 1)
            return 0.14 + 0.86 * (0.5 - 0.5 * cos(phase * 2 * .pi))
        case .blink:
            return positiveRemainder(time, modulus: 1) < 0.5 ? 1 : 0.04
        }
    }

    private static func colorSample(_ color: AgentLightRGBColor) -> LightStripSample {
        let red = Double(color.red) / 255
        let green = Double(color.green) / 255
        let blue = Double(color.blue) / 255
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        let saturation = maximum == 0 ? 0 : delta / maximum
        let hue: Double

        if delta == 0 {
            hue = 0
        } else if maximum == red {
            hue = positiveRemainder((green - blue) / delta / 6, modulus: 1)
        } else if maximum == green {
            hue = ((blue - red) / delta + 2) / 6
        } else {
            hue = ((red - green) / delta + 4) / 6
        }

        return LightStripSample(
            hue: hue,
            saturation: saturation,
            brightness: maximum,
            opacity: 1
        )
    }

    private static func positiveRemainder(_ value: Double, modulus: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: modulus)
        return remainder >= 0 ? remainder : remainder + modulus
    }
}

struct LightStripPreview: View {
    let effect: AgentLightEffect
    let time: TimeInterval
    let baseColor: AgentLightRGBColor
    var size = CGSize(width: 10, height: 40)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(LightStripStyle.shellOpacity))

            RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)
                .fill(gradient)
                .padding(LightStripStyle.borderWidth)
                .shadow(color: glowColor.opacity(0.42), radius: 2.5)
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    private var outerCornerRadius: CGFloat {
        min(size.width / 2, 5)
    }

    private var innerCornerRadius: CGFloat {
        max(outerCornerRadius - LightStripStyle.borderWidth, 0)
    }

    private var gradient: LinearGradient {
        let samples = LightStripModel.samples(
            effect: effect,
            time: time,
            count: 24,
            baseColor: baseColor
        )
        let stops = samples.enumerated().map { index, sample in
            Gradient.Stop(
                color: sample.color,
                location: CGFloat(index) / CGFloat(max(samples.count - 1, 1))
            )
        }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    private var glowColor: Color {
        LightStripModel.samples(
            effect: effect,
            time: time,
            count: 1,
            baseColor: baseColor
        ).first?.color ?? .clear
    }
}
