# PRD: Dikta for Windows — Minimal Offline Dictation

## 1. Introduction/Overview

Dikta for Windows is a sibling project to the existing macOS Dikta app. It provides fully offline speech-to-text dictation as a system tray application on Windows 11 (x64). The user presses a global hotkey to start/stop recording, and the transcribed text is automatically pasted into the active window. No cloud services, no data leaves the machine.

The initial release targets a single user (the developer's mother) and her data-sensitive company, where cloud-based dictation tools are not acceptable.

## 2. Goals

- Provide fully offline dictation on Windows 11 with zero cloud dependencies
- Match Dikta macOS core UX: hotkey → record → transcribe → auto-paste
- Keep the app minimal and easy to install for non-technical users
- Use .NET 8 / C# / WPF as the native Windows stack
- Bundle whisper.cpp (via Whisper.net) for local speech-to-text

## 3. User Stories

### US-001: System Tray App with Recording Toggle

**Description:** As a user, I want a system tray app that I can start/stop recording with a global hotkey so that I can dictate text from anywhere on my desktop.

**Acceptance Criteria:**
- [ ] App runs as a system tray icon with a context menu (Settings, History, Quit)
- [ ] Pressing the global hotkey (default: Ctrl+Shift) starts recording; pressing again stops recording, transcribes, and pastes the result into the active window
- [ ] Tray icon visually changes to indicate recording state (e.g., red dot)
- [ ] Sound effects play on recording start and stop to confirm state changes

### US-002: Offline Speech-to-Text with Whisper

**Description:** As a user, I want my speech transcribed locally using Whisper so that my dictation data never leaves my machine.

**Acceptance Criteria:**
- [ ] Audio is transcribed using Whisper.net (whisper.cpp C# bindings) with the bundled `small` model
- [ ] Transcription produces accurate text for both English and Swedish speech
- [ ] Transcription completes within a reasonable time (under 5 seconds for a 30-second clip on a modern x64 machine)

### US-003: Settings and Customization

**Description:** As a user, I want to customize my hotkey, language, and Whisper model so that Dikta fits my workflow and language.

**Acceptance Criteria:**
- [ ] Settings accessible from tray context menu allow changing: hotkey, language (English/Swedish), Whisper model (small/medium)
- [ ] Settings persist across app restarts (saved to a local JSON config file)
- [ ] Hotkey customization uses a "press your desired hotkey" capture dialog

### US-004: Transcript History

**Description:** As a user, I want to see my recent transcriptions so that I can re-copy something I dictated earlier.

**Acceptance Criteria:**
- [ ] Tray context menu shows a "History" submenu with the last 10 transcriptions (truncated preview)
- [ ] Clicking a history entry copies its full text to the clipboard
- [ ] History persists across app restarts

### US-005: First-Run Experience and Microphone Permission

**Description:** As a user launching Dikta for the first time, I want clear guidance on granting microphone access so that recording works without confusion.

**Acceptance Criteria:**
- [ ] On first launch, if microphone access is not granted, the app shows a dialog explaining how to enable it in Windows Privacy Settings
- [ ] The app detects microphone permission status and shows a clear error state if access is denied
- [ ] First launch pre-downloads/extracts the Whisper model so subsequent starts are fast

## 4. Functional Requirements

- **FR-1:** The app must run as a Windows system tray (notification area) application with no main window.
- **FR-2:** The app must register a global hotkey using Win32 `RegisterHotKey` or low-level keyboard hook (`SetWindowsHookEx`) that works regardless of which window is focused.
- **FR-3:** Audio recording must use NAudio (or equivalent) to capture microphone input as WAV/PCM suitable for Whisper.
- **FR-4:** Speech-to-text must use Whisper.net (C# bindings for whisper.cpp) running entirely locally. No network calls.
- **FR-5:** After transcription, the app must place the text on the clipboard and simulate Ctrl+V (`SendInput`) to paste into the active window.
- **FR-6:** The app must play a start sound and a stop sound to provide audible feedback for recording state changes.
- **FR-7:** Configuration must persist as a JSON file in `%APPDATA%\Dikta\config.json`.
- **FR-8:** Transcript history must persist as a JSON file in `%APPDATA%\Dikta\history.json`, capped at the last 50 entries.
- **FR-9:** The app must bundle the Whisper `small` model. The `medium` model can be downloaded on demand when selected in settings.
- **FR-10:** The app must target .NET 8, x64, Windows 11.

## 5. Non-Goals (Out of Scope)

- **No Text-to-Speech / Read Aloud mode** — will be a future phase
- **No Push-to-Talk mode** — start with toggle only, add PTT in a later release
- **No auto-update mechanism** — manual updates for now
- **No cross-platform shared codebase** with macOS Dikta — this is a sibling project
- **No ARM64 Windows support** — x64 only for now
- **No code signing or Microsoft Store distribution** — initial distribution via zip/installer
- **No notification toasts** — sound effects provide recording feedback instead
- **No onboarding wizard** — just a first-run mic permission check and model extraction

## 6. Technical Considerations

### Stack
- **.NET 8** with C# and **WPF** for the system tray UI
- **Whisper.net** (NuGet) — C# bindings for whisper.cpp
- **NAudio** (NuGet) — audio capture
- **System.Text.Json** — config/history persistence

### Global Hotkey Approach
- `RegisterHotKey` (Win32) is simplest for modifier+key combos
- If modifier-only hotkeys are needed (like macOS Dikta's Shift+Ctrl), a low-level keyboard hook via `SetWindowsHookEx` will be required
- Start with `RegisterHotKey` for a modifier+key default (e.g., Ctrl+Shift+D), revisit if modifier-only is requested

### Model Bundling
- The Whisper `small` model (~460 MB) should be bundled or downloaded on first run
- Models stored in `%APPDATA%\Dikta\models\`
- Consider first-run extraction from a compressed archive to keep installer size down

### Dev Environment
- Development on macOS via UTM running Windows 11 ARM (x86 emulation)
- CI/CD via GitHub Actions `windows-latest` runner for build verification

## 7. Success Metrics

- User (mom) can install and dictate text within 5 minutes of first launch
- Transcription accuracy matches the macOS Dikta experience (same Whisper small model)
- App runs without any network connections (verified via firewall/network monitor)
- Recording → transcription → paste cycle completes in under 10 seconds for typical dictation

## 8. Open Questions

1. **Hotkey default:** Should we use Ctrl+Shift+D (easy with RegisterHotKey) or attempt modifier-only like macOS Dikta? Modifier-only requires more complex hook logic.
2. **Model bundling vs. first-run download:** Bundle the ~460 MB model in the installer, or download on first launch? Bundling is simpler but makes the installer large.
3. **Installer format:** Simple zip extract, Inno Setup installer, or MSIX? For a non-technical user, an installer (Inno Setup) is probably friendliest.
4. **Audio format:** NAudio can capture various formats — need to confirm what Whisper.net expects (likely 16kHz mono PCM WAV).
