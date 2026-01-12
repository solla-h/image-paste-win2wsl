# WSL Image Clipboard Helper (Forked & Enhanced)

> **Note**: This project is a hard fork of [cpulxb/WSL-Image-Clipboard-Helper](https://github.com/cpulxb/WSL-Image-Clipboard-Helper).
> While the original project provided the core idea, this fork focuses on **performance optimization**, **LLM compatibility**, and **automated maintenance**.

Language: [中文说明](#中文说明) | [English Guide](#english-guide)

---

## 中文说明

### 概述

#### 背景
当前许多智能编程 CLI Agent（如 Codex 、Claude Code、Amazon Q 等）主要针对 Linux 和 macOS 系统优化。Windows 用户即使使用 WSL2，也面临**图片粘贴不便**的痛点：
- **无法直接粘贴**：WSL2 终端无法读取 Windows 剪贴板的图片。
- **Token 消耗巨大**：高清截图直接传给大模型（如 GPT-4o, Claude 3.5），单张图可能消耗 1000+ Token，既贵又容易挤占上下文。

#### 解决方案
本工具通过 `Alt+V` 快捷键实现：
1.  **自动保存**：将剪贴板图片保存到 Windows 本地。
2.  **自动粘贴**：将 WSL 路径（`/mnt/c/...`）输入到当前终端。
3.  **智能压缩 (Smart Scale) [v2.1 新特性]**：
    - 自动检测图片尺寸，若超过 **1568px**（Claude/OpenAI 的最佳甜点），自动使用高质量算法缩放。
    - **效果**：Token 消耗降低 **60%~70%**，且肉眼几乎无法察觉画质损失。

**v2.1 版本重点**：引入 LLM 专用的 Smart Scale 插件，并支持 GitHub Action 自动编译发布。

### 核心特性
- **即时路径输出**：`Alt+V` 触发后立即粘贴 `/mnt/...` 路径，无需等待图片写入完成，整体响应时间从约 3 秒缩短到 1 秒以内。
- **输入法智能保护**：粘贴前自动切换至英文输入法，完成后恢复原状态，避免中文输入法导致路径错乱。
- **后台异步保存**：借助 PowerShell 脚本在后台保存图片，确保操作无感延迟，并对错误静默处理。
- **自动清理机制**：定时清理超过 2 小时的临时图片，退出时自动回收缓存与子进程。
- **托盘管理增强**：托盘菜单支持一键打开缓存目录、退出程序，便于日常维护。

### 必备环境
- Windows 10/11，已启用 WSL2
- PowerShell 5.1 及以上，允许执行本地脚本（建议运行 `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`）
- AutoHotkey v2（已编译为 `wsl_clipboard.exe`；仅在需要重新编译或调试脚本时安装）

### 使用方式
1. 克隆仓库并进入目录：
   ```bash
   git clone https://github.com/cpulxb/WSL-Image-Clipboard-Helper.git
   cd WSL-Image-Clipboard-Helper
   ```
2. 保证 `scripts` 目录下的 `wsl_clipboard.exe` 与相关 `.ps1` 脚本位于同一文件夹。
3. 双击 `scripts/wsl_clipboard.exe`，程序会最小化至系统托盘。
4. 在任意文本输入框按下 `Alt+V`：
   - 剪贴板图片保存至 `temp/` 目录（后台进行）
   - `/mnt/...` 路径立即粘贴至当前窗口
5. 退出时，从托盘图标右键菜单选择 `Exit`，程序会调用 `exit-all.ps1` 清理缓存与子进程。

### 常见注意事项
- `Alt+V` 为全局快捷键，如与其他软件冲突，可编辑 `scripts/wsl_clipboard.ahk` 并重新编译。
- 若托盘图标未显示，请检查任务栏的隐藏图标区域。
- 所有 PowerShell 脚本推荐使用 UTF-8 with BOM 保存，以避免中文内容导致解析失败。
- 可随时运行 `scripts/exit-all.ps1` 手动清理缓存与相关进程。

### 重新编译（可选）

如需自定义热键、修改临时目录路径或分发新的 `.exe`，需先安装 AutoHotkey v2，然后使用自带的 Ahk2Exe 编译器：

1. **安装 AutoHotkey v2**
   - 下载并安装 [AutoHotkey v2 官方版](https://www.autohotkey.com/download/ahk-v2.exe)

2. **修改脚本（可选）**
   - **修改热键**：编辑 `scripts/wsl_clipboard.ahk` 第 18 行，将 `!v::` 改为其他组合键
     - `!v` = Alt+V
     - `^!v` = Ctrl+Alt+V
     - `^+v` = Ctrl+Shift+V
   - **修改临时目录**：编辑第 5 行 `gTempDir` 变量的路径
   - **修改清理间隔**：编辑第 125 行的时间参数（默认 2 小时 = 7200000 毫秒）

3. **编译为可执行文件**
   - 打开 `C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe`
   - **Source (script file)**：选择 `scripts\wsl_clipboard.ahk`
   - **Destination (.exe file)**：指定输出路径（如 `scripts\wsl_clipboard.exe`）
   - **Base File (.bin, .exe)**：选择合适的 Base（推荐 `AutoHotkey64.exe`）
   - 点击 `Convert` 开始编译

4. **测试新版本**
   - 先从托盘退出旧版本
   - 双击新编译的 `wsl_clipboard.exe` 测试

### 附加文档
- [技术架构与流程说明](docs/architecture_by_codex.md)

### 版本历史

#### v2.0 (当前版本)
- ✨ **路径优先异步保存**：先粘贴路径，后台保存图片，响应时间从 ~3 秒降至 <1 秒
- 🔤 **输入法智能保护**：自动切换英文输入法，避免中文输入法干扰路径
- 🧹 **自动清理机制**：每 2 小时清理超过 2 小时的临时图片
- 🚀 **代码精简**：PowerShell 脚本从 86 行减少到 28 行（-67%）
- 🐛 **编码修复**：exit-all.ps1 改用 UTF-8 with BOM，支持 emoji 和中文字符
- ❌ **移除缓存文件**：删除 last_output.txt、last_seq.txt、last_hash.txt

#### v1.0
- 基础剪贴板图片同步功能
- SHA256 去重机制
- 缓存文件管理

---

## English Guide

### Overview

> **Note**: This is a performance-focused fork of [cpulxb/WSL-Image-Clipboard-Helper](https://github.com/cpulxb/WSL-Image-Clipboard-Helper).

#### Background
Using CLI Agents (Claude Code, Codex) on Windows via WSL2 often lacks seamless **image pasting** support. Furthermore, pasting raw 4K screenshots to LLMs (GPT-4o, Claude 3.5) burns excessive tokens and context window.

#### Solution
Press `Alt+V` to:
1.  **Save**: Dump clipboard image to a local file.
2.  **Paste**: Type the WSL path (`/mnt/c/...`) into your terminal.
3.  **Optimize (Smart Scale) [New in v2.1]**:
    - Automatically downscales images > **1568px** (The "Sweet Spot" for Vision LLMs).
    - **Result**: Reduces token usage by **60-70%** with zero perceived quality loss.

**v2.1 Highlights**: Added Smart Scale plugin for LLM optimization and GitHub Actions CI/CD.

### Highlights
- **Instant Path Output**: Paste the `/mnt/...` path immediately after `Alt+V`, trimming end-to-end latency from ~3 seconds to under 1 second and avoiding the prior character-by-character send effect.
- **Input Method Safeguard**: Temporarily switch to the English keyboard layout to avoid IME mis-typing, then restore the prior layout.
- **Asynchronous Save Pipeline**: Offload image persistence to PowerShell in the background with silent error handling, keeping the hotkey responsive.
- **Automatic Cleanup**: Periodically prune cached images older than two hours and remove leftovers when exiting from the tray.
- **Enhanced Tray Menu**: Quickly open the cache directory or exit the helper directly from the system tray.

### Requirements
- Windows 10/11 with WSL2 enabled
- PowerShell 5.1+ with local script execution allowed (`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`)
- AutoHotkey v2 (already compiled into `wsl_clipboard.exe`; install only if you need to rebuild or debug)

### Usage
1. Clone the repository and move into the project folder:
   ```bash
   git clone https://github.com/cpulxb/WSL-Image-Clipboard-Helper.git
   cd WSL-Image-Clipboard-Helper
   ```
2. Keep `wsl_clipboard.exe` and its companion `.ps1` scripts together inside the `scripts` directory.
3. Double-click `scripts/wsl_clipboard.exe`; the helper minimizes to the system tray.
4. Press `Alt+V` in any editable field:
   - The clipboard image is stored in `temp/` asynchronously.
   - The `/mnt/...` path is pasted right away into the active window.
5. Use the tray icon menu → `Exit` to shut down gracefully; this triggers `exit-all.ps1` to clean processes and cached files.

### Notes
- `Alt+V` is a global hotkey; adjust it inside `scripts/wsl_clipboard.ahk` and rebuild if you encounter conflicts.
- If the tray icon is hidden, look in the taskbar overflow section.
- Save PowerShell scripts as UTF-8 with BOM when they contain non-ASCII characters to avoid parsing issues.
- You can run `scripts/exit-all.ps1` manually for a quick cleanup at any time.

### Rebuild (Optional)

If you want to customize the hotkey, modify the temp directory path, or distribute a new `.exe`, install AutoHotkey v2 first and use the bundled Ahk2Exe compiler:

1. **Install AutoHotkey v2**
   - Download and install the official [AutoHotkey v2](https://www.autohotkey.com/download/ahk-v2.exe)

2. **Modify the Script (Optional)**
   - **Change hotkey**: Edit `scripts/wsl_clipboard.ahk` line 18, change `!v::` to another key combination
     - `!v` = Alt+V
     - `^!v` = Ctrl+Alt+V
     - `^+v` = Ctrl+Shift+V
   - **Change temp directory**: Edit line 5, modify the `gTempDir` variable path
   - **Change cleanup interval**: Edit line 125, adjust the time parameter (default 2 hours = 7200000 milliseconds)

3. **Compile to Executable**
   - Launch `C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe`
   - **Source (script file)**: Select `scripts\wsl_clipboard.ahk`
   - **Destination (.exe file)**: Specify output path (e.g., `scripts\wsl_clipboard.exe`)
   - **Base File (.bin, .exe)**: Choose appropriate base (recommended `AutoHotkey64.exe`)
   - Click `Convert` to start compilation

4. **Test the New Version**
   - Exit the old version from the tray first
   - Double-click the newly compiled `wsl_clipboard.exe` to test

### Additional Resources
- [Architecture & Workflow Details](docs/architecture_by_codex.md)

### Changelog

#### v2.0 (Current)
- ✨ **Path-first async save**: Paste path immediately, save image in background, latency reduced from ~3s to <1s
- 🔤 **IME protection**: Auto-switch to English input during paste, restore after
- 🧹 **Auto cleanup**: Remove images older than 2 hours every 2 hours
- 🚀 **Code simplification**: PowerShell scripts reduced from 86 to 28 lines (-67%)
- 🐛 **Encoding fix**: exit-all.ps1 now uses UTF-8 with BOM for emoji and Chinese characters
- ❌ **Cache removal**: Deleted last_output.txt, last_seq.txt, last_hash.txt

#### v1.0
- Basic clipboard image sync functionality
- SHA256 deduplication mechanism
- Cache file management
