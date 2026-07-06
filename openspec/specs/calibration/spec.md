# calibration — current spec (merged from add-shell-and-calibration, 2026-07-04)

## Requirements

#### Requirement: Guided per-gesture calibration flow

Settings SHALL offer a calibration dialog covering every supported gesture
(3-finger left / right / up, plus their Cmd variants counted as the same motion).
For each gesture the dialog SHALL show a mini animation demonstrating the motion,
prompt the user to perform it a fixed number of attempts, and animate live feedback:
per-attempt success/failure, running accuracy, and overall progress.

##### Scenario: Right-swipe calibration round
- WHEN the user starts calibration and reaches the "swipe right" step
- THEN an animation demonstrates the motion, each physical attempt is immediately
  marked recognized/unrecognized, and a running accuracy indicator updates

##### Scenario: Audible step cue
- WHEN a calibration step completes and the next gesture prompt appears, and when the
  whole session completes
- THEN Tiler plays a short system sound to signal the transition

#### Requirement: Calibration output is per-user tunables, safely clamped

Completing calibration SHALL produce personal `Tunables` overrides (at minimum the
direction-dominance cones; extensible to displacement/speed), persisted and applied
to the live recognizer without restart. Every calibrated value SHALL be clamped to
safe ranges chosen so that the false-positive blocker classes (scrolls, palm,
2→3→2, momentum — see gestures spec) can never be re-enabled by calibration. The
golden-trace regression suite SHALL pass with any values inside the clamp ranges.

##### Scenario: Calibration fixes an under-detected gesture
- WHEN the user's right swipes are recognized in fewer than half of attempts and the
  user completes calibration
- THEN subsequent right swipes matching their recorded motion register reliably,
  while replaying the golden blocker fixtures against the calibrated tunables still
  yields zero actions

##### Scenario: Reset to defaults
- WHEN the user chooses "Reset to defaults" in calibration/settings
- THEN stock tunables apply immediately and the persisted overrides are removed

#### Requirement: Calibration data capture doubles as diagnostics

Each calibration session SHALL record its raw frames as a standard JSONL trace
(TraceIO format) so failed sessions can be analyzed with TraceCheck and frozen into
golden fixtures.

##### Scenario: Analyzing a poor calibration
- WHEN a calibration step ends with low accuracy
- THEN a trace file of that session exists and `swift run TraceCheck <file>` replays it
