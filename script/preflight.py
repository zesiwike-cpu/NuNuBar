#!/usr/bin/env python3
"""Read-only host and keyboard discovery for a Codex-guided NuNuBar setup."""

from __future__ import annotations

import argparse
import json
import os
import platform
import plistlib
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
NUPHY_VENDOR_ID = 0x19F5
DFU_IDENTITY = (0x0483, 0xDF11)
RAW_HID_USAGE = (0xFF60, 0x0061)
AIR65_FN_RULE_DESCRIPTION = "NuNuBar Air65 V3: F24 to fn (globe)"

CATALOG = {
    0x102B: {
        "model": "NuPhy Air65 V3",
        "layout": "ANSI",
        "status": "verified",
        "platforms": ["macOS"],
        "route": "official-wired-control-no-flash",
    },
    0x3255: {
        "model": "NuPhy Air60 V2 ANSI",
        "layout": "ANSI",
        "status": "testing",
        "platforms": ["macOS", "Windows"],
        "route": "model-locked-v2-raw-hid",
    },
    0x3246: {
        "model": "NuPhy Air75 V2 ANSI",
        "layout": "ANSI",
        "status": "testing",
        "platforms": ["macOS", "Windows"],
        "route": "model-locked-v2-raw-hid",
    },
    0x3266: {
        "model": "NuPhy Air96 V2 ANSI",
        "layout": "ANSI",
        "status": "verified",
        "platforms": ["macOS", "Windows"],
        "route": "model-locked-v2-raw-hid",
    },
    0x32F5: {
        "model": "NuPhy Halo75 V2 ANSI",
        "layout": "ANSI",
        "status": "testing",
        "platforms": ["macOS", "Windows"],
        "route": "model-locked-v2-raw-hid",
    },
}


def run(command: list[str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, capture_output=True, check=False)


def integer(record: dict[str, Any], *keys: str) -> int | None:
    for key in keys:
        value = record.get(key)
        if isinstance(value, bool):
            continue
        if isinstance(value, int):
            return value
        if isinstance(value, bytes) and value:
            return int.from_bytes(value, byteorder="little")
        if isinstance(value, str):
            try:
                return int(value, 0)
            except ValueError:
                continue
    return None


def text_value(record: dict[str, Any], *keys: str) -> str | None:
    for key in keys:
        value = record.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def macos_ioreg(class_name: str) -> list[dict[str, Any]]:
    result = run(["/usr/sbin/ioreg", "-ar", "-c", class_name])
    if result.returncode != 0:
        return []
    try:
        value = plistlib.loads(result.stdout)
    except (plistlib.InvalidFileException, ValueError):
        return []
    return [item for item in value if isinstance(item, dict)] if isinstance(value, list) else []


def macos_hid_interfaces() -> list[dict[str, Any]]:
    interfaces: list[dict[str, Any]] = []
    for record in macos_ioreg("IOHIDDevice"):
        vendor_id = integer(record, "VendorID", "idVendor")
        product_id = integer(record, "ProductID", "idProduct")
        if vendor_id != NUPHY_VENDOR_ID or product_id is None:
            continue
        interfaces.append(
            {
                "product": text_value(record, "Product", "USB Product Name") or "Unknown NuPhy device",
                "vendorId": f"{vendor_id:04X}",
                "productId": f"{product_id:04X}",
                "transport": text_value(record, "Transport") or "unknown",
                "usagePage": integer(record, "PrimaryUsagePage"),
                "usage": integer(record, "PrimaryUsage"),
                "maxInputReportSize": integer(record, "MaxInputReportSize"),
                "maxOutputReportSize": integer(record, "MaxOutputReportSize"),
            }
        )
    return interfaces


def macos_usb_devices() -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    devices: list[dict[str, Any]] = []
    dfu_devices: list[dict[str, Any]] = []
    seen: set[tuple[int, int, int | None]] = set()
    for record in macos_ioreg("IOUSBHostDevice"):
        vendor_id = integer(record, "idVendor", "USB Vendor ID")
        product_id = integer(record, "idProduct", "USB Product ID")
        location_id = integer(record, "locationID")
        if vendor_id is None or product_id is None:
            continue
        identity = (vendor_id, product_id, location_id)
        if identity in seen:
            continue
        seen.add(identity)
        device = {
            "product": text_value(record, "USB Product Name", "kUSBProductString") or "Unknown USB device",
            "vendorId": f"{vendor_id:04X}",
            "productId": f"{product_id:04X}",
            "locationId": f"0x{location_id:08X}" if location_id is not None else None,
        }
        if (vendor_id, product_id) == DFU_IDENTITY:
            dfu_devices.append(device)
        elif vendor_id == NUPHY_VENDOR_ID:
            devices.append(device)
    return devices, dfu_devices


def windows_supported_interfaces() -> tuple[list[dict[str, Any]], str | None]:
    sys.path.insert(0, str(ROOT / "windows"))
    try:
        from nunubar.hid import HIDTransport  # type: ignore

        records = HIDTransport().list_devices()
        interfaces = [
            {
                "product": record.product_name,
                "vendorId": f"{record.vendor_id:04X}",
                "productId": f"{record.product_id:04X}",
                "transport": "USB",
                "usagePage": record.usage_page,
                "usage": record.usage,
                "maxInputReportSize": None,
                "maxOutputReportSize": record.output_report_length,
            }
            for record in records
        ]
        return interfaces, None
    except (ImportError, OSError, RuntimeError) as error:
        return [], str(error)


def windows_pnp_devices() -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    command = [
        "powershell.exe",
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        "Get-CimInstance Win32_PnPEntity | "
        "Where-Object { $_.PNPDeviceID -match 'VID_(19F5|0483)&PID_([0-9A-F]{4})' } | "
        "Select-Object Name,PNPDeviceID | ConvertTo-Json -Compress",
    ]
    result = run(command)
    if result.returncode != 0 or not result.stdout.strip():
        return [], []
    try:
        value = json.loads(result.stdout.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return [], []
    records = value if isinstance(value, list) else [value]
    devices: dict[tuple[int, int], dict[str, Any]] = {}
    dfu_devices: dict[tuple[int, int], dict[str, Any]] = {}
    for record in records:
        if not isinstance(record, dict):
            continue
        pnp_id = record.get("PNPDeviceID")
        if not isinstance(pnp_id, str):
            continue
        match = re.search(r"VID_([0-9A-F]{4})&PID_([0-9A-F]{4})", pnp_id, re.IGNORECASE)
        if not match:
            continue
        vendor_id, product_id = (int(part, 16) for part in match.groups())
        device = {
            "product": record.get("Name") or "Unknown USB device",
            "vendorId": f"{vendor_id:04X}",
            "productId": f"{product_id:04X}",
            "locationId": None,
        }
        target = dfu_devices if (vendor_id, product_id) == DFU_IDENTITY else devices
        target[(vendor_id, product_id)] = device
    return list(devices.values()), list(dfu_devices.values())


def classify_devices(
    host_name: str,
    usb_devices: list[dict[str, Any]],
    hid_interfaces: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    product_ids = {
        int(device["productId"], 16)
        for device in usb_devices + hid_interfaces
        if isinstance(device.get("productId"), str)
    }
    for product_id in sorted(product_ids):
        usb = [item for item in usb_devices if int(item["productId"], 16) == product_id]
        hid = [item for item in hid_interfaces if int(item["productId"], 16) == product_id]
        catalog = CATALOG.get(product_id)
        if catalog is None:
            result.append(
                {
                    "model": None,
                    "detectedProduct": (usb or hid)[0].get("product"),
                    "vendorId": f"{NUPHY_VENDOR_ID:04X}",
                    "productId": f"{product_id:04X}",
                    "catalogStatus": "unsupported",
                    "controlInterfaceReady": False,
                    "route": "stop-unsupported-device",
                    "physicalConfirmationRequired": True,
                    "interfaces": hid,
                }
            )
            continue

        if product_id == 0x102B:
            ready = host_name == "macOS" and any(
                str(interface.get("product", "")).casefold() == "air65 v3"
                and str(interface.get("transport", "")).casefold() == "usb"
                and interface.get("usagePage") == 0x0001
                and interface.get("usage") == 0x0000
                and interface.get("maxInputReportSize") == 64
                and interface.get("maxOutputReportSize") == 64
                for interface in hid
            )
        else:
            expected_output = 33 if host_name == "Windows" else 32
            ready = any(
                (interface.get("usagePage"), interface.get("usage")) == RAW_HID_USAGE
                and str(interface.get("transport", "")).casefold() == "usb"
                and (interface.get("maxOutputReportSize") or 0) >= expected_output
                for interface in hid
            )

        result.append(
            {
                "model": catalog["model"],
                "detectedProduct": (usb or hid)[0].get("product"),
                "vendorId": f"{NUPHY_VENDOR_ID:04X}",
                "productId": f"{product_id:04X}",
                "layout": catalog["layout"],
                "catalogStatus": catalog["status"],
                "platformSupported": host_name in catalog["platforms"],
                "controlInterfaceReady": ready,
                "route": catalog["route"] if host_name in catalog["platforms"] else "stop-unsupported-platform",
                "physicalConfirmationRequired": True,
                "firmwareCompatibilityKnown": product_id == 0x102B,
                "interfaces": hid,
            }
        )
    return result


def macos_installation() -> dict[str, Any]:
    app = Path("/Applications/NuNuBar.app")
    info_path = app / "Contents" / "Info.plist"
    version = None
    build = None
    if info_path.is_file():
        try:
            info = plistlib.loads(info_path.read_bytes())
            version = info.get("CFBundleShortVersionString")
            build = info.get("CFBundleVersion")
        except (OSError, plistlib.InvalidFileException, ValueError):
            pass
    process = run(["/bin/ps", "-axo", "command="])
    running = b"/Applications/NuNuBar.app/Contents/MacOS/NuNuBar" in process.stdout
    return {
        "installed": app.is_dir(),
        "path": str(app),
        "version": version,
        "build": build,
        "runningFromExpectedPath": running,
        "codexHooksPresent": codex_hooks_present(Path.home()),
    }


def windows_installation() -> dict[str, Any]:
    local_app_data = os.environ.get("LOCALAPPDATA")
    executable = Path(local_app_data) / "NuNuBar" / "NuNuBar.exe" if local_app_data else None
    return {
        "installed": bool(executable and executable.is_file()),
        "path": str(executable) if executable else None,
        "version": None,
        "build": None,
        "runningFromExpectedPath": None,
        "codexHooksPresent": codex_hooks_present(Path.home()),
    }


def codex_hooks_present(home: Path) -> bool:
    path = home / ".codex" / "hooks.json"
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return False
    serialized = json.dumps(value, ensure_ascii=True).lower()
    return "nunubar" in serialized and " hook codex " in f" {serialized} "


def air65_fn_rule_matches(rule: Any) -> bool:
    if not isinstance(rule, dict) or rule.get("description") != AIR65_FN_RULE_DESCRIPTION:
        return False
    manipulators = rule.get("manipulators")
    if not isinstance(manipulators, list) or len(manipulators) != 1:
        return False
    manipulator = manipulators[0]
    if not isinstance(manipulator, dict) or manipulator.get("type") != "basic":
        return False
    source = manipulator.get("from")
    targets = manipulator.get("to")
    conditions = manipulator.get("conditions")
    if not isinstance(source, dict) or source.get("key_code") != "f24":
        return False
    if not isinstance(targets, list) or not any(
        isinstance(target, dict)
        and target.get("apple_vendor_top_case_key_code") == "keyboard_fn"
        for target in targets
    ):
        return False
    if not isinstance(conditions, list):
        return False
    for condition in conditions:
        if not isinstance(condition, dict) or condition.get("type") != "device_if":
            continue
        identifiers = condition.get("identifiers")
        if not isinstance(identifiers, list):
            continue
        if any(
            isinstance(identifier, dict)
            and identifier.get("vendor_id") == NUPHY_VENDOR_ID
            and identifier.get("product_id") == 0x102B
            and identifier.get("is_keyboard") is True
            for identifier in identifiers
        ):
            return True
    return False


def macos_air65_fn_shortcut(home: Path, include_hardware: bool = True) -> dict[str, Any]:
    app = Path("/Applications/Karabiner-Elements.app")
    cli = Path(
        "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
    )
    config = home / ".config" / "karabiner" / "karabiner.json"
    mapping_present = False
    configuration_valid = False
    try:
        value = json.loads(config.read_text(encoding="utf-8"))
        profiles = value.get("profiles") if isinstance(value, dict) else None
        if isinstance(profiles, list):
            configuration_valid = True
            mapping_present = any(
                air65_fn_rule_matches(rule)
                for profile in profiles
                if isinstance(profile, dict)
                for complex_modifications in [profile.get("complex_modifications")]
                if isinstance(complex_modifications, dict)
                for rules in [complex_modifications.get("rules")]
                if isinstance(rules, list)
                for rule in rules
            )
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        pass

    physical_keyboard_ready = False
    virtual_keyboard_ready = False
    if include_hardware and cli.is_file() and os.access(cli, os.X_OK):
        result = run([str(cli), "--list-connected-devices"])
        if result.returncode == 0:
            try:
                devices = json.loads(result.stdout.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                devices = []
            if isinstance(devices, list):
                for device in devices:
                    identifiers = device.get("device_identifiers") if isinstance(device, dict) else None
                    if not isinstance(identifiers, dict):
                        continue
                    if (
                        identifiers.get("vendor_id") == NUPHY_VENDOR_ID
                        and identifiers.get("product_id") == 0x102B
                        and identifiers.get("is_keyboard") is True
                    ):
                        physical_keyboard_ready = True
                    if (
                        identifiers.get("is_keyboard") is True
                        and identifiers.get("is_virtual_device") is True
                    ):
                        virtual_keyboard_ready = True

    return {
        "supported": True,
        "karabinerInstalled": app.is_dir(),
        "configurationPath": str(config),
        "configurationPresent": config.is_file(),
        "configurationValid": configuration_valid,
        "managedMappingPresent": mapping_present,
        "physicalAir65Ready": physical_keyboard_ready,
        "virtualKeyboardReady": virtual_keyboard_ready,
        "ready": mapping_present and physical_keyboard_ready and virtual_keyboard_ready,
        "changesMade": False,
    }


def verify_repository() -> tuple[bool, str]:
    result = subprocess.run(
        [sys.executable, str(ROOT / "script" / "verify_repository.py")],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    detail = (result.stdout if result.returncode == 0 else result.stderr).strip()
    return result.returncode == 0, detail


def build_setup_plan(report: dict[str, Any]) -> dict[str, Any]:
    plan: dict[str, Any] = {
        "eligible": False,
        "path": None,
        "status": "stop",
        "summary": "No hardware-verified normal-user path was selected.",
        "required": [],
        "conditionalFirmwareRequirements": [],
        "approvalGates": [],
        "nextAction": "stop-and-explain",
        "limitations": [],
    }
    if not report.get("repository", {}).get("verified"):
        plan["summary"] = "Repository verification failed; do not install or flash anything."
        return plan

    host = report.get("host") or {}
    if host.get("os") != "macOS" or host.get("architecture") not in {"arm64", "aarch64"}:
        plan["summary"] = (
            "The two hardware-verified paths currently require Apple Silicon macOS. "
            "Windows and other hosts are not normal-user success paths yet."
        )
        return plan

    candidates = [
        keyboard
        for keyboard in report.get("keyboards", [])
        if keyboard.get("productId") in {"102B", "3266"}
    ]
    if len(candidates) != 1:
        plan["summary"] = (
            "Connect exactly one Air65 V3 or Air96 V2 ANSI by USB, then run preflight again."
        )
        plan["nextAction"] = "connect-one-verified-keyboard-by-usb"
        return plan

    keyboard = candidates[0]
    installation = report.get("installation") or {}
    common_approvals = [
        "install-or-replace-nunubar-app",
        "write-codex-hooks",
    ]
    if keyboard["productId"] == "102B":
        plan.update(
            {
                "eligible": True,
                "path": "air65-v3-macos-wired",
                "status": "hardware-verified",
                "summary": (
                    "Use the Air65 V3 official wired control path. Never enter DFU or flash firmware."
                ),
                "required": [
                    "Apple Silicon Mac with macOS 14 or later",
                    "Printed model confirmed as Air65 V3",
                    "USB wired mode and a data-capable cable",
                    "NuNuBar App running from /Applications",
                    "Four reviewed and approved Codex Hooks",
                ],
                "approvalGates": common_approvals + [
                    "optional-install-karabiner-elements-for-key-mapping",
                    "optional-write-karabiner-config-for-key-mapping",
                ],
                "limitations": [
                    "Air65 V3 status lighting is USB-only; Bluetooth is typing-only",
                    "Status lighting does not require Karabiner",
                    "Key and knob mapping requires official Karabiner-Elements",
                ],
            }
        )
        if not keyboard.get("controlInterfaceReady"):
            plan["nextAction"] = "switch-air65-to-wired-usb-and-reconnect"
        elif not installation.get("installed"):
            plan["nextAction"] = "install-nunubar-app"
        elif not installation.get("codexHooksPresent"):
            plan["nextAction"] = "connect-and-approve-codex-hooks"
        else:
            plan["nextAction"] = "run-light-self-test-and-real-codex-acceptance"
        return plan

    plan.update(
        {
            "eligible": True,
            "path": "air96-v2-ansi-macos-v7",
            "status": "hardware-verified",
            "summary": (
                "Use the Air96 V2 ANSI v7 path. Test the installed firmware first and never reflash a working keyboard."
            ),
            "required": [
                "Apple Silicon Mac with macOS 14 or later",
                "Printed model and physical layout confirmed as Air96 V2 ANSI",
                "USB wired mode and a data-capable cable",
                "NuNuBar App running from /Applications",
                "Visible orange, green, and red App self-test",
                "Four reviewed and approved Codex Hooks",
            ],
            "conditionalFirmwareRequirements": [
                "Required only when the App self-test produces no visible status-light change",
                "VIA JSON backup stored outside the repository",
                "Exact official Air96 V2 ANSI recovery firmware and source URL",
                "Bundled NuNuBar v7 firmware with manifest size and SHA-256 verified",
                "Separate user confirmations for entering DFU and for the final firmware write",
            ],
            "approvalGates": common_approvals + [
                "enter-dfu-only-if-self-test-fails",
                "flash-air96-v2-v7-only-after-a-second-confirmation",
            ],
            "limitations": [
                "This path is only verified for the exact Air96 V2 ANSI model",
                "A common STM32 DFU identity never proves the keyboard model",
            ],
        }
    )
    plan["nextAction"] = (
        "install-nunubar-app"
        if not installation.get("installed")
        else "run-air96-existing-firmware-light-self-test"
    )
    return plan


def collect(include_hardware: bool) -> dict[str, Any]:
    repository_verified, repository_detail = verify_repository()
    system = platform.system()
    host_name = {"Darwin": "macOS", "Windows": "Windows"}.get(system, system or "Unknown")
    host_supported = host_name in {"macOS", "Windows"}
    report: dict[str, Any] = {
        "schemaVersion": 1,
        "repository": {"verified": repository_verified, "detail": repository_detail},
        "host": {
            "os": host_name,
            "version": platform.mac_ver()[0] if host_name == "macOS" else platform.version(),
            "architecture": platform.machine(),
            "supported": host_supported,
        },
        "installation": None,
        "air65FnShortcut": None,
        "keyboards": [],
        "dfuDevices": [],
        "discoveryWarnings": [],
        "setupPlan": None,
        "changesMade": False,
    }
    if not host_supported:
        report["discoveryWarnings"].append("NuNuBar currently supports macOS and Windows only.")
        report["setupPlan"] = build_setup_plan(report)
        return report

    report["installation"] = macos_installation() if host_name == "macOS" else windows_installation()
    if host_name == "macOS":
        report["air65FnShortcut"] = macos_air65_fn_shortcut(
            Path.home(),
            include_hardware=include_hardware,
        )
    if not include_hardware:
        report["discoveryWarnings"].append("Hardware discovery was skipped by request.")
        report["setupPlan"] = build_setup_plan(report)
        return report

    if host_name == "macOS":
        hid_interfaces = macos_hid_interfaces()
        usb_devices, dfu_devices = macos_usb_devices()
    else:
        hid_interfaces, error = windows_supported_interfaces()
        usb_devices, dfu_devices = windows_pnp_devices()
        if error:
            report["discoveryWarnings"].append(f"Windows HID inspection failed: {error}")

    report["keyboards"] = classify_devices(host_name, usb_devices, hid_interfaces)
    report["dfuDevices"] = dfu_devices
    if dfu_devices:
        report["discoveryWarnings"].append(
            "STM32 DFU 0483:DF11 does not identify a keyboard model; never select firmware from DFU identity alone."
        )
    if not report["keyboards"]:
        report["discoveryWarnings"].append("No supported or candidate NuPhy USB device was detected.")
    report["setupPlan"] = build_setup_plan(report)
    return report


def render(report: dict[str, Any]) -> str:
    host = report["host"]
    lines = [
        "NuNuBar read-only preflight",
        f"Repository: {'verified' if report['repository']['verified'] else 'FAILED'}",
        f"Host: {host['os']} {host['version']} ({host['architecture']})",
    ]
    installation = report.get("installation")
    if installation:
        version = installation.get("version") or "unknown version"
        lines.append(
            f"App: {'installed' if installation['installed'] else 'not installed'} ({version}); "
            f"Codex Hooks: {'present' if installation['codexHooksPresent'] else 'not detected'}"
        )
    shortcut = report.get("air65FnShortcut")
    if shortcut:
        lines.append(
            "Air65 yellow-key Fn: "
            f"Karabiner={'installed' if shortcut['karabinerInstalled'] else 'not installed'}, "
            f"mapping={'present' if shortcut['managedMappingPresent'] else 'not present'}, "
            f"engine-ready={shortcut['ready']}"
        )
    plan = report.get("setupPlan")
    if plan:
        lines.append(f"Verified path: {plan['path'] or 'none'}")
        lines.append(f"Decision: {plan['summary']}")
        lines.append(f"Next action: {plan['nextAction']}")
    if report["keyboards"]:
        lines.append("Keyboard candidates:")
        for keyboard in report["keyboards"]:
            usage = [
                f"{interface['usagePage']:04X}:{interface['usage']:04X}"
                for interface in keyboard["interfaces"]
                if isinstance(interface.get("usagePage"), int) and isinstance(interface.get("usage"), int)
            ]
            lines.append(
                f"- {keyboard.get('model') or keyboard.get('detectedProduct')} "
                f"{keyboard['vendorId']}:{keyboard['productId']} | "
                f"status={keyboard['catalogStatus']} | control-ready={keyboard['controlInterfaceReady']} | "
                f"HID={','.join(usage) or 'not found'}"
            )
            if keyboard.get("route") == "model-locked-v2-raw-hid":
                lines.append(
                    "  V2 firmware compatibility is not inferable from VID/PID. Run the App self-test first; "
                    "do not flash if status lighting already works."
                )
    for warning in report["discoveryWarnings"]:
        lines.append(f"Warning: {warning}")
    lines.extend(
        [
            "Printed model and ANSI layout still require human confirmation.",
            "No App, Hooks, permissions, DFU state, or firmware was changed.",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="emit a machine-readable report")
    parser.add_argument("--no-hardware", action="store_true", help="skip USB/HID discovery (for CI)")
    arguments = parser.parse_args()
    report = collect(include_hardware=not arguments.no_hardware)
    print(json.dumps(report, indent=2, ensure_ascii=False) if arguments.json else render(report))
    return 0 if report["repository"]["verified"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
