@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-context-menu.ps1"
set "code=%errorlevel%"
echo.
pause
exit /b %code%
