from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).resolve().parents[1] / "preflight.py"
SPEC = importlib.util.spec_from_file_location("nunubar_preflight", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
preflight = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(preflight)


def usb(product_id: int, product: str) -> dict[str, object]:
    return {
        "product": product,
        "vendorId": "19F5",
        "productId": f"{product_id:04X}",
        "locationId": "0x01000000",
    }


def hid(
    product_id: int,
    usage_page: int,
    usage: int,
    input_size: int,
    output_size: int,
    product: str = "NuPhy keyboard",
) -> dict[str, object]:
    return {
        "product": product,
        "vendorId": "19F5",
        "productId": f"{product_id:04X}",
        "transport": "USB",
        "usagePage": usage_page,
        "usage": usage,
        "maxInputReportSize": input_size,
        "maxOutputReportSize": output_size,
    }


class PreflightClassificationTests(unittest.TestCase):
    def test_no_hardware_mode_does_not_run_karabiner_device_discovery(self) -> None:
        with mock.patch.object(preflight, "run") as run_mock:
            report = preflight.macos_air65_fn_shortcut(
                Path("/definitely-not-a-user-home"),
                include_hardware=False,
            )

        run_mock.assert_not_called()
        self.assertFalse(report["physicalAir65Ready"])
        self.assertFalse(report["virtualKeyboardReady"])

    def test_air65_fn_rule_requires_exact_device_scope(self) -> None:
        exact = {
            "description": preflight.AIR65_FN_RULE_DESCRIPTION,
            "manipulators": [
                {
                    "type": "basic",
                    "from": {"key_code": "f24"},
                    "to": [{"apple_vendor_top_case_key_code": "keyboard_fn"}],
                    "conditions": [
                        {
                            "type": "device_if",
                            "identifiers": [
                                {"vendor_id": 0x19F5, "product_id": 0x102B, "is_keyboard": True}
                            ],
                        }
                    ],
                }
            ],
        }
        broad = {
            **exact,
            "manipulators": [
                {
                    "type": "basic",
                    "from": {"key_code": "f24"},
                    "to": [{"apple_vendor_top_case_key_code": "keyboard_fn"}],
                    "conditions": [],
                }
            ],
        }

        self.assertTrue(preflight.air65_fn_rule_matches(exact))
        self.assertFalse(preflight.air65_fn_rule_matches(broad))

    def test_air65_requires_exact_official_macos_interface(self) -> None:
        device = preflight.classify_devices(
            "macOS",
            [usb(0x102B, "Air65 V3")],
            [hid(0x102B, 0x0001, 0x0000, 64, 64, product="Air65 V3")],
        )[0]

        self.assertTrue(device["controlInterfaceReady"])
        self.assertEqual(device["route"], "official-wired-control-no-flash")
        self.assertEqual(device["catalogStatus"], "verified")
        self.assertTrue(device["firmwareCompatibilityKnown"])

    def test_setup_plan_selects_the_verified_air65_no_flash_path(self) -> None:
        report = {
            "repository": {"verified": True},
            "host": {"os": "macOS", "architecture": "arm64"},
            "installation": {"installed": True, "codexHooksPresent": True},
            "keyboards": [{"productId": "102B", "controlInterfaceReady": True}],
        }

        plan = preflight.build_setup_plan(report)

        self.assertTrue(plan["eligible"])
        self.assertEqual(plan["path"], "air65-v3-macos-wired")
        self.assertEqual(plan["nextAction"], "run-light-self-test-and-real-codex-acceptance")
        self.assertIn("Never enter DFU", plan["summary"])

    def test_air75_selects_official_minimum_firmware_path(self) -> None:
        device = preflight.classify_devices(
            "macOS",
            [usb(0x1028, "Air75 V3")],
            [hid(0x1028, 0x0001, 0x0000, 64, 64, product="Air75 V3")],
        )[0]
        report = {
            "repository": {"verified": True},
            "host": {"os": "macOS", "architecture": "arm64"},
            "installation": {"installed": True, "codexHooksPresent": True},
            "keyboards": [device],
        }

        plan = preflight.build_setup_plan(report)

        self.assertTrue(device["controlInterfaceReady"])
        self.assertEqual(device["minimumFirmwareVersion"], "1.0.14.6")
        self.assertTrue(plan["eligible"])
        self.assertEqual(plan["path"], "air75-v3-macos-wired-1.0.14.6")
        self.assertEqual(
            plan["nextAction"],
            "verify-air75-firmware-and-run-real-codex-acceptance",
        )

    def test_setup_plan_makes_air96_self_test_precede_any_flash(self) -> None:
        report = {
            "repository": {"verified": True},
            "host": {"os": "macOS", "architecture": "arm64"},
            "installation": {"installed": True, "codexHooksPresent": False},
            "keyboards": [{"productId": "3266", "controlInterfaceReady": False}],
        }

        plan = preflight.build_setup_plan(report)

        self.assertTrue(plan["eligible"])
        self.assertEqual(plan["path"], "air96-v2-ansi-macos-v7")
        self.assertEqual(plan["nextAction"], "run-air96-existing-firmware-light-self-test")
        self.assertIn("Required only when", plan["conditionalFirmwareRequirements"][0])

    def test_setup_plan_stops_non_verified_hosts_and_models(self) -> None:
        windows = {
            "repository": {"verified": True},
            "host": {"os": "Windows", "architecture": "AMD64"},
            "installation": {},
            "keyboards": [{"productId": "3266", "controlInterfaceReady": True}],
        }
        testing_model = {
            "repository": {"verified": True},
            "host": {"os": "macOS", "architecture": "arm64"},
            "installation": {},
            "keyboards": [{"productId": "3246", "controlInterfaceReady": True}],
        }

        self.assertFalse(preflight.build_setup_plan(windows)["eligible"])
        self.assertFalse(preflight.build_setup_plan(testing_model)["eligible"])

    def test_air65_rejects_a_similar_but_wrong_product_string(self) -> None:
        device = preflight.classify_devices(
            "macOS",
            [usb(0x102B, "Different keyboard")],
            [hid(0x102B, 0x0001, 0x0000, 64, 64, product="Different keyboard")],
        )[0]

        self.assertFalse(device["controlInterfaceReady"])

    def test_air65_is_not_supported_on_windows(self) -> None:
        device = preflight.classify_devices(
            "Windows",
            [usb(0x102B, "Air65 V3")],
            [],
        )[0]

        self.assertFalse(device["platformSupported"])
        self.assertEqual(device["route"], "stop-unsupported-platform")

    def test_air96_macos_raw_hid_is_ready_but_firmware_remains_unknown(self) -> None:
        device = preflight.classify_devices(
            "macOS",
            [usb(0x3266, "NuPhy Air96 V2")],
            [hid(0x3266, 0xFF60, 0x0061, 32, 32)],
        )[0]

        self.assertTrue(device["controlInterfaceReady"])
        self.assertEqual(device["catalogStatus"], "verified")
        self.assertFalse(device["firmwareCompatibilityKnown"])

    def test_windows_raw_hid_length_includes_report_id(self) -> None:
        ready = preflight.classify_devices(
            "Windows",
            [usb(0x3266, "NuPhy Air96 V2")],
            [hid(0x3266, 0xFF60, 0x0061, 33, 33)],
        )[0]
        short = preflight.classify_devices(
            "Windows",
            [usb(0x3266, "NuPhy Air96 V2")],
            [hid(0x3266, 0xFF60, 0x0061, 32, 32)],
        )[0]

        self.assertTrue(ready["controlInterfaceReady"])
        self.assertFalse(short["controlInterfaceReady"])

    def test_unknown_nuphy_product_stops_as_unsupported(self) -> None:
        device = preflight.classify_devices(
            "macOS",
            [usb(0x9999, "Unknown NuPhy")],
            [],
        )[0]

        self.assertEqual(device["catalogStatus"], "unsupported")
        self.assertEqual(device["route"], "stop-unsupported-device")


if __name__ == "__main__":
    unittest.main()
