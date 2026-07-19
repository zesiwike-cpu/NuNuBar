[CmdletBinding()]
param(
    [string]$OutputDirectory = "windows\release"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$WindowsDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepositoryRoot = Split-Path -Parent $WindowsDirectory
$OutputPath = Join-Path $RepositoryRoot $OutputDirectory
$ZipPath = Join-Path $OutputPath "NuNuBar-windows-x64.zip"

Push-Location $WindowsDirectory
try {
    python -m pip install --requirement requirements-build.txt
    if ($LASTEXITCODE -ne 0) {
        throw "Installing PyInstaller failed with exit code $LASTEXITCODE"
    }
    python -m PyInstaller --noconfirm --clean NuNuBar.spec
    if ($LASTEXITCODE -ne 0) {
        throw "PyInstaller failed with exit code $LASTEXITCODE"
    }

    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    if (Test-Path $ZipPath) {
        Remove-Item $ZipPath -Force
    }
    Compress-Archive -Path (Join-Path $WindowsDirectory "dist\NuNuBar.exe") -DestinationPath $ZipPath
    $Hash = Get-FileHash -Algorithm SHA256 $ZipPath
    Write-Host "Created $ZipPath"
    Write-Host "SHA-256: $($Hash.Hash.ToLowerInvariant())"
}
finally {
    Pop-Location
}
