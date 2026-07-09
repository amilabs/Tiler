# power — delta for add-power-control (new capability)

## ADDED Requirements

#### Requirement: Keep Awake session

The feature is labelled **"Prevent Sleep"** in all user-facing UI (owner, gate 2.1);
the internal power-assertion names remain `Tiler Keep Awake …` (acceptance greps and
this spec's scenarios rely on them). Tiler SHALL hold the system awake on user command
from the menu bar: indefinitely or for a fixed duration of 10 min, 30 min, 1 h, 2 h,
5 h, 10 h, or 24 h, implemented with macOS power assertions (no elevated privileges). By default the display MAY sleep
while the system stays awake. Starting a session while one is active SHALL replace it
(single assertion set, new deadline). Stopping or expiry SHALL release assertions
immediately. Assertions SHALL NOT outlive the app process (crash safety).

##### Scenario: Timed session expires
- WHEN a "For 30 min" session reaches its deadline
- THEN assertions are released, and the menu and status item show the inactive state

##### Scenario: App killed mid-session
- WHEN the app is force-quit during an active session
- THEN `pmset -g assertions` no longer lists a Tiler assertion

##### Scenario: Replacing an active session
- WHEN the user picks "For 2 h" while an indefinite session runs
- THEN exactly one Tiler assertion set remains, expiring in 2 h

#### Requirement: Display hold option

Settings SHALL offer "Keep display awake" (default off). The option SHALL apply
without restart, including to an already-active session.

##### Scenario: Toggled during an active session
- WHEN the user enables "Keep display awake" while a session runs
- THEN the display-sleep assertion is added to the running session immediately

#### Requirement: Battery floor

Settings SHALL offer a battery floor: Off / 30% / 20% / 10% (default 20%). While a
session is active and the Mac is on battery power at or below the floor, the session
SHALL stop automatically with a user-visible notification. A floor stop SHALL NOT
auto-restart the session on recharge or AC attach — restarting is an explicit user
action. Floor evaluation SHALL be event-driven (power-source change notifications).

##### Scenario: Floor crossed on battery
- WHEN the battery reaches 20% with the default floor during a session on battery
- THEN the session stops and a notification explains why

##### Scenario: Same charge on AC
- WHEN the charge is 15% but the Mac is on AC power
- THEN the session keeps running

##### Scenario: No auto-restart
- WHEN AC is attached after a floor stop
- THEN no session starts until the user starts one

#### Requirement: Lid-closed keep-awake

The Prevent Sleep menu SHALL offer lid-closed sessions via a single "Prevent sleep
with lid closed…" ⚠ item that opens a dialog (duration picker + heat warning + Start/
Cancel), so each lid-closed start is an explicit, atomic, per-session choice — not a
menu-closing checkbox. Starting such a session SHALL set `pmset -a disablesleep 1`
through the standard admin dialog (a FOREGROUND command — verified to run as root; a
detached background watchdog is NOT used: it was proven to be reaped by the privileged
wrapper on macOS 26, 2026-07-09, and never restored the flag). The flag is cleared with
`pmset -a disablesleep 0` through the same foreground admin path when the session ends
(Stop, timer expiry, battery-floor stop); macOS caches the admin credential for ~5 min,
so a short session ends with no second prompt. Because there is no promptless daemon,
Tiler SHALL self-check for a leftover flag AT LAUNCH and ON WAKE (and offer a one-click
restore) so a crash/quit or a cancelled restore self-heals; a reboot also clears the
runtime flag. The session SHALL additionally hold the public assertions (idle; plus
plain `PreventSystemSleep`, which alone suffices on AC). Cancelling the auth dialog at
start SHALL leave no session running. Choosing a lid-closed start is itself the
per-session opt-in (no persistent mode to leave on) and its UI copy SHALL warn about
heat (never run closed in a bag). The battery floor applies unchanged. (Trade-off vs a
root daemon / model B: a battery-floor stop while the Mac is literally in a bag would
wait for the user to authorize the restore on return — the very misuse the ⚠ warns
against; deferred unless it proves necessary.)

##### Scenario: Lid closed during clamshell session
- WHEN the lid closes during a session with the option enabled
- THEN the system keeps running (verified hands-on at gate 4.2: ~44 min, continuous
  liveness heartbeats)

##### Scenario: Clamshell session ends (short session)
- WHEN such a session started and is stopped within ~5 min
- THEN `pmset -g` shows SleepDisabled 0 with no second authorization dialog (cached
  credential), and normal lid-close sleep behavior returns

##### Scenario: Authorization cancelled
- WHEN the user cancels the admin dialog at clamshell session start
- THEN no session starts and the menu shows the inactive state

##### Scenario: Leftover flag self-heals at launch/wake
- WHEN Tiler launches or wakes while SleepDisabled is 1 with no live clamshell session
- THEN an alert explains the state and offers a one-click (admin-authorized) restore

#### Requirement: Deep Sleep profile (battery)

Tiler SHALL offer a persistent "Deep Sleep on lid close" toggle (Settings → Power)
switching the battery-side sleep profile to full hibernation: `hibernatemode 25` with
Power Nap and TCP keep-alive disabled (and proximity wake where the key exists) — so
sleep writes RAM to disk and powers it off. Writes are admin-authorized. Before the
first write Tiler SHALL snapshot the previous values and SHALL restore them verbatim
on disable (missing snapshot → Apple portable defaults: hibernatemode 3, powernap 1,
tcpkeepalive 1). AC-side sleep SHALL stay untouched. The profile persists across
reboots by design; at every launch Tiler SHALL reconcile the toggle with actual
`pmset -g custom` values. UI SHALL state the slower wake (~10–20 s).

##### Scenario: Enabling the profile
- WHEN the user enables Deep Sleep and authorizes
- THEN battery-side pmset shows hibernatemode 25 / powernap 0 / tcpkeepalive 0, and
  the toggle still shows on after relaunch

##### Scenario: Disabling restores verbatim
- WHEN the user disables Deep Sleep
- THEN the snapshotted previous values are written back exactly

##### Scenario: Authorization cancelled
- WHEN the auth dialog is cancelled
- THEN the toggle reverts and settings reflect the re-read actual pmset state

##### Scenario: Manual pmset edits
- WHEN the owner changes hibernatemode manually and relaunches Tiler
- THEN the toggle reflects the actual system state

#### Requirement: Precedence

An active Keep Awake session SHALL take precedence over sleep entirely; the Deep
Sleep profile governs *how* the Mac sleeps whenever it actually sleeps on battery;
with neither, system defaults apply. Help SHALL document this order.

##### Scenario: Both features engaged
- WHEN Deep Sleep is on and a lid-closed session is active
- THEN closing the lid keeps the Mac awake; after the session ends, the next
  battery sleep hibernates

#### Requirement: Diagnostic logging

Settings → Power SHALL offer an opt-in "Debug logging" toggle (default off) that
records power events to `~/Library/Logs/Tiler/power-debug.log`: discrete events
(session start/stop/expiry/floor-stop, assertion acquire/release with held summary,
clamshell arm/disarm, Deep Sleep enable/disable, deduped source changes, launch
reconciliation), system sleep/wake, screen sleep/wake, and screen lock/unlock (incl.
the ⌃A hotkey, via distributed notifications) with the current lid state,
and — while a session runs — a ~15 s liveness heartbeat (elapsed, power, lid, held
assertions) so a real sleep shows as a heartbeat gap. Logging SHALL be event/heartbeat
driven (no busy polling) and bounded on disk (rotate through 3 backups past ~5 MB each,
≤ ~20 MB total) so it is safe to leave on for days. A "Reveal Log" affordance SHALL
open the file in Finder.

##### Scenario: Lid-closed session over a multi-day run
- WHEN debug logging is on and a lid-closed session runs with the lid shut for 20 min
- THEN the log shows continuous ~15 s heartbeats with `lid=closed` across that span
  (proving the Mac stayed awake), and total size stays well under the ~20 MB bound
