# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Local Dictation Tool is a minimal, fully offline dictation application that transcribes speech to clipboard using a global hotkey. It's a local alternative to Wispr Flow, using Whisper for speech-to-text.

## Development Commands

```bash
# Install dependencies (recommended)
uv sync
source .venv/bin/activate

# Alternative: pip install
pip install -e .

# Run the dictation tool
python dictation.py

# Run with LLM cleanup (requires Ollama)
python dictation.py --cleanup

# Run with different Whisper model
python dictation.py --whisper-model small.en
```

## Prerequisites

For basic dictation, no external services are required.

For LLM cleanup feature, Ollama must be running locally:
```bash
ollama pull gemma3
```

## Architecture

The application follows a simple pipeline:

```
Hotkey (Shift+Ctrl) → Recording → Whisper STT → (optional LLM cleanup) → Clipboard
```

### Key Components

- **dictation.py**: Main application with global hotkey listener
  - Global hotkey detection via `pynput`
  - Audio recording via `sounddevice`
  - Speech-to-text via Whisper
  - Optional text cleanup via Ollama
  - Clipboard integration via `pyperclip`
  - Audio feedback (beeps) for user feedback

### Audio Feedback

- **600 Hz beep**: Recording started
- **400 Hz beep**: Recording stopped (processing)
- **800 Hz double beep**: Clipboard ready

## CLI Arguments

- `--cleanup`: Use LLM to clean transcription (remove fillers, fix punctuation)
- `--model`: Ollama model for cleanup (default: gemma3)
- `--whisper-model`: Whisper model size (default: base.en)

## Building the macOS App Bundle

The app can be packaged as a standalone macOS menu bar application using py2app.

### Install Build Dependencies

```bash
# Note: py2app 0.28.9+ has compatibility issues with newer setuptools
uv pip install "py2app>=0.28.0,<0.28.9" "setuptools>=69.0.0,<80"
# or
pip install "py2app>=0.28.0,<0.28.9" "setuptools>=69.0.0,<80"
```

### Build Commands

```bash
# Development build (alias mode, fast, uses system Python)
python setup.py py2app -A

# Production build (standalone, includes all dependencies)
python setup.py py2app
```

The built app will be at `dist/Dictation.app`.

### Running the App

```bash
# Open the built app
open dist/Dictation.app

# Or run directly for development
python dictation.py
```

### Menu Bar Features

- **Icon states**: 🎤 (idle), 🔴 (recording), ⏳ (processing)
- **Menu**: Start/Stop Recording, Toggle Cleanup, Quit
- **Hotkey**: Shift+Ctrl still works for hands-free operation
- **Notifications**: macOS notifications for status updates

## macOS Permissions

The app requires these permissions:
- **Microphone**: For recording audio (System Preferences → Privacy & Security → Microphone)
- **Accessibility**: For global hotkey detection (System Preferences → Privacy & Security → Accessibility)

Add Terminal/IDE during development, or Dictation.app after building.
