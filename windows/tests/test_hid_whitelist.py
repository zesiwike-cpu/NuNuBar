import unittest

from nunubar.hid import HIDError, SUPPORTED_PRODUCT_IDS, is_supported_device, validate_write_length


class HIDWhitelistTests(unittest.TestCase):
    def test_all_four_models_are_allowed(self) -> None:
        self.assertEqual(SUPPORTED_PRODUCT_IDS, {0x3255, 0x3246, 0x3266, 0x32F5})
        for product_id in SUPPORTED_PRODUCT_IDS:
            self.assertTrue(is_supported_device(0x19F5, product_id, 0xFF60, 0x61, 33))

    def test_vendor_product_usage_and_length_are_strict(self) -> None:
        self.assertFalse(is_supported_device(0x19F4, 0x3266, 0xFF60, 0x61, 33))
        self.assertFalse(is_supported_device(0x19F5, 0x3299, 0xFF60, 0x61, 33))
        self.assertFalse(is_supported_device(0x19F5, 0x3266, 0xFF61, 0x61, 33))
        self.assertFalse(is_supported_device(0x19F5, 0x3266, 0xFF60, 0x62, 33))
        self.assertFalse(is_supported_device(0x19F5, 0x3266, 0xFF60, 0x61, 32))

    def test_writefile_must_report_the_full_prefixed_length(self) -> None:
        validate_write_length(33, 33)
        with self.assertRaises(HIDError):
            validate_write_length(33, 32)


if __name__ == "__main__":
    unittest.main()
