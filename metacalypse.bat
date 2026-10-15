@echo off
setlocal EnableExtensions

if "%~1"=="" (
    echo Drag and drop files or folders onto this script.
    echo It creates cleaned copies without changing the originals.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0metacalypse.ps1" -TargetPaths %*
set "code=%errorlevel%"
echo.
pause
exit /b %code%
