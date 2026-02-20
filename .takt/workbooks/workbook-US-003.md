# Workbook: US-003 - Mute feedback sounds

## Status: DONE

## Summary
Added a "Mute Sounds" toggle to the Advanced menu that silences dictation feedback beeps (beepOn/beepOff). The setting persists via ConfigService and gracefully defaults to false for old configs.

## Changes Made

### 1. AppConfig.swift
- Added `var muteSounds: Bool` field
- Added `case muteSounds = "mute_sounds"` to `CodingKeys`
- Added `muteSounds: false` to the `default` static property
- Added `muteSounds: Bool = false` parameter to the memberwise `init`
- Added `decodeIfPresent` with `?? false` fallback in `init(from decoder:)` for backward compatibility

### 2. ConfigService.swift
- Added `muteSounds` computed property with getter/setter that calls `objectWillChange.send()` and `save()`

### 3. AudioFeedback.swift
- Added `var isMuted: Bool = false` property
- Added `guard !isMuted else { return }` at the top of both `beepOn()` and `beepOff()`

### 4. MenuBarViewModel.swift
- Added `toggleMuteSounds()` method that toggles `configService.muteSounds` and syncs `audioFeedback.isMuted`
- Added `audioFeedback.isMuted = configService.muteSounds` in `init()` to sync initial state

### 5. MenuBarView.swift (AdvancedMenu)
- Added "Mute Sounds" button at the top of the Advanced menu with checkmark state indicator
- Added Divider after the toggle to separate it from Language/Model/Voice settings

## Acceptance Criteria Verification
1. AppConfig has muteSounds Bool field (default false), persisted as mute_sounds in JSON; old configs without the field decode gracefully to false -- PASS
2. A Mute Sounds toggle in the Advanced menu shows checkmark state and persists the setting via ConfigService -- PASS
3. beepOn() and beepOff() early-return without playing when muteSounds is true -- PASS
4. swift build succeeds -- PASS (BUILD SUCCEEDED)
