@echo off
setlocal EnableDelayedExpansion

:: ==============================================================================
:: WSL Automation Manager
:: Provides Backup, Restore, and OS Upgrade capabilities for WSL distributions.
:: ==============================================================================
set "SCRIPT_VERSION=1.0.1"
set "SCRIPT_DATE=2024-03-04"

:: Debug Mode Handling
set "DEBUG=0"
if /I "%~1"=="--debug" set "DEBUG=1"
if /I "%~1"=="-d" set "DEBUG=1"

if "%DEBUG%"=="1" (
    echo [DEBUG] SCRIPT_VERSION = %SCRIPT_VERSION%
    echo [DEBUG] Running in DEBUG mode. All variables and commands will be verbose.
    @echo on
)

:: Ensure WSL is installed
wsl --status >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] WSL is not installed or not functioning properly.
    pause
    exit /b 1
)

:MENU
cls
echo ========================================================
echo        WSL Automation Manager (v%SCRIPT_VERSION%)
echo ========================================================
echo.
echo   1. Backup WSL Distribution
echo   2. Restore WSL Distribution
echo   3. Upgrade Ubuntu WSL (Seamless LTS Upgrade)
echo   4. Exit
echo.
set /p "CHOICE=Please select an option (1-4): "

if "%CHOICE%"=="1" goto BACKUP
if "%CHOICE%"=="2" goto RESTORE
if "%CHOICE%"=="3" goto UPGRADE
if "%CHOICE%"=="4" exit /b 0

echo [ERROR] Invalid choice.
timeout /t 2 >nul
goto MENU

:: ==========================================
:: 1. BACKUP WSL
:: ==========================================
:BACKUP
echo.
echo === Backup WSL Distribution ===
call :GET_DISTROS
if %idx%==0 (
    echo [ERROR] No WSL distributions found.
    pause
    goto MENU
)

echo Available Distributions:
for /L %%i in (1,1,%idx%) do echo   %%i. !DIST_%%i!
echo.
set /p "dist_choice=Select distribution to backup (1-%idx%): "
set "TARGET_DIST=!DIST_%dist_choice%!"

if "%TARGET_DIST%"=="" (
    echo [ERROR] Invalid selection.
    pause
    goto MENU
)

set /p "BACKUP_DIR=Enter backup directory path (e.g., D:\WSL_Backups): "
if not exist "%BACKUP_DIR%" (
    echo [INFO] Directory does not exist. Creating "%BACKUP_DIR%"...
    mkdir "%BACKUP_DIR%"
)

:: Generate Timestamp robustly
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set TIMESTAMP=%datetime:~0,4%%datetime:~4,2%%datetime:~6,2%_%datetime:~8,2%%datetime:~10,2%%datetime:~12,2%
set "BACKUP_FILE=%BACKUP_DIR%\%TARGET_DIST%_backup_%TIMESTAMP%.tar"

echo.
echo [INFO] Starting backup of "%TARGET_DIST%"...
echo [INFO] Target file: %BACKUP_FILE%
echo [INFO] Please wait, this may take several minutes...
wsl --export "%TARGET_DIST%" "%BACKUP_FILE%"

if %ERRORLEVEL% EQU 0 (
    echo [SUCCESS] Backup completed successfully!
) else (
    echo [ERROR] Backup failed.
)
pause
goto MENU

:: ==========================================
:: 2. RESTORE WSL
:: ==========================================
:RESTORE
echo.
echo === Restore WSL Distribution ===
set /p "BACKUP_DIR=Enter directory path where backups (.tar) are stored: "
if not exist "%BACKUP_DIR%" (
    echo [ERROR] Directory "%BACKUP_DIR%" does not exist.
    pause
    goto MENU
)

set "b_idx=0"
echo.
echo Available Backup Files:
for %%F in ("%BACKUP_DIR%\*.tar") do (
    set /a b_idx+=1
    set "BACKUP_!b_idx!=%%~fF"
    echo   !b_idx!. %%~nxF
)

if %b_idx%==0 (
    echo [ERROR] No .tar backup files found in "%BACKUP_DIR%".
    pause
    goto MENU
)

echo.
set /p "backup_choice=Select backup to restore (1-%b_idx%): "
set "TARGET_BACKUP=!BACKUP_%backup_choice%!"

if "%TARGET_BACKUP%"=="" (
    echo [ERROR] Invalid selection.
    pause
    goto MENU
)

echo.
set /p "NEW_DIST_NAME=Enter a name for the restored WSL instance (e.g., Ubuntu-Restored): "
set /p "INSTALL_DIR=Enter installation directory for the virtual disk (e.g., C:\WSL\%NEW_DIST_NAME%): "

if not exist "%INSTALL_DIR%" (
    echo [INFO] Creating installation directory "%INSTALL_DIR%"...
    mkdir "%INSTALL_DIR%"
)

echo.
echo [INFO] Restoring "%TARGET_BACKUP%" as "%NEW_DIST_NAME%"...
echo [INFO] Installation path: %INSTALL_DIR%
echo [INFO] Please wait, this may take several minutes...
wsl --import "%NEW_DIST_NAME%" "%INSTALL_DIR%" "%TARGET_BACKUP%"

if %ERRORLEVEL% EQU 0 (
    echo [SUCCESS] Restore completed successfully!
    echo [INFO] You can launch it using: wsl -d %NEW_DIST_NAME%
) else (
    echo [ERROR] Restore failed.
)
pause
goto MENU

:: ==========================================
:: 3. UPGRADE WSL (Seamless)
:: ==========================================
:UPGRADE
echo.
echo === Upgrade Ubuntu WSL ===
echo [INFO] This process uses the official Ubuntu In-Place LTS Upgrader.
echo [INFO] It natively preserves your user directory, configurations, installed packages,
echo [INFO] and VSCode/Cursor plugins to provide a truly seamless upgrade experience.
echo.
call :GET_DISTROS
if %idx%==0 (
    echo [ERROR] No WSL distributions found.
    pause
    goto MENU
)

echo Available Distributions:
for /L %%i in (1,1,%idx%) do echo   %%i. !DIST_%%i!
echo.
set /p "dist_choice=Select distribution to upgrade (1-%idx%): "
set "TARGET_DIST=!DIST_%dist_choice%!"

if "%TARGET_DIST%"=="" (
    echo [ERROR] Invalid selection.
    pause
    goto MENU
)

echo.
set /p "ASK_BACKUP=Do you want to backup "%TARGET_DIST%" before upgrading? (Highly Recommended) (Y/N): "
if /I "%ASK_BACKUP%"=="Y" (
    set /p "BACKUP_DIR=Enter backup directory path: "
    if not exist "!BACKUP_DIR!" mkdir "!BACKUP_DIR!"
    for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
    set TIMESTAMP=!datetime:~0,4!!datetime:~4,2!!datetime:~6,2!_!datetime:~8,2!!datetime:~10,2!!datetime:~12,2!
    set "BACKUP_FILE=!BACKUP_DIR!\!TARGET_DIST!_pre_upgrade_!TIMESTAMP!.tar"
    echo [INFO] Backing up to "!BACKUP_FILE!"...
    wsl --export "%TARGET_DIST%" "!BACKUP_FILE!"
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Backup failed. Aborting upgrade to protect your data.
        pause
        goto MENU
    )
    echo [SUCCESS] Backup completed successfully.
)

echo.
echo [INFO] Preparing for upgrade...
echo [INFO] Step 1: Ensuring upgrader is set to LTS mode...
wsl -d "%TARGET_DIST%" -u root -- bash -c "sed -i 's/^Prompt=.*$/Prompt=lts/' /etc/update-manager/release-upgrades"

echo [INFO] Step 2: Updating current packages (this preserves your existing software)...
wsl -d "%TARGET_DIST%" -u root -- bash -c "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to update current packages. Please check your network and apt sources.
    pause
    goto MENU
)

echo.
echo [INFO] Step 3: Starting Ubuntu Release Upgrade...
echo [INFO] NOTE: This will upgrade to the next LTS version (e.g., 20.04 -^> 22.04).
echo [INFO] You may be prompted inside the Linux environment. Follow the on-screen instructions.
wsl -d "%TARGET_DIST%" -u root -- bash -c "do-release-upgrade"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCESS] Upgrade script executed successfully!
    echo [INFO] All user data, VSCode/Cursor servers, and packages have been preserved.
    echo [INFO] Verifying new OS version:
    wsl -d "%TARGET_DIST%" -- bash -c "cat /etc/os-release | grep PRETTY_NAME"
) else (
    echo.
    echo [ERROR] The upgrade process encountered an error.
)
pause
goto MENU

:: ==========================================
:: HELPER: GET DISTRIBUTIONS
:: ==========================================
:GET_DISTROS
set "idx=0"
:: Use PowerShell to properly decode UTF-16LE from WSL and completely strip any hidden whitespace or carriage returns
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$ErrorActionPreference='SilentlyContinue'; (wsl --list --quiet) -replace '\x00', '' -replace '\r', '' -replace '\n', '' | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }"`) do (
    set "dist=%%A"
    if not "!dist!"=="" (
        set /a idx+=1
        set "DIST_!idx!=!dist!"
    )
)
exit /b