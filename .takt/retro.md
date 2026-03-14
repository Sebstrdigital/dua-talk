# Active Alerts

| Status | Alert | First Seen | Last Seen |
|--------|-------|------------|-----------|
| mitigated | Workers unable to use Bash (background agents denied, foreground requires constant approval) | 2026-02-20 | 2026-03-07 |
| potential | Self-contained test types must be manually synced with production code | 2026-02-26 | 2026-02-26 |
| confirmed | swift test never run end-to-end — unit tests unverified across all runs | 2026-02-26 | 2026-03-14 |
| confirmed | ConfigService has redundant atomic write strategies — never cleaned up across multiple runs | 2026-03-07 | 2026-03-14 |

---

## Retro: 2026-03-14 — takt/fix-build-signing

### What Went Well
- **All 3 stories implemented in one sequential pass** with no blocked stories. US-001 and US-002 shared the same file and were implemented in a single atomic edit, keeping the diff clean.
- **Signing block replacement was surgical**: The old custom logic (find-loop over Mach-O binaries, custom Downloader.xpc entitlements) was replaced with Sparkle's exact 5 documented commands. No guessing — the exact commands came from Sparkle's official sandboxing documentation.
- **ExportOptions.plist is a clean, maintainable artifact**: Moving export config to a plist rather than inline xcodebuild flags makes the intent explicit and the config easy to review or extend.
- **Review cycle found 0 must-fix issues**: The diff was small and well-scoped. The single suggestion (redundant `mkdir -p`) is harmless and doesn't block release.

### What Didn't Go Well
- **Task tool unavailable — session agent implemented all stories directly**: No worker agents could be spawned. All story work was done inline by the orchestrator. This is a session environment constraint (same pattern as previous run).
- **US-002 and US-001 changes were inseparable in git**: Both stories touched build-release.sh in overlapping regions. They were committed together as a single commit under US-001. US-002 has no separate git footprint.
- **US-003 timing is 0s** — it was a verification story with no code changes needed. The appcast/GitHub Release logic was already correct from the previous sprint. No meaningful duration to record.

### Patterns Observed
- **Build script signing complexity is a recurring pattern**: This is the second sprint that touched Sparkle signing in build-release.sh. The signing logic was brittle and custom — replacing it with vendor-documented commands is the right fix. Future Sparkle updates may require re-checking this.
- **Task tool unavailability remains a persistent environment constraint**: Now seen in 2 consecutive sprints. Sequential execution by the session agent is the de-facto fallback.

### Action Items
- [ ] [carried 5x] Add a note to story templates for Swift/Apple platform work: flag CoreFoundation types as requiring `CFGetTypeID` guards
  Suggested story: Codify a Swift story template section listing known platform gotchas (CFGetTypeID, async actor isolation, Xcode project.pbxproj sync)
- [ ] [carried 6x] Run `swift test` end-to-end to verify unit tests actually execute
  Suggested story: Add a CI step or pre-release checklist item that runs `swift test` and gates the release
- [ ] [carried 6x] Simplify ConfigService atomic write (remove either `.atomic` flag or `replaceItemAt`)
  Suggested story: Audit ConfigService.swift and pick one atomic write strategy, remove the redundant one
- [ ] [carried 3x] Fix xcodebuild test bundle code signing mismatch (`different Team IDs`) so unit tests can actually run
  Suggested story: Investigate and fix the Team ID mismatch that prevents xcodebuild test from running
- [ ] [carried 3x] Consider extracting AudioRecorder.swift subsystems (retry logic, converter lifecycle, silence detection) into focused types
- [ ] [carried 2x] Commit or remove DiagnosticLogger before next release — decide if it stays as a permanent debug tool or is stripped
- [ ] [carried 2x] Add `[BLANK_AUDIO]` / bracket noise token fix to CHANGELOG.md under [0.6] entry
- [ ] [carried 1x] Commit pre-existing working-tree changes from v0.6 work (AppConfig.swift, ConfigService.swift, DiagnosticLogger.swift) to main before starting next sprint
- [ ] Generate real EdDSA keypair, replace SUPublicEDKey placeholder in Info.plist before v0.7 release build
- [ ] Enable GitHub Pages on repo (Settings → Pages → docs/ folder on main)
- [ ] Run a real build with the new signing flow to confirm notarization passes end-to-end

### Metrics
- Stories completed: 3/3
- Stories blocked: 0
- Total workbooks: 3
- Avg story duration: medium=337s (~6 min) [running avg across 5 medium stories]
- Phase overhead (verification + review): ~810s (~14 min) [running avg across 2 runs]
- Verification cycles: 1 (all 7 scenarios passed static verification)
- Review cycles: 1 (0 must-fix, 1 suggestion)
