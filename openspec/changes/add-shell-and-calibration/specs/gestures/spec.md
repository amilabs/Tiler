# gestures — delta for add-shell-and-calibration

## MODIFIED Requirements

#### Requirement: Confirmation requires sustained, unambiguous, monotonic movement (modified)

Unchanged in substance, with one addition: the recognizer SHALL use the effective
`Tunables` = stock defaults overridden by persisted per-user calibration values
(clamped to safe ranges per the calibration spec). Changing effective tunables SHALL
apply to the live recognizer without restart and never mid-gesture (applied at the
next clean idle state).

##### Scenario: Calibrated tunables apply live
- WHEN calibration saves new dominance values while Tiler runs
- THEN the very next gesture is evaluated with the new values, and any gesture already
  in progress is evaluated entirely with the old ones
