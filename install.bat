@echo off
rem Install SWRacer Enhance Mod into the game directory.
rem Every overwritten file is backed up; use uninstall.bat to restore.
rem Usage: install.bat [--hd-8x] [--ai-realistic | --ai-clonewars] [--ui-hd] [--reshade] "C:\...\Star Wars Episode I Racer"
setlocal enabledelayedexpansion
set "HD8X="
set "AI="
set "EXTRA="
set "GAMEDIR="
:parse
if "%~1"=="" goto check
if /i "%~1"=="--hd-8x" ( set "HD8X=-Hd8x" & shift & goto parse )
if /i "%~1"=="--ai-realistic" ( set "AI=!AI! -AiRealistic" & shift & goto parse )
if /i "%~1"=="--ai-clonewars" ( set "AI=!AI! -AiClonewars" & shift & goto parse )
if /i "%~1"=="--ui-hd" ( set "EXTRA=!EXTRA! -UiHd" & shift & goto parse )
if /i "%~1"=="--reshade" ( set "EXTRA=!EXTRA! -Reshade" & shift & goto parse )
set "GAMEDIR=%~1"
:check
if "%GAMEDIR%"=="" (
    echo Usage: install.bat [--hd-8x] [--ai-realistic ^| --ai-clonewars] [--ui-hd] [--reshade] "C:\...\Star Wars Episode I Racer"
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -GameDir "%GAMEDIR%" %HD8X% %AI% %EXTRA%
endlocal
