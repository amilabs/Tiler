# Tiler — instructions for Claude sessions

**Start here every session:**
1. Read `openspec/project.md` (context, environment, workflow rules).
2. Read the active change: `openspec/changes/add-tiler-mvp/` — `tasks.md` is the
   implementation plan; `design.md` holds approved decisions; `specs/` are the
   requirements (scenarios = required tests).
3. Continue from the first unchecked task. Update `tasks.md` checkboxes **as you work**
   and keep specs in sync with any behavior change (owner mandate: everything is
   protocoled in OpenSpec, updated on any change).

**Hard rules:**
- False gesture positives are release blockers (see gestures spec).
- TDD for recognizer/window logic; run `swift build && swift test` before claiming done.
- Sign every .app build with identity "WindowGestures Local Dev" (never ad-hoc) so
  TCC grants survive rebuilds.
- No new system-wide installs or external dependencies without asking the owner.
- Minimize owner involvement: batch questions; the only owner touchpoints are the
  `[USER GATE]` items in tasks.md.
- Owner communicates in Russian; repo artifacts are in English.

**Environment:** macOS 26.5 / Xcode 26.6 / Swift 6.3; push via SSH to
`git@github.com:amilabs/Tiler.git` (`gh` CLI not authenticated); Node.js absent —
OpenSpec structure is maintained manually, no CLI.
