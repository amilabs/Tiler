# Owner's original assignment (2026-07-04, translated)

The owner's working language is Russian; the assignment was originally recorded
here verbatim. Translated to English 2026-08-05 under the public-repo
English-artifacts rule, content preserved faithfully. This file remains the
source of truth behind the spec deltas.

---

Use https://github.com/Fission-AI/openspec; protocol every task and assignment
and update them on any change.

Research the means for self-service debugging, testing, and acceptance; involve
the user as little as possible during development, but never at the expense of
quality.

Product: a macOS menu-bar utility for controlling the active window via fixed
hotkeys and precise trackpad gestures. The app must move and resize the
currently active window, work through the Accessibility permission, and neither
crash nor permanently disable input when the permission is absent. If
Accessibility is not granted, Tiler does not move windows but stays alive,
shows a warning, and recovers without a restart once the permission is granted.

Required actions:

| Input | Action |
|---|---|
| Ctrl + Shift + ← | window to the left half of the current visible screen |
| Ctrl + Shift + → | window to the right half of the current visible screen |
| Ctrl + Shift + ↑ | maximize on the current visible screen |
| double Ctrl + Shift + ↑ | window at full height, centered, 1/3 of the screen width |
| Ctrl + Shift + ↓ | restore the previous size/position |
| Cmd + Ctrl + Shift + ←/→ | the same action, but on the other/next monitor |
| swipe with exactly three fingers left/right/up | left half / right half / maximize |
| Cmd held during a three-finger left/right swipe | the action on the other/next monitor |

This is an approximate description — think it through and propose improvements
where needed, especially on the technical side of the implementation. Research
the best practices that exist today. For example, the BetterTouchTool (BTT)
app documents plenty of problems and solutions in its tickets and forums.

Do not implement the three-finger swipe down. Two- and four-finger gestures
must not trigger actions.

The key requirement is reliable detection of exactly three active touches. A
gesture must not be considered valid merely because the callback reported
fingerCount = 3: inactive/stale contacts must be excluded, including contacts
with size = 0 and completed states. A gesture is accepted only after sustained
movement: at least several stable samples, a short confirmation delay, one
action per physical gesture; repeated callbacks after firing are ignored until
all fingers fully lift off, plus a cooldown.

When idle, with the trackpad untouched, the process CPU must not exceed 1%.

Recognize directions strictly. A horizontal swipe is valid only with clear
X-over-Y dominance: guideline |dx| >= 2.0 * |dy|, i.e. roughly up to 26–27°
deviation from horizontal. An upward vertical swipe is valid with Y-over-X
dominance: guideline |dy| >= 1.6 * |dx|, i.e. roughly up to 32° from vertical.
Diagonal movements — especially near 30° for the horizontal swipe — must be
treated as ambiguous and trigger no action. Gestures that are too short, too
slow, jerky, direction-reversing, or cancelled before confirmation are ignored.

False positives are a blocker. Tiler must not move windows during two-finger
vertical, horizontal, or diagonal scrolling in Safari/Chrome/Firefox, Finder,
TextEdit, and other ordinary apps; during momentum/inertial scroll; when a
third finger is accidentally added during a two-finger scroll; on 2 → 3 → 2,
3 → 2, 3 → 4 transitions; when returning to three fingers without a full
lift-off; on a stale third contact after a finger lifts. There must also be no
repeated action from one and the same gesture.

Possible macOS system conflicts: Mission Control, App Exposé, Spaces,
Trackpad > More Gestures, and Accessibility > Three Finger Drag. Tiler
probably must not use the two-finger scrollWheel/public NSEvent as an action
source in normal mode. Conflicting system settings must be described in the
diagnostics/instructions; clean gesture acceptance is performed with the
conflicting system three-finger gestures disabled.

---

Follow-up owner decisions (same day, in chat): wait ~300 ms to disambiguate double
Ctrl+Shift+↑; target macOS 26 only; OpenSpec maintained manually without Node/CLI;
implementation starts in a new session.
