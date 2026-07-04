# gestures — delta for add-tiler-mvp

## ADDED Requirements

#### Requirement: Gesture source is raw multitouch contact frames

Tiler SHALL consume raw per-contact frames from the multitouch device (private
MultitouchSupport framework) as the only gesture source. Tiler SHALL NOT derive gesture
actions from two-finger `scrollWheel` events or public `NSEvent` gesture events in normal
operation.

##### Scenario: No event-tap or scroll-event dependency
- WHEN Tiler runs in normal mode
- THEN no CGEventTap is installed and no scroll-wheel event monitor feeds the recognizer

#### Requirement: Active contact definition excludes stale and ended contacts

A contact SHALL be counted as active only if its state is `making` or `touching`, its
size is ≥ `minContactSize` (> 0) and ≤ `palmSizeThreshold`, keyed uniquely by
(deviceID, fingerID). Contacts with state `breaking`, `lingering`, `leaving`,
`notTracking`, or size = 0 SHALL never be counted. `fingerCount` reported by the callback
SHALL never be trusted directly.

##### Scenario: Stale third contact after finger lift
- WHEN two fingers scroll and a third contact remains in the frame with size = 0 or state `lingering`
- THEN the recognizer counts 2 active contacts and no gesture is armed

##### Scenario: Palm resting on trackpad
- WHEN two fingers move while a palm-sized contact (size > palmSizeThreshold) is present
- THEN the palm is not counted and no 3-finger gesture is armed

#### Requirement: Arming requires exactly three stable contacts

The recognizer SHALL arm only when exactly 3 active contacts (and no additional non-active
contacts beyond those 3) persist for at least `stableArmFrames` consecutive frames.

##### Scenario: Momentary third finger during two-finger scroll
- WHEN a 2-finger scroll briefly becomes 3 contacts for fewer than `stableArmFrames` frames (2→3→2)
- THEN no gesture is armed and no action fires

##### Scenario: Four fingers
- WHEN 4 active contacts are present at any point before confirmation (3→4)
- THEN the gesture is aborted into lockout and no action fires

##### Scenario: Two-finger gestures never act
- WHEN any 2-finger movement occurs (vertical, horizontal, diagonal, any speed)
- THEN no action fires

#### Requirement: Confirmation requires sustained, unambiguous, monotonic movement

After arming, an action SHALL fire only when all hold: centroid displacement from the
arm baseline ≥ `minDisplacement` on the dominant axis; direction dominance —
horizontal `|dx| ≥ 2.0·|dy|`, vertical-up `|dy| ≥ 1.6·|dx|` with dy pointing up; the
dominance and monotonicity (cumulative backtrack ≤ `reversalTolerance`) hold for
`confirmSamples` consecutive frames; mean speed ≥ `minMeanSpeed`; elapsed time since
arming ≤ `maxGestureDuration`. Movements failing any condition SHALL abort without action.

##### Scenario: Diagonal ~30° movement is ambiguous
- WHEN 3 fingers move at ≈30° from horizontal (|dx| < 2.0·|dy|) and < the vertical dominance bound
- THEN no action fires and the gesture locks out until lift-off

##### Scenario: Slow, short, jerky, or reversed movements
- WHEN a 3-finger movement is shorter than `minDisplacement`, slower than `minMeanSpeed`,
  exceeds `maxGestureDuration`, or reverses direction beyond `reversalTolerance`
- THEN no action fires

##### Scenario: Three-finger swipe down is not implemented
- WHEN 3 fingers swipe down with any parameters
- THEN no action fires (by design; not a failure)

#### Requirement: Direction mapping and Cmd modifier

On confirmation the recognizer SHALL emit exactly one action: left → left half,
right → right half, up → maximize. If Cmd is held at confirmation time for left/right,
the action SHALL target the next display instead. Cmd with up SHALL emit nothing.

##### Scenario: Cmd-held three-finger swipe right
- WHEN a valid 3-finger right swipe confirms while Cmd is physically held
- THEN the right-half action targets the next display

#### Requirement: One action per physical gesture (lockout)

After firing — or after any abort — the recognizer SHALL enter lockout and ignore all
frames until 0 active contacts persist for `liftOffQuietMs`, plus a `cooldownMs`
cooldown. Returning to 3 contacts without full lift-off SHALL NOT re-arm.

##### Scenario: Continued movement after fire
- WHEN a confirmed swipe continues moving or produces further callbacks
- THEN no second action fires

##### Scenario: Re-forming three fingers without lift-off
- WHEN after an abort or fire the contacts go 3→2→3 without reaching zero
- THEN no gesture is armed until full lift-off and cooldown

#### Requirement: Scrolling in applications never triggers actions (blocker class)

Two-finger vertical/horizontal/diagonal scrolling — including momentum/inertial phases —
in Safari, Chrome, Firefox, Finder, TextEdit and other ordinary applications SHALL never
produce a Tiler action. Violations of this requirement are release blockers.

##### Scenario: Momentum scroll continues after lift-off
- WHEN a 2-finger scroll ends and inertial scrolling continues with no contacts on the pad
- THEN no action fires

##### Scenario: Accidental third finger during scroll
- WHEN during a 2-finger scroll a third finger touches down and lifts (2→3→2) while scroll continues
- THEN no action fires
