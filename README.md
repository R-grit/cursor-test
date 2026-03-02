# cursor-test

## WSL 自动化脚本（Windows）

仓库现在提供 `wsl_automation.bat`，可直接双击或在 `cmd/PowerShell` 运行，支持：

1. WSL 备份（支持自定义备份目录）
2. 从多个备份中选择恢复（`.tar` 列表可选）
3. 使用 `do-release-upgrade` 升级 Ubuntu，且可指定目标 LTS 版本

### 脚本位置

- `wsl_automation.bat`

### 快速使用

```bat
:: 交互菜单（最方便）
wsl_automation.bat

:: 备份到自定义目录
wsl_automation.bat backup --distro Ubuntu --backup-dir "D:\WSLBackups"

:: 恢复（不传 --backup-file 时会列出多个备份供选择）
wsl_automation.bat restore --backup-dir "D:\WSLBackups"

:: 升级到指定 LTS（示例：24.04）
wsl_automation.bat upgrade --distro Ubuntu --target-lts 24.04 --backup-dir "D:\WSLBackups"
```

### 说明

- 升级动作默认会先做一次升级前备份，便于回滚。
- `--target-lts` 格式示例：`20.04`、`22.04`、`24.04`。
- 恢复使用 `wsl --import`，导入后默认用户可能是 root，可按需再设置。
- 脚本执行结束会显示返回码并暂停，方便查看结果；如需关闭暂停可加 `--no-pause`。
