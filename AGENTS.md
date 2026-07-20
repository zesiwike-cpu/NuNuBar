# NuNuBar repository instructions

These instructions apply to every Codex or other coding agent working in this
repository. Safety takes priority over completing setup quickly.

## Three normal-user success paths

Do not build a setup plan from the full firmware catalog. Ordinary users may
use only these hardware-verified paths:

1. `air65-v3-macos-wired`: Air65 V3 `19F5:102B`, Apple Silicon macOS, wired
   official control, never DFU and never flash. Read
   `docs/AIR65_V3_VERIFICATION.md`. Read the key-mapping document only when the
   user asks for shortcuts.
2. `air75-v3-macos-wired-1.0.14.6`: Air75 V3 `19F5:1028`, Apple Silicon
   macOS, official wired control and official firmware `1.0.14.6` or later.
   Read `docs/AIR75_V3_VERIFICATION.md`. Older firmware requires a NuPhyIO
   configuration backup and a separate confirmation before the official update;
   never use a V2 NuNuBar image on this keyboard.
3. `air96-v2-ansi-macos-v7`: Air96 V2 ANSI `19F5:3266`, Apple Silicon macOS,
   wired USB, existing-firmware self-test first. Read
   `docs/AIR96_V2_SUCCESS.md`. A visible self-test means keep the firmware and
   skip DFU. Only a failed self-test may open the backed-up v7 firmware path.

Run `python3 script/preflight.py --json` and report its `setupPlan` before any
change. If `setupPlan.eligible` is false, stop the normal-user setup. Air60 V2,
Air75 V2, Halo75 V2, Windows, Intel Mac, and unlisted hardware remain source or
contributor test targets, not substitutes for a success path.

## Start with discovery

Before installing, configuring, or flashing anything:

1. Identify the host and architecture. The three verified paths require Apple
   Silicon macOS; stop normal-user setup on other hosts.
2. Identify the keyboard by its printed model name, physical layout, and USB
   VID/PID. Do not infer a model from size, appearance, or a DFU device.
3. Confirm that the keyboard is an exact supported **ANSI** model.
4. For Air96 V2, run the existing-firmware light self-test before asking for
   any firmware material. Only after that self-test fails, ask the user for a
   VIA layout backup and the matching official recovery image; keep both
   outside the repository. Air65 V3 always skips this step. Air75 V3 uses only
   the official NuPhyIO update when its detected version is below `1.0.14.6`.
5. Read `START_HERE.md`, then only the success document named by `setupPlan`.
   Consult `docs/NBAR_PROTOCOL.md` and the firmware manifest only when the
   Air96 v7 firmware branch is actually required.
6. Run `python3 script/preflight.py --json`. It invokes the repository verifier
   and adds read-only host, installation, USB, and HID discovery. Stop if the
   App version, release notes, model allowlist, firmware size, or SHA-256 checks
   do not agree.

The preflight result is evidence, not consent. Its model name is a catalog
candidate derived from USB identity; the user must still confirm the printed
model and ANSI layout. For V2 devices, VID/PID and a Raw HID interface do not
prove that compatible NuNuBar firmware is installed. Run the App self-test
before proposing a flash, and never flash a keyboard whose status lights
already respond correctly.

Hardware-verified normal-user USB identities are:

| Model | VID:PID | Release status |
| --- | --- | --- |
| NuPhy Air65 V3 | `19F5:102B` | Verified official wired control; never flash |
| NuPhy Air75 V3 | `19F5:1028` | Verified official wired control; official `1.0.14.6` or later |
| NuPhy Air96 V2 ANSI | `19F5:3266` | Verified v7 route; self-test before any flash |

No testing, ISO, JIS, HE, V1, other V3, or differently sized model is interchangeable
with an entry in this table. Air65/Air75 V3 require the exact USB identity, usage
`0001:0000`, and 64-byte control reports. It is a no-flash path and must never
be asked to enter the V2 DFU route for NuNuBar. The common STM32 DFU identity `0483:DF11`
does not identify the keyboard model.

For Air65/Air75 V3, the installed NuNuBar App is the only normal owner of the official
device session. Hooks only update the shared state file. Use the App's Keyboard
page self-test for routine acceptance; `agent-light describe` is enumeration-only.
Do not run `demo`, `stress`, `recovery-test`, or `soak-test` while the App is
running, because those developer diagnostics intentionally open their own HID
session.

Air75 V3 Auto-sleep is a keyboard firmware preference, not an Agent state. When
the user requests always-on idle lighting, first confirm the NuNuBar idle color
is non-black and its effect is solid, then instruct one short `Fn + ]` press to
disable Auto-sleep per the official Air75 V3 manual. Do not add periodic HID
polling or synthetic keyboard activity as a substitute.

Air65/Air75 V3 status lighting does not depend on Karabiner. The current macOS
key and knob mapping editors depend on the official Karabiner-Elements application.
Before offering mappings, explain that boundary. Installing Karabiner and
writing `~/.config/karabiner/karabiner.json` are separate user-visible changes;
obtain the applicable approval, preserve unrelated profiles and rules, and keep
every NuNuBar rule scoped to the detected exact device: Air65 V3 `19F5:102B`
or Air75 V3 `19F5:1028`. Read the matching `AIR65_V3_KEY_MAPPING` or
`AIR75_V3_KEY_MAPPING` guide. Without Karabiner,
skip shortcut mapping and continue the independent lighting setup.

## Mandatory human approval gates

Never combine these approvals, and never treat an earlier "continue" or
general setup approval as approval for a later action:

1. **Replace an existing application, executable, or user configuration:**
   show the exact destination and backup/rollback behavior, then wait for an
   explicit confirmation before replacing it.
2. **Write Agent or Codex integration configuration:** show which files or
   entries will change and confirm that unrelated entries will be preserved,
   then wait for a separate explicit confirmation. Never bypass Codex Hook
   trust or approval UI.
3. **Enter DFU:** only after the exact model/layout, VIA backup, official
   recovery image, firmware manifest, and SHA-256 have been checked, explain
   that normal keyboard input will stop and ask for confirmation before
   instructing the user to enter DFU.
4. **Flash firmware:** after DFU detection, require exactly one matching
   physical DFU path containing both Option Bytes and Internal Flash. Display
   the exact model, layout, firmware filename, release status, SHA-256, DFU
   path, alt setting, and address. Then wait for a new, explicit confirmation
   before running any write command.

Do not run `dfu-util -D`, `dfu-util --download`, or another firmware write
command before gate 4. Do not automatically enter DFU, flash firmware, select
among multiple DFU devices, overwrite Hooks, or weaken model/hash checks.

## Platform rules

- **macOS:** use a release DMG or `script/setup-macos.sh`. The script installs
  only `NuNuBar.app`; it never flashes firmware or edits Hooks. Prefer a
  Developer ID signed and Apple-notarized release. Treat an artifact marked
  `UNNOTARIZED` as a development build and explain the Gatekeeper implication.
- **Windows and Intel Mac:** no hardware-verified normal-user path currently
  exists. Report that limitation and stop instead of adapting the macOS success
  instructions.
- Installation and firmware setup are separate operations. Installing the app
  must never imply consent to flash a keyboard.

## Firmware rules

- Use only the model-specific image named by
  `Sources/AgentLightApp/Resources/Firmware/manifest.json`.
- Verify filename, byte size, SHA-256, protocol version, release status,
  VID/PID, DFU alt `0`, and address `0x08000000` before presenting a flash.
- Air60 V2, Air75 V2, and Halo75 V2 images remain contributor test assets and
  must never be offered by the normal-user flow.
- Air75 V3 is distinct from Air75 V2 and must use official firmware `1.0.14.6`
  or later, never a bundled V2 image.
- Never copy a binary, LED map, product ID, or verification status from one
  model to another.

## Verification and privacy

Run the relevant Swift and Windows Python tests before packaging. Validate
YAML and shell syntax after changing automation. Do not commit user VIA
backups, official recovery images, local configuration, absolute local paths,
account names, tokens, certificates, signing identities, or notarization
credentials.

Use the status language in `docs/VERIFIED_PATHS.md`. A successful build, USB
identity match, ACK, or another keyboard size's result does not make a setup
verified. Finish the applicable success checklist on the exact host and
keyboard. Report unobserved physical behavior as pending and testing profiles
as testing.
