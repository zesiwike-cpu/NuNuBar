# Air65 V3 yellow-key Fn shortcut

This optional macOS path turns the physical yellow `PGDN` key on an exact
NuPhy Air65 V3 `19F5:102B` into the native Apple `fn`/Globe key. It is separate
from Codex status lighting: it does not flash firmware, change Hooks, or alter
the NuNuBar light protocol.

## Verified result

The complete path was physically verified on 2026-07-18 with:

- macOS 15.1 on Apple Silicon;
- NuPhy Air65 V3 over wired USB, `19F5:102B`;
- official NuPhyIO 2.0, Mac mode, M1 profile;
- official Karabiner-Elements 16.1.0, Apple-notarized;
- the yellow physical `PGDN` position saved as `F24` in NuPhyIO;
- a device-scoped Karabiner rule that maps `F24` to
  `apple_vendor_top_case_key_code: keyboard_fn`.

Karabiner-EventViewer recorded both `down` and `up` for `keyboard_fn` from the
Karabiner DriverKit virtual keyboard. This verifies the full physical-key to
native-Fn conversion, not just JSON syntax.

## Why F24 is used

`F24` is an intermediate carrier. It is unlikely to conflict with ordinary
macOS shortcuts, and Karabiner can recognize it before emitting the real Apple
Fn/Globe event. The final user-visible key is Fn/Globe, not F24.

## App-guided setup

1. Connect the exact Air65 V3 by USB and open NuNuBar > Keyboard.
2. Select the yellow `PGDN` key in the Yellow Key Shortcut keyboard view. The
   App shows the physical `PGDN` key, `F24` carrier, and final `Fn/Globe`
   action separately.
3. Open NuPhyIO. Select Mac mode and the M1 profile, select the physical yellow
   `PGDN` position, assign `F24`, save, then reload NuPhyIO once to confirm that
   the assignment persisted. NuNuBar cannot read NuPhyIO's internal keymap yet,
   so also confirm that N and other keys do not use `F24`.
4. Install Karabiner-Elements only from its
   [official website](https://karabiner-elements.pqrs.org/). Complete its Setup
   checks for both background services, Accessibility, input capture, and the
   DriverKit extension.
5. Return to NuNuBar. The App detects Karabiner and shows Configure. Before any
   write, its confirmation dialog displays the exact destination and backup:
   `~/.config/karabiner/karabiner.json` and a timestamped sibling `.bak` file.
6. Confirm the write. NuNuBar merges one rule into the selected profile,
   preserves unrelated profiles and rules, and keeps the original file mode.
7. Open Key Test and press the yellow key once. EventViewer must show
   `keyboard_fn` down/up from the Karabiner virtual keyboard.

The rule is limited to vendor `6645` (`19F5`), product `4139` (`102B`), and a
keyboard interface. It does not change the built-in Apple keyboard or another
NuPhy model.

## Recovery

Use the mapping options menu in NuNuBar to remove only the NuNuBar-managed
rule. The App creates another timestamped backup before removal. Then restore
the physical yellow key from `F24` to `PGDN` in NuPhyIO. A full backup restore
is appropriate only when no later Karabiner changes need to be retained.

Do not enter DFU or flash V2 firmware for this shortcut. Bluetooth may still be
used for typing after the keyboard-side assignment is saved, but the verified
setup and all NuNuBar Air65 V3 status lighting remain wired-USB paths.
