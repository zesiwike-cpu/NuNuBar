# NuNuBar Halo75 V2 ANSI USB Raw HID v3 test firmware v1

This directory contains a hardware-unverified test firmware for the NuPhy
Halo75 V2 ANSI. It must not be promoted to one-click production flashing until
it has passed recovery-ready testing on the exact keyboard model.

## Baseline

- Repository: `https://github.com/nuphy-src/qmk_firmware.git`
- Branch: `nuphy-keyboards`
- Commit: `f1856912d603800eaca227ae2e1c5c8548fdf261`
- Keyboard: `nuphy/halo75_v2/ansi`
- Keymap: `via`
- MCU: `STM32F072`
- Bootloader: `stm32-dfu`
- Compiler: `arm-none-eabi-gcc 8.5.0`
- USB VID/PID: `19F5:32F5`
- Device version: `1.1.9`
- Patch: `halo75-v2-usb-raw-hid-v3-test-v1.patch`
- Patch SHA-256: `c27e9837a05b6e440810ca33cab69589d863d77856efcef667eb26a2e08145d0`

## Source changes

- `keyboards/nuphy/halo75_v2/ansi/agent_light_protocol.h`
- `keyboards/nuphy/halo75_v2/ansi/side.c`
- `keyboards/nuphy/halo75_v2/ansi/tests/agent_light_protocol_test.c`

The VIA keymap enables QMK Raw HID through `VIA_ENABLE = yes`; the QMK build
expands this to `RAW_ENABLE = yes`. The resulting interface uses QMK's default
vendor usage page `0xFF60`, usage ID `0x61`, report ID `0`, and 32-byte reports.

USB mode accepts NuNuBar protocol v1, v2, and v3 reports. Protocol v3 supports
custom RGB with solid, breathe, or blink effects. Bluetooth and 2.4G continue
to consume the original RF module's host LED state and use the protocol's
default status colors/effects because Raw HID is not available over those
wireless transports.

For Bluetooth and 2.4G, NuNuBar derives its status from `rf_led & 0x05`.
The independent Caps Lock bit `0x02` is excluded before selecting a default
effect and remains owned by the original host LED indicator layer. For
example, `0x07` becomes complete (`0x05`), `0x03` becomes working (`0x01`),
and Caps Lock alone (`0x02`) becomes idle (`0x00`) for NuNuBar rendering.

NuNuBar status rendering follows all 45 entries in Halo75 V2's original
`side_led_index_tab`, covering the complete Halolight instead of applying the
Air-series five-pixel side-bar mapping. The status layer is rendered before
the original battery, host LED, system-switch, sleep, and RF indicators, so
those keyboard prompts retain visual priority.

## Build

Run from the QMK repository root:

```bash
PATH=/opt/homebrew/opt/arm-none-eabi-gcc@8/bin:/opt/homebrew/opt/avr-gcc@8/bin:/opt/homebrew/opt/avr-binutils/bin:/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/bin:$PATH \
  qmk compile -kb nuphy/halo75_v2/ansi -km via
```

The test artifact is:

- File: `NuNuBar-Halo75-V2-ANSI-usb-raw-hid-v3-test-v1.bin`
- File size: `73748` bytes
- Linked flash content: `73730` bytes (`0x12002`)
- SHA-256: `adbdb0deaf6f92f3830117ba87a81dbffbbaf031cb3fbf6c58b24f77488ed7a8`
- STM32 DFU identity: `0483:df11`
- Expected flash target: alternate interface `0`, address `0x08000000`

No device was flashed while producing this artifact.

## Verification

- QMK compile completed successfully for `nuphy/halo75_v2/ansi:via`.
- Link map contains `via_command_kb` and `raw_hid_receive`.
- Build flags contain `VIA_ENABLE`, `RAW_ENABLE`, `BOOTLOADER_STM32_DFU`, and
  `QMK_MCU=STM32F072`.
- Protocol decoder host test passed with `-Wall -Wextra -Werror`.
- Wireless status decoding masks out Caps Lock with `rf_led & 0x05` before
  selecting the NuNuBar default color and effect.
- The 45-entry Halolight map contains each relative LED index `0..44` exactly
  once.
- `git diff --check` passed for the Halo75 V2 ANSI source changes.
- QMK lint accepts the new source files. Full keyboard lint remains blocked by
  missing license comments in the two unmodified upstream keymap files.

## Hardware validation required

- Confirm exact Halo75 V2 ANSI hardware and USB identity before entering DFU.
- Keep the official recovery firmware and a VIA layout backup available.
- Verify Raw HID enumeration, report ID `0`, 32-byte writes, and USB reconnect.
- Verify all 45 physical Halolight LEDs follow the intended perimeter order.
- Verify solid, breathe, and blink in USB mode for idle, working, waiting, and
  complete states.
- Verify Bluetooth and 2.4G status changes and all factory battery, pairing,
  connection, system-switch, sleep, Caps Lock, and startup indicators.
- Confirm the firmware matches the retail PCB revision and does not regress
  wireless pairing, charging, sleep, wake, or VIA behavior.
