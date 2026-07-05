# Change: add-thirds-lock-help

## Why

Owner feature batch (2026-07-05): finer tiling granularity from gestures, a quick
screen-lock hotkey, and a clearer menu label.

## What Changes

1. **Shift + 3-finger swipe left/right → thirds.** With ⇧ held at confirmation, the
   window tiles to the left/right THIRD of the screen instead of the half. Combines
   with ⌘ (third on the next display). ⇧ with swipe-up changes nothing.
2. **⌃A → lock screen.** New global hotkey. KNOWN TRADE-OFF (flagged to owner):
   ⌃A is the standard "beginning of line" in terminals/text fields; the global
   hotkey takes priority everywhere while Tiler's hotkeys are enabled.
3. **Menu label:** "Tiler" → "Help" (no ellipsis per the menu convention).

## Capabilities affected

| Capability | Delta |
|---|---|
| `gestures` | MODIFIED — Shift modifier snapshot → third-width actions |
| `hotkeys` | MODIFIED — ⌃A lock-screen binding (+conflict note) |
| `window-actions` | MODIFIED — left/right third geometries; lockScreen command |
| `app-shell` | MODIFIED — menu label; cheat sheet gains the new rows |
