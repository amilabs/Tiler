# power — delta for fix-touch-stream-resilience

## MODIFIED Requirements

#### Requirement: Diagnostic logging

(Addition to the existing requirement — new logged events only.) The debug log
SHALL also record the touch-stream lifecycle so a dead-gestures report is
attributable from the log alone: device IDs at every successful stream start; every
rebuild with its trigger reason and resulting device signature (and failures with
the error); device drift with the old and new ID sets; debounced display-
reconfiguration events with the screen count; and every silence self-heal decision
with its evidence (silence age, HID age). Healthy watchdog ticks SHALL log nothing
(no spam). Rebuild/failure lines are mirrored to NSLog (they matter even with debug
logging off).

##### Scenario: Dead stream is attributable post-hoc
- WHEN gestures stop being recognized on a machine with debug logging on
- THEN the log names the recovery trigger that fired (or shows the last stream
  start and the absence of frames) without needing a reproduction
