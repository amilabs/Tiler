import Foundation
import IOKit.pwr_mgt
import TilerCore

/// Owns the live IOPMAssertion IDs for a Keep Awake session (power spec). Translates
/// an `AssertionSpec` (nil = release all) into create/release of three named public
/// assertions, diffing against what is currently held so `apply` is idempotent.
/// Assertions are process-scoped: powerd releases them when Tiler exits, so a crash
/// can never leave the Mac stuck awake (acceptance-verified).
///
/// IOPMLib's `k…` string constants are CFSTR macros that do NOT import into Swift, so
/// the property keys are literal strings (`"AssertType"`, `"AssertName"`,
/// `"AssertLevel"`) — measured working on macOS 26 in the spike.
@MainActor public final class AwakeController {
    private var idle: IOPMAssertionID?
    private var display: IOPMAssertionID?
    private var system: IOPMAssertionID?

    public init() {}

    /// Compact held-state for NSLog / acceptance greps: e.g. "idle+display", "none".
    public var heldSummary: String {
        var parts: [String] = []
        if idle != nil { parts.append("idle") }
        if display != nil { parts.append("display") }
        if system != nil { parts.append("system") }
        return parts.isEmpty ? "none" : parts.joined(separator: "+")
    }

    public func apply(_ spec: AssertionSpec?) {
        setAssertion(&idle, want: spec != nil,
                     type: "PreventUserIdleSystemSleep", name: "Tiler Keep Awake (idle)")
        setAssertion(&display, want: spec?.displayAwake ?? false,
                     type: "PreventUserIdleDisplaySleep", name: "Tiler Keep Awake (display)")
        setAssertion(&system, want: spec?.systemSleepBlock ?? false,
                     type: "PreventSystemSleep", name: "Tiler Keep Awake (system)")
        NSLog("Tiler: keep-awake %@", heldSummary)
    }

    private func setAssertion(_ id: inout IOPMAssertionID?, want: Bool,
                              type: String, name: String) {
        if want, id == nil {
            id = create(type: type, name: name)
        } else if !want, let held = id {
            IOPMAssertionRelease(held)
            id = nil
        }
    }

    private func create(type: String, name: String) -> IOPMAssertionID? {
        var id = IOPMAssertionID(0)
        let props: [String: Any] = [
            "AssertType": type,
            "AssertName": name,
            "AssertLevel": 255,
        ]
        guard IOPMAssertionCreateWithProperties(props as CFDictionary, &id)
            == kIOReturnSuccess else {
            NSLog("Tiler: power assertion FAILED: %@", type)
            return nil
        }
        return id
    }
}
