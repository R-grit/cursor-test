@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "CLI_PS1=%SCRIPT_DIR%wsl_automation_cli.ps1"
set "AUTO_PAUSE=1"

if not exist "%CLI_PS1%" (
    echo.
    echo ERROR: Missing script: "%CLI_PS1%"
    set "RC=1"
    goto :done
)

for %%A in (%*) do (
    if /I "%%~A"=="--no-pause" set "AUTO_PAUSE=0"
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CLI_PS1%" %*
set "RC=%errorlevel%"

:done
echo.
if "%RC%"=="0" (
    echo Completed successfully, exit code: 0
) else (
    echo Failed, exit code: %RC%
)

if "%AUTO_PAUSE%"=="1" (
    echo.
    pause
)

endlocal & exit /b %RC%
