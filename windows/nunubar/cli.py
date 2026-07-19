from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Sequence

from . import __version__
from .daemon import DaemonAlreadyRunning, run_daemon
from .hid import HIDTransport, describe_device
from .hooks import install_codex, map_codex_hook, uninstall_codex
from .protocol import DEFAULT_PALETTE, Status, encode_report
from .state import AgentEvent, StateStore


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="NuNuBar",
        description="Sync Codex status to supported NuPhy keyboards over USB Raw HID.",
    )
    parser.add_argument("--version", action="version", version=f"NuNuBar {__version__}")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("describe", help="list compatible USB keyboards")

    send = subparsers.add_parser("send", help="send one light state immediately")
    send.add_argument("status", choices=sorted(Status.ALL))
    send.add_argument("--protocol", type=int, choices=(1, 2, 3), default=3)

    hook = subparsers.add_parser("hook", help="consume an agent hook payload from stdin")
    hook.add_argument("provider", choices=("codex",))
    hook.add_argument("event_name")

    event = subparsers.add_parser("event", help="record an explicit session state")
    event.add_argument("provider")
    event.add_argument("status", choices=sorted(Status.ALL))
    event.add_argument("session_id")

    install = subparsers.add_parser("install-codex", help="merge NuNuBar into Codex hooks.json")
    install.add_argument("--home", type=Path)
    install.add_argument("--executable", type=Path)

    uninstall = subparsers.add_parser("uninstall-codex", help="remove only NuNuBar Codex hooks")
    uninstall.add_argument("--home", type=Path)

    daemon = subparsers.add_parser("daemon", help="run the background USB status synchronizer")
    daemon.add_argument("--poll-interval", type=float, default=0.2)
    daemon.add_argument("--verbose", action="store_true")
    return parser


def current_executable() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve()
    return Path(sys.argv[0]).resolve()


def main(arguments: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(arguments)
    try:
        if args.command == "describe":
            devices = HIDTransport().list_devices()
            if not devices:
                print("No supported NuPhy QMK Raw HID keyboard is connected over USB.")
                return 1
            print("\n\n".join(describe_device(device) for device in devices))
            return 0

        if args.command == "send":
            payload = encode_report(args.status, DEFAULT_PALETTE, version=args.protocol)
            delivered = HIDTransport().send(payload)
            print(f"Sent {args.status} using NBAR v{args.protocol} to {delivered} keyboard(s).")
            return 0

        if args.command == "hook":
            payload = json.load(sys.stdin)
            if not isinstance(payload, dict):
                raise ValueError("hook payload must be a JSON object")
            event = map_codex_hook(args.event_name, payload)
            if event is not None:
                StateStore().apply(event)
            return 0

        if args.command == "event":
            StateStore().apply(AgentEvent(args.provider, args.session_id, args.status))
            return 0

        if args.command == "install-codex":
            executable = (args.executable or current_executable()).resolve()
            hooks_path, _ = install_codex(executable, args.home)
            print(f"Installed NuNuBar hooks in {hooks_path}")
            print("Codex trust was not approved automatically. Review and approve the hooks in Codex.")
            return 0

        if args.command == "uninstall-codex":
            hooks_path = uninstall_codex(args.home)
            print(f"Removed NuNuBar entries from {hooks_path}")
            return 0

        if args.command == "daemon":
            try:
                run_daemon(args.poll_interval, args.verbose)
            except DaemonAlreadyRunning:
                return 0
            return 0
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as error:
        print(f"NuNuBar: {error}", file=sys.stderr)
        return 1
    parser.error("unknown command")
    return 2
