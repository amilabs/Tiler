# Change: add-power-control

## Why

Owner request (2026-07-08, chat): Tiler should cover caffeinator-class power control so
no separate app (Caffeinator/CoffeeTea) is needed — keep the Mac awake on demand
(indefinitely or for a fixed time, with a battery floor), keep it awake with the lid
closed, and the opposite: make lid-close sleep a *true* hibernate, because default
sleep keeps draining the battery in the background even with everything tuned off.

## What Changes

1. **Keep Awake sessions** (menu bar): indefinite or timed — 10 min / 30 min / 1 h /
   2 h / 5 h / 10 h / 24 h — via public IOPMAssertion API, no elevated privileges.
   Display sleep stays allowed by default; Settings option "Keep display awake".
2. **Battery floor**: Off / 30% / 20% / 10% (default 20%). An active session
   auto-stops at/below the floor **on battery**, with a notification; no auto-restart.
3. **Lid-closed keep-awake** (session option, ⚠ heat warning): additionally holds the
   system awake with the lid closed (Amphetamine-style system assertion that also
   applies on battery). Feasibility spike on macOS 26 first; fallback =
   `pmset disablesleep` via admin auth (gated).
4. **Deep Sleep on lid close**: persistent battery-side profile switch —
   `hibernatemode 25` + Power Nap / TCP keep-alive off — so sleep writes RAM to disk
   and powers off (community data: ≈1%/8 h vs 6–7%/8 h at default mode 3).
   Admin-authorized `pmset` writes; previous values snapshotted and restored on
   disable; AC sleep behavior untouched.
5. New **Power section in the menu** and **Power tab in Settings**; status-item state
   for an active session. Target release: **v0.3.0**.

| Capability | Delta |
|---|---|
| `power` | ADDED — sessions, battery floor, clamshell option, deep-sleep profile |
| `app-shell` | MODIFIED — menu Power section, status glyph session state |
| `settings` | MODIFIED — Power tab (display hold, battery floor, deep sleep) |

## Out of scope

- Wake schedules (`pmset repeat`), per-app/per-process awake triggers, calendar rules.
- Shortcuts / CLI / URL-scheme control of sessions.
- Login-item/autostart changes; any always-on root helper (unless gate 0.1 picks it).
