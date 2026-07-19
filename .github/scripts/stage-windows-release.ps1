[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[0-9A-Za-z._-]+$")]
    [string]$Version,

    [string]$OutputDirectory = "windows\release\github"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$OutputRoot = Join-Path $RepositoryRoot $OutputDirectory
$ExecutableSource = Join-Path $RepositoryRoot "windows\dist\NuNuBar.exe"
$SetupSource = Join-Path $RepositoryRoot "script\setup-windows.ps1"
$FirmwareSource = Join-Path $RepositoryRoot "Sources\AgentLightApp\Resources\Firmware"
$ManifestSource = Join-Path $FirmwareSource "manifest.json"
$BundleName = "NuNuBar-Windows-$Version-x64"
$BundleRoot = Join-Path $OutputRoot $BundleName
$ZipPath = Join-Path $OutputRoot "$BundleName.zip"
$ExePath = Join-Path $OutputRoot "$BundleName.exe"

foreach ($RequiredPath in @($ExecutableSource, $SetupSource, $ManifestSource)) {
    if (-not (Test-Path -LiteralPath $RequiredPath -PathType Leaf)) {
        throw "Required release input is missing: $RequiredPath"
    }
}

$Catalog = Get-Content -LiteralPath $ManifestSource -Raw | ConvertFrom-Json
if ($Catalog.schemaVersion -ne 2) {
    throw "Unsupported firmware catalog schema: $($Catalog.schemaVersion)"
}
$Firmwares = @($Catalog.firmwares)
if ($Firmwares.Count -ne 4) {
    throw "The Windows release must contain exactly four firmware catalog entries."
}

foreach ($Firmware in $Firmwares) {
    $FirmwarePath = Join-Path $FirmwareSource $Firmware.firmwareFile
    if (-not (Test-Path -LiteralPath $FirmwarePath -PathType Leaf)) {
        throw "Catalog firmware is missing: $($Firmware.firmwareFile)"
    }
    $File = Get-Item -LiteralPath $FirmwarePath
    if ($File.Length -ne [long]$Firmware.firmwareSize) {
        throw "Firmware size mismatch for $($Firmware.firmwareFile)"
    }
    $ActualHash = (Get-FileHash -LiteralPath $FirmwarePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($ActualHash -ne [string]$Firmware.firmwareSHA256) {
        throw "Firmware SHA-256 mismatch for $($Firmware.firmwareFile)"
    }
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
Remove-Item -LiteralPath $BundleRoot -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ZipPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $ExePath -Force -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Path (Join-Path $BundleRoot "catalog") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $BundleRoot "firmware") -Force | Out-Null
Copy-Item -LiteralPath $ExecutableSource -Destination (Join-Path $BundleRoot "NuNuBar.exe")
Copy-Item -LiteralPath $SetupSource -Destination (Join-Path $BundleRoot "setup-windows.ps1")
Copy-Item -LiteralPath $ManifestSource -Destination (Join-Path $BundleRoot "catalog\manifest.json")
Copy-Item -LiteralPath (Join-Path $RepositoryRoot "windows\README.md") -Destination (Join-Path $BundleRoot "WINDOWS.md")
Copy-Item -LiteralPath (Join-Path $RepositoryRoot "docs\CODEX_SETUP.md") -Destination (Join-Path $BundleRoot "CODEX_SETUP.md")
Copy-Item -LiteralPath (Join-Path $RepositoryRoot "docs\NBAR_PROTOCOL.md") -Destination (Join-Path $BundleRoot "NBAR_PROTOCOL.md")
Copy-Item -LiteralPath (Join-Path $RepositoryRoot "LICENSE") -Destination (Join-Path $BundleRoot "LICENSE")

foreach ($Firmware in $Firmwares) {
    Copy-Item -LiteralPath (Join-Path $FirmwareSource $Firmware.firmwareFile) -Destination (Join-Path $BundleRoot "firmware\$($Firmware.firmwareFile)")
}

Copy-Item -LiteralPath $ExecutableSource -Destination $ExePath
Compress-Archive -Path (Join-Path $BundleRoot "*") -DestinationPath $ZipPath

foreach ($Artifact in @($ExePath, $ZipPath)) {
    $Hash = (Get-FileHash -LiteralPath $Artifact -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host "Created $Artifact"
    Write-Host "SHA-256: $Hash"
}
