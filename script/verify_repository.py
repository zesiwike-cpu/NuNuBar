#!/usr/bin/env python3
"""Validate NuNuBar release metadata and model-specific firmware inputs."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
FIRMWARE_ROOT = ROOT / "Sources" / "AgentLightApp" / "Resources" / "Firmware"

EXPECTED_MODELS = {
    "air60-v2-ansi": {
        "product_id": 0x3255,
        "status": "testing",
        "zone": "dualSideBars",
        "build_record": ROOT / "firmware" / "air60-v2-qmk" / "BUILD_RECORD.md",
    },
    "air75-v2-ansi": {
        "product_id": 0x3246,
        "status": "testing",
        "zone": "dualSideBars",
        "build_record": ROOT / "firmware" / "air75-v2" / "BUILD_RECORD.md",
    },
    "air96-v2-ansi": {
        "product_id": 0x3266,
        "status": "verified",
        "zone": "dualSideBars",
        "build_record": ROOT / "firmware" / "air96-v2" / "BUILD_RECORD.md",
    },
    "halo75-v2-ansi": {
        "product_id": 0x32F5,
        "status": "testing",
        "zone": "halolight",
        "build_record": ROOT / "firmware" / "halo75-v2" / "BUILD_RECORD.md",
    },
}

VERIFIED_NORMAL_PATHS = {
    "air65-v3-macos-wired",
    "air96-v2-ansi-macos-v7",
}


def fail(message: str) -> None:
    raise ValueError(message)


def read_text(path: Path) -> str:
    if not path.is_file():
        fail(f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def default_app_version(path: Path) -> str:
    match = re.search(r'APP_VERSION="\$\{APP_VERSION:-([^}]+)\}"', read_text(path))
    if not match:
        fail(f"could not read APP_VERSION from {path.relative_to(ROOT)}")
    return match.group(1)


def verify_versions() -> str:
    version_files = [
        ROOT / "script" / "build_app.sh",
        ROOT / "script" / "package_release.sh",
        ROOT / "script" / "package_public_release.sh",
    ]
    versions = {path: default_app_version(path) for path in version_files}
    unique_versions = set(versions.values())
    if len(unique_versions) != 1:
        detail = ", ".join(
            f"{path.name}={version}" for path, version in versions.items()
        )
        fail(f"App version defaults disagree: {detail}")

    version = unique_versions.pop()
    about = read_text(ROOT / "Sources" / "AgentLightApp" / "Views" / "AboutSettingsView.swift")
    if f'?? "{version}"' not in about:
        fail("AboutSettingsView fallback version does not match packaging scripts")
    windows_version = read_text(ROOT / "windows" / "nunubar" / "__init__.py")
    if f'__version__ = "{version}"' not in windows_version:
        fail("Windows client version does not match packaging scripts")
    read_text(ROOT / "docs" / "releases" / f"v{version}.md")
    if f"## {version} -" not in read_text(ROOT / "CHANGELOG.md"):
        fail(f"CHANGELOG.md has no dated {version} section")
    return version


def verify_firmware_catalog() -> None:
    manifest_path = FIRMWARE_ROOT / "manifest.json"
    manifest = json.loads(read_text(manifest_path))
    if manifest.get("schemaVersion") != 2:
        fail("firmware manifest schemaVersion must be 2")

    entries = manifest.get("firmwares")
    if not isinstance(entries, list):
        fail("firmware manifest firmwares must be a list")
    by_model = {entry.get("modelIdentifier"): entry for entry in entries}
    if set(by_model) != set(EXPECTED_MODELS):
        fail(
            "firmware catalog models must be exactly: "
            + ", ".join(EXPECTED_MODELS)
        )
    if "air65-v3" in by_model:
        fail("Air65 V3 must never have a flashable NuNuBar firmware entry")

    for model, expected in EXPECTED_MODELS.items():
        entry = by_model[model]
        if entry.get("layout") != "ANSI":
            fail(f"{model} layout must remain ANSI")
        if entry.get("keyboardVendorID") != 0x19F5:
            fail(f"{model} vendor ID changed")
        if entry.get("keyboardProductID") != expected["product_id"]:
            fail(f"{model} product ID changed")
        if entry.get("releaseStatus") != expected["status"]:
            fail(f"{model} release status changed without hardware evidence")
        if entry.get("lightZone") != expected["zone"]:
            fail(f"{model} light zone changed")
        if entry.get("protocolVersion") != 3:
            fail(f"{model} protocol version must remain 3")
        if entry.get("dfuVendorID") != 0x0483 or entry.get("dfuProductID") != 0xDF11:
            fail(f"{model} DFU identity changed")
        if entry.get("alternateInterface") != 0:
            fail(f"{model} DFU alternate interface must be 0")
        if entry.get("flashAddress") != "0x08000000":
            fail(f"{model} flash address changed")

        firmware = FIRMWARE_ROOT / str(entry.get("firmwareFile", ""))
        if not firmware.is_file():
            fail(f"missing firmware for {model}: {firmware.name}")
        data = firmware.read_bytes()
        if len(data) != entry.get("firmwareSize"):
            fail(f"firmware size mismatch for {model}")
        if hashlib.sha256(data).hexdigest() != entry.get("firmwareSHA256"):
            fail(f"firmware SHA-256 mismatch for {model}")
        read_text(expected["build_record"])


def verify_handoff_docs() -> None:
    required_phrases = {
        ROOT / "AGENTS.md": [
            "air65-v3-macos-wired",
            "air96-v2-ansi-macos-v7",
            "never flash",
            "script/preflight.py",
        ],
        ROOT / "README.md": ["Air65 V3", "Air96 V2 ANSI", "Codex setup", "script/preflight.py", "Karabiner-Elements"],
        ROOT / "README.zh-CN.md": ["Air65 V3", "Air96 V2 ANSI", "交给 Codex", "script/preflight.py", "Karabiner-Elements"],
        ROOT / "START_HERE.md": [
            "air65-v3-macos-wired",
            "air96-v2-ansi-macos-v7",
            "setupPlan",
            "script/preflight.py",
            "hooks.json",
            "Karabiner-Elements",
        ],
        ROOT / "docs" / "CODEX_SETUP.md": ["Codex Hook steps", "hooks.json", "PermissionRequest", "Karabiner-Elements"],
        ROOT / "docs" / "CODEX_SETUP.zh-CN.md": ["Codex Hooks 操作步骤", "hooks.json", "PermissionRequest", "Karabiner-Elements"],
        ROOT / "docs" / "VERIFIED_PATHS.md": [
            "air65-v3-macos-wired",
            "air96-v2-ansi-macos-v7",
            "AIR96_V2_SUCCESS.md",
        ],
        ROOT / "docs" / "VERIFIED_PATHS.zh-CN.md": [
            "air65-v3-macos-wired",
            "air96-v2-ansi-macos-v7",
            "AIR96_V2_SUCCESS.zh-CN.md",
        ],
        ROOT / "docs" / "AIR65_V3_VERIFICATION.md": [
            "NuNuBar 0.13.1 build 48",
            "F21",
            "F22",
            "F23",
            "Command-Shift-]",
        ],
        ROOT / "docs" / "AIR65_V3_KEY_MAPPING.md": [
            "0.13.1 build 48",
            "F21",
            "F22",
            "F23",
            "Command-Shift-]",
        ],
        ROOT / "docs" / "AIR65_V3_KEY_MAPPING.zh-CN.md": [
            "0.13.1 build 48",
            "F21",
            "F22",
            "F23",
            "Command-Shift-]",
        ],
        ROOT / "docs" / "AIR65_V3_FN_SHORTCUT.md": ["19F5:102B", "F24", "keyboard_fn", "Karabiner-Elements 16.1.0"],
        ROOT / "docs" / "AIR65_V3_FN_SHORTCUT.zh-CN.md": ["19F5:102B", "F24", "keyboard_fn", "Karabiner-Elements 16.1.0"],
        ROOT / "docs" / "AIR96_V2_SUCCESS.md": [
            "air96-v2-ansi-macos-v7",
            "existing firmware",
            "66088",
            "d3cfd9e76a38b70e823889197bdd92bc42e1fbfb96d938d02c4178720b0bb898",
        ],
        ROOT / "docs" / "AIR96_V2_SUCCESS.zh-CN.md": [
            "air96-v2-ansi-macos-v7",
            "现有固件",
            "66088",
            "d3cfd9e76a38b70e823889197bdd92bc42e1fbfb96d938d02c4178720b0bb898",
        ],
    }
    for path, phrases in required_phrases.items():
        text = read_text(path)
        for phrase in phrases:
            if phrase not in text:
                fail(f"{path.relative_to(ROOT)} is missing required text: {phrase}")


def verify_preflight_catalog() -> None:
    path = ROOT / "script" / "preflight.py"
    spec = importlib.util.spec_from_file_location("nunubar_preflight_verify", path)
    if spec is None or spec.loader is None:
        fail("could not load script/preflight.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    catalog = module.CATALOG

    air65 = catalog.get(0x102B)
    if not isinstance(air65, dict):
        fail("preflight catalog is missing Air65 V3")
    if air65.get("route") != "official-wired-control-no-flash":
        fail("Air65 V3 preflight route must remain no-flash")
    if air65.get("status") != "verified":
        fail("Air65 V3 preflight status must remain verified")
    if air65.get("platforms") != ["macOS"]:
        fail("Air65 V3 preflight route is currently macOS-only")

    expected_by_product = {
        expected["product_id"]: (model, expected)
        for model, expected in EXPECTED_MODELS.items()
    }
    if set(catalog) != {0x102B, *expected_by_product}:
        fail("preflight catalog must contain only Air65 V3 and the four V2 models")
    for product_id, (model, expected) in expected_by_product.items():
        entry = catalog[product_id]
        if entry.get("status") != expected["status"]:
            fail(f"preflight release status disagrees for {model}")
        if entry.get("layout") != "ANSI":
            fail(f"preflight layout disagrees for {model}")
        if entry.get("route") != "model-locked-v2-raw-hid":
            fail(f"preflight route disagrees for {model}")

    sample_reports = {
        "air65-v3-macos-wired": {
            "repository": {"verified": True},
            "host": {"os": "macOS", "architecture": "arm64"},
            "installation": {"installed": True, "codexHooksPresent": True},
            "keyboards": [{"productId": "102B", "controlInterfaceReady": True}],
        },
        "air96-v2-ansi-macos-v7": {
            "repository": {"verified": True},
            "host": {"os": "macOS", "architecture": "arm64"},
            "installation": {"installed": True, "codexHooksPresent": True},
            "keyboards": [{"productId": "3266", "controlInterfaceReady": True}],
        },
    }
    selected_paths = {
        module.build_setup_plan(report).get("path")
        for report in sample_reports.values()
    }
    if selected_paths != VERIFIED_NORMAL_PATHS:
        fail("preflight must expose exactly the two verified normal-user path IDs")

    windows_report = {
        "repository": {"verified": True},
        "host": {"os": "Windows", "architecture": "AMD64"},
        "installation": {},
        "keyboards": [{"productId": "3266", "controlInterfaceReady": True}],
    }
    if module.build_setup_plan(windows_report).get("eligible"):
        fail("preflight must not select a normal-user Windows path")


def verify_public_release_scope() -> None:
    workflow = read_text(ROOT / ".github" / "workflows" / "release.yml")
    for forbidden in ("release-windows", "NuNuBar-Windows-"):
        if forbidden in workflow:
            fail(f"public Release workflow must not publish contributor asset: {forbidden}")
    for required in (
        "needs: [macos]",
        "Air65 V3 or Air96 V2 ANSI only",
        "START_HERE.md",
    ):
        if required not in workflow:
            fail(f"public Release workflow is missing verified-path guard: {required}")


def main() -> int:
    try:
        version = verify_versions()
        verify_firmware_catalog()
        verify_handoff_docs()
        verify_preflight_catalog()
        verify_public_release_scope()
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"repository verification failed: {error}", file=sys.stderr)
        return 1

    print(f"NuNuBar {version} repository verification passed")
    print("Normal-user verified paths:")
    print("- air65-v3-macos-wired: official firmware, no flash")
    print("- air96-v2-ansi-macos-v7: self-test first, conditional v7 firmware")
    print("Contributor test assets retained: air60-v2-ansi, air75-v2-ansi, halo75-v2-ansi, Windows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
