# Full production build of Kiss VPN.
# Produces a self-contained directory tree under .\dist\<config> that the
# Inno Setup script picks up.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\build.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Debug
#   powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -SkipInstaller

[CmdletBinding()]
param(
    [switch]$DebugBuild,
    [switch]$SkipInstaller
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    $cfg     = if ($DebugBuild) { 'Debug'   } else { 'Release' }
    $fluCfg  = if ($DebugBuild) { '--debug' } else { '--release' }
    $dist    = Join-Path $repoRoot "dist\$cfg"
    $flutter = Get-Command flutter -ErrorAction Stop | Select-Object -ExpandProperty Source
    $dotnet  = $null
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        $dotnet = (Get-Command dotnet).Source
    } elseif (Test-Path "C:\Program Files\dotnet\dotnet.exe") {
        $dotnet = "C:\Program Files\dotnet\dotnet.exe"
    } else {
        throw "dotnet not found in PATH or C:\Program Files\dotnet"
    }

    Write-Host "==> Cleaning $dist"
    if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
    New-Item -ItemType Directory -Path $dist | Out-Null

    Write-Host "==> Building Flutter UI ($cfg)"
    Push-Location (Join-Path $repoRoot 'kiss_vpn')
    try {
        & $flutter pub get
        & $flutter build windows $fluCfg
        if ($LASTEXITCODE -ne 0) { throw "flutter build failed ($LASTEXITCODE)" }
    } finally { Pop-Location }
    $fluOut = Join-Path $repoRoot "kiss_vpn\build\windows\x64\runner\$cfg"
    Copy-Item -Path "$fluOut\*" -Destination $dist -Recurse -Force

    Write-Host "==> Building Helper Service ($cfg)"
    Push-Location (Join-Path $repoRoot 'kiss_vpn_helper')
    try {
        & $dotnet publish -c $cfg -r win-x64 --self-contained `
            -p:PublishSingleFile=true -nologo --verbosity:minimal
        if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed ($LASTEXITCODE)" }
    } finally { Pop-Location }
    $helpOut = Join-Path $repoRoot "kiss_vpn_helper\bin\$cfg\net8.0-windows\win-x64\publish"
    Copy-Item "$helpOut\KissVPNHelper.exe" -Destination $dist -Force

    Write-Host "==> Staging core, geo, wintun"
    Copy-Item "$repoRoot\kiss_vpn_core\bin\KissVPNCore.exe" -Destination $dist -Force
    Copy-Item "$repoRoot\kiss_vpn_core\bin\wintun.dll"      -Destination $dist -Force
    Copy-Item "$repoRoot\kiss_vpn_core\geo\geoip.dat"       -Destination $dist -Force
    Copy-Item "$repoRoot\kiss_vpn_core\geo\geosite.dat"     -Destination $dist -Force
    Copy-Item "$repoRoot\kiss_vpn_core\geo\geoip.metadb"    -Destination $dist -Force

    Write-Host "==> Output:"
    Get-ChildItem $dist | Sort-Object Length -Descending |
        Select-Object Length, Name | Format-Table -AutoSize

    if (-not $SkipInstaller -and -not $DebugBuild) {
        $iscc = @(
            "${env:ProgramFiles(x86)}\Inno Setup 6\iscc.exe",
            "${env:ProgramFiles}\Inno Setup 6\iscc.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($iscc) {
            Write-Host "==> Building installer via $iscc"
            & $iscc /Qp (Join-Path $repoRoot 'installer\kiss_vpn.iss')
        } else {
            Write-Warning "Inno Setup not found; skipping installer build."
        }
    }
} finally { Pop-Location }
