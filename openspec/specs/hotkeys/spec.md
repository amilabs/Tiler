# hotkeys — current spec (merged from add-tiler-mvp, 2026-07-04)

## Requirements

#### Requirement: Fixed hotkey bindings

Tiler SHALL register the following global hotkeys via Carbon `RegisterEventHotKey`
(no CGEventTap):

| Input | Action |
|---|---|
| Ctrl+Shift+← | left half of the window's current screen |
| Ctrl+Shift+→ | right half of the window's current screen |
| Ctrl+Shift+↑ | maximize on the window's current screen (visible frame) |
| Ctrl+Shift+↑ ×2 (second press ≤ 300 ms after first) | full height, horizontally centered, width = 1/3 of screen |
| Ctrl+Shift+↓ | restore the window's pre-Tiler frame |
| Cmd+Ctrl+Shift+← | left half on the next display |
| Cmd+Ctrl+Shift+→ | right half on the next display |

##### Scenario: Hotkey fires with permission granted
- WHEN Accessibility permission is granted and Ctrl+Shift+← is pressed
- THEN the focused window of the frontmost app moves to the left half of its current screen

#### Requirement: Double-press disambiguation waits

On Ctrl+Shift+↑, Tiler SHALL wait `doublePressWindowMs` (~300 ms) for a possible second
press. A second press within the window SHALL execute center-third (full height, centered,
1/3 width) and no maximize SHALL be executed. If the window expires with no second press,
maximize SHALL execute once. (Owner-approved: latency preferred over transient maximize.)

##### Scenario: Single press
- WHEN Ctrl+Shift+↑ is pressed once
- THEN after ~300 ms the window maximizes exactly once, with no intermediate resize

##### Scenario: Double press
- WHEN Ctrl+Shift+↑ is pressed twice within 300 ms
- THEN the window goes directly to full-height centered 1/3-width, and never to maximize

#### Requirement: Hotkeys never endanger system input

Hotkey handling SHALL use only Carbon hotkey registration, which cannot intercept, delay,
or disable systemwide input if Tiler hangs or crashes.

##### Scenario: Tiler killed while hotkeys registered
- WHEN Tiler is force-killed (kill -9)
- THEN keyboard and trackpad input systemwide continue to work normally

#### Requirement: Registration is independent of Accessibility permission

Hotkeys SHALL be registered at launch regardless of AX permission state. Without
permission, a hotkey press SHALL be a safe no-op (with the warning state visible in the
menu bar) and SHALL NOT crash or unregister the hotkey.
