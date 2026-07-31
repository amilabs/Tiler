# power — delta for rename-deep-sleep-battery

## MODIFIED Requirements

#### Requirement: Deep Sleep profile (battery)

(Naming + honesty; mechanism unchanged.) The toggle is named **"Deep Sleep on
battery"** (was "…on lid close" — the old label promised a lid-only scope pmset
cannot deliver; 2026-07-19 field surprise: idle sleep with the lid open hibernated
under another user). The requirement states explicitly: `hibernatemode` is per
POWER SOURCE, not per sleep cause — while the profile is on, EVERY battery sleep
hibernates (lid close and open-lid idle sleep alike), and the pmset profile is
machine-wide (all macOS users). UI copy (Settings, Guide, README) SHALL state both
facts plainly.

##### Scenario: Idle sleep with the lid open
- WHEN the profile is on and the Mac idle-sleeps on battery with the lid open
  (any user logged in)
- THEN that sleep is a hibernate — and the UI copy has said so up front
