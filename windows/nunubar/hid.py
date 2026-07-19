from __future__ import annotations

import ctypes
import os
from ctypes import wintypes
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from .fileio import FileLock
from .protocol import REPORT_SIZE, windows_output_report
from .state import application_data_directory


NUPHY_VENDOR_ID = 0x19F5
SUPPORTED_PRODUCT_IDS = frozenset({0x3255, 0x3246, 0x3266, 0x32F5})
RAW_HID_USAGE_PAGE = 0xFF60
RAW_HID_USAGE = 0x61
MODEL_NAMES = {
    0x3255: "NuPhy Air60 V2 ANSI",
    0x3246: "NuPhy Air75 V2 ANSI",
    0x3266: "NuPhy Air96 V2 ANSI",
    0x32F5: "NuPhy Halo75 V2 ANSI",
}


@dataclass(frozen=True)
class HIDDevice:
    path: str
    vendor_id: int
    product_id: int
    usage_page: int
    usage: int
    output_report_length: int
    product_name: str


def is_supported_device(
    vendor_id: int,
    product_id: int,
    usage_page: int,
    usage: int,
    output_report_length: int,
) -> bool:
    return (
        vendor_id == NUPHY_VENDOR_ID
        and product_id in SUPPORTED_PRODUCT_IDS
        and usage_page == RAW_HID_USAGE_PAGE
        and usage == RAW_HID_USAGE
        and output_report_length >= REPORT_SIZE + 1
    )


class HIDError(RuntimeError):
    pass


def validate_write_length(expected: int, actual: int) -> None:
    if actual != expected:
        raise HIDError(f"short HID WriteFile result: {actual} of {expected} bytes")


class _GUID(ctypes.Structure):
    _fields_ = [
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", ctypes.c_ubyte * 8),
    ]


class _SP_DEVICE_INTERFACE_DATA(ctypes.Structure):
    _fields_ = [
        ("cbSize", wintypes.DWORD),
        ("InterfaceClassGuid", _GUID),
        ("Flags", wintypes.DWORD),
        ("Reserved", ctypes.c_size_t),
    ]


class _HIDD_ATTRIBUTES(ctypes.Structure):
    _fields_ = [
        ("Size", wintypes.DWORD),
        ("VendorID", wintypes.WORD),
        ("ProductID", wintypes.WORD),
        ("VersionNumber", wintypes.WORD),
    ]


class _HIDP_CAPS(ctypes.Structure):
    _fields_ = [
        ("Usage", wintypes.WORD),
        ("UsagePage", wintypes.WORD),
        ("InputReportByteLength", wintypes.WORD),
        ("OutputReportByteLength", wintypes.WORD),
        ("FeatureReportByteLength", wintypes.WORD),
        ("Reserved", wintypes.WORD * 17),
        ("NumberLinkCollectionNodes", wintypes.WORD),
        ("NumberInputButtonCaps", wintypes.WORD),
        ("NumberInputValueCaps", wintypes.WORD),
        ("NumberInputDataIndices", wintypes.WORD),
        ("NumberOutputButtonCaps", wintypes.WORD),
        ("NumberOutputValueCaps", wintypes.WORD),
        ("NumberOutputDataIndices", wintypes.WORD),
        ("NumberFeatureButtonCaps", wintypes.WORD),
        ("NumberFeatureValueCaps", wintypes.WORD),
        ("NumberFeatureDataIndices", wintypes.WORD),
    ]


class _WindowsHIDAPI:
    DIGCF_PRESENT = 0x00000002
    DIGCF_DEVICEINTERFACE = 0x00000010
    ERROR_NO_MORE_ITEMS = 259
    GENERIC_WRITE = 0x40000000
    FILE_SHARE_READ = 0x00000001
    FILE_SHARE_WRITE = 0x00000002
    OPEN_EXISTING = 3
    INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value

    def __init__(self) -> None:
        if os.name != "nt":
            raise OSError("NuNuBar Win32 HID is available only on Windows")
        self.hid = ctypes.WinDLL("hid", use_last_error=True)
        self.setupapi = ctypes.WinDLL("setupapi", use_last_error=True)
        self.kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        self._configure_functions()

    def _configure_functions(self) -> None:
        self.hid.HidD_GetHidGuid.argtypes = [ctypes.POINTER(_GUID)]
        self.hid.HidD_GetAttributes.argtypes = [wintypes.HANDLE, ctypes.POINTER(_HIDD_ATTRIBUTES)]
        self.hid.HidD_GetAttributes.restype = wintypes.BOOLEAN
        self.hid.HidD_GetPreparsedData.argtypes = [wintypes.HANDLE, ctypes.POINTER(ctypes.c_void_p)]
        self.hid.HidD_GetPreparsedData.restype = wintypes.BOOLEAN
        self.hid.HidD_FreePreparsedData.argtypes = [ctypes.c_void_p]
        self.hid.HidD_FreePreparsedData.restype = wintypes.BOOLEAN
        self.hid.HidD_GetProductString.argtypes = [wintypes.HANDLE, ctypes.c_void_p, wintypes.ULONG]
        self.hid.HidD_GetProductString.restype = wintypes.BOOLEAN
        self.hid.HidP_GetCaps.argtypes = [ctypes.c_void_p, ctypes.POINTER(_HIDP_CAPS)]
        self.hid.HidP_GetCaps.restype = ctypes.c_long

        self.setupapi.SetupDiGetClassDevsW.argtypes = [
            ctypes.POINTER(_GUID), wintypes.LPCWSTR, wintypes.HWND, wintypes.DWORD
        ]
        self.setupapi.SetupDiGetClassDevsW.restype = wintypes.HANDLE
        self.setupapi.SetupDiEnumDeviceInterfaces.argtypes = [
            wintypes.HANDLE,
            wintypes.LPVOID,
            ctypes.POINTER(_GUID),
            wintypes.DWORD,
            ctypes.POINTER(_SP_DEVICE_INTERFACE_DATA),
        ]
        self.setupapi.SetupDiEnumDeviceInterfaces.restype = wintypes.BOOL
        self.setupapi.SetupDiGetDeviceInterfaceDetailW.argtypes = [
            wintypes.HANDLE,
            ctypes.POINTER(_SP_DEVICE_INTERFACE_DATA),
            wintypes.LPVOID,
            wintypes.DWORD,
            ctypes.POINTER(wintypes.DWORD),
            wintypes.LPVOID,
        ]
        self.setupapi.SetupDiGetDeviceInterfaceDetailW.restype = wintypes.BOOL
        self.setupapi.SetupDiDestroyDeviceInfoList.argtypes = [wintypes.HANDLE]
        self.setupapi.SetupDiDestroyDeviceInfoList.restype = wintypes.BOOL

        self.kernel32.CreateFileW.argtypes = [
            wintypes.LPCWSTR,
            wintypes.DWORD,
            wintypes.DWORD,
            wintypes.LPVOID,
            wintypes.DWORD,
            wintypes.DWORD,
            wintypes.HANDLE,
        ]
        self.kernel32.CreateFileW.restype = wintypes.HANDLE
        self.kernel32.WriteFile.argtypes = [
            wintypes.HANDLE,
            wintypes.LPCVOID,
            wintypes.DWORD,
            ctypes.POINTER(wintypes.DWORD),
            wintypes.LPVOID,
        ]
        self.kernel32.WriteFile.restype = wintypes.BOOL
        self.kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
        self.kernel32.CloseHandle.restype = wintypes.BOOL

    def enumerate(self) -> list[HIDDevice]:
        hid_guid = _GUID()
        self.hid.HidD_GetHidGuid(ctypes.byref(hid_guid))
        info_set = self.setupapi.SetupDiGetClassDevsW(
            ctypes.byref(hid_guid), None, None, self.DIGCF_PRESENT | self.DIGCF_DEVICEINTERFACE
        )
        if info_set == self.INVALID_HANDLE_VALUE:
            raise ctypes.WinError(ctypes.get_last_error())

        devices: list[HIDDevice] = []
        try:
            index = 0
            while True:
                interface = _SP_DEVICE_INTERFACE_DATA()
                interface.cbSize = ctypes.sizeof(interface)
                if not self.setupapi.SetupDiEnumDeviceInterfaces(
                    info_set, None, ctypes.byref(hid_guid), index, ctypes.byref(interface)
                ):
                    error = ctypes.get_last_error()
                    if error == self.ERROR_NO_MORE_ITEMS:
                        break
                    raise ctypes.WinError(error)
                index += 1
                path = self._device_path(info_set, interface)
                device = self._inspect(path)
                if device and is_supported_device(
                    device.vendor_id,
                    device.product_id,
                    device.usage_page,
                    device.usage,
                    device.output_report_length,
                ):
                    devices.append(device)
        finally:
            self.setupapi.SetupDiDestroyDeviceInfoList(info_set)
        return devices

    def _device_path(self, info_set: int, interface: _SP_DEVICE_INTERFACE_DATA) -> str:
        required = wintypes.DWORD()
        self.setupapi.SetupDiGetDeviceInterfaceDetailW(
            info_set, ctypes.byref(interface), None, 0, ctypes.byref(required), None
        )
        if required.value == 0:
            raise ctypes.WinError(ctypes.get_last_error())
        detail = ctypes.create_string_buffer(required.value)
        ctypes.cast(detail, ctypes.POINTER(wintypes.DWORD))[0] = 8 if ctypes.sizeof(ctypes.c_void_p) == 8 else 6
        if not self.setupapi.SetupDiGetDeviceInterfaceDetailW(
            info_set,
            ctypes.byref(interface),
            ctypes.cast(detail, wintypes.LPVOID),
            required,
            None,
            None,
        ):
            raise ctypes.WinError(ctypes.get_last_error())
        return ctypes.wstring_at(ctypes.addressof(detail) + ctypes.sizeof(wintypes.DWORD))

    def _open(self, path: str, desired_access: int) -> int:
        handle = self.kernel32.CreateFileW(
            path,
            desired_access,
            self.FILE_SHARE_READ | self.FILE_SHARE_WRITE,
            None,
            self.OPEN_EXISTING,
            0,
            None,
        )
        if handle == self.INVALID_HANDLE_VALUE:
            raise ctypes.WinError(ctypes.get_last_error())
        return handle

    def _inspect(self, path: str) -> HIDDevice | None:
        try:
            handle = self._open(path, 0)
        except OSError:
            return None
        try:
            attributes = _HIDD_ATTRIBUTES()
            attributes.Size = ctypes.sizeof(attributes)
            if not self.hid.HidD_GetAttributes(handle, ctypes.byref(attributes)):
                return None

            preparsed = ctypes.c_void_p()
            if not self.hid.HidD_GetPreparsedData(handle, ctypes.byref(preparsed)):
                return None
            try:
                caps = _HIDP_CAPS()
                if self.hid.HidP_GetCaps(preparsed, ctypes.byref(caps)) < 0:
                    return None
            finally:
                self.hid.HidD_FreePreparsedData(preparsed)

            product_buffer = ctypes.create_unicode_buffer(256)
            product_name = MODEL_NAMES.get(int(attributes.ProductID), "NuPhy keyboard")
            if self.hid.HidD_GetProductString(handle, product_buffer, ctypes.sizeof(product_buffer)):
                product_name = product_buffer.value or product_name
            return HIDDevice(
                path=path,
                vendor_id=int(attributes.VendorID),
                product_id=int(attributes.ProductID),
                usage_page=int(caps.UsagePage),
                usage=int(caps.Usage),
                output_report_length=int(caps.OutputReportByteLength),
                product_name=product_name,
            )
        finally:
            self.kernel32.CloseHandle(handle)

    def write(self, device: HIDDevice, payload: bytes) -> None:
        packet = windows_output_report(payload, device.output_report_length)
        handle = self._open(device.path, self.GENERIC_WRITE)
        try:
            written = wintypes.DWORD()
            buffer = ctypes.create_string_buffer(packet, len(packet))
            if not self.kernel32.WriteFile(handle, buffer, len(packet), ctypes.byref(written), None):
                raise ctypes.WinError(ctypes.get_last_error())
            validate_write_length(len(packet), int(written.value))
        finally:
            self.kernel32.CloseHandle(handle)


class HIDTransport:
    def __init__(self, lock_path: Path | None = None) -> None:
        self._api = _WindowsHIDAPI()
        self.lock_path = lock_path or application_data_directory() / "transmission.lock"

    def list_devices(self) -> list[HIDDevice]:
        return self._api.enumerate()

    def send(self, payload: bytes, devices: Iterable[HIDDevice] | None = None) -> int:
        targets = list(devices) if devices is not None else self.list_devices()
        if not targets:
            raise HIDError("no supported NuPhy QMK Raw HID keyboard is connected over USB")
        failures: list[str] = []
        delivered = 0
        with FileLock(self.lock_path):
            for device in targets:
                try:
                    self._api.write(device, payload)
                    delivered += 1
                except OSError as error:
                    failures.append(f"{device.product_name}: {error}")
        if failures:
            raise HIDError("; ".join(failures))
        return delivered


def describe_device(device: HIDDevice) -> str:
    return "\n".join(
        [
            f"Device: {device.product_name}",
            "Transport: USB",
            f"VID:PID: {device.vendor_id:04X}:{device.product_id:04X}",
            f"Usage: {device.usage_page:04X}:{device.usage:02X}",
            "Output report: 0 (QMK Raw HID)",
            f"Windows output length: {device.output_report_length} bytes (includes report ID)",
        ]
    )
