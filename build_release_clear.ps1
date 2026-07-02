# ============================================================
# build_release_clear.ps1 - PicGuide Windows 一键打包脚本（全量清理版）
# ============================================================
#
# 用法（在项目根目录执行）：
#   powershell -ExecutionPolicy Bypass -File .\build_release.ps1
#
# 可选参数：
#   -Version "1.2.3"        指定版本号（默认从 pubspec.yaml 读取）
#   -OutputDir "dist"       输出目录（默认 dist）
#   -SkipBuild              跳过 flutter build，复用已有 Release 目录
#   -SkipZip                不生成绿色版 zip
#   -SkipInnoSetup          不调用 Inno Setup（即便检测到也不调用）
#   -FlutterExe "flutter"   指定 flutter 可执行路径
#   -InnoSetupExe "C:\...\ISCC.exe"  指定 Inno Setup 编译器
#   -FfmpegPath "D:\ffmpeg"          指定本地 ffmpeg 目录或 ffmpeg.exe 路径
#
# 前置：
#   1. Flutter >= 3.16，配置了 Windows 桌面（flutter config --enable-windows-desktop）
#   2. （可选）Inno Setup 6.x，用于生成安装程序
# ============================================================

[CmdletBinding()]
param(
    [string]$Version = "",
    [string]$OutputDir = "dist",
    [switch]$SkipBuild,
    [switch]$SkipZip,
    [switch]$SkipInnoSetup,
    [string]$FlutterExe = "flutter",
    [string]$InnoSetupExe = "",
    [string]$FfmpegPath = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference   = "SilentlyContinue"   # 关闭 Windows 原生进度条

# ────────── 工具函数 ──────────

function Write-Section([string]$title) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host "▶ $title" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor DarkGray
}

function Write-OK([string]$msg)   { Write-Host "  ✔ $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Err([string]$msg)  { Write-Host "  ✖ $msg" -ForegroundColor Red }

# 带进度条 + 速度检测的下载函数
# 优先使用 aria2c 多线程下载（16 线程），不可用时回退到 WebClient
# 若平均速度低于 MinSpeedKBps 持续超过 CheckAfterSec 秒，自动中断切换源
function _downloadWithProgress {
    param(
        [string]$Url,
        [string]$OutFile,
        [int]$TimeoutSec = 60,
        [int]$MinSpeedKBps = 30,
        [int]$CheckAfterSec = 10
    )

    # ── 优先 aria2c（16 线程，自带进度条） ──
    $aria2 = Get-Command aria2c -ErrorAction SilentlyContinue
    if ($aria2) {
        Write-Host "  使用 aria2c 多线程下载 (16 线程)" -ForegroundColor DarkGray
        # 清理所有残留（上次失败可能留下 .zip / .1.zip / .zip.aria2）
        $outDir = Split-Path $OutFile
        $outName = Split-Path $OutFile -Leaf
        Get-ChildItem $outDir -Filter "$outName*" | Remove-Item -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 300  # 等文件句柄释放

        $aria2Proc = Start-Process -FilePath $aria2.Source -ArgumentList @(
            "-x16", "-s16", "-k1M",
            "--max-overall-download-limit=0",
            "--console-log-level=notice",
            "--summary-interval=0",
            "--connect-timeout=10",
            "--max-connection-per-server=16",
            "--min-split-size=1M",
            "--allow-overwrite=true",
            "--auto-file-renaming=false",
            "-d", $outDir,
            "-o", $outName,
            $Url
        ) -Wait -NoNewWindow -PassThru

        Start-Sleep -Milliseconds 500

        # aria2c 自动改名了？把 .1.zip 移回来
        $renamedFile = Join-Path $outDir "$outName.1"
        if ((Test-Path $renamedFile) -and -not (Test-Path $OutFile)) {
            Move-Item $renamedFile $OutFile -Force
        }

        if ($aria2Proc.ExitCode -eq 0 -and (Test-Path $OutFile)) {
            $finalSize = [math]::Round((Get-Item $OutFile).Length / 1MB, 1)
            Write-Host "  aria2c 完成: $finalSize MB"
            return $true
        }
        Write-Warn "  aria2c 失败 (exit=$($aria2Proc.ExitCode))，回退 WebClient"
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
    }

    # ── 回退 WebClient（Job + 速度检测） ──
    # 确保目标文件不存在（WebClient.DownloadFile 不会自动覆盖）
    Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $job = Start-Job -ScriptBlock {
        param($u, $o)
        $wc = New-Object System.Net.WebClient
        try { $wc.DownloadFile($u, $o) } finally { $wc.Dispose() }
    } -ArgumentList $Url, $OutFile

    try {
        while ($job.State -eq 'Running') {
            Start-Sleep -Milliseconds 800
            $elapsed = $sw.Elapsed.TotalSeconds

            $currentBytes = if (Test-Path $OutFile) {
                (Get-Item $OutFile -ErrorAction SilentlyContinue).Length
            } else { 0 }

            $speedKBps = if ($elapsed -gt 0) { [math]::Round($currentBytes / $elapsed / 1KB, 1) } else { 0 }
            $sizeMB    = [math]::Round($currentBytes / 1MB, 1)

            $pct = [math]::Min(100, ($elapsed / $TimeoutSec) * 100)
            Write-Progress -Activity "下载 ffmpeg" `
                -Status "$sizeMB MB | $speedKBps KB/s | $([math]::Round($elapsed))s" `
                -PercentComplete $pct

            # 速度检测：N 秒后平均速度仍低于阈值 → 中断
            if ($elapsed -gt $CheckAfterSec -and $currentBytes -lt ($MinSpeedKBps * $elapsed * 1KB)) {
                Write-Progress -Activity "下载 ffmpeg" -Completed
                Stop-Job $job -ErrorAction SilentlyContinue
                Remove-Job $job -Force -ErrorAction SilentlyContinue
                throw "速度过慢 ($speedKBps KB/s < $MinSpeedKBps KB/s)，自动切源"
            }

            if ($elapsed -gt $TimeoutSec) {
                Write-Progress -Activity "下载 ffmpeg" -Completed
                Stop-Job $job -ErrorAction SilentlyContinue
                Remove-Job $job -Force -ErrorAction SilentlyContinue
                throw "超时 ($TimeoutSec s)"
            }
        }

        Write-Progress -Activity "下载 ffmpeg" -Completed

        $result = Receive-Job $job -ErrorAction SilentlyContinue
    } finally {
        Remove-Job $job -Force -ErrorAction SilentlyContinue
    }

    $sw.Stop()
    $totalSec = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    if (Test-Path $OutFile) {
        $finalSize = (Get-Item $OutFile).Length
        $avgSpeed = [math]::Round($finalSize / $totalSec / 1KB, 1)
        Write-Host "    $([math]::Round($finalSize/1MB,1)) MB | $avgSpeed KB/s | $totalSec s"
        return $true
    }
    return $false
}

function _copyOrDownloadFfmpeg {
    param([string]$DestDir, [string]$FfmpegPath)
    $destExe = Join-Path $DestDir "bin\ffmpeg.exe"
    $destProbe = Join-Path $DestDir "bin\ffprobe.exe"

    # 1. 用户指定了本地路径 → 直接拷贝
    if ($FfmpegPath -and (Test-Path $FfmpegPath)) {
        if ((Get-Item $FfmpegPath) -is [System.IO.DirectoryInfo]) {
            Copy-Item $FfmpegPath $DestDir -Recurse -Force
        } elseif ($FfmpegPath -like "*ffmpeg.exe") {
            New-Item -ItemType Directory -Path (Join-Path $DestDir "bin") -Force | Out-Null
            Copy-Item $FfmpegPath $destExe -Force
            $probePath = Join-Path (Split-Path $FfmpegPath) "ffprobe.exe"
            if (Test-Path $probePath) { Copy-Item $probePath $destProbe -Force }
        }
        if ((Test-Path $destExe) -and (Test-Path $destProbe)) {
            Write-OK "ffmpeg 已从本地拷贝: $destExe"
            return
        }
        Write-Warn "指定的 ffmpeg 路径无效，尝试其他方式..."
    }

    # 2. 项目根目录 ffmpeg\bin\ 自动检测（开发者一次性下好，后续零下载）
    $vendorFfmpeg = Join-Path $PSScriptRoot "ffmpeg\bin\ffmpeg.exe"
    $vendorFfprobe = Join-Path $PSScriptRoot "ffmpeg\bin\ffprobe.exe"
    if ((Test-Path $vendorFfmpeg) -and (Test-Path $vendorFfprobe)) {
        Write-Warn "检测到项目根目录 ffmpeg\，直接拷贝"
        Copy-Item (Join-Path $PSScriptRoot "ffmpeg") $DestDir -Recurse -Force
        if ((Test-Path $destExe) -and (Test-Path $destProbe)) {
            Write-OK "ffmpeg 已从项目根目录拷贝"
            return
        }
    }

    # 3. 从系统 PATH 或常见路径找 ffmpeg
    $sysFfmpeg = (Get-Command ffmpeg.exe -ErrorAction SilentlyContinue).Source
    if ($sysFfmpeg) {
        $srcDir = Split-Path $sysFfmpeg
        Write-Warn "从系统 PATH 获取 ffmpeg: $srcDir"
        Copy-Item $srcDir $DestDir -Recurse -Force
        Rename-Item (Join-Path $DestDir (Split-Path $srcDir -Leaf)) (Join-Path $DestDir "bin") -Force
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
        if ((Test-Path $destExe) -and (Test-Path $destProbe)) {
            Write-OK "ffmpeg 已从系统 PATH 拷贝"
            return
        }
    }

    # 3.5 清理 Temp 里之前失败的残留（避免 aria2c 自动改名 .1.zip 等冲突）
    Get-ChildItem $env:TEMP -Filter "ffmpeg-pixelvault*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    # 4. 在线下载（多源轮询 + 进度条 + 慢速自动切源）
    #    直连源 10s 内平均速度 < 30KB/s 就放弃，直接走代理
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

    $ffmpegZip = Join-Path $env:TEMP "ffmpeg-pixelvault.zip"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    foreach ($group in $sourceGroups) {
        Write-Warn "--- $($group.Label) ($($group.Urls.Count) 个源, 慢速阈值 $($group.MinSpeedKBps) KB/s) ---"
        foreach ($url in $group.Urls) {
            Remove-Item $ffmpegZip -Force -ErrorAction SilentlyContinue
            Write-Warn "  $url"
            try {
                $ok = _downloadWithProgress -Url $url -OutFile $ffmpegZip `
                    -TimeoutSec $group.Timeout -MinSpeedKBps $group.MinSpeedKBps -CheckAfterSec 8
                if (-not $ok) { Write-Warn "  下载未完成，尝试下一个源"; continue }

                # 解压到独立临时目录（避免 Expand-Archive 在目标目录上的兼容问题）
                $unzipTmp = Join-Path $env:TEMP "ffmpeg-extract"
                Remove-Item $unzipTmp -Recurse -Force -ErrorAction SilentlyContinue
                $unzipOk = $false
                for ($retry = 0; $retry -lt 3; $retry++) {
                    try {
                        [System.IO.Compression.ZipFile]::ExtractToDirectory($ffmpegZip, $unzipTmp)
                        $unzipOk = $true; break
                    } catch {
                        if ($retry -lt 2) {
                            Write-Warn "  解压重试 $($retry+1)/3: $($_.Exception.Message)"
                            [System.GC]::Collect(); [System.GC]::WaitForPendingFinalizers()
                            Start-Sleep -Milliseconds 1000
                        } else {
                            Remove-Item $unzipTmp -Recurse -Force -ErrorAction SilentlyContinue
                            throw
                        }
                    }
                }
                if (-not $unzipOk) { Write-Warn "  解压失败，尝试下一个源"; continue }

                # 找到 bin/ffmpeg.exe（无论嵌套几层）
                $foundFfmpeg  = Get-ChildItem $unzipTmp -Recurse -Filter "ffmpeg.exe"  -ErrorAction SilentlyContinue | Select-Object -First 1
                $foundFfprobe = Get-ChildItem $unzipTmp -Recurse -Filter "ffprobe.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($foundFfmpeg -and $foundFfprobe) {
                    $targetBin = Join-Path $DestDir "bin"
                    New-Item -ItemType Directory -Path $targetBin -Force | Out-Null
                    Copy-Item $foundFfmpeg.FullName  $targetBin -Force
                    Copy-Item $foundFfprobe.FullName $targetBin -Force
                    Write-Host "  提取 ffmpeg.exe ($([math]::Round($foundFfmpeg.Length/1MB,1)) MB) + ffprobe.exe"
                } else {
                    Write-Warn "  zip 内未找到 ffmpeg.exe/ffprobe.exe，尝试下一个源"
                    Remove-Item $unzipTmp -Recurse -Force -ErrorAction SilentlyContinue
                    Remove-Item $ffmpegZip -Force -ErrorAction SilentlyContinue
                    continue
                }

                # 清理临时文件
                Remove-Item $unzipTmp -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item $ffmpegZip -Force -ErrorAction SilentlyContinue
                if ((Test-Path $destExe) -and (Test-Path $destProbe)) {
                    Write-OK "ffmpeg 就绪: $destExe"
                    # 自动缓存到项目根目录（后续打包跳过下载）
                    $cacheDir = Join-Path $PSScriptRoot "ffmpeg\bin"
                    $cacheExe = Join-Path $cacheDir "ffmpeg.exe"
                    if (-not (Test-Path $cacheExe)) {
                        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
                        Copy-Item $destExe $cacheDir -Force
                        Copy-Item $destProbe $cacheDir -Force
                        Write-OK "已缓存到项目根目录 ffmpeg\（下次跳过下载）"
                    }
                    return
                }
                Write-Warn "  解压后文件结构不符，尝试下一个源"
            } catch {
                Write-Warn "  失败: $($_.Exception.Message)"
            }
        }
    }

    Remove-Item $ffmpegZip -Force -ErrorAction SilentlyContinue
    Write-Warn "所有下载源均不可用，请手动准备 ffmpeg 或使用 -FfmpegPath 参数指定路径"
}

function Get-FormattedSize([int64]$bytes) {
    if ($bytes -ge 1GB) { return ("{0:N2} GB" -f ($bytes / 1GB)) }
    if ($bytes -ge 1MB) { return ("{0:N2} MB" -f ($bytes / 1MB)) }
    if ($bytes -ge 1KB) { return ("{0:N2} KB" -f ($bytes / 1KB)) }
    return "$bytes B"
}

function Read-PubspecVersion {
    $pubspecPath = Join-Path $PSScriptRoot "pubspec.yaml"
    if (-not (Test-Path $pubspecPath)) {
        throw "未找到 pubspec.yaml，请确认脚本在项目根目录运行"
    }
    $content = Get-Content $pubspecPath -Raw
    $m = [regex]::Match($content, "(?m)^\s*version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+[0-9]+)?\s*$")
    if (-not $m.Success) {
        throw "无法从 pubspec.yaml 解析 version 字段"
    }
    return $m.Groups[1].Value
}

# ────────── Inno Setup 自动部署（便携版）──────────
#
# 检测不到 ISCC 时调用：
#   1) 用 winget 试装（最省事；Win10/11 自带）
#   2) 失败则下载官方 is.exe 便携安装器，静默装到 %LOCALAPPDATA%\InnoSetup\
#   3) 装完返回 ISCC.exe 绝对路径；任何步骤失败返回 $null
function Install-InnoSetupPortable {
    $portableDir = Join-Path $env:LOCALAPPDATA "InnoSetup"
    $isccExe     = Join-Path $portableDir "ISCC.exe"
    if (Test-Path $isccExe) { return $isccExe }

    # 1) winget 路径
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Warn "未检测到 Inno Setup，尝试用 winget 安装（约 1-2 分钟）..."
        try {
            & winget install --id JRSoftware.InnoSetup -e --source winget --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            $paths = @(
                (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
                (Join-Path ${env:ProgramFiles} 'Inno Setup 6\ISCC.exe')
            )
            foreach ($p in $paths) { if (Test-Path $p) { return $p } }
        } catch {
            Write-Warn "winget 部署失败，回退到便携版下载"
        }
    }

    # 2) 官方便携版下载
    $url       = "https://jrsoftware.org/download.php/is.exe"
    $installer = Join-Path $portableDir "is-setup.exe"
    if (-not (Test-Path $portableDir)) {
        New-Item -ItemType Directory $portableDir -Force | Out-Null
    }
    if (-not (Test-Path $installer)) {
        Write-Warn "下载 Inno Setup 便携版到 $portableDir ..."
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing -TimeoutSec 120
        } catch {
            Write-Warn "下载失败: $($_.Exception.Message)"
            return $null
        }
    }

    # 3) 静默安装到便携目录（仅当前用户，无需管理员）
    Write-Warn "静默安装 Inno Setup 到 $portableDir ..."
    $proc = Start-Process -FilePath $installer `
        -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART","/CURRENTUSER","/DIR=`"$portableDir`"" `
        -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        Write-Warn "便携版安装失败 (exit=$($proc.ExitCode))"
        return $null
    }

    if (Test-Path $isccExe) { return $isccExe }

    # 兜底：某些版本装在 ISCC64.exe
    $iscc64 = Join-Path $portableDir "ISCC64.exe"
    if (Test-Path $iscc64) { return $iscc64 }

    return $null
}

# ────────── 预检查 ──────────

Write-Section "环境检查"

# 1) Flutter
try {
    $flutterVersion = (& $FlutterExe --version 2>&1 | Select-Object -First 1).ToString()
    Write-OK "Flutter: $flutterVersion"
} catch {
    Write-Err "未找到 flutter 可执行文件（$FlutterExe）。请安装 Flutter 并加入 PATH。"
    throw
}

# 2) Windows 桌面已启用
$configOut = & $FlutterExe config 2>&1 | Out-String
if ($configOut -notmatch "enable-windows-desktop:\s*true") {
    Write-Warn "Windows 桌面未启用，正在执行：flutter config --enable-windows-desktop"
    & $FlutterExe config --enable-windows-desktop | Out-Null
}

# 3) 版本号
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Read-PubspecVersion
}
Write-OK "版本号: $Version"

# 4) Inno Setup（探测 → 缺失则自动下载便携版）
$useInnoSetup = -not $SkipInnoSetup
if ($useInnoSetup) {
    $candidatePaths = @()

    if (-not [string]::IsNullOrWhiteSpace($InnoSetupExe)) {
        $candidatePaths += $InnoSetupExe
    }
    # 标准安装位置 + 之前自动下载的便携版默认位置
    $candidatePaths += @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 5\ISCC.exe",
        (Join-Path $env:LOCALAPPDATA "InnoSetup\ISCC.exe"),
        (Join-Path $env:LOCALAPPDATA "InnoSetup\ISCC64.exe")
    )

    $iscc = $candidatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($iscc) {
        Write-OK "Inno Setup 编译器: $iscc"
    } else {
        # 自动下载 + 静默安装便携版（无需管理员）
        $iscc = Install-InnoSetupPortable
        if ($iscc) {
            Write-OK "Inno Setup 已自动部署: $iscc"
        } else {
            Write-Warn "未能部署 Inno Setup，将跳过安装程序生成（仅生成绿色版 zip）"
            $useInnoSetup = $false
        }
    }
}

# ────────── 路径常量 ──────────

$projectRoot   = $PSScriptRoot
$releaseDir    = Join-Path $projectRoot "build\windows\x64\runner\Release"
$dataDir       = Join-Path $projectRoot "data"
$issFile       = Join-Path $projectRoot "installer.iss"
$outputAbsDir  = Join-Path $projectRoot $OutputDir
$timestamp     = Get-Date -Format "yyyyMMdd-HHmmss"
$baseName      = "PicGuide-$Version-win-x64"
$zipPath       = Join-Path $outputAbsDir "$baseName.zip"
$checksumPath  = Join-Path $outputAbsDir "$baseName.zip.sha256.txt"

# ────────── 准备输出目录 ──────────

Write-Section "准备输出目录"
if (-not (Test-Path $outputAbsDir)) {
    New-Item -ItemType Directory -Path $outputAbsDir -Force | Out-Null
}
Write-OK "输出目录: $outputAbsDir"

# ────────── 1. flutter pub get ──────────

Write-Section "1/6  拉取依赖"
& $FlutterExe pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get 失败" }
Write-OK "依赖已更新"

# ────────── 2. 编译 Rust native_media.dll ──────────

Write-Section "2/6  编译 Rust 原生库"
$nativeDir = Join-Path $projectRoot "native"
$rustTargetDll = Join-Path $nativeDir "target\Release\native_media.dll"

# 检查 Rust 工具链
$cargo = Get-Command cargo -ErrorAction SilentlyContinue
if (-not $cargo) {
    throw "未找到 cargo，请先安装 Rust：https://rustup.rs"
}
Write-OK "Rust 工具链: $((& cargo --version 2>&1).ToString().Trim())"

Push-Location $nativeDir
try {
    & cargo build --release
    if ($LASTEXITCODE -ne 0) { throw "cargo build --release 失败" }
} finally {
    Pop-Location
}

if (-not (Test-Path $rustTargetDll)) {
    throw "未找到 $rustTargetDll，Rust 编译可能未成功"
}
Write-OK "Rust 原生库: $rustTargetDll ($((Get-Item $rustTargetDll).Length/1KB -as [int]) KB)"

# ────────── 3. flutter build windows ──────────

if (-not $SkipBuild) {
    Write-Section "3/6  编译 Release"

    # 检查 media_kit 预下载依赖
    $vendorMpvDir = Join-Path $projectRoot "vendor\mpv"
    $vendorFiles = @(
        "mpv-dev-x86_64-20230924-git-652a1dd.7z",
        "ANGLE.7z"
    )
    $missingVendor = @()
    foreach ($f in $vendorFiles) {
        if (-not (Test-Path (Join-Path $vendorMpvDir $f))) {
            $missingVendor += $f
        }
    }
    if ($missingVendor.Count -gt 0) {
        Write-Warn "缺少 media_kit 预下载依赖: $($missingVendor -join ', ')"
        Write-Warn "请先运行: .\vendor\mpv\download.ps1"
        Write-Warn "或手动下载上述文件放入 vendor\mpv\ 目录"
        Write-Warn "详见 vendor\mpv\download.ps1 中的下载地址"
        throw "缺少预下载依赖，无法继续编译"
    }
    Write-OK "media_kit 预下载依赖已就绪"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # 全量清理 build\windows\（完整重建，含 sqlite3 重编译 + mpv 重解压）
    $buildRoot = Join-Path $projectRoot "build\windows"
    if (Test-Path $buildRoot) {
        Write-Warn "全量清理 build\windows\（完整重建）"
        Remove-Item $buildRoot -Recurse -Force
    }

    & $FlutterExe build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows --release 失败" }

    $sw.Stop()
    Write-OK "构建完成，耗时 $([math]::Round($sw.Elapsed.TotalSeconds, 1)) s"
} else {
    Write-Section "3/6  编译 Release（跳过 -SkipBuild）"
    if (-not (Test-Path $releaseDir)) {
        throw "未找到 $releaseDir，请先去掉 -SkipBuild 执行一次完整构建"
    }
    Write-OK "复用既有 Release 目录"
}

# 校验产物
if (-not (Test-Path (Join-Path $releaseDir "pixelvault.exe"))) {
    throw "未在 $releaseDir 找到 pixelvault.exe，构建可能未成功"
}
Write-OK "主程序: $releaseDir\pixelvault.exe"

# ────────── 4. 拷贝 USER_MANUAL.md ──────────

Write-Section "4/6  拷贝使用手册到 Release 目录"
$manualSrc = Join-Path $projectRoot "assets\USER_MANUAL.md"
$manualDst = Join-Path $releaseDir "USER_MANUAL.md"
if (Test-Path $manualSrc) {
    Copy-Item $manualSrc $manualDst -Force
    Write-OK "已复制: $manualDst"
} else {
    Write-Warn "未找到 $manualSrc，跳过（应用启动时也会自动生成）"
}

# ────────── 5. 便携版 ffmpeg ──────────

Write-Section "5/7  准备 ffmpeg 便携版"
$ffmpegDir = Join-Path $releaseDir "ffmpeg"
$ffmpegExe = Join-Path $ffmpegDir "bin\ffmpeg.exe"
if (Test-Path $ffmpegExe) {
    Write-OK "ffmpeg 已缓存: $ffmpegExe"
} else {
    _copyOrDownloadFfmpeg -DestDir $ffmpegDir -FfmpegPath $FfmpegPath
    if (-not (Test-Path $ffmpegExe)) {
        Write-Warn "ffmpeg 未就绪，视频封面将依赖目标机器的系统 ffmpeg"
    }
}

# ────────── 6. 生成绿色版 zip ──────────

if (-not $SkipZip) {
    Write-Section "6/7  打包绿色版 zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # PowerShell 5.1 / 7+ 通用写法：用 .NET ZipFile
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $releaseDir,
        $zipPath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false  # includeBaseDirectory
    )

    $sw.Stop()
    $zipSize = (Get-Item $zipPath).Length
    Write-OK "已生成: $zipPath ($([math]::Round($zipSize/1MB, 2)) MB, $([math]::Round($sw.Elapsed.TotalSeconds,1)) s)"

    # SHA256
    $hash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
    "SHA256: $hash  $baseName.zip" | Out-File -FilePath $checksumPath -Encoding UTF8
    Write-OK "校验和: $checksumPath"
    Write-Host "       $hash" -ForegroundColor DarkGray
}

# ────────── 6. Inno Setup 安装程序 ──────────

if ($useInnoSetup) {
    Write-Section "7/7  生成 Inno Setup 安装程序"

    # 生成临时 .iss（也可让用户自建固定模板）
    $issContent = @"
; ============================================================
; installer.iss - 由 build_release.ps1 自动生成
; 重新发布前请检查 AppId / 版权 / 图标等
; ============================================================
[Setup]
AppId={{A8C2E0F1-3B4D-4E5F-9A0B-1C2D3E4F5A6B}
AppName=PicGuide
AppVersion=$Version
AppPublisher=PicGuide
AppPublisherURL=https://example.com
AppSupportURL=https://example.com
DefaultDirName={autopf}\PicGuide
DefaultGroupName=PicGuide
AllowNoIcons=yes
OutputDir=$($outputAbsDir -replace '\\','\\')
OutputBaseFilename=$baseName-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\pixelvault.exe

[Files]
Source: "$($releaseDir -replace '\\','\\')\*"; \
    DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autodesktop}\PicGuide"; Filename: "{app}\pixelvault.exe"
Name: "{group}\PicGuide 使用手册"; Filename: "{app}\USER_MANUAL.md"
Name: "{group}\卸载 PicGuide"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\pixelvault.exe"; Description: "{cm:LaunchProgram,PicGuide}"; \
    Flags: nowait postinstall skipifsilent
"@

    $issFile = Join-Path $projectRoot "installer.iss"
    $issContent | Out-File -FilePath $issFile -Encoding UTF8
    Write-OK "已生成脚本: $issFile"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $iscc $issFile
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup 编译失败（exit=$LASTEXITCODE）" }
    $sw.Stop()

    $setupExe = Join-Path $outputAbsDir "$baseName-Setup.exe"
    if (Test-Path $setupExe) {
        $setupSize = (Get-Item $setupExe).Length
        Write-OK "已生成: $setupExe ($([math]::Round($setupSize/1MB, 2)) MB, $([math]::Round($sw.Elapsed.TotalSeconds,1)) s)"

        # 安装包校验和
        $setupHash = (Get-FileHash -Path $setupExe -Algorithm SHA256).Hash
        $setupHashPath = Join-Path $outputAbsDir "$baseName-Setup.exe.sha256.txt"
        "SHA256: $setupHash  $baseName-Setup.exe" | Out-File -FilePath $setupHashPath -Encoding UTF8
        Write-OK "安装包校验和: $setupHashPath"
    } else {
        Write-Warn "未找到安装程序，Inno Setup 可能输出了非预期位置"
    }
} else {
    Write-Section "7/7  Inno Setup 安装程序（跳过）"
}

# ────────── 汇总 ──────────

Write-Section "完成 ✅"
Write-Host "  版本:     $Version" -ForegroundColor Green
Write-Host "  源码目录: $projectRoot" -ForegroundColor Green
Write-Host "  Release:  $releaseDir" -ForegroundColor Green
Write-Host "  输出目录: $outputAbsDir" -ForegroundColor Green
Write-Host ""

# 列出输出文件
Write-Host "📦 输出文件:" -ForegroundColor Cyan
Get-ChildItem $outputAbsDir -File |
    Sort-Object Name |
    ForEach-Object {
        $size = Get-FormattedSize $_.Length
        Write-Host "    $($_.Name)  ($size)" -ForegroundColor White
    }

Write-Host ""
Write-Host "🚀 下一步：" -ForegroundColor Cyan
Write-Host "   • 本地试运行: $releaseDir\pixelvault.exe" -ForegroundColor Gray
Write-Host "   • 分发绿色版: $zipPath" -ForegroundColor Gray
if ($useInnoSetup) {
    Write-Host "   • 分发安装包: $outputAbsDir\$baseName-Setup.exe" -ForegroundColor Gray
}
Write-Host ""
