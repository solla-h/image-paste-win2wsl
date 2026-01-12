# Architecture & Technical Flow

This document provides a technical deep-dive into the component design, execution flow, and implementation details of Image Paste Win2WSL.

---

## Component Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    image-paster-win2wsl.exe (AutoHotkey v2)              │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  • Alt+V hotkey listener                                           │  │
│  │  • Input method (IME) state capture & restore                      │  │
│  │  • Path conversion (Windows → WSL)                                 │  │
│  │  • Tray menu & status notifications                                │  │
│  │  • Scheduled cleanup dispatcher (every 2 hours)                    │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                    │                                      │
│           ┌────────────────────────┼────────────────────────┐             │
│           ▼                        ▼                        ▼             │
│  ┌─────────────────────┐  ┌─────────────────┐      ┌───────────────┐     │
│  │ lib/save-clipboard- │  │ lib/SmartScale  │      │    temp/      │     │
│  │     image.ps1       │  │     .ps1        │      │    *.png      │     │
│  │                     │  │                 │      │               │     │
│  │ • Async image save  │  │ • Image resize  │      │ • Image cache │     │
│  │ • Calls SmartScale  │  │ • LLM optimize  │      │ • Auto-purged │     │
│  │ • Silent errors     │  │ • 1568px limit  │      │               │     │
│  └─────────────────────┘  └─────────────────┘      └───────────────┘     │
│                                                                           │
│  ┌─────────────────────┐                                                  │
│  │  lib/exit-all.ps1   │  Called on tray "Exit": terminates processes,   │
│  │                     │  clears temp directory                          │
│  └─────────────────────┘                                                  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
image-paste-win2wsl/
├── image-paster-win2wsl.ahk    # Main AutoHotkey script
├── image-paster-win2wsl.exe    # Compiled executable (from Releases)
├── lib/
│   ├── save-clipboard-image.ps1   # Clipboard → PNG + SmartScale hook
│   ├── SmartScale.ps1             # LLM-optimized image scaling plugin
│   └── exit-all.ps1               # Cleanup script
├── temp/                          # Image cache (auto-cleaned)
├── icon/                          # Application icons
├── docs/                          # Technical documentation
└── .github/workflows/             # CI/CD (GitHub Actions)
```

---

## Core Flow

### Alt+V Hotkey Sequence

```
User presses Alt+V
    │
    ├─→ 1. Save current keyboard layout (HKL handle)
    │
    ├─→ 2. Switch to English (US) layout via PostMessage(0x50)
    │
    ├─→ 3. Generate timestamped filename → 20260112_180000.png
    │
    ├─→ 4. Build Windows path → C:\...\temp\20260112_180000.png
    │
    ├─→ 5. Convert to WSL path → /mnt/c/.../temp/20260112_180000.png
    │
    ├─→ 6. Paste WSL path immediately via SendText() [~100ms]
    │
    ├─→ 7. Async: Launch PowerShell to save image (non-blocking)
    │       │
    │       ├─→ Read clipboard image
    │       ├─→ Apply SmartScale (if >1568px)
    │       └─→ Save as PNG
    │
    └─→ 8. Restore original keyboard layout after 500ms delay
```

### Key Design Decision: Path-First Architecture

The path is pasted **before** the image is saved. This decoupling provides:

- **Instant feedback** (~100ms response time)
- **Non-blocking UX** (image saves asynchronously)
- **Graceful degradation** (path works even if save fails)

---

## Smart Scale Plugin

### Purpose

Automatically resize large screenshots to reduce token consumption when processed by Vision LLMs.

### Threshold: 1568px

Based on official recommendations:
- **Claude**: "If your image's long edge is more than **1568 pixels**... it will first be scaled down"
- **OpenAI GPT-4o**: Images are tiled into 512×512 chunks; larger images = more tiles = more tokens
- **Gemini**: Larger images processed with more slices

### Implementation

```
┌─────────────────────────────────────────────────────────────┐
│                   SmartScale.ps1                            │
├─────────────────────────────────────────────────────────────┤
│  Input: System.Drawing.Image object                         │
│                                                             │
│  IF max(width, height) > 1568px:                            │
│      Calculate scale ratio                                  │
│      Create new bitmap with:                                │
│        • InterpolationMode: HighQualityBicubic              │
│        • SmoothingMode: HighQuality                         │
│        • PixelOffsetMode: HighQuality                       │
│        • CompositingQuality: HighQuality                    │
│      Return scaled image                                    │
│  ELSE:                                                      │
│      Return original image (pass-through)                   │
│                                                             │
│  Dependencies: None (native .NET System.Drawing)            │
└─────────────────────────────────────────────────────────────┘
```

---

## Path Conversion Strategy

### Priority Order

1. **Built-in regex** (fast, handles 99% of cases)
2. **Fallback to `wsl wslpath`** (for edge cases like network paths)

### Implementation

```ahk
ConvertPathToWsl(winPath) {
    ; Handle common drive paths "C:\path\to\file"
    if RegExMatch(p, "^[A-Za-z]:\\") {
        drive := SubStr(p, 1, 1)
        rest := SubStr(p, 3)
        rest := StrReplace(rest, "\", "/")
        return "/mnt/" . StrLower(drive) . "/" . rest
    }
    
    ; Fallback to wsl wslpath command
    try {
        return Trim(RunGetStdOut('wsl wslpath -a -u "' p '"'))
    }
    return ""
}
```

---

## Input Method (IME) Protection

### Problem

When Chinese/Japanese IME is active, pasting a path like `/mnt/c/temp/` can result in garbled text or trigger IME suggestions.

### Solution

1. **Preload English layout** on startup: `LoadKeyboardLayoutW("00000409")`
2. **Switch before paste**: `PostMessage(0x50, 0, englishHKL)`
3. **Wait for switch**: `Sleep 100`
4. **Paste path**: `SendText(wslPath)`
5. **Restore original layout**: `PostMessage(0x50, 0, previousHKL)` after 500ms

---

## Cleanup Mechanisms

### Periodic Cleanup (Timer)

- **Interval**: Every 2 hours
- **Threshold**: Delete files older than 2 hours
- **Scope**: `temp/*.png` only

### Exit Cleanup (exit-all.ps1)

Triggered when user selects "Exit" from tray menu:

1. Terminate any lingering `save-clipboard-image.ps1` processes
2. Clear all files in `temp/` directory
3. Exit gracefully

---

## Technical Highlights

| Aspect | Implementation |
|--------|----------------|
| **Hotkey response** | ~100ms (path paste only) |
| **Image save** | Async, non-blocking |
| **IME handling** | Pre-cached English HKL, PostMessage switch |
| **Path conversion** | Regex-first, wslpath fallback |
| **Image optimization** | SmartScale plugin, 1568px threshold |
| **Cleanup** | Timer-based (2h) + exit-triggered |
| **Error handling** | Silent failures, no pop-ups |
| **Encoding** | UTF-8 with BOM for non-ASCII PowerShell scripts |

---

## Known Limitations

- Only outputs `/mnt/...` paths (no Windows native path mode)
- Cleanup uses time threshold only (no capacity limit)
- Single hotkey mode (`Alt+V` only, no GUI config)

---

## References

- [Claude Vision Documentation](https://platform.claude.com/docs/en/build-with-claude/vision)
- [OpenAI Vision Guide](https://platform.openai.com/docs/guides/images-vision)
- [Gemini Media Resolution](https://ai.google.dev/gemini-api/docs/media-resolution)
