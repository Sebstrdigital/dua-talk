# dikta-windows Verification Checklist

Run these steps on Windows 11 VM after pulling commit `57e9a3e`.

## Build

- [ ] `dotnet restore` — NuGet packages resolve (Whisper.net 1.9.0, NAudio 2.2.1)
- [ ] `dotnet build` — zero errors, zero warnings

## Runtime

- [ ] `dotnet run` — tray icon appears in system tray
- [ ] No crash on startup (HotkeyManager self-creates HwndSource)
- [ ] Right-click tray icon — context menu shows History, Settings, Quit

## Hotkey (Ctrl+Shift+D)

- [ ] Press Ctrl+Shift+D — recording starts (system beep sound)
- [ ] Press Ctrl+Shift+D again — recording stops (asterisk sound)
- [ ] No key-repeat flood when holding the hotkey (MOD_NOREPEAT)
- [ ] Hotkey works from any focused application

## Transcription

- [ ] Place a model file at `%APPDATA%/Dikta/models/ggml-small.bin`
- [ ] Record a short phrase, verify transcription completes
- [ ] Transcribed text appears in clipboard and auto-pastes (Ctrl+V)
- [ ] Temp WAV file is cleaned up from `%TEMP%`

## Clipboard

- [ ] Paste lands correctly in Notepad
- [ ] Paste lands correctly in a browser text field
- [ ] No `CLIPBRD_E_CANT_OPEN` errors in debug output

## History

- [ ] After transcription, History submenu shows the transcribed text
- [ ] Clicking a history item copies it to clipboard

## Edge Cases

- [ ] Double-press during transcription is ignored (processing guard)
- [ ] Missing model file — shows warning dialog, does not crash
- [ ] Quit from tray menu — app exits cleanly, no orphan processes

## Mute

- [ ] Set `mute_sounds: true` in `%APPDATA%/Dikta/config.json` — no beep/asterisk sounds

## Done

Delete this file after verification passes.
