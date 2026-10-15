@echo off
setlocal EnableExtensions

set "BASE=HKCU\Software\Classes"
set "MENU=METACALYPSE"

reg delete "%BASE%\*\shell\%MENU%" /f >nul 2>&1
reg delete "%BASE%\Directory\shell\%MENU%" /f >nul 2>&1
reg delete "%BASE%\Directory\Background\shell\%MENU%" /f >nul 2>&1
reg delete "%BASE%\*\shell\KillMetadata" /f >nul 2>&1
reg delete "%BASE%\Directory\shell\KillMetadata" /f >nul 2>&1
reg delete "%BASE%\Directory\Background\shell\KillMetadata" /f >nul 2>&1

echo Context menu removed.
pause
exit /b 0
