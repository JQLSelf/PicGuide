# ============================================================
# download_ffmpeg_dev.ps1 - PicGuide 开发环境 ffmpeg 下载
# ============================================================
# 下载到项目根目录 ffmpeg\bin\，flutter run 会自动检测
# 用法：.\download_ffmpeg_dev.ps1
# ============================================================

$ErrorActionPreference = "Stop"
$ProgressPreference   = "SilentlyContinue"

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$TargetDir   = Join-Path $ScriptDir "ffmpeg"
$TargetExe   = Join-Path $TargetDir "bin\ffmpeg.exe"
$TargetProbe = Join-Path $TargetDir "bin\ffprobe.exe"

# ── 已存在则跳过 ──
if ((Test-Path $TargetExe) -and (Test-Path $TargetProbe)) {
    Write-Host "[OK] ffmpeg 已就绪: $($TargetDir)\bin\" -ForegroundColor Green
    exit 0
}

# ── 下载源（与 build_release.ps1 同步） ──
$sourceGroups = @(
    @{
        Label        = "直连源"
        Timeout      = 15
        MinSpeedKBps = 30
        Urls         = @(
            "https://github.com/GyanD/codexffmpeg/releases/latest/download/ffmpeg-release-essentials.zip",
            "https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-win64-gpl.zip"
        )
    },
    @{
        Label        = "ghproxy 镜像"
        Timeout      = 120
        MinSpeedKBps = 10
        Urls         = @(
            "https://ghproxy.com/https://github.com/GyanD/codexffmpeg/releases/latest/download/ffmpeg-release-essentials.zip",
            "https://ghproxy.net/https://github.com/GyanD/codexffmpeg/releases/latest/download/ffmpeg-release-essentials.zip",
            "https://ghproxy.com/https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-win64-gpl.zip",
            "https://ghproxy.net/https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-win64-gpl.zip"
        )
    },
    @{
        Label        = "备用镜像"
        Timeout      = 120
        MinSpeedKBps = 10
        Urls         = @(
            "https://gh-proxy.com/https://github.com/GyanD/codexffmpeg/releases/latest/download/ffmpeg-release-essentials.zip",
            "https://github.akams.cn/https://github.com/GyanD/codexffmpeg/releases/latest/download/ffmpeg-release-essentials.zip",
            "https://gh-proxy.com/https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-win64-gpl.zip",
            "https://github.akams.cn/https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-win64-gpl.zip"
        )
    }
)

$ffmpegZip = Join-Path $env:TEMP "ffmpeg-dev.zip"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 清理 Temp 残留
Get-ChildItem $env:TEMP -Filter "ffmpeg-dev*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

# ── 逐源下载 ──
$downloaded = $false
foreach ($group in $sourceGroups) {
    Write-Host "--- $($group.Label) ($($group.Urls.Count) 个源) ---" -ForegroundColor DarkGray
    foreach ($url in $group.Urls) {
        Remove-Item $ffmpegZip -Force -ErrorAction SilentlyContinue
        Write-Host "  $url" -ForegroundColor DarkGray

        # aria2c 优先
        $aria2 = Get-Command aria2c -ErrorAction SilentlyContinue
        if ($aria2) {
            Get-ChildItem (Split-Path $ffmpegZip) -Filter "$(Split-Path $ffmpegZip -Leaf)*" | Remove-Item -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 300
            $aria2Args = @("-x16","-s16","-k1M","--allow-overwrite=true","--auto-file-renaming=false",
                "--console-log-level=notice","--summary-interval=0","--connect-timeout=10",
                "-d",(Split-Path $ffmpegZip),"-o",(Split-Path $ffmpegZip -Leaf),$url)
            $aria2Proc = Start-Process -FilePath $aria2.Source -ArgumentList $aria2Args -Wait -NoNewWindow -PassThru
            Start-Sleep -Milliseconds 500
            # 改名兜底
            $renamed = Join-Path (Split-Path $ffmpegZip) "$(Split-Path $ffmpegZip -Leaf).1"
            if ((Test-Path $renamed) -and -not (Test-Path $ffmpegZip)) { Move-Item $renamed $ffmpegZip -Force }
            if ($aria2Proc.ExitCode -ne 0 -or -not (Test-Path $ffmpegZip)) {
                Write-Host "  aria2c 失败 (exit=$($aria2Proc.ExitCode))，回退" -ForegroundColor Yellow
                Remove-Item $ffmpegZip -Force -ErrorAction SilentlyContinue
            } else {
                $downloaded = $true
                break
            }
        }

        # WebClient 回退
        try {
            Remove-Item $ffmpegZip -Force -ErrorAction SilentlyContinue
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($url, $ffmpegZip)
            $wc.Dispose()
            if (Test-Path $ffmpegZip) { $downloaded = $true; break }
        } catch {
            Write-Host "  WebClient 失败: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    if ($downloaded) { break }
}

if (-not $downloaded) {
    Write-Host "[FAIL] 所有下载源均不可用" -ForegroundColor Red
    Write-Host "请手动下载 ffmpeg 放到: $TargetDir\bin\" -ForegroundColor Yellow
    exit 1
}

$zipSize = [math]::Round((Get-Item $ffmpegZip).Length / 1MB, 1)
Write-Host "  下载完成: $zipSize MB" -ForegroundColor DarkGray

# ── 解压（.NET ZipFile，免 Expand-Archive 兼容问题） ──
$unzipTmp = Join-Path $env:TEMP "ffmpeg-dev-extract"
Remove-Item $unzipTmp -Recurse -Force -ErrorAction SilentlyContinue
try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ffmpegZip, $unzipTmp)
} catch {
    Write-Host "[FAIL] 解压失败: $($_.Exception.Message)" -ForegroundColor Red
    Remove-Item $ffmpegZip -Force -ErrorAction SilentlyContinue
    exit 1
}

$foundFfmpeg  = Get-ChildItem $unzipTmp -Recurse -Filter "ffmpeg.exe"  | Select-Object -First 1
$foundFfprobe = Get-ChildItem $unzipTmp -Recurse -Filter "ffprobe.exe" | Select-Object -First 1
if (-not $foundFfmpeg -or -not $foundFfprobe) {
    Write-Host "[FAIL] zip 内未找到 ffmpeg.exe / ffprobe.exe" -ForegroundColor Red
    Remove-Item $unzipTmp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $ffmpegZip -Force -ErrorAction SilentlyContinue
    exit 1
}

# ── 拷贝到目标 ──
$targetBin = Join-Path $TargetDir "bin"
New-Item -ItemType Directory -Path $targetBin -Force | Out-Null
Copy-Item $foundFfmpeg.FullName  $targetBin -Force
Copy-Item $foundFfprobe.FullName $targetBin -Force

# ── 清理 ──
Remove-Item $unzipTmp -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $ffmpegZip -Force -ErrorAction SilentlyContinue

Write-Host "[OK] ffmpeg 就绪: $targetBin\" -ForegroundColor Green
Write-Host "现在可以运行: flutter run -d windows" -ForegroundColor Cyan
