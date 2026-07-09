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

    // The clamshell flag is set/cleared with plain `pmset -a disablesleep 1/0` via a
    // foreground admin command; the old detached-watchdog `armCommand` was removed
    // (proven reaped by the privileged wrapper — the restore never ran).
}
