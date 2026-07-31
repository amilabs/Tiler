# power — delta for fix-rebuild-gesture-loss

## MODIFIED Requirements

#### Requirement: Diagnostic logging

(Addition only.) The log SHALL also record every REJECTED armed 3-finger candidate
with the failed gate and metrics (`reject reason=short|slow|brief|ambiguous|
fingers|palm|reversal|timeout`, peak dx/dy, progress, dt, speed) — so a "gesture
didn't fire" report is attributable, not just confirmed fires. Intent filter: only
candidates that moved ≥ half the displacement threshold log (resting fingers stay
silent); rate limit: at most one reject line per second of frame time; zero cost
while diagnostics are off (nil channel).

##### Scenario: A too-slow swipe is attributable
- WHEN debug logging is on and a 3-finger stroke moves far enough but too slowly
  to confirm
- THEN the log contains one `reject reason=slow` line with the stroke's metrics
