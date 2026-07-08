import Foundation

/// Parses the "Battery Power:" section of `pmset -g custom` into a key→value map
/// (power spec, Deep Sleep profile). Section headers are non-indented and end with
/// ":"; setting lines are indented `key   value`, where the value is the final
/// whitespace field and the key is everything before it (some keys are multi-word,
/// e.g. "Sleep On Power Button"). Only the Battery section is returned; a missing
/// section yields `[:]`.
public enum PmsetCustomParser {
    public static func batterySettings(from output: String) -> [String: String] {
        var result: [String: String] = [:]
        var inBattery = false
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.isEmpty { continue }
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") {   // section header
                inBattery = line.trimmingCharacters(in: .whitespaces) == "Battery Power:"
                continue
            }
            guard inBattery else { continue }
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count >= 2, let value = fields.last else { continue }
            let key = fields.dropLast().joined(separator: " ")
            result[key] = String(value)
        }
        return result
    }
}
