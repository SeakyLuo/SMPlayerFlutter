@echo off
setlocal
chcp 65001 >nul
for %%I in ("%COMSPEC%") do set "CMD_DIR=%%~dpI"
for %%I in ("%CMD_DIR%..") do set "SystemRoot=%%~fI"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\scripts\package-windows.ps1" %*
exit /b %errorlevel%
