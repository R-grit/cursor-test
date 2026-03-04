param(
    [ValidateSet("menu", "backup", "restore", "upgrade")]
    [string]$Action = "menu",
    [string]$DistroName,
    [string]$BackupDirectory,
    [string]$BackupFile,
    [string]$RestoreAs,
    [string]$InstallPath,
    [string]$TargetLtsVersion,
    [switch]$SkipPreUpgradeBackup,
    [switch]$AutoFixForeignArch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "==== $Title ===="
}

function Get-DefaultBackupDirectory {
    return Join-Path $env:USERPROFILE "WSL-Backups"
}

function Normalize-BackupDirectory {
    param([string]$Dir)
    if ([string]::IsNullOrWhiteSpace($Dir)) {
        return (Get-DefaultBackupDirectory)
    }
    return $Dir
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-SafeFileName {
    param([string]$Name)
    return ($Name -replace "[^a-zA-Z0-9._-]", "_")
}

function Normalize-Token {
    param([string]$Text)
    if ($null -eq $Text) {
        return ""
    }
    $clean = $Text -replace '[\x00-\x1F\x7F]', ''
    $clean = $clean -replace '\p{Cf}', ''
    return $clean.Trim().Trim('"')
}

function Get-WslDistros {
    $items = @()
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $raw = @(& wsl.exe -l -q 2>$null)
    foreach ($line in $raw) {
        $v = Normalize-Token -Text $line
        if ((-not [string]::IsNullOrWhiteSpace($v)) -and $seen.Add($v)) {
            $items += $v
        }
    }
    return @($items)
}

function Resolve-CanonicalDistro {
    param([string]$InputName)
    $normalizedInput = Normalize-Token -Text $InputName
    if ([string]::IsNullOrWhiteSpace($normalizedInput)) {
        throw "Distro name is empty."
    }
    $distros = @(Get-WslDistros)
    $match = $distros | Where-Object {
        (Normalize-Token -Text $_).Equals($normalizedInput, [System.StringComparison]::OrdinalIgnoreCase)
    } | Select-Object -First 1
    if ($null -eq $match) {
        throw "Distro '$InputName' not found."
    }
    return [string]$match
}

function Select-FromList {
    param(
        [Parameter(Mandatory = $true)][array]$Items,
        [Parameter(Mandatory = $true)][scriptblock]$LabelBuilder,
        [string]$Prompt
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
        $n = 0
        if ([int]::TryParse($choice, [ref]$n) -and $n -ge 1 -and $n -le $Items.Count) {
            return $Items[$n - 1]
        }
        Write-Host "Invalid selection, retry."
    }
}

function Resolve-DistroName {
    param([string]$InputName)
    $distros = @(Get-WslDistros)
    if ($distros.Count -eq 0) {
        throw "No WSL distro found."
    }
    if (-not [string]::IsNullOrWhiteSpace($InputName)) {
        return (Resolve-CanonicalDistro -InputName $InputName)
    }
    Write-Section "Available WSL distros"
    $selected = Select-FromList -Items $distros -LabelBuilder { param($x) $x } -Prompt "Choose distro"
    return (Resolve-CanonicalDistro -InputName $selected)
}

function Invoke-WslCapture {
    param(
        [string]$Distro,
        [string]$Command,
        [switch]$AsRoot,
        [switch]$AllowFailure
    )
    $resolved = Resolve-CanonicalDistro -InputName $Distro
    $args = @("-d", $resolved)
    if ($AsRoot) { $args += @("-u", "root") }
    $args += @("--", "bash", "-lc", $Command)
    $output = & wsl.exe @args 2>&1
    $code = $LASTEXITCODE
    $text = ($output -join "`n").Trim()
    if (($code -ne 0) -and (-not $AllowFailure)) {
        throw "WSL command failed (exit $code): $Command`n$text"
    }
    return [pscustomobject]@{
        Code = $code
        Text = $text
    }
}

function Invoke-WslLive {
    param(
        [string]$Distro,
        [string]$Command,
        [switch]$AsRoot,
        [switch]$AllowFailure
    )
    $resolved = Resolve-CanonicalDistro -InputName $Distro
    $args = @("-d", $resolved)
    if ($AsRoot) { $args += @("-u", "root") }
    $args += @("--", "bash", "-lc", $Command)
    & wsl.exe @args
    $code = $LASTEXITCODE
    if (($code -ne 0) -and (-not $AllowFailure)) {
        throw "WSL command failed (exit $code): $Command"
    }
    return $code
}

function Try-ExtractVersionFromDistroName {
    param([string]$Distro)
    $name = Normalize-Token -Text $Distro
    if ($name -match "(?i)ubuntu[-_ ]?([0-9]{2}\.[0-9]{2})") {
        return $Matches[1]
    }
    return $null
}

function Get-UbuntuVersion {
    param([string]$Distro)
    $result = Invoke-WslCapture -Distro $Distro -AsRoot -AllowFailure -Command "lsb_release -rs 2>/dev/null"
    if ($result.Code -eq 0 -and -not [string]::IsNullOrWhiteSpace($result.Text)) {
        $v = $result.Text -split "`r?`n" | ForEach-Object { Normalize-Token -Text $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
        if ($v -match "^[0-9]+\.[0-9]+$") {
            return $v
        }
    }
    $fallback = Try-ExtractVersionFromDistroName -Distro $Distro
    if (-not [string]::IsNullOrWhiteSpace($fallback)) {
        return $fallback
    }
    throw "Failed to detect Ubuntu version."
}

function Assert-UbuntuDistro {
    param([string]$Distro)
    $name = Normalize-Token -Text $Distro
    if ($name -match "^(?i)ubuntu([-_ ].*)?$") {
        return
    }
    $r = Invoke-WslCapture -Distro $Distro -AsRoot -AllowFailure -Command "lsb_release -is 2>/dev/null"
    $id = $r.Text -split "`r?`n" | ForEach-Object { Normalize-Token -Text $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    if ($r.Code -eq 0 -and (-not [string]::IsNullOrWhiteSpace($id)) -and $id.Equals("ubuntu", [System.StringComparison]::OrdinalIgnoreCase)) {
        return
    }
    throw "Distro '$Distro' is not Ubuntu."
}

function Get-WslNativeArchitecture {
    param([string]$Distro)
    $result = Invoke-WslCapture -Distro $Distro -AsRoot -AllowFailure -Command "dpkg --print-architecture 2>/dev/null"
    if ($result.Code -ne 0) {
        throw "Failed to detect native package architecture."
    }
    $native = $result.Text -split "`r?`n" | ForEach-Object { Normalize-Token -Text $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($native)) {
        throw "Native package architecture is empty."
    }
    return [string]$native
}

function Get-WslForeignArchitectures {
    param([string]$Distro)
    $result = Invoke-WslCapture -Distro $Distro -AsRoot -AllowFailure -Command "dpkg --print-foreign-architectures 2>/dev/null"
    if ($result.Code -ne 0 -or [string]::IsNullOrWhiteSpace($result.Text)) {
        return @()
    }
    $arches = $result.Text -split "`r?`n" | ForEach-Object { Normalize-Token -Text $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    return @($arches)
}

function Get-WslPackagesForArchitecture {
    param(
        [string]$Distro,
        [string]$Architecture
    )
    if ([string]::IsNullOrWhiteSpace($Architecture)) {
        return @()
    }
    $pattern = "*:$Architecture"
    $cmd = "dpkg -l '{0}' 2>/dev/null" -f $pattern
    $result = Invoke-WslCapture -Distro $Distro -AsRoot -AllowFailure -Command $cmd
    if ([string]::IsNullOrWhiteSpace($result.Text)) {
        return @()
    }
    $lines = @()
    foreach ($raw in ($result.Text -split "`r?`n")) {
        $line = Normalize-Token -Text $raw
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -notmatch "^[a-z][a-z]\s+") { continue }
        $parts = @($line -split "\s+")
        if ($parts.Count -lt 2) { continue }
        $status = $parts[0]
        $pkg = $parts[1]
        if ($pkg -notlike "*:$Architecture") { continue }
        # state=not-installed (second char n) usually does not block remove-architecture
        if ($status.Length -ge 2 -and $status[1] -eq 'n') { continue }
        $lines += ("{0}`t{1}" -f $pkg, $status)
    }
    return @($lines)
}

function AutoFix-ForeignArchitecture {
    param(
        [string]$Distro,
        [string]$Architecture
    )
    Write-Host "Auto-fix enabled, cleaning packages for '$Architecture'..."
    Invoke-WslLive -Distro $Distro -AsRoot -Command "export DEBIAN_FRONTEND=noninteractive; apt-get purge -y '*:$Architecture'"
    Invoke-WslLive -Distro $Distro -AsRoot -Command "export DEBIAN_FRONTEND=noninteractive; apt-get autoremove -y"
    $remaining = @(Get-WslPackagesForArchitecture -Distro $Distro -Architecture $Architecture)
    if ($remaining.Count -gt 0) {
        $preview = ($remaining | Select-Object -First 12) -join "`n  "
        $suffix = if ($remaining.Count -gt 12) { "`n  ... (+$($remaining.Count - 12) more)" } else { "" }
        $hint = @"
Auto-fix could not fully clean '$Architecture' package entries ($($remaining.Count) entries).
Examples:
  $preview$suffix
"@
        throw $hint.Trim()
    }
    Invoke-WslLive -Distro $Distro -AsRoot -Command ("dpkg --remove-architecture {0}" -f $Architecture)
}

function Ensure-ReleaseUpgradeArchitectureState {
    param(
        [string]$Distro,
        [switch]$AutoFix
    )
    Write-Section "Check package architectures"
    $native = Get-WslNativeArchitecture -Distro $Distro
    $foreign = @(Get-WslForeignArchitectures -Distro $Distro)
    Write-Host "Native architecture: $native"
    if ($foreign.Count -eq 0) {
        Write-Host "No foreign architecture found."
        return
    }
    Write-Host ("Foreign architectures: {0}" -f ($foreign -join ", "))

    foreach ($arch in $foreign) {
        if ($arch -notmatch "^[a-z0-9][a-z0-9_-]*$") {
            throw "Unexpected architecture token '$arch'."
        }
        $archPackages = @(Get-WslPackagesForArchitecture -Distro $Distro -Architecture $arch)
        if ($archPackages.Count -gt 0) {
            if ($AutoFix) {
                AutoFix-ForeignArchitecture -Distro $Distro -Architecture $arch
                continue
            }
            $preview = ($archPackages | Select-Object -First 12) -join "`n  "
            $suffix = if ($archPackages.Count -gt 12) { "`n  ... (+$($archPackages.Count - 12) more)" } else { "" }
            $hint = @"
Foreign architecture '$arch' is still in use by package database ($($archPackages.Count) entries).
Examples:
  $preview$suffix

Please clean packages for this architecture, then retry:
  apt-get purge '*:$arch'
  apt-get autoremove -y
  dpkg --remove-architecture $arch
Or rerun with:
  --auto-fix-foreign-arch
"@
            throw $hint.Trim()
        }
        Write-Host "Removing unused foreign architecture: $arch"
        $remove = Invoke-WslCapture -Distro $Distro -AsRoot -AllowFailure -Command ("dpkg --remove-architecture {0}" -f $arch)
        if ($remove.Code -ne 0) {
            $archPackagesAfterFailure = @(Get-WslPackagesForArchitecture -Distro $Distro -Architecture $arch)
            if ($archPackagesAfterFailure.Count -gt 0) {
                $preview = ($archPackagesAfterFailure | Select-Object -First 12) -join "`n  "
                $suffix = if ($archPackagesAfterFailure.Count -gt 12) { "`n  ... (+$($archPackagesAfterFailure.Count - 12) more)" } else { "" }
                $hint = @"
Cannot remove foreign architecture '$arch' because package database still references it ($($archPackagesAfterFailure.Count) entries).
Examples:
  $preview$suffix

Please clean packages for this architecture, then retry:
  apt-get purge '*:$arch'
  apt-get autoremove -y
  dpkg --remove-architecture $arch
"@
                throw $hint.Trim()
            }
            $fallbackHint = @"
Failed to remove foreign architecture '$arch': $($remove.Text)

Please inspect and clean architecture packages manually:
  dpkg -l '*:$arch'
  apt-get purge '*:$arch'
  apt-get autoremove -y
  dpkg --remove-architecture $arch
"@
            throw $fallbackHint.Trim()
        }
    }
}

function Backup-WslDistro {
    param(
        [string]$Distro,
        [string]$BackupDir
    )
    $Distro = Resolve-CanonicalDistro -InputName $Distro
    Ensure-Directory -Path $BackupDir
    $safe = Get-SafeFileName -Name $Distro
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $archivePath = Join-Path $BackupDir "$safe`_$ts.tar"

    Write-Section "Backup"
    Write-Host "Stopping distro '$Distro' for consistency..."
    & wsl.exe --terminate $Distro 2>$null | Out-Null

    Write-Host "Exporting to: $archivePath"
    & wsl.exe --export $Distro $archivePath
    if ($LASTEXITCODE -ne 0) {
        throw "wsl --export failed."
    }
    if (-not (Test-Path -LiteralPath $archivePath)) {
        throw "Backup archive not created: $archivePath"
    }
    $size = (Get-Item -LiteralPath $archivePath).Length
    if ($size -le 0) {
        throw "Backup archive is empty: $archivePath"
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

function Get-BackupFiles {
    param([string]$BackupDir)
    if (-not (Test-Path -LiteralPath $BackupDir)) {
        throw "Backup directory not found: $BackupDir"
    }
    $files = @(Get-ChildItem -LiteralPath $BackupDir -Filter "*.tar" -File -Recurse | Sort-Object LastWriteTime -Descending)
    if ($files.Count -eq 0) {
        throw "No backup .tar found under: $BackupDir"
    }
    return $files
}

function Resolve-BackupArchive {
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
        "{0} | {1} MB | {2}" -f $f.FullName, $sizeMb, $f.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    } -Prompt "Choose backup number")
}

function Get-BackupSourceDistro {
    param([System.IO.FileInfo]$TarFile)
    $metaPath = "$($TarFile.FullName).meta.json"
    if (Test-Path -LiteralPath $metaPath) {
        try {
            $meta = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
            if (-not [string]::IsNullOrWhiteSpace($meta.distro)) {
                return [string]$meta.distro
            }
        }
        catch { }
    }
    if ($TarFile.BaseName -match "^(.*)_\d{8}_\d{6}$") {
        return $Matches[1]
    }
    return $TarFile.BaseName
}

function Restore-WslFromBackup {
    param(
        [System.IO.FileInfo]$Archive,
        [string]$TargetName,
        [string]$TargetPath
    )
    Write-Section "Restore"
    $source = Get-BackupSourceDistro -TarFile $Archive
    if ([string]::IsNullOrWhiteSpace($TargetName)) {
        $defaultName = "{0}-restored-{1}" -f $source, (Get-Date -Format "yyyyMMddHHmm")
        $in = Read-Host "Restore distro name [$defaultName]"
        $TargetName = if ([string]::IsNullOrWhiteSpace($in)) { $defaultName } else { $in }
    }
    if ([string]::IsNullOrWhiteSpace($TargetPath)) {
        $defaultPath = Join-Path $env:LOCALAPPDATA "WSL\Distros\$TargetName"
        $in = Read-Host "Restore install path [$defaultPath]"
        $TargetPath = if ([string]::IsNullOrWhiteSpace($in)) { $defaultPath } else { $in }
    }

    $existing = @(Get-WslDistros)
    if ($existing -contains $TargetName) {
        $ans = Read-Host "Distro '$TargetName' exists. Unregister first? [y/N]"
        if ($ans -match "^(?i:y|yes)$") {
            & wsl.exe --unregister $TargetName
            if ($LASTEXITCODE -ne 0) { throw "Failed to unregister '$TargetName'." }
        }
        else {
            throw "Restore cancelled."
        }
    }

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    }
    elseif ((Get-ChildItem -LiteralPath $TargetPath -Force | Select-Object -First 1) -ne $null) {
        throw "Install path is not empty: $TargetPath"
    }

    Write-Host "Importing '$($Archive.FullName)' to '$TargetName'..."
    & wsl.exe --import $TargetName $TargetPath $Archive.FullName --version 2
    if ($LASTEXITCODE -ne 0) {
        throw "wsl --import failed."
    }
    Write-Host "Restore completed: $TargetName"
}

function Ensure-UpgradePrerequisites {
    param(
        [string]$Distro,
        [switch]$AutoFixForeignArch
    )
    Write-Section "Prepare release upgrade"
    Ensure-ReleaseUpgradeArchitectureState -Distro $Distro -AutoFix:$AutoFixForeignArch
    Invoke-WslLive -Distro $Distro -AsRoot -Command "export DEBIAN_FRONTEND=noninteractive; apt-get update"
    Invoke-WslLive -Distro $Distro -AsRoot -Command "export DEBIAN_FRONTEND=noninteractive; apt-get -y upgrade"
    Invoke-WslLive -Distro $Distro -AsRoot -Command "export DEBIAN_FRONTEND=noninteractive; apt-get -y dist-upgrade"
    Invoke-WslLive -Distro $Distro -AsRoot -Command "export DEBIAN_FRONTEND=noninteractive; apt-get -y autoremove"
    Invoke-WslLive -Distro $Distro -AsRoot -Command "export DEBIAN_FRONTEND=noninteractive; apt-get -y install update-manager-core"
    Invoke-WslLive -Distro $Distro -AsRoot -Command "if [ -f /etc/update-manager/release-upgrades ]; then sed -i 's/^Prompt=.*/Prompt=lts/' /etc/update-manager/release-upgrades; else echo 'Prompt=lts' > /etc/update-manager/release-upgrades; fi"
}

function Invoke-OneReleaseUpgrade {
    param([string]$Distro)
    Write-Section "Run do-release-upgrade"
    $code = Invoke-WslLive -Distro $Distro -AsRoot -AllowFailure -Command "export DEBIAN_FRONTEND=noninteractive; export RELEASE_UPGRADER_NO_SCREEN=1; do-release-upgrade -m server -f DistUpgradeViewNonInteractive"
    & wsl.exe --terminate $Distro 2>$null | Out-Null
    Start-Sleep -Seconds 3
    return $code
}

function Parse-Version {
    param([string]$VersionText)
    return [version]::Parse($VersionText)
}

function Upgrade-UbuntuDistro {
    param(
        [string]$Distro,
        [string]$TargetVersion,
        [string]$BackupDir,
        [switch]$SkipBackup,
        [switch]$AutoFixForeignArch
    )
    Assert-UbuntuDistro -Distro $Distro
    $currentVersion = Get-UbuntuVersion -Distro $Distro
    Write-Host "Current Ubuntu version: $currentVersion"

    if (-not $SkipBackup) {
        $archive = Backup-WslDistro -Distro $Distro -BackupDir $BackupDir
        Write-Host "Pre-upgrade backup created: $archive"
    }
    else {
        Write-Host "Skipped pre-upgrade backup."
    }

    Ensure-UpgradePrerequisites -Distro $Distro -AutoFixForeignArch:$AutoFixForeignArch

    if ([string]::IsNullOrWhiteSpace($TargetVersion)) {
        $code = Invoke-OneReleaseUpgrade -Distro $Distro
        $newVersion = Get-UbuntuVersion -Distro $Distro
        if ($newVersion -eq $currentVersion -and $code -ne 0) {
            throw "Upgrade failed and version did not change."
        }
        Write-Host "Upgrade finished: $currentVersion -> $newVersion"
        return
    }

    if ($TargetVersion -notmatch "^\d{2}\.04$") {
        throw "Target LTS format must be 20.04 / 22.04 / 24.04."
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
        Write-Host "Upgrading from $currentVersion toward $TargetVersion ..."
        $code = Invoke-OneReleaseUpgrade -Distro $Distro
        $newVersion = Get-UbuntuVersion -Distro $Distro
        if ($newVersion -eq $currentVersion) {
            if ($code -eq 0) { throw "Upgrade completed but version did not change." }
            throw "Upgrade failed from $currentVersion."
        }
        Write-Host "Version changed: $currentVersion -> $newVersion"
        $currentVersion = $newVersion
        $currentParsed = Parse-Version -VersionText $currentVersion
        if ($currentParsed -gt $targetParsed) {
            throw "Reached $currentVersion, beyond target $TargetVersion."
        }
    }
    Write-Host "Target reached: Ubuntu $currentVersion"
}

function Show-Menu-And-Run {
    Write-Section "WSL automation script (.ps1 core)"
    Write-Host "[1] Backup distro"
    Write-Host "[2] Restore from backup"
    Write-Host "[3] Upgrade Ubuntu LTS"
    $choice = Read-Host "Choose action"
    switch ($choice) {
        "1" {
            $distro = Resolve-DistroName -InputName $DistroName
            $dir = Normalize-BackupDirectory -Dir $BackupDirectory
            Backup-WslDistro -Distro $distro -BackupDir $dir | Out-Null
        }
        "2" {
            $archive = Resolve-BackupArchive -InputBackupFile $BackupFile -InputBackupDir $BackupDirectory
            Restore-WslFromBackup -Archive $archive -TargetName $RestoreAs -TargetPath $InstallPath
        }
        "3" {
            $distro = Resolve-DistroName -InputName $DistroName
            $target = $TargetLtsVersion
            if ([string]::IsNullOrWhiteSpace($target)) {
                $target = Read-Host "Target LTS version (optional, e.g. 24.04)"
            }
            $dir = Normalize-BackupDirectory -Dir $BackupDirectory
            Upgrade-UbuntuDistro -Distro $distro -TargetVersion $target -BackupDir $dir -SkipBackup:$SkipPreUpgradeBackup -AutoFixForeignArch:$AutoFixForeignArch
        }
        default {
            throw "Invalid menu choice: $choice"
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
            $archive = Resolve-BackupArchive -InputBackupFile $BackupFile -InputBackupDir $BackupDirectory
            Restore-WslFromBackup -Archive $archive -TargetName $RestoreAs -TargetPath $InstallPath
        }
        "upgrade" {
            $distro = Resolve-DistroName -InputName $DistroName
            $dir = Normalize-BackupDirectory -Dir $BackupDirectory
            Upgrade-UbuntuDistro -Distro $distro -TargetVersion $TargetLtsVersion -BackupDir $dir -SkipBackup:$SkipPreUpgradeBackup -AutoFixForeignArch:$AutoFixForeignArch
        }
        "menu" {
            Show-Menu-And-Run
        }
    }
}
catch {
    Write-Host ""
    Write-Host ("ERROR: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
