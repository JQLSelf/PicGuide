# ============================================================
# PixelVault - Flutter 环境检查脚本
# 用法: 在项目目录下运行  .\check_env.ps1
# ============================================================

$ErrorActionPreference = "Continue"
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  PixelVault - 环境检查"                   -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

$allPass = $true

function Check-Result($name, $pass, $msg, $fix) {
    if ($pass) {
        Write-Host "  [✓] $name" -ForegroundColor Green
    } else {
        Write-Host "  [✗] $name" -ForegroundColor Red
        Write-Host "      $msg"   -ForegroundColor Yellow
        if ($fix) { Write-Host "      修复: $fix" -ForegroundColor Gray }
        $script:allPass = $false
    }
}

# 1. Flutter
Write-Host "`n[1] Flutter SDK" -ForegroundColor Yellow
try {
    $fVer = flutter --version 2>$null | Select-String "Flutter" | Out-String
    Check-Result "Flutter 已安装" $true $fVer
} catch {
    Check-Result "Flutter 已安装" $false "未找到 flutter 命令" "运行 setup_flutter_env.ps1 安装"
}

# 2. Dart
Write-Host "`n[2] Dart SDK" -ForegroundColor Yellow
try {
    $dVer = dart --version 2>&1
    Check-Result "Dart 已安装" $true $dVer
} catch {
    Check-Result "Dart 已安装" $false "未找到 dart 命令" "Flutter 内置 Dart，检查 Flutter 安装"
}

# 3. Git
Write-Host "`n[3] Git" -ForegroundColor Yellow
try {
    $gVer = git --version 2>$null
    Check-Result "Git 已安装" $true $gVer
} catch {
    Check-Result "Git 已安装" $false "未找到 git 命令" "https://git-scm.com/download/win"
}

# 4. Visual Studio (Windows 桌面开发)
Write-Host "`n[4] Visual Studio (Windows 桌面开发)" -ForegroundColor Yellow
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsWhere) {
    $vsInfo = & "$vsWhere" -products "*" -requires Microsoft.VisualStudio.Component.Windows10SDK -latest -format json 2>$null | ConvertFrom-Json
    if ($vsInfo) {
        Check-Result "Visual Studio 已安装 (含 C++/SDK)" $true "版本: $($vsInfo.installationName)"
    } else {
        Check-Result "Visual Studio 已安装 (含 C++/SDK)" $false "已安装 VS 但未勾选 '使用 C++ 的桌面开发'" "通过 VS Installer 修改安装，勾选该组件"
    }
} else {
    Check-Result "Visual Studio 已安装 (含 C++/SDK)" $false "未安装 Visual Studio" "https://visualstudio.microsoft.com/zh-hans/downloads/"
}

# 5. Windows 桌面支持
Write-Host "`n[5] Flutter Windows 桌面支持" -ForegroundColor Yellow
try {
    $enabled = flutter config 2>$null | Select-String "enable-windows-desktop.*true"
    if ($enabled) {
        Check-Result "Windows 桌面支持已启用" $true "flutter config --enable-windows-desktop"
    } else {
        Check-Result "Windows 桌面支持已启用" $false "未启用" "flutter config --enable-windows-desktop"
    }
} catch {
    Check-Result "Windows 桌面支持已启用" $false "无法检测" "请手动运行 flutter config"
}

# 6. 项目依赖
Write-Host "`n[6] 项目依赖 (pubspec.yaml)" -ForegroundColor Yellow
if (Test-Path "pubspec.yaml") {
    $pubGet = flutter pub get 2>&1
    if ($LASTEXITCODE -eq 0) {
        Check-Result "项目依赖安装成功" $true "flutter pub get 完成"
    } else {
        Check-Result "项目依赖安装成功" $false "flutter pub get 失败" "检查网络 / 国内镜像配置"
    }
} else {
    Check-Result "项目目录正确" $false "当前目录不是项目根目录" "cd 到 E:\flutter\desk-pic-view"
}

# 7. flutter doctor
Write-Host "`n[7] Flutter Doctor 综合检查" -ForegroundColor Yellow
Write-Host "  (运行 flutter doctor -v ...)" -ForegroundColor Gray
$doctor = flutter doctor -v 2>&1
$doctorLines = $doctor | Out-String
Write-Host $doctorLines

$issues = $doctorLines | Select-String "\[✗\]|\[!\]|\[x\]"
if ($issues) {
    Write-Host "  发现问题:" -ForegroundColor Yellow
    foreach ($i in $issues) { Write-Host "    $i" -ForegroundColor Red }
    $allPass = $false
} else {
    Write-Host "  ✓ 无重大问题" -ForegroundColor Green
}

# 总结
Write-Host "`n==============================================" -ForegroundColor Cyan
if ($allPass) {
    Write-Host "  🎉 环境检查全部通过！可以开始开发。" -ForegroundColor Green
    Write-Host "`n  运行项目:   flutter run -d windows"    -ForegroundColor White
    Write-Host "  编译发布:   flutter build windows --release" -ForegroundColor White
} else {
    Write-Host "  ⚠ 环境存在问题，请按上述提示修复。"   -ForegroundColor Yellow
}
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "按 Enter 退出"
