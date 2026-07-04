import CoreGraphics
import Foundation
import TilerCore

/// Owns the recognizer and the optional trace recorder.
/// @unchecked Sendable: all mutable state is confined to the TouchStream serial queue —
/// `handle(_:)` is only ever called from there.
final class GestureEngine: @unchecked Sendable {
    private let recognizer = GestureRecognizer()
    private let recorder: TraceRecorder?
    private let onAction: @Sendable (GestureAction) -> Void

    init(recorder: TraceRecorder?, onAction: @escaping @Sendable (GestureAction) -> Void) {
        self.recorder = recorder
        self.onAction = onAction
    }

    /// Runs on the TouchStream serial queue.
    func handle(_ frame: TouchFrame) {
        recorder?.append(frame)
        let cmdHeld = CGEventSource.flagsState(.hidSystemState).contains(.maskCommand)
        if let action = recognizer.process(frame, cmdHeld: cmdHeld) {
            onAction(action)
        }
    }
}
