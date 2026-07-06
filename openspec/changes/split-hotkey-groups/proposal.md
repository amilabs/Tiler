# Change: split-hotkey-groups

## Why
Owner batch (2026-07-05): window-tiling hotkeys and utility hotkeys (⌃A lock) need
independent toggles — the owner drives windows by gestures and wants the arrow
hotkeys OFF by default; and calibration should give an audible cue on step change.

## What Changes
1. Two hotkey groups with separate persisted toggles: **window tiling** (all
   ⌃⇧/⌘⌃⇧ arrows, default OFF) and **utility** (⌃A lock screen, default ON).
   The legacy single `hotkeysEnabled` key is dropped (no migration; owner-approved).
2. Settings → General gains the two toggles; the Help cheat sheet notes the
   window-hotkeys default.
3. Calibration plays a system sound when advancing to the next gesture step and on
   completion.

| Capability | Delta |
|---|---|
| `hotkeys` | MODIFIED — groups + defaults |
| `settings` | MODIFIED — two toggles replace one |
| `calibration` | MODIFIED — audible step cue |
