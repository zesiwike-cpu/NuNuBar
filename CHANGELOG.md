# Changelog

## Unreleased

## 0.15.0 - 2026-07-19

- Added independent 0-100% brightness controls for working, waiting, complete,
  and idle. Air75 V3 uses its official 0-100 hardware range, Air65 V3 maps to
  its 0-24 range, and existing V2 firmware keeps its protocol while receiving
  brightness-adjusted RGB values.
- Migrated existing color/effect files with deterministic 100% brightness and
  added debounced three-second hardware previews for brightness changes.
- Physically verified Air75 V3 at 20%: the App value, HID delivery log, visible
  side-light level, and keyboard `D5` readback byte `0x14` all agreed.
- Debounced live color previews so dragging the macOS color picker sends only
  the settled color to Air V3 keyboards instead of restarting the hardware
  effect for every intermediate value.
- Updated the key-mapping shortcut from the obsolete NuPhyIO `#/pressKey`
  route to the current official NuPhyIO 2.0 entry, preserving the App language.

- Added a clickable Air75 V3 75% ANSI key-mapping layout to the macOS App,
  including its function row, navigation column, and three independent knob
  directions.
- Generalized the Karabiner mapping engine across Air65 V3 `19F5:102B` and
  Air75 V3 `19F5:1028`, with model-specific rule ownership, backups, device
  conditions, and connection readiness checks.
- Kept Air65 V3 mappings intact when Air75 V3 rules are added or removed.
  Codex actions remain active only while Codex is frontmost.
- Air75 V3 knob mappings use the same explicit carrier pattern: `F21` left,
  `F22` press, and `F23` right. The App's input probe verifies these carriers
  before physical acceptance.
- Documented the official Air75 V3 short `Fn + ]` Auto-sleep toggle for users
  who require a non-black solid idle light to stay on continuously; no periodic
  HID keepalive or synthetic key activity is used.

## 0.14.1 - 2026-07-19

- Added the hardware-calibrated Air75 V3 `19F5:1028` official wired path using
  NuPhyIO's two acknowledged `D6` writes for side-light state and brightness.
- Added in-app official firmware detection and a minimum Air75 V3 version of
  `1.0.14.6`; lower versions stop setup and direct the user to a separately
  approved NuPhyIO backup and official update.
- Physically verified the installed Codex Hook path on Air75 V3: a real task
  changed from orange working breathe to green complete solid.
- Added Air75 V3 to the setup assistant, HID allowlist, read-only preflight,
  release checks, and bilingual verification documentation.
- Preserved the verified Air65 V3 lighting and Karabiner mapping route, Air96
  V2 v7 route, and the existing Air60/Air75/Halo75 V2 contributor assets.

## 0.13.1 - 2026-07-19

- NuNuBar 0.13.1 build 48 passed retail Air65 V3 acceptance on macOS 15.1:
  a real Codex prompt restored the configured working light, and a physical
  `F23` knob rotation produced `Command-Shift-]` and switched to the next Codex
  task.
- Restored the proven Air65 V3 delivery checkpoint behavior: every Codex
  `UserPromptSubmit` and `PermissionRequest` now advances a persisted delivery
  revision even when the visible state is unchanged.
- The menu app uses that revision to resend the current color. If NuPhyIO or
  another HID client replaced the Air65 V3 device-global session, the failed
  stale send automatically enters the existing handshake recovery path and
  replays the latest Codex state.
- Kept ordinary `PostToolUse` events coalesced, avoiding a full Air65 V3 light
  transaction after every tool call.
- Added an eight-second input probe to the Air65 mapping editor. It distinguishes
  the expected `F21`/`F22`/`F23` carrier from an unexpected Fn/Globe result
  without storing ordinary keystrokes.
- Preserved the Air65 V3 `F21`/`F22`/`F23` knob mappings, the yellow-key `F24`
  Fn/Globe mapping, and all Air60/Air75/Air96/Halo75 V2 routes unchanged.

## 0.13.0 - 2026-07-19

- Added independent Air65 V3 knob mappings for the NuPhyIO-verified `F21`
  left rotation, `F22` press, and `F23` right rotation input events.
- Added Codex actions for new task, navigation, panels, terminal, browser,
  shortcuts, and settings. These rules apply only while Codex is frontmost and
  preserve the knob or key's original event in other applications.
- Split the mapping menu into System and Codex sections, added a three-way knob
  selector, and replaced the old F24-specific guidance with general mapping
  instructions.
- Kept the verified Air65 V3 status-light path and all Air60/Air75/Air96/Halo75
  V2 setup, firmware, and validation routes unchanged.

## 0.12.0 - 2026-07-19

- Replaced the Air65 V3 single-purpose yellow-key panel with a clickable key
  mapping editor. Standard keys can create, update, and delete device-scoped
  mappings for Fn/Globe, navigation, editing, media, and volume actions.
- Existing verified `PGDN` / `F24` / Fn rules are imported without requiring
  migration. Their carrier appears only as compact technical state instead of
  dominating the mapping workflow.
- Added per-key mapped indicators, explicit original-key replacement warnings,
  exact destination and backup confirmations, and preservation of unrelated
  Karabiner profiles and rules.
- Kept Air65 V3 status lighting and all four Air60/Air75/Air96/Halo75 V2 routes
  unchanged.

## 0.11.0 - 2026-07-18

- Added a V2 compatibility stage to the new-keyboard assistant. NuNuBar now
  sends an orange/green/red self-test before offering any firmware operation.
- The user must record the physical result: visible changes keep the installed
  firmware and jump directly to Codex setup; no change continues to the
  existing model, backup, recovery-image, DFU, and final flash gates.
- Air65 V3 continues to use its official no-flash route. Air60 V2, Air75 V2,
  Air96 V2, and Halo75 V2 remain present with their existing per-model release
  status and firmware safeguards.
- Aligned the macOS and Windows client version metadata at 0.11.0.
- Added explicit in-app and bilingual documentation for Codex Hook setup,
  including the two modified files, four lifecycle events, manual trust review,
  Check Again verification, and a real-task acceptance test.
- Added an optional Air65 V3 yellow-key setup that guides NuPhyIO `PGDN` to
  `F24`, detects official Karabiner-Elements, previews the exact config and
  backup paths, and merges a `19F5:102B`-scoped Fn/Globe rule.
- Added in-app EventViewer acceptance and a backed-up removal path. The full
  physical-key to `keyboard_fn` conversion passed on macOS 15.1 with
  Karabiner-Elements 16.1.0.

## 0.10.0 - 2026-07-18

- Added a bilingual `START_HERE.md` handoff so a new user can download the
  repository, give one fixed prompt to Codex, and enter the verified setup
  decision tree.
- Added a read-only cross-platform preflight report for host, installed App and
  Hooks, USB/HID identity, interface readiness, model status, and safe route.
  V2 firmware compatibility remains explicitly unknown until the App self-test
  proves it, preventing unnecessary repeat flashes.
- Added repository-level release verification for version metadata, the exact
  four-model V2 catalog, firmware sizes and SHA-256 values, documentation, and
  build records.
- Public macOS tag releases now fail closed unless all Developer ID signing and
  Apple notarization credentials are present; ad-hoc artifacts remain CI-only.
- Air65 V3 now reads the keyboard's active light profile with the official
  encrypted `GetBase` command before declaring the HID session ready, instead
  of assuming every keyboard uses profile 0.
- Added an in-app three-state wired light self-test that restores the current
  Agent state afterwards, making HID/profile failures distinguishable from
  Hook integration failures.
- Made `agent-light describe` enumeration-only for Air65 V3 so read-only
  inspection cannot replace the persistent session owned by the menu App.
- Corrected the Air65 V3 protocol and verification records: a valid ACK alone
  does not prove that the active visible light record changed.
- Retained the model-locked Air60 V2 ANSI, Air75 V2 ANSI, Air96 V2 ANSI, and
  Halo75 V2 ANSI Raw HID paths, firmware catalog, and validation status.
- Hardware acceptance on a retail Air65 V3 confirmed automatic profile `0`
  discovery, visible orange/green/red in-app self-test states, and restoration
  of the current Codex state.

## 0.9.9 - 2026-07-18

- Air65 V3 side-light writes now use the official offset 9 together with the
  active Mac profile 0. Green completion was physically verified over USB.

## 0.9.8 - 2026-07-18

- Restored the Air65 V3 side-light memory slots, but retained a profile value
  that did not target the keyboard's active Mac configuration.

## 0.9.7 - 2026-07-18

- Migrated Air65 V3 writes to NuPhy's official light-state packet layout while
  the side-light memory target was still under hardware validation.

## 0.9.6 - 2026-07-18

- Restored one persistent Air65 V3 control session per USB connection. Status
  updates and host-rendered blink frames now reuse the negotiated key instead
  of repeatedly replacing the keyboard's device-global session.
- Air65 V3 reports a rebuilding state until its initial handshake succeeds, so
  the app cannot mark a status as delivered before the control channel is ready.

## 0.9.5 - 2026-07-18

- Air65 V3 now negotiates a fresh device session inside the cross-process
  transmission lock immediately before every status update and blink frame.
- Device inspection is read-only and can no longer invalidate the running
  NuNuBar app's Air65 V3 session.
- The two-second state-file safety monitor now coalesces an unchanged or
  in-flight payload instead of retransmitting it.

## 0.9.4 - 2026-07-18

- Fixed an Air65 V3 HID teardown crash caused by synchronously cleaning up from
  the transport's own serial queue.
- Added a two-second state-file reconciliation safety net alongside immediate
  cross-process notifications so missed notifications self-heal automatically.
- Added persistent in-app duration controls for completion and error indicators.
- Added independent working and confirmation safety timeouts for stale Hook sessions.
- Status duration changes now take effect immediately and are shared with the Hook helper.
- Added macOS support for wired Air65 V3 through its official `19F5:102B`
  64-byte HID control interface, including session negotiation, strict interface
  matching, custom colors, native solid/breathe effects, and no firmware flash.
- Added ACK-gated Air65 V3 transactions, automatic full-session recovery and
  state replay after a timeout, and host-rendered 500 ms blink frames matching
  the Air96 V2 red waiting/error effect.
- Added `agent-light demo`, `agent-light stress ITERATIONS`, and
  `agent-light recovery-test ITERATIONS` hardware diagnostics, plus a timed
  `agent-light soak-test SECONDS` with ACK, timeout, and recovery counters.
- Serialized continuous Air65 V3 blink frames with app and CLI transmissions
  through the same cross-process lock.
- Added Air65 V3 to the macOS new-keyboard assistant with exact USB identity
  matching and an official-firmware path that skips backup, DFU, and flashing.

## 0.9.0 - 2026-07-18

### Apps

- Renamed the user-facing macOS application to NuNuBar and added the new app icon, menu, settings window, and guided first-run setup.
- Added USB Raw HID delivery alongside the existing Bluetooth status channel.
- Added configurable idle, working, waiting, and complete colors with solid, breathe, and blink effects.
- Added a model-locked firmware assistant with bundled firmware verification, DFU detection, explicit pre-flash confirmation, reconnect checks, and a default light preset.
- Added support metadata for Air60 V2 ANSI, Air75 V2 ANSI, Air96 V2 ANSI, and Halo75 V2 ANSI. Air96 V2 is physically verified; the other three USB builds remain testing firmware.
- Added a Windows USB companion implemented with the Python standard library and Win32 HID APIs, plus Codex Hook setup and a PyInstaller build.

### Firmware

- Added the `NBAR` Raw HID protocol v3 with per-state RGB colors and solid, breathe, or blink effects while retaining v1/v2 decoding.
- Added model-specific QMK patches and reproducible build records for all four supported NuPhy V2 ANSI keyboards.
- Preserved stock battery, pairing, connection, sleep, OS-switch, and Caps Lock indicators at higher display priority.

### Project

- Added Codex-oriented setup instructions, macOS and Windows bootstrap scripts, cross-platform CI, release artifacts, protocol documentation, and public-release safety checks.
- Kept firmware flashing behind exact model/layout checks and a separate human confirmation. Codex Hook trust is never approved automatically.

## 0.5.9 - 2026-07-15

### App

- Added an Antigravity integration using Google's official global plugin and lifecycle Hooks, with an icon derived from the official macOS app asset.
- Replaced one-second Agent-state polling with macOS system notifications and exact expiration timers; a five-second fallback remains if notification registration fails.
- Replaced repeated HID scanning and per-command device opens with a persistent non-exclusive HID manager driven by connection and removal callbacks.
- Added bounded HID session recovery after report failures and proactive session rebuilding after Mac wake, with automatic replay of the latest Agent state when delivery is ready again.
- Coalesced Agent events that arrive during an in-flight HID report into one immediate follow-up refresh.
- Changed terminal error retention from 15 minutes to about 15 seconds, matching completion behavior.
- Removed unused source and icon assets, simplified state/effect logic, and stripped local symbols from Release binaries.

### Firmware tooling

- Replaced Python `assert`-based candidate checks with verification that remains active under optimized Python execution.
- Added a regression test proving invalid firmware candidates are rejected with `python -O`.

## 0.5.8 - 2026-07-14

### App

- Added the native NuphyBar macOS menu-bar app and compact settings window.
- Added local integrations for Codex, Claude Code, OpenCode, Grok Build, Hermes, and OpenClaw.
- Added multi-session state aggregation with error/waiting, working, complete, and idle priority.
- Added BLE NuPhy device discovery, serialized HID delivery, reconnect recovery, launch at login, Chinese/English UI, and official integration brand assets.
- Removed animation streaming: the Mac now sends only one persistent LED state report when the state changes.

### Firmware

- Added the physically verified Air60 V2 ANSI `stable-v7` minimal patch on NuPhy official v2.1.5.
- Preserved the stock Caps Lock indicator and idle lighting.
- Added local blue working wave, amber waiting double pulse, and green completion breathing effects.
- Added machine-code baseline guards, deterministic patch layout verification, effect tests, and a reproducible builder.
