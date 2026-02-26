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
- **Multi-language** — English, Swedish, and Indonesian
- **Mic Distance** — tune speech detection sensitivity for Close, Normal, or Far/Headset scenarios
- **Launch at Login** — optionally start Dikta automatically when you log in

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
│   └── Mic Distance: Close / Normal / Far/Headset
├── Write in: English >
│   ├── English
│   ├── Svenska
│   └── Indonesia
├── Advanced >
│   ├── Start at Login
│   ├── Whisper Model: Small / Medium
│   └── Voice: (Kokoro TTS voices)
├── About
└── Quit
```

## Mic Distance

If you get "No Speech" errors, adjust **Mic Distance** under Audio:

| Setting | Use when | Thresholds |
|---------|----------|------------|
| **Close** | Laptop mic at 15–30cm | Strict (Whisper defaults) |
| **Normal** | Desk mic at ~50cm | Balanced |
| **Far / Headset** | AirPods, Bluetooth headsets | Permissive |

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

**"No Speech" notifications** — Try adjusting **Mic Distance** in the Audio menu. For AirPods, use "Far / Headset". Also ensure the correct input device is selected in System Settings > Sound > Input before recording.

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
- `Models/MicDistance.swift` — Speech detection sensitivity presets (noSpeechThreshold, logProbThreshold)
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
