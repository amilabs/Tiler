import Foundation
import Testing
@testable import TilerSystem

// Pure string composition for the clamshell root path (power spec). The admin auth
// and the sentinel watchdog are exercised hands-on at gate 4.2; here we lock the two
// pure helpers whose exact bytes matter: AppleScript escaping and the watchdog arm
// command.
@Suite("Admin command composition") struct AdminCommandTests {

    // MARK: appleScriptLiteral — escape \ then ", wrap in quotes; newlines stay raw.

    @Test func literalPlainWrapsInQuotes() {
        #expect(AdminShell.appleScriptLiteral("echo hi") == "\"echo hi\"")
    }

    @Test func literalEscapesEmbeddedQuotes() {
        // Input:  say "hi"      Output: "say \"hi\""
        #expect(AdminShell.appleScriptLiteral(#"say "hi""#) == #""say \"hi\"""#)
    }

    @Test func literalEscapesBackslashBeforeQuote() {
        // Input two chars  \ "   →  \\ \"  (backslash escaped first)
        #expect(AdminShell.appleScriptLiteral("\\\"") == "\"\\\\\\\"\"")
    }

    @Test func literalKeepsNewlineRaw() {
        // Newlines are valid inside AppleScript string literals — not escaped.
        #expect(AdminShell.appleScriptLiteral("a\nb") == "\"a\nb\"")
    }

    // MARK: armCommand — the FOREGROUND watchdog (not backgrounded `&`: that gets reaped
    // by the privileged wrapper). D=0 indefinite, else deadline epoch + 120 s grace.

    private func expectedArm(d: Int) -> String {
        [
            "pmset -a disablesleep 1",
            "echo 1 > \(DisableSleepGovernor.startedPath)",
            "S=\(DisableSleepGovernor.sentinelPath); D=\(d)",
            "while [ -f \"$S\" ]; do",
            "  A=$(( $(date +%s) - $(stat -f %m \"$S\") )); [ \"$A\" -lt 45 ] || break",
            "  [ \"$D\" -eq 0 ] || [ \"$(date +%s)\" -lt \"$D\" ] || break",
            "  sleep 10",
            "done",
            "pmset -a disablesleep 0",
            "rm -f \"$S\"",
        ].joined(separator: "\n")
    }

    @Test func armIndefiniteUsesDZero() {
        #expect(DisableSleepGovernor.armCommand(deadline: nil) == expectedArm(d: 0))
    }

    @Test func armTimedUsesDeadlineEpochPlusGrace() {
        let deadline = Date(timeIntervalSince1970: 1_000_000)
        #expect(DisableSleepGovernor.armCommand(deadline: deadline) == expectedArm(d: 1_000_120))
    }

    @Test func armIsForegroundNotBackgrounded() {
        let cmd = DisableSleepGovernor.armCommand(deadline: nil)
        #expect(!cmd.contains("nohup"))
        #expect(!cmd.contains("&"))
        #expect(cmd.contains("-lt 45"))   // staleness cutoff
    }
}
