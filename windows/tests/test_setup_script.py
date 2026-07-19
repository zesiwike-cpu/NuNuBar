import unittest
from pathlib import Path


class SetupScriptSafetyTests(unittest.TestCase):
    def test_install_requires_hash_and_separate_explicit_operations(self) -> None:
        repository = Path(__file__).resolve().parents[2]
        script = (repository / "script" / "setup-windows.ps1").read_text(encoding="utf-8")
        for required in (
            "ExpectedSHA256",
            "Get-FileHash -LiteralPath $Path -Algorithm SHA256",
            "AllowExecutableReplace",
            "InstallCodexHooks",
            "RegisterStartup",
            "ShouldProcess",
            "Restore-FileSnapshot",
            "Restore-StartupSnapshot",
        ):
            self.assertIn(required, script)


if __name__ == "__main__":
    unittest.main()
