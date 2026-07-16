# Tasks — fix-touch-stream-resilience

Owner go-ahead 2026-07-16: "да, делай, не жалей отладки - больше наловим" (fix
approved; be generous with diagnostics). No user gates — bugfix change; field
verification happens on the second laptop after the v0.3.1 release.

- [x] 1. Probe MultitouchSupport identity semantics (MTDeviceGetDeviceID presence,
      pointer stability) — design depends on it.
- [x] 2. `StreamHealthPolicy` in TilerCore (TDD): `deviceDrift` set-compare +
      `shouldSelfHeal` gate matrix (silence / HID recency / cooldown / lock).
- [x] 3. TouchStream: optional `MTDeviceGetDeviceID` symbol, `attachedSignature`
      captured at start, `currentSignature()` fresh enumeration, frame-liveness
      clock (`silentSeconds()`), NSLock-guarded (C callback thread).
- [x] 4. AppDelegate guardian: shared `rebuildTouchStream(reason:)` (wake path
      folded in), display-reconfiguration observer (debounced 1.5 s), unlock drift
      check (+2 s), 60 s watchdog (drift → self-heal policy), `screenLockedNow`
      tracking, HID age via CGEventSource; debug-log lines per design.
- [x] 5. `swift build && swift test --skip AXSystemTests` green; power-acceptance +
      run-acceptance green; local smoke of the new log lines.
- [x] 6. Merge spec deltas (app-shell "Gesture stream recovery", power diagnostic
      logging), bump version 0.3.0 → 0.3.1 (AppDelegate + make-app.sh), release
      v0.3.1 (`gh release`), archive this change, update project.md / CLAUDE.md.
