# Phase 4 — Integration

**Goal:** Wire the formatter engine into Dikta with a hotkey, style picker, and text selection handling.

**Depends on:** Phase 1, 2, and 3 must be working and tested.

**When done:** User can select text in any app, press a hotkey, pick a style, and get formatted text.

---

## Progress

- [ ] TODO 1: Read selected text via pasteboard
- [ ] TODO 2: Register formatting hotkey
- [ ] TODO 3: Build style picker (HUD/keypresses)
- [ ] TODO 4: Edge cases (empty selection, short text, already formatted)
- [ ] TODO 5: Add to Dikta's menu bar
- [ ] TODO 6: Manual testing in Mail, Notes, Slack

---

## TODO 1: Read the selected text

The user selects text in another app (Mail, Slack, Notes, whatever). Dikta needs to grab that text.

### The approach

Dikta already uses the pasteboard for pasting transcriptions. Same technique:

1. Simulate `Cmd+C` to copy the selected text to the system pasteboard
2. Read the pasteboard contents
3. Format it
4. Write the result back to the pasteboard
5. Simulate `Cmd+V` to paste the formatted text back

This replaces the selection with the formatted version. The target app's undo (Cmd+Z) should revert it since it's just a paste operation.

### Things to watch out for

- **Timing:** After simulating Cmd+C, you need a tiny delay before reading the pasteboard (the system needs time to process). Dikta already handles this for transcription paste — reuse that approach.
- **Permissions:** This requires Accessibility permissions (same as the dictation hotkey). Dikta already has this.
- **Pasteboard types:** Read the pasteboard as plain text (`NSPasteboard.PasteboardType.string`). Don't try to preserve rich text formatting — the formatter works on plain text.
- **Empty selection:** If the user hits the hotkey with nothing selected, the pasteboard won't change. Detect this (compare pasteboard contents before and after Cmd+C, or check if pasteboard is empty) and show a brief notification: "No text selected."

---

## TODO 2: Register the formatting hotkey

### Choosing the hotkey

Check what's already taken in Dikta (the dictation hotkey, language hotkey, etc.). The formatting hotkey needs to be:
- Not used by Dikta already
- Not commonly used by other apps
- Easy to remember

Suggestion: **Cmd+Shift+F** (common "format" association). But check collisions first — many apps use Cmd+Shift+F for "Find in project."

Alternative: **Ctrl+Shift+F** or a configurable hotkey.

### Implementation

Use the same hotkey registration system that Dikta uses for the dictation hotkey. Look at how the dictation hotkey is registered and follow the same pattern. The formatter hotkey should:
1. Be registered at app startup
2. Be configurable in settings (nice-to-have, can hardcode for v1)
3. Work globally (when Dikta is in the background)

---

## TODO 3: Build the style picker

When the user presses the formatting hotkey, show a small popup to pick a style.

### UI options (pick one)

**Option A — Floating panel near cursor:**
A small, minimal popup that appears near the mouse cursor. Two buttons: "Message" and "Structure". Click one and it formats.

**Option B — Single-key shortcuts after hotkey:**
After pressing the hotkey, Dikta listens for a second keypress:
- `M` → Message formatter
- `S` → Structure formatter
- `Esc` → Cancel

This is faster for keyboard-heavy users (no mouse needed). Show a brief tooltip: "M: Message | S: Structure"

**Option C — Menu bar submenu:**
Add a "Format" submenu to Dikta's menu bar icon. Less discoverable but simpler to build.

**Recommendation for v1:** Option B (second keypress). It's the fastest UX and simplest to implement — no window/panel UI needed, just keyboard listening.

### Implementation for Option B

1. On formatting hotkey press:
   - Copy selection to pasteboard (Cmd+C)
   - Show a small HUD/tooltip near the menu bar icon: "Format: M=Message  S=Structure"
   - Start listening for next keypress
2. On valid keypress (M or S):
   - Hide the HUD
   - Read pasteboard
   - Format with the chosen style
   - Write to pasteboard
   - Paste (Cmd+V)
3. On Esc or timeout (3 seconds):
   - Hide the HUD
   - Cancel — do nothing
4. On any other keypress:
   - Ignore it (or cancel)

### The HUD/tooltip

Use `NSPanel` or a borderless `NSWindow` with a small label. Make it:
- Semi-transparent dark background
- White text
- No title bar
- Disappears after action or timeout
- Positioned near the menu bar icon or center of screen

Look at how Dikta shows notifications (if it has any) and reuse that pattern.

---

## TODO 4: Handle edge cases

### Nothing selected
If the pasteboard is empty or unchanged after Cmd+C → show "No text selected" notification and cancel.

### Very short text
If the text is 1-2 words → return unchanged and optionally show "Text too short to format."

### Already formatted text
Phase 3 already handles this (returns unchanged if bullets/numbers detected). Phase 2 should also check — if text already has blank lines between paragraphs, don't add more.

### Formatting takes noticeable time
It shouldn't — these are string operations, should be instant. But if somehow it does, consider running the format on a background thread and showing a brief spinner. Probably not needed.

---

## TODO 5: Add to Dikta's menu

Add a "Format Selection" menu item under the Dikta menu bar icon. This serves as:
- Discoverability (users can see the feature exists)
- Shows the hotkey shortcut
- Provides an alternative way to trigger it

```
Dikta Menu:
  ┌─────────────────────────┐
  │ Start Dictation    ⌘⇧D  │
  │ ─────────────────────── │
  │ Format Selection   ⌘⇧F  │
  │   Message          M     │
  │   Structure        S     │
  │ ─────────────────────── │
  │ Language ▸               │
  │ Settings ▸               │
  │ ─────────────────────── │
  │ Quit                     │
  └─────────────────────────┘
```

---

## TODO 6: Test the full flow manually

### Test scenario 1: Email in Mail.app
1. Open Mail, compose new email
2. Dictate a message using Dikta
3. Select the dictated text
4. Press Cmd+Shift+F, then M
5. Verify: greeting separated, paragraphs added, sign-off on its own line

### Test scenario 2: Bullet list in Notes.app
1. Open Notes, create new note
2. Dictate a list of items
3. Select the text
4. Press Cmd+Shift+F, then S
5. Verify: items converted to bullets

### Test scenario 3: Slack message
1. Open Slack, start typing in a channel
2. Dictate a message
3. Select and format as Message
4. Verify: properly structured

### Test scenario 4: Nothing selected
1. In any app, don't select anything
2. Press Cmd+Shift+F
3. Verify: "No text selected" notification, nothing changes

### Test scenario 5: Already formatted
1. Select text that already has bullet points
2. Press Cmd+Shift+F, then S
3. Verify: text unchanged

### Test scenario 6: Undo
1. Dictate and format text
2. Press Cmd+Z
3. Verify: original unformatted text is restored

---

## Done checklist

- [ ] Formatting hotkey is registered and works globally
- [ ] Selection is read via pasteboard (Cmd+C simulation)
- [ ] Style picker appears (HUD or panel) with M/S/Esc options
- [ ] Formatted text is pasted back (Cmd+V simulation)
- [ ] "No text selected" case is handled
- [ ] Menu bar shows "Format Selection" option
- [ ] Full flow works in Mail.app
- [ ] Full flow works in Notes.app
- [ ] Full flow works in Slack
- [ ] Undo (Cmd+Z) works in the target app
- [ ] Already-formatted text is returned unchanged

---

## Future ideas (not for now)

- **Auto mode:** Try both formatters, use whichever produced more changes
- **Custom styles:** Let users define their own formatting rules
- **Markdown toggle:** Output markdown or plain text depending on target app
- **Preview:** Show a preview of the formatted text before applying
- **History:** Keep last 5 formatted texts, allow re-applying different style
