<p align="center">
  <img src="icon/image-paste-icon.svg" alt="Image Paste Win2WSL Logo" width="128" height="128">
</p>

<h1 align="center">Image Paste Win2WSL</h1>

<p align="center">
  <strong>为 WSL 终端和 LLM 编程代理提供无缝的 Windows 剪贴板图片共享</strong>
</p>

<p align="center">
  <a href="https://github.com/solla-h/image-paste-win2wsl/releases"><img alt="GitHub release" src="https://img.shields.io/github/v/release/solla-h/image-paste-win2wsl?style=flat-square&color=blue"></a>
  <a href="https://github.com/solla-h/image-paste-win2wsl/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/github/license/solla-h/image-paste-win2wsl?style=flat-square"></a>
  <a href="https://github.com/solla-h/image-paste-win2wsl/actions"><img alt="Build Status" src="https://img.shields.io/github/actions/workflow/status/solla-h/image-paste-win2wsl/release.yml?style=flat-square"></a>
</p>

<p align="center">
  <a href="#功能特性">功能特性</a> •
  <a href="#快速开始">快速开始</a> •
  <a href="#工作原理">工作原理</a> •
  <a href="#技术文档">技术文档</a> •
  <a href="#参与贡献">参与贡献</a>
</p>

<p align="center">
  <b>语言:</b> <a href="README.md">English</a> | 中文
</p>

---

## 问题背景

在 WSL2 中使用 AI 编程代理（Claude Code、Codex CLI、Kiro CLI）时，你可能遇到过：

| 痛点 | 影响 |
|------|------|
| **剪贴板不可用** | WSL 终端无法读取 Windows 剪贴板中的图片 |
| **Token 消耗高** | 大尺寸截图发送给视觉 LLM 时会消耗大量 Token |
| **工作流繁琐** | 手动保存 → 上传 → 粘贴路径，效率低下 |

## 解决方案

**一键触发，零摩擦体验。**

按下 `Alt+V`，Image Paste Win2WSL 会：

1. 📋 **抓取** Windows 剪贴板中的图片
2. 🗜️ **优化** 图片尺寸（Smart Scale 自动压缩）
3. 📂 **异步保存** 到本地存储
4. 📝 **立即粘贴** WSL 兼容路径（`/mnt/c/...`）

---

## 功能特性

| 特性 | 说明 |
|------|------|
| ⚡ **即时路径输出** | 路径在约 100ms 内粘贴，图片后台保存 |
| 🧠 **Smart Scale 插件** | 自动压缩大尺寸图片以减少 Token 消耗 |
| 🔤 **输入法保护** | 自动切换英文键盘，避免路径乱码 |
| 🧹 **自动清理** | 定时删除 2 小时前的缓存图片 |
| 🖥️ **系统托盘** | 简洁 UI，快速访问缓存目录 |
| 🔧 **零依赖** | 单一 `.exe` + PowerShell 脚本，无需安装 |

---

## 快速开始

### 下载与运行

1. **下载** 最新版本：[Releases](https://github.com/solla-h/image-paste-win2wsl/releases)
2. **解压** ZIP 到任意目录（如 `C:\Tools\ImagePasteWin2WSL`）
3. **运行** `image-paster-win2wsl.exe`（最小化到系统托盘）
4. **使用** 在任意文本框按 `Alt+V` 粘贴图片路径

> [!TIP]
> 将 `image-paster-win2wsl.exe` 添加到 Windows 启动项可实现开机自启。

### 从源码运行

```bash
git clone https://github.com/solla-h/image-paste-win2wsl.git
cd image-paste-win2wsl
```

**方式 A：直接运行脚本**（需安装 [AutoHotkey v2](https://www.autohotkey.com/download/ahk-v2.exe)）
- 双击 `image-paster-win2wsl.ahk` 即可运行

**方式 B：编译为 `.exe`**（用于分发或开机启动）
1. 安装 [AutoHotkey v2](https://www.autohotkey.com/download/ahk-v2.exe)
2. 右键点击 `image-paster-win2wsl.ahk` → "Compile Script"
3. 运行生成的 `image-paster-win2wsl.exe`

> [!NOTE]
> 预编译版本可在 [Releases](https://github.com/solla-h/image-paste-win2wsl/releases) 页面下载。

---

## 系统要求

| 要求 | 详情 |
|------|------|
| **操作系统** | Windows 10/11，已启用 WSL2 |
| **PowerShell** | 5.1+，已允许执行本地脚本 |
| **AutoHotkey** | 仅在从源码编译时需要 |

**启用脚本执行**（首次设置）：
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 工作原理

```
┌────────────────────────────────────────────────────────────────┐
│                     Alt+V 快捷键触发                            │
├────────────────────────────────────────────────────────────────┤
│  1. 保存当前键盘布局                                            │
│  2. 切换到英文 (US) 布局                                        │
│  3. 生成时间戳文件名 → 20260112_172400_123.png                  │
│  4. 转换为 WSL 路径 → /mnt/c/.../temp/20260112_172400_123.png   │
│  5. 立即粘贴路径（即时反馈）                                     │
│  6. 异步：PowerShell 保存图片 + SmartScale 优化                 │
│  7. 恢复原键盘布局                                              │
└────────────────────────────────────────────────────────────────┘
```

### 项目结构

```
image-paste-win2wsl/
├── image-paster-win2wsl.ahk   # 主 AutoHotkey 脚本
├── image-paster-win2wsl.exe   # 编译后的可执行文件
├── lib/
│   ├── save-clipboard-image.ps1   # 剪贴板 → PNG 保存器
│   ├── SmartScale.ps1             # LLM 优化图片缩放
│   └── exit-all.ps1               # 清理脚本
├── temp/                          # 图片缓存（自动清理）
├── icon/                          # 应用图标
└── docs/                          # 技术文档
```

---

## Smart Scale 插件

Smart Scale 插件会在保存前自动压缩大尺寸图片，帮助减少视觉 LLM 处理图片时的 Token 消耗。

### 为什么是 1568px？

插件使用 **1568 像素** 作为最大长边阈值。该值基于主流 LLM 提供商的官方建议：

| 提供商 | 模型 | 官方说明 | 来源 |
|--------|------|----------|------|
| **Anthropic** | Claude 4 Sonnet | "如果图片长边超过 1568 像素...将首先被缩小" | [Claude Vision 文档](https://platform.claude.com/docs/en/build-with-claude/vision) |
| **OpenAI** | GPT-4o | 图片被切分为 512x512 块；图片越大 = 块越多 = Token 越多 | [OpenAI Vision 指南](https://platform.openai.com/docs/guides/images-vision) |
| **Google** | Gemini 3 | 推荐使用 `MEDIA_RESOLUTION_HIGH`；大图会用更多分块处理 | [Gemini 媒体分辨率](https://ai.google.dev/gemini-api/docs/media-resolution) |

### 工作方式

1. 长边 ≤ 1568px 的图片直接通过，不做处理
2. 较大图片按比例缩小，使用高质量双三次插值算法
3. 无外部依赖 — 使用原生 .NET GDI+ 图形库

### Token 计算参考

精确的 Token 计算请参考官方文档：

- **Claude**: `tokens = (宽 × 高) / 750` — [计算图片成本](https://platform.claude.com/docs/en/build-with-claude/vision#calculate-image-costs)
- **GPT-4o**: `85 + 170 × (512px 分块数量)` — [Vision 定价](https://platform.openai.com/docs/guides/images-vision)
- **Gemini 3**: Token 数量取决于 `media_resolution` 设置 — [Token 计数](https://ai.google.dev/gemini-api/docs/tokens)

---

## 技术文档

| 文档 | 说明 |
|------|------|
| [技术架构与流程](docs/architecture_zh-CN.md) | 组件设计深度解析 |
| [终端 Ctrl+V 拦截分析](docs/terminal-ctrl-v-interception.md) | 终端为何拦截 Ctrl+V 及我们的解决方案 |

---

## 自定义配置

### 修改快捷键

编辑 `image-paster-win2wsl.ahk` 第 23 行：

```ahk
; 当前: Alt+V
!v:: {

; 示例:
; ^!v::     → Ctrl+Alt+V
; ^+v::     → Ctrl+Shift+V
; #v::      → Win+V
```

修改后需重新编译（参见 [从源码编译](#从源码编译)）。

### 修改临时目录

编辑 `image-paster-win2wsl.ahk` 第 6 行：

```ahk
global gTempDir := gScriptDir "\temp"  ; 在此修改路径
```

### 调整清理间隔

编辑 `image-paster-win2wsl.ahk` 第 127 行：

```ahk
SetTimer(CleanupTempFolder, 2 * 60 * 60 * 1000)  ; 默认: 2 小时
```

---

## 从源码编译

### 前置条件

1. 安装 [AutoHotkey v2](https://www.autohotkey.com/download/ahk-v2.exe)
2. 下载 [Ahk2Exe 编译器](https://github.com/AutoHotkey/Ahk2Exe/releases)

### 编译步骤

```powershell
# 使用 Ahk2Exe GUI
# 源文件: image-paster-win2wsl.ahk
# 输出文件: image-paster-win2wsl.exe
# 图标: icon\image-paste-icon_256.ico
# 基础文件: AutoHotkey64.exe
```

或使用 CI/CD 自动化流水线，推送版本标签即可：

```bash
git tag v2.2.0
git push origin v2.2.0
```

GitHub Actions 将自动编译并创建 Release。

---

## 安全提示

> [!NOTE]
> 部分杀毒软件可能将 AutoHotkey 可执行文件误报为威胁。
> 这是 AutoHotkey 社区的[已知问题](https://www.autohotkey.com/docs/v2/FAQ.htm#Virus)。
> 
> **所有源代码完全公开可审查。** 请查看 `.ahk` 和 `.ps1` 文件以验证安全性。

---

## 参与贡献

欢迎贡献！请：

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送分支 (`git push origin feature/amazing-feature`)
5. 发起 Pull Request

---

## 更新日志

### v2.1（当前版本）
- ✨ **Smart Scale 插件**：自动调整图片尺寸以适配 LLM Vision API
- 🚀 **GitHub Actions CI/CD**：自动化构建和发布
- 📁 **扁平化结构**：简化项目布局

### v2.0
- ⚡ **路径优先架构**：立即粘贴路径，异步保存图片
- 🔤 **输入法保护**：可靠的纯英文路径输出
- 🧹 **自动清理**：定时清理缓存

### v1.0
- 📋 基础剪贴板同步，支持 SHA256 去重

---

## 致谢

本项目是 [cpulxb/WSL-Image-Clipboard-Helper](https://github.com/cpulxb/WSL-Image-Clipboard-Helper) 的硬分叉。原项目提供了基础概念，本分叉专注于**性能优化**、**LLM 兼容性**和**自动化维护**。

---

## 许可证

[MIT License](LICENSE) © 2026 solla-h

---

<p align="center">
  Made with ❤️ for WSL 开发者
</p>
