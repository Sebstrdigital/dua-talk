# Dikta Architecture

## Pipeline

```
Hotkey → Recording → WhisperKit STT → Auto-paste + History
```

## Key Files (Swift)

- **Models/**
  - `AppConfig.swift` — Full config structure, persisted as JSON
  - `HotkeyConfig.swift` — Modifier keys (shift, ctrl, cmd, alt, fn), hotkey matching logic
  - `WhisperModel.swift` — Available models: small, medium
  - `MicDistance.swift` — Close/Normal/Far presets for speech detection sensitivity
  - `Language.swift` — Supported languages: English, Swedish, Indonesian
- **Services/**
  - `HotkeyManager.swift` — CGEventTap-based global hotkey detection (flagsChanged + keyDown/keyUp)
  - `ConfigService.swift` — Singleton config manager, persists to `~/Library/Application Support/Dikta/config.json`
  - `UpdateChecker.swift` — Checks GitHub releases for newer versions
  - `TextToSpeechService.swift` — Kokoro TTS integration via local Python server
  - `TextSelectionService.swift` — Gets selected text via Accessibility API
  - `ClipboardManager.swift` — Clipboard operations and auto-paste (Cmd+V simulation)
- **ViewModels/**
  - `MenuBarViewModel.swift` — Main app state machine (idle/loading/recording/processing/speaking), delegates hotkey events
- **Views/**
  - `MenuBarView.swift` — Menu structure: Hotkeys, Audio, Write in, Advanced
  - `OnboardingWindow.swift` — About window with permission checks, TTS install, version display, update checker
  - `HotkeyRecordingWindow.swift` — Hotkey capture UI

## Hotkey Detection

Uses `CGEvent.tapCreate` listening for `keyDown`, `keyUp`, and `flagsChanged` events. Modifier-only hotkeys (e.g., Shift+Ctrl) detected via `flagsChanged`. fn/Globe key uses `.maskSecondaryFn`.

`HotkeyConfig.matchesModifiers()` does **strict matching** — all modifiers in `ModifierKey.allCases` must match exactly.

## Hotkey Modes

- **Toggle** (default): Press to start, press again to stop
- **Push-to-Talk**: Hold to record, release to stop
- **Read Aloud**: Press to read selected text via TTS
- **Language Toggle**: Press to cycle between languages

Default hotkeys: Toggle = Shift+Ctrl, PTT = Cmd+Shift, TTS = Cmd+Alt, Language = Cmd+Ctrl.

## Config

Persisted at `~/Library/Application Support/Dikta/config.json`.

Key fields: `hotkeys` (toggle, push_to_talk, text_to_speech, language_toggle), `whisper_model`, `language`, `mic_distance`, `mute_sounds`, `mute_notifications`.

## Menu Structure

```
Dikta
├── Stop Recording / Stop Speaking / Processing...
├── History >
├── Hotkeys >
│   ├── Set Record Hotkey...
│   ├── Set Push-to-Talk Hotkey...
│   ├── Set Read Aloud Hotkey...
│   └── Set Language Toggle Hotkey...
├── Audio >
│   ├── Mute Sounds
│   ├── Mute Notifications
│   └── Mic Distance: Close / Normal / Far
├── Write in: (language) >
│   ├── English
│   ├── Svenska
│   └── Bahasa Indonesia
├── Advanced >
│   ├── Whisper Model: Small / Medium
│   └── Voice: (Kokoro voices)
├── About
└── Quit
```

## macOS Permissions

- **Microphone** — for recording (entitlement: `com.apple.security.device.audio-input`)
- **Accessibility** — for global hotkeys and auto-paste

## Text-to-Speech

Kokoro TTS is set up from the About window. Creates a Python venv at `~/Library/Application Support/Dikta/venv` and installs kokoro + dependencies.

## Release Build Notes

The re-signing step after bundling the Whisper model must pass `--entitlements` or they get stripped. This is handled in `scripts/build-release.sh`.
