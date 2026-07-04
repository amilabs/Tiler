# Tasks — stabilize-menu

- [x] 1.1 Menu: Tiler… / Settings… (⌘,) / Quit; ⚠︎ marker on Settings when
      unpermitted, updated live (permission change + menu open).
- [x] 1.2 Stability pass: 96 tests + acceptance ALL PASS (idle CPU max 0.8%).
      The earlier "process gone" acceptance failure was NOT an app crash: the
      harness launches a second Tiler (second pinch icon in the menu bar) and the
      owner closed the duplicate mid-measurement. Manual 30 s monitor: stable.
- [x] 1.3 Owner-reported idle CPU regression (20–30%) diagnosed and fixed:
      (a) AuxWindow retained closed windows → SwiftUI TimelineView animations kept
      rendering forever (17–21% after close) — windows now fully released on close
      and recreated on demand; (b) six 120 fps demo canvases while open (15–20%) —
      demos are now static poses that animate on hover, hero cycles poses via
      .periodic (1.4 s), occlusion pauses everything; (c) measurement methodology
      fixed: harness now measures true utilization (cputime delta) in three
      mandatory states — launch idle 0.13%, window open 0.50%, post-UI 0.20%.
      Root cause of the missed requirement: the harness only ever measured the
      launch state and used lifetime-average %cpu; both gaps are now closed.
- [ ] 1.4 Owner confirms; merge spec, archive.
