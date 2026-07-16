# app-shell — delta for fix-touch-stream-resilience

## MODIFIED Requirements

#### Requirement: Gesture stream recovery

(Replaces "Gesture recovery after system wake".) The MultitouchSupport contact
stream can go stale without the app crashing — its device refs die across a real
system sleep (observed at gate 4.2 of add-power-control) and can also die with no
system sleep at all (observed in the field 2026-07-15: stream dead after a display
sleep / lock cycle afternoon, no `didWake` ever fired again, gestures stayed dead
until relaunch). Tiler SHALL therefore rebuild the stream (stop + start → fresh
device list; on failure, full pipeline rebuild) on EVERY one of these triggers:

1. ~1.5 s after `NSWorkspace.didWakeNotification` (system wake — existing behavior);
2. after a debounced display reconfiguration
   (`didChangeScreenParametersNotification`) — dock/undock re-enumerates HID devices;
3. on device drift — the set of multitouch device IDs from a fresh enumeration
   differs from the IDs the stream attached to — checked shortly after screen unlock
   and by a periodic (~60 s) watchdog;
4. as a silence self-heal: the watchdog detects the stream frame-silent for ≥ 10 min
   while system pointer/scroll HID activity is ≤ 60 s old and the screen is unlocked,
   rate-limited to at most one self-heal per 10 min.

Rebuilds SHALL be no-ops when no stream exists (no trackpad). A rebuild MUST NOT
introduce gesture false positives: self-heal only fires on a ≥ 10 min-silent stream
(no gesture can be in flight), and a truncated stroke tail after any rebuild is
strictly less likely to confirm than the full stroke.

##### Scenario: Stream dies without a system sleep
- WHEN the contact stream stops delivering frames while the user keeps using the
  machine (no system sleep occurs)
- THEN within ~10 min a watchdog rebuild restores gesture recognition without a
  relaunch

##### Scenario: Display topology change
- WHEN an external display is connected or disconnected
- THEN the stream is rebuilt within a few seconds and gestures keep working

##### Scenario: Healthy stream stays untouched
- WHEN frames are flowing normally
- THEN the watchdog performs no rebuilds (and logs nothing)

##### Scenario: System wake (regression guard)
- WHEN the Mac wakes from a real system sleep
- THEN gestures work within a few seconds without a relaunch (v0.3.0 behavior kept)
