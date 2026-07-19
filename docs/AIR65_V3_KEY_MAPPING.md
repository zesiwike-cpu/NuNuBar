# Air65 V3 key mapping

NuNuBar 0.13.0 provides a clickable Air65 V3 mapping editor on macOS. Mappings
are applied by official Karabiner-Elements and scoped to the exact `19F5:102B`
device, so they do not affect the built-in Mac keyboard or another NuPhy model.

## Dependency boundary

- Air65 V3 status lighting does not require Karabiner.
- Key and knob mappings in this release require official Karabiner-Elements on
  macOS and remain inactive when it is not installed and running.
- NuNuBar does not bundle a keyboard driver. It backs up and merges only its
  managed rules after the user confirms the configuration change.

## Create a mapping

1. Connect Air65 V3 over USB and open NuNuBar > Keyboard > Key Mapping.
2. Select a key in the keyboard view. For the knob, also select Left, Press, or
   Right.
3. Choose a target from the System or Codex action group.
4. Select Create. The confirmation names `~/.config/karabiner/karabiner.json`
   and the exact timestamped sibling backup.
5. Confirm the change. A green dot identifies the saved mapping. The mapping
   replaces that key's original action.

## Knob

Configure the knob in NuPhyIO first:

- Left rotation: `F21`
- Press: `F22`
- Right rotation: `F23`

These three inputs are verified on Air65 V3. NuNuBar stores them independently,
so a useful setup is Codex Previous Task, New Task, and Next Task. Removing one
direction does not remove either of the others.

NuNuBar 0.13.1 build 48 passed an end-to-end hardware check on 2026-07-19. A
physical right rotation entered as `F23`, Karabiner produced
`Command-Shift-]`, and Codex visibly switched to the next task.

Use the waveform button beside the input label to open the eight-second raw
carrier probe. Keep NuNuBar foreground while testing. If Codex is foreground,
the Codex-scoped Karabiner rule consumes the carrier first, so EventViewer shows
the mapped shortcut instead of `F23`; that is expected. Fn/Globe indicates the
separate global `F24` yellow-key route and is not a valid knob result.

## Codex actions

Available actions include new task, sidebar, bottom panel, file tree, review
panel, terminal, browser, previous or next task, keyboard shortcuts, and
settings. Codex rules activate only while Codex is frontmost, preserving the
original knob or key event in every other app. System actions are global and
replace the selected key's original behavior.

An existing verified yellow `PGDN` / `F24` / Fn rule is imported automatically.
`F24` is only the input event used by that historical verified route and now
appears as compact technical state beside the mapping. Use Open Keyboard-Level
Settings to change the keyboard's own NuPhyIO output when necessary.

Native Fn remains unavailable because it does not expose an ordinary input
event that Karabiner can remap. Delete removes only the NuNuBar rule for the
selected key or knob direction; unrelated Karabiner profiles and rules remain
intact.

Key mapping does not change Codex Hooks, NuNuBar status lighting, keyboard
firmware, or DFU state.
