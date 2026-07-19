[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("Install", "Uninstall", "UninstallHooks")]
    [string]$Action,

    [Parameter()]
    [string]$ReleaseZip,

    [Parameter()]
    [ValidatePattern("^[A-Fa-f0-9]{64}$")]
    [string]$ExpectedSHA256,

    [Parameter()]
    [switch]$AllowExecutableReplace,

    [Parameter()]
    [switch]$InstallCodexHooks,

    [Parameter()]
    [switch]$RegisterStartup,

    [Parameter()]
    [switch]$StartDaemon
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not $env:LOCALAPPDATA) {
    throw "LOCALAPPDATA is not available for the current user."
}

$InstallDirectory = Join-Path $env:LOCALAPPDATA "NuNuBar"
$Executable = Join-Path $InstallDirectory "NuNuBar.exe"
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunValueName = "NuNuBar"
$CodexDirectory = Join-Path $HOME ".codex"
$CodexHooksPath = Join-Path $CodexDirectory "hooks.json"
$CodexConfigPath = Join-Path $CodexDirectory "config.toml"

function Get-InstalledNuNuBarProcesses {
    foreach ($Process in @(Get-Process -Name "NuNuBar" -ErrorAction SilentlyContinue)) {
        try {
            if ($Process.Path -eq $Executable) {
                Write-Output $Process
            }
        }
        catch {
            Write-Verbose "Could not inspect NuNuBar process $($Process.Id): $($_.Exception.Message)"
        }
    }
}

function Stop-InstalledNuNuBar {
    foreach ($Process in @(Get-InstalledNuNuBarProcesses)) {
        Stop-Process -Id $Process.Id -Force
    }
}

function New-FileSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$BackupPath
    )

    $Existed = Test-Path -LiteralPath $Path -PathType Leaf
    if ($Existed) {
        Copy-Item -LiteralPath $Path -Destination $BackupPath -Force
    }
    return [pscustomobject]@{
        Path = $Path
        BackupPath = $BackupPath
        Existed = $Existed
    }
}

function Restore-FileSnapshot {
    param([Parameter(Mandatory = $true)]$Snapshot)

    if ($Snapshot.Existed) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $Snapshot.Path) -Force | Out-Null
        Copy-Item -LiteralPath $Snapshot.BackupPath -Destination $Snapshot.Path -Force
    }
    else {
        Remove-Item -LiteralPath $Snapshot.Path -Force -ErrorAction SilentlyContinue
    }
}

function Get-StartupSnapshot {
    $Existed = $false
    $Value = $null
    if (Test-Path -LiteralPath $RunKey) {
        $Properties = Get-ItemProperty -LiteralPath $RunKey
        if ($Properties.PSObject.Properties.Name -contains $RunValueName) {
            $Existed = $true
            $Value = $Properties.$RunValueName
        }
    }
    return [pscustomobject]@{
        Existed = $Existed
        Value = $Value
    }
}

function Restore-StartupSnapshot {
    param([Parameter(Mandatory = $true)]$Snapshot)

    if ($Snapshot.Existed) {
        New-Item -Path $RunKey -Force | Out-Null
        New-ItemProperty -Path $RunKey -Name $RunValueName -Value $Snapshot.Value -PropertyType String -Force | Out-Null
    }
    else {
        Remove-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
    }
}

function Assert-ReleaseHash {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Expected
    )

    $Actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    $NormalizedExpected = $Expected.ToLowerInvariant()
    if ($Actual -ne $NormalizedExpected) {
        throw "Release zip SHA-256 mismatch. Expected $NormalizedExpected but found $Actual."
    }
    Write-Host "Verified release SHA-256: $Actual"
}

function Install-NuNuBar {
    if (-not $ReleaseZip) {
        throw "Install requires -ReleaseZip with a local NuNuBar release zip."
    }
    if (-not $ExpectedSHA256) {
        throw "Install requires -ExpectedSHA256 with the hash published for this release."
    }

    $ResolvedZip = (Resolve-Path -LiteralPath $ReleaseZip).Path
    if ([System.IO.Path]::GetExtension($ResolvedZip) -ne ".zip") {
        throw "ReleaseZip must point to a .zip file."
    }
    Assert-ReleaseHash -Path $ResolvedZip -Expected $ExpectedSHA256

    $TemporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("NuNuBar-" + [guid]::NewGuid())
    $RollbackDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("NuNuBar-rollback-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $TemporaryDirectory | Out-Null
    New-Item -ItemType Directory -Path $RollbackDirectory | Out-Null

    try {
        Expand-Archive -LiteralPath $ResolvedZip -DestinationPath $TemporaryDirectory
        $Candidates = @(Get-ChildItem -Path $TemporaryDirectory -Filter "NuNuBar.exe" -File -Recurse)
        if ($Candidates.Count -ne 1) {
            throw "The release zip must contain exactly one NuNuBar.exe."
        }

        $ExecutableExists = Test-Path -LiteralPath $Executable -PathType Leaf
        if ($ExecutableExists -and -not $AllowExecutableReplace) {
            throw "NuNuBar.exe already exists. Re-run with -AllowExecutableReplace after reviewing the release hash."
        }
        $ExecutableAction = if ($ExecutableExists) { "Replace existing executable" } else { "Install executable" }
        if (-not $PSCmdlet.ShouldProcess($Executable, $ExecutableAction)) {
            Write-Warning "Executable installation was not confirmed; no changes were made."
            return
        }

        $ExecutableSnapshot = New-FileSnapshot -Path $Executable -BackupPath (Join-Path $RollbackDirectory "NuNuBar.exe")
        $HooksSnapshot = $null
        $ConfigSnapshot = $null
        $StartupSnapshot = $null
        $ExecutableAttempted = $false
        $HooksAttempted = $false
        $StartupAttempted = $false
        $WasRunning = @(Get-InstalledNuNuBarProcesses).Count -gt 0

        try {
            New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
            Stop-InstalledNuNuBar
            $ExecutableAttempted = $true
            Copy-Item -LiteralPath $Candidates[0].FullName -Destination $Executable -Force

            if ($InstallCodexHooks) {
                if ($PSCmdlet.ShouldProcess($CodexHooksPath, "Merge NuNuBar Codex hooks and enable the hooks feature")) {
                    New-Item -ItemType Directory -Path $CodexDirectory -Force | Out-Null
                    $HooksSnapshot = New-FileSnapshot -Path $CodexHooksPath -BackupPath (Join-Path $RollbackDirectory "hooks.json")
                    $ConfigSnapshot = New-FileSnapshot -Path $CodexConfigPath -BackupPath (Join-Path $RollbackDirectory "config.toml")
                    $HooksAttempted = $true
                    & $Executable install-codex
                    if ($LASTEXITCODE -ne 0) {
                        throw "NuNuBar could not install Codex hooks."
                    }
                }
            }
            else {
                Write-Host "Codex hooks were not changed. Pass -InstallCodexHooks to request that operation."
            }

            if ($RegisterStartup) {
                if ($PSCmdlet.ShouldProcess($RunKey, "Register NuNuBar daemon for current-user startup")) {
                    $StartupSnapshot = Get-StartupSnapshot
                    $StartupAttempted = $true
                    New-Item -Path $RunKey -Force | Out-Null
                    $StartupCommand = '"{0}" daemon' -f $Executable
                    New-ItemProperty -Path $RunKey -Name $RunValueName -Value $StartupCommand -PropertyType String -Force | Out-Null
                }
            }
            else {
                Write-Host "Startup registration was not changed. Pass -RegisterStartup to request that operation."
            }

            if ($StartDaemon -and $PSCmdlet.ShouldProcess($Executable, "Start NuNuBar daemon now")) {
                Start-Process -FilePath $Executable -ArgumentList "daemon" -WindowStyle Hidden
            }

            Write-Host "NuNuBar executable installed at $Executable"
            if ($HooksAttempted) {
                Write-Host "Codex hooks were added, but trust was not approved automatically. Approve them in Codex."
            }
            Write-Host "Windows v1 syncs status over USB only. Firmware flashing remains a separate manual-confirmation step."
        }
        catch {
            Write-Warning "Installation failed; restoring files and startup settings."
            Stop-InstalledNuNuBar
            if ($StartupAttempted) {
                Restore-StartupSnapshot -Snapshot $StartupSnapshot
            }
            if ($HooksAttempted) {
                Restore-FileSnapshot -Snapshot $HooksSnapshot
                Restore-FileSnapshot -Snapshot $ConfigSnapshot
            }
            if ($ExecutableAttempted) {
                Restore-FileSnapshot -Snapshot $ExecutableSnapshot
            }
            if ($WasRunning -and (Test-Path -LiteralPath $Executable -PathType Leaf)) {
                Start-Process -FilePath $Executable -ArgumentList "daemon" -WindowStyle Hidden
            }
            throw
        }
    }
    finally {
        Remove-Item -LiteralPath $TemporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $RollbackDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Uninstall-NuNuBarHooks {
    param([switch]$Required)

    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
        throw "NuNuBar.exe is not installed at $Executable."
    }
    if (-not $PSCmdlet.ShouldProcess($CodexHooksPath, "Remove only NuNuBar Codex hook entries")) {
        if ($Required) {
            throw "Hook removal was not confirmed; NuNuBar was left installed to avoid orphaned hooks."
        }
        return
    }
    & $Executable uninstall-codex
    if ($LASTEXITCODE -ne 0) {
        throw "NuNuBar could not remove its Codex hooks; the application was left installed."
    }
    Write-Host "NuNuBar Codex hooks removed. Existing user hooks were preserved."
}

function Uninstall-NuNuBar {
    if (Test-Path -LiteralPath $Executable -PathType Leaf) {
        Uninstall-NuNuBarHooks -Required
    }
    if ($PSCmdlet.ShouldProcess($RunKey, "Remove NuNuBar current-user startup registration")) {
        Remove-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
    }
    if ($PSCmdlet.ShouldProcess($InstallDirectory, "Stop NuNuBar and remove its installed files")) {
        Stop-InstalledNuNuBar
        if (Test-Path -LiteralPath $InstallDirectory) {
            Remove-Item -LiteralPath $InstallDirectory -Recurse -Force
        }
    }
    Write-Host "NuNuBar uninstall operations completed for the current user."
}

switch ($Action) {
    "Install" { Install-NuNuBar }
    "UninstallHooks" { Uninstall-NuNuBarHooks }
    "Uninstall" { Uninstall-NuNuBar }
}
