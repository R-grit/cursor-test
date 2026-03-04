# cursor-test

## WSL 自动化脚本（Windows）

仓库现在提供 `wsl_automation.bat`，可直接双击或在 `cmd/PowerShell` 运行，支持：

1. WSL 备份（支持自定义备份目录）
2. 从多个备份中选择恢复（`.tar` 列表可选）
3. 使用 `do-release-upgrade` 升级 Ubuntu，且可指定目标 LTS 版本

### 脚本位置

- `wsl_automation.bat`
- `wsl_automation_cli.ps1`（`.bat` 调用的稳定执行入口）

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

:: 原地升级时，升级前备份改为确认制（默认 No，回车跳过）
wsl_automation.bat upgrade --distro Ubuntu-20.04 --target-lts 22.04

:: 如需每次都强制做升级前备份
wsl_automation.bat upgrade --distro Ubuntu-20.04 --target-lts 22.04 --force-pre-upgrade-backup

:: 如需始终跳过升级前备份
wsl_automation.bat upgrade --distro Ubuntu-20.04 --target-lts 22.04 --skip-pre-upgrade-backup

:: 原地升级并保留当前环境（用户配置/软件/VSCode Server 等）
wsl_automation.bat upgrade --distro Ubuntu-20.04 --target-lts 22.04 --preserve-current

:: 调试模式（打印关键变量和返回码）
wsl_automation.bat backup --debug
```

### 说明

- 升级动作支持升级前备份；原地升级默认会先询问是否备份（默认 No）。
- `upgrade` 默认是原地升级（等价 `--preserve-current`），即在当前发行版内升级，保留现有用户目录、软件与配置。
- `--in-place-upgrade` 与 `--preserve-current` 等价（都表示原地升级）。
- 原地升级时，升级前备份会先询问确认（`Create pre-upgrade backup now? [y/N]`，默认 No）。
- 升级前会自动检查 `dpkg` 架构状态：若存在未使用的 foreign arch（如 `i386`）会自动移除，降低 `do-release-upgrade` 依赖冲突概率。
- 若 foreign arch 仍被数据库占用，脚本会提前停止并给出 `*:i386`（或对应架构）包示例与清理命令，再重试升级，避免在长时间升级后才失败。
- 可用 `--force-pre-upgrade-backup` 强制备份，或 `--skip-pre-upgrade-backup` 始终跳过备份。
- 升级前的 WSL 导出备份用于回滚，避免误操作导致环境不可恢复。
- 为优先保证稳定性，当前 `.bat` 走 PowerShell 稳定执行入口；复杂 clone 升级参数会回退为原地升级并给出提示。
- `--target-lts` 格式示例：`20.04`、`22.04`、`24.04`。
- 兼容 `--target-tls` 写法（等价于 `--target-lts`）。
- 恢复使用 `wsl --import`，导入后默认用户可能是 root，可按需再设置。
- 脚本执行结束会显示返回码并暂停，方便查看结果；如需关闭暂停可加 `--no-pause`。
- 需要排障时可加 `--debug`，输出关键变量、选项解析、WSL 命令返回码。
- 为兼容不同 `cmd` 代码页，`.bat` 内文案已使用纯 ASCII，避免编码导致的解析异常。
- 已添加 `.gitattributes` 强制 `.bat/.cmd` 在 Windows 检出为 CRLF，减少 `call :label` 异常。
