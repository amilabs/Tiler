# app-shell — delta for fix-rebuild-gesture-loss

## MODIFIED Requirements

#### Requirement: Gesture stream recovery

(Only the display-reconfiguration trigger changes; the rest is unchanged.) The
display-change rebuild becomes POLITE: it is skipped when a rebuild ran < 10 s ago
(notification bursts produce at most one rebuild) or when a frame arrived within
the last ~1 s — frames after the change prove the stream survived it, and a rebuild
would only risk dropping an in-flight stroke (2026-07-31 charger-unplug incident).
Skips are logged with the evidence. Wake rebuilds stay unconditional; drift and
self-heal triggers are unchanged.

##### Scenario: Charger unplug during active use
- WHEN display parameters change while the stream is delivering frames (e.g. a
  power-source switch adjusts the display)
- THEN no rebuild occurs, in-flight gestures are not interrupted, and the log
  records the skip
