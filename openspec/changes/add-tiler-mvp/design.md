# Design — add-tiler-mvp

Approved by owner on 2026-07-04 (chat). Key owner decisions:
- Double-press Ctrl+Shift+↑ disambiguation: **wait ~300 ms** before executing single-press
  maximize (no flicker; accepted latency).
- Deployment target: **macOS 26 only**.
- OpenSpec maintained manually (no Node/CLI).

## 1. Architecture

Four modules over thin system wrappers. Only `TouchStream` and `WindowActions` touch
system APIs; everything decision-making is pure and unit-testable.

```
MultitouchSupport (private)          Carbon RegisterEventHotKey
        │ raw contact frames                 │ hotkey events
        ▼                                    ▼
  TouchStream ──TouchFrame──▶ GestureRecognizer(FSM) ──GestureAction──┐
                                                                      ▼
                                    HotkeyController ──HotkeyAction──▶ ActionRouter
                                                                      │
                                                     WindowActions (AX) ◀ PermissionMonitor
                                                                      │
                                                              AppShell (menu bar, diagnostics)
```

- **TouchStream** — own ~200-line wrapper over `MTDeviceCreateList` /
  `MTRegisterContactFrameCallback` (pattern proven by Karabiner-Elements multitouch
  extension, MiddleDrag, OpenMultitouchSupport; we do NOT take a dependency).
  Normalizes raw contacts into `TouchFrame { timestampMs, contacts: [Contact(deviceID,
  fingerID, state, size, x, y, velX, velY)] }`. Handles device attach/detach (built-in +
  Magic Trackpad). No permission required for MT data (verified empirically in task 1.4).
  **Probe findings (2026-07-04, macOS 26.5.1):** the framework binary lives in the dyld
  shared cache, so it is loaded via `dlopen`/`dlsym` (no link-time `-framework`);
  `MTDeviceCreateList` found 1 device (family 0x6e, 26×18 grid = built-in trackpad);
  `MTRegisterContactFrameCallback` + `MTDeviceStart` succeed from a plain CLI process
  with **no TCC prompt and no crash**. Live frame delivery is confirmed at gate 3.1.
- **GestureRecognizer** — pure deterministic FSM, no system imports. Input: `TouchFrame`
  sequence + modifier snapshot; output: `GestureAction` events. All thresholds in
  `Tunables.swift`. This is the module where every reliability requirement is enforced
  and unit-tested (synthetic + golden traces).
- **HotkeyController** — Carbon hotkey registration + double-press disambiguation timer.
- **WindowActions** — AX layer: resolve target window (focused window of frontmost app),
  compute target frame from the window's current screen `visibleFrame`, apply with
  Rectangle-proven workarounds. Per-window original-frame store for Restore.
- **PermissionMonitor** — `AXIsProcessTrusted` state; poll (2 s) only while missing;
  publishes state to AppShell and WindowActions.
- **AppShell** — NSStatusItem menu, conflict diagnostics, SMAppService launch-at-login.

## 2. Gesture FSM

States: `idle → tracking → candidate → confirmed(fired) → lockout → idle`.

- **Active contact** := state ∈ {making, touching} AND size ≥ `minContactSize` AND
  size ≤ `palmSizeThreshold`, keyed by (deviceID, fingerID). States breaking / lingering /
  leaving / notTracking and size = 0 contacts are *never* counted (kills stale-contact
  false threes).
- **Session rule (2026-07-04, found during TDD):** a touch session runs from the first
  contact after zero to full lift-off. Arming additionally requires a *clean* session:
  all 3 fingers assembled within `touchdownAssemblyWindow` of the session's first touch,
  and no session poisoning (count > 3 at any point, any count decrease while contacts
  remain, palm-class contact). This is what actually blocks "third finger added
  mid-scroll" — stable-frame counting alone would not.
- `idle → tracking`: exactly 3 active contacts and zero palm-class contacts on the
  device in a clean session, sustained for `stableArmFrames` consecutive frames;
  ended/zero-size artifacts are ignored entirely (neither counted nor blocking).
  Baseline centroid captured at arm time.
- `tracking → candidate`: centroid displacement ≥ `minDisplacement` on the dominant axis.
- `candidate → confirmed`: for `confirmSamples` consecutive frames the direction test
  holds and displacement is monotonic (cumulative backtrack ≤ `reversalTolerance`):
  - horizontal: `|dx| ≥ 2.0·|dy|` (≈ ≤26.6° off horizontal)
  - vertical-up: `|dy| ≥ 1.6·|dx|` (≈ ≤32° off vertical), dy must point up
  - anything else (incl. ~30° diagonals) = ambiguous → **abort**
  - mean speed ≥ `minMeanSpeed`; elapsed ≤ `maxGestureDuration`
- On confirm: read Cmd modifier state → emit exactly one `GestureAction`
  (left/right/up × normal/next-display; swipe-down and Cmd+up emit nothing) → `lockout`.
- **Any** deviation before confirm (count ≠ 3 incl. 2→3→2, 3→4; timeout; reversal;
  ambiguity; touch cancel) → `lockout` (require clean lift-off; returning to 3 fingers
  without full lift-off must NOT re-arm).
- `lockout → idle`: 0 active contacts for `liftOffQuietMs`, then `cooldownMs` elapsed.
  Guarantees one action per physical gesture regardless of callback storms.

### Tunables (initial values; single source `Tunables.swift`, refined vs golden traces)

| name | initial | meaning |
|---|---|---|
| minContactSize | 0.05 | below → contact ignored (incl. size=0 stale) |
| palmSizeThreshold | 2.0 | above → palm, ignored |
| stableArmFrames | 4 | consecutive exact-3 frames to arm (~33 ms @120 Hz) |
| touchdownAssemblyWindow | 60 ms | all 3 fingers must land within this window of first touch |
| minDisplacement | 0.10 | normalized units, dominant axis, from arm baseline |
| horizontalDominance | 2.0 | |dx| ≥ k·|dy| |
| verticalDominance | 1.6 | |dy| ≥ k·|dx| |
| confirmSamples | 3 | consecutive consistent samples to fire |
| minMeanSpeed | 0.5 /s | normalized displacement / elapsed |
| maxGestureDuration | 600 ms | arm→confirm budget |
| reversalTolerance | 0.08 | max cumulative backtrack fraction |
| liftOffQuietMs | 80 ms | zero-contact quiet time ending a gesture |
| cooldownMs | 250 ms | after lift-off before re-arm |
| doublePressWindowMs | 300 ms | hotkey ↑ disambiguation |
| permissionPollSec | 2 s | only while AX missing |

## 3. Hotkeys

Carbon `RegisterEventHotKey` — chosen over CGEventTap deliberately: needs no TCC
permission, is event-driven (no idle cost), and cannot stall or disable system input if
Tiler hangs/crashes (a disabled/timed-out event tap is exactly the "input dies" failure
mode the requirements forbid). Bindings are fixed constants. Ctrl+Shift+↑ runs through a
300 ms disambiguation timer (owner-approved latency): second press within the window →
center-third; otherwise maximize.

## 4. Window actions (AX)

- Target window: `AXFocusedWindow` of the frontmost app; no window → soft no-op + log.
- Current screen: `NSScreen` with max intersection area with the window frame.
- Geometry targets are computed from `visibleFrame` (menu bar/Dock respected), converted
  Cocoa (bottom-left) → AX (top-left) coordinates.
- Workarounds (from Rectangle):
  - read & clear `AXEnhancedUserInterface` on the app element before setting frame,
    restore afterwards (fixes Chrome/Electron animated mis-placement);
  - cross-display moves apply **size → position → size** (macOS clamps size to the
    source display otherwise).
- Restore: before Tiler's *first* action on a window, its frame is saved (keyed by
  window identity); Ctrl+Shift+↓ restores it. If the window's current frame differs from
  the last Tiler-set frame (user moved it manually), the saved original is refreshed on
  the next action.
- Next-display: cycle `NSScreen.screens` by index; same fraction applied to target
  screen's `visibleFrame`.
- Every AX call checks `AXError`; failures log and no-op. No force-unwraps in this module.

## 5. Permission lifecycle & resilience

- Startup: `AXIsProcessTrustedWithOptions(prompt: true)` once.
- Not granted: hotkeys and gestures stay registered; actions no-op; status item shows
  warning state; 2 s poll of `AXIsProcessTrusted()`.
- Granted (no restart): poll notices, warning clears, actions start working. AX API needs
  no re-init; nothing to rebuild.
- MT stream and hotkey registration are independent of AX permission by construction.

## 6. Performance

Idle CPU < 1% (hard requirement): MT callback is push-based (no frames when trackpad
untouched), Carbon hotkeys are event-driven, no timers in steady state (the only timers —
double-press disambiguation, permission poll while missing, lockout cooldown — are short
lived or absent when healthy+idle). Frame processing is O(contacts) with early exit in
`idle` for counts ≠ 3.

## 7. System-gesture conflicts (diagnostics)

Read-only checks surfaced in the menu ("Diagnostics") and in README:
- `defaults read com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag` (AX Three
  Finger Drag)
- `TrackpadThreeFingerHorizSwipeGesture`, `TrackpadThreeFingerVertSwipeGesture`
  (Mission Control / App Exposé / Spaces three-finger swipes)
Tiler never changes system settings; it warns that system three-finger gestures will
consume/compete with swipes. Gesture acceptance testing is performed with the conflicting
system three-finger gestures disabled (owner instruction).

## 8. Testing strategy (self-service first)

1. **Unit (CI-grade, no permissions):** GestureRecognizer on synthetic `TouchFrame`
   traces; every blocker scenario from the gestures spec is a named test. Property-style
   fuzz: random 2/4-finger noise must never emit actions.
2. **Golden traces:** debug flag `--record-touches <file>` dumps raw frames to JSON.
   One owner session (scrolls in Safari/Chrome/Finder, momentum, 2→3→2, diagonals, valid
   swipes) [USER GATE]; fixtures replayed in `swift test` forever after.
3. **Integration (AX):** move a real window (spawned helper/TextEdit) via WindowActions,
   read frame back, assert geometry incl. cross-display. Needs one-time AX grant to the
   test host [USER GATE].
4. **E2E hotkeys:** post synthetic key events via `CGEventPost` (same AX grant) and
   assert resulting frames, incl. double-press timing windows.
5. **Performance/resilience acceptance:** `ps` CPU sampling 60 s idle; `tccutil reset
   Accessibility <bundle-id>` for negative tests (self-service); re-grant recovery
   [USER GATE]; kill -9 → relaunch → input untouched.
6. **Final manual acceptance:** owner runs real-trackpad checklist (system 3-finger
   gestures off) [USER GATE].

## 9. Risks

| Risk | Mitigation |
|---|---|
| Private MT API breaks / needs permission on macOS 26 | Probe task 1.4 first; isolate in TouchStream; fallback research documented there |
| TCC grant lost on rebuild | Stable codesign identity "WindowGestures Local Dev"; never ad-hoc |
| System 3-finger gestures swallow swipes | Diagnostics + documented acceptance preconditions |
| Thresholds mistuned for real hardware | Tunables in one file; golden-trace replay to retune without re-recording |
