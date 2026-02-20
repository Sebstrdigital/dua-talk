# Workbook: US-004 - Remove activeMode from config and clean up references

## Summary
Removed the `activeMode` field from `AppConfig` and all related computed properties (`activeHotkeyMode`, `activeHotkey`) from `ConfigService`. This eliminates dead code around mode switching, since both toggle and push-to-talk hotkeys are now always active simultaneously (established in US-001).

## Changes Made

### AppConfig.swift
- Removed `var activeMode: HotkeyMode` property from the struct
- Removed `case activeMode = "active_mode"` from `CodingKeys` enum
- Removed `activeMode` parameter from the memberwise initializer
- Bumped default config version from 2 to 3
- Updated `init(from decoder:)` to:
  - Read the saved version and migrate to version 3 via `max(savedVersion, 3)`
  - No longer decode `activeMode` -- since the CodingKey case is removed, Swift's `Codable` silently ignores the unknown `active_mode` key in v2 JSON configs

### ConfigService.swift
- Removed `activeHotkeyMode` computed property (get/set that accessed `config.activeMode`)
- Removed `activeHotkey` computed property (that delegated to `getHotkey(for: activeHotkeyMode)`)
- Kept `getHotkey(for:)` and `setHotkey(_:for:)` -- still used by menu UI for hotkey configuration

### No changes needed
- **HotkeyManager.swift** -- already had the dual-config `updateConfig(toggle:pushToTalk:)` signature from US-001, no `activeMode` references
- **MenuBarViewModel.swift** -- already used `configService.getHotkey(for: .toggle)` instead of `activeHotkey`, no references found
- **MenuBarView.swift** -- no references to removed symbols

## Verification
- `swift build` / `xcodebuild` succeeds with zero errors
- `grep -r "activeMode|activeHotkeyMode|activeHotkey|setHotkeyMode"` returns zero matches across entire codebase
- v2 JSON configs with `active_mode` field will decode without error (unknown keys ignored by Codable)

## Acceptance Criteria Status
1. **activeMode removed from AppConfig; activeHotkeyMode and activeHotkey removed from ConfigService; HotkeyManager.updateConfig() accepts both toggle and PTT configs** -- DONE
2. **AppConfig version bumped to 3; JSON decoding handles version 2 configs without error** -- DONE
3. **No references to activeMode, activeHotkeyMode, activeHotkey, or setHotkeyMode remain** -- DONE (verified via grep)
4. **swift build succeeds** -- DONE
