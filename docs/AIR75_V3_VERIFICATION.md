# Air75 V3 verified wired path

Path ID: `air75-v3-macos-wired-1.0.14.6`

This route is for an exact Air75 V3 `19F5:1028` on Apple Silicon macOS over
wired USB. It uses NuPhy's official 64-byte control interface at HID usage
`0001:0000`; it never uses a V2 NuNuBar firmware image or the V2 DFU catalog.

## Firmware requirement

NuNuBar requires official Air75 V3 firmware `1.0.14.6` or later. On the tested
keyboard, `1.0.13.6` acknowledged `D6` writes but did not apply the side-light
state. NuPhyIO reproduced the same failure, proving that Hooks and NuNuBar were
not the cause. After a NuPhyIO configuration export and the official update to
`1.0.14.6`, NuPhyIO restored the configuration and side-light writes became
visible.

NuNuBar 0.15.0 reads the official firmware payload and blocks the setup
assistant below the minimum. The user must separately approve any update and
perform it at `https://drive.nuphy.io`; NuNuBar does not silently update or
flash this keyboard.

## Captured protocol

The live NuPhyIO path uses report ID `0`, a session-key XOR, and acknowledged
64-byte reports. A side-light state is two `D6` writes:

1. eight contiguous bytes at offset `9`: mode, brightness, speed, custom RGB
   flag, color index, red, green, blue;
2. one brightness byte at offset `10`.

Verified official mode IDs are static `2` and breathe `3`; custom RGB uses flag
`0`. NuNuBar renders blink as acknowledged 500 ms static on/off frames because
the official side-light set has no separate blink mode.

## Always-on idle lighting

Air75 V3 firmware can turn all lighting off after inactivity even when NuNuBar's
current state is a non-black solid color. This is the keyboard's Auto-sleep
preference, not a Codex state transition or HID failure.

The [official Air75 V3 manual](https://cdn.shopify.com/s/files/1/0268/7297/1373/files/Air75_V3_Quick_Guide_FAQ.pdf?v=1753438891)
specifies a short `Fn + ]` press to enable or disable Auto-sleep. For always-on
status lighting:

1. choose a non-black idle color and the solid effect in NuNuBar;
2. short-press `Fn + ]` once while Auto-sleep is enabled;
3. leave the keyboard untouched past its previous sleep interval and confirm
   the idle side lights remain visible;
4. verify a real Codex state still replaces idle and returns to it normally.

NuNuBar intentionally does not simulate keystrokes or poll the HID interface to
defeat sleep. The firmware preference is deterministic and avoids unnecessary
traffic.

## Physical acceptance

- NuPhyIO static cyan at 99% brightness changed both side lights.
- The bundled helper visibly cycled configured working, complete, waiting, and
  idle states after NuPhyIO released the HID interface.
- NuNuBar 0.14.1 build 50 or later detects firmware `1.0.14.6`, owns the persistent HID
  session, and uses the installed Codex Hook helper path.
- A real Codex task was physically observed changing from the configured orange
  working breathe effect to green solid when the response completed. This
  verifies the installed `UserPromptSubmit` and `Stop` Hook path, not only the
  direct demo.
- Per-state brightness passed physical acceptance in NuNuBar 0.15.0 build 54.
  The user reduced working from 100% to 20% and visibly observed the side lights
  dim. The saved value and delivery log were both 20%, while the keyboard's
  `D5` state readback returned brightness byte `0x14`, exactly decimal 20.

`PermissionRequest` remains covered by the shared Hook mapping and automated
tests; ordinary acceptance should also observe it when the next real approval
request occurs.

## Reusable setup order

1. Confirm printed model Air75 V3 and USB identity `19F5:1028`.
2. Use wired mode and confirm HID usage `0001:0000` with 64-byte reports.
3. Install and launch NuNuBar, then grant Input Monitoring.
4. Read firmware in the App. If it is below `1.0.14.6`, export NuPhyIO
   configuration, obtain explicit approval, update officially, and reconnect.
5. Run the App light self-test. If it works, configure and approve the four
   Codex Hooks; do not open NuPhyIO at the same time.
6. If always-on idle is required, set a non-black solid idle color and disable
   Auto-sleep with one short `Fn + ]` press.
7. Verify real Codex working, waiting, complete, idle retention, and USB
   reconnect replay.

Optional key and knob mappings are a separate Karabiner path. Read
[`AIR75_V3_KEY_MAPPING.md`](AIR75_V3_KEY_MAPPING.md); they do not change this
lighting acceptance or require keyboard firmware changes.
