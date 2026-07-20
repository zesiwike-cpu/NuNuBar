# Air75 V3 key mapping

NuNuBar 0.15.0 adds a clickable 75% ANSI mapping editor for the exact wired
Air75 V3 `19F5:1028`. The layout is separate from Air65 V3 and includes the
function row, right navigation column, and the top-right knob.

## Boundaries

- Status lighting does not require Karabiner.
- Key and knob mappings require official Karabiner-Elements on macOS.
- Every generated rule has an exact `19F5:1028` device condition.
- Air65 V3 rules, other Karabiner profiles, and unrelated rules are preserved.
- Codex actions trigger only while the Codex App is frontmost.
- Air75 V3 mapping requires wired USB. It never requires DFU or custom firmware.

## Use the editor

1. Connect Air75 V3 by USB and open NuNuBar > Keyboard > Key Mapping.
2. Select the physical key or the knob.
3. Choose a system action or Codex action.
4. Review the Karabiner configuration and timestamped backup paths, then confirm.
5. Test the physical control. Delete removes only that model and control's
   NuNuBar rule.

## Knob carriers

The editor reserves three independent keyboard events:

| Physical control | NuPhyIO carrier |
| --- | --- |
| Left rotation | `F21` |
| Press | `F22` |
| Right rotation | `F23` |

Assign these carriers to the knob in NuPhyIO before creating the corresponding
NuNuBar mappings. The waveform button checks the actual function-key input for
the selected direction. Do not claim the knob path is hardware-verified until
all three directions pass this probe and one real mapped action is observed.

## Recovery

NuNuBar creates a timestamped backup beside
`~/.config/karabiner/karabiner.json` before every change. Prefer deleting an
individual mapping in the App. Restore a full backup only when no later
Karabiner changes need to be retained.
