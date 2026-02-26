# Dikta TODO

## Bugs & Polish

- [ ] About window title says "Welcome to Dikta" even when reopened — should say "About Dikta" when not first launch
- [ ] Hotkey collision: users can set the same hotkey for two modes with no warning
- [ ] "Processing..." state has no timeout or cancel — menu bar can appear frozen
- [ ] Audio buffer has no size limit — long recordings could eat RAM
- [ ] Config write is not atomic — crash mid-save corrupts config.json

## UX Improvements

- [ ] "No Speech" notification should hint at mic distance ("Try adjusting Mic Distance in Audio settings")
- [ ] Add Input Monitoring permission check to About window (hotkeys silently fail without it)
- [ ] Processing cancel: let user press hotkey again during processing to abort
- [ ] Model loading progress — show intermediate % instead of jumping 0 to 100

## Features

- [ ] Auto-start on login (launch at login toggle in menu)
- [ ] Export history to file (markdown or plain text)
- [ ] Customizable history length (currently hardcoded to 5)
- [ ] Menu bar icon should indicate active language (e.g., "EN" / "SV" / "ID" badge)

## Code Quality

- [ ] OutputMode and CustomPrompt — verify if still used, remove if dead code
- [ ] Add doc comments to MicDistance threshold values explaining the empirical reasoning
- [ ] Unit tests for hotkey matching, config migration, version comparison
