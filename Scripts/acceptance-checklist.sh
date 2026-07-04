#!/bin/zsh
# USER GATE #4: final manual acceptance checklist (tasks.md 8.3).
# Precondition: Scripts/diagnose.sh reports no conflicts; Tiler.app running & trusted.
cat <<'CHECKLIST'
Tiler — final acceptance checklist (real trackpad)
==================================================
Precondition: Scripts/diagnose.sh → OK; Tiler.app launched; Accessibility granted.

HOTKEYS (focus a normal window, e.g. TextEdit):
 [ ] Ctrl+Shift+←        → left half of current screen
 [ ] Ctrl+Shift+→        → right half
 [ ] Ctrl+Shift+↑ (once) → maximize after ~0.3 s pause, exactly once
 [ ] Ctrl+Shift+↑ ×2 fast→ full height, centered, 1/3 width (NO transient maximize)
 [ ] Ctrl+Shift+↓        → window returns to its pre-Tiler frame
 [ ] Cmd+Ctrl+Shift+←/→  → halves on the other display (or same screen if single)

GESTURES:
 [ ] 3-finger swipe left / right / up → left half / right half / maximize, one action per swipe
 [ ] Cmd held + 3-finger swipe left/right → other display
 [ ] 3-finger swipe down → nothing
 [ ] 2-finger scrolling everywhere (Safari/Chrome/Firefox/Finder/TextEdit,
     vertical/horizontal/diagonal, with momentum) → windows NEVER move
 [ ] Third finger added mid-scroll / 2→3→2 / palm resting → nothing
 [ ] Diagonal ~30° 3-finger swipe → nothing
 [ ] Repeat swipe without lifting fingers → no second action

PERMISSIONS & LIFECYCLE:
 [ ] Quit Tiler while windows tiled → system input fully normal
 [ ] Revoke Accessibility (tccutil reset Accessibility pro.amilabs.tiler) while running
     → Tiler alive, menu shows warning, windows don't move, no crash
 [ ] Re-grant without relaunching → tiling works again within a few seconds

Any false positive (window moves during normal scrolling) = BLOCKER: record a trace
with Scripts/record-golden.sh reproducing it and hand it to Claude.
CHECKLIST
