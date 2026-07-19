# NBAR status-light protocol

This document specifies the host-to-keyboard NuNuBar status protocol. The USB
payload is stable across macOS and Windows; only the operating-system HID API
framing differs.

## USB HID interface

- Vendor ID: `0x19F5` (NuPhy)
- Usage page: `0xFF60`
- Usage ID: `0x61`
- HID report ID: `0`
- Logical NBAR payload size: exactly 32 bytes
- Direction: host output report to keyboard
- Command model: persistent state changes, not streamed animation frames

The keyboard renders breathing, blinking, and other animation frames locally.
Hosts should send on a state or palette change and after reconnect, not at an
animation frame rate.

## USB model allowlist

| Model/layout | VID:PID | Decimal PID | Validation | Light topology |
| --- | --- | ---: | --- | --- |
| Air60 V2 ANSI | `19F5:3255` | 12885 | Testing | Left `64-68`, right `69-73` |
| Air75 V2 ANSI | `19F5:3246` | 12870 | Testing | Two native 6-LED side bars |
| Air96 V2 ANSI | `19F5:3266` | 12902 | Hardware verified | Two native side bars |
| Halo75 V2 ANSI | `19F5:32F5` | 13045 | Testing | Native 45-LED Halolight |

Matching the USB allowlist is necessary but not sufficient for flashing. The
printed model and ANSI layout must also be confirmed. `0483:DF11` is the shared
STM32 bootloader identity and is never a model identifier.

## Common fields

All multi-byte descriptions below are byte sequences, not integers. Unused
bytes must be zero.

| Offset | Size | Value | Meaning |
| ---: | ---: | --- | --- |
| `0` | 4 | `4E 42 41 52` | ASCII `NBAR` magic |
| `4` | 1 | `01`, `02`, or `03` | Protocol version |
| `5` | 1 | `01` | Set-status command |
| `6` | 1 | See status table | Status value |

The checksum is an 8-bit XOR initialized to zero. XOR only the bytes before
the checksum position; trailing zero padding is not included.

## Status values

| Status | Byte | Meaning |
| --- | ---: | --- |
| Idle | `00` | No active Agent work |
| Working | `01` | Agent is processing or using tools |
| Waiting | `04` | Human confirmation or input is required |
| Error | `04` | Shares the waiting visual role on the wire |
| Complete | `05` | Work completed recently |

Unknown status values must be rejected without changing the current display.

## Version 1: status only

| Offset | Size | Meaning |
| ---: | ---: | --- |
| `0-6` | 7 | Common header and status |
| `7` | 1 | XOR of bytes `0-6` |
| `8-31` | 24 | Zero padding |

Firmware chooses its built-in color and effect. Current firmware defaults are
working orange with a local wave, waiting/error red blink, complete green
solid, and factory lighting at idle.

## Version 2: status and RGB

| Offset | Size | Meaning |
| ---: | ---: | --- |
| `0-6` | 7 | Common header and status |
| `7` | 1 | Red, `0-255` |
| `8` | 1 | Green, `0-255` |
| `9` | 1 | Blue, `0-255` |
| `10` | 1 | XOR of bytes `0-9` |
| `11-31` | 21 | Zero padding |

Firmware uses the supplied color and chooses its built-in effect for the
status. At idle, the built-in factory effect may take control.

## Version 3: status, RGB, and effect

| Offset | Size | Meaning |
| ---: | ---: | --- |
| `0-6` | 7 | Common header and status |
| `7` | 1 | Red, `0-255` |
| `8` | 1 | Green, `0-255` |
| `9` | 1 | Blue, `0-255` |
| `10` | 1 | Effect value |
| `11` | 1 | XOR of bytes `0-10` |
| `12-31` | 20 | Zero padding |

Public v3 effect values are:

| Effect | Byte | Rendering |
| --- | ---: | --- |
| Solid | `00` | Constant selected RGB |
| Breathe | `01` | Firmware-timed brightness cycle |
| Blink | `02` | Firmware-timed on/off cycle |

Other effect values must be rejected. Firmware may use private effects such as
a wave for v1/v2 defaults, but a host must not send those values in v3.

The default NuNuBar v3 palette is:

| Status role | RGB | Effect |
| --- | --- | --- |
| Idle | `0, 0, 0` (`#000000`) | Solid |
| Working | `252, 84, 0` (`#FC5400`) | Breathe |
| Waiting/error | `255, 0, 0` (`#FF0000`) | Blink |
| Complete | `0, 255, 0` (`#00FF00`) | Solid |

## Compatibility behavior

A receiver validates all of the following before applying a report: exact
32-byte payload length, magic, supported version, command `01`, known status,
version-specific checksum, and (for v3) a known effect.

The macOS sender currently transmits v1, then v2, then v3 for each update. This
allows older compatible firmware to receive the newest version it understands;
v3 firmware ends on the fully customized packet. A new sender may negotiate or
select a known supported version, but must not assume that a successful HID
write proves that the firmware parsed the payload.

## Windows report-ID framing

The 32 bytes above are the logical NBAR payload. Windows HID `WriteFile` style
APIs require the report ID as byte zero of the API buffer, even when the report
ID is zero:

```text
00 | 4E 42 41 52 ... 32-byte NBAR payload ...
^    ^
ID  payload byte 0
```

Therefore the normal Windows output buffer is 33 bytes: one `00` report-ID
prefix followed by the complete 32-byte payload. If the device-reported output
length is larger, append zero padding after the payload. Do not count the
Windows prefix as part of the NBAR length and do not include it in the NBAR XOR
checksum.

macOS `IOHIDDeviceSetReport` receives report ID `0` as a separate argument and
is passed the 32-byte NBAR payload without this prefix.

## Air65 V3 official control transport

Air65 V3 does not use NBAR firmware. NuNuBar for macOS talks to the control
interface already exposed by official Air65 V3 firmware and applies the same
host-side state and palette model.

The allowlist is intentionally exact:

- product name: `Air65 V3`;
- transport: USB;
- VID:PID: `19F5:102B`;
- HID usage page/usage: `0001:0000`;
- input and output report size: 64 bytes;
- report ID: `0`.

NuNuBar first sends a `55 EE` challenge and validates the `AA EE` response,
checksum, repeated session-key bytes, and XOR response payload. It then sends a
`GetBase` command (`A0`) for eight bytes at offset `0`. The decrypted first data
byte is the keyboard's current mode; the channel is not ready until this value
has been read.

Set-data reports use command `D6`, the negotiated XOR key, and an additive
checksum over bytes `4-63`. Encrypted byte `4` is payload length, bytes `5-6`
are the little-endian data offset, and byte `7` is the current mode. The
side-light payload is eight bytes at offset `9`; the brightness payload is one
byte at offset `10`. Incoming `AA D6` acknowledgements are checksum validated
while the app remains connected. An acknowledgement proves transport and packet
validity, but does not by itself prove that a visible active light record was
changed.

The official effect identifiers used by NuNuBar are static `2` and breathe `3`.
Because the official firmware does not expose a discrete blink mode, NuNuBar
renders blink as acknowledged 500 ms solid on/off frames. Each control report
must receive a valid `AA D6` response before the next report is sent. A timeout
rebuilds the full HID session, then the app replays the current state after a new
handshake. This path never enters DFU, writes firmware, or
touches keyboard input interfaces, receivers, or upgrader PIDs. The current
NuNuBar Windows companion remains NBAR Raw HID only.

## Wireless status channel

Wireless status is not a 32-byte NBAR transport. On the currently supported
macOS path, the host updates the standard keyboard LED output report and uses
the following persistent bit mask:

- bit `0x02`: Caps Lock, owned by normal keyboard behavior;
- bits selected by mask `0x05`: NBAR status (`00`, `01`, `04`, or `05`).

Firmware extracts the coarse status and renders built-in colors/effects. RGB
and effect values from the desktop palette are not sent over this channel.
Wireless delivery also depends on the model firmware and active connection
path; it must not be inferred from USB Raw HID support.

The first Windows release deliberately supports USB Raw HID only. It does not
claim Bluetooth or 2.4G status delivery.

## Safety and forward compatibility

- Ignore malformed packets without changing the previous valid state.
- Do not stream animation frames over USB, Bluetooth, or 2.4G.
- Do not widen the VID/PID allowlist without a model-specific firmware,
  catalog entry, tests, and hardware validation status.
- Keep firmware flashing outside this protocol. NBAR packets never request
  DFU, erase flash, or write firmware.
- Add a new protocol version instead of silently changing existing offsets.
