# 开发流水账

## 2026-01-12
- 初始化记忆库
- 读取 README.md 以理解项目
- **[调研]** 完成三巨头 Vision API Token 计算机制调研
  - Claude: 线性像素级 (`W*H/750`)
  - OpenAI: 512px Tile 级 (`85 + Tiles*170`)
  - Gemini: 动态切片 (`CropUnit = ShortEdge/1.5`)
- **[共识]** 确定 **1568px** 作为通用安全阈值

- **[开发]** 创建分支 `feature/smart-scale-plugin` 并完成插件开发
  - ✅ 新建 `scripts/lib/SmartScale.ps1`
    - 核心函数：`Optimize-ImageObject`
    - 阈值：1568px (Long Edge)
    - 算法：HighQualityBicubic 插值
    - 无外部依赖 (Zero-Dependency, GDI+ Only)
  - ✅ 修改 `scripts/save-clipboard-image.ps1`
    - 增加 Plugin Hook (Dot-source loading)
    - Fallback 机制：插件不存在时保持原始行为
  - ✅ 提交 commit: `9639b96`
