# app-shell — current spec (last merged: unify-about-guide, 2026-07-05)

## Requirements

#### Requirement: Menu-bar-only application

Tiler SHALL run as an `LSUIElement` app with an `NSStatusItem` (no Dock icon, no main
window). The menu SHALL contain exactly TWO items: **Tiler…** (single entry point,
opening the unified About & Guide window) and **Quit**. Settings are reached from
within the unified window (prominent header button + troubleshooting link). The
status item SHALL show a distinct alert appearance (with explanatory tooltip) when
Accessibility is missing OR conflicting system gestures are detected; the conflict
check re-runs at launch and on every menu open.

##### Scenario: Warning state visible
- WHEN AX permission is missing
- THEN the status item shows a distinct alert appearance until the permission is granted

#### Requirement: App icon

Tiler.app SHALL ship an app icon (owner-picked hand.pinch glyph on the violet tile,
generated at build) and a matching template menu-bar icon.

#### Requirement: Unified About & Guide window

One window SHALL serve as About, guide, and entry point, containing: an animated hero
(cycling gesture demo) with the app name and a one-line tagline; a short value section
grounded in the original brief (reliability/no false positives, per-hand calibration,
lightweight resilience); the live permission card; the complete hotkey and gesture
reference (keycaps + looping direction animations, Cmd variants, double-press ↑,
restore); a troubleshooting section (inline conflicts + Calibrate); a prominent
Settings entry; and a footer with version, build timestamp (injected at build,
displayed in the user's LOCAL timezone), and the GitHub link.

##### Scenario: Build time reflects the actual build
- WHEN the app is rebuilt and the unified window is opened
- THEN the displayed build timestamp matches the new build, not a stale constant

##### Scenario: Story and reference in one place
- WHEN the unified window is open
- THEN the user can read what the app is for AND see every binding/gesture without
  opening anything else

#### Requirement: Fits small screens

Auxiliary windows SHALL never exceed the screen's visible height: the unified window's
content scrolls vertically when it does not fit, and window heights are clamped to the
visible frame.

##### Scenario: Small display
- WHEN the unified window opens on a display whose visible height is smaller than the
  full content
- THEN the window is clamped to the screen and the content is reachable by scrolling

#### Requirement: Startup flow

On the very first launch, on any launch without Accessibility, and on any launch with
conflicting system gestures detected, Tiler SHALL open the unified window (permission
card highlighted when relevant), continuing to run normally otherwise. Granting the
permission while the window is open SHALL flip its permission card without relaunch.

#### Requirement: Conflict diagnostics

Diagnostics SHALL report (read-only) system settings that compete with Tiler's gestures:
Three Finger Drag (Accessibility), three-finger Mission Control / App Exposé / Spaces
swipes (Trackpad › More Gestures), reading the relevant `defaults` domains. Tiler SHALL
NOT modify system settings. The README SHALL document these conflicts and that gesture
acceptance is performed with system three-finger gestures disabled.

##### Scenario: Three Finger Drag enabled
- WHEN TrackpadThreeFingerDrag is enabled in system settings
- THEN Diagnostics lists it as a conflict with guidance to disable it for gesture use

#### Requirement: Idle CPU budget

With the trackpad untouched and permission granted, Tiler's process CPU SHALL stay below
1% (no polling timers in steady state; multitouch callback is push-based; hotkeys are
event-driven).

##### Scenario: 60-second idle sample
- WHEN Tiler idles for 60 s with no trackpad contact and permission granted
- THEN sampled CPU (`ps -o %cpu`) stays < 1%

#### Requirement: Crash and kill safety

Tiler SHALL install no mechanism that could persist input interference beyond its
process lifetime. Force-killing Tiler at any moment SHALL leave keyboard, trackpad, and
system gestures fully functional.
