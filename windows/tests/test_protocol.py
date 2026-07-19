import unittest

from nunubar.protocol import (
    DEFAULT_PALETTE,
    Effect,
    Palette,
    RGBColor,
    encode_report,
    windows_output_report,
    xor_checksum,
)


class ProtocolTests(unittest.TestCase):
    def test_default_palette_matches_swift(self) -> None:
        self.assertEqual(DEFAULT_PALETTE.idle, RGBColor(0, 0, 0))
        self.assertEqual(DEFAULT_PALETTE.working, RGBColor(252, 84, 0))
        self.assertEqual(DEFAULT_PALETTE.waiting, RGBColor(255, 0, 0))
        self.assertEqual(DEFAULT_PALETTE.complete, RGBColor(0, 255, 0))
        self.assertEqual(DEFAULT_PALETTE.idle_effect, Effect.SOLID)
        self.assertEqual(DEFAULT_PALETTE.working_effect, Effect.BREATHE)
        self.assertEqual(DEFAULT_PALETTE.waiting_effect, Effect.BLINK)
        self.assertEqual(DEFAULT_PALETTE.complete_effect, Effect.SOLID)

    def test_v1_report_is_exactly_swift_compatible(self) -> None:
        report = encode_report("working", version=1)
        self.assertEqual(len(report), 32)
        self.assertEqual(report[:8], bytes((0x4E, 0x42, 0x41, 0x52, 0x01, 0x01, 0x01, 0x1E)))
        self.assertEqual(report[8:], bytes(24))

    def test_v2_report_is_exactly_swift_compatible(self) -> None:
        report = encode_report("working", version=2)
        self.assertEqual(
            report[:11],
            bytes((0x4E, 0x42, 0x41, 0x52, 0x02, 0x01, 0x01, 0xFC, 0x54, 0x00, 0xB5)),
        )
        self.assertEqual(report[11:], bytes(21))

    def test_v3_report_contains_color_effect_and_checksum(self) -> None:
        report = encode_report("working", version=3)
        self.assertEqual(
            report[:12],
            bytes((0x4E, 0x42, 0x41, 0x52, 0x03, 0x01, 0x01, 0xFC, 0x54, 0x00, 0x01, 0xB5)),
        )
        self.assertEqual(report[11], xor_checksum(report[:11]))
        self.assertEqual(report[12:], bytes(20))

    def test_status_values_and_error_palette_match_swift(self) -> None:
        self.assertEqual(encode_report("idle")[6], 0x00)
        self.assertEqual(encode_report("working")[6], 0x01)
        self.assertEqual(encode_report("waiting")[6], 0x04)
        self.assertEqual(encode_report("error")[6], 0x04)
        self.assertEqual(encode_report("complete")[6], 0x05)
        self.assertEqual(encode_report("error")[7:11], encode_report("waiting")[7:11])

    def test_custom_palette_uses_swift_json_field_names(self) -> None:
        palette = Palette.from_mapping(
            {
                "idle": {"red": 1, "green": 2, "blue": 3},
                "working": {"red": 4, "green": 5, "blue": 6},
                "waiting": {"red": 7, "green": 8, "blue": 9},
                "complete": {"red": 10, "green": 11, "blue": 12},
                "workingEffect": "solid",
            }
        )
        self.assertEqual(encode_report("working", palette)[7:11], bytes((4, 5, 6, 0)))

    def test_windows_report_id_zero_is_prefixed(self) -> None:
        payload = encode_report("complete")
        packet = windows_output_report(payload, 35)
        self.assertEqual(len(packet), 35)
        self.assertEqual(packet[0], 0)
        self.assertEqual(packet[1:33], payload)
        self.assertEqual(packet[33:], b"\x00\x00")


if __name__ == "__main__":
    unittest.main()
