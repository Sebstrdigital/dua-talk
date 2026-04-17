# Feature: Windows Mic Sensitivity Preset (F-7)

**Epic:** [Dikta Windows v1.2 — MVP Reliability & Polish](epic-windows-v12-mvp-reliability.md)

## 1. Introduction/Overview

Bluetooth and headset microphones deliver weaker signals than desk-level mics. Whisper's default `no_speech_threshold` of 0.6 treats weak signals as silence, producing empty transcriptions. macOS Dikta solves this with a Normal / Headset preset that tunes Whisper's decoding thresholds. Whisper.net exposes the same knob via `.WithNoSpeechThreshold(float)` on the processor builder. This Feature adds a matching preset to Windows, persists it in `AppConfig`, and wires it into the cached `WhisperFactory` + processor pipeline from F-1.

## 2. Goals

- Bluetooth / headset users can switch to a Headset preset and get reliable transcriptions
- The preset persists across app restarts
- The preset is reachable from Settings without a full UI redesign

## 3. User Stories

### US-001: MicSensitivity enum and config wiring

**Description:** As a user, I want Dikta to remember my mic sensitivity choice so that I don't have to reconfigure every launch.

**Acceptance Criteria:**
- [ ] A `MicSensitivity` enum (`Normal`, `Headset`) is added to `Models/`
- [ ] `AppConfig` has a `MicSensitivity` field (default `Normal`, JSON property `mic_sensitivity`)
- [ ] The setting persists in `%APPDATA%\Dikta\config.json` across restarts

### US-002: Settings UI toggle

**Description:** As a user, I want to change mic sensitivity from Settings so that I can switch profiles when I switch from laptop mic to headset.

**Acceptance Criteria:**
- [ ] The SettingsWindow has a "Microphone" section with a two-option segmented control or ComboBox: Normal / Headset
- [ ] The current setting is pre-selected when the window opens
- [ ] Save persists the chosen value; Cancel discards the change

### US-003: Wire preset into Whisper.net processor

**Description:** As a user on a headset, I want Dikta to correctly transcribe my voice so that weak signals don't produce empty output.

**Acceptance Criteria:**
- [ ] When `MicSensitivity` is `Normal`, the Whisper processor is built with `.WithNoSpeechThreshold(0.3f)`
- [ ] When `MicSensitivity` is `Headset`, the processor is built with `.WithNoSpeechThreshold(0.15f)`
- [ ] A Bluetooth headset recording that previously returned empty now returns usable text (verified on tester hardware)

## 4. Functional Requirements

- FR-1: `Models/MicSensitivity.cs` declares an enum with `Normal` and `Headset` values, a `DisplayName` property (for UI), and a `NoSpeechThreshold` `float` property (0.3 for Normal, 0.15 for Headset).
- FR-2: `AppConfig` gains `MicSensitivity Sensitivity { get; set; } = MicSensitivity.Normal;` with `[JsonPropertyName("mic_sensitivity")]`.
- FR-3: `TranscriberService` reads `_configService.Config.Sensitivity` when building each processor and calls `.WithNoSpeechThreshold(value.NoSpeechThreshold)` on the builder.
- FR-4: If sensitivity changes in Settings and is saved, subsequent transcriptions pick up the new value automatically (the processor is built per-transcription; the factory can stay cached per F-1).
- FR-5: SettingsWindow adds a `Microphone` label and a ComboBox or RadioButtons bound to the enum.
- FR-6: JSON serialization uses the enum name as string (`"Normal"`, `"Headset"`) via `JsonStringEnumConverter`.

## 5. Non-Goals (Out of Scope)

- Silence auto-stop based on RMS threshold — explicitly deferred per epic
- `LogProbThreshold` tuning — not exposed by current Whisper.net release
- Manual numeric threshold override for power users
- Auto-detect headset / mic type
- Per-language threshold overrides
- VAD (voice activity detection) configuration

## 6. Design Considerations

- **UI placement:** A "Microphone" section below the Hotkey section in SettingsWindow. Compact — just a label + a two-option control.
- **Labels:** "Normal (desk / laptop mic)" and "Headset (Bluetooth / wired headset)" so users know which to pick.
- **No tray menu toggle:** Keep this in Settings only. A tray toggle would add menu clutter for a rarely-changed setting.

## 7. Technical Considerations

- **Whisper.net builder chain:** Per the Whisper.net 1.9.0 API, `.WithLanguage(code).WithNoSpeechThreshold(0.3f).Build()` is the chain. Verify the exact method name (`WithNoSpeechThreshold` vs `WithNoSpeechProb` vs `NoSpeechThreshold`) at implementation time — the skill must check the installed package's actual API.
- **Threshold value mapping:** macOS uses 0.3 / 0.15 after internal tuning with real Bluetooth recordings. Start with the same values; tester feedback can adjust.
- **Cached factory + per-call processor:** F-1 caches the `WhisperFactory`. Per-call `CreateBuilder()` still picks up the current config value, so no cache invalidation is needed on sensitivity change.

## 8. Success Metrics

- Tester on a Bluetooth headset switches to Headset preset and gets usable transcriptions from a previously-failing setup
- Sensitivity choice persists across restarts
- No regression in Normal-preset behavior for desk-mic users

## 9. Open Questions

1. **Whisper.net API method name** — I'm writing `.WithNoSpeechThreshold(float)` based on expected API. The implementer must confirm against the actual Whisper.net 1.9.0 `WhisperProcessorBuilder` members. If the method is named differently, adjust.
2. **Default `Normal` for all users** — OK given most users are on laptop mics. Headset users self-select when dictation fails. Confirm.
3. **Migration of existing config** — Users upgrading from v1.1 will have no `mic_sensitivity` field in their JSON. Default-on-deserialize handles this cleanly (no migration needed). Confirm with a round-trip test.
