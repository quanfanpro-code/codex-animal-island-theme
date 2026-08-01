@echo off
chcp 65001 >nul
where pwsh.exe >nul 2>nul
if errorlevel 1 (
  echo 本主题包需要 PowerShell 7。请先安装 PowerShell 7 后再运行。
  pause
  exit /b 1
)
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\安装狸克手机主题.ps1"
if errorlevel 1 pause
