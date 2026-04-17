# Feature: Windows Onboarding Startup Modal (F-4)

**Epic:** [Dikta Windows v1.2 — MVP Reliability & Polish](epic-windows-v12-mvp-reliability.md)

## 1. Introduction/Overview

Non-technical Windows users launching Dikta today see nothing — the app installs a tray icon and waits. They don't know the default hotkey is Ctrl+Shift+D, they don't know whether the mic permission is granted, and they have no visible confirmation that the app is running. This Feature adds an onboarding modal shown on every launch (with an opt-out checkbox), mirroring the role macOS `OnboardingWindow` plays. The modal also serves as the foreground target when a second app instance is launched (via the Mutex from F-1).

## 2. Goals

- Every launch surfaces a visible modal confirming Dikta is running
- The modal shows current mic permission status with a Grant button when missing
- The modal shows the current dictation hotkey binding
- A "Don't show on startup" checkbox lets power users suppress future modals
- The modal is reachable from the tray `About` menu item at any time
- A second app launch brings the existing instance's modal to the foreground

## 3. User Stories

### US-001: Modal shown on every launch by default

**Description:** As a non-technical user, I want to see something when I start Dikta so that I know it's ready and what hotkey to press.

**Acceptance Criteria:**
- [ ] When Dikta launches and `ShowOnStartup` is true (default), an Onboarding modal window appears
- [ ] The modal shows: Dikta version, current hotkey binding, current microphone permission status, and a "Don't show on startup" checkbox
- [ ] Unchecking "Don't show on startup" and closing the modal persists the preference so future launches skip the modal

### US-002: Mic permission status + Grant button

**Description:** As a user, I want the modal to tell me whether Dikta can access my microphone so that I'm not confused when my first dictation produces no text.

**Acceptance Criteria:**
- [ ] The modal displays a clear status: "Microphone: Granted" (green) or "Microphone: Not granted" (red)
- [ ] When not granted, a "Grant" button opens `ms-settings:privacy-microphone` so the user can enable access without leaving Dikta
- [ ] The status refreshes when the modal regains focus (so the user sees the updated state after granting)

### US-003: Reachable from tray About menu

**Description:** As a user, I want to re-open the onboarding modal at any time so that I can check my hotkey or version without restarting the app.

**Acceptance Criteria:**
- [ ] The tray right-click menu has an `About` item (above Settings or near Quit)
- [ ] Clicking `About` opens the same Onboarding modal, whether `ShowOnStartup` is true or false
- [ ] Opening About while the modal is already visible brings it to the foreground instead of opening a duplicate

### US-004: Second-instance foreground activation

**Description:** As a user, I want launching Dikta a second time to show me the existing instance so that I know it's already running.

**Acceptance Criteria:**
- [ ] Launching `DiktaWindows.exe` while an instance is already running does not create a second process
- [ ] The existing instance's Onboarding modal comes to the foreground
- [ ] If the modal is closed, launching a second time re-opens it on the existing instance

### US-005: Mic permission status query

**Description:** As a user, I want the mic permission status to reflect reality so that a "Granted" label means dictation will work.

**Acceptance Criteria:**
- [ ] The status query uses an API that returns the current Windows mic permission state for this app
- [ ] The "Granted" status only shows when `WaveIn.DeviceCount > 0` AND the permission check succeeds
- [ ] "Not granted" is shown when either condition fails

## 4. Functional Requirements

- FR-1: `OnboardingWindow` is a WPF `Window` with content: Dikta logo/text, version (from assembly), hotkey binding (formatted as "Ctrl+Shift+D"), mic status label + Grant button (when not granted), "Don't show on startup" `CheckBox` (bound to `AppConfig.ShowOnStartup`, default `true`).
- FR-2: `AppConfig` gains `ShowOnStartup` (default `true`) persisted like other fields.
- FR-3: `App.OnStartup` shows the modal if `ShowOnStartup == true`; always accessible via tray `About`.
- FR-4: The second-instance activation (from F-1 Mutex) posts a `WM_APP + 1` message to the existing instance's HwndSource; the handler opens/focuses the OnboardingWindow.
- FR-5: The Grant button launches `Process.Start(new ProcessStartInfo("ms-settings:privacy-microphone") { UseShellExecute = true })`.
- FR-6: Mic permission query: call `WaveIn.DeviceCount` (returns 0 when permission is denied in practice); secondary check via `MMDeviceEnumerator.EnumerateAudioEndPoints(DataFlow.Capture, DeviceState.Active)` state flags if available without adding dependencies.
- FR-7: The modal refreshes mic status on `Activated` event.

## 5. Non-Goals (Out of Scope)

- Animated onboarding tutorial / multi-step wizard
- Interactive permission grant flow that bypasses Settings (Windows does not allow this for privacy APIs)
- Localized text (English only)
- Modal theming / dark mode
- Video or GIF demonstrations
- Telemetry that the modal was shown

## 6. Design Considerations

- **Visual style:** Match macOS `OnboardingWindow`'s Scandinavian minimalism. Plain Segoe UI, gentle spacing, no branding flourishes. Fixed size (~ 480 × 360), centered on screen, non-resizable.
- **"Don't show on startup" placement:** Bottom-left, small font, not attention-grabbing. Non-tech users won't notice it (good); power users can find it (also good).
- **Mic status color:** Subtle green / red; not large emoji. The word "Granted" or "Not granted" carries the signal.
- **Hotkey display:** Formatted as `Ctrl + Shift + D` (spaced) for readability, not raw `Ctrl+Shift+D`.

## 7. Technical Considerations

- **Mutex activation (from F-1):** Needs a cross-instance signal channel. Chosen approach: `PostMessage(HWND_BROADCAST, regMsg, 0, 0)` with a registered window message (`RegisterWindowMessage("DiktaShowOnboarding")`). The existing instance listens via the HwndSource from `HotkeyManager` (or a new dedicated hidden window). Simpler than named pipes; no listener thread.
- **Mic permission in Windows 10/11:** There is no direct "is permission granted" query available without adding `Windows.Security.Authorization.AppCapabilityAccess` (WinRT) which requires packaging changes. Heuristic: `WaveIn.DeviceCount == 0` on a machine with a connected mic strongly implies denied permission.
- **`ms-settings:` URI:** Opens Windows Settings directly. No admin elevation needed.

## 8. Success Metrics

- Tester confirms modal appears on first launch without prompting
- Tester can see mic status correctly reflect their state (granted/not granted)
- Tester can open Settings and grant permission via the Grant button
- Second launch does not start a second process; foregrounds the modal

## 9. Open Questions

1. **`About` menu placement** — above Settings, or separate? macOS has a dedicated About window. Suggest: top of menu, above `History`.
2. **"Don't show on startup" default** — I proposed `true` (show every launch) based on your preference for non-tech users. Confirm this applies even once the user has been onboarded? Alternative: auto-switch to `false` after the user unchecks it once.
3. **Windows 10 mic permission on framework-dependent publish** — Does the permission prompt appear the first time `WaveIn.StartRecording` runs, or only via the Windows Settings path? If the former, we may not need the Grant button — just a "Try recording once" hint.
4. **Accessibility** — screen readers should read the modal content. WPF defaults are generally OK but worth confirming with `AutomationProperties.Name` on key controls.
