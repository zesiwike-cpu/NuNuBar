from __future__ import annotations

import json
import signal
import threading
import time
from pathlib import Path
from typing import Any, Mapping

from .fileio import FileLock
from .hid import HIDError, HIDTransport
from .protocol import DEFAULT_PALETTE, Palette, encode_report
from .state import StateStore, application_data_directory


class DaemonAlreadyRunning(RuntimeError):
    pass


def load_palette(path: Path | None = None) -> Palette:
    palette_path = path or application_data_directory() / "palette.json"
    if not palette_path.exists():
        return DEFAULT_PALETTE
    try:
        value: Any = json.loads(palette_path.read_text(encoding="utf-8"))
        return Palette.from_mapping(value) if isinstance(value, Mapping) else DEFAULT_PALETTE
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, KeyError, TypeError, ValueError):
        return DEFAULT_PALETTE


def run_daemon(poll_interval: float = 0.2, verbose: bool = False) -> None:
    if poll_interval < 0.05:
        raise ValueError("poll interval must be at least 0.05 seconds")
    data_directory = application_data_directory()
    stop_event = threading.Event()
    for signal_number in (signal.SIGINT, signal.SIGTERM):
        try:
            signal.signal(signal_number, lambda _number, _frame: stop_event.set())
        except (OSError, ValueError):
            pass

    try:
        daemon_lock = FileLock(data_directory / "daemon.lock", blocking=False)
        daemon_lock.__enter__()
    except BlockingIOError as error:
        raise DaemonAlreadyRunning("NuNuBar daemon is already running") from error

    try:
        state_store = StateStore()
        transport = HIDTransport()
        last_report: bytes | None = None
        last_devices: tuple[str, ...] = ()
        next_retry = 0.0

        while not stop_event.is_set():
            now = time.time()
            state = state_store.load()
            command = state.presentation(int(now)).command
            report = encode_report(command, load_palette(), version=3)
            try:
                devices = transport.list_devices()
                device_signature = tuple(sorted(device.path for device in devices))
                should_send = bool(devices) and (
                    report != last_report or device_signature != last_devices or now >= next_retry
                )
                if should_send:
                    transport.send(report, devices)
                    last_report = report
                    last_devices = device_signature
                    next_retry = float("inf")
                    if verbose:
                        print(f"NuNuBar: sent {command} to {len(devices)} keyboard(s)", flush=True)
                elif not devices:
                    last_devices = ()
                    next_retry = now + 1.0
            except (HIDError, OSError) as error:
                next_retry = now + 1.0
                if verbose:
                    print(f"NuNuBar: {error}", flush=True)
            stop_event.wait(poll_interval)
    finally:
        daemon_lock.__exit__(None, None, None)
