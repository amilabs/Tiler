# fix-touch-stream-resilience

## Why

Field bug (owner's second laptop, diagnosed from `power-debug` logs on 2026-07-16):
gesture recognition silently died and stayed dead for a day. Timeline from the log —
Tiler v0.3.0 ran continuously since 2026-07-14; the wake-path recovery worked after a
real system sleep (2026-07-15 10:10Z `touch stream restarted after wake`, gestures
confirmed firing at 14:11Z); then the MultitouchSupport stream died some time after
14:11Z **without any system sleep ever happening again** (lid stayed open; only
display sleeps and screen locks followed). v0.3.0's only recovery trigger is
`NSWorkspace.didWakeNotification`, so nothing ever rebuilt the stream; gestures were
dead through 2026-07-16 while permissions showed green (they were — Accessibility
affects window moves, not touch input) and toggling them changed nothing. Only an app
relaunch recovers.

The trigger on the second laptop is unconfirmed (owner: probably no external-display
change that afternoon), so the fix must not bet on one cause: it must detect a dead
stream by *evidence* and rebuild, and it must log enough that the next death names
its killer.

## What

1. **Device-drift detection** — the stream remembers the multitouch device IDs it
   attached to (`MTDeviceGetDeviceID`, probe-verified present and stable); a fresh
   enumeration that differs means the old refs are stale → rebuild immediately.
   Checked periodically and shortly after screen unlock.
2. **Display-reconfiguration rebuild** — `didChangeScreenParametersNotification`
   (debounced) rebuilds the stream unconditionally, mirroring the wake path
   (dock/undock re-enumerates HID devices).
3. **Silence self-heal watchdog** — a 60 s tick rebuilds when the stream has been
   frame-silent for ≥ 10 min while system HID activity (cursor/scroll) is recent,
   rate-limited to one self-heal per 10 min so an external-mouse user doesn't churn.
   Decision logic is pure (`StreamHealthPolicy` in TilerCore, TDD).
4. **Diagnostics** (owner: "не жалей отладки — больше наловим") — the debug log
   gains: device IDs at every stream start, every rebuild with reason and device
   delta, drift details (old → new IDs), display-change events with screen count,
   and self-heal decisions with their evidence (silence age, HID age).

## Impact

- `Sources/TilerCore/StreamHealthPolicy.swift` (new, TDD) — drift + self-heal decisions.
- `Sources/TilerSystem/TouchStream.swift` — device-ID capture, frame liveness clock,
  fresh-enumeration API.
- `Sources/Tiler/AppDelegate.swift` — stream guardian (observers + 60 s watchdog),
  generalized rebuild path (wake / display change / drift / self-heal share it).
- Specs: app-shell "Gesture recovery after system wake" → broadened to
  "Gesture stream recovery"; power "Diagnostic logging" gains the stream lines.
- Release as **v0.3.1** (needed on the second laptop; the fix cannot be
  field-verified anywhere else).

## Non-goals

- No UI changes; no changes to recognition logic or tunables.
- Not attempting to prevent the stream from dying (private-framework internals);
  only guaranteed detection + recovery + attribution.
