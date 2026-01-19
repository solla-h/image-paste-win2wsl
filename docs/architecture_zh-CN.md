# 技术架构与实现细节

本文档深入介绍 Image Paste Win2WSL 的组件设计、执行流程与实现要点。

---

## 组件架构

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    image-paster-win2wsl.exe (AutoHotkey v2)              │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  • Alt+V 热键监听                                                   │  │
│  │  • 输入法状态保存与恢复                                              │  │
│  │  • 路径转换 (Windows → WSL)                                         │  │
│  │  • 托盘菜单与状态通知                                                │  │
│  │  • 定时清理调度（每 2 小时）                                         │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                    │                                      │
│           ┌────────────────────────┼────────────────────────┐             │
│           ▼                        ▼                        ▼             │
│  ┌─────────────────────┐  ┌─────────────────┐      ┌───────────────┐     │
│  │ lib/save-clipboard- │  │ lib/SmartScale  │      │    temp/      │     │
│  │     image.ps1       │  │     .ps1        │      │    *.png      │     │
│  │                     │  │                 │      │               │     │
│  │ • 异步保存图片      │  │ • 图片缩放      │      │ • 图片缓存    │     │
│  │ • 调用 SmartScale   │  │ • LLM 优化      │      │ • 自动清理    │     │
│  │ • 静默错误处理      │  │ • 1568px 阈值   │      │               │     │
│  └─────────────────────┘  └─────────────────┘      └───────────────┘     │
│                                                                           │
│  ┌─────────────────────┐                                                  │
│  │  lib/exit-all.ps1   │  托盘"Exit"时调用：终止进程、清理临时目录        │
│  │                     │                                                  │
│  └─────────────────────┘                                                  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 项目结构

```
image-paste-win2wsl/
├── image-paster-win2wsl.ahk    # 主 AutoHotkey 脚本
├── image-paster-win2wsl.exe    # 编译后可执行文件（从 Releases 下载）
├── lib/
│   ├── save-clipboard-image.ps1   # 剪贴板 → PNG + SmartScale 钩子
│   ├── SmartScale.ps1             # LLM 优化图片缩放插件
│   └── exit-all.ps1               # 清理脚本
├── temp/                          # 图片缓存（自动清理）
├── icon/                          # 应用图标
├── docs/                          # 技术文档
└── .github/workflows/             # CI/CD (GitHub Actions)
```

---

## 核心流程

### Alt+V 热键执行序列

```
用户按下 Alt+V
    │
    ├─→ 1. 保存当前键盘布局（HKL 句柄）
    │
    ├─→ 2. 通过 PostMessage(0x50) 切换到英文 (US) 布局
    │
    ├─→ 3. 生成时间戳文件名 → 20260112_180000_123.png
    │
    ├─→ 4. 构建 Windows 路径 → C:\...\temp\20260112_180000_123.png
    │
    ├─→ 5. 转换为 WSL 路径 → /mnt/c/.../temp/20260112_180000_123.png
    │
    ├─→ 6. 立即通过 SendText() 粘贴 WSL 路径 [~100ms]
    │
    ├─→ 7. 异步：启动 PowerShell 保存图片（非阻塞）
    │       │
    │       ├─→ 读取剪贴板图片
    │       ├─→ 应用 SmartScale（若 >1568px）
    │       └─→ 保存为 PNG
    │
    └─→ 8. 500ms 延迟后恢复原键盘布局
```

### 关键设计决策：路径优先架构

路径在图片保存**之前**就已粘贴完成。这种解耦设计提供：

- **即时反馈**（~100ms 响应时间）
- **非阻塞体验**（图片异步保存）
- **优雅降级**（即使保存失败，路径仍可用）

---

## Smart Scale 插件

### 目的

自动压缩大尺寸截图，减少视觉 LLM 处理时的 Token 消耗。

### 阈值：1568px

基于官方建议：
- **Claude**："如果图片长边超过 **1568 像素**... 将首先被缩小"
- **OpenAI GPT-4o**：图片被切分为 512×512 块；图片越大 = 块越多 = Token 越多
- **Gemini**：大图使用更多分片处理

### 实现逻辑

```
┌─────────────────────────────────────────────────────────────┐
│                   SmartScale.ps1                            │
├─────────────────────────────────────────────────────────────┤
│  输入: System.Drawing.Image 对象                            │
│                                                             │
│  IF max(width, height) > 1568px:                            │
│      计算缩放比例                                            │
│      创建新位图，使用：                                       │
│        • InterpolationMode: HighQualityBicubic              │
│        • SmoothingMode: HighQuality                         │
│        • PixelOffsetMode: HighQuality                       │
│        • CompositingQuality: HighQuality                    │
│      返回缩放后的图片                                        │
│  ELSE:                                                      │
│      返回原图（直通）                                        │
│                                                             │
│  依赖: 无（原生 .NET System.Drawing）                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 路径转换策略

### 优先级顺序

1. **内置正则匹配**（快速，处理 99% 的情况）
2. **回退到 `wsl wslpath`**（用于网络路径等边缘情况）

### 实现代码

```ahk
ConvertPathToWsl(winPath) {
    ; 处理常见驱动器路径 "C:\path\to\file"
    if RegExMatch(p, "^[A-Za-z]:\\") {
        drive := SubStr(p, 1, 1)
        rest := SubStr(p, 3)
        rest := StrReplace(rest, "\", "/")
        return "/mnt/" . StrLower(drive) . "/" . rest
    }
    
    ; 回退到 wsl wslpath 命令
    try {
        return Trim(RunGetStdOut('wsl wslpath -a -u "' p '"'))
    }
    return ""
}
```

---

## 输入法 (IME) 保护

### 问题

当中文/日文输入法激活时，粘贴 `/mnt/c/temp/` 这样的路径可能导致乱码或触发输入法候选。

### 解决方案

1. **启动时预加载英文布局**：`LoadKeyboardLayoutW("00000409")`
2. **粘贴前切换**：`PostMessage(0x50, 0, englishHKL)`
3. **等待切换完成**：`Sleep 100`
4. **粘贴路径**：`SendText(wslPath)`
5. **恢复原布局**：500ms 后 `PostMessage(0x50, 0, previousHKL)`

---

## 清理机制

### 定时清理（定时器）

- **间隔**：每 2 小时
- **阈值**：删除超过 2 小时的文件
- **范围**：仅 `temp/*.png`

### 退出清理（exit-all.ps1）

用户从托盘菜单选择 "Exit" 时触发：

1. 终止所有残留的 `save-clipboard-image.ps1` 进程
2. 清空 `temp/` 目录下所有文件
3. 优雅退出

---

## 技术要点总结

| 方面 | 实现 |
|------|------|
| **热键响应** | ~100ms（仅路径粘贴） |
| **图片保存** | 异步、非阻塞 |
| **输入法处理** | 预缓存英文 HKL，PostMessage 切换 |
| **路径转换** | 正则优先，wslpath 回退 |
| **图片优化** | SmartScale 插件，1568px 阈值 |
| **清理机制** | 定时器（2h）+ 退出触发 |
| **错误处理** | 静默失败，无弹窗 |
| **编码** | 含非 ASCII 的 PowerShell 脚本使用 UTF-8 with BOM |

---

## 已知限制

- 仅输出 `/mnt/...` 路径（无 Windows 原生路径模式）
- 清理策略仅基于时间阈值（无容量限制）
- 单一热键模式（仅 `Alt+V`，无 GUI 配置）

---

## 参考资料

- [Claude Vision 文档](https://platform.claude.com/docs/en/build-with-claude/vision)
- [OpenAI Vision 指南](https://platform.openai.com/docs/guides/images-vision)
- [Gemini 媒体分辨率](https://ai.google.dev/gemini-api/docs/media-resolution)
