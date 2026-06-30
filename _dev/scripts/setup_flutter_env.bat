@echo off
chcp 65001 >nul 2>&1
echo ============================================
echo   PixelVault - Flutter 环境配置脚本
echo ============================================
echo.
set "SCRIPT_DIR=%~dp0"
set "PS1_FILE=%SCRIPT_DIR%setup_flutter_env.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%PS1_FILE%'"
pause
