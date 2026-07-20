# Verified setup paths

NuNuBar uses a success-first support model. A path is called **verified** only
after the exact hardware and host combination completes installation, state
lighting, disconnect recovery, and normal keyboard-use checks. Compiling or
matching a USB product ID is not enough.

## Three verified paths

| Host and keyboard | Status | Recommended path |
| --- | --- | --- |
| Apple Silicon Mac, macOS 14+, Air65 V3 `19F5:102B` | Hardware verified for wired Codex lighting and optional knob mapping | Official USB control interface; no firmware and no DFU |
| Apple Silicon Mac, macOS 14+, Air75 V3 `19F5:1028` | Hardware verified for official wired side-light control | Official firmware `1.0.14.6` or later; separately approved NuPhyIO update only when older |
| Apple Silicon Mac, Air96 V2 ANSI `19F5:3266` | Verified with custom firmware v7 | Test existing firmware first; only failure requires backup, recovery image, and two flash confirmations |

Air60 V2, Air75 V2, Halo75 V2, Windows, Intel Mac, other NuPhy families, and
unlisted layouts are not normal-user success paths. Their code or firmware may
remain for contributors, but Codex must not choose them during ordinary setup.

## How Codex chooses a path

1. Record the host OS, architecture, exact printed keyboard model and layout.
2. Detect the application-mode USB VID/PID, HID usage, and report sizes.
3. Match exactly one row in the support matrix and the allowlists in
   `AGENTS.md`.
4. Require `setupPlan.path` to equal `air65-v3-macos-wired`,
   `air75-v3-macos-wired-1.0.14.6`, or `air96-v2-ansi-macos-v7`. Otherwise stop.
5. Keep app installation, Hook configuration, DFU entry, and firmware writing
   as separate approvals.
6. Finish with the success checklist below. Do not call the setup successful
   when any required observation is missing.

## Air65 V3 verified path

This path was physically exercised on macOS arm64 with Air65 V3 `19F5:102B`,
HID usage `0001:0000`, and 64-byte input/output reports. The verified result
includes automatic active-profile discovery, real Codex state transitions, USB
reconnect recovery, and the optional physical `F23` right-rotation mapping for
the next Codex task. Requirements and evidence are recorded in
[`AIR65_V3_VERIFICATION.md`](AIR65_V3_VERIFICATION.md).

1. Put the Air65 V3 in wired USB mode and use a data-capable cable.
   Bluetooth can be used for typing, but it is not an Air65 V3 status-light
   transport in the current release. Physical testing confirmed that the
   standard BLE LED report is accepted but produces no side-light change.
2. Install the current NuNuBar macOS release. Prefer an
   Apple-notarized DMG; an `UNNOTARIZED` asset is a development build and needs
   its explicit Gatekeeper flow.
3. Launch NuNuBar and grant Input Monitoring. NuNuBar uses HID output only and
   does not read or store keystrokes.
4. Confirm the Keyboard page reports `Air65 V3` over USB and displays a discovered
   active light profile. This path never asks for a VIA backup, recovery firmware,
   DFU, or a keyboard firmware write.
5. Connect Codex from the Agent page, review the scoped entries, and approve
   the Hooks in Codex Settings.
6. Run the three-state light self-test, then exercise a real Codex working,
   waiting, and complete transition. A successful command is not a substitute
   for confirming the physical light.
7. Run the bundled helper's read-only `describe` command and trigger another
   transition. The light must still change.
8. Unplug and reconnect USB once. NuNuBar must rediscover the same interface
   and replay the current state without restarting the app.

The optional Air65 V3 yellow-key Fn/Globe conversion is separately hardware
verified with official Karabiner-Elements 16.1.0. It is not required for status
lighting and never changes the V2 firmware matrix. See
[`AIR65_V3_FN_SHORTCUT.md`](AIR65_V3_FN_SHORTCUT.md).

## Air75 V3 verified path

Air75 V3 uses its official `19F5:1028`, HID `0001:0000`, 64-byte wired control
interface. NuNuBar reads the official firmware version and requires `1.0.14.6`
or later. On the tested keyboard, `1.0.13.6` acknowledged side-light writes but
did not apply them; NuPhyIO reproduced the same behavior. After an official
NuPhyIO backup, update, reboot, and configuration restore, both NuPhyIO and
NuNuBar changed the side lights correctly.

Read [`AIR75_V3_VERIFICATION.md`](AIR75_V3_VERIFICATION.md) before setup. This
route never uses a bundled Air75 V2 image. Keep NuPhyIO closed while NuNuBar is
running because both applications own the same device-global HID session.

NuNuBar 0.15.0 also exposes the model-specific 75% key mapping editor documented
in [`AIR75_V3_KEY_MAPPING.md`](AIR75_V3_KEY_MAPPING.md). Its exact `19F5:1028`
Karabiner rule generation is covered by automated tests. Do not promote the
Air75 knob route to hardware-verified until `F21`/`F22`/`F23` and a real mapped
action have been physically observed.

## Air96 V2 ANSI verified path

Air96 V2 uses a different route. The App must test the installed firmware first.
Visible orange/green/red states mean the keyboard is already compatible and
must not be reflashed. Only a failed self-test opens the model-locked v7 branch,
which requires a VIA backup, exact official recovery firmware, hash verification,
manual DFU entry, and a second final flash confirmation.

Read [`AIR96_V2_SUCCESS.md`](AIR96_V2_SUCCESS.md) for the exact firmware file,
SHA-256, prerequisites, and acceptance list.

## Success checklist

A verified setup must satisfy all applicable items:

- the app reports the exact supported model and expected transport;
- normal typing, modifiers, Caps Lock, sleep, and wake continue to work;
- idle, working, waiting/error, and complete are physically distinguishable;
- configured color and effect changes reach every intended lighting zone;
- real Codex lifecycle events, not only a direct demo, change the keyboard;
- read-only inspection does not interrupt later Air65 V3 updates;
- Air75 V3 reports official firmware `1.0.14.6` or later before final acceptance;
- USB unplug/replug restores the current state without restarting NuNuBar;
- unrelated Hooks and user configuration remain intact;
- the user knows the uninstall and, for V2 firmware, official recovery path.

Record missing physical checks as pending. Never promote a testing profile to
verified based only on another keyboard size or another user's binary.

## Evidence and troubleshooting

The Air65 V3 protocol, stress, session, and reconnect evidence is recorded in
[`AIR65_V3_VERIFICATION.md`](AIR65_V3_VERIFICATION.md). Firmware evidence is
stored per model in `firmware/<model>/BUILD_RECORD.md`.

For Air65 V3 that remains on one color:

1. verify the installed `/Applications/NuNuBar.app` is running;
2. confirm `19F5:102B`, usage `0001:0000`, and a discovered active profile;
3. run Light self-test; if it fails, diagnose HID/session/profile before Hooks;
4. if self-test works but Codex does not, verify the installed helper Hooks are trusted;
5. reconnect USB once, wait for ready, then repeat self-test and a real Codex event.

Do not solve an Air65 V3 connection problem by entering DFU or flashing a V2
image.

For Air75 V3, first check the firmware version in NuNuBar. Below `1.0.14.6`,
back up in NuPhyIO and use only the separately approved official update. At or
above the minimum, close NuPhyIO before diagnosing NuNuBar or Hooks.
