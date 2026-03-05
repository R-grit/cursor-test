# WSL Automation Manager

[English](#english) | [中文说明](#%E4%B8%AD%E6%96%87%E8%AF%B4%E6%98%8E)

---

## English

A highly compatible, robust Windows Batch script designed to manage Windows Subsystem for Linux (WSL) distributions. It provides automated backup, restoration, and a seamless in-place upgrade mechanism for Ubuntu WSL environments.

### Features

1. **Backup WSL Distribution**
   - Automatically detects and lists all installed WSL distributions.
   - Allows custom backup directory paths.
   - Generates `.tar` backups with precise timestamps.

2. **Restore WSL Distribution**
   - Scans a specified directory for existing `.tar` backup files.
   - Allows restoring a backup to a custom virtual disk installation path with a new distribution name.

3. **Upgrade Ubuntu WSL (Seamless LTS Upgrade)**
   - Natively utilizes the official Ubuntu `do-release-upgrade` tool.
   - **Data Preservation:** Retains user directories (`/home/`), user configurations (`.bashrc`, `.zshrc`), installed APT packages, and VSCode/Cursor Server plugins intact.
   - Prompts for an optional pre-upgrade backup to ensure data safety.
   - Automatically sets the update manager to track LTS releases to prevent unstable beta upgrades.

4. **Robust Compatibility & Debugging**
   - Employs lightweight PowerShell sub-commands to perfectly handle WSL's UTF-16 LE output encoding, preventing string corruption on older Windows 10/11 builds.
   - Real-time progress and status indicators (`[INFO]`, `[SUCCESS]`, `[ERROR]`).
   - Supports a Debug Mode (run with `--debug` or `-d`) to trace all variables and command executions.

### Usage

1. Open your Windows Command Prompt (CMD) or PowerShell.
2. Run the script:
   ```cmd
   wsl_manager.bat
   ```
3. (Optional) Run in Debug mode for verbose logging:
   ```cmd
   wsl_manager.bat --debug
   ```

### Requirements
- Windows 10 or Windows 11 with WSL installed.
- (For Upgrades) An Ubuntu-based WSL distribution.

---

## 中文说明

一个具备高兼容性和强稳定性的 Windows 批处理（Batch）脚本，专门用于管理 Windows Subsystem for Linux (WSL) 发行版。它为 Ubuntu WSL 环境提供了自动化备份、恢复以及无感就地升级的功能。

### 功能特性

1. **备份 WSL 发行版**
   - 自动检测并列出当前系统安装的所有 WSL 发行版。
   - 支持自定义备份目录。
   - 自动生成带有精确时间戳的 `.tar` 备份镜像。

2. **恢复 WSL 发行版**
   - 自动扫描指定目录下的 `.tar` 备份文件供用户选择。
   - 支持将备份恢复到自定义的虚拟磁盘安装路径，并可为其指定全新的发行版名称。

3. **升级 Ubuntu WSL (无感 LTS 升级)**
   - 原生调用 Ubuntu 官方的 `do-release-upgrade` 升级通道。
   - **数据完美保留：** 升级过程完美保留用户的 `/home/` 目录、环境配置（`.bashrc` 等）、通过 APT 安装的所有软件包以及 VSCode/Cursor 的 Server 插件，实现真正的“无感”升级。
   - 升级前会贴心询问是否进行镜像级备份，防止意外丢失数据。
   - 自动配置更新管理器仅追踪 LTS（长期支持）版本，避免升级到不稳定的测试版。

4. **高兼容性与调试机制**
   - 巧妙嵌套轻量级 PowerShell 命令，完美清洗 WSL 输出的 UTF-16 LE 编码及隐藏回车符，彻底解决在不同版本 Windows CMD 下执行命令时导致的字符串解析异常问题。
   - 提供实时的关键步骤与进度显示（如 `[INFO]`, `[SUCCESS]`, `[ERROR]`）。
   - 支持调试模式，通过追加 `--debug` 或 `-d` 参数运行即可输出所有执行过程中的变量及回显。

### 使用方法

1. 打开 Windows 的 命令提示符 (CMD) 或 PowerShell。
2. 执行该脚本：
   ```cmd
   wsl_manager.bat
   ```
3. (可选) 以调试模式运行，查看详细日志：
   ```cmd
   wsl_manager.bat --debug
   ```

### 运行要求
- 开启并安装了 WSL 的 Windows 10 或 Windows 11 系统。
- （针对升级功能）需为基于 Ubuntu 的 WSL 发行版。