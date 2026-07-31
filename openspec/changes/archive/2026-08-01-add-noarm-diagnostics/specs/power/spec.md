# power — delta for add-noarm-diagnostics

## MODIFIED Requirements

#### Requirement: Diagnostic logging

(Additions only.) Reject lines SHALL also carry `near=K` — contacts the driver
reports in near-pad states (starting/hovering/breaking/lingering/leaving) at the
failure frame, so a finger hovering 1 mm off the pad (`raw=2 near=1`) is
distinguishable from a fully lifted one (`raw=2 near=0`). Touch sessions that saw
exactly-3 active fingers at least once but never ARMED SHALL emit one
`noarm frames3=… maxStreak=… minSize=… near=… dirty=…` line when the attempt ends
(all fingers lifted) — making flickering/light/hovering third fingers visible
(the dark matter behind "почти не ловит" reports, 2026-08-01). Same 1-line/s
rate limit and nil-channel zero cost.

##### Scenario: A flickering third finger is visible
- WHEN a 3-finger swipe attempt never stabilizes exactly-3 long enough to arm
- THEN the log contains one `noarm` line with the streak and contact evidence
