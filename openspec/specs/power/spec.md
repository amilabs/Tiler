# power — Prevent Sleep & Deep Sleep

Merged from add-power-control (v0.3.0). Caffeinator-class power control: Prevent Sleep
sessions (indefinite / timed / until a set time), battery floor, lid-closed keep-awake
via a foreground admin watchdog, and a persistent battery-side Deep Sleep profile.

## Requirements

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
menu-closing checkbox. Starting such a session SHALL run EXACTLY ONE admin-authorized
command that sets `pmset -a disablesleep 1` and then runs an inline watchdog which
restores `disablesleep 0` — all as the FOREGROUND command of one
`osascript … with administrator privileges`, launched asynchronously. It MUST NOT
background the watchdog with `&` (the privileged wrapper reaps such children — proven
on macOS 26, 2026-07-09 — so the flag was never restored). A foreground command runs as
root and survives the app's death, so the restore is PROMPTLESS. The app keeps a
sentinel file fresh (~10 s) while the session lives; the watchdog restores the flag once
the sentinel is removed (clean Stop / timer expiry / battery-floor stop), goes stale
(crash / quit / in a bag), or a timed deadline (+ grace) passes — no second prompt in
any case. Cancelling the auth dialog at start SHALL leave no session running. The
session SHALL additionally hold the public assertions (idle; plus plain
`PreventSystemSleep`, which alone suffices on AC). Choosing a lid-closed start is itself
the per-session opt-in (no persistent mode to leave on) and its UI copy SHALL warn about
heat (never run closed in a bag). The battery floor applies unchanged. When a lid-closed
session ends on its own (timer expiry or battery floor — NOT a user Stop) while the lid
is still closed, Tiler SHALL put the Mac to sleep once the flag is restored: macOS does
not re-trigger lid-close sleep for an already-closed lid, so "keep awake N min with the
lid closed" would otherwise leave it awake until the lid is cycled. As a rare
backstop (watchdog process itself killed), Tiler SHALL self-check at launch and on wake:
a leftover `SleepDisabled 1` with no live session is offered for a one-click restore via
a warning alert carrying the heat/bag graphic.

##### Scenario: Lid closed during clamshell session
- WHEN the lid closes during a session with the option enabled
- THEN the system keeps running (verified hands-on at gate 4.2: ~44 min, continuous
  liveness heartbeats)

##### Scenario: Clamshell session ends without a second prompt
- WHEN such a session ends for any reason (Stop, expiry, floor stop, crash, quit)
- THEN `pmset -g` shows SleepDisabled 0 within the watchdog grace (~15 s) with NO
  additional authorization dialog, and normal lid-close sleep behavior returns

##### Scenario: Authorization cancelled
- WHEN the user cancels the admin dialog at clamshell session start
- THEN no session starts and the menu shows the inactive state

##### Scenario: Leftover flag self-heals at launch/wake
- WHEN Tiler launches or wakes while SleepDisabled is 1 with no live clamshell session
  (the watchdog process was killed)
- THEN a warning alert (with the heat/bag graphic) offers a one-click restore

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
records power events (and, for diagnosis, gesture decisions and sleep-blocker
assertions) to `~/Library/Logs/Tiler/power-debug.log`: discrete events
(session start/stop/expiry/floor-stop, assertion acquire/release with held summary,
clamshell arm/disarm, Deep Sleep enable/disable, deduped source changes, launch
reconciliation), system sleep/wake, screen sleep/wake, and screen lock/unlock (incl.
the ⌃A hotkey, via distributed notifications) with the current lid state,
and — while a session runs — a ~15 s liveness heartbeat (elapsed, power, lid, held
assertions) so a real sleep shows as a heartbeat gap. For diagnosis it SHALL also log
every confirmed gesture decision with its evidence (direction, movement, speed, finger
count, modifiers — so a false positive is caught with data, not guesswork), every
executed window move with its source (gesture / hotkey — so a window that moves with no
such line is provably not Tiler), and, at
launch/wake/sleep transitions and after a session release, the full set of
sleep-blocking assertion holders (`pmset -g assertions`, incl. non-Tiler holders) so
"why won't it sleep" needs no manual command. The log SHALL also record the
touch-stream lifecycle (fix-touch-stream-resilience, v0.3.1) so a dead-gestures
report is attributable from the log alone: device IDs at every successful stream
start; every rebuild with its trigger reason and resulting device signature (and
failures with the error); device drift with the old and new ID sets; debounced
display-reconfiguration events with the screen count; and every silence self-heal
decision with its evidence (silence age, HID age) — healthy watchdog ticks log
nothing, and rebuild/failure lines are mirrored to NSLog (they matter even with
debug logging off). Logging SHALL be event/heartbeat driven
(no busy polling) and bounded on disk (rotate to one backup past ~100 MB, ≤ ~200 MB
total — owner asked for detailed multi-day logging without disk worry, 2026-07-10) so
it is safe to leave on for days. A "Reveal Log" affordance SHALL open the file in Finder.

##### Scenario: Lid-closed session over a multi-day run
- WHEN debug logging is on and a lid-closed session runs with the lid shut for 20 min
- THEN the log shows continuous ~15 s heartbeats with `lid=closed` across that span
  (proving the Mac stayed awake), and total size stays within the ~200 MB bound

##### Scenario: Dead stream is attributable post-hoc
- WHEN gestures stop being recognized on a machine with debug logging on
- THEN the log names the recovery trigger that fired (or shows the last stream
  start and the absence of frames) without needing a reproduction
