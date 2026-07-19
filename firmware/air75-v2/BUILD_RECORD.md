# NuNuBar Air75 V2 ANSI USB Raw HID v3 test firmware

This directory records an unverified test build. NuNuBar may bundle it only as
explicitly labeled testing firmware with an additional user confirmation; it
must not be presented as verified release firmware until it has passed physical
Air75 V2 ANSI testing.

## Source

- Repository: `https://github.com/nuphy-src/qmk_firmware.git`
- Branch: `nuphy-keyboards`
- Commit: `f1856912d603800eaca227ae2e1c5c8548fdf261`
- Keyboard: `nuphy/air75_v2/ansi`
- Keymap: `via`
- Patch: `air75-v2-nunubar-usb-v3-test.patch`
- Patch SHA-256: `0216ed1fd68afa2290d93ffac1066fbcf36fe0fc0a9a4b7dd43625aec8919dd9`

## Toolchain and build

- QMK CLI: `1.1.8`
- Compiler: `arm-none-eabi-gcc 8.5.0`
- Build command:

```sh
PATH=/opt/homebrew/opt/arm-none-eabi-gcc@8/bin:/opt/homebrew/opt/avr-gcc@8/bin:/opt/homebrew/opt/avr-binutils/bin:/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/bin:$PATH \
  qmk compile -kb nuphy/air75_v2/ansi -km via
```

Build output:

- Binary: `.build/nuphy_air75_v2_ansi_via.bin`
- Root copy: `nuphy_air75_v2_ansi_via.bin`
- Test copy: `firmware/air75-v2/NuNuBar-Air75-V2-ANSI-usb-raw-hid-v3-test-v1.bin`
- File size: `65468` bytes
- SHA-256: `187124a455929ea83c69eaad40f111280d5fcee73f5ac639c2ce47090b85bd00`
- ELF sections: text `63470`, data `1980`, bss `14400` bytes

## USB and target metadata

- MCU: `STM32F072`
- Bootloader: `stm32-dfu`
- VID: `0x19F5`
- PID: `0x3246`
- VIA enables QMK Raw HID for this target.
- Raw HID report size: `32` bytes
- Raw HID usage page: `0xFF60`
- Raw HID usage ID: `0x61`
- Raw HID report ID: `0` (the descriptor has no explicit report-ID item)

## Behavior

- USB uses the NuNuBar `NBAR` protocol versions 1, 2, and 3.
- Protocol v3 accepts custom RGB with solid, breathe, and blink effects.
- Bluetooth and 2.4 GHz retain the existing one-byte status path from the RF
  module and use firmware defaults for working, confirmation, and completion.
- Wireless status rendering masks the RF byte with `0x05` before selecting the
  default effect. The independent `0x02` Caps Lock bit remains owned by the
  stock host LED indicator and may coexist with any NuNuBar state.
- Idle without a USB v3 override falls back to the selected factory side-light
  effect.
- The Air75 V2 side driver is preserved: six LEDs on each side are written
  through `side_led_index_tab` and retain the factory quarter-brightness limit.
- The NuNuBar status layer renders before the stock battery, sleep, OS switch,
  Caps Lock, connection, and pairing indicators, so stock indicators keep
  priority.

## Verification performed

- `qmk compile -kb nuphy/air75_v2/ansi -km via`: passed
- `qmk lint -kb nuphy/air75_v2/ansi`: passed
- Host protocol and RF status-mask tests with `-Wall -Wextra -Werror`: passed
- `git diff --check`: passed
- Compile database contains both `VIA_ENABLE` and `RAW_ENABLE`.
- The `.build`, root, and `firmware/air75-v2` test binaries are byte-identical.

## Unverified risks

- No physical Air75 V2 ANSI was connected, tested, or flashed.
- The physical left/right LED order and brightness are inferred from NuPhy's
  existing Air75 side-light driver and have not been visually confirmed.
- Bluetooth and 2.4 GHz state changes depend on the existing RF module status
  byte. Custom v3 RGB/effect payloads are USB-only because the public RF path
  does not carry those fields.
- NuPhy's public QMK commit may differ from a newer production firmware and may
  lack later RF stability fixes. Wireless typing, sleep/wake, charging, pairing,
  VIA backup/restore, and all stock indicators require regression testing.
- Keep the exact official Air75 V2 ANSI recovery firmware available before any
  controlled test flash.

No device was flashed while producing this build record.
