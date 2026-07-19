from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
from typing import Any, Mapping


REPORT_SIZE = 32
REPORT_ID = 0
MAGIC = b"NBAR"
SET_STATUS_COMMAND = 0x01


class Status(str):
    IDLE = "idle"
    WORKING = "working"
    WAITING = "waiting"
    COMPLETE = "complete"
    ERROR = "error"

    ALL = frozenset({IDLE, WORKING, WAITING, COMPLETE, ERROR})


class Effect(IntEnum):
    SOLID = 0x00
    BREATHE = 0x01
    BLINK = 0x02


STATUS_VALUES = {
    Status.IDLE: 0x00,
    Status.WORKING: 0x01,
    Status.WAITING: 0x04,
    Status.ERROR: 0x04,
    Status.COMPLETE: 0x05,
}


@dataclass(frozen=True)
class RGBColor:
    red: int
    green: int
    blue: int

    def __post_init__(self) -> None:
        for component in (self.red, self.green, self.blue):
            if not isinstance(component, int) or not 0 <= component <= 255:
                raise ValueError("RGB components must be integers from 0 through 255")

    @classmethod
    def from_mapping(cls, value: Mapping[str, Any]) -> "RGBColor":
        return cls(int(value["red"]), int(value["green"]), int(value["blue"]))


@dataclass(frozen=True)
class Palette:
    idle: RGBColor
    working: RGBColor
    waiting: RGBColor
    complete: RGBColor
    idle_effect: Effect = Effect.SOLID
    working_effect: Effect = Effect.BREATHE
    waiting_effect: Effect = Effect.BLINK
    complete_effect: Effect = Effect.SOLID

    def color_for(self, status: str) -> RGBColor:
        status = normalize_status(status)
        if status == Status.IDLE:
            return self.idle
        if status == Status.WORKING:
            return self.working
        if status in (Status.WAITING, Status.ERROR):
            return self.waiting
        return self.complete

    def effect_for(self, status: str) -> Effect:
        status = normalize_status(status)
        if status == Status.IDLE:
            return self.idle_effect
        if status == Status.WORKING:
            return self.working_effect
        if status in (Status.WAITING, Status.ERROR):
            return self.waiting_effect
        return self.complete_effect

    @classmethod
    def from_mapping(cls, value: Mapping[str, Any]) -> "Palette":
        defaults = DEFAULT_PALETTE

        def color(key: str) -> RGBColor:
            item = value.get(key)
            return RGBColor.from_mapping(item) if isinstance(item, Mapping) else getattr(defaults, key)

        def effect(key: str, default: Effect) -> Effect:
            item = value.get(key)
            if item is None:
                return default
            if isinstance(item, str):
                names = {"solid": Effect.SOLID, "breathe": Effect.BREATHE, "blink": Effect.BLINK}
                if item not in names:
                    raise ValueError(f"unknown effect: {item}")
                return names[item]
            return Effect(int(item))

        return cls(
            idle=color("idle"),
            working=color("working"),
            waiting=color("waiting"),
            complete=color("complete"),
            idle_effect=effect("idleEffect", defaults.idle_effect),
            working_effect=effect("workingEffect", defaults.working_effect),
            waiting_effect=effect("waitingEffect", defaults.waiting_effect),
            complete_effect=effect("completeEffect", defaults.complete_effect),
        )


DEFAULT_PALETTE = Palette(
    idle=RGBColor(0, 0, 0),
    working=RGBColor(252, 84, 0),
    waiting=RGBColor(255, 0, 0),
    complete=RGBColor(0, 255, 0),
)


def normalize_status(status: str) -> str:
    value = str(status).lower()
    if value not in Status.ALL:
        raise ValueError(f"unknown status: {status}")
    return value


def xor_checksum(data: bytes | bytearray) -> int:
    checksum = 0
    for value in data:
        checksum ^= value
    return checksum


def encode_report(status: str, palette: Palette = DEFAULT_PALETTE, version: int = 3) -> bytes:
    status = normalize_status(status)
    if version not in (1, 2, 3):
        raise ValueError("protocol version must be 1, 2, or 3")

    report = bytearray(REPORT_SIZE)
    report[0:4] = MAGIC
    report[4] = version
    report[5] = SET_STATUS_COMMAND
    report[6] = STATUS_VALUES[status]

    if version == 1:
        report[7] = xor_checksum(report[0:7])
        return bytes(report)

    color = palette.color_for(status)
    report[7:10] = bytes((color.red, color.green, color.blue))
    if version == 2:
        report[10] = xor_checksum(report[0:10])
        return bytes(report)

    report[10] = int(palette.effect_for(status))
    report[11] = xor_checksum(report[0:11])
    return bytes(report)


def windows_output_report(payload: bytes, output_report_length: int = REPORT_SIZE + 1) -> bytes:
    """Prefix report ID 0 as required by the Windows HID WriteFile contract."""
    if len(payload) != REPORT_SIZE:
        raise ValueError(f"NuNuBar payload must contain exactly {REPORT_SIZE} bytes")
    if output_report_length < REPORT_SIZE + 1:
        raise ValueError("Windows HID output report is too short for report ID 0 plus payload")
    return bytes((REPORT_ID,)) + payload + bytes(output_report_length - REPORT_SIZE - 1)
