from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path
from typing import Any


class FileLock:
    def __init__(self, path: Path, *, blocking: bool = True) -> None:
        self.path = Path(path)
        self.blocking = blocking
        self._file = None
        self._handle = None
        self._overlapped = None

    def __enter__(self) -> "FileLock":
        self.path.parent.mkdir(parents=True, exist_ok=True)
        if os.name == "nt":
            self._acquire_windows()
        else:
            self._acquire_posix()
        return self

    def __exit__(self, exc_type: Any, exc: Any, traceback: Any) -> None:
        if os.name == "nt":
            self._release_windows()
        else:
            self._release_posix()

    def _acquire_posix(self) -> None:
        import fcntl

        self._file = self.path.open("a+b")
        operation = fcntl.LOCK_EX | (0 if self.blocking else fcntl.LOCK_NB)
        try:
            fcntl.flock(self._file.fileno(), operation)
        except OSError:
            self._file.close()
            self._file = None
            raise

    def _release_posix(self) -> None:
        if self._file is None:
            return
        import fcntl

        fcntl.flock(self._file.fileno(), fcntl.LOCK_UN)
        self._file.close()
        self._file = None

    def _acquire_windows(self) -> None:
        import ctypes
        from ctypes import wintypes

        class OVERLAPPED(ctypes.Structure):
            _fields_ = [
                ("Internal", ctypes.c_size_t),
                ("InternalHigh", ctypes.c_size_t),
                ("Offset", wintypes.DWORD),
                ("OffsetHigh", wintypes.DWORD),
                ("hEvent", wintypes.HANDLE),
            ]

        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.CreateFileW.argtypes = [
            wintypes.LPCWSTR,
            wintypes.DWORD,
            wintypes.DWORD,
            wintypes.LPVOID,
            wintypes.DWORD,
            wintypes.DWORD,
            wintypes.HANDLE,
        ]
        kernel32.CreateFileW.restype = wintypes.HANDLE
        kernel32.LockFileEx.argtypes = [
            wintypes.HANDLE,
            wintypes.DWORD,
            wintypes.DWORD,
            wintypes.DWORD,
            wintypes.DWORD,
            ctypes.POINTER(OVERLAPPED),
        ]
        kernel32.LockFileEx.restype = wintypes.BOOL
        kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
        kernel32.CloseHandle.restype = wintypes.BOOL

        generic_read_write = 0x80000000 | 0x40000000
        share_read_write = 0x00000001 | 0x00000002
        open_always = 4
        handle = kernel32.CreateFileW(
            str(self.path), generic_read_write, share_read_write, None, open_always, 0, None
        )
        if handle == wintypes.HANDLE(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())

        overlapped = OVERLAPPED()
        flags = 0x00000002 | (0 if self.blocking else 0x00000001)
        if not kernel32.LockFileEx(handle, flags, 0, 1, 0, ctypes.byref(overlapped)):
            error = ctypes.get_last_error()
            kernel32.CloseHandle(handle)
            if not self.blocking and error in (32, 33, 158):
                raise BlockingIOError(error, "lock is already held", str(self.path))
            raise ctypes.WinError(error)
        self._handle = handle
        self._overlapped = overlapped

    def _release_windows(self) -> None:
        if self._handle is None:
            return
        import ctypes
        from ctypes import wintypes

        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.UnlockFileEx.argtypes = [
            wintypes.HANDLE,
            wintypes.DWORD,
            wintypes.DWORD,
            wintypes.DWORD,
            ctypes.c_void_p,
        ]
        kernel32.UnlockFileEx.restype = wintypes.BOOL
        kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
        kernel32.CloseHandle.restype = wintypes.BOOL
        kernel32.UnlockFileEx(self._handle, 0, 1, 0, ctypes.byref(self._overlapped))
        kernel32.CloseHandle(self._handle)
        self._handle = None
        self._overlapped = None


def atomic_write_text(path: Path, content: str) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_path, path)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise


def atomic_write_json(path: Path, value: Any) -> None:
    atomic_write_text(path, json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
