@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ACTION="
set "DISTRO="
set "BACKUP_DIR="
set "BACKUP_FILE="
set "RESTORE_AS="
set "INSTALL_PATH="
set "TARGET_LTS="
set "SKIP_PRE_UPGRADE_BACKUP=0"
set "PRE_UPGRADE_BACKUP_PROMPT=1"
set "AUTO_PAUSE=1"
set "DEBUG=0"
set "UPGRADE_ON_CLONE=0"
set "UPGRADE_CLONE_NAME="
set "UPGRADE_CLONE_PATH="
set "HELP_ONLY=0"
set "RET=0"

if /I "%~1"=="backup" (
    set "ACTION=backup"
    shift
) else if /I "%~1"=="restore" (
    set "ACTION=restore"
    shift
) else if /I "%~1"=="upgrade" (
    set "ACTION=upgrade"
    shift
) else if /I "%~1"=="menu" (
    set "ACTION=menu"
    shift
)

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--action" (
    set "ACTION=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--distro" (
    set "DISTRO=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--backup-dir" (
    set "BACKUP_DIR=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--backup-file" (
    set "BACKUP_FILE=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--restore-as" (
    set "RESTORE_AS=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--install-path" (
    set "INSTALL_PATH=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--target-lts" (
    set "TARGET_LTS=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--target-tls" (
    set "TARGET_LTS=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--upgrade-clone-name" (
    set "UPGRADE_CLONE_NAME=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--upgrade-clone-path" (
    set "UPGRADE_CLONE_PATH=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--skip-pre-upgrade-backup" (
    set "SKIP_PRE_UPGRADE_BACKUP=1"
    set "PRE_UPGRADE_BACKUP_PROMPT=0"
    shift
    goto parse_args
)
if /I "%~1"=="--force-pre-upgrade-backup" (
    set "SKIP_PRE_UPGRADE_BACKUP=0"
    set "PRE_UPGRADE_BACKUP_PROMPT=0"
    shift
    goto parse_args
)
if /I "%~1"=="--ask-pre-upgrade-backup" (
    set "PRE_UPGRADE_BACKUP_PROMPT=1"
    shift
    goto parse_args
)
if /I "%~1"=="--in-place-upgrade" (
    set "UPGRADE_ON_CLONE=0"
    shift
    goto parse_args
)
if /I "%~1"=="--preserve-current" (
    set "UPGRADE_ON_CLONE=0"
    shift
    goto parse_args
)
if /I "%~1"=="--upgrade-on-clone" (
    set "UPGRADE_ON_CLONE=1"
    shift
    goto parse_args
)
if /I "%~1"=="--no-pause" (
    set "AUTO_PAUSE=0"
    shift
    goto parse_args
)
if /I "%~1"=="--debug" (
    set "DEBUG=1"
    shift
    goto parse_args
)
if /I "%~1"=="--help" (
    set "HELP_ONLY=1"
    goto show_help
)
if /I "%~1"=="-h" (
    set "HELP_ONLY=1"
    goto show_help
)

echo.
echo ERROR: Unknown argument "%~1"
goto show_help

:args_done
if not defined ACTION set "ACTION=menu"
if defined TARGET_LTS call :NormalizeSimpleVar TARGET_LTS
if defined DISTRO (
    call :CanonicalizeDistro
    if errorlevel 1 (
        echo.
        echo ERROR: Distro "%DISTRO%" not found.
        set "RET=1"
        goto script_end
    )
)
call :DebugKV "ACTION" "%ACTION%"
call :DebugKV "DISTRO" "%DISTRO%"
call :DebugKV "BACKUP_DIR" "%BACKUP_DIR%"
call :DebugKV "BACKUP_FILE" "%BACKUP_FILE%"
call :DebugKV "RESTORE_AS" "%RESTORE_AS%"
call :DebugKV "INSTALL_PATH" "%INSTALL_PATH%"
call :DebugKV "TARGET_LTS" "%TARGET_LTS%"
call :DebugKV "SKIP_PRE_UPGRADE_BACKUP" "%SKIP_PRE_UPGRADE_BACKUP%"
call :DebugKV "PRE_UPGRADE_BACKUP_PROMPT" "%PRE_UPGRADE_BACKUP_PROMPT%"
call :DebugKV "AUTO_PAUSE" "%AUTO_PAUSE%"
call :DebugKV "DEBUG" "%DEBUG%"
call :DebugKV "UPGRADE_ON_CLONE" "%UPGRADE_ON_CLONE%"
call :DebugKV "UPGRADE_CLONE_NAME" "%UPGRADE_CLONE_NAME%"
call :DebugKV "UPGRADE_CLONE_PATH" "%UPGRADE_CLONE_PATH%"

where wsl.exe >nul 2>nul
if errorlevel 1 (
    echo.
    echo ERROR: wsl.exe not found. Run this script on Windows with WSL installed.
    set "RET=1"
    goto script_end
)

if /I "%ACTION%"=="backup" goto run_backup
if /I "%ACTION%"=="restore" goto run_restore
if /I "%ACTION%"=="upgrade" goto run_upgrade
if /I "%ACTION%"=="menu" goto run_menu

echo.
echo ERROR: Unsupported action "%ACTION%"
set "RET=1"
goto show_help

:run_backup
call :ActionBackup
set "RET=%errorlevel%"
goto script_end

:run_restore
call :ActionRestore
set "RET=%errorlevel%"
goto script_end

:run_upgrade
call :ActionUpgrade
set "RET=%errorlevel%"
goto script_end

:run_menu
call :ActionMenu
set "RET=%errorlevel%"
goto script_end

:show_help
echo.
echo Usage:
echo   wsl_automation.bat [menu^|backup^|restore^|upgrade] [options]
echo.
echo Options:
echo   --action ^<menu^|backup^|restore^|upgrade^>
echo   --distro ^<WSL distro name^>
echo   --backup-dir ^<directory for .tar backups^>
echo   --backup-file ^<specific .tar file to restore^>
echo   --restore-as ^<new distro name when restore^>
echo   --install-path ^<path used by wsl --import^>
echo   --target-lts ^<20.04^|22.04^|24.04...^>
echo   --target-tls ^<alias of --target-lts^>
echo   --skip-pre-upgrade-backup
echo   --force-pre-upgrade-backup
echo   --ask-pre-upgrade-backup
echo   --preserve-current ^<default, in-place upgrade on current distro^>
echo   --in-place-upgrade ^<alias of --preserve-current^>
echo   --upgrade-on-clone ^<upgrade imported clone; keep source unchanged^>
echo   --upgrade-clone-name ^<new distro name for safe upgrade clone^>
echo   --upgrade-clone-path ^<install path for safe upgrade clone^>
echo   --no-pause
echo   --debug
echo.
echo Examples:
echo   wsl_automation.bat
echo   wsl_automation.bat backup --distro Ubuntu --backup-dir "D:\WSLBackups"
echo   wsl_automation.bat restore --backup-dir "D:\WSLBackups"
echo   wsl_automation.bat upgrade --distro Ubuntu --target-lts 24.04 --backup-dir "D:\WSLBackups"
echo   wsl_automation.bat upgrade --distro Ubuntu-20.04 --target-lts 22.04 --force-pre-upgrade-backup
echo   wsl_automation.bat upgrade --distro Ubuntu-20.04 --target-lts 22.04 --preserve-current
echo   wsl_automation.bat upgrade --distro Ubuntu-20.04 --target-lts 22.04 --upgrade-on-clone
echo   wsl_automation.bat backup --debug
if "%HELP_ONLY%"=="1" (
    set "RET=0"
) else (
    set "RET=1"
)
goto script_end

:script_end
if not defined RET set "RET=0"
call :FinalizeAndExit %RET%

:FinalizeAndExit
set "FINAL_CODE=%~1"
echo.
if "%FINAL_CODE%"=="0" (
    echo Completed successfully, exit code: 0
) else (
    echo Failed, exit code: %FINAL_CODE%
)
if "%AUTO_PAUSE%"=="1" (
    echo.
    pause
)
endlocal & exit /b %FINAL_CODE%

:Debug
if not "%DEBUG%"=="1" exit /b 0
echo [DEBUG] %~1
exit /b 0

:DebugKV
if not "%DEBUG%"=="1" exit /b 0
echo [DEBUG] %~1=%~2
exit /b 0

:NormalizeSimpleVar
set "NV_NAME=%~1"
if not defined NV_NAME exit /b 1
call set "NV_VALUE=%%%NV_NAME%%%"
if not defined NV_VALUE exit /b 0
for /f "usebackq delims=" %%n in (`powershell -NoProfile -Command "$s=[string]$env:NV_VALUE; if($null -eq $s){''} else { (($s -replace '[\x00-\x1F\x7F]','' -replace '\p{Cf}','').Trim()) }"`) do set "%NV_NAME%=%%n"
exit /b 0

:StripOuterQuotes
set "SOQ_NAME=%~1"
if not defined SOQ_NAME exit /b 1
if not defined %SOQ_NAME% exit /b 0
call set "SOQ_VAL=%%%SOQ_NAME%%%"
if defined SOQ_VAL (
    if "%SOQ_VAL:~0,1%"=="\"" (
        if "%SOQ_VAL:~-1%"=="\"" (
            call set "%SOQ_NAME%=%%SOQ_VAL:~1,-1%%"
        )
    )
)
exit /b 0

:CanonicalizeDistro
if not defined DISTRO exit /b 1
call :NormalizeSimpleVar DISTRO
set "CANONICAL_DISTRO="
for /f "usebackq delims=" %%d in (`powershell -NoProfile -Command "$ErrorActionPreference='SilentlyContinue'; function Clean([string]$x){ if($null -eq $x){ return '' }; return (($x -replace '[\x00-\x1F\x7F]','' -replace '\p{Cf}','').Trim()) }; $target=Clean($env:DISTRO); if(-not $target){exit 0}; $items=wsl.exe -l -q | ForEach-Object { Clean($_.ToString()) } | Where-Object { $_ }; $m=$items | Where-Object { $_.Equals($target,[System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1; if($m){$m}"`) do set "CANONICAL_DISTRO=%%d"
if not defined CANONICAL_DISTRO exit /b 1
set "DISTRO=%CANONICAL_DISTRO%"
call :DebugKV "CanonicalizeDistro" "%DISTRO%"
call :DebugHexVar DISTRO
exit /b 0

:DebugHexVar
if not "%DEBUG%"=="1" exit /b 0
set "DH_NAME=%~1"
if not defined DH_NAME exit /b 0
call set "DH_VAL=%%%DH_NAME%%%"
if not defined DH_VAL (
    echo [DEBUG] %DH_NAME%.hex=
    exit /b 0
)
set "DH_HEX="
for /f "usebackq delims=" %%h in (`powershell -NoProfile -Command "$s=[string]$env:DH_VAL; (($s.ToCharArray() | ForEach-Object { '{0:X4}' -f [int][char]$_ }) -join '-')"`) do set "DH_HEX=%%h"
echo [DEBUG] %DH_NAME%.hex=%DH_HEX%
exit /b 0

:NormalizeBackupDir
if not defined BACKUP_DIR set "BACKUP_DIR=%USERPROFILE%\WSL-Backups"
exit /b 0

:GetTimestamp
set "%~1="
for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "(Get-Date).ToString('yyyyMMdd_HHmmss')"`) do set "%~1=%%t"
if not defined %~1 exit /b 1
exit /b 0

:GetTimestampCompact
set "%~1="
for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "(Get-Date).ToString('yyyyMMddHHmm')"`) do set "%~1=%%t"
if not defined %~1 exit /b 1
exit /b 0

:SanitizeName
set "RAW_NAME=%~1"
set "%~2="
for /f "usebackq delims=" %%s in (`powershell -NoProfile -Command "$env:RAW_NAME -replace '[^a-zA-Z0-9._-]','_'"`) do set "%~2=%%s"
if not defined %~2 exit /b 1
exit /b 0

:ListDistros
set "DISTRO_COUNT=0"
call :Debug "ListDistros: querying wsl.exe -l -q"
for /f "usebackq delims=" %%d in (`powershell -NoProfile -Command "$ErrorActionPreference='Stop'; wsl.exe -l -q | ForEach-Object { ($_.ToString() -replace [char]0,'').Trim() } | Where-Object { $_ }"`) do (
    if not "%%d"=="" (
        set /a DISTRO_COUNT+=1
        set "DISTRO_!DISTRO_COUNT!=%%d"
        call :Debug "ListDistros item[!DISTRO_COUNT!]=%%d"
    )
)
call :DebugKV "ListDistros.count" "!DISTRO_COUNT!"
exit /b 0

:ResolveDistro
if defined DISTRO goto validate_distro

call :ListDistros
if "!DISTRO_COUNT!"=="0" (
    echo.
    echo ERROR: No WSL distro found.
    exit /b 1
)

echo.
echo ==== Available WSL distros ====
for /l %%i in (1,1,!DISTRO_COUNT!) do echo [%%i] !DISTRO_%%i!

:choose_distro
set "IDX="
set /p "IDX=Select distro number: "
if not defined IDX goto choose_distro
2>nul set /a IDXN=IDX
if errorlevel 1 goto choose_distro
if !IDXN! LSS 1 goto choose_distro
if !IDXN! GTR !DISTRO_COUNT! goto choose_distro
call set "DISTRO=%%DISTRO_%IDXN%%%"
if not defined DISTRO goto choose_distro
call :CanonicalizeDistro
if errorlevel 1 goto choose_distro
call :DebugKV "ResolveDistro.selected_index" "%IDXN%"
call :DebugKV "ResolveDistro.selected_name" "%DISTRO%"
exit /b 0

:validate_distro
call :CanonicalizeDistro
if errorlevel 1 (
    echo.
    echo ERROR: Distro "%DISTRO%" not found.
    exit /b 1
)
call :DebugKV "ResolveDistro.validate_name" "%DISTRO%"
call :DebugKV "ResolveDistro.validate_found" "1"
exit /b 0

:BackupCurrentDistro
call :NormalizeBackupDir
call :DebugKV "BackupCurrentDistro.distro" "%DISTRO%"
call :DebugKV "BackupCurrentDistro.backup_dir" "%BACKUP_DIR%"
if not exist "%BACKUP_DIR%" (
    mkdir "%BACKUP_DIR%" >nul 2>nul
    if errorlevel 1 (
        echo.
        echo ERROR: Cannot create backup directory "%BACKUP_DIR%".
        exit /b 1
    )
)

call :GetTimestamp TS
if errorlevel 1 (
    echo.
    echo ERROR: Failed to generate timestamp.
    exit /b 1
)

call :SanitizeName "%DISTRO%" SAFE_DISTRO
if errorlevel 1 (
    echo.
    echo ERROR: Failed to sanitize distro name.
    exit /b 1
)

set "ARCHIVE_PATH=%BACKUP_DIR%\%SAFE_DISTRO%_%TS%.tar"
call :DebugKV "BackupCurrentDistro.archive_path" "%ARCHIVE_PATH%"

echo.
echo ==== Backup ====
echo Stopping distro "%DISTRO%" for consistency...
wsl.exe --terminate "%DISTRO%" >nul 2>nul

echo Exporting to: %ARCHIVE_PATH%
wsl.exe --export "%DISTRO%" "%ARCHIVE_PATH%"
set "EXPORT_RC=%errorlevel%"
call :DebugKV "BackupCurrentDistro.export_rc" "%EXPORT_RC%"
if not "%EXPORT_RC%"=="0" (
    echo.
    echo ERROR: wsl --export failed with exit code %EXPORT_RC%.
    exit /b 1
)
if not exist "%ARCHIVE_PATH%" (
    echo.
    echo ERROR: backup archive was not created: %ARCHIVE_PATH%
    exit /b 1
)
for %%A in ("%ARCHIVE_PATH%") do set "ARCHIVE_SIZE=%%~zA"
call :DebugKV "BackupCurrentDistro.archive_size" "%ARCHIVE_SIZE%"
if "%ARCHIVE_SIZE%"=="0" (
    echo.
    echo ERROR: backup archive is empty: %ARCHIVE_PATH%
    exit /b 1
)

set "META_PATH=%ARCHIVE_PATH%.meta.json"
powershell -NoProfile -Command "$obj=[ordered]@{distro=$env:DISTRO;createdAt=(Get-Date).ToString('o');archive=$env:ARCHIVE_PATH;host=$env:COMPUTERNAME};$obj|ConvertTo-Json|Out-File -LiteralPath $env:META_PATH -Encoding utf8" >nul 2>nul

echo Backup completed: %ARCHIVE_PATH%
exit /b 0

:ResolveBackupFile
if defined BACKUP_FILE goto validate_backup_file

call :NormalizeBackupDir
call :DebugKV "ResolveBackupFile.input_backup_dir" "%BACKUP_DIR%"
if not exist "%BACKUP_DIR%" (
    echo.
    echo ERROR: Backup directory not found: "%BACKUP_DIR%"
    exit /b 1
)

set "BACKUP_COUNT=0"
for /f "usebackq delims=" %%f in (`powershell -NoProfile -Command "$ErrorActionPreference='Stop';Get-ChildItem -LiteralPath $env:BACKUP_DIR -Filter '*.tar' -File -Recurse | Sort-Object LastWriteTime -Descending | ForEach-Object { $_.FullName }"`) do (
    set /a BACKUP_COUNT+=1
    set "BACKUP_!BACKUP_COUNT!=%%f"
)
call :DebugKV "ResolveBackupFile.count" "!BACKUP_COUNT!"

if "!BACKUP_COUNT!"=="0" (
    echo.
    echo ERROR: No .tar backups found under "%BACKUP_DIR%".
    exit /b 1
)

echo.
echo ==== Available backups ====
for /l %%i in (1,1,!BACKUP_COUNT!) do echo [%%i] !BACKUP_%%i!

:choose_backup
set "BIDX="
set /p "BIDX=Select backup number: "
if not defined BIDX goto choose_backup
2>nul set /a BIDXN=BIDX
if errorlevel 1 goto choose_backup
if !BIDXN! LSS 1 goto choose_backup
if !BIDXN! GTR !BACKUP_COUNT! goto choose_backup
call set "BACKUP_FILE=%%BACKUP_%BIDXN%%%"
if not defined BACKUP_FILE goto choose_backup
call :DebugKV "ResolveBackupFile.selected_index" "%BIDXN%"
call :DebugKV "ResolveBackupFile.selected_file" "%BACKUP_FILE%"
exit /b 0

:validate_backup_file
if not exist "%BACKUP_FILE%" (
    echo.
    echo ERROR: Backup file not found: "%BACKUP_FILE%"
    exit /b 1
)
call :DebugKV "ResolveBackupFile.direct_file" "%BACKUP_FILE%"
exit /b 0

:ResolveRestoreNameAndPath
for %%I in ("%BACKUP_FILE%") do set "SOURCE_BASENAME=%%~nI"
set "SOURCE_NAME="
for /f "usebackq delims=" %%s in (`powershell -NoProfile -Command "$n=$env:SOURCE_BASENAME; if($n -match '^(.*)_\d{8}_\d{6}$'){ $matches[1] } else { $n }"`) do set "SOURCE_NAME=%%s"
if not defined SOURCE_NAME set "SOURCE_NAME=%SOURCE_BASENAME%"

if not defined RESTORE_AS (
    call :GetTimestampCompact TS2
    if errorlevel 1 set "TS2=restored"
    set "DEFAULT_RESTORE=%SOURCE_NAME%-restored-%TS2%"
    set /p "RESTORE_AS=Restored distro name [%DEFAULT_RESTORE%]: "
    if not defined RESTORE_AS set "RESTORE_AS=%DEFAULT_RESTORE%"
)

if not defined INSTALL_PATH (
    set "DEFAULT_INSTALL=%LOCALAPPDATA%\WSL\Distros\%RESTORE_AS%"
    set /p "INSTALL_PATH=Restore install path [%DEFAULT_INSTALL%]: "
    if not defined INSTALL_PATH set "INSTALL_PATH=%DEFAULT_INSTALL%"
)
call :DebugKV "ResolveRestoreNameAndPath.restore_as" "%RESTORE_AS%"
call :DebugKV "ResolveRestoreNameAndPath.install_path" "%INSTALL_PATH%"

exit /b 0

:EnsureRestoreTargetReady
set "RESTORE_EXISTS="
call :ListDistros
for /l %%i in (1,1,!DISTRO_COUNT!) do (
    if /I "!DISTRO_%%i!"=="%RESTORE_AS%" set "RESTORE_EXISTS=1"
)
call :DebugKV "EnsureRestoreTargetReady.restore_exists" "%RESTORE_EXISTS%"

if defined RESTORE_EXISTS (
    set "UNREG_CONFIRM="
    set /p "UNREG_CONFIRM=Distro %RESTORE_AS% already exists. Unregister first? [y/N]: "
    if /I not "%UNREG_CONFIRM%"=="y" if /I not "%UNREG_CONFIRM%"=="yes" (
        echo.
        echo ERROR: Restore cancelled because target distro exists.
        exit /b 1
    )
    wsl.exe --unregister "%RESTORE_AS%"
    if errorlevel 1 (
        echo.
        echo ERROR: Failed to unregister "%RESTORE_AS%".
        exit /b 1
    )
)

if not exist "%INSTALL_PATH%" (
    mkdir "%INSTALL_PATH%" >nul 2>nul
    if errorlevel 1 (
        echo.
        echo ERROR: Cannot create install path "%INSTALL_PATH%".
        exit /b 1
    )
) else (
    dir /b "%INSTALL_PATH%" 2>nul | findstr . >nul
    if not errorlevel 1 (
        echo.
        echo ERROR: Install path is not empty: "%INSTALL_PATH%"
        exit /b 1
    )
)
exit /b 0

:BuildUpgradeCloneInfo
if defined UPGRADE_CLONE_NAME (
    set "CLONE_DISTRO=%UPGRADE_CLONE_NAME%"
) else (
    call :GetTimestampCompact CLONE_TS
    if errorlevel 1 set "CLONE_TS=clone"
    set "CLONE_TAG=%TARGET_LTS%"
    if not defined CLONE_TAG set "CLONE_TAG=next"
    set "CLONE_TAG=%CLONE_TAG:.=%"
    set "CLONE_DISTRO=!DISTRO!-lts!CLONE_TAG!-!CLONE_TS!"
)
if defined UPGRADE_CLONE_PATH (
    set "CLONE_INSTALL_PATH=%UPGRADE_CLONE_PATH%"
) else (
    set "CLONE_INSTALL_PATH=%LOCALAPPDATA%\WSL\Distros\!CLONE_DISTRO!"
)
call :DebugKV "BuildUpgradeCloneInfo.clone_distro" "%CLONE_DISTRO%"
call :DebugKV "BuildUpgradeCloneInfo.clone_install_path" "%CLONE_INSTALL_PATH%"
exit /b 0

:EnsureUpgradeCloneTargetReady
set "CLONE_EXISTS="
call :ListDistros
for /l %%i in (1,1,!DISTRO_COUNT!) do (
    if /I "!DISTRO_%%i!"=="%CLONE_DISTRO%" set "CLONE_EXISTS=1"
)
if defined CLONE_EXISTS (
    echo.
    echo ERROR: Upgrade clone distro already exists: "%CLONE_DISTRO%"
    echo Use --upgrade-clone-name to provide a different name.
    exit /b 1
)

if not exist "%CLONE_INSTALL_PATH%" (
    mkdir "%CLONE_INSTALL_PATH%" >nul 2>nul
    if errorlevel 1 (
        echo.
        echo ERROR: Cannot create clone install path "%CLONE_INSTALL_PATH%".
        exit /b 1
    )
) else (
    dir /b "%CLONE_INSTALL_PATH%" 2>nul | findstr . >nul
    if not errorlevel 1 (
        echo.
        echo ERROR: Clone install path is not empty: "%CLONE_INSTALL_PATH%"
        echo Use --upgrade-clone-path to provide an empty directory.
        exit /b 1
    )
)
exit /b 0

:ImportBackupAsUpgradeClone
if not exist "%ARCHIVE_PATH%" (
    echo.
    echo ERROR: Backup archive for clone import not found: "%ARCHIVE_PATH%"
    exit /b 1
)
echo.
echo ==== Create upgrade clone ====
echo Importing backup "%ARCHIVE_PATH%" as "%CLONE_DISTRO%"...
wsl.exe --import "%CLONE_DISTRO%" "%CLONE_INSTALL_PATH%" "%ARCHIVE_PATH%" --version 2
set "CLONE_IMPORT_RC=%errorlevel%"
call :DebugKV "ImportBackupAsUpgradeClone.rc" "%CLONE_IMPORT_RC%"
if not "%CLONE_IMPORT_RC%"=="0" (
    echo.
    echo ERROR: Failed to import upgrade clone, exit code %CLONE_IMPORT_RC%.
    exit /b 1
)
echo Upgrade clone created: %CLONE_DISTRO%
exit /b 0

:EnsureDistroAccessible
call :CanonicalizeDistro
if errorlevel 1 (
    echo.
    echo ERROR: Distro "%DISTRO%" not found.
    exit /b 1
)
powershell -NoProfile -Command "$d=[string]$env:DISTRO; & wsl.exe -d $d -u root -- bash -lc 'true' > $null; exit $LASTEXITCODE" >nul 2>nul
set "DISTRO_CHECK_RC=%errorlevel%"
call :DebugKV "EnsureDistroAccessible.rc" "%DISTRO_CHECK_RC%"
if "%DISTRO_CHECK_RC%"=="0" exit /b 0

echo.
echo ERROR: Cannot execute commands in distro "%DISTRO%".
echo Diagnostic output:
powershell -NoProfile -Command "$d=[string]$env:DISTRO; & wsl.exe -d $d -u root -- bash -lc 'echo ok'; exit $LASTEXITCODE"
echo Please check this distro is healthy: wsl -d "%DISTRO%" -- bash -lc "echo ok"
exit /b 1

:RunWslRoot
set "WSL_CMD=%~1"
call :CanonicalizeDistro
if errorlevel 1 (
    echo.
    echo ERROR: Distro "%DISTRO%" not found before root command.
    exit /b 1
)
call :DebugKV "RunWslRoot.distro" "%DISTRO%"
powershell -NoProfile -Command "$d=[string]$env:DISTRO; $c=[string]$env:WSL_CMD; & wsl.exe -d $d -u root -- bash -lc $c; exit $LASTEXITCODE"
set "WSL_RC=%errorlevel%"
call :DebugKV "RunWslRoot.rc" "%WSL_RC%"
if "%WSL_RC%"=="0" exit /b 0
exit /b 1

:GetUbuntuVersion
set "UBUNTU_VERSION="
call :CanonicalizeDistro
if errorlevel 1 exit /b 1
call :DebugKV "GetUbuntuVersion.distro" "%DISTRO%"
for /f "delims=" %%v in ('wsl.exe -d "%DISTRO%" -u root -- bash -lc "grep '^VERSION_ID=' /etc/os-release 2>/dev/null | head -n 1 | cut -d= -f2 | tr -d '\"'" 2^>nul') do set "UBUNTU_VERSION=%%v"
if not defined UBUNTU_VERSION (
    for /f "delims=" %%v in ('wsl.exe -d "%DISTRO%" -u root -- bash -lc "lsb_release -rs 2>/dev/null" 2^>nul') do set "UBUNTU_VERSION=%%v"
)
if not defined UBUNTU_VERSION (
    for /f "usebackq delims=" %%v in (`powershell -NoProfile -Command "$d=[string]$env:DISTRO; if($d -match '(?i)ubuntu[-_ ]?([0-9]{2}\.[0-9]{2})'){ $matches[1] }"`) do set "UBUNTU_VERSION=%%v"
    if defined UBUNTU_VERSION call :Debug "GetUbuntuVersion fallback from distro name"
)
call :NormalizeSimpleVar UBUNTU_VERSION
call :StripOuterQuotes UBUNTU_VERSION
call :NormalizeSimpleVar UBUNTU_VERSION
call :DebugKV "GetUbuntuVersion.value" "%UBUNTU_VERSION%"
if not defined UBUNTU_VERSION exit /b 1
echo %UBUNTU_VERSION% | findstr /r "^[0-9][0-9]*\.[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo.
    echo ERROR: Failed to parse Ubuntu version from distro "%DISTRO%".
    exit /b 1
)
exit /b 0

:AssertUbuntuDistro
set "UBUNTU_ID="
call :CanonicalizeDistro
if errorlevel 1 exit /b 1
if /I "%DISTRO:~0,6%"=="Ubuntu" (
    call :Debug "AssertUbuntuDistro fallback matched distro name prefix"
    exit /b 0
)
for /f "delims=" %%i in ('wsl.exe -d "%DISTRO%" -u root -- bash -lc "grep '^ID=' /etc/os-release 2>/dev/null | head -n 1 | cut -d= -f2 | tr -d '\"' | tr 'A-Z' 'a-z'" 2^>nul') do set "UBUNTU_ID=%%i"
call :NormalizeSimpleVar UBUNTU_ID
call :DebugKV "AssertUbuntuDistro.id" "%UBUNTU_ID%"
if /I "%UBUNTU_ID%"=="ubuntu" exit /b 0

echo.
echo ERROR: Distro "%DISTRO%" is not Ubuntu or os-release cannot be read.
exit /b 1

:VersionToInt
set "TMP_VER=%~1"
set "TMP_INT="
for /f %%n in ('powershell -NoProfile -Command "([int](([version]$env:TMP_VER).Major*100 + ([version]$env:TMP_VER).Minor))"') do set "TMP_INT=%%n"
if not defined TMP_INT exit /b 1
set "%~2=%TMP_INT%"
exit /b 0

:RunReleaseUpgradeOnce
echo.
echo ==== Run do-release-upgrade ====
call :CanonicalizeDistro
if errorlevel 1 (
    echo.
    echo ERROR: Distro "%DISTRO%" not found before do-release-upgrade.
    set "%~1=1"
    exit /b 0
)
call :DebugKV "RunReleaseUpgradeOnce.distro" "%DISTRO%"
wsl.exe -d "%DISTRO%" -u root -- bash -lc "export DEBIAN_FRONTEND=noninteractive; export RELEASE_UPGRADER_NO_SCREEN=1; do-release-upgrade -m server -f DistUpgradeViewNonInteractive"
set "UPGRADE_EXIT_CODE=%errorlevel%"
call :DebugKV "RunReleaseUpgradeOnce.rc" "%UPGRADE_EXIT_CODE%"
wsl.exe --terminate "%DISTRO%" >nul 2>nul
timeout /t 3 /nobreak >nul
set "%~1=%UPGRADE_EXIT_CODE%"
exit /b 0

:ActionBackup
call :Debug "ActionBackup: start"
call :ResolveDistro
if errorlevel 1 exit /b 1

if not defined BACKUP_DIR (
    set /p "BACKUP_DIR=Backup directory [%USERPROFILE%\WSL-Backups]: "
)
if not defined BACKUP_DIR set "BACKUP_DIR=%USERPROFILE%\WSL-Backups"
call :DebugKV "ActionBackup.backup_dir" "%BACKUP_DIR%"

call :BackupCurrentDistro
exit /b %errorlevel%

:ActionRestore
call :Debug "ActionRestore: start"
if not defined BACKUP_FILE (
    if not defined BACKUP_DIR (
        set /p "BACKUP_DIR=Backup directory [%USERPROFILE%\WSL-Backups]: "
    )
    if not defined BACKUP_DIR set "BACKUP_DIR=%USERPROFILE%\WSL-Backups"
)

call :ResolveBackupFile
if errorlevel 1 exit /b 1

call :ResolveRestoreNameAndPath
if errorlevel 1 exit /b 1

call :EnsureRestoreTargetReady
if errorlevel 1 exit /b 1
call :DebugKV "ActionRestore.backup_file" "%BACKUP_FILE%"
call :DebugKV "ActionRestore.restore_as" "%RESTORE_AS%"
call :DebugKV "ActionRestore.install_path" "%INSTALL_PATH%"

echo.
echo ==== Restore ====
echo Importing backup "%BACKUP_FILE%" as distro "%RESTORE_AS%"...
wsl.exe --import "%RESTORE_AS%" "%INSTALL_PATH%" "%BACKUP_FILE%" --version 2
set "IMPORT_RC=%errorlevel%"
call :DebugKV "ActionRestore.import_rc" "%IMPORT_RC%"
if not "%IMPORT_RC%"=="0" (
    echo.
    echo ERROR: wsl --import failed with exit code %IMPORT_RC%.
    exit /b 1
)

echo Restore completed: %RESTORE_AS%
echo Note: imported distro may default to root user.
exit /b 0

:ActionUpgrade
call :Debug "ActionUpgrade: start"
call :ResolveDistro
if errorlevel 1 exit /b 1
call :EnsureDistroAccessible
if errorlevel 1 exit /b 1

set "UPGRADE_SOURCE_DISTRO=%DISTRO%"
set "UPGRADE_SKIP_BACKUP=%SKIP_PRE_UPGRADE_BACKUP%"
set "UPGRADE_BACKUP_PROMPT=%PRE_UPGRADE_BACKUP_PROMPT%"
call :DebugKV "ActionUpgrade.source_distro" "%UPGRADE_SOURCE_DISTRO%"
call :DebugKV "ActionUpgrade.upgrade_on_clone" "%UPGRADE_ON_CLONE%"
call :DebugKV "ActionUpgrade.backup_prompt" "%UPGRADE_BACKUP_PROMPT%"

if "%UPGRADE_ON_CLONE%"=="1" (
    call :AssertUbuntuDistro
    if errorlevel 1 exit /b 1

    if not defined BACKUP_DIR (
        set /p "BACKUP_DIR=Backup directory for preserved source [%USERPROFILE%\WSL-Backups]: "
    )
    if not defined BACKUP_DIR set "BACKUP_DIR=%USERPROFILE%\WSL-Backups"
    call :DebugKV "ActionUpgrade.preserve.backup_dir" "!BACKUP_DIR!"
    if "%UPGRADE_SKIP_BACKUP%"=="1" (
        echo.
        echo INFO: --skip-pre-upgrade-backup ignored because --upgrade-on-clone requires backup.
    )

    call :BackupCurrentDistro
    if errorlevel 1 exit /b 1

    call :BuildUpgradeCloneInfo
    if errorlevel 1 exit /b 1
    call :EnsureUpgradeCloneTargetReady
    if errorlevel 1 exit /b 1
    call :ImportBackupAsUpgradeClone
    if errorlevel 1 exit /b 1

    set "DISTRO=!CLONE_DISTRO!"
    set "UPGRADE_SKIP_BACKUP=1"
    set "UPGRADE_BACKUP_PROMPT=0"
    echo.
    echo Source distro remains unchanged: !UPGRADE_SOURCE_DISTRO!
    echo Upgrade will run on cloned distro: !DISTRO!
)
if "%UPGRADE_ON_CLONE%"=="0" (
    echo.
    echo In-place upgrade mode on distro: %DISTRO%
    echo Existing users, home configs and installed software are kept in this distro.
    if "!UPGRADE_SKIP_BACKUP!"=="0" (
        if "!UPGRADE_BACKUP_PROMPT!"=="1" (
            echo.
            set "BACKUP_CONFIRM="
            set /p "BACKUP_CONFIRM=Create pre-upgrade backup now? [y/N]: "
            call :NormalizeSimpleVar BACKUP_CONFIRM
            call :DebugKV "ActionUpgrade.backup_confirm" "!BACKUP_CONFIRM!"
            if /I not "!BACKUP_CONFIRM!"=="y" if /I not "!BACKUP_CONFIRM!"=="yes" (
                set "UPGRADE_SKIP_BACKUP=1"
                echo Pre-upgrade backup skipped by confirmation.
            )
        )
    )
)

call :AssertUbuntuDistro
if errorlevel 1 exit /b 1

call :GetUbuntuVersion
if errorlevel 1 (
    echo.
    echo ERROR: Failed to detect Ubuntu version.
    exit /b 1
)
echo Current Ubuntu version: %UBUNTU_VERSION%
call :DebugKV "ActionUpgrade.current_version" "%UBUNTU_VERSION%"
call :DebugKV "ActionUpgrade.effective_skip_backup" "%UPGRADE_SKIP_BACKUP%"

if "%UPGRADE_SKIP_BACKUP%"=="0" (
    if not defined BACKUP_DIR (
        set /p "BACKUP_DIR=Pre-upgrade backup directory [%USERPROFILE%\WSL-Backups]: "
    )
    if not defined BACKUP_DIR set "BACKUP_DIR=%USERPROFILE%\WSL-Backups"
    call :BackupCurrentDistro
    if errorlevel 1 exit /b 1
) else (
    echo Skipped pre-upgrade backup.
)
call :DebugKV "ActionUpgrade.target_lts" "%TARGET_LTS%"

echo.
echo ==== Prepare release upgrade ====
call :Debug "ActionUpgrade step: apt-get update"
call :RunWslRoot "export DEBIAN_FRONTEND=noninteractive; apt-get update"
if errorlevel 1 goto upgrade_prepare_failed
call :Debug "ActionUpgrade step: apt-get -y upgrade"
call :RunWslRoot "export DEBIAN_FRONTEND=noninteractive; apt-get -y upgrade"
if errorlevel 1 goto upgrade_prepare_failed
call :Debug "ActionUpgrade step: apt-get -y dist-upgrade"
call :RunWslRoot "export DEBIAN_FRONTEND=noninteractive; apt-get -y dist-upgrade"
if errorlevel 1 goto upgrade_prepare_failed
call :Debug "ActionUpgrade step: apt-get -y autoremove"
call :RunWslRoot "export DEBIAN_FRONTEND=noninteractive; apt-get -y autoremove"
if errorlevel 1 goto upgrade_prepare_failed
call :Debug "ActionUpgrade step: apt-get -y install update-manager-core"
call :RunWslRoot "export DEBIAN_FRONTEND=noninteractive; apt-get -y install update-manager-core"
if errorlevel 1 goto upgrade_prepare_failed
call :Debug "ActionUpgrade step: set Prompt=lts"
call :RunWslRoot "if [ -f /etc/update-manager/release-upgrades ]; then sed -i 's/^Prompt=.*/Prompt=lts/' /etc/update-manager/release-upgrades; else echo 'Prompt=lts' > /etc/update-manager/release-upgrades; fi"
if errorlevel 1 goto upgrade_prepare_failed
goto after_prepare

:upgrade_prepare_failed
echo.
echo ERROR: Failed while preparing system for release upgrade.
exit /b 1

:after_prepare
if not defined TARGET_LTS goto one_step_upgrade
call :NormalizeSimpleVar TARGET_LTS

echo %TARGET_LTS% | findstr /r "^[0-9][0-9]\.04$" >nul
if errorlevel 1 (
    echo.
    echo ERROR: --target-lts must look like 20.04 / 22.04 / 24.04
    exit /b 1
)

call :VersionToInt "%TARGET_LTS%" TARGET_INT
if errorlevel 1 (
    echo.
    echo ERROR: Invalid target version: %TARGET_LTS%
    exit /b 1
)
call :VersionToInt "%UBUNTU_VERSION%" CURRENT_INT
if errorlevel 1 (
    echo.
    echo ERROR: Invalid current version: %UBUNTU_VERSION%
    exit /b 1
)

if %CURRENT_INT% GTR %TARGET_INT% (
    echo.
    echo ERROR: Current version %UBUNTU_VERSION% is newer than target %TARGET_LTS%.
    exit /b 1
)
if %CURRENT_INT% EQU %TARGET_INT% (
    echo Already on target version: %TARGET_LTS%
    exit /b 0
)

:upgrade_loop
if %CURRENT_INT% GEQ %TARGET_INT% goto target_reached
set "PREV_VERSION=%UBUNTU_VERSION%"
echo Upgrading from %PREV_VERSION% to target %TARGET_LTS% ...
call :RunReleaseUpgradeOnce STEP_EXIT
call :GetUbuntuVersion
if errorlevel 1 (
    echo.
    echo ERROR: Cannot detect Ubuntu version after upgrade.
    exit /b 1
)
if /I "%UBUNTU_VERSION%"=="%PREV_VERSION%" (
    if "%STEP_EXIT%"=="0" (
        echo.
        echo ERROR: do-release-upgrade completed but version did not change.
        exit /b 1
    ) else (
        echo.
        echo ERROR: do-release-upgrade failed or no newer LTS available.
        exit /b 1
    )
)
echo Version changed: %PREV_VERSION% ^> %UBUNTU_VERSION%
call :VersionToInt "%UBUNTU_VERSION%" CURRENT_INT
if errorlevel 1 (
    echo.
    echo ERROR: Invalid upgraded version: %UBUNTU_VERSION%
    exit /b 1
)
if %CURRENT_INT% GTR %TARGET_INT% (
    echo.
    echo ERROR: Upgraded to %UBUNTU_VERSION%, which is higher than target %TARGET_LTS%.
    exit /b 1
)
goto upgrade_loop

:target_reached
echo Target reached: %UBUNTU_VERSION%
exit /b 0

:one_step_upgrade
set "PREV_ONE_STEP=%UBUNTU_VERSION%"
call :RunReleaseUpgradeOnce STEP_EXIT
call :GetUbuntuVersion
if errorlevel 1 (
    echo.
    echo ERROR: Cannot detect Ubuntu version after upgrade.
    exit /b 1
)
if /I "%UBUNTU_VERSION%"=="%PREV_ONE_STEP%" (
    if "%STEP_EXIT%"=="0" (
        echo No version change detected; may already be newest available LTS.
        exit /b 0
    ) else (
        echo.
        echo ERROR: Upgrade failed and version stayed at %PREV_ONE_STEP%.
        exit /b 1
    )
)
echo Upgrade completed: %PREV_ONE_STEP% ^> %UBUNTU_VERSION%
exit /b 0

:ActionMenu
echo.
echo ==== WSL automation script (.bat) ====
echo [1] Backup distro
echo [2] Restore from backup
echo [3] Upgrade Ubuntu LTS with do-release-upgrade
set "MENU_CHOICE="
set /p "MENU_CHOICE=Choose action: "
call :DebugKV "ActionMenu.choice" "%MENU_CHOICE%"

if "%MENU_CHOICE%"=="1" (
    set "ACTION=backup"
    set "DISTRO="
    set "BACKUP_DIR="
    call :ActionBackup
    set "MENU_RC=!errorlevel!"
    exit /b !MENU_RC!
)
if "%MENU_CHOICE%"=="2" (
    set "ACTION=restore"
    call :ActionRestore
    set "MENU_RC=!errorlevel!"
    exit /b !MENU_RC!
)
if "%MENU_CHOICE%"=="3" (
    set "ACTION=upgrade"
    set "DISTRO="
    if not defined TARGET_LTS (
        set /p "TARGET_LTS=Target LTS version (optional, e.g. 24.04): "
    )
    call :ActionUpgrade
    set "MENU_RC=!errorlevel!"
    exit /b !MENU_RC!
)

echo.
echo ERROR: Invalid menu choice.
exit /b 1
