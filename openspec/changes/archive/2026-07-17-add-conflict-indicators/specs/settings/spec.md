# settings — delta for add-conflict-indicators

## MODIFIED Requirements

#### Requirement: Gestures tab conflict mark

While system gesture conflicts are detected AND gestures are enabled, the Gestures
tab item SHALL carry a "⚠︎" title suffix ("Gestures ⚠︎") so the conflict section is
discoverable without opening the tab. macOS tab items cannot be colored — the suffix
renders in the label color; the orange accent lives in the conflict rows inside the
tab and on the menu's Settings item (app-shell spec). With gestures disabled or no
conflicts the tab title stays plain "Gestures".

##### Scenario: Mark appears and clears live
- WHEN a system 3-finger gesture setting is enabled while the Settings window shows
  no conflicts, and the window refreshes (reopen / conflict refresh)
- THEN the tab reads "Gestures ⚠︎", and returns to "Gestures" once the system
  setting is moved to four fingers or Tiler's gestures are switched off
