# Change: add-snap-glyphs

## Why
Owner: the cheat sheet's text-only actions ("Left third", "Right half on the next
display") are hard to parse. Add small "where the window lands" diagrams, like the
macOS tiling menu icons but bigger and clearer.

## What Changes
A `SnapGlyph` view (SwiftUI Canvas, static — no idle CPU, renders in screenshots)
draws a screen outline with the target region as a little window (title bar) plus a
directional chevron. It leads every row in BOTH cheat-sheet sections (hotkeys and
gestures). Covers halves, thirds, center-third, maximize, restore, next-display
(two screens) and the ⌃A lock (padlock). Style chosen by the owner: window-pane +
arrow.

| Capability | Delta |
|---|---|
| `app-shell` | MODIFIED — cheat sheet rows carry a placement glyph |
