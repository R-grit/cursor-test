param(
    [ValidateSet("menu", "backup", "restore", "upgrade")]
    [string]$Action = "menu",
    [string]$DistroName,
    [string]$BackupDirectory,
    [string]$BackupFile,
    [string]$RestoreAs,
    [string]$InstallPath,
    [string]$TargetLtsVersion,
    [switch]$SkipPreUpgradeBackup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "==== $Title ===="
}

function Get-DefaultBackupDirectory {
    return (Join-Path $env:USERPROFILE "WSL-Backups")
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-SafeFileName {
    param([Parameter(Mandatory = $true)][string]$Name)
    return ($Name -replace "[^a-zA-Z0-9._-]", "_")
}

function Get-WslDistros {
    $raw = @(& wsl.exe -l -q 2>$null)
    $distros = @()
    foreach ($line in $raw) {
        $trimmed = $line.Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
            $distros += $trimmed
        }
    }
    return $distros
}

function Select-FromList {
    param(
        [Parameter(Mandatory = $true)][array]$Items,
        [Parameter(Mandatory = $true)][scriptblock]$LabelBuilder,
        [string]$Prompt = "Select item by number"
    )

    if ($Items.Count -eq 0) {
        throw "No items available to select."
    }

    for ($i = 0; $i -lt $Items.Count; $i++) {
        $label = & $LabelBuilder $Items[$i]
        Write-Host ("[{0}] {1}" -f ($i + 1), $label)
    }

    while ($true) {
        $choice = Read-Host $Prompt
        $idx = 0
        if ([int]::TryParse($choice, [ref]$idx) -and $idx -ge 1 -and $idx -le $Items.Count) {
            return $Items[$idx - 1]
        }
        Write-Host "Invalid selection, please enter a valid number."
    }
}

function Resolve-DistroName {
    param([string]$InputName)
    $distros = Get-WslDistros
    if ($distros.Count -eq 0) {
        throw "No WSL distributions found."
    }

    if (-not [string]::IsNullOrWhiteSpace($InputName)) {
        if ($distros -contains $InputName) {
            return $InputName
        }
        throw "Distribution '$InputName' not found."
    }

    Write-Section "Available WSL distributions"
    return (Select-FromList -Items $distros -LabelBuilder { param($x) $x } -Prompt "Choose distro")
}

function New-WslCommandArgs {
    param(
        [Parameter(Mandatory = $true)][string]$Distro,
        [Parameter(Mandatory = $true)][string]$Command,
        [switch]$AsRoot
    )

    $args = @("-d", $Distro)
    if ($AsRoot) {
        $args += @("-u", "root")
    }
    $args += @("--", "bash", "-lc", $Command)
    return ,$args
}

function Invoke-WslCapture {
    param(
        [Parameter(Mandatory = $true)][string]$Distro,
        [Parameter(Mandatory = $true)][string]$Command,
        [switch]$AsRoot
    )

    $wslArgs = New-WslCommandArgs -Distro $Distro -Command $Command -AsRoot:$AsRoot
    $output = & wsl.exe @wslArgs 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output -join "`n").Trim()
    if ($exitCode -ne 0) {
        throw "WSL command failed (exit $exitCode): $Command`n$text"
    }
    return $text
}

function Invoke-WslLive {
    param(
        [Parameter(Mandatory = $true)][string]$Distro,
        [Parameter(Mandatory = $true)][string]$Command,
        [switch]$AsRoot,
        [switch]$AllowFailure
    )

    $wslArgs = New-WslCommandArgs -Distro $Distro -Command $Command -AsRoot:$AsRoot
    & wsl.exe @wslArgs
    $exitCode = $LASTEXITCODE
    if (($exitCode -ne 0) -and (-not $AllowFailure)) {
        throw "WSL command failed (exit $exitCode): $Command"
    }
    return $exitCode
}

function Get-UbuntuVersion {
    param([Parameter(Mandatory = $true)][string]$Distro)
    $cmd = "if command -v lsb_release >/dev/null 2>&1; then lsb_release -rs; else . /etc/os-release; echo `${VERSION_ID}; fi"
    return (Invoke-WslCapture -Distro $Distro -Command $cmd -AsRoot).Trim()
}

function Assert-UbuntuDistro {
    param([Parameter(Mandatory = $true)][string]$Distro)
    $osId = (Invoke-WslCapture -Distro $Distro -Command ". /etc/os-release; echo `${ID}" -AsRoot).Trim()
    if ($osId -ne "ubuntu") {
        throw "Distribution '$Distro' is not Ubuntu (ID=$osId)."
    }
}

function Normalize-BackupDirectory {
    param([string]$Dir)
    if ([string]::IsNullOrWhiteSpace($Dir)) {
        return (Get-DefaultBackupDirectory)
    }
    return $Dir
}

function Backup-WslDistro {
    param(
        [Parameter(Mandatory = $true)][string]$Distro,
        [Parameter(Mandatory = $true)][string]$BackupDir
    )

    Ensure-Directory -Path $BackupDir
    $safeName = Get-SafeFileName -Name $Distro
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $archivePath = Join-Path $BackupDir "$safeName`_$ts.tar"

    Write-Section "Backup"
    Write-Host "Stopping distro '$Distro' to improve backup consistency..."
    & wsl.exe --terminate $Distro 2>$null | Out-Null

    Write-Host "Exporting distro to: $archivePath"
    & wsl.exe --export $Distro $archivePath
    if ($LASTEXITCODE -ne 0) {
        throw "wsl --export failed."
    }

    $metaPath = "$archivePath.meta.json"
    $meta = [ordered]@{
        distro    = $Distro
        createdAt = (Get-Date).ToString("o")
        archive   = $archivePath
        host      = $env:COMPUTERNAME
    }
    $meta | ConvertTo-Json | Set-Content -LiteralPath $metaPath -Encoding UTF8
    Write-Host "Backup completed: $archivePath"
    return $archivePath
}

function Get-BackupSourceDistro {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$TarFile)

    $metaPath = "$($TarFile.FullName).meta.json"
    if (Test-Path -LiteralPath $metaPath) {
        try {
            $meta = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
            if (-not [string]::IsNullOrWhiteSpace($meta.distro)) {
                return [string]$meta.distro
            }
        }
        catch {
            # Ignore malformed metadata and fallback to filename parsing.
        }
    }

    if ($TarFile.BaseName -match "^(.*)_\d{8}_\d{6}$") {
        return $Matches[1]
    }
    return $TarFile.BaseName
}

function Get-BackupFiles {
    param([Parameter(Mandatory = $true)][string]$BackupDir)
    if (-not (Test-Path -LiteralPath $BackupDir)) {
        throw "Backup directory not found: $BackupDir"
    }
    $files = @(Get-ChildItem -Path $BackupDir -Filter "*.tar" -File -Recurse | Sort-Object LastWriteTime -Descending)
    if ($files.Count -eq 0) {
        throw "No .tar backup archives found under: $BackupDir"
    }
    return $files
}

function Restore-WslFromBackup {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$SelectedBackup,
        [string]$RestoreDistroName,
        [string]$RestoreInstallPath
    )

    Write-Section "Restore"
    $sourceDistro = Get-BackupSourceDistro -TarFile $SelectedBackup

    if ([string]::IsNullOrWhiteSpace($RestoreDistroName)) {
        $defaultName = "{0}-restored-{1}" -f $sourceDistro, (Get-Date -Format "yyyyMMddHHmm")
        $inputName = Read-Host "Restore distro name [$defaultName]"
        if ([string]::IsNullOrWhiteSpace($inputName)) {
            $RestoreDistroName = $defaultName
        }
        else {
            $RestoreDistroName = $inputName
        }
    }

    if ([string]::IsNullOrWhiteSpace($RestoreInstallPath)) {
        $defaultInstall = Join-Path $env:LOCALAPPDATA "WSL\Distros\$RestoreDistroName"
        $inputInstall = Read-Host "Restore install path [$defaultInstall]"
        if ([string]::IsNullOrWhiteSpace($inputInstall)) {
            $RestoreInstallPath = $defaultInstall
        }
        else {
            $RestoreInstallPath = $inputInstall
        }
    }

    $existing = Get-WslDistros
    if ($existing -contains $RestoreDistroName) {
        $confirm = Read-Host "Distro '$RestoreDistroName' already exists. Unregister it first? [y/N]"
        if ($confirm -match "^(y|yes)$") {
            & wsl.exe --unregister $RestoreDistroName
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to unregister existing distro '$RestoreDistroName'."
            }
        }
        else {
            throw "Restore cancelled because target distro already exists."
        }
    }

    if (-not (Test-Path -LiteralPath $RestoreInstallPath)) {
        New-Item -ItemType Directory -Path $RestoreInstallPath -Force | Out-Null
    }
    else {
        $hasFiles = (Get-ChildItem -LiteralPath $RestoreInstallPath -Force | Select-Object -First 1)
        if ($null -ne $hasFiles) {
            throw "Install path is not empty: $RestoreInstallPath"
        }
    }

    Write-Host "Importing backup '$($SelectedBackup.FullName)' as distro '$RestoreDistroName'..."
    & wsl.exe --import $RestoreDistroName $RestoreInstallPath $SelectedBackup.FullName --version 2
    if ($LASTEXITCODE -ne 0) {
        throw "wsl --import failed."
    }

    Write-Host "Restore completed. New distro: $RestoreDistroName"
    Write-Host "Note: imported distro may start as root user by default."
}

function Parse-Version {
    param([Parameter(Mandatory = $true)][string]$VersionText)
    return [version]::Parse($VersionText)
}

function Ensure-UpgradePrerequisites {
    param([Parameter(Mandatory = $true)][string]$Distro)
    Write-Section "Prepare for release upgrade"
    Invoke-WslLive -Distro $Distro -AsRoot -Command "export DEBIAN_FRONTEND=noninteractive; apt-get update"
    Invoke-WslLive -Distro $Distro -AsRoot -Command "export DEBIAN_FRONTEND=noninteractive; apt-get -y upgrade"
    Invoke-WslLive -Distro $Distro -AsRoot -Command "export DEBIAN_FRONTEND=noninteractive; apt-get -y dist-upgrade"
    Invoke-WslLive -Distro $Distro -AsRoot -Command "export DEBIAN_FRONTEND=noninteractive; apt-get -y autoremove"
    Invoke-WslLive -Distro $Distro -AsRoot -Command "export DEBIAN_FRONTEND=noninteractive; apt-get -y install update-manager-core"
    Invoke-WslLive -Distro $Distro -AsRoot -Command "if [ -f /etc/update-manager/release-upgrades ]; then sed -i 's/^Prompt=.*/Prompt=lts/' /etc/update-manager/release-upgrades; else echo 'Prompt=lts' > /etc/update-manager/release-upgrades; fi"
}

function Invoke-OneReleaseUpgrade {
    param([Parameter(Mandatory = $true)][string]$Distro)
    Write-Section "Run do-release-upgrade"
    $code = Invoke-WslLive -Distro $Distro -AsRoot -AllowFailure -Command "export DEBIAN_FRONTEND=noninteractive; export RELEASE_UPGRADER_NO_SCREEN=1; do-release-upgrade -m server -f DistUpgradeViewNonInteractive"
    & wsl.exe --terminate $Distro 2>$null | Out-Null
    Start-Sleep -Seconds 3
    return $code
}

function Upgrade-UbuntuDistro {
    param(
        [Parameter(Mandatory = $true)][string]$Distro,
        [string]$TargetVersion,
        [string]$BackupDir,
        [switch]$SkipBackup
    )

    Assert-UbuntuDistro -Distro $Distro
    $currentVersion = Get-UbuntuVersion -Distro $Distro
    Write-Host "Current Ubuntu version: $currentVersion"

    if (-not $SkipBackup) {
        $backupPath = Backup-WslDistro -Distro $Distro -BackupDir $BackupDir
        Write-Host "Pre-upgrade backup created: $backupPath"
    }

    Ensure-UpgradePrerequisites -Distro $Distro

    if ([string]::IsNullOrWhiteSpace($TargetVersion)) {
        $exit = Invoke-OneReleaseUpgrade -Distro $Distro
        $newVersion = Get-UbuntuVersion -Distro $Distro
        if ($newVersion -eq $currentVersion) {
            if ($exit -eq 0) {
                Write-Host "No version change detected after upgrade."
                return
            }
            throw "Upgrade did not change Ubuntu version. No newer LTS may be available."
        }
        Write-Host "Upgrade completed: $currentVersion -> $newVersion"
        return
    }

    if ($TargetVersion -notmatch "^\d{2}\.04$") {
        throw "TargetLtsVersion must look like 20.04 / 22.04 / 24.04."
    }

    $targetParsed = Parse-Version -VersionText $TargetVersion
    $currentParsed = Parse-Version -VersionText $currentVersion

    if ($currentParsed -eq $targetParsed) {
        Write-Host "Already on target version $TargetVersion."
        return
    }

    if ($currentParsed -gt $targetParsed) {
        throw "Current version $currentVersion is newer than target $TargetVersion."
    }

    while ($currentParsed -lt $targetParsed) {
        Write-Host "Upgrading from $currentVersion toward target $TargetVersion ..."
        $exitCode = Invoke-OneReleaseUpgrade -Distro $Distro
        $newVersion = Get-UbuntuVersion -Distro $Distro
        $newParsed = Parse-Version -VersionText $newVersion

        if ($newVersion -eq $currentVersion) {
            if ($exitCode -eq 0) {
                throw "Upgrade command finished but version stayed at $currentVersion."
            }
            throw "Upgrade failed or no newer LTS available from $currentVersion."
        }

        Write-Host "Version changed: $currentVersion -> $newVersion"
        $currentVersion = $newVersion
        $currentParsed = $newParsed

        if ($currentParsed -gt $targetParsed) {
            throw "Reached $currentVersion, which is higher than requested target $TargetVersion."
        }
    }

    Write-Host "Target reached: Ubuntu $currentVersion"
}

function Resolve-BackupFile {
    param(
        [string]$InputBackupFile,
        [string]$InputBackupDir
    )

    if (-not [string]::IsNullOrWhiteSpace($InputBackupFile)) {
        if (-not (Test-Path -LiteralPath $InputBackupFile)) {
            throw "Backup file not found: $InputBackupFile"
        }
        return (Get-Item -LiteralPath $InputBackupFile)
    }

    $dir = Normalize-BackupDirectory -Dir $InputBackupDir
    Write-Section "Available backups"
    $files = Get-BackupFiles -BackupDir $dir

    return (Select-FromList -Items $files -LabelBuilder {
        param($f)
        $sizeMb = [Math]::Round(($f.Length / 1MB), 2)
        "{0} | {1} | {2} MB" -f $f.FullName, $f.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"), $sizeMb
    } -Prompt "Choose backup archive")
}

function Show-MenuAndRun {
    Write-Section "WSL Automation Script"
    Write-Host "[1] Backup distro"
    Write-Host "[2] Restore distro from backup"
    Write-Host "[3] Upgrade Ubuntu with do-release-upgrade"
    $selection = Read-Host "Choose action"

    switch ($selection) {
        "1" {
            $distro = Resolve-DistroName -InputName $DistroName
            $defaultDir = Normalize-BackupDirectory -Dir $BackupDirectory
            $dirInput = Read-Host "Backup directory [$defaultDir]"
            $finalDir = if ([string]::IsNullOrWhiteSpace($dirInput)) { $defaultDir } else { $dirInput }
            Backup-WslDistro -Distro $distro -BackupDir $finalDir | Out-Null
        }
        "2" {
            $selected = Resolve-BackupFile -InputBackupFile $BackupFile -InputBackupDir $BackupDirectory
            Restore-WslFromBackup -SelectedBackup $selected -RestoreDistroName $RestoreAs -RestoreInstallPath $InstallPath
        }
        "3" {
            $distro = Resolve-DistroName -InputName $DistroName
            $target = $TargetLtsVersion
            if ([string]::IsNullOrWhiteSpace($target)) {
                $target = Read-Host "Target LTS version (optional, e.g. 24.04). Empty means one upgrade step"
            }
            $defaultDir = Normalize-BackupDirectory -Dir $BackupDirectory
            Upgrade-UbuntuDistro -Distro $distro -TargetVersion $target -BackupDir $defaultDir -SkipBackup:$SkipPreUpgradeBackup
        }
        default {
            throw "Unknown menu selection: $selection"
        }
    }
}

try {
    switch ($Action) {
        "backup" {
            $distro = Resolve-DistroName -InputName $DistroName
            $dir = Normalize-BackupDirectory -Dir $BackupDirectory
            Backup-WslDistro -Distro $distro -BackupDir $dir | Out-Null
        }
        "restore" {
            $selected = Resolve-BackupFile -InputBackupFile $BackupFile -InputBackupDir $BackupDirectory
            Restore-WslFromBackup -SelectedBackup $selected -RestoreDistroName $RestoreAs -RestoreInstallPath $InstallPath
        }
        "upgrade" {
            $distro = Resolve-DistroName -InputName $DistroName
            $dir = Normalize-BackupDirectory -Dir $BackupDirectory
            Upgrade-UbuntuDistro -Distro $distro -TargetVersion $TargetLtsVersion -BackupDir $dir -SkipBackup:$SkipPreUpgradeBackup
        }
        "menu" {
            Show-MenuAndRun
        }
        default {
            throw "Unsupported action: $Action"
        }
    }
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
