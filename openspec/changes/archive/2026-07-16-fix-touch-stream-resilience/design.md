# Design — fix-touch-stream-resilience

## Evidence (field log, second laptop, exported 2026-07-16)

| When (UTC) | Event |
|---|---|
| 07-14 15:53 | launch v0.3.0 (last launch in the log — app ran continuously after) |
| 07-14 17:03 | system willSleep (lid closed) |
| 07-15 10:10 | system didWake → `touch stream restarted after wake` — wake path OK |
| 07-15 14:11 | last `gesture fire` ever (stream alive 4 h after the wake rebuild) |
| 07-15 14:49 → 07-16 16:49 | only `screens didWake` / lock/unlock cycles; **zero** system sleeps, zero gesture fires |
| 07-16 16:48 | owner opens Settings (setFloor lines), gestures dead, permissions green |

Conclusions: (a) the stream can die without a system sleep; (b) the only v0.3.0
trigger (didWake) then never fires; (c) permission toggling is irrelevant —
`route()` never logged `gesture ignored`, so no actions reached it: the input side
was dead, not the policy side. The specific killer on the 15th is unidentified
(no display change confirmed by the owner) → the fix detects death by evidence
rather than subscribing to one cause.

## Probe findings (this machine, macOS 26.5, 2026-07-16)

`scratchpad/mt-probe.swift`: `MTDeviceGetDeviceID` symbol is PRESENT in
MultitouchSupport; device IDs are stable across `MTDeviceCreateList` calls
(504403158265495719 for the built-in trackpad); the returned MTDeviceRef pointers
are also cache-stable in-process while the HID generation is unchanged. Identity
therefore uses real device IDs, not pointer bits. If the symbol ever disappears
(future macOS), the device signature degrades to the device *count* — drift then
catches attach/detach but not same-count re-enumeration; all other triggers remain.

## Mechanism

### TouchStream additions (TilerSystem)

- `getDeviceID: GetDeviceIDFn?` — optional dlsym alongside the existing four; absence
  is not an error.
- `attachedSignature: [UInt64]` — captured in `start()`: sorted device IDs (or
  `[count]` in fallback mode). Exposed for the guardian.
- `currentSignature() -> [UInt64]?` — fresh `MTDeviceCreateList` enumeration, same
  encoding; `nil` when the list cannot be built (treated as "no information", never
  as drift).
- Frame liveness: the C contact callback stamps `lastFrameTime` (CFAbsoluteTime,
  NSLock-guarded — the callback runs on a MultitouchSupport thread).
  `silentSeconds()` reports time since the later of (last frame, last start()), so a
  freshly rebuilt stream is never instantly "silent for 10 min".

### StreamHealthPolicy (TilerCore, pure, TDD)

```
deviceDrift(attached:current:) -> Bool     // order-insensitive; current==nil → false
shouldSelfHeal(silentFor:hidAgo:sinceLastRebuild:screenLocked:) -> Bool
```

Self-heal fires only when ALL hold: not locked; silent ≥ 600 s; HID (cursor/scroll)
seen ≤ 60 s ago (`hidAgo != nil`); last rebuild ≥ 600 s ago. Rationale: recent HID
with a long-silent stream means the user is at the machine moving the pointer while
we hear nothing. An external-mouse-only user can legitimately look like that — the
600 s cooldown caps the cost at one stop/start per 10 min, and a stop/start of an
already-healthy stream is idempotent (same devices re-attach).

Thresholds are function defaults so tests pin them explicitly.

### Guardian (AppDelegate)

One shared `rebuildTouchStream(reason:)` — stop, start, `plog` the reason and the
device signature; on throw, fall back to `startTouchPipeline()` (the 5.8 fallback).
Triggers:

| Trigger | Action |
|---|---|
| system didWake + 1.5 s (existing) | unconditional rebuild ("wake") |
| `didChangeScreenParametersNotification`, debounced 1.5 s | unconditional rebuild ("display change", logs screen count) |
| screen unlock + 2 s | drift check → rebuild only on drift |
| 60 s watchdog tick | drift check; else self-heal policy |

The watchdog also needs `screenLockedNow` (tracked from the same distributed
lock/unlock notifications already observed for logging) and HID age from
`CGEventSource.secondsSinceLastEventType(.combinedSessionState, ...)` — min of
`.mouseMoved` and `.scrollWheel`.

All triggers no-op when `touchStream == nil` (no trackpad at launch — unchanged
v0.3.0 behavior).

### Mid-stroke rebuild safety (false-positive rule)

A rebuild while fingers are mid-stroke hands the recognizer a truncated tail of the
gesture. The recognizer needs sustained progress from *its own* first frame, so a
tail is strictly less likely to confirm than the full stroke — the change cannot
create a new false-positive class. Self-heal additionally requires ≥ 10 min of
frame silence, so a live gesture (frames flowing) can never be interrupted by it;
wake/display-change rebuilds happen when no gesture is plausibly in flight.

## Diagnostics (debug log)

- `touch stream started devices=[id,…]` — at every successful `start()`.
- `touch stream rebuilt (<reason>) devices=[…]` / `touch stream rebuild failed
  (<reason>): <error>, rebuilding pipeline`.
- `touch stream drift: [old] -> [new]` — before a drift rebuild.
- `display change screens=N` — every debounced reconfiguration event.
- `touch self-heal: silent=<s>s hid=<s>s` — before a self-heal rebuild.
  (Healthy watchdog ticks log nothing — no spam.)

NSLog mirrors the rebuilt/failed lines (they matter without debug logging too).

## Verification

- TDD: `StreamHealthPolicyTests` (drift set-compare incl. nil/empty/reorder;
  self-heal gate matrix incl. cooldown and lock).
- Full `swift build && swift test --skip AXSystemTests` + power-acceptance +
  run-acceptance on the signed .app.
- Local smoke: dev build with debug logging on — `touch stream started devices=[…]`
  line appears; 60 s watchdog stays silent on a healthy stream; a forced rebuild via
  the existing wake path shape is covered by unit-level review (the rebuild function
  is shared).
- Field verification (the actual bug) only possible on the second laptop →
  release v0.3.1, owner updates that machine; the new diagnostics attribute any
  recurrence.
