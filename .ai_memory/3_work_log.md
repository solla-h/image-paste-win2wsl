# 开发流水账

## 2026-01-12
- 初始化记忆库
- 读取 README.md 以理解项目
- **[调研]** 完成关于 Claude/GPT-4o/Gemini 图片处理机制的调研
  - 确认均为 Native Multimodal (Visual Tokens)，非 OCR
  - 确认图片大小直接影响 Token 消耗（基于 Tile/Patch 切分）
  - 确认图片 Token 占用上下文窗口
  - 收集了 OpenAI, Anthropic, Google 的相关计费与技术文档信源

- **[调研]** 完成关于图片压缩/优化的调研
  - 核心发现：Token 是按 Tile (如 512x512) 计费的，减少 Tile 数量是关键。
  - 优化方案：Smart Cropping, Resolution Alignment.

- **[调研]** 智能缩放安全阈值 (Safe Resolution Threshold)
  - 详细结论：OpenAI 内部会压到 768px (最短边)。Claude 建议 1.15MP。
  - 最终建议：保留 Claude 3.5 原生分辨率 (1568px) 作为最佳平衡点。

- **[重大发现]** 深入研究 Claude Vision 文档
  - **计费逻辑**：像素级线性计费 (`width * height / 750`)。
  - **最佳实践**：目标 1.15 megapixels (1568px long edge)。

- **[重大发现]** 深入研究 OpenAI Vision 文档
  - **计费逻辑**：Tile 级计费 (512x512)。公式：`85 + (Tiles * 170)`。
  - **算法**：先 scale long <= 2048, 再 scale short = 768px。
  - **最佳实践**：控制最短边在 768px 左右，或激进至 512px。

- **[重大发现]** 深入研究 Gemini Vision 文档 (https://ai.google.dev/gemini-api/docs/tokens)
  - **核心机制**：切片计费 (768x768 基础)。
  - **算法**：`crop_unit = min(W,H)/1.5`，Token = `ceil(W/crop)*ceil(H/crop)*258`。
  - **小图优惠**：<= 384x384 固定 258 tokens。
  - **最佳实践**：1568px 依然是黄金点（兼容 Claude/OpenAI，且在 Gemini 下不过分触发切片）。

## 核心共识 (v2.1 优化方案)
**Universal Safe Resolution**: 
1. **Rule**: If `max(W, H) > 1568`, scale maintaining aspect ratio so `long_edge = 1568`.
2. **Benefit**:
   - Claude: 完美 1.15MP 甜点，无损。
   - OpenAI: 缩放后短边通常 < 768px，触发较少 Tiles。
   - Gemini: 触发适量 Tiles，保留细节。
3. **Action**: 将在 PowerShell 脚本中实现此逻辑。
