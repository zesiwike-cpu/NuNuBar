# NuNuBar for Windows

This directory contains the Python 3.11 source for the Windows USB status client. The PyInstaller build is a single `NuNuBar.exe` and does not require Python on the target PC.

## Scope

- Codex hook state aggregation for concurrent sessions.
- USB Raw HID status delivery to NuPhy Air60 V2 ANSI, Air75 V2 ANSI, Air96 V2 ANSI, and Halo75 V2 ANSI.
- NBAR protocol v1, v2, and v3, with v3 used by the daemon.
- Current-user installation and startup registration.

Windows v1 does **not** flash firmware and does not control Bluetooth or 2.4G connections. A keyboard must already have the matching NuNuBar-compatible firmware. Firmware flashing remains a separate operation that requires exact model confirmation, a recovery image, DFU mode, and explicit user approval.

## Build on Windows

Use Python 3.11 on a Windows x64 GitHub Actions runner or development PC:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows\build-release.ps1
```

The build script installs the pinned PyInstaller build dependency, creates `NuNuBar.exe`, and packages `windows\release\NuNuBar-windows-x64.zip`. Runtime code uses only the Python standard library and Win32 APIs through `ctypes`.

Equivalent GitHub Actions steps are:

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: "3.11"
- shell: pwsh
  run: .\windows\build-release.ps1
```

## Install

The setup script accepts only a local release zip and requires the SHA-256 published with that exact release. Do not calculate `ExpectedSHA256` from the downloaded file and then trust that value; obtain it from the release page or another authenticated release channel.

```powershell
$PublishedSHA256 = "<64-character SHA-256 published for this release>"
.\script\setup-windows.ps1 Install `
  -ReleaseZip .\windows\release\NuNuBar-windows-x64.zip `
  -ExpectedSHA256 $PublishedSHA256 `
  -InstallCodexHooks `
  -RegisterStartup `
  -StartDaemon
```

The script prompts separately before installing or replacing the executable, writing Codex Hooks, registering startup, and starting the daemon. `-InstallCodexHooks` and `-RegisterStartup` are independent explicit requests; omitting either leaves that part of the system unchanged. Replacing an existing executable additionally requires `-AllowExecutableReplace`.

Installation targets `%LOCALAPPDATA%\NuNuBar`. Existing JSON hooks are retained and changed configuration files are backed up. The installer also keeps transaction snapshots of the executable, `hooks.json`, `config.toml`, and the current-user startup value, and restores them if a later installation step fails. Codex hook trust is never approved automatically; the user must review and approve it in Codex.

Removal is always explicit:

```powershell
.\script\setup-windows.ps1 UninstallHooks
.\script\setup-windows.ps1 Uninstall
```

## CLI

```text
NuNuBar.exe describe
NuNuBar.exe send working
NuNuBar.exe hook codex UserPromptSubmit
NuNuBar.exe event codex waiting session-id
NuNuBar.exe install-codex
NuNuBar.exe uninstall-codex
NuNuBar.exe daemon
```

Hook payloads are JSON objects read from standard input. The daemon polls the locked atomic state file and resends after a supported keyboard reconnects.

## Tests

The pure protocol, state, hook merge, and whitelist tests also run on macOS or Linux:

```bash
PYTHONPATH=windows python3 -m unittest discover -s windows/tests -v
```

Win32 SetupAPI enumeration and physical HID output require a Windows PC and a supported keyboard for final verification.
