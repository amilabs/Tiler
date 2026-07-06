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
| Ctrl+A | lock the screen |

Known trade-off, accepted by the owner: Ctrl+A shadows the "beginning-of-line"
shortcut system-wide while Tiler hotkeys are enabled (the Settings toggle releases
it together with the rest).

##### Scenario: Lock screen
- WHEN Ctrl+A is pressed while Tiler hotkeys are enabled
- THEN the session locks via the system lock; unlocking returns with Tiler running
  normally

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

Bindings are in two independently toggleable groups: **window tiling** (all ⌃⇧ / ⌘⌃⇧
arrow bindings) and **utility** (⌃A lock screen). Each Settings toggle
registers/unregisters only its own group's Carbon hotkeys without relaunch and persists
across restarts. Defaults: window tiling **OFF**, utility **ON**.

##### Scenario: Window hotkeys off by default
- WHEN Tiler runs with fresh settings
- THEN ⌃⇧-arrow combos reach other applications normally while ⌃A still locks the screen

##### Scenario: Independent toggles
- WHEN the window group is enabled and the utility group disabled (or vice versa)
- THEN only the enabled group acts; the disabled group's combos behave as if Tiler
  were not running, and toggling either applies without relaunch
