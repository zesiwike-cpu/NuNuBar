# Safe setup with Codex

NuNuBar turns local Codex lifecycle events into status lighting on compatible
NuPhy keyboards. A new user can give this repository URL to Codex and let it
prepare the correct app, but hardware identification and every destructive
step remain human decisions.

## Prompt to give Codex

```text
Configure NuNuBar safely from the repository URL attached to this task.
Follow AGENTS.md, START_HERE.md, docs/CODEX_SETUP.md, and
docs/VERIFIED_PATHS.md exactly. First run python3 script/preflight.py --json and
report setupPlan.path, required, conditionalFirmwareRequirements, approvalGates,
and nextAction. Then use my physical confirmation of the exact model and ANSI
layout. setupPlan.path must be air65-v3-macos-wired,
air75-v3-macos-wired-1.0.14.6, or air96-v2-ansi-macos-v7; otherwise stop and
explain. Do not enter DFU,
flash firmware, replace an existing app or configuration, or write Codex Hooks
until you have explained that specific action and received a separate
confirmation for it. Preserve unrelated configuration and never choose between
multiple DFU devices. Finish with the published success checklist and do not
claim success while a required observation is missing.
```

Codex should clone or inspect the repository, report what it found, and stop
for input whenever a required fact or approval is missing. Giving Codex the
URL is not approval to modify the computer or keyboard.

The read-only preflight also runs the repository integrity verifier and reports
whether the App/Hooks exist, which keyboard is a catalog candidate, and whether
the expected control interface is ready. A V2 VID/PID and Raw HID interface do
not prove that compatible firmware is installed. Run the App light self-test
first, and never reflash a keyboard whose status lights already respond.

The support decision matrix and required final observations are in
[Verified setup paths](VERIFIED_PATHS.md).

## Before setup

Both paths require:

- the exact model printed on the keyboard or packaging;
- confirmation that the physical layout is ANSI;
- a reliable USB data cable connected directly to the computer.

Air65 V3 needs no VIA backup, recovery image, or firmware material. Air75 V3
uses official firmware `1.0.14.6` or later; an older version requires a
NuPhyIO export and separate approval before the official update. Air96 V2
must also test its existing firmware first. Prepare a VIA JSON backup and the
exact official recovery image only after that self-test fails. Keep both outside
the repository; never commit them or upload them to a public issue.

Air65/Air75 V3 status lighting does not require Karabiner. Their optional model-
specific key and knob mapping editors use official Karabiner-Elements to execute
exact-device rules. Follow [`AIR65_V3_KEY_MAPPING.md`](AIR65_V3_KEY_MAPPING.md)
or [`AIR75_V3_KEY_MAPPING.md`](AIR75_V3_KEY_MAPPING.md); installing
Karabiner and writing `~/.config/karabiner/karabiner.json` each require a visible
user decision. The yellow-key Fn/Globe route remains documented separately in
[`AIR65_V3_FN_SHORTCUT.md`](AIR65_V3_FN_SHORTCUT.md).

## Supported models

| Model | USB VID:PID | Current firmware status | Lighting zone |
| --- | --- | --- | --- |
| Air65 V3 | `19F5:102B` | Official firmware; automatic profile discovery, default orange/green/red, and real Codex transitions verified | Side lights |
| Air75 V3 | `19F5:1028` | Official firmware `1.0.14.6` or later; model-specific official wired protocol verified | Side lights |
| Air96 V2 ANSI | `19F5:3266` | Hardware-verified v7 path; self-test first | Two side bars |

These are the only normal-user paths. Air60 V2, Air75 V2, Halo75 V2, Windows,
and other hardware remain contributor targets and must not be selected by an
ordinary Codex setup.

## macOS

The current macOS app targets Apple Silicon and macOS 14 or later.

Codex should prefer the DMG attached to the requested GitHub release. A local
DMG can be installed with:

```bash
./script/setup-macos.sh \
  --dmg /path/to/NuNuBar-<version>-macOS-arm64.dmg \
  --allow-unnotarized \
  --sha256 <optional-expected-sha256>
```

To download an exact release asset:

```bash
./script/setup-macos.sh \
  --release OWNER/REPOSITORY \
  --tag v<version> \
  --asset NuNuBar-<version>-macOS-arm64.dmg \
  --sha256 <optional-expected-sha256>
```

Replace `OWNER/REPOSITORY` with the repository path shown in the browser.

A direct GitHub release asset URL is also supported:

```bash
./script/setup-macos.sh --release-url <github-release-dmg-url>
```

The script verifies the optional SHA-256, validates the app signature, and
installs `NuNuBar.app`. Formal GitHub release assets must pass Gatekeeper
assessment for both the DMG and app. Quarantine metadata is preserved. If an
app already exists, the script asks before replacement. It does not launch
DFU, flash firmware, edit Codex Hooks, or start the app.

A local DMG or asset with `UNNOTARIZED` in its name is a development source.
It requires `--allow-unnotarized` plus an interactive `UNNOTARIZED`
confirmation. Codex must explain that it may be blocked at launch and must not
describe it as a public, Gatekeeper-ready build, even if a local assessment
happens to pass.

After installation, launch NuNuBar and connect the keyboard by USB. V2 models
require USB Raw HID and matching NuNuBar firmware for custom RGB and effects;
Air65/Air75 V3 use their official wired control interfaces; Bluetooth typing
does not provide V3 side-light status in the current release. Connecting
Codex is a separate configuration change: NuNuBar may propose scoped Hook
entries, but Codex must show the affected configuration and obtain approval
before writing it. The user must still approve Hooks in Codex Settings.

## Codex Hook steps

1. Launch Codex once so its `~/.codex` configuration directory exists.
2. Click Connect on NuNuBar's Agent page, or Connect Codex in the keyboard
   assistant.
3. NuNuBar backs up and merges `~/.codex/hooks.json`, then enables
   `hooks = true` under `[features]` in `~/.codex/config.toml`. Unrelated fields,
   Hooks, and notification settings are preserved.
4. Open pending Hooks in Codex Settings. Confirm that each command points to
   the installed `NuNuBar.app/Contents/Helpers/agent-light`, then approve
   `UserPromptSubmit`, `PermissionRequest`, `PostToolUse`, and `Stop`.
5. Return to NuNuBar and click Check Again. Hook setup is complete only after
   the App reports Connected.
6. Start a new Codex task and physically verify working, waiting, and complete.
   A demo light sequence is not a substitute for a real Hook acceptance test.

Hooks send only the local Agent name, coarse state, session ID, and timestamp.
They do not read prompts or responses. Do not type `/hooks` into a Codex chat;
this step uses Codex Settings and its pending-Hook review. NuNuBar never
approves Hook trust on the user's behalf.

## Other platforms

There is no hardware-verified Windows or Intel Mac normal-user route. Stop and
explain that limitation. Contributor code may remain in the repository, but it
must not be used to claim a successful setup.

## Firmware flow

Bundled firmware is needed only for an exact Air96 V2 ANSI after its
existing-firmware self-test fails. Air65/Air75 V3 already have official
interfaces and must never receive a V2 image. Air75 V3 below `1.0.14.6` uses
only the separately approved NuPhyIO official update described in
[`AIR75_V3_VERIFICATION.md`](AIR75_V3_VERIFICATION.md). For Air96, read
[`AIR96_V2_SUCCESS.md`](AIR96_V2_SUCCESS.md), then use
this sequence:

1. Detect application-mode USB VID/PID and compare it with the printed model.
2. Confirm ANSI, VIA backup, official recovery firmware, and model-specific
   catalog entry.
3. Verify the bundled image size and SHA-256.
4. Explain DFU and obtain a dedicated confirmation before asking the user to
   enter it.
5. Detect exactly one physical STM32 DFU path with Option Bytes and Internal
   Flash on that same path.
6. Display the exact image, status, hash, path, alt `0`, and `0x08000000`.
7. Obtain a new flash confirmation immediately before the write command.
8. Reconnect by USB and verify typing, every status/effect, sleep/wake, and the
   official recovery route.

The generic DFU ID `0483:DF11` cannot identify a keyboard. If detection is
ambiguous, the model/layout differs, a hash fails, or recovery material is
missing, stop without flashing.

## Status defaults

The default palette is idle off, working orange breathe, waiting/error red
blink, and complete green solid. Air96 V2 renders effects in firmware;
Air65/Air75 V3 use official control interfaces and the App renders blink. All
verified paths use USB. See `docs/NBAR_PROTOCOL.md` for the byte-level contract.
