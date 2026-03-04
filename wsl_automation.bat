@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "CLI_PS1=%SCRIPT_DIR%wsl_automation_cli.ps1"
set "AUTO_PAUSE=1"
set "DEBUG=0"
set "RUNNER_VERSION=stable-ps-runner-2"
set "GIT_SHA=unknown"

for /f %%G in ('git -C "%SCRIPT_DIR%" rev-parse --short HEAD 2^>nul') do set "GIT_SHA=%%G"
set "WSL_AUTOMATION_COMMIT=%GIT_SHA%"

if not exist "%CLI_PS1%" (
    echo.
    echo ERROR: Missing script: "%CLI_PS1%"
    set "RC=1"
    goto :done
)

for %%A in (%*) do (
    if /I "%%~A"=="--no-pause" set "AUTO_PAUSE=0"
    if /I "%%~A"=="--debug" set "DEBUG=1"
)

echo [INFO] BAT_RUNNER_VERSION=%RUNNER_VERSION% COMMIT=%WSL_AUTOMATION_COMMIT%
if "%DEBUG%"=="1" echo [DEBUG] BAT_RUNNER_VERSION=%RUNNER_VERSION%
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
