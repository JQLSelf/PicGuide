# build_native.ps1
# 编译 Rust native_media.dll 并复制到 Flutter 输出目录
param([switch]$Release)

$projectRoot = $PSScriptRoot
$nativeDir   = Join-Path $projectRoot "native"

Push-Location $nativeDir
try {
    if ($Release) {
        cargo build --release
    } else {
        cargo build
    }
    if ($LASTEXITCODE -ne 0) { throw "cargo build failed" }
} finally {
    Pop-Location
}

$profile = if ($Release) { "Release" } else { "Debug" }
$targetDll = Join-Path $nativeDir "target\$profile\native_media.dll"
$flutterDir = Join-Path $projectRoot "build\windows\x64\runner\$profile"

if (-not (Test-Path $flutterDir)) {
    New-Item -ItemType Directory $flutterDir -Force | Out-Null
}
Copy-Item $targetDll (Join-Path $flutterDir "native_media.dll") -Force

Write-Host "native_media.dll ($profile) ready" -ForegroundColor Green
