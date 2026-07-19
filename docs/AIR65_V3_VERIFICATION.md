# Air65 V3 hardware verification

Last updated: 2026-07-19

## Exact device

- Product: `Air65 V3`
- Transport: USB
- VID:PID: `19F5:102B`
- HID usage page/usage: `0001:0000`
- Input/output report size: 64 bytes
- Firmware path: official firmware control HID; no DFU and no firmware write

## What the user needs

- Apple Silicon Mac with macOS 14 or later;
- printed model confirmed as Air65 V3;
- wired USB mode and a data-capable cable;
- NuNuBar installed in `/Applications` and kept running;
- manual review and approval of the four Codex Hooks.

No VIA backup, recovery image, DFU entry, or keyboard firmware write is needed.

Optional key and knob mapping additionally requires official
Karabiner-Elements. Configure the knob in NuPhyIO as left `F21`, press `F22`,
and right `F23`.

## Verified result

- NuNuBar identifies the exact `19F5:102B` 64-byte official control interface
  and reads the active light profile before sending a state.
- The in-App orange, green, and red self-test is visible on the retail keyboard.
- Real Codex working and complete events visibly change the side light.
- NuNuBar 0.13.1 build 48 resends the current state at a new Codex delivery
  checkpoint and recovers a stale HID session automatically.
- A physical USB reconnect restores delivery without restarting NuNuBar.
- With the optional mapping enabled, a physical `F23` right rotation produces
  `Command-Shift-]` and switches Codex to the next task.

Codex Hooks write only coarse local state. The installed NuNuBar App owns the
keyboard session. Karabiner handles optional shortcuts and does not participate
in status-light delivery.

## Raw carrier versus mapped output

The mapping editor's input probe verifies the raw `F21`/`F22`/`F23` carrier.
Bring NuNuBar to the foreground before starting the eight-second probe. When
Codex remains foreground, Karabiner intentionally consumes `F23` first and
EventViewer reports the configured output (`Command-Shift-]`) instead of the
raw function key. That transformed output is the correct end-to-end acceptance
signal, not evidence that the knob is still emitting `F24` or Fn/Globe.

## Limits

- Air65 V3 status lighting requires wired USB. Bluetooth is typing-only.
- Status lighting does not require Karabiner; shortcuts do.
- A successful command or HID acknowledgement is not physical acceptance. The
  user must see the real light change.
- This result does not apply to another Air V3 size or any V2 keyboard.

## Optional checks beyond the core verified path

- Visually confirm the configured idle state and at least one non-default custom
  color selected in the App, including consistent output on every intended side
  light.
- Repeat unplug/replug acceptance on the current 0.13.1 build with automatic
  mode discovery enabled.

Automatic mode discovery, default orange/green/red states, real Codex-driven
orange/green transitions, the 0.13.1 working-light checkpoint, and the physical
`F23` right-knob Codex task switch are verified. Do not claim the remaining
custom/idle visuals or the current-build replug check until they are recorded
here.
