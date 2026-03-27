# Dikta

A minimal, fully offline dictation app for macOS. Press a hotkey, speak, and your words are pasted instantly. No cloud services, no subscriptions.

## Install

Download the latest DMG from [Releases](https://github.com/Sebstrdigital/dikta/releases), drag to Applications, and launch. The About window opens automatically and guides you through permissions.

## Features

- **Fully Offline** — WhisperKit runs speech-to-text locally on your Mac. No data ever leaves your device.
- **Menu Bar App** — sits quietly in your menu bar, always one hotkey away
- **Three Hotkey Modes** — Toggle recording, Push-to-Talk, Language switch, and Read Aloud — all customizable
- **fn/Globe Key Support** — use the fn/Globe key as a hotkey modifier
- **Auto-paste** — transcription goes straight to your cursor via Cmd+V simulation
- **Silence Auto-Stop** — recording stops automatically after 10 seconds of silence
- **Text-to-Speech** — select text and have it read aloud via Kokoro TTS (optional, installed separately)
- **History** — access your last 5 dictations from the menu bar
- **Multi-language** — 12 languages: English, Swedish, Spanish, French, German, Portuguese, Italian, Dutch, Finnish, Norwegian, Danish, and Indonesian. Whisper transcribes what it hears regardless of the selected language — the selector is a preference hint used to improve accuracy when languages could be ambiguous (e.g. Norwegian vs Danish, Portuguese vs Spanish). For clearly different languages it has minimal effect.
- **Mic Sensitivity** — tune speech detection sensitivity for Normal or Headset use
- **Launch at Login** — optionally start Dikta automatically when you log in
- **Auto-Update** — checks for updates via Sparkle; configure in the About screen

## Permissions

The About window checks these for you on first launch:

| Permission | Why | How |
|------------|-----|-----|
| **Microphone** | Record audio | Click "Grant" on the About screen |
| **Accessibility** | Global hotkeys (CGEventTap) and auto-paste | System Settings > Privacy & Security > Accessibility |

Note: **Input Monitoring** is NOT required — Dikta uses CGEventTap which falls under Accessibility, not the separate Input Monitoring permission.

## Hotkeys

All hotkeys are customizable via **Hotkeys** in the menu bar. Collision detection warns you if two modes share the same hotkey.

| Mode | Default | Behavior |
|------|---------|----------|
| **Record** | Shift + Ctrl | Press to start, press again to stop |
| **Push-to-Talk** | Cmd + Shift | Hold to record, release to stop |
| **Read Aloud** | Cmd + Alt | Reads selected text aloud via TTS |
| **Switch Language** | Cmd + Ctrl | Cycles through available languages |

## Menu Structure

```
Dikta
├── Stop Recording / Stop Speaking / Processing...
├── History >
├── Hotkeys >
│   ├── Set Record Hotkey...
│   ├── Set Push-to-Talk Hotkey...
│   ├── Set Read Aloud Hotkey...
│   └── Set Switch Language Hotkey...
├── Audio >
│   ├── Mute Sounds
│   ├── Mute Notifications
│   └── Mic Sensitivity: Normal / Headset
├── Write in: English >
│   ├── ✓ English (enabled)
│   ├── Svenska (enabled)
│   ├── Español
│   ├── Français
│   ├── Deutsch
│   ├── Português
│   ├── Italiano
│   ├── Nederlands
│   ├── Suomi
│   ├── Norsk
│   ├── Dansk
│   └── Indonesia
├── Advanced >
│   ├── Start at Login
│   ├── Check for Updates...
│   ├── Whisper Model: Small / Medium
│   ├── Diagnostic Logging
│   └── Voice: (Kokoro TTS voices)
├── About
└── Quit
```

## Mic Sensitivity

If you get "No Speech" errors with AirPods or Bluetooth headsets, switch to **Headset** under Audio > Mic Sensitivity:

| Setting | Use when | Thresholds |
|---------|----------|------------|
| **Normal** | Built-in mic, desk mic | Balanced |
| **Headset** | AirPods, Bluetooth headsets | Permissive |

## Text-to-Speech

Select text in any app and press the Read Aloud hotkey. Set up the TTS engine from the About window — it downloads Kokoro TTS into a local Python venv automatically. Requires Python 3 installed on your system.

## Building from Source

```bash
cd dikta-macos
swift build
.build/debug/Dikta
```

Or open in Xcode:

```bash
open dikta-macos/Dikta.xcodeproj
```

### Release Build

```bash
cd dikta-macos
./scripts/build-release.sh
```

This archives, signs, bundles the Whisper model, notarizes with Apple, and produces a DMG at `build/Dikta.dmg`. Requires a Developer ID certificate and notarization credentials (see script header for setup).

## Troubleshooting

**Hotkey not working** — Check that the app is listed in System Settings > Privacy & Security > Accessibility. Restart after granting.

**"No Speech" notifications** — Try switching to **Headset** in the Audio > Mic Sensitivity menu. Also ensure the correct input device is selected in System Settings > Sound > Input before recording.

**Text-to-speech not working** — Open the About window and click "Set Up" next to Text-to-Speech. Requires Python 3 (`/usr/bin/python3` or Homebrew).

**Model loading is slow** — The Whisper model loads on first launch. A spinner is shown in the About window. Subsequent launches are faster (model stays cached).

**App won't start** — Clean and rebuild: `cd dikta-macos && rm -rf .build && swift build`

## Architecture

```
Hotkey → Recording → WhisperKit STT → Auto-paste + History
```

Key source files:

- `Models/AppConfig.swift` — Full config structure, persisted as JSON at `~/Library/Application Support/Dikta/config.json`
- `Models/HotkeyConfig.swift` — Modifier keys, hotkey matching, collision detection
- `Models/MicSensitivity.swift` — Speech detection sensitivity presets (noSpeechThreshold, logProbThreshold, silenceRMSThreshold)
- `Services/HotkeyManager.swift` — CGEventTap-based global hotkey detection
- `Services/ConfigService.swift` — Singleton config manager with atomic writes
- `Services/Transcriber.swift` — WhisperKit integration with timeout and progress callbacks
- `Services/AudioRecorder.swift` — AVAudioEngine recording with silence auto-stop
- `ViewModels/MenuBarViewModel.swift` — Main app state machine (idle/loading/recording/processing/speaking)
- `Views/OnboardingWindow.swift` — About/setup screen with permissions, TTS install, launch at login
- `Views/HotkeyRecordingWindow.swift` — Hotkey capture UI with collision warning

## Resources

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) — On-device speech recognition for Apple Silicon
- [Kokoro TTS](https://github.com/hexgrad/kokoro) — Text-to-speech engine

## License

[MIT License](LICENSE)
