# window-actions — current spec (merged from add-tiler-mvp, 2026-07-04)

## Requirements

#### Requirement: Target window and screen resolution

Actions SHALL apply to the focused window (`AXFocusedWindow`) of the frontmost
application. The "current screen" SHALL be the `NSScreen` with the largest intersection
with the window's frame. Geometry SHALL be computed against the screen's `visibleFrame`
(menu bar and Dock excluded) with correct Cocoa→AX coordinate conversion.

##### Scenario: No focused window
- WHEN an action triggers while the frontmost app has no focused window (or it is not movable)
- THEN Tiler logs and does nothing (no crash, no beep loop)

#### Requirement: Tiling geometries

Left/right half SHALL fill exactly half of the visible frame. Left/right THIRD
(⇧-variants) SHALL fill exactly the leftmost/rightmost third. Maximize SHALL fill the
whole visible frame (not native fullscreen). Center-third SHALL be full visible-frame
height, width = 1/3 of the visible frame, horizontally centered.

##### Scenario: Right third
- WHEN the right-third action targets a window
- THEN its frame equals the rightmost third of the screen's visible frame

##### Scenario: Maximize respects menu bar and Dock
- WHEN a window is maximized
- THEN its frame equals the screen's visibleFrame, not the full display bounds

#### Requirement: Restore returns the pre-Tiler frame

Before Tiler's first action on a window, its frame SHALL be saved per window identity.
Ctrl+Shift+↓ SHALL restore that frame. If the user manually changed the window frame
after a Tiler action, the next Tiler action SHALL re-capture the manual frame as the new
restore point.

##### Scenario: Snap then restore
- WHEN a window at frame F is snapped left-half and then Ctrl+Shift+↓ is pressed
- THEN the window returns to F

##### Scenario: Restore with no history
- WHEN Ctrl+Shift+↓ is pressed on a window Tiler never touched
- THEN nothing happens (safe no-op)

#### Requirement: Next-display actions

Next-display variants SHALL cycle through `NSScreen.screens` (wrapping) and apply the
same fractional geometry on the target screen's visible frame. Cross-display moves SHALL
land the window FULLY on the target display with that display's exact target width and
height, even when the displays differ in size (position-first application plus a
read-back-and-correct pass, defeating source-display size clamping and window-server
reassociation lag). With a single display, next-display variants SHALL act on the
current screen.

##### Scenario: Move from a wide display to a narrower one and back
- WHEN a window on a wide display is sent to the next (narrower) display's left half,
  then sent back
- THEN each result exactly matches the destination display's half — never a width
  carried over from the source display

##### Scenario: Left half on next monitor
- WHEN Cmd+Ctrl+Shift+← fires with two displays and the window on display 1
- THEN the window occupies the left half of display 2's visible frame

#### Requirement: AXEnhancedUserInterface workaround

Before setting a window frame, Tiler SHALL read and clear the application's
`AXEnhancedUserInterface` attribute if set, and restore it afterwards (prevents animated
mis-positioning in Chrome/Electron apps).

#### Requirement: AX errors are soft failures

Every AX call SHALL check `AXError` and degrade to a logged no-op. No AX failure may
crash Tiler or corrupt the restore history.

#### Requirement: Lock-screen command

A lockScreen command SHALL lock the user session using the system lock (private
`SACLockScreenImmediate`, falling back to `CGSession -suspend`); it requires no
Accessibility permission and never crashes on failure.
