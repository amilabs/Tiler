# Tasks — stabilize-menu

- [x] 1.1 Menu: Tiler… / Settings… (⌘,) / Quit; ⚠︎ marker on Settings when
      unpermitted, updated live (permission change + menu open).
- [x] 1.2 Stability pass: 96 tests + acceptance ALL PASS (idle CPU max 0.8%).
      The earlier "process gone" acceptance failure was NOT an app crash: the
      harness launches a second Tiler (second pinch icon in the menu bar) and the
      owner closed the duplicate mid-measurement. Manual 30 s monitor: stable.
- [ ] 1.3 Owner confirms; merge spec, archive.
