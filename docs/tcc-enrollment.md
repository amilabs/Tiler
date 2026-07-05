# TCC enrollment on macOS 26 — the hard-won recipe

Symptom we fought: the Accessibility prompt appears, but the app's row **silently
never persists** in System Settings (not via the prompt, not via "+", not via drag).
Root causes found on 2026-07-04, in order of discovery:

1. **Self-signed identities don't enroll.** A locally created certificate — even
   imported as a trusted Code Signing root into the *System* keychain — shows the
   prompt but tccd refuses to create the row. An Apple-issued **Apple Development**
   certificate is required (free Apple ID is enough; Xcode → Settings → Accounts →
   Manage Certificates → "+").
2. **Expired WWDR intermediate breaks the identity.** If `security find-identity`
   shows the Apple Development cert as `CSSMERR_TP_NOT_TRUSTED`, the Apple WWDR G3
   intermediate is missing/expired locally. Fix: import
   https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer into the login
   keychain.
3. **A TCC client record can wedge.** After many grant/reset cycles, the record for
   the original bundle id (`pro.amilabs.tiler`) got stuck: prompts shown, row never
   created, reboot didn't help, `tccutil reset` reported success but changed nothing.
   A **fresh bundle id** enrolled instantly — hence the current id
   `pro.amilabs.tilerx`. Don't "clean it up" back to the old id: the grant follows
   (bundle id + signing team), and the old id is dead on this machine.
4. **The list row may vanish while the grant persists.** System Settings sometimes
   stops SHOWING the Tiler row even though the TCC grant is alive (windows still
   move; `Tiler --ax-report <file>` prints `trusted=true`). Cosmetic Settings-UI
   flakiness on this machine — verify functionally, don't chase the row.

