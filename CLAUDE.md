# CLAUDE.md

## Workflow Rules — READ FIRST

**Do not write code without explicit approval.** When the user describes a change, bug, or feature:

1. **Analyze** — Read the relevant code, understand the problem
2. **Propose** — Explain your approach concisely
3. **Wait** — Get explicit approval before touching any code
4. **Implement** — Only then make changes

**Use takt for non-trivial work.** For features likely 3+ stories, suggest `/takt-prd` → `/takt` → `takt solo`/`takt team`. Opus is the analyst/architect. Sonnet implements via takt agents.

## Project Overview

Dikta is a minimal, fully offline dictation app for macOS (v0.4). Press a hotkey, speak, and your words are pasted. Menu bar app, no cloud services.

- **dikta-macos/** — Primary implementation (Swift/SwiftUI/WhisperKit)
- **dikta-windows/** — Windows port (.NET 8/C#/WPF)
- **dikta-python/** — Legacy, not actively developed

## Conventions

- **Release titles**: `Dikta vX.Y — Short Subtitle` (e.g. "Dikta v0.4 — Stability & Polish")
- **No debug builds for testing** — only release builds (`build-release.sh`)

## Build & Run

```bash
cd dikta-macos
open Dikta.xcodeproj        # Development
./scripts/build-release.sh   # Release: signed, notarized DMG → build/Dikta.dmg
```

## Detailed Docs

- **[Architecture](docs/architecture.md)** — Key files, hotkey system, config, menu structure, permissions
