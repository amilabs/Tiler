# Change: add-tiler-mvp

## Why

The owner needs a lightweight, reliable window tiler driven by fixed hotkeys and *precise*
3-finger trackpad gestures. Existing tools (BetterTouchTool et al.) show recurring
community-reported failure modes: stale trackpad contacts inflating finger count, false
triggers during 2-finger scrolling, repeat-fire from one physical gesture, and conflicts
with system three-finger gestures. Tiler's differentiator is a strict, testable gesture
state machine where false positives are treated as release blockers.

## What Changes

New app (from scratch):

- Menu-bar-only app `Tiler.app` (LSUIElement), Swift 6.3 / AppKit / SwiftPM, macOS 26+.
- Global hotkeys via Carbon `RegisterEventHotKey` (no event taps): halves, maximize,
  double-press center-third, restore, next-display variants.
- 3-finger swipe gestures via private `MultitouchSupport.framework` raw contact frames,
  filtered through a deterministic gesture FSM (exact-3 detection, direction dominance,
  confirmation window, one-action-per-gesture lockout).
- Window manipulation via the AX API with known workarounds (AXEnhancedUserInterface reset,
  size→position→size across displays).
- Accessibility-permission lifecycle: alive without permission, menu-bar warning,
  auto-recovery after grant without restart.
- Conflict diagnostics for system gestures (Mission Control, App Exposé, Three Finger Drag).
- Self-testing harness: unit-tested FSM on synthetic + recorded (golden) touch traces,
  AX read-back integration tests, CGEvent-driven hotkey e2e, idle-CPU sampling.

## Capabilities affected

| Capability | Delta |
|---|---|
| `gestures` | ADDED — 3-finger swipe recognition requirements (core reliability spec) |
| `hotkeys` | ADDED — fixed bindings, double-press semantics |
| `window-actions` | ADDED — halves/maximize/center-third/restore/next-display via AX |
| `permissions` | ADDED — AX lifecycle & resilience |
| `app-shell` | ADDED — menu bar, diagnostics, launch-at-login, idle CPU budget |

## Non-goals (out of scope for this change)

- Configurable/custom shortcuts or gesture mapping UI.
- 3-finger swipe **down** (explicitly not implemented).
- Any action on 2- or 4-finger gestures.
- App Store distribution, sandboxing, notarization pipeline.
- Window animations, snap-drag zones, layouts beyond the listed actions.

## Impact

- New SwiftPM package, `Sources/` + `Tests/`, `Scripts/` for bundling/acceptance.
- Requires: Accessibility permission (runtime), disabled sandbox, codesign with the
  stable local identity so TCC grants persist.
- Risk: private MultitouchSupport API may change between macOS versions — probed early
  (task 1.4) and isolated behind `TouchStream` so the blast radius is one module.
