import Foundation

/// Accessibility-permission lifecycle (permissions spec): polls only while the
/// permission is missing, stops when granted, resumes when an action failure
/// reveals revocation. The trust check is injected for testability.
@MainActor
public final class PermissionMonitor {
    public private(set) var trusted: Bool
    var isPolling: Bool { timer != nil } // internal for tests

    private let pollInterval: TimeInterval
    private let check: () -> Bool
    private let onChange: (Bool) -> Void
    private var timer: Timer?

    public init(pollInterval: TimeInterval,
                check: @escaping () -> Bool,
                onChange: @escaping (Bool) -> Void) {
        self.pollInterval = pollInterval
        self.check = check
        self.onChange = onChange
        self.trusted = check()
    }

    public func start() {
        onChange(trusted)
        if !trusted { schedule() }
    }

    /// Call when an AX action fails — detects revocation without background polling.
    public func noteActionFailed() {
        evaluate()
    }

    /// Timer body; exposed internally so tests can drive polls deterministically.
    func tick() {
        evaluate()
    }

    private func evaluate() {
        let now = check()
        if now != trusted {
            trusted = now
            onChange(now)
        }
        if now {
            timer?.invalidate()
            timer = nil
        } else if timer == nil {
            schedule()
        }
    }

    private func schedule() {
        let t = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }
}
