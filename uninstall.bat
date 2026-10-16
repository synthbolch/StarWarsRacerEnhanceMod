@echo off
rem Uninstall SWRacer Enhance Mod: remove added files and restore backups.
rem Usage: uninstall.bat "C:\Program Files (x86)\Steam\steamapps\common\Star Wars Episode I Racer"
setlocal
if "%~1"=="" (
    echo Usage: uninstall.bat "C:\Program Files (x86)\Steam\steamapps\common\Star Wars Episode I Racer"
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" -GameDir "%~1"
endlocal
