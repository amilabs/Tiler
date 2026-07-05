# Change: add-shift-up-third

## Why
Owner follow-up to add-thirds-lock-help: ⇧ + swipe-up was left as plain maximize;
it should mirror the double Ctrl+Shift+↑ hotkey — full height, centered, ⅓ width.

## What Changes
⇧ held during a confirmed up-swipe emits a third-width up action routed to
center-third. ⌘+up (with or without ⇧) still emits nothing.

| Capability | Delta |
|---|---|
| `gestures` | MODIFIED — ⇧+up → center-third |
| `app-shell` | cheat sheet row |
