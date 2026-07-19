import SwiftUI

struct Air65KeyboardKey: Identifiable, Equatable, Sendable {
    let id: String
    let legend: String
    let width: Double
    let inputKeyCode: String?

    var isYellowShortcut: Bool { id == Air65KeyboardLayout.yellowShortcutKeyID }
    var isMappable: Bool { inputKeyCode != nil || id == Air65KeyboardLayout.knobKeyID }
}

enum Air65KeyboardLayout {
    static let yellowShortcutKeyID = "pgdn"
    static let knobKeyID = "knob"
    static let knobLeftKeyID = "knob_left"
    static let knobPressKeyID = "knob_press"
    static let knobRightKeyID = "knob_right"

    static let knobControls: [Air65KeyboardKey] = [
        Air65KeyboardKey(id: knobLeftKeyID, legend: "LEFT", width: 1, inputKeyCode: "f21"),
        Air65KeyboardKey(id: knobPressKeyID, legend: "PRESS", width: 1, inputKeyCode: "f22"),
        Air65KeyboardKey(id: knobRightKeyID, legend: "RIGHT", width: 1, inputKeyCode: "f23"),
    ]

    static let rows: [[Air65KeyboardKey]] = [
        row([
            ("escape", "ESC", 1, "escape"),
            ("1", "1", 1, "1"), ("2", "2", 1, "2"),
            ("3", "3", 1, "3"), ("4", "4", 1, "4"),
            ("5", "5", 1, "5"), ("6", "6", 1, "6"),
            ("7", "7", 1, "7"), ("8", "8", 1, "8"),
            ("9", "9", 1, "9"), ("0", "0", 1, "0"),
            ("minus", "-", 1, "hyphen"), ("equal", "=", 1, "equal_sign"),
            ("backspace", "BACK", 2, "delete_or_backspace"),
            (knobKeyID, "KNOB", 1, nil),
        ]),
        row([
            ("tab", "TAB", 1.45, "tab"),
            ("q", "Q", 1, "q"), ("w", "W", 1, "w"),
            ("e", "E", 1, "e"), ("r", "R", 1, "r"),
            ("t", "T", 1, "t"), ("y", "Y", 1, "y"),
            ("u", "U", 1, "u"), ("i", "I", 1, "i"),
            ("o", "O", 1, "o"), ("p", "P", 1, "p"),
            ("left_bracket", "[", 1, "open_bracket"),
            ("right_bracket", "]", 1, "close_bracket"),
            ("backslash", "\\", 1.55, "backslash"),
            (yellowShortcutKeyID, "PGDN", 1, "f24"),
        ]),
        row([
            ("caps_lock", "CAPS", 1.75, "caps_lock"),
            ("a", "A", 1, "a"), ("s", "S", 1, "s"),
            ("d", "D", 1, "d"), ("f", "F", 1, "f"),
            ("g", "G", 1, "g"), ("h", "H", 1, "h"),
            ("j", "J", 1, "j"), ("k", "K", 1, "k"),
            ("l", "L", 1, "l"), ("semicolon", ";", 1, "semicolon"),
            ("quote", "'", 1, "quote"),
            ("return", "ENTER", 2.15, "return_or_enter"),
            ("home", "HOME", 1, "home"),
        ]),
        row([
            ("left_shift", "SHIFT", 2.2, "left_shift"),
            ("z", "Z", 1, "z"), ("x", "X", 1, "x"),
            ("c", "C", 1, "c"), ("v", "V", 1, "v"),
            ("b", "B", 1, "b"), ("n", "N", 1, "n"),
            ("m", "M", 1, "m"), ("comma", ",", 1, "comma"),
            ("period", ".", 1, "period"), ("slash", "/", 1, "slash"),
            ("right_shift", "SHIFT", 1.8, "right_shift"),
            ("up_arrow", "↑", 1, "up_arrow"), ("end", "END", 1, "end"),
        ]),
        row([
            ("left_control", "CTRL", 1.25, "left_control"),
            ("left_option", "OPT", 1.25, "left_option"),
            ("left_command", "CMD", 1.25, "left_command"),
            ("spacebar", "SPACE", 5.8, "spacebar"),
            ("right_command", "CMD", 1.25, "right_command"),
            ("fn", "FN", 1.1, nil),
            ("right_control", "CTRL", 1.1, "right_control"),
            ("left_arrow", "←", 1, "left_arrow"),
            ("down_arrow", "↓", 1, "down_arrow"),
            ("right_arrow", "→", 1, "right_arrow"),
        ]),
    ]

    static func key(id: String) -> Air65KeyboardKey? {
        rows.lazy.flatMap { $0 }.first { $0.id == id }
            ?? knobControls.first { $0.id == id }
    }

    static func duplicateCarriers(
        in assignments: [String: String]
    ) -> [String: [String]] {
        let grouped = Dictionary(grouping: assignments.keys) { assignments[$0] ?? "" }
        return grouped.reduce(into: [:]) { result, entry in
            let carrier = entry.key
            let keyIDs = entry.value.sorted()
            if !carrier.isEmpty, keyIDs.count > 1 {
                result[carrier] = keyIDs
            }
        }
    }

    private static func row(
        _ definitions: [(String, String, Double, String?)]
    ) -> [Air65KeyboardKey] {
        definitions.map(Air65KeyboardKey.init)
    }
}

struct Air65KeyboardLayoutView: View {
    @Binding var selection: String
    let mappedKeyIDs: Set<String>

    private let horizontalSpacing: CGFloat = 2.5
    private let rowHeight: CGFloat = 27

    init(selection: Binding<String>, mappedKeyIDs: Set<String> = []) {
        _selection = selection
        self.mappedKeyIDs = mappedKeyIDs
    }

    var body: some View {
        VStack(spacing: 3) {
            ForEach(Array(Air65KeyboardLayout.rows.enumerated()), id: \.offset) { _, row in
                GeometryReader { geometry in
                    let keyWidth = availableKeyWidth(in: geometry.size.width, for: row)

                    HStack(spacing: horizontalSpacing) {
                        ForEach(row) { key in
                            let isMapped = mappedKeyIDs.contains(key.id)
                            Button {
                                selection = key.id
                            } label: {
                                ZStack(alignment: .bottomTrailing) {
                                    Text(key.legend)
                                        .font(.system(size: key.legend.count > 4 ? 6.5 : 7.5, weight: .semibold))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    if isMapped {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 4.5, height: 4.5)
                                            .padding(2)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(Air65KeyButtonStyle(
                                isSelected: selection == key.id,
                                isYellowShortcut: key.isYellowShortcut,
                                isMapped: isMapped,
                                isMappable: key.isMappable
                            ))
                            .frame(width: keyWidth * key.width, height: rowHeight)
                            .help(isMapped ? "\(key.legend) · Mapped" : key.legend)
                            .accessibilityLabel(key.legend)
                            .accessibilityValue(isMapped ? "Mapped" : "Not mapped")
                        }
                    }
                }
                .frame(height: rowHeight)
            }
        }
        .padding(5)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Air65 V3")
    }

    private func availableKeyWidth(
        in availableWidth: CGFloat,
        for row: [Air65KeyboardKey]
    ) -> CGFloat {
        let spacing = horizontalSpacing * CGFloat(max(row.count - 1, 0))
        let totalUnits = row.reduce(0) { $0 + $1.width }
        return max(0, availableWidth - spacing) / totalUnits
    }
}

private struct Air65KeyButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isYellowShortcut: Bool
    let isMapped: Bool
    let isMappable: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isMappable ? Color.primary : NuphyBarTheme.tertiaryText)
            .background(
                backgroundColor(isPressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 0.5)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isYellowShortcut {
            return Color.yellow.opacity(isPressed ? 0.7 : 0.52)
        }
        if isMapped {
            return Color.green.opacity(isPressed ? 0.2 : 0.1)
        }
        if isSelected {
            return NuphyBarTheme.accent.opacity(0.12)
        }
        return Color(nsColor: .windowBackgroundColor).opacity(isPressed ? 0.65 : 1)
    }

    private var borderColor: Color {
        if isSelected { return NuphyBarTheme.accent }
        if isMapped { return Color.green.opacity(0.7) }
        return Color(nsColor: .separatorColor)
    }
}
