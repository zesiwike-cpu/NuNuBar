import json
import tempfile
import unittest
from pathlib import Path

from nunubar.hooks import (
    CODEX_EVENTS,
    install_codex,
    is_nunubar_hook_group,
    map_codex_hook,
    merge_codex_hooks,
    uninstall_codex,
)


class HookTests(unittest.TestCase):
    def test_codex_event_mapping_matches_swift(self) -> None:
        payload = {"session_id": "codex-1"}
        expected = {
            "UserPromptSubmit": "working",
            "PreToolUse": "working",
            "PostToolUse": "working",
            "PermissionRequest": "waiting",
            "Stop": "complete",
        }
        for event_name, status in expected.items():
            event = map_codex_hook(event_name, payload)
            self.assertIsNotNone(event)
            self.assertEqual(event.status, status)
        self.assertIsNone(map_codex_hook("Unrelated", {}))

    def test_known_hook_requires_session_id(self) -> None:
        with self.assertRaises(ValueError):
            map_codex_hook("Stop", {})

    def test_merge_is_idempotent_and_preserves_user_data(self) -> None:
        executable = Path("/Users/example/App Data/NuNuBar.exe")
        original = {
            "keep": {"value": True},
            "hooks": {
                "Stop": [{"hooks": [{"type": "command", "command": "existing-stop"}]}],
                "Custom": [{"hooks": [{"type": "command", "command": "custom-hook"}]}],
            },
        }
        once = merge_codex_hooks(original, executable)
        twice = merge_codex_hooks(once, executable)
        self.assertEqual(once, twice)
        self.assertEqual(once["keep"], {"value": True})
        self.assertEqual(once["hooks"]["Custom"], original["hooks"]["Custom"])
        for event_name in CODEX_EVENTS:
            groups = once["hooks"][event_name]
            self.assertEqual(sum(is_nunubar_hook_group(group) for group in groups), 1)
        self.assertEqual(len(once["hooks"]["Stop"]), 2)

    def test_install_backs_up_changes_without_approving_trust(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            codex = home / ".codex"
            codex.mkdir()
            hooks_path = codex / "hooks.json"
            hooks_path.write_text(
                json.dumps({"hooks": {"Stop": [{"hooks": [{"command": "keep-me"}]}]}}),
                encoding="utf-8",
            )
            config_path = codex / "config.toml"
            trust = '[hooks.state."keep"]\ntrusted_hash = "sha256:user-value"\n'
            config_path.write_text(trust, encoding="utf-8")

            executable = home / "NuNuBar.exe"
            install_codex(executable, home)
            first_hooks_backups = list(codex.glob("hooks.json.nunubar-backup-*"))
            first_config_backups = list(codex.glob("config.toml.nunubar-backup-*"))
            self.assertEqual(len(first_hooks_backups), 1)
            self.assertEqual(len(first_config_backups), 1)
            updated_config = config_path.read_text(encoding="utf-8")
            self.assertIn("hooks = true", updated_config)
            self.assertIn('trusted_hash = "sha256:user-value"', updated_config)

            install_codex(executable, home)
            self.assertEqual(len(list(codex.glob("hooks.json.nunubar-backup-*"))), 1)
            self.assertEqual(len(list(codex.glob("config.toml.nunubar-backup-*"))), 1)

            uninstall_codex(home)
            root = json.loads(hooks_path.read_text(encoding="utf-8"))
            commands = [
                handler.get("command")
                for groups in root["hooks"].values()
                for group in groups
                for handler in group.get("hooks", [])
            ]
            self.assertIn("keep-me", commands)
            self.assertFalse(any(command and "hook codex" in command for command in commands))


if __name__ == "__main__":
    unittest.main()
