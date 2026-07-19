# NuNuBar Air60 V2 ANSI USB Raw HID v3 test firmware

This is an unverified QMK test build. It has not been flashed to or tested on
physical hardware and must not be offered as an automatic production update.

## Baseline

- Repository: `https://github.com/nuphy-src/qmk_firmware.git`
- Branch: `nuphy-keyboards`
- Commit: `f1856912d603800eaca227ae2e1c5c8548fdf261`
- Keyboard: `nuphy/air60_v2/ansi`
- Keymap: `via`
- MCU: `STM32F072`
- Compiler: `arm-none-eabi-gcc 8.5.0`
- Build date: `2026-07-18`
- Patch: `air60-v2-usb-raw-hid-v3-test-v1.patch`
- Patch SHA-256: `fbefac7b0813fb26aca96c83f2d315af2c70881f27314113fdbffcc6617f3b94`

## Build

The Air60 V2 VIA keymap already sets `VIA_ENABLE = yes`. QMK expands that to
`DYNAMIC_KEYMAP_ENABLE = yes` and `RAW_ENABLE = yes`; the generated compiler
flags contain both `-DVIA_ENABLE` and `-DRAW_ENABLE`.

```bash
PATH=/opt/homebrew/opt/arm-none-eabi-gcc@8/bin:$PATH \
  make nuphy/air60_v2/ansi:via
```

The isolated verification build used an equivalent custom output directory and
target name so concurrent keyboard builds could not replace its ELF metadata:

```bash
PATH=/opt/homebrew/opt/arm-none-eabi-gcc@8/bin:$PATH \
  make nuphy/air60_v2/ansi:via \
  BUILD_DIR=.build-air60 \
  TARGET=nunubar_air60_v2_ansi_usb_v3_test
```

## Artifact

- File: `NuNuBar-Air60-V2-ANSI-usb-raw-hid-v3-test.bin`
- Size: `72116` bytes, including the 16-byte DFU suffix
- Linked Flash content: `72098` bytes of text and initialized data
- SHA-256: `81d38b94c9869a1cde93c09669b952b3b5311be3fdedac3acbe5e5989a567305`
- Keyboard USB VID/PID: `19F5:3255`
- USB device version: `0x0117`
- DFU suffix VID/PID: `0483:DF11`
- DFU alternate interface: `0`
- Flash address: `0x08000000`

## Raw HID

- QMK Raw HID enabled through the VIA keymap
- Report size: `32` bytes in both directions
- Usage page: `0xFF60`
- Usage ID: `0x61`
- Report ID: none (`0` at the host API boundary)
- ELF symbols verified: `via_command_kb`, `raw_hid_receive`, `raw_hid_send`

NuNuBar protocol v3 accepts idle, working, waiting, and complete status values,
an RGB color, and solid, breathe, or blink effects. Protocol v1 and v2 reports
remain accepted for compatibility.

## Lighting behavior

- Air60 side-light indexes are used directly: `64-68` left and `69-73` right.
- USB mode uses the latest valid NuNuBar Raw HID command.
- Bluetooth and 2.4 GHz modes continue to use NuPhy's existing `rf_led` status
  channel with the protocol's default colors and effects. The firmware masks
  status bits with `0x05`, leaving the independent Caps Lock bit intact.
- NuNuBar renders before the original battery, connection, Caps Lock, sleep,
  and system-switch indicators. Those original indicators therefore retain
  display priority while active.

## Source changes

- `keyboards/nuphy/air60_v2/ansi/side.c`
- `keyboards/nuphy/air60_v2/ansi/agent_light_protocol.h`
- `keyboards/nuphy/air60_v2/ansi/tests/agent_light_protocol_test.c`

No App source, Air96 source, or existing `firmware/air60-v2/` file is part of
this test build.

## Verification

- Protocol unit test compiled with `-Wall -Wextra -Werror`: passed
- `qmk lint -kb nuphy/air60_v2/ansi`: passed
- Full `nuphy/air60_v2/ansi:via` QMK build: passed
- DFU suffix check with `dfu-suffix -c`: passed
- `git apply --reverse --check` for the complete source patch: passed
- Physical keyboard, Bluetooth, 2.4 GHz, USB HID, side-light mapping, typing,
  battery indication, and recovery flashing: not tested

Do not promote or automatically flash this artifact until an Air60 V2 ANSI
owner has backed up VIA settings, prepared the official recovery firmware, and
completed a controlled physical validation pass.
