# Active Alerts

| Status | Alert | First Seen | Last Seen |
|--------|-------|------------|-----------|
| mitigated | Workers unable to use Bash (background agents denied, foreground requires constant approval) | 2026-02-20 | 2026-03-07 |
| mitigated | Self-contained test types must be manually synced with production code | 2026-02-26 | 2026-03-29 |
| confirmed | swift test never run end-to-end — unit tests unverified across all runs | 2026-02-26 | 2026-04-17 |
| confirmed | ConfigService has redundant atomic write strategies — never cleaned up across multiple runs | 2026-03-07 | 2026-04-17 |
| confirmed | xcodebuild broken in agent environment (IDESimulatorFoundation symbol not found) | 2026-03-14 | 2026-04-17 |
| confirmed | AudioRecorder.swift subsystems (retry, converter, silence detection) never refactored into focused types | 2026-03-27 | 2026-04-17 |
| confirmed | DiagnosticLogger never gated or removed before release | 2026-03-27 | 2026-04-17 |
| confirmed | CHANGELOG.md [0.6] entry missing bracket noise token strip fix | 2026-03-27 | 2026-04-17 |
| confirmed | Pre-existing working-tree changes from v0.6 never committed to main | 2026-03-27 | 2026-04-17 |
| confirmed | 17 zombie agent panes accumulate during parallel sprints — no automatic cleanup mechanism | 2026-03-27 | 2026-04-17 |
| confirmed | Test file inline-copy of production formatters is a permanent manual burden — no automation | 2026-03-29 | 2026-04-17 |
| confirmed | Windows build never verified end-to-end on actual Windows hardware | 2026-04-17 | 2026-04-17 |
| potential | Account usage limit hit mid-sprint — spawned workers terminated, session agent completed remaining stories | 2026-04-17 | 2026-04-17 |

---

## Retro: 2026-04-17 — takt/windows-v12-sprint-2

### What Went Well
- **All 10 stories delivered, 0 blocked.** Sprint covered F-3 (Model Download Robustness), F-4 (Onboarding Modal), and F-7 (Mic Sensitivity Preset) across 3 waves.
- **Model download hardening was surgical**: US-001 (HttpClient timeout) and US-002 (post-download size validation with 1% tolerance + .tmp file preservation on mismatch) landed cleanly with no blockers. Decisions well-reasoned and captured in workbooks.
- **Onboarding modal wired correctly end-to-end**: US-003 through US-007 form a coherent feature with proper ConfigService injection, atomic ShowOnStartup persistence, Activated-event mic status refresh, and second-instance foreground activation via the Sprint 1 HotkeyManager event.
- **MicSensitivity enum design is idiomatic**: US-008 used JsonStringEnumConverter for human-readable config.json ("Normal"/"Headset"), US-009 correctly used fully-qualified DiktaWindows.Models.MicSensitivity to avoid WPF Window.Language-style shadowing — same pattern from Sprint 1 retained.
- **US-009/US-010/US-007 completed by session agent when workers hit usage limit** — feature scope was fully delivered despite mid-sprint worker failures. No scope reduction.

### What Didn't Go Well
- **Account usage limit terminated 3 spawned workers mid-sprint**: US-007 (haiku), US-009 (sonnet), US-010 (haiku) were completed by the session agent. This is a new failure mode — previous sprints had full worker coverage.
- **US-010 has an unverified API assumption**: Session agent noted `WithNoSpeechThreshold` is assumed based on Whisper.net 1.9.0 convention; if the actual method name differs (e.g. `WithNoSpeechProb`), it will fail to compile. Flagged for Phase 4b CI to catch.
- **Build verification still impossible in agent environment**: All 10 stories validated by code inspection only. No Windows hardware run performed.
- **Parallel wave timing produces no meaningful per-story data**: Wave 1 (131s), Wave 2 (1772s), Wave 3 (0s) — individual durations reflect wave grouping, not story effort.

### Patterns Observed
- **Worker usage limits are now a real operational risk**: 3 of 10 stories fell back to the session agent. Larger sprints or repeated back-to-back runs may exhaust quota mid-wave. Consider smaller waves or rate-limit awareness.
- **Windows feature delivery remains fast and clean when scoped correctly**: No merge conflicts, no ambiguity blockers across all 10 stories. The onboarding feature (5 interdependent stories across 3 waves) resolved cleanly via explicit `dependsOn` ordering.
- **"Verified by code inspection" is now a sprint-defining pattern for Windows**: This is the third consecutive Windows sprint where every AC is passed by reading, not building. The gap between "implemented" and "works on Windows" compounds with each sprint.
- **TrayIconManager.cs continues as a hotspot**: US-005 and US-006 both modified it this sprint; Sprint 1 had 4 stories touch it. Dependency management via `dependsOn` is working but the file is accumulating complexity.

### Action Items
- [ ] [carried 11x] Add a note to story templates for Swift/Apple platform work: flag CoreFoundation types as requiring `CFGetTypeID` guards
  Suggested story: Codify a Swift story template section listing known platform gotchas (CFGetTypeID, async actor isolation, Xcode project.pbxproj sync)
- [ ] [carried 12x] Run `swift test` end-to-end to verify unit tests actually execute
  Suggested story: Add a CI step or pre-release checklist item that runs `swift test` and gates the release
- [ ] [carried 12x] Simplify ConfigService atomic write (remove either `.atomic` flag or `replaceItemAt`)
  Suggested story: Audit ConfigService.swift and pick one atomic write strategy, remove the redundant one
- [ ] [carried 9x] Fix xcodebuild test bundle code signing mismatch (`different Team IDs`) so unit tests can actually run
  Suggested story: Investigate and fix the Team ID mismatch that prevents xcodebuild test from running
- [ ] [carried 9x] Consider extracting AudioRecorder.swift subsystems (retry logic, converter lifecycle, silence detection) into focused types
  Suggested story: Refactor AudioRecorder.swift — split retry/backoff, AVAudioConverter lifecycle, and silence detection into separate structs or actors
- [ ] [carried 8x] Commit or remove DiagnosticLogger before next release — decide if it stays as a permanent debug tool or is stripped
  Suggested story: Gate DiagnosticLogger behind a compile flag or remove it; update MEMORY.md accordingly
- [ ] [carried 8x] Add `[BLANK_AUDIO]` / bracket noise token fix to CHANGELOG.md under [0.6] entry
  Suggested story: Update CHANGELOG.md [0.6] section with the bracket noise token strip fix
- [ ] [carried 7x] Commit pre-existing working-tree changes from v0.6 work (AppConfig.swift, ConfigService.swift, DiagnosticLogger.swift) to main before starting next sprint
  Suggested story: Stage and commit the v0.6 working-tree files that were never committed (AppConfig.swift, ConfigService.swift, DiagnosticLogger.swift)
- [ ] [carried 4x] Verify Windows build end-to-end on a Windows machine: `dotnet build`, `dotnet run`, hotkey registration, model download, transcription, and Inno Setup compilation
  Suggested story: Add a Windows smoke-test checklist to VERIFY.md or the release runbook; run it manually before every Windows release
- [ ] [carried 4x] Add Windows verification step to release checklist (VERIFY.md or build-release.sh equivalent for Windows)
  Suggested story: Create dikta-windows/RELEASE.md with build, smoke-test, and Inno Setup steps
- [ ] [carried 4x] Eliminate the inline-copy pattern in FormatterTests.swift — either refactor tests to import production types directly or generate the inline via a build script
  Suggested story: Refactor FormatterTests.swift to remove inlined StructuredTextFormatter and MessageFormatter structs, replacing with direct imports of production types
- [ ] Verify `WithNoSpeechThreshold` is the correct Whisper.net 1.9.0 method name — US-010 notes it may be `WithNoSpeechProb` or similar
  Suggested story: On a Windows build machine, compile dikta-windows and confirm TranscriberService builds cleanly with the threshold wiring

### Chronic Tech Debt
- [ ] [carried 12x] Run `swift test` end-to-end to verify unit tests actually execute
  Suggested story: Add a CI step or pre-release checklist item that runs `swift test` and gates the release
  This item should be included as a story in the next sprint, or explicitly dismissed with a reason.
- [ ] [carried 12x] Simplify ConfigService atomic write (remove either `.atomic` flag or `replaceItemAt`)
  Suggested story: Audit ConfigService.swift and pick one atomic write strategy, remove the redundant one
  This item should be included as a story in the next sprint, or explicitly dismissed with a reason.

### Metrics
- Stories completed: 10/10
- Stories blocked: 0
- Stories completed by session agent (worker quota exhausted): 3 (US-007, US-009, US-010) + 1 fix workbook
- Total workbooks: 10
- Sprint wall clock: 1903s (1776416954 → 1776418857), 3 waves
- Wave durations: Wave 1 = 131s, Wave 2 = 1772s, Wave 3 = 0s (same-timestamp)
- Avg story duration: ~211s (small, 9 stories this run, wave-divided) → running avg 279s (small, 22 total); 131s (medium, 1 story this run) → running avg 311s (medium, 11 total)
- Phase overhead: 869s (retro start − last story endTime)
