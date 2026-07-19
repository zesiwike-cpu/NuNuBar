# NuNuBar Codex Micro mode

This document records the product capabilities NuNuBar can learn from Codex
Micro, the compatibility boundary, and a maintainable implementation path. The
goal is not to impersonate Work Louder hardware. It is to provide a dependable
physical Codex control surface using NuPhy keyboards, supported Codex inputs,
and NuNuBar's existing status channel.

## What Codex Micro provides

OpenAI describes four core capabilities:

1. six Agent Keys that show live status and open their assigned tasks;
2. command keys for actions such as approve, reject, push-to-talk, and new task;
3. a joystick that launches workflows such as PR review, debugging, and refactoring;
4. a rotary encoder that adjusts reasoning level.

The hardware has 13 mechanical switches, a touch sensor, rotary encoder, and
planar joystick. It supports USB-C, Bluetooth, macOS, and Windows. See
[OpenAI Supply Co. x Work Louder](https://openai.com/supply/co-lab/work-louder/).

The locally installed Codex desktop app also shows that Codex Micro uses a
dedicated Work Louder HID service. Codex sends up to six task states directly
to the device and receives key, joystick, and encoder events through a native
command bridge. That bridge is not a public third-party API NuNuBar can rely on.

## Capability matrix

| Capability | Air65 V3 path | Result |
| --- | --- | --- |
| Current Codex status light | Existing official USB side-light control | Verified |
| App-configurable colors and effects | Existing NuNuBar Light page | Implemented |
| App-configurable physical actions | F13-F24 carriers + Karabiner + Codex shortcuts | Feasible |
| New task, settings, and dictation | Supported or configurable Codex shortcuts | Feasible |
| Reasoning and plan controls | User assigns dedicated Codex shortcuts first | Feasible |
| Fixed Skill or prompt actions | Open a task and insert configured content | Feasible after validation |
| Six simultaneous task lights | Current Air65 path exposes one side-light state | Not equivalent |
| Background approve or reject | No public context-safe external command API | Not offered yet |
| Encoder and joystick behavior | Air65 V3 lacks those controls | Use keys instead |

## Safety and compatibility boundary

Codex Micro commands are context-aware internal actions, not raw Enter, Escape,
or Command-N keystrokes. An external Enter mapping could submit a message when
no approval is visible. Approval and permission actions therefore remain
unavailable until there is a public API or an implementation that can validate
the exact Codex context.

NuNuBar must not impersonate the Codex Micro USB identity, copy or depend on
private Work Louder packages, modify the Codex app bundle, inject scripts, or
flash Air65 V3 for shortcut mapping. Those approaches are unsuitable for a
public project because of licensing, signing, security, and update risk.

## Recommended architecture

### Status channel

Keep the existing Codex Hooks. `AgentState` already stores records by
`provider + sessionID`; NuNuBar currently reduces them to one side-light state
using error, waiting, working, complete, and idle priority. The first Micro-mode
release should preserve that reliable aggregate behavior.

### Input channel

NuPhyIO stores chosen physical keys as low-conflict `F13-F24` carriers. NuNuBar
generates exact-device Karabiner rules and exposes the assigned action in its UI.
The first release builds on the hardware-verified yellow `PGDN -> F24` path.

### Action channel

Every action has an explicit reliability class:

- **native shortcut**: a stable shortcut supplied by Codex;
- **user shortcut**: assigned by the user in Codex Keyboard Shortcuts first;
- **system action**: open Codex, a URL, or an explicitly configured Shortcut;
- **unavailable**: no safe public entry point exists.

NuNuBar does not edit Codex private storage. It may open the relevant settings,
show the expected binding, and let the user confirm that binding in Codex.

## Air65 V3 first-release acceptance

The first Micro-mode release targets wired Air65 V3 `19F5:102B` without firmware:

1. show the carrier used by the yellow key;
2. select Fn/Globe, new task, dictation, keyboard-shortcut settings, or a custom
   Codex shortcut in NuNuBar;
3. back up and merge Karabiner configuration without replacing unrelated rules;
4. do not run ambiguous actions while Codex is not frontmost;
5. preserve existing status colors, effects, and display timing;
6. physically verify press, release, and repeated use for every action.

## Other NuPhy models

Air60/75/96 V2 and Halo75 V2 retain their existing lighting and firmware paths.
They can share the action model and Codex shortcut dispatcher, but every model
needs its own verified physical carrier layout. Shortcut work must not change a
firmware verification status or automatically enter DFU.

Full parity for approve, reject, task switching, push-to-talk, and reasoning
would be best served by a public Codex peripheral API, URL action, or validated
command IPC. Until one exists, NuNuBar should ship the reliable shortcut subset
and label unsupported actions honestly.
