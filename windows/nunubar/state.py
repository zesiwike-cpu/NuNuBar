from __future__ import annotations

import json
import os
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Mapping

from .fileio import FileLock, atomic_write_json
from .protocol import Status, normalize_status


COMPLETION_RETENTION = 15
ACTIVE_RETENTION = 15 * 60


def application_data_directory() -> Path:
    root = os.environ.get("LOCALAPPDATA")
    if root:
        return Path(root) / "NuNuBar"
    return Path.home() / "AppData" / "Local" / "NuNuBar"


@dataclass(frozen=True)
class AgentEvent:
    provider: str
    session_id: str
    status: str

    def __post_init__(self) -> None:
        if not self.provider or not self.session_id:
            raise ValueError("provider and session_id must not be empty")
        object.__setattr__(self, "status", normalize_status(self.status))


@dataclass
class SessionRecord:
    provider: str
    session_id: str
    status: str
    updated_at: int

    @property
    def key(self) -> tuple[str, str]:
        return self.provider, self.session_id


@dataclass(frozen=True)
class Presentation:
    command: str
    next_expiration: int | None


@dataclass
class AgentState:
    sessions: dict[tuple[str, str], SessionRecord] = field(default_factory=dict)

    def apply(self, event: AgentEvent, now: int) -> None:
        self.prune(now)
        key = (event.provider, event.session_id)
        if event.status == Status.IDLE:
            self.sessions.pop(key, None)
        else:
            self.sessions[key] = SessionRecord(event.provider, event.session_id, event.status, now)

    def presentation(self, now: int) -> Presentation:
        self.prune(now)
        statuses = {record.status for record in self.sessions.values()}
        if Status.ERROR in statuses:
            command = Status.ERROR
        elif Status.WAITING in statuses:
            command = Status.WAITING
        elif Status.WORKING in statuses:
            command = Status.WORKING
        elif Status.COMPLETE in statuses:
            command = Status.COMPLETE
        else:
            command = Status.IDLE

        expirations = [self._expiration(record) for record in self.sessions.values()]
        return Presentation(command, min(expirations) if expirations else None)

    def prune(self, now: int) -> None:
        self.sessions = {
            key: record
            for key, record in self.sessions.items()
            if self._is_retained(record, now)
        }

    @staticmethod
    def _is_retained(record: SessionRecord, now: int) -> bool:
        age = max(0, now - record.updated_at)
        if record.status == Status.IDLE:
            return False
        if record.status in (Status.COMPLETE, Status.ERROR):
            return age <= COMPLETION_RETENTION
        return age <= ACTIVE_RETENTION

    @staticmethod
    def _expiration(record: SessionRecord) -> int:
        retention = COMPLETION_RETENTION if record.status in (Status.COMPLETE, Status.ERROR) else ACTIVE_RETENTION
        return record.updated_at + retention + 1

    def to_mapping(self) -> dict[str, Any]:
        records = sorted(self.sessions.values(), key=lambda item: item.key)
        return {
            "version": 1,
            "sessions": [
                {
                    "provider": record.provider,
                    "session_id": record.session_id,
                    "status": record.status,
                    "updated_at": record.updated_at,
                }
                for record in records
            ],
        }

    @classmethod
    def from_mapping(cls, value: Mapping[str, Any]) -> "AgentState":
        raw_sessions = value.get("sessions", [])
        if not isinstance(raw_sessions, Iterable) or isinstance(raw_sessions, (str, bytes, Mapping)):
            return cls()
        sessions: dict[tuple[str, str], SessionRecord] = {}
        try:
            for item in raw_sessions:
                if not isinstance(item, Mapping):
                    continue
                record = SessionRecord(
                    provider=str(item["provider"]),
                    session_id=str(item["session_id"]),
                    status=normalize_status(str(item["status"])),
                    updated_at=int(item["updated_at"]),
                )
                if record.provider and record.session_id:
                    sessions[record.key] = record
        except (KeyError, TypeError, ValueError):
            return cls()
        return cls(sessions)


class StateStore:
    def __init__(self, path: Path | None = None) -> None:
        self.path = Path(path) if path else application_data_directory() / "state.json"
        self.lock_path = self.path.with_name("state.lock")

    def load(self) -> AgentState:
        with FileLock(self.lock_path):
            return self._load_unlocked()

    def apply(self, event: AgentEvent, now: int | None = None) -> str | None:
        timestamp = int(time.time()) if now is None else int(now)
        with FileLock(self.lock_path):
            state = self._load_unlocked()
            previous = state.presentation(timestamp).command
            state.apply(event, timestamp)
            current = state.presentation(timestamp).command
            atomic_write_json(self.path, state.to_mapping())
        return current if current != previous else None

    def _load_unlocked(self) -> AgentState:
        if not self.path.exists():
            return AgentState()
        try:
            value = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            return AgentState()
        return AgentState.from_mapping(value) if isinstance(value, Mapping) else AgentState()
