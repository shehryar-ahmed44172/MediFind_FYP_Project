# Builds a shareable MediFind APK.
#   .\build_apk.ps1                          -> backend on this laptop's Wi-Fi IP (same Wi-Fi only)
#   .\build_apk.ps1 -ApiHost https://x.y.z   -> backend at a public URL (e.g. a tunnel or server)
# The APK is copied to E:\Medifind_FYP_Project\APK with the date in its name.
param([string]$ApiHost = '')

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$env:PUB_CACHE = 'E:\DevCaches\Pub\Cache'

if (-not $ApiHost) {
  $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi*' -ErrorAction SilentlyContinue |
         Where-Object { $_.IPAddress -notlike '169.*' } | Select-Object -First 1).IPAddress
  if (-not $ip) { throw 'No Wi-Fi IP found. Connect to Wi-Fi or pass -ApiHost.' }
  $ApiHost = "http://${ip}:3000"
}
Write-Host "Building MediFind APK for backend: $ApiHost" -ForegroundColor Cyan

flutter build apk --release --split-per-abi --dart-define=MEDIFIND_API_HOST=$ApiHost
if ($LASTEXITCODE -ne 0) { throw 'Build failed (check internet for the first build of the day).' }

$outDir = 'E:\Medifind_FYP_Project\APK'
New-Item -ItemType Directory -Force $outDir | Out-Null
$name = 'MediFind-' + (Get-Date -Format 'yyyy-MM-dd-HHmm') + '.apk'
Copy-Item 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk' (Join-Path $outDir $name)
Write-Host "Done: $outDir\$name  (backend: $ApiHost)" -ForegroundColor Green
