# Tiler — instructions for Claude sessions

**Start here every session:**
1. Read `openspec/project.md` (context, environment, workflow rules).
2. Check the active change listed in `openspec/project.md`. Currently:
   **none** — latest shipped: `add-noarm-diagnostics` as v0.3.6 (2026-08-01, noarm + near= diagnostics for never-arming attempts), `improve-failure-attribution` as v0.3.5 (reject raw= + window-failure why/app; AX grant survives installs), `fix-rebuild-gesture-loss` + `rename-deep-sleep-battery` as v0.3.4 (polite display-change rebuilds + reject diagnostics + honest Deep Sleep naming), `add-conflict-indicators` as v0.3.3 (2026-07-17,
   colored menu/tab conflict marks gated on gesturesEnabled), `lower-macos-floor`
   as v0.3.2 (launch floor 15 + universal; target/tested OS stays macOS 26 — owner
   rule: untested ≠ blocked), and `fix-touch-stream-resilience` as v0.3.1 (gesture
   stream recovery; field verification still pending), all archived
   under `openspec/changes/archive/` with full design history. Start new work as a
   fresh change folder. `openspec/specs/` is the current merged truth (scenarios =
   required tests). The owner's verbatim original assignment is
   `archive/2026-07-04-add-tiler-mvp/brief.md`.
3. New work starts as a new change folder (kebab-case) with proposal/design/tasks/spec
   deltas; update `tasks.md` checkboxes **as you work** and keep specs in sync with
   any behavior change (owner mandate: everything is protocoled in OpenSpec).

If your session runs in a git worktree (not the main checkout), persistent memory files
are unavailable — this file and `openspec/` carry everything needed; merge your branch
back to `main` and push when a phase completes.

**Hard rules:**
- False gesture positives are release blockers (see gestures spec).
- TDD for recognizer/window logic; run `swift build && swift test` before claiming done,
  plus `swift format lint --recursive --strict Sources` — must be clean (config in
  `.swift-format`; swift-format ships with the Swift 6 toolchain, zero install).
- Sign every .app build with the Apple Development identity and keep bundle id
  `pro.amilabs.tilerx` (constants in Scripts/make-app.sh — change neither: self-signed
  certs never enroll in Accessibility on macOS 26, and the original id's TCC record is
  wedged on the owner's machine; see README "TCC enrollment" for the full recipe).
- No new system-wide installs or external dependencies without asking the owner.
- Minimize owner involvement: batch questions; the only owner touchpoints are the
  `[USER GATE]` items in tasks.md.
- Owner communicates in Russian; repo artifacts are in English — this repo is
  **public**. Russian is fine in local working docs (untracked or unpushed);
  the rule binds at push time: no Cyrillic in pushed files or commit messages
  (owner rule, refined 2026-08-05). Owner quotes are recorded as English
  translations marked "translated". Gate before every push:
  `Scripts/check-english.sh` (tracked files + unpushed commit messages).
- Required plugins: `flow@flow-skeleton` + `superpowers` (its dependency). If `/flow:`
  skills are missing at session start, tell the owner before starting (the desktop GUI
  is known to silently drop third-party-marketplace plugins; reinstall + restart cures)
  and follow the OpenSpec lifecycle manually — it is fully described above.

**Environment:** macOS 26.5 / Xcode 26.6 / Swift 6.3; push via SSH to
`git@github.com:amilabs/Tiler.git`; `gh` CLI authenticated (alexnskcody) since
2026-07-05 — releases via `gh release`; Node.js absent —
OpenSpec structure is maintained manually, no CLI.
