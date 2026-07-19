# NuNuBar Air96 V2 ANSI firmware v7

This directory contains the source patch required to reproduce the firmware
bundled with NuNuBar 0.8.0.

## Baseline

- Repository: `https://github.com/nuphy-src/qmk_firmware.git`
- Branch: `nuphy-keyboards`
- Commit: `f1856912d603800eaca227ae2e1c5c8548fdf261`
- Keyboard: `nuphy/air96_v2/ansi`
- Keymap: `via`
- Compiler: `arm-none-eabi-gcc 8.5.0`
- Patch: `air96-v2-custom-effects-v7.patch`
- Patch SHA-256: `9370bcb232f544ada90d9cc9577132dbae1b14f2d0284c2a4718e779de3c2552`

## Build

Apply the patch at the QMK repository root, then run:

```bash
PATH=/opt/homebrew/opt/arm-none-eabi-gcc@8/bin:/opt/homebrew/opt/avr-gcc@8/bin:/opt/homebrew/opt/avr-binutils/bin:/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/bin:$PATH \
  qmk compile -kb nuphy/air96_v2/ansi -km via
```

The packaged artifact is:

- File: `NuphyBar-Air96-V2-ANSI-custom-effects-v7.bin`
- Size: `66088` bytes
- SHA-256: `d3cfd9e76a38b70e823889197bdd92bc42e1fbfb96d938d02c4178720b0bb898`
- DFU target: `0483:df11`, alternate interface `0`, address `0x08000000`

The firmware supports the NuNuBar USB status protocol v3. Idle, working,
waiting, and complete each accept an RGB color plus solid, breathe, or blink
effect and render on both side-light bars.
