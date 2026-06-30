# ============================================================
# build_release.ps1 - PixelVault Windows 一键打包脚本
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
    [string]$InnoSetupExe = ""
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
$baseName      = "PixelVault-$Version-win-x64"
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
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # 清理上次产物（避免旧 dll 残留）
    $buildRoot = Join-Path $projectRoot "build\windows"
    if (Test-Path $buildRoot) {
        Write-Warn "清理 build\windows\"
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

# ────────── 5. 生成绿色版 zip ──────────

if (-not $SkipZip) {
    Write-Section "5/6  打包绿色版 zip"
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
    Write-Section "6/6  生成 Inno Setup 安装程序"

    # 生成临时 .iss（也可让用户自建固定模板）
    $issContent = @"
; ============================================================
; installer.iss - 由 build_release.ps1 自动生成
; 重新发布前请检查 AppId / 版权 / 图标等
; ============================================================
[Setup]
AppId={{A8C2E0F1-3B4D-4E5F-9A0B-1C2D3E4F5A6B}
AppName=PixelVault
AppVersion=$Version
AppPublisher=PixelVault
AppPublisherURL=https://example.com
AppSupportURL=https://example.com
DefaultDirName={autopf}\PixelVault
DefaultGroupName=PixelVault
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
Name: "{autodesktop}\PixelVault"; Filename: "{app}\pixelvault.exe"
Name: "{group}\PixelVault 使用手册"; Filename: "{app}\USER_MANUAL.md"
Name: "{group}\卸载 PixelVault"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\pixelvault.exe"; Description: "{cm:LaunchProgram,PixelVault}"; \
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
    Write-Section "6/6  Inno Setup 安装程序（跳过）"
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
