# Security policy

## Supported version

Security fixes are applied to the latest NuNuBar Release.

## Reporting

Do not post private Agent configuration, local paths, session identifiers,
signing credentials, firmware dumps, or crash logs containing personal data in
a public issue. Use GitHub private vulnerability reporting when available. If
it is unavailable, open a minimal issue asking for a private contact channel
without including the sensitive details.

## Data boundary

NuNuBar is local-only:

- it does not read or store keystrokes;
- it does not send prompts or responses to another service;
- Agent hooks record only provider, coarse lifecycle status, local session identifier, and timestamp;
- the apps send small status reports to a locally connected NuPhy keyboard over USB Raw HID, the exact Air65 V3 official macOS control interface, or the existing Bluetooth keyboard LED channel;
- no analytics or telemetry service is bundled.

macOS labels the required HID capability as Input Monitoring even though
NuNuBar only writes output reports. Permission can be removed at any time in
System Settings > Privacy & Security > Input Monitoring. The Windows companion
uses the Win32 HID API and does not install a custom kernel driver.

Integration installers preserve unrelated JSON keys and only remove files or
entries marked as NuNuBar-owned. Hook trust remains a user decision in Codex;
setup scripts must not bypass or edit Codex trust decisions.

## Firmware safety

Firmware is hardware-specific. Current images target only the exact ANSI models
listed in the firmware manifest: Air60 V2, Air75 V2, Air96 V2, and Halo75 V2.
Air65 V3 is separately locked to `19F5:102B`, HID usage `0001:0000`, and a
64-byte official control report; it is never a firmware-flash target.
Confirm the exact model and layout, export VIA configuration, keep the matching
official recovery image, verify SHA-256, and use a stable USB connection before
flashing.

Only Air96 V2 has completed physical validation for the current USB v3 build.
Air60 V2, Air75 V2, and Halo75 V2 images are testing firmware and require an
additional warning and confirmation. Setup software must match the connected
USB VID/PID before DFU, accept only one intended STM32 DFU device, validate the
model-specific image hash, and request a separate final confirmation before
writing. Never weaken these checks to make a new model appear supported.
