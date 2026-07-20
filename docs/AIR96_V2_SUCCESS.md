# Air96 V2 ANSI verified setup

This is one of NuNuBar's three hardware-verified normal-user paths. It applies
only to an exact NuPhy Air96 V2 ANSI connected to an Apple Silicon Mac by USB.

## What the user needs

- Apple Silicon Mac with macOS 14 or later;
- printed model and physical layout confirmed as **Air96 V2 ANSI**;
- a data-capable USB cable and wired keyboard mode;
- NuNuBar installed in `/Applications`;
- manual review and approval of the four Codex Hooks.

Do not prepare DFU materials until the existing firmware has been tested.

## Fast decision

1. Run `python3 script/preflight.py --json` and require
   `setupPlan.path = air96-v2-ansi-macos-v7`.
2. Install and open NuNuBar, then run the orange/green/red light self-test.
3. If all three colors are visible, keep the installed firmware. Skip DFU and
   every firmware write, connect Codex Hooks, and run a real-task acceptance.
4. If the self-test is not visible, first recheck USB mode, cable, model, and
   App detection. Only after those checks may Codex prepare the v7 flash path.

## Conditional v7 firmware path

The following are required only when the existing-firmware self-test fails:

- VIA JSON layout backup stored outside the repository;
- exact official Air96 V2 ANSI recovery firmware and its source URL;
- separate user confirmation before entering DFU;
- a unique STM32 DFU device path;
- separate final confirmation immediately before the firmware write.

Verified bundled firmware:

- file: `NuphyBar-Air96-V2-ANSI-custom-effects-v7.bin`;
- size: `66088` bytes;
- SHA-256: `d3cfd9e76a38b70e823889197bdd92bc42e1fbfb96d938d02c4178720b0bb898`;
- target: `0483:DF11`, alternate `0`, address `0x08000000`.

The common DFU identity does not identify a keyboard model. Codex must match
the printed model, ANSI layout, application-mode `19F5:3266`, manifest, size,
and SHA-256 before presenting a flash command.

## Success criteria

- both side-light bars visibly show idle, working, waiting, and complete;
- colors and solid/breathe/blink effects selected in NuNuBar are visible;
- a real Codex prompt changes the keyboard state;
- USB reconnect restores delivery without reflashing;
- normal typing and the user's VIA layout still work;
- the user knows where the VIA backup and official recovery firmware are kept.

Air60 V2, Air75 V2, and Halo75 V2 assets are contributor test targets. Their
presence in the repository does not make them part of this verified path.
