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

The Keep Awake menu SHALL offer a per-session "Keep awake with lid closed" ⚠ option
(mechanism spike-verified 2026-07-08). Starting such a session SHALL run exactly ONE
admin-authorized command that sets `pmset -a disablesleep 1` and arms a root
watchdog; the app SHALL refresh a sentinel file (every ~10 s) while the session
lives, and the watchdog SHALL restore `disablesleep 0` without further prompts once
the sentinel is stale or absent — covering normal stop, timer expiry, battery-floor
stop, app crash, and quit — or once a timed session's deadline (+ grace) passes.
The session SHALL additionally hold the public assertions (idle; plus plain
`PreventSystemSleep`, which alone suffices on AC). Cancelling the auth dialog SHALL
leave no session running. The option SHALL reset to off for every new session
(deliberate opt-in friction) and its UI copy SHALL warn about heat (never run
closed in a bag). The battery floor applies unchanged. At launch, Tiler SHALL
reconcile a leftover `SleepDisabled 1` with no live session by alerting with a
one-click (admin-authorized) restore.

##### Scenario: Lid closed during clamshell session
- WHEN the lid closes during a session with the option enabled
- THEN the system keeps running (verified hands-on at gate 4.2)

##### Scenario: Clamshell session ends without a second prompt
- WHEN such a session ends for any reason (Stop, expiry, floor stop)
- THEN `pmset -g` shows SleepDisabled 0 within the watchdog grace (~15 s) with no
  additional authorization dialog, and normal lid-close sleep behavior returns

##### Scenario: Floor stop while the lid is closed
- WHEN the battery floor stops a clamshell session while the lid is closed
- THEN the watchdog restores normal sleep and the Mac goes to sleep unattended

##### Scenario: App killed mid-clamshell-session
- WHEN the app is force-quit during a clamshell session
- THEN the sentinel goes stale and `pmset -g` shows SleepDisabled 0 within ~60 s

##### Scenario: Authorization cancelled
- WHEN the user cancels the admin dialog at clamshell session start
- THEN no session starts and the menu shows the inactive state

##### Scenario: Stale flag reconciliation
- WHEN Tiler launches while SleepDisabled is 1 and no session marker exists
- THEN an alert explains the state and offers a one-click restore

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
records discrete power events (session start/stop/expiry/floor-stop, assertion
acquire/release, clamshell arm/disarm, Deep Sleep enable/disable, source flips, and
launch reconciliation) to `~/Library/Logs/Tiler/power-debug.log`. Logging SHALL be
event-driven only (no polling), deduped for noisy sources, and bounded on disk
(rotate past ~512 KB to a single backup, ≤ ~1 MB total) so it is safe to leave on for
days without material CPU or disk cost. A "Reveal Log" affordance SHALL open the file
in Finder.

##### Scenario: Logging a session over a multi-day run
- WHEN debug logging is on and the user runs timed and lid-closed sessions over days
- THEN the log holds one concise timestamped line per event and never exceeds ~1 MB
