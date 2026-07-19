from __future__ import annotations

import json
import re
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping

from .fileio import FileLock, atomic_write_json, atomic_write_text
from .protocol import Status
from .state import AgentEvent


CODEX_EVENTS = ("UserPromptSubmit", "PermissionRequest", "PostToolUse", "Stop")
CODEX_EVENT_STATUS = {
    "UserPromptSubmit": Status.WORKING,
    "PreToolUse": Status.WORKING,
    "PostToolUse": Status.WORKING,
    "PermissionRequest": Status.WAITING,
    "Stop": Status.COMPLETE,
}


class HookConfigurationError(RuntimeError):
    pass


def map_codex_hook(event_name: str, payload: Mapping[str, Any]) -> AgentEvent | None:
    status = CODEX_EVENT_STATUS.get(event_name)
    if status is None:
        return None
    session_id = payload.get("session_id") or payload.get("sessionId") or payload.get("conversationId")
    if not isinstance(session_id, str) or not session_id:
        raise ValueError("Codex hook payload does not contain a session ID")
    return AgentEvent("codex", session_id, status)


def command_for_hook(executable: Path, event_name: str) -> str:
    return subprocess.list2cmdline([str(executable), "hook", "codex", event_name])


def is_nunubar_hook_group(group: Any) -> bool:
    if not isinstance(group, Mapping):
        return False
    handlers = group.get("hooks")
    if not isinstance(handlers, list):
        return False
    for handler in handlers:
        if not isinstance(handler, Mapping):
            continue
        command = handler.get("command")
        if not isinstance(command, str):
            continue
        normalized = command.replace("\\", "/").lower()
        if re.search(r"(?:^|[\s\"/])nunubar(?:\.exe|_cli\.py)?(?:[\"\s]|$)", normalized) and " hook codex " in f" {normalized} ":
            return True
    return False


def merge_codex_hooks(root: Mapping[str, Any], executable: Path) -> dict[str, Any]:
    merged = dict(root)
    existing_hooks = merged.get("hooks", {})
    if not isinstance(existing_hooks, Mapping):
        raise HookConfigurationError("hooks.json 'hooks' value must be a JSON object")
    hooks = dict(existing_hooks)

    for event_name in CODEX_EVENTS:
        existing_groups = hooks.get(event_name, [])
        if not isinstance(existing_groups, list):
            raise HookConfigurationError(f"hooks.json entry for {event_name} must be an array")
        groups = [group for group in existing_groups if not is_nunubar_hook_group(group)]
        groups.append(
            {
                "hooks": [
                    {
                        "type": "command",
                        "command": command_for_hook(executable, event_name),
                        "timeout": 10,
                    }
                ]
            }
        )
        hooks[event_name] = groups
    merged["hooks"] = hooks
    return merged


def remove_codex_hooks(root: Mapping[str, Any]) -> dict[str, Any]:
    merged = dict(root)
    existing_hooks = merged.get("hooks", {})
    if not isinstance(existing_hooks, Mapping):
        raise HookConfigurationError("hooks.json 'hooks' value must be a JSON object")
    hooks = dict(existing_hooks)
    for event_name in list(hooks):
        groups = hooks[event_name]
        if not isinstance(groups, list):
            continue
        remaining = [group for group in groups if not is_nunubar_hook_group(group)]
        if remaining:
            hooks[event_name] = remaining
        else:
            hooks.pop(event_name)
    merged["hooks"] = hooks
    return merged


def enable_hooks_feature(config: str) -> str:
    lines = config.splitlines()
    features_index = next((index for index, line in enumerate(lines) if line.strip() == "[features]"), None)
    if features_index is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.extend(("[features]", "hooks = true"))
        return "\n".join(lines) + "\n"

    section_end = len(lines)
    for index in range(features_index + 1, len(lines)):
        if re.fullmatch(r"\s*\[[^]]+]\s*", lines[index]):
            section_end = index
            break
    hooks_index = next(
        (index for index in range(features_index + 1, section_end) if re.match(r"\s*hooks\s*=", lines[index])),
        None,
    )
    if hooks_index is None:
        lines.insert(features_index + 1, "hooks = true")
    else:
        lines[hooks_index] = "hooks = true"
    return "\n".join(lines) + "\n"


def install_codex(executable: Path, home: Path | None = None) -> tuple[Path, Path]:
    home = Path.home() if home is None else Path(home)
    codex_directory = home / ".codex"
    hooks_path = codex_directory / "hooks.json"
    config_path = codex_directory / "config.toml"
    codex_directory.mkdir(parents=True, exist_ok=True)

    with FileLock(codex_directory / "nunubar-install.lock"):
        original_root = _read_json_object(hooks_path)
        updated_root = merge_codex_hooks(original_root, Path(executable))
        if updated_root != original_root:
            _backup(hooks_path)
            atomic_write_json(hooks_path, updated_root)

        original_config = config_path.read_text(encoding="utf-8") if config_path.exists() else ""
        updated_config = enable_hooks_feature(original_config)
        if updated_config != original_config:
            _backup(config_path)
            atomic_write_text(config_path, updated_config)
    return hooks_path, config_path


def uninstall_codex(home: Path | None = None) -> Path:
    home = Path.home() if home is None else Path(home)
    codex_directory = home / ".codex"
    hooks_path = codex_directory / "hooks.json"
    if not hooks_path.exists():
        return hooks_path
    with FileLock(codex_directory / "nunubar-install.lock"):
        original_root = _read_json_object(hooks_path)
        updated_root = remove_codex_hooks(original_root)
        if updated_root != original_root:
            _backup(hooks_path)
            atomic_write_json(hooks_path, updated_root)
    return hooks_path


def _read_json_object(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise HookConfigurationError(f"cannot parse {path}: {error}") from error
    if not isinstance(value, dict):
        raise HookConfigurationError(f"{path} must contain a JSON object")
    return value


def _backup(path: Path) -> Path | None:
    if not path.exists():
        return None
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    destination = path.with_name(f"{path.name}.nunubar-backup-{timestamp}")
    shutil.copy2(path, destination)
    return destination
