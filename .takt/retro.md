# Active Alerts

| Status | Alert | First Seen | Last Seen |
|--------|-------|------------|-----------|
| mitigated | Workers unable to use Bash (background agents denied, foreground requires constant approval) | 2026-02-20 | 2026-03-07 |
| potential | Self-contained test types must be manually synced with production code | 2026-02-26 | 2026-02-26 |
| confirmed | swift test never run end-to-end — unit tests unverified across all runs | 2026-02-26 | 2026-03-14 |
| confirmed | ConfigService has redundant atomic write strategies — never cleaned up across multiple runs | 2026-03-07 | 2026-03-14 |

---

## Retro: 2026-03-14 — takt/sparkle-auto-update

### What Went Well
- **All 5 stories implemented in one sequential pass** with no blocked stories. The dependency chain (US-001 → US-002/US-005 → US-003/US-004) was clean and the Xcode project file edits were straightforward to pattern-match from the WhisperKit setup.
- **SPUUpdaterDelegate wiring caught by scenario verification (SC-011)**: The initial SparkleController lacked delegate conformance — Sparkle would never auto-clear the badge. Verification caught this before merge. Fix required adding NSObject inheritance and wiring 4 delegate methods — structural correctness validated.
- **Appcast history preservation caught by scenario verification (SC-014)**: Initial build-release.sh overwrote appcast.xml entirely. Scenario flagged it; Python-based insert-before-first-item fix was added. Multi-version update chains will now work correctly.
- **Review gate added for EdDSA placeholder**: The placeholder key in Info.plist would silently break all updates if shipped. The build-script abort guard and XML comment make this a hard release gate rather than a footgun.
- **Parallel wave structure worked well**: US-002 and US-005 were independent and committed separately without conflicts.

### What Didn't Go Well
- **Pre-existing uncommitted changes caused stash gymnastics**: AppConfig.swift, ConfigService.swift, DiagnosticLogger.swift, MenuBarViewModel.swift, MenuBarView.swift all had local modifications from v0.6 work that hadn't been committed to main. The orchestrator had to stash/unstash around the US-001 commit to avoid polluting it. These working-tree changes should have been committed to main before the sprint started.
- **Task tool unavailable — all work executed sequentially by orchestrator**: The intended takt parallel mode (worktrees + worker agents) could not run because the Task tool was not available. All stories were implemented inline by the session agent rather than being distributed to worker agents. This is a session environment constraint.
- **EdDSA key generation is a manual one-time step not automated in the script**: The `generate_keys` binary must be located and run manually before the first release. The script handles the guard but cannot self-heal.

### Patterns Observed
- **Third-party SDK integration stories require manual post-setup steps**: Both Sparkle (generate EdDSA key) and Kokoro TTS (Python venv) have manual one-time setup that can't be automated in the build script. These should be documented as release checklists.
- **MenuBarView is a high-overlap hotspot**: US-002, US-003, and US-004 all touched MenuBarView.swift. In a true parallel run, this would require careful merge ordering (US-002 first, then US-003/US-004).
- **Xcode project.pbxproj requires manual edits for SPM additions**: Adding Sparkle required 6 coordinated edits to project.pbxproj. This is fragile and hard to review. A pattern to note for future SPM dependency stories.

### Action Items
- [ ] [carried 4x] Add a note to story templates for Swift/Apple platform work: flag CoreFoundation types as requiring `CFGetTypeID` guards
  Suggested story: Codify a Swift story template section listing known platform gotchas (CFGetTypeID, async actor isolation, Xcode project.pbxproj sync)
- [ ] [carried 5x] Run `swift test` end-to-end to verify unit tests actually execute
  Suggested story: Add a CI step or pre-release checklist item that runs `swift test` and gates the release
- [ ] [carried 5x] Simplify ConfigService atomic write (remove either `.atomic` flag or `replaceItemAt`)
  Suggested story: Audit ConfigService.swift and pick one atomic write strategy, remove the redundant one
- [ ] [carried 2x] Fix xcodebuild test bundle code signing mismatch (`different Team IDs`) so unit tests can actually run
- [ ] [carried 2x] Consider extracting AudioRecorder.swift subsystems (retry logic, converter lifecycle, silence detection) into focused types
- [ ] [carried 1x] Commit or remove DiagnosticLogger before next release — decide if it stays as a permanent debug tool or is stripped
- [ ] [carried 1x] Add `[BLANK_AUDIO]` / bracket noise token fix to CHANGELOG.md under [0.6] entry
- [ ] Commit pre-existing working-tree changes from v0.6 work (AppConfig.swift, ConfigService.swift, DiagnosticLogger.swift) to main before starting next sprint
- [ ] Generate real EdDSA keypair, replace SUPublicEDKey placeholder in Info.plist before v0.7 release build
- [ ] Enable GitHub Pages on repo (Settings → Pages → docs/ folder on main)

### Metrics
- Stories completed: 5/5
- Stories blocked: 0
- Total workbooks: 5
- Avg story duration: large=618s (~10 min), medium=520s (~9 min)
- Phase overhead (verification + review): ~1200s (~20 min)
- Verification cycles: 1 (2 bugs found and fixed — SC-011, SC-014)
- Review cycles: 1 (1 must-fix resolved)
