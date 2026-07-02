param(
    [string]$FlutterVersion = "3.29.3",
    [string]$InstallDir    = "$env:USERPROFILE\flutter_sdk",
    [string]$JavaVersion   = "17",
    [bool]  $UseMirror    = $true
)

$ErrorActionPreference = "Stop"

function Write-Color($msg, $color = "White") {
    Write-Host "`n$msg" -ForegroundColor $color
}

function Test-Command($cmd) {
    try { Get-Command $cmd -ErrorAction Stop | Out-Null; return $true }
    catch { return $false }
}

# ============================================================
# 带进度条的下载函数
# ============================================================
function Invoke-DownloadWithProgress {
    param(
        [string]$Url,
        [string]$OutFile,
        [string]$Label = "下载"
    )

    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Method = "GET"
    $req.UserAgent = "PowerShell PicGuide Setup"
    $req.AllowAutoRedirect = $true

    try {
        $resp = $req.GetResponse()
        $totalBytes = $resp.ContentLength64
        $respStream = $resp.GetResponseStream()

        if ($totalBytes -gt 0) {
            $totalMB = "{0:N1}" -f ($totalBytes / 1MB)
            Write-Host "`n  [$Label] 文件大小: $totalMB MB" -ForegroundColor Gray
        } else {
            Write-Host "`n  [$Label] 开始下载 (无法获取文件大小)..." -ForegroundColor Yellow
        }

        $outStream = [System.IO.File]::Create($OutFile)
        $buffer = New-Object byte[] 65536
        $read = 0
        $downloaded = [long]0
        $lastPercent = -1

        do {
            $read = $respStream.Read($buffer, 0, $buffer.Length)
            if ($read -gt 0) {
                $outStream.Write($buffer, 0, $read)
                $downloaded += $read

                if ($totalBytes -gt 0) {
                    $percent = [math]::Floor($downloaded * 100 / $totalBytes)
                    if ($percent -ne $lastPercent) {
                        $mb = "{0:N1}" -f ($downloaded / 1MB)
                        $barLen = 30
                        $filled = [math]::Floor($barLen * $percent / 100)
                        $bar = ("#" * $filled) + ("-" * ($barLen - $filled))
                        Write-Host ("`r  [$Label] [{0}] {1,3}%  ({2}/{3} MB)   " -f $bar, $percent, $mb, $totalMB) -NoNewline -ForegroundColor Cyan
                        $lastPercent = $percent
                    }
                } else {
                    $mb = "{0:N1}" -f ($downloaded / 1MB)
                    Write-Host ("`r  [$Label] 已下载: {0} MB                              " -f $mb) -NoNewline -ForegroundColor Cyan
                }
            }
        } while ($read -gt 0)

        $outStream.Close()
        $respStream.Close()
        $resp.Close()
        $finalMB = "{0:N1}" -f ($downloaded / 1MB)
        Write-Host ""
        Write-Host "  OK $Label 完成 (共 $finalMB MB)" -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "  X $Label 失败: $_" -ForegroundColor Red
        throw $_
    }
}

# ============================================================
# 第 1 步: 检查 PowerShell 执行策略
# ============================================================
Write-Color "==============================================" "Cyan"
Write-Color "  PicGuide - Flutter 环境配置脚本"         "Cyan"
Write-Color "==============================================" "Cyan"
Write-Color "目标 Flutter 版本: $FlutterVersion"
Write-Color "安装目录: $InstallDir"
if ($UseMirror) {
    Write-Color "下载镜像: 国内镜像 (flutter-io.cn / ghproxy.com)" "Green"
} else {
    Write-Color "下载镜像: 官方源 (googleapis.com / github.com)" "Yellow"
}
Write-Color "==============================================" "Cyan"

Write-Color "`n[1/8] 检查 PowerShell 执行策略..." "Yellow"
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq "Restricted" -or $policy -eq "AllSigned") {
    Write-Color "  执行策略受限，正在设置为 RemoteSigned..." "Yellow"
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Color "  OK 执行策略已设置" "Green"
} else {
    Write-Color "  OK 执行策略: $policy (无需修改)" "Green"
}

# ============================================================
# 第 2 步: 检查并安装 Git
# ============================================================
Write-Color "`n[2/8] 检查 Git..." "Yellow"
if (Test-Command "git") {
    $gitVer = git --version
    Write-Color "  OK $gitVer" "Green"
} else {
    Write-Color "  X 未检测到 Git，正在下载安装..." "Red"
    if ($UseMirror) {
        $gitUrl = "https://ghproxy.com/https://github.com/git-for-windows/git/releases/download/v2.49.0.windows.1/Git-2.49.0-64-bit.exe"
        Write-Color "  使用国内镜像加速 (ghproxy.com)..." "Gray"
    } else {
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.49.0.windows.1/Git-2.49.0-64-bit.exe"
    }
    $gitInstaller = "$env:TEMP\git_installer.exe"
    try {
        Invoke-DownloadWithProgress -Url $gitUrl -OutFile $gitInstaller -Label "Git"
        Start-Process -FilePath $gitInstaller -Args "/VERYSILENT /NORESTART" -Wait
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        Write-Color "  OK Git 安装完成" "Green"
    } catch {
        Write-Color "  X Git 下载失败，请手动安装: https://git-scm.com/download/win" "Red"
        Read-Host "安装 Git 后按 Enter 继续"
    }
}

# ============================================================
# 第 3 步: 下载并安装 Flutter SDK
# ============================================================
Write-Color "`n[3/8] 检查 Flutter SDK..." "Yellow"

$flutterExe = "$InstallDir\bin\flutter.bat"

if (Test-Path $flutterExe) {
    Write-Color "  OK Flutter 已安装在: $InstallDir" "Green"
} else {
    Write-Color "  Flutter 未安装，正在下载 $FlutterVersion ..." "Yellow"

    if (!(Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    }

    if ($UseMirror) {
        $flutterUrl = "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_${FlutterVersion}-stable.zip"
        Write-Color "  使用国内镜像加速 (flutter-io.cn)..." "Gray"
    } else {
        $flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_${FlutterVersion}-stable.zip"
    }
    $flutterZip  = "$env:TEMP\flutter_sdk.zip"

    try {
        Invoke-DownloadWithProgress -Url $flutterUrl -OutFile $flutterZip -Label "Flutter SDK"
        Write-Color "  下载完成，正在解压..." "Green"

        $parentDir = Split-Path $InstallDir
        Expand-Archive -Path $flutterZip -DestinationPath $parentDir -Force

        $extractedPath = "$parentDir\flutter"
        if ((Test-Path $extractedPath) -and ($InstallDir -ne $extractedPath)) {
            if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
            Move-Item $extractedPath $InstallDir
        }

        Remove-Item $flutterZip -Force -ErrorAction SilentlyContinue
        Write-Color "  OK Flutter SDK 安装完成: $InstallDir" "Green"
    }
    catch {
        Write-Color "  X 下载失败! 可能原因: 网络问题 / 需翻墙" "Red"
        Write-Color "  备用方案: 手动下载后解压到指定目录" "Yellow"
        Write-Color "  下载地址: https://docs.flutter.dev/get-started/install/windows" "Yellow"
        Write-Color "  或国内镜像: https://flutter.cn/docs/get-started/install/windows" "Yellow"
        exit 1
    }
}

# ============================================================
# 将 Flutter 加入 PATH (用户级，永久生效)
# ============================================================
Write-Color "  配置 Flutter 环境变量..." "Yellow"
$flutterBin = "$InstallDir\bin"
try {
    $currentUserPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentUserPath -notlike "*$flutterBin*") {
        $newPath = "$currentUserPath;$flutterBin"
        if ($newPath.Length -gt 1800) {
            Write-Host "  ⚠  PATH 变量较长 ($($newPath.Length) 字符)，写入可能失败" -ForegroundColor Yellow
        }
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:Path += ";$flutterBin"
        Write-Color "  OK Flutter 已加入 PATH (用户级)" "Green"
    } else {
        Write-Color "  OK Flutter 已在 PATH 中" "Green"
    }
} catch {
    Write-Host "  ⚠  无法自动写入 PATH: $_" -ForegroundColor Yellow
    Write-Host "    请手动将以下路径加入用户级 PATH 环境变量：" -ForegroundColor Yellow
    Write-Host "    $flutterBin" -ForegroundColor Cyan
    Write-Host "    操作步骤: 设置 → 关于 → 高级系统设置 → 环境变量 → 用户变量 Path → 编辑 → 新建" -ForegroundColor Gray
}

# ============================================================
# 第 4 步: 配置国内镜像
# ============================================================
Write-Color "`n[4/8] 配置 Flutter 国内镜像源..." "Yellow"
try {
    $pubEnv = [System.Environment]::GetEnvironmentVariable("PUB_HOSTED_URL", "User")
    if (-not $pubEnv) {
        [System.Environment]::SetEnvironmentVariable("PUB_HOSTED_URL",       "https://pub.flutter-io.cn", "User")
        [System.Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "User")
        $env:PUB_HOSTED_URL       = "https://pub.flutter-io.cn"
        $env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
        Write-Color "  OK 已配置国内镜像 (pub.flutter-io.cn)" "Green"
    } else {
        Write-Color "  OK 镜像已配置: $pubEnv" "Green"
    }
} catch {
    Write-Host "  ⚠  无法自动配置镜像环境变量: $_" -ForegroundColor Yellow
    Write-Host "    请手动设置以下用户级环境变量：" -ForegroundColor Yellow
    Write-Host "    PUB_HOSTED_URL       = https://pub.flutter-io.cn" -ForegroundColor Cyan
    Write-Host "    FLUTTER_STORAGE_BASE_URL = https://storage.flutter-io.cn" -ForegroundColor Cyan
}

# ============================================================
# 第 5 步: 检查 Visual Studio
# ============================================================
Write-Color "`n[5/8] 检查 Visual Studio (Windows 桌面开发必需)..." "Yellow"

$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsFound  = $false

if (Test-Path $vsWhere) {
    $vsInstalls = & $vsWhere -products "*" -requires Microsoft.VisualStudio.Component.Windows10SDK -latest -format json 2>$null | ConvertFrom-Json
    if ($vsInstalls) {
        $vsFound = $true
        $vsPath  = $vsInstalls.installationPath
        Write-Color "  OK Visual Studio 已安装: $vsPath" "Green"
    }
}

if (-not $vsFound) {
    Write-Color "  X 未检测到 Visual Studio (含 Windows 10/11 SDK)" "Red"
    Write-Color "  Flutter Windows 桌面开发必须安装 Visual Studio 2022" "Yellow"
    Write-Color "  正在打开下载页面..." "Yellow"
    Start-Process "https://visualstudio.microsoft.com/zh-hans/downloads/"

    Write-Color "`n  请手动安装 Visual Studio 2022 Community (免费)，并勾选:" "Yellow"
    Write-Color "    [x] 使用 C++ 的桌面开发" "Yellow"
    Write-Color "    [x] Windows 10/11 SDK" "Yellow"
    Write-Color "`n  安装完成后，重新运行本脚本。" "Cyan"

    $continue = Read-Host "是否已安装 Visual Studio 并勾选了 C++ 桌面开发? (y/n)"
    if ($continue -ne "y") {
        Write-Color "  请先完成 Visual Studio 安装后再继续。" "Red"
        exit 1
    }
}

# ============================================================
# 第 6 步: 运行 flutter doctor
# ============================================================
Write-Color "`n[6/8] 运行 flutter doctor (首次运行会下载 Dart/工具链)..." "Yellow"
Write-Color "  这可能需要几分钟，请耐心等待..." "Gray"

$flutterCmd = "$InstallDir\bin\flutter.bat"
& $flutterCmd --version | Out-Null
& $flutterCmd doctor -v

Write-Color "`n  flutter doctor 完成，请检查上方输出。" "Green"

# ============================================================
# 第 7 步: 启用 Windows 桌面支持
# ============================================================
Write-Color "`n[7/8] 启用 Windows 桌面支持..." "Yellow"
& $flutterCmd config --enable-windows-desktop
Write-Color "  OK Windows 桌面支持已启用" "Green"

# ============================================================
# 第 8 步: 为项目安装依赖
# ============================================================
Write-Color "`n[8/8] 为 PicGuide 项目安装依赖..." "Yellow"

$projectDir = Split-Path $MyInvocation.MyCommand.Path
Set-Location $projectDir

Write-Color "  项目目录: $projectDir" "Gray"
Write-Color "  执行 flutter pub get ..." "Yellow"
& $flutterCmd pub get

if ($LASTEXITCODE -eq 0) {
    Write-Color "  OK 依赖安装完成" "Green"
} else {
    Write-Color "  X 依赖安装失败，请检查网络或镜像配置" "Red"
}

# ============================================================
# 完成提示
# ============================================================
Write-Color "`n==============================================" "Cyan"
Write-Color "  Flutter 环境配置完成!" "Green"
Write-Color "==============================================" "Cyan"
Write-Color ""
Write-Color "下一步操作:" "Yellow"
Write-Color "  1. 重新打开 PowerShell 或终端 (使 PATH 生效)" "White"
Write-Color "  2. 进入项目目录:" "White"
Write-Color "     cd $PSScriptRoot" "Gray"
Write-Color "  3. 运行项目:" "White"
Write-Color "     flutter run -d windows" "Gray"
Write-Color "  4. 编译 Release 版本:" "White"
Write-Color "     flutter build windows --release" "Gray"
Write-Color ""
Write-Color "Flutter SDK 路径: $InstallDir" "Gray"
Write-Color "如需卸载: 直接删除 $InstallDir 并清理 PATH 中的对应条目" "Gray"
Write-Color "==============================================" "Cyan"

Read-Host "`n按 Enter 退出"

