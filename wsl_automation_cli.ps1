Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Show-Help {
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  wsl_automation.bat [menu|backup|restore|upgrade] [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --action <menu|backup|restore|upgrade>"
    Write-Host "  --distro <WSL distro name>"
    Write-Host "  --backup-dir <backup directory>"
    Write-Host "  --backup-file <backup tar path>"
    Write-Host "  --restore-as <new distro name>"
    Write-Host "  --install-path <import path>"
    Write-Host "  --target-lts <20.04|22.04|24.04...>"
    Write-Host "  --target-tls <alias of --target-lts>"
    Write-Host "  --skip-pre-upgrade-backup"
    Write-Host "  --force-pre-upgrade-backup"
    Write-Host "  --ask-pre-upgrade-backup"
    Write-Host "  --debug"
    Write-Host "  --no-pause"
    Write-Host ""
}

function Write-DebugLine {
    param(
        [bool]$Enabled,
        [string]$Name,
        [string]$Value
    )
    if ($Enabled) {
        Write-Host ("[DEBUG] {0}={1}" -f $Name, $Value)
    }
}

function Parse-Args {
    param([string[]]$RawArgs)

    $cfg = [ordered]@{
        Action                     = $null
        Distro                     = $null
        BackupDir                  = $null
        BackupFile                 = $null
        RestoreAs                  = $null
        InstallPath                = $null
        TargetLts                  = $null
        SkipPreUpgradeBackup       = $false
        ForcePreUpgradeBackup      = $false
        AskPreUpgradeBackup        = $false
        Debug                      = $false
        ShowHelp                   = $false
        CompatUpgradeOnClone       = $false
        CompatUpgradeCloneName     = $null
        CompatUpgradeClonePath     = $null
    }

    $i = 0
    if ($RawArgs.Count -gt 0) {
        switch ($RawArgs[0].ToLowerInvariant()) {
            "menu"    { $cfg.Action = "menu"; $i = 1 }
            "backup"  { $cfg.Action = "backup"; $i = 1 }
            "restore" { $cfg.Action = "restore"; $i = 1 }
            "upgrade" { $cfg.Action = "upgrade"; $i = 1 }
            default   { }
        }
    }

    while ($i -lt $RawArgs.Count) {
        $arg = $RawArgs[$i]
        switch ($arg.ToLowerInvariant()) {
            "--action" {
                $i++
                if ($i -ge $RawArgs.Count) { throw "Missing value for --action" }
                $cfg.Action = $RawArgs[$i]
            }
            "--distro" {
                $i++
                if ($i -ge $RawArgs.Count) { throw "Missing value for --distro" }
                $cfg.Distro = $RawArgs[$i]
            }
            "--backup-dir" {
                $i++
                if ($i -ge $RawArgs.Count) { throw "Missing value for --backup-dir" }
                $cfg.BackupDir = $RawArgs[$i]
            }
            "--backup-file" {
                $i++
                if ($i -ge $RawArgs.Count) { throw "Missing value for --backup-file" }
                $cfg.BackupFile = $RawArgs[$i]
            }
            "--restore-as" {
                $i++
                if ($i -ge $RawArgs.Count) { throw "Missing value for --restore-as" }
                $cfg.RestoreAs = $RawArgs[$i]
            }
            "--install-path" {
                $i++
                if ($i -ge $RawArgs.Count) { throw "Missing value for --install-path" }
                $cfg.InstallPath = $RawArgs[$i]
            }
            "--target-lts" {
                $i++
                if ($i -ge $RawArgs.Count) { throw "Missing value for --target-lts" }
                $cfg.TargetLts = $RawArgs[$i]
            }
            "--target-tls" {
                $i++
                if ($i -ge $RawArgs.Count) { throw "Missing value for --target-tls" }
                $cfg.TargetLts = $RawArgs[$i]
            }
            "--skip-pre-upgrade-backup" {
                $cfg.SkipPreUpgradeBackup = $true
                $cfg.AskPreUpgradeBackup = $false
            }
            "--force-pre-upgrade-backup" {
                $cfg.ForcePreUpgradeBackup = $true
                $cfg.SkipPreUpgradeBackup = $false
                $cfg.AskPreUpgradeBackup = $false
            }
            "--ask-pre-upgrade-backup" {
                $cfg.AskPreUpgradeBackup = $true
                $cfg.SkipPreUpgradeBackup = $false
                $cfg.ForcePreUpgradeBackup = $false
            }
            "--debug" { $cfg.Debug = $true }
            "--no-pause" { }
            "--preserve-current" { }
            "--in-place-upgrade" { }
            "--upgrade-on-clone" { $cfg.CompatUpgradeOnClone = $true }
            "--upgrade-clone-name" {
                $i++
                if ($i -ge $RawArgs.Count) { throw "Missing value for --upgrade-clone-name" }
                $cfg.CompatUpgradeCloneName = $RawArgs[$i]
            }
            "--upgrade-clone-path" {
                $i++
                if ($i -ge $RawArgs.Count) { throw "Missing value for --upgrade-clone-path" }
                $cfg.CompatUpgradeClonePath = $RawArgs[$i]
            }
            "--help" { $cfg.ShowHelp = $true }
            "-h" { $cfg.ShowHelp = $true }
            default {
                throw "Unknown argument: $arg"
            }
        }
        $i++
    }

    if ([string]::IsNullOrWhiteSpace($cfg.Action)) {
        $cfg.Action = "menu"
    }
    return $cfg
}

try {
    $cfg = Parse-Args -RawArgs $args
}
catch {
    Write-Host ""
    Write-Host ("ERROR: {0}" -f $_.Exception.Message) -ForegroundColor Red
    Show-Help
    exit 1
}

if ($cfg.ShowHelp) {
    Show-Help
    exit 0
}

if ($cfg.Action -eq "menu") {
    Write-Host ""
    Write-Host "==== WSL automation script (.bat) ===="
    Write-Host "[1] Backup distro"
    Write-Host "[2] Restore from backup"
    Write-Host "[3] Upgrade Ubuntu LTS with do-release-upgrade"
    $menuChoice = Read-Host "Choose action"
    Write-DebugLine -Enabled $cfg.Debug -Name "ActionMenu.choice" -Value $menuChoice
    switch ($menuChoice) {
        "1" { $cfg.Action = "backup" }
        "2" { $cfg.Action = "restore" }
        "3" {
            $cfg.Action = "upgrade"
            if ([string]::IsNullOrWhiteSpace($cfg.TargetLts)) {
                $targetInput = Read-Host "Target LTS version (optional, e.g. 24.04)"
                if (-not [string]::IsNullOrWhiteSpace($targetInput)) {
                    $cfg.TargetLts = $targetInput
                }
            }
        }
        default {
            Write-Host ""
            Write-Host "ERROR: Invalid menu choice." -ForegroundColor Red
            exit 1
        }
    }
}

Write-DebugLine -Enabled $cfg.Debug -Name "ACTION" -Value ([string]$cfg.Action)
Write-DebugLine -Enabled $cfg.Debug -Name "DISTRO" -Value ([string]$cfg.Distro)
Write-DebugLine -Enabled $cfg.Debug -Name "BACKUP_DIR" -Value ([string]$cfg.BackupDir)
Write-DebugLine -Enabled $cfg.Debug -Name "BACKUP_FILE" -Value ([string]$cfg.BackupFile)
Write-DebugLine -Enabled $cfg.Debug -Name "RESTORE_AS" -Value ([string]$cfg.RestoreAs)
Write-DebugLine -Enabled $cfg.Debug -Name "INSTALL_PATH" -Value ([string]$cfg.InstallPath)
Write-DebugLine -Enabled $cfg.Debug -Name "TARGET_LTS" -Value ([string]$cfg.TargetLts)
Write-DebugLine -Enabled $cfg.Debug -Name "SKIP_PRE_UPGRADE_BACKUP" -Value ([string]$cfg.SkipPreUpgradeBackup)
Write-DebugLine -Enabled $cfg.Debug -Name "FORCE_PRE_UPGRADE_BACKUP" -Value ([string]$cfg.ForcePreUpgradeBackup)
Write-DebugLine -Enabled $cfg.Debug -Name "ASK_PRE_UPGRADE_BACKUP" -Value ([string]$cfg.AskPreUpgradeBackup)
Write-DebugLine -Enabled $cfg.Debug -Name "UPGRADE_ON_CLONE" -Value ([string]$cfg.CompatUpgradeOnClone)

if ($cfg.CompatUpgradeOnClone) {
    Write-Host "WARN: --upgrade-on-clone is temporarily not supported in stable mode, using in-place upgrade."
}

if ($cfg.Action -eq "upgrade") {
    if (-not $cfg.SkipPreUpgradeBackup -and -not $cfg.ForcePreUpgradeBackup) {
        $ask = $cfg.AskPreUpgradeBackup
        if (-not $ask) {
            $ask = $true
        }
        if ($ask) {
            Write-Host ""
            $ans = Read-Host "Create pre-upgrade backup now? [y/N]"
            $cfg.SkipPreUpgradeBackup = -not ($ans -match "^(?i:y|yes)$")
            Write-DebugLine -Enabled $cfg.Debug -Name "BACKUP_CONFIRM" -Value $ans
            if ($cfg.SkipPreUpgradeBackup) {
                Write-Host "Pre-upgrade backup skipped by confirmation."
            }
        }
    }
    elseif ($cfg.ForcePreUpgradeBackup) {
        $cfg.SkipPreUpgradeBackup = $false
    }
}

$coreScript = Join-Path $PSScriptRoot "wsl_automation.ps1"
if (-not (Test-Path -LiteralPath $coreScript)) {
    Write-Host ""
    Write-Host "ERROR: Core script not found: $coreScript" -ForegroundColor Red
    exit 1
}

$invokeArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $coreScript,
    "-Action", [string]$cfg.Action
)

if (-not [string]::IsNullOrWhiteSpace($cfg.Distro)) { $invokeArgs += @("-DistroName", [string]$cfg.Distro) }
if (-not [string]::IsNullOrWhiteSpace($cfg.BackupDir)) { $invokeArgs += @("-BackupDirectory", [string]$cfg.BackupDir) }
if (-not [string]::IsNullOrWhiteSpace($cfg.BackupFile)) { $invokeArgs += @("-BackupFile", [string]$cfg.BackupFile) }
if (-not [string]::IsNullOrWhiteSpace($cfg.RestoreAs)) { $invokeArgs += @("-RestoreAs", [string]$cfg.RestoreAs) }
if (-not [string]::IsNullOrWhiteSpace($cfg.InstallPath)) { $invokeArgs += @("-InstallPath", [string]$cfg.InstallPath) }
if (-not [string]::IsNullOrWhiteSpace($cfg.TargetLts)) { $invokeArgs += @("-TargetLtsVersion", [string]$cfg.TargetLts) }
if ($cfg.SkipPreUpgradeBackup) { $invokeArgs += "-SkipPreUpgradeBackup" }

if ($cfg.Debug) {
    Write-Host "[DEBUG] INVOKE_CORE=powershell.exe $($invokeArgs -join ' ')"
}

& powershell.exe @invokeArgs
exit $LASTEXITCODE
