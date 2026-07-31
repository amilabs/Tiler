# fix-rebuild-gesture-loss

## Why

Field incident 2026-07-31 ~23:58 local (owner's machine, log-diagnosed): unplugging
the charger fired `didChangeScreenParametersNotification` twice (23:58:35, :41);
the v0.3.1 guardian rebuilt the touch stream unconditionally both times. The
owner's swipes in that window did not fire until 00:00:39 — a rebuild drops any
in-flight stroke, and the stream was demonstrably alive (fire at 23:00, no sleep
since), so both rebuilds were unnecessary. Second gap: unconfirmed swipe attempts
are not logged at all, so a "gesture didn't fire" report cannot be attributed to a
specific gate (too slow / too short / ambiguous angle / finger drop).

## What

1. **Polite display-change rebuilds** (`StreamHealthPolicy.displayChangeRebuild`,
   TDD): skip when a rebuild happened < 10 s ago (coalesce the notification
   bursts) or when a frame arrived within the last ~1 s — frames after the change
   prove the stream survived it, and a rebuild could only eat a live stroke.
   Otherwise rebuild (pad idle ≥ 1 s → nothing in flight). Wake rebuilds stay
   unconditional (nothing is in flight after a real sleep); drift and self-heal
   triggers are unchanged. The skip decision is logged.
2. **Rejected-candidate diagnostics** (recognizer, TDD): when an ARMED 3-finger
   candidate dies without confirming, emit one `reject reason=… `line with the
   failed gate (short / slow / brief / ambiguous / fingers / palm / reversal /
   timeout) and the metrics (peak dx/dy, progress, dt, speed). Only candidates
   with real movement (≥ half the displacement threshold) are logged, at most one
   line per second of frame time — resting fingers stay silent. Zero cost with
   diagnostics off (existing nil-channel contract).

## Impact

- TilerCore: StreamHealthPolicy + GestureRecognizer (pure, TDD both).
- AppDelegate: display-change handler consults the policy and logs the decision.
- Specs: app-shell "Gesture stream recovery" (politeness clause), power
  "Diagnostic logging" (reject lines). Ships in v0.3.4.
