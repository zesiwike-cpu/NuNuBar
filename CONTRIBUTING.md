# Contributing

Thanks for helping improve NuNuBar.

## Before changing code

1. Open an issue describing the exact NuPhy model, layout, connection mode, and firmware track (QMK or NuPhy IO).
2. Never assume that two Air/Halo sizes share LED indices or a flashable binary.
3. Keep host-to-keyboard traffic state-based. Animation belongs in firmware; do not stream frames over USB/BLE or accelerate the stock RF polling loop.
4. Treat firmware flashing as a destructive operation. Detection, model/layout confirmation, recovery preparation, and final flash approval must remain separate checkpoints.
5. A model with an official control interface must use an exact product name,
   VID/PID, usage, and report-size allowlist. Keep it separate from firmware
   targets and document any native effect limitations.

## macOS checks

```bash
swift test
swift build -c release
bash -n script/*.sh firmware/air60-v2/*.sh
```

## Windows checks

The Windows companion targets Python 3.11 or later and uses only the standard
library at runtime. Its pure-logic tests can run on macOS, Linux, or Windows;
HID enumeration, startup registration, and the packaged executable still need
Windows verification.

```bash
python3 -m unittest discover -s windows/tests -v
```

## Legacy Air60 V2 firmware checks

```bash
./firmware/air60-v2/test.sh
./firmware/air60-v2/build.sh /path/to/official-v2.1.5.bin
```

The legacy Bluetooth release firmware must reproduce SHA-256
`c573c7939a53994b50f29313744f27f9af30b90cd064f13fc019f87710b89ac0`
with the documented GCC 8.5.0 toolchain.

## New keyboard ports

A port is not “supported” until it has:

- an exact model and layout;
- an official source/recovery baseline with hashes;
- model-specific LED indices or audited function signatures;
- tests for state decoding and effects;
- a dedicated output filename that includes the model;
- a manifest entry with the exact USB VID/PID, firmware size, SHA-256, protocol version, and release status;
- staged physical verification of typing, Caps Lock, every state, reconnect, sleep, and recovery.

A compiled image remains `testing` until it passes those checks on the exact
retail model and layout. Never reuse one model's image, LED map, or product ID
for another model.

Do not include user VIA backups, full-flash dumps, old experiments, official
recovery binaries, local Agent configuration, tokens, signing identities, or
notarization credentials in a pull request.

## Licensing

App changes are MIT. Firmware changes derived from QMK/NuPhy must remain
GPL-2.0-or-later and retain relevant copyright notices. Third-party logos must
include a primary source and must not be presented as project-owned artwork.
