@echo off
rem Change the texture pack of an already-installed SWRacer Enhance Mod.
rem Usage: change_textures.bat <pack> "C:\...\Star Wars Episode I Racer"
rem   pack: default ^| 8x ^| realistic ^| clonewars ^| list
setlocal
if "%~1"=="" (
    echo Usage: change_textures.bat ^<pack^> "C:\...\Star Wars Episode I Racer"
    echo   pack: default ^| 8x ^| realistic ^| clonewars ^| list
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0change_textures.ps1" -Pack "%~1" -GameDir "%~2"
endlocal
