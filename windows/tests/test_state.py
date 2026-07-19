import json
import tempfile
import unittest
from pathlib import Path

from nunubar.state import (
    ACTIVE_RETENTION,
    COMPLETION_RETENTION,
    AgentEvent,
    AgentState,
    StateStore,
)


class StateTests(unittest.TestCase):
    def test_working_beats_complete_across_sessions(self) -> None:
        state = AgentState()
        state.apply(AgentEvent("codex", "one", "working"), 100)
        state.apply(AgentEvent("codex", "two", "complete"), 101)
        self.assertEqual(state.presentation(101).command, "working")

    def test_error_waiting_working_complete_priority(self) -> None:
        state = AgentState()
        state.apply(AgentEvent("codex", "working", "working"), 100)
        state.apply(AgentEvent("codex", "waiting", "waiting"), 101)
        self.assertEqual(state.presentation(101).command, "waiting")
        state.apply(AgentEvent("codex", "error", "error"), 102)
        self.assertEqual(state.presentation(102).command, "error")

    def test_idle_removes_only_its_session(self) -> None:
        state = AgentState()
        state.apply(AgentEvent("codex", "one", "working"), 100)
        state.apply(AgentEvent("codex", "two", "working"), 100)
        state.apply(AgentEvent("codex", "one", "idle"), 101)
        self.assertNotIn(("codex", "one"), state.sessions)
        self.assertIn(("codex", "two"), state.sessions)

    def test_completion_and_error_expire_after_15_seconds(self) -> None:
        for status in ("complete", "error"):
            state = AgentState()
            state.apply(AgentEvent("codex", status, status), 200)
            self.assertEqual(state.presentation(200 + COMPLETION_RETENTION).command, status)
            self.assertEqual(state.presentation(200 + COMPLETION_RETENTION + 1).command, "idle")

    def test_active_states_expire_and_report_exact_deadline(self) -> None:
        state = AgentState()
        state.apply(AgentEvent("codex", "active", "working"), 100)
        presentation = state.presentation(101)
        self.assertEqual(presentation.next_expiration, 100 + ACTIVE_RETENTION + 1)
        self.assertEqual(state.presentation(100 + ACTIVE_RETENTION + 1).command, "idle")

    def test_store_writes_atomic_json_and_preserves_sessions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            store = StateStore(path)
            self.assertEqual(store.apply(AgentEvent("codex", "one", "working"), 100), "working")
            self.assertIsNone(store.apply(AgentEvent("codex", "two", "working"), 101))
            value = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(value["version"], 1)
            self.assertEqual(len(value["sessions"]), 2)
            self.assertEqual(store.load().presentation(101).command, "working")


if __name__ == "__main__":
    unittest.main()
