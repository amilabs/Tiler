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
displayed in the user's LOCAL timezone), the honest verified-configuration note
("verified on macOS 26.5 only" until another configuration passes acceptance),
and the GitHub link.

##### Scenario: Build time reflects the actual build
- WHEN the app is rebuilt and the unified window is opened
- THEN the displayed build timestamp matches the new build, not a stale constant

##### Scenario: Story and reference in one place
- WHEN the unified window is open
- THEN the user can read what the app is for AND see every binding/gesture without
  opening anything else

#### Requirement: Fits without vertical scrolling

The unified window SHALL fit ordinary displays with NO vertical scrolling: a
two-column layout (story/troubleshooting left, full hotkey/gesture reference right;
header, permission card and footer spanning both) within ≈880×780 pt. Auxiliary
window heights remain clamped to the screen's visible frame as a safety net.

##### Scenario: Everything visible at once
- WHEN the unified window opens on a display with ≥800 pt of visible height
- THEN all sections are visible simultaneously without scrolling

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

With the trackpad untouched, Tiler's process CPU SHALL stay below 1% in EVERY
no-finger state: freshly launched with no UI, with the unified window open (demo
animations are static poses; they animate only under the pointer or during an active
calibration; occluded windows pause everything), and after UI windows are closed
(closed windows are fully released — retained off-screen animations are the
regression this guards against). CPU SHALL be measured as true utilization
(cputime delta over a wall interval) — `ps %cpu` is a lifetime average on macOS and
lies in both directions.

##### Scenario: Idle after launch
- WHEN Tiler idles with no trackpad contact and no windows
- THEN true utilization stays < 1%

##### Scenario: Idle with the unified window open
- WHEN the unified window is open and focused but the trackpad is untouched
- THEN true utilization stays < 1%

##### Scenario: Idle after the UI was used
- WHEN the unified window was opened and then closed
- THEN true utilization returns below 1% (measured 2026-07-05: 0.13% / 0.50% /
  0.20% for the three states; pre-fix regression burned 15–21%)

#### Requirement: Crash and kill safety

Tiler SHALL install no mechanism that could persist input interference beyond its
process lifetime. Force-killing Tiler at any moment SHALL leave keyboard, trackpad, and
system gestures fully functional.
