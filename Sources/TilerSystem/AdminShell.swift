import Foundation

/// One-shot privilege escalation via the standard macOS admin dialog (power spec /
/// design.md model A). `osascript … with administrator privileges` shows the system
/// password/Touch-ID prompt; the owner's daily user has no sudo, so this is the only
/// sanctioned privileged path. Never call `sudo`.
public enum AdminShellError: Error, Equatable {
    case cancelled                                  // user dismissed the auth dialog
    case failed(status: Int32, message: String)
}

public enum AdminShell {
    /// Turn an arbitrary shell string into an AppleScript string literal: escape
    /// backslashes first, then double-quotes, then wrap in quotes. Newlines are legal
    /// inside AppleScript literals and pass through unescaped (the watchdog script is
    /// multi-line).
    public static func appleScriptLiteral(_ shell: String) -> String {
        let escaped = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// Run `shell` as root through the admin dialog. Returns trimmed stdout. A
    /// cancelled dialog throws `.cancelled`; any other non-zero exit throws `.failed`.
    @discardableResult
    public static func runPrivileged(_ shell: String) throws -> String {
        let script = "do shell script \(appleScriptLiteral(shell)) with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let stdout = String(decoding: outData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = String(decoding: errData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            if stderr.contains("User canceled") || stderr.contains("-128") {
                throw AdminShellError.cancelled
            }
            throw AdminShellError.failed(status: process.terminationStatus, message: stderr)
        }
        return stdout
    }
}
