# ============================================================
# install_inno_setup.ps1 - 一键安装 Inno Setup 6
# 装完后 build_release.ps1 才能自动生成 Setup.exe
# ============================================================

$ErrorActionPreference = "Stop"

# 探测是否已安装
$paths = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path ${env:ProgramFiles} 'Inno Setup 6\ISCC.exe')
)
foreach ($p in $paths) {
    if (Test-Path $p) {
        Write-Host "Inno Setup 已安装: $p" -ForegroundColor Green
        exit 0
    }
}

Write-Host "==> 准备安装 Inno Setup 6 ..." -ForegroundColor Cyan

# 方案 1：winget（Win10/11 自带，最快）
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
    Write-Host "  使用 winget 安装" -ForegroundColor Gray
    winget install --id JRSoftware.InnoSetup -e --source winget
    if ($LASTEXITCODE -eq 0) {
        Write-Host "==> 安装完成 ✅" -ForegroundColor Green
        Write-Host "    现在可以跑：powershell -File .\build_release.ps1" -ForegroundColor Green
        exit 0
    }
    Write-Host "  winget 失败，回退到手动下载" -ForegroundColor Yellow
}

# 方案 2：下载官方便携版（无需管理员）
$url      = "https://jrsoftware.org/download.php/is.exe"
$destDir  = Join-Path $env:LOCALAPPDATA "InnoSetup"
$installer = Join-Path $destDir "is.exe"

if (-not (Test-Path $destDir)) { New-Item -ItemType Directory $destDir -Force | Out-Null }
if (-not (Test-Path $installer)) {
    Write-Host "  下载便携版: $url" -ForegroundColor Gray
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
}
Write-Host "  静默安装到 $destDir ..." -ForegroundColor Gray
$proc = Start-Process -FilePath $installer `
                       -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/CURRENTUSER","/DIR=`"$destDir`"" `
                       -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    throw "Inno Setup 安装失败 (exit=$($proc.ExitCode))"
}

# 便携版不会自动加到 PATH，把 ISCC 路径打印出来
$iscc = Join-Path $destDir "ISCC.exe"
if (Test-Path $iscc) {
    Write-Host "==> 安装完成 ✅" -ForegroundColor Green
    Write-Host "    ISCC 路径: $iscc" -ForegroundColor Green
    Write-Host "" -ForegroundColor Green
    Write-Host "    由于是便携版，build_release.ps1 默认探测不到。" -ForegroundColor Yellow
    Write-Host "    打包时请手动指定：" -ForegroundColor Yellow
    Write-Host "      powershell -File .\build_release.ps1 -InnoSetupExe `"$iscc`"" -ForegroundColor Yellow
} else {
    throw "安装后未找到 $iscc，请检查安装日志"
}
