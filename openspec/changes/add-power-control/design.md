# Design — add-power-control

## Research findings (2026-07-08)

### Power assertions (the no-root workhorse)

`IOPMAssertionCreateWithProperties` (IOKit/pwr_mgt, public API, no sandbox/root issues
for us — App Sandbox is already off):

- `kIOPMAssertionTypePreventUserIdleSystemSleep` — system stays awake, display may
  sleep. This is `caffeinate -i`. Base of every Keep Awake session.
- `kIOPMAssertionTypePreventUserIdleDisplaySleep` — display stays on too
  (`caffeinate -d`). Added when "Keep display awake" is on.
- `kIOPMAssertionTypePreventSystemSleep` — blocks non-forced system sleep; by default
  honored on AC only; adding `kIOPMAssertionAppliesToLimitedPowerKey = true` makes it
  apply on battery as well. This is the lid-closed candidate.

Key property: assertions are **process-scoped** — powerd releases them when the owning
process exits, so a crash can never leave the Mac stuck awake. Verification is
scriptable: `pmset -g assertions` lists holder + named assertion
(acceptance greps for `pro.amilabs.tilerx` / assertion name).

`caffeinate` as a child process was considered and rejected (approach 2 below).

### Lid-closed keep-awake (clamshell)

macOS forces sleep on lid close except in closed-display mode (external display + AC +
input device). Amphetamine documents that it lifts these requirements with the
*public* assertion API — no root, no AC, no external display — and that on Apple
Silicon the built-in panel is still forced to sleep when folded (desired; prevents
burn-in). Their "Power Protect" add-on exists because unplugging AC mid-clamshell on
Apple Silicon can end the session unexpectedly — our battery floor + explicit session
model covers the same risk class.

Unknown: whether macOS 26 still honors `PreventSystemSleep(+LimitedPower)` across a
lid close on battery — Apple has tightened clamshell behavior over the years, and the
press coverage is contradictory. **Decision: hands-on spike (task 0.2) before any UI
work.** Fallback if assertions lose: `sudo pmset -a disablesleep 1` (documented in
`man pmset`; blocks all sleep incl. clamshell, incl. on battery; root-only). The
fallback is dangerous global state (persists until unset), so it would ship only with:
set on session start / unset on every session end, relaunch reconciliation (clear the
flag if no session is active), and the same battery floor. Gate 0.1 decides whether
the fallback is acceptable at all.

Safety: lid-closed awake in a bag = heat. UI copy carries ⚠ and Help explains; the
clamshell option deliberately resets to OFF for every new session (opt-in friction).

### Deep Sleep ("заснуть намертво")

`pmset -g custom` / `man pmset` facts:

- `hibernatemode 0` — sleep keeps RAM powered (desktops). `3` (portable default) —
  RAM powered + sleepimage on disk ("safe sleep"), background DarkWake activity
  (Power Nap, tcpkeepalive) keeps draining. `25` — suspend-to-disk: sleepimage
  written, RAM powered off; wake takes ~10–20 s; works on Apple Silicon.
- Community measurements: mode 3 ≈ 6–7% battery per 8 h of "sleep"; mode 25 ≈ 1%.
- Contributors to background drain that we also disable (battery side):
  `powernap 0`, `tcpkeepalive 0` (+ `proximitywake 0` where the key exists).
- `pmset` writes require root and **persist across reboots** — for this feature that
  is the point (a persistent profile), but it means: snapshot previous values before
  the first write, restore them verbatim on disable, and reconcile the toggle with
  actual `pmset -g custom` output at every launch (owner may flip values manually).
- Profile applies **battery-side only** (`pmset -b`): docked/AC sleep (incl. native
  closed-display mode at a desk) keeps stock behavior and instant wake.

### Privilege paths for `pmset`

- **A. Per-toggle admin auth**: `osascript -e 'do shell script "pmset …" with
  administrator privileges'` — zero infrastructure, standard macOS auth dialog
  (password/Touch ID), one prompt per Deep Sleep toggle. Toggling is rare
  (set-and-forget profile), so prompts are infrequent by nature.
- **B. Root helper daemon**: `SMAppService.daemon` + XPC + audit-token checks —
  promptless after a one-time install approval (System Settings → Login Items),
  but adds signing/packaging surface, uninstall hygiene, and a resident root
  process to a project that so far ships a single signed .app. Also the only path
  that could auto-restore `disablesleep` after a crash, if the fallback is ever used.

Recommendation: **A** now; revisit B only if the clamshell spike forces the
`disablesleep` fallback into the product (auto-restore argument) or the owner
objects to prompts. [Gate 0.1]

### Battery monitoring

`IOPSCopyPowerSourcesInfo` + `IOPSGetPowerSourceDescription` give percentage
(`kIOPSCurrentCapacityKey`) and source state (`kIOPSPowerSourceStateKey`:
AC vs battery); `IOPSNotificationCreateRunLoopSource` delivers change events —
no polling, no root. Floor rule evaluated on every event: session active AND on
battery AND percent ≤ floor → stop (reason: batteryFloor) + notification.

## Approaches considered

1. **In-process assertions + IOPS events; admin-auth `pmset` only for Deep Sleep**
   — no new processes or dependencies, sessions crash-safe by construction, root
   surface limited to a rare, explicit, user-authorized action. **Recommended.**
2. `caffeinate` child processes — simplest start, but no clamshell story at all,
   process babysitting, and IOPS/UI work remains anyway. Rejected.
3. Root helper daemon doing everything via `pmset` (incl. `disablesleep` for
   clamshell) — strongest guarantees, promptless; but heavy infra and a resident
   root process is disproportionate for v1. Deferred (see gate 0.1 / spike outcome).

## Architecture (approach 1)

- **TilerCore** (pure, TDD): `PowerPolicy` — session state machine. State:
  `off | active(mode, clamshell, deadline: Date?)`; inputs: user commands, clock
  ticks, battery events `(percent, onBattery)`, floor setting; outputs: effects
  (`acquireAssertions(spec)`, `releaseAssertions`, `notify(reason)`). Clock and
  battery injected — unit tests cover expiry, floor crossing on battery vs AC,
  no-auto-restart after floor stop, session replacement.
- **TilerSystem**:
  - `AwakeController` — owns assertion IDs; translates `spec` (system/display/
    clamshell) into create/release calls; NSLog state lines for harness greps.
  - `PowerSourceMonitor` — IOPS wrapper → `(percent, onBattery)` callbacks.
  - `PowerProfileController` — `pmset -g custom` snapshot/parse, battery-side
    apply/restore, launch reconciliation; executes via `AdminShell` (osascript
    admin-auth wrapper). Missing snapshot on disable → Apple portable defaults
    (hibernatemode 3, powernap 1, tcpkeepalive 1).
  - `SettingsStore` +4: `keepDisplayAwake=false`, `batteryFloorPercent=20` (0=Off),
    `deepSleepOnBattery=false` (reconciled at launch), `powerSnapshot` (JSON).
- **Tiler (UI)**: menu section — `Keep Awake` submenu (Start / durations / lid-closed
  ⚠ option / Stop, header row shows remaining time, refreshed in `menuWillOpen`);
  status item appends a compact glyph while a session is active (exact glyph — via
  mockups, owner visual-first rule). Deep Sleep toggle lives in Settings → Power tab
  only (persistent set-and-forget profile; keeps the menu lean) with the wake-time
  caveat and explanation. Guide/Help gains a Power section incl. the heat warning.
- **Precedence** (documented in Help): active Keep Awake session ≻ Deep Sleep profile
  ≻ system defaults. No technical conflict: assertions decide *whether* the Mac
  sleeps; hibernatemode decides *how* it sleeps when it does.
- **Quit/crash**: assertions vanish with the process (acceptance-verified); the Deep
  Sleep profile intentionally survives (persistent preference), reconciled at launch.
- **Failures**: assertion create failure → menu shows error state + log; auth
  cancelled / pmset write failed → toggle reverts, state re-read from `pmset`.
- **Notifications**: UserNotifications banner on floor auto-stop (and deep-sleep
  apply/restore failure); permission requested lazily on first session start.

## Testing

- TDD `PowerPolicy` in TilerCoreTests (the only new pure-logic unit).
- SettingsStoreTests: new keys round-trip.
- Acceptance (`run-acceptance.sh` additions): session start → `pmset -g assertions`
  contains the named assertion; stop → absent; `kill -9` app → absent (crash safety).
  Deep Sleep apply/restore → `pmset -g custom` diff matches, verbatim restore
  (hands-on, gated — needs admin auth).
- Existing gesture/hotkey suites untouched but run in full (no-false-positives
  invariant is release-blocking regardless of feature area).

## Open questions → gates

1. Privilege model A vs B (recommend A) — gate 0.1.
2. Clamshell spike outcome; if assertions fail on macOS 26: accept `disablesleep`
   fallback, restrict lid-closed mode to AC, or drop it — gate 0.2 → 0.3.
3. UI naming/layout/glyph sign-off from rendered mockups — gate 2.1.

## Sources

- Amphetamine (App Store listing + developer support portal): closed-display mode via
  public IOPMAssertion API, Apple Silicon folded-display behavior, Power Protect.
- `man pmset` (macOS 26): `disablesleep`, `hibernatemode 0/3/25`, per-source flags.
- Apple IOKit/pwr_mgt headers: assertion types, `AppliesToLimitedPower`, timeout keys.
- Community measurements of mode-3 vs mode-25 sleep drain (MacRumors threads, Intego
  sleep-mode overview, makaiteetum.com battery-drain guide): 6–7% vs ≈1% per 8 h.
- Macworld clamshell overview (macOS tightening lid-close sleep over releases).
