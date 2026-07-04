# Tiler — instructions for Claude sessions

**Start here every session:**
1. Read `openspec/project.md` (context, environment, workflow rules).
2. Read the active change: `openspec/changes/add-tiler-mvp/` — `tasks.md` is the
   implementation plan; `design.md` holds approved decisions; `specs/` are the
   requirements (scenarios = required tests); `brief.md` is the owner's verbatim
   original assignment (source of truth if a spec seems off).
3. Continue from the first unchecked task. Update `tasks.md` checkboxes **as you work**
   and keep specs in sync with any behavior change (owner mandate: everything is
   protocoled in OpenSpec, updated on any change).

The design was approved by the owner on 2026-07-04 — implement it; do not re-open design
questions unless you find a real contradiction (then fix the spec and note it in
design.md). Build/acceptance scripts referenced in `openspec/project.md` do not exist
until Phase 1 creates them. If your session runs in a git worktree (not the main checkout),
persistent memory files are unavailable — this file and `openspec/` carry everything
needed; merge your branch back to `main` and push when a phase completes.

**Hard rules:**
- False gesture positives are release blockers (see gestures spec).
- TDD for recognizer/window logic; run `swift build && swift test` before claiming done.
- Sign every .app build with the Apple Development identity and keep bundle id
  `pro.amilabs.tilerx` (constants in Scripts/make-app.sh — change neither: self-signed
  certs never enroll in Accessibility on macOS 26, and the original id's TCC record is
  wedged on the owner's machine; see README "TCC enrollment" for the full recipe).
- No new system-wide installs or external dependencies without asking the owner.
- Minimize owner involvement: batch questions; the only owner touchpoints are the
  `[USER GATE]` items in tasks.md.
- Owner communicates in Russian; repo artifacts are in English.

**Environment:** macOS 26.5 / Xcode 26.6 / Swift 6.3; push via SSH to
`git@github.com:amilabs/Tiler.git` (`gh` CLI not authenticated); Node.js absent —
OpenSpec structure is maintained manually, no CLI.
