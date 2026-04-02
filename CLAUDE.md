# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Windows-to-WSL2 clipboard image paster. Hotkey (`Alt+V`) instantly pastes a WSL-compatible image path into the active terminal, then asynchronously saves and optimizes the clipboard image in the background. Built for LLM coding agents (Claude Code, Codex CLI, Kiro CLI) that accept image paths.

## Architecture

Three-layer design: AHK orchestrator → PowerShell workers → temp file cache.

**Entry point:** `image-paster-win2wsl.ahk` (AutoHotkey v2) — hotkey listener, IME state management, path conversion, tray menu, cleanup scheduler.

**Workers (`lib/`):**
- `save-clipboard-image.ps1` — async image saver, spawned non-blocking by AHK
- `SmartScale.ps1` — LLM-optimized scaling plugin (1568px long-edge threshold, GDI+ bicubic). Called as a hook by save-clipboard-image.ps1
- `exit-all.ps1` — process cleanup + temp dir purge on exit

**Critical design decision:** Path-first architecture. The WSL path is pasted immediately (~100ms) via `SendText()` before the image is saved. This decouples user feedback from the async PowerShell save pipeline.

**IME protection:** Before pasting, the script switches to English (US) keyboard layout via `PostMessage(0x50)`, then restores the original layout after 500ms. This prevents CJK input methods from garbling the path.

**Path conversion:** Built-in regex handles `[A-Z]:\` → `/mnt/[a-z]/` (99% of cases). Falls back to `wsl wslpath` for edge cases like network paths.

**Temp cleanup:** Timer-based, every 2 hours, deletes PNGs older than 2 hours from `temp/`.

## Build & Release

No package manager. No test framework. This is a Windows desktop utility.

- **Runtime requires:** Windows 10/11 + WSL2, PowerShell 5.1+, execution policy `RemoteSigned`
- **Build requires:** AutoHotkey v2 + Ahk2Exe compiler
- **Manual compile:** Right-click `.ahk` → "Compile Script", or use Ahk2Exe GUI
- **Release:** Push a git tag (`git tag v2.x.x && git push origin v2.x.x`) → GitHub Actions auto-builds, packages, and publishes

## Languages

- AutoHotkey v2 syntax (`.ahk`) — NOT v1. Key differences: functions use `{}` blocks, `SendText()` not `SendRaw`, `:=` assignment, `#Requires AutoHotkey v2.0+`
- PowerShell 5.1 (`.ps1`) — uses `System.Drawing` (GDI+) for image processing, no external modules

## Key Conventions

- Filenames use millisecond timestamps (`YYYYMMDD_HHmmss_fff.png`) to avoid collisions
- All PowerShell scripts run with `-WindowStyle Hidden` for silent operation
- SmartScale threshold (1568px) is derived from Claude/GPT-4o/Gemini Vision API docs — don't change without reviewing upstream specs
- `Alt+V` chosen over `Ctrl+V` because terminal emulators intercept Ctrl+V at the OS level (see `docs/terminal-ctrl-v-interception.md`)
