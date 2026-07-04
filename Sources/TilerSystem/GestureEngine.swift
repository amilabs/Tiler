import CoreGraphics
import Foundation
import TilerCore

/// Owns the recognizer and the optional trace recorder.
/// @unchecked Sendable: recognizer/recorder state is confined to the TouchStream
/// serial queue (`handle(_:)` only runs there); cross-thread inputs (staged
/// tunables, frame tap) are lock-protected.
public final class GestureEngine: @unchecked Sendable {
    private let recognizer: GestureRecognizer
    private let recorder: TraceRecorder?
    private let onAction: @Sendable (GestureAction) -> Void

    private let lock = NSLock()
    private var stagedTunables: Tunables?
    private var frameTap: (@Sendable (TouchFrame) -> Void)?

    public init(recorder: TraceRecorder?,
                tunables: Tunables = .default,
                onAction: @escaping @Sendable (GestureAction) -> Void) {
        recognizer = GestureRecognizer(tunables: tunables)
        self.recorder = recorder
        self.onAction = onAction
    }

    /// Stage new tunables from any thread; the recognizer picks them up on the
    /// touch queue (and itself applies them only from a clean idle pad).
    public func stageTunables(_ tunables: Tunables) {
        lock.lock()
        stagedTunables = tunables
        lock.unlock()
    }

    /// Mirror every incoming frame to an observer (calibration UI). Set nil to stop.
    public func setFrameTap(_ tap: (@Sendable (TouchFrame) -> Void)?) {
        lock.lock()
        frameTap = tap
        lock.unlock()
    }

    /// Runs on the TouchStream serial queue.
    public func handle(_ frame: TouchFrame) {
        lock.lock()
        let staged = stagedTunables
        stagedTunables = nil
        let tap = frameTap
        lock.unlock()

        if let staged {
            recognizer.updateTunables(staged)
        }
        tap?(frame)

        recorder?.append(frame)
        let cmdHeld = CGEventSource.flagsState(.hidSystemState).contains(.maskCommand)
        if let action = recognizer.process(frame, cmdHeld: cmdHeld) {
            onAction(action)
        }
    }
}
