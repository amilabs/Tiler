# add-noarm-diagnostics

## Why

2026-08-01 ~01:00: owner reports poor recognition ("очень плохо ловит даже
боковые, вертикальный почти не ловит"), yet the log shows every ARMED candidate
either fired (16 window moves, all ok=true, 10 of them up→maximize) or rejected
with `raw=2/1` — the pad physically losing fingers at driver level. The failing
attempts that never ARM (third finger absent/hovering from the start, or exact-3
never stable) log NOTHING — the bulk of the perceived misses is diagnostic dark
matter. Calibration is ruled out (override == defaults exactly); stream rebuilds
are ruled out (none during the test window); the size filter is ruled out
(raw counts pre-filter).

## What

Diagnostic-only (no recognition change):

1. **No-arm session lines**: a touch session that saw exactly-3 active fingers at
   least once but never armed emits `noarm frames3=… maxStreak=… minSize=…
   near=… dirty=…` at session end — flicker (streak resets), light touch
   (minSize near the floor), and hovering fingers become visible.
2. **Reject lines gain `near=K`** — contacts the driver reports in near-pad
   states (starting/hovering/breaking/lingering/leaving) at the failure frame: a
   finger 1 mm off the pad shows as `raw=2 near=1`, a fully-gone finger as
   `raw=2 near=0`.
3. Same rate limit (1 line/s of frame time) and nil-channel zero cost.

## Impact

GestureRecognizer only (session counters gated on the diagnostic channel; TDD).
Power spec diagnostic-logging updated. Ships as v0.3.6.
