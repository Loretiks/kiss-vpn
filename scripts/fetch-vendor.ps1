# Downloads the bundled binaries that the build needs but we don't
# commit to git:
#   - Mihomo (Clash.Meta) — windows-amd64-compatible release
#   - Xray-core — side-channel transport for vless+grpc proxies that Mihomo
#                 can't handle correctly (its gRPC client is unary-only)
#   - Wintun — 0.14.1 from wintun.net
#   - GeoIP / GeoSite / metadb — Loyalsoldier + MetaCubeX
#
# Run once after cloning the repo:
#   powershell -ExecutionPolicy Bypass -File scripts\fetch-vendor.ps1

[CmdletBinding()]
param(
    [string]$MihomoVersion = 'v1.19.25',
    [string]$XrayVersion   = 'v26.3.27'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol =
    [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

$root = Split-Path -Parent $PSScriptRoot
$coreDir = Join-Path $root 'kiss_vpn_core\bin'
$geoDir  = Join-Path $root 'kiss_vpn_core\geo'
$tmpDir  = Join-Path $root 'vendor'
New-Item -ItemType Directory -Path $coreDir -Force | Out-Null
New-Item -ItemType Directory -Path $geoDir  -Force | Out-Null
New-Item -ItemType Directory -Path $tmpDir  -Force | Out-Null

function Download($url, $out) {
    Write-Host "→ $url"
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -TimeoutSec 120
}

# ── Mihomo
$mihomoExe = Join-Path $coreDir 'KissVPNCore.exe'
if (-not (Test-Path $mihomoExe)) {
    $zip = Join-Path $tmpDir 'mihomo.zip'
    Download "https://github.com/MetaCubeX/mihomo/releases/download/$MihomoVersion/mihomo-windows-amd64-compatible-$MihomoVersion.zip" $zip
    $extract = Join-Path $tmpDir 'mihomo-extracted'
    Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $exe = Get-ChildItem $extract -Filter '*.exe' | Select-Object -First 1
    Copy-Item $exe.FullName $mihomoExe -Force
    Write-Host "Mihomo $MihomoVersion → $mihomoExe"
}

# ── Xray-core (side-channel for grpc proxies)
$xrayExe = Join-Path $coreDir 'xray.exe'
if (-not (Test-Path $xrayExe)) {
    $zip = Join-Path $tmpDir 'xray.zip'
    Download "https://github.com/XTLS/Xray-core/releases/download/$XrayVersion/Xray-windows-64.zip" $zip
    $extract = Join-Path $tmpDir 'xray-extracted'
    Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    Copy-Item (Join-Path $extract 'xray.exe') $xrayExe -Force
    Write-Host "Xray $XrayVersion → $xrayExe"
}

# ── Wintun
$wintun = Join-Path $coreDir 'wintun.dll'
if (-not (Test-Path $wintun)) {
    $zip = Join-Path $tmpDir 'wintun.zip'
    Download 'https://www.wintun.net/builds/wintun-0.14.1.zip' $zip
    $extract = Join-Path $tmpDir 'wintun-extracted'
    Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    Copy-Item (Join-Path $extract 'wintun\bin\amd64\wintun.dll') $wintun -Force
    Write-Host "Wintun 0.14.1 → $wintun"
}

# ── GeoIP / GeoSite
$geoFiles = @(
    @{Url = 'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat';    Path = Join-Path $geoDir 'geoip.dat'}
    @{Url = 'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat';  Path = Join-Path $geoDir 'geosite.dat'}
    @{Url = 'https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geoip.metadb';     Path = Join-Path $geoDir 'geoip.metadb'}
)
foreach ($g in $geoFiles) {
    if (-not (Test-Path $g.Path)) { Download $g.Url $g.Path }
}

Write-Host ""
Write-Host "Done. Next step:"
Write-Host "  powershell -ExecutionPolicy Bypass -File scripts\build.ps1"
