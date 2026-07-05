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
- [x] 1.4 Owner follow-up: unified window reworked to a two-column, no-scroll
      layout (880×771 measured; story + troubleshooting left, reference right,
      header/permission/footer full-width; density tightened). CPU behavior
      accepted by owner («поведение хорошее»).
- [x] 1.5 Honesty about the tested configuration: footer states "verified on
      macOS 26.5 only"; README spells out that all acceptance claims refer to that
      configuration and porting is untested; spec requires the note until another
      configuration passes acceptance.
- [x] 1.6 Owner UI review fixes: Settings window collapse fixed (List-backed Form
      inside TabView reports no intrinsic height — explicit 460×320 frame; permission
      row and toggles visible again, measured 484×376); duplicate Settings button
      removed from troubleshooting (header gear is the single entry); permanent
      green permission banner removed — the card appears only while the permission
      is missing (guide now 880×720).
- [x] 1.7 Release prep: menu labels without ellipses (spec updated), version 0.2.0,
      product README (screenshots pending from owner — self-render produced no text,
      SwiftUI offscreen limitation; --render-shots tooling kept), TCC saga moved to
      docs/tcc-enrollment.md, release zip built.
- [x] 1.8 GitHub release v0.2.0 published (gh device flow; token now in keyring).
      README screenshots solved via SwiftUI ImageRenderer self-render (--render-shots
      from the built bundle): real UI, reproducible per release; Link and ProgressView
      don't rasterize under ImageRenderer — replaced with render-safe equivalents
      (styled Text link, capsule ProgressBar). List-backed Settings form can't render
      offscreen — README ships guide + calibration shots. Archived.
