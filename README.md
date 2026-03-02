# cursor-test

## WSL automation script (Windows)

This repository now includes `wsl_automation.ps1`, a PowerShell script for:

1. WSL distro backup (custom backup directory supported)
2. Restore from selectable backups (choose from multiple `.tar` archives)
3. Ubuntu LTS release upgrade with `do-release-upgrade` (target LTS can be specified)

### Script location

- `wsl_automation.ps1`

### Quick examples

Run in PowerShell (Windows):

```powershell
# Interactive menu
powershell -ExecutionPolicy Bypass -File .\wsl_automation.ps1

# Backup a distro to custom directory
powershell -ExecutionPolicy Bypass -File .\wsl_automation.ps1 `
  -Action backup `
  -DistroName Ubuntu `
  -BackupDirectory "D:\WSLBackups"

# Restore (if BackupFile is omitted, script lists backups to choose)
powershell -ExecutionPolicy Bypass -File .\wsl_automation.ps1 `
  -Action restore `
  -BackupDirectory "D:\WSLBackups"

# Upgrade Ubuntu to a target LTS (example: 24.04)
powershell -ExecutionPolicy Bypass -File .\wsl_automation.ps1 `
  -Action upgrade `
  -DistroName Ubuntu `
  -TargetLtsVersion 24.04 `
  -BackupDirectory "D:\WSLBackups"
```

### Notes

- Upgrade action creates a pre-upgrade backup by default.
- `TargetLtsVersion` uses LTS format like `20.04`, `22.04`, `24.04`.
- Restore uses `wsl --import`, and imported distro may default to root user initially.
