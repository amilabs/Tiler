# Tasks — fix-rebuild-gesture-loss

Owner go-ahead 2026-08-01 ("approved" — translated) on the two-part proposal from the 07-31 log
diagnosis. No user gates (no UI).

- [x] 1. TDD `StreamHealthPolicy.displayChangeRebuild` (coalesce <10 s, alive
      ≤1 s, else rebuild; boundaries pinned).
- [x] 2. TDD recognizer rejection diagnostics: reasons short/slow/brief/ambiguous/
      fingers/palm/reversal/timeout; intent filter (≥ half displacement threshold);
      1 s rate limit on frame time; no line for resting lifts; fire still logs
      exactly one `fire` line.
- [x] 3. AppDelegate: display-change handler → policy decision, log
      `display change screens=N -> rebuild|skip (alive|coalesced)`.
- [x] 4. Full tests + acceptance; specs merged (app-shell recovery politeness,
      power diagnostic logging); release with v0.3.4.
