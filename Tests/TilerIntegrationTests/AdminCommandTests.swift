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

    // MARK: armCommand — exact bytes; D=0 indefinite, else deadline epoch + 120 grace.

    private func expectedArm(d: Int) -> String {
        [
            "pmset -a disablesleep 1",
            "nohup /bin/zsh -c 'S=/tmp/pro.amilabs.tilerx.clamshell.sentinel; D=\(d)",
            "while :; do",
            "  [ -f \"$S\" ] || break",
            "  A=$(( $(date +%s) - $(stat -f %m \"$S\") )); [ \"$A\" -lt 45 ] || break",
            "  [ \"$D\" -eq 0 ] || [ \"$(date +%s)\" -lt \"$D\" ] || break",
            "  sleep 15",
            "done",
            "pmset -a disablesleep 0",
            "rm -f \"$S\"' >/dev/null 2>&1 &",
        ].joined(separator: "\n")
    }

    @Test func armIndefiniteUsesDZero() {
        let cmd = DisableSleepGovernor.armCommand(deadline: nil, now: Date(timeIntervalSince1970: 500))
        #expect(cmd == expectedArm(d: 0))
    }

    @Test func armTimedUsesDeadlineEpochPlusGrace() {
        let deadline = Date(timeIntervalSince1970: 1_000_000)
        let cmd = DisableSleepGovernor.armCommand(deadline: deadline, now: Date(timeIntervalSince1970: 500))
        #expect(cmd == expectedArm(d: 1_000_120))     // 1_000_000 + 120 s grace
    }

    @Test func armMentionsStalenessAndPollConstants() {
        let cmd = DisableSleepGovernor.armCommand(deadline: nil, now: Date())
        #expect(cmd.contains("-lt 45"))               // 45 s staleness cutoff
        #expect(cmd.contains("sleep 15"))             // 15 s poll interval
        #expect(cmd.contains(DisableSleepGovernor.sentinelPath))
    }
}
