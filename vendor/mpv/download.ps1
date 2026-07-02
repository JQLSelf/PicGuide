# PixelVault media_kit 依赖预下载脚本
# 如果本机无法访问 GitHub，请在浏览器中手动下载以下两个文件并放入当前目录。
#
# 文件 1: mpv-dev-x86_64-20230924-git-652a1dd.7z (8.38 MB)
#   URL: https://github.com/media-kit/libmpv-win32-video-build/releases/download/2023-09-24/mpv-dev-x86_64-20230924-git-652a1dd.7z
#
# 文件 2: ANGLE.7z (4.8 MB)
#   URL: https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z
#
# GitHub 镜像（如果直连失败可尝试）:
#   https://ghproxy.com/https://github.com/media-kit/libmpv-win32-video-build/releases/download/2023-09-24/mpv-dev-x86_64-20230924-git-652a1dd.7z
#   https://ghproxy.com/https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$files = @(
    @{
        Name = "mpv-dev-x86_64-20230924-git-652a1dd.7z"
        Url  = "https://github.com/media-kit/libmpv-win32-video-build/releases/download/2023-09-24/mpv-dev-x86_64-20230924-git-652a1dd.7z"
    },
    @{
        Name = "ANGLE.7z"
        Url  = "https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z"
    }
)

$allExist = $true
foreach ($f in $files) {
    $path = Join-Path $ScriptDir $f.Name
    if (-not (Test-Path $path)) {
        $allExist = $false
        Write-Host "[MISSING] $($f.Name)" -ForegroundColor Yellow
    } else {
        $size = (Get-Item $path).Length
        Write-Host "[OK] $($f.Name) ($([math]::Round($size/1MB, 2)) MB)" -ForegroundColor Green
    }
}

if ($allExist) {
    Write-Host "`nAll files present. You can now run: flutter run -d windows" -ForegroundColor Green
    exit 0
}

Write-Host "`nAttempting to download missing files..." -ForegroundColor Cyan

foreach ($f in $files) {
    $path = Join-Path $ScriptDir $f.Name
    if (Test-Path $path) { continue }

    Write-Host "Downloading $($f.Name)..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $f.Url -OutFile $path -TimeoutSec 30
        Write-Host "[OK] Downloaded $($f.Name)" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] Cannot download $($f.Name): $_" -ForegroundColor Red
        Write-Host "Please manually download from: $($f.Url)" -ForegroundColor Yellow
    }
}

Write-Host "`nAfter all files are downloaded, run: flutter run -d windows" -ForegroundColor Cyan
