import Foundation
import Testing
@testable import TilerCore

/// Frame-sequence simulator: drives a GestureRecognizer at 120 Hz and collects actions.
struct Sim {
    var recognizer: GestureRecognizer
    var t: Double
    let dt = 1.0 / 120.0
    var actions: [GestureAction] = []

    init(tunables: Tunables = .default, startTime: Double = 10.0) {
        recognizer = GestureRecognizer(tunables: tunables)
        t = startTime
    }

    mutating func feed(_ contacts: [Contact], cmd: Bool = false) {
        if let a = recognizer.process(TouchFrame(timestamp: t, contacts: contacts), cmdHeld: cmd) {
            actions.append(a)
        }
        t += dt
    }

    mutating func hold(_ contacts: [Contact], frames: Int, cmd: Bool = false) {
        for _ in 0..<frames { feed(contacts, cmd: cmd) }
    }

    /// Move `n` fingers' centroid from `start` by `delta` over `frames` frames.
    /// `extra` contacts (palm, stale…) are appended to every frame.
    mutating func move(_ n: Int, from start: (x: Double, y: Double),
                       by delta: (dx: Double, dy: Double), frames: Int,
                       cmd: Bool = false, size: Double = 0.5,
                       idBase: Int32 = 1, extra: [Contact] = []) {
        for i in 1...frames {
            let f = Double(i) / Double(frames)
            let contacts = fingers(n, at: start.x + delta.dx * f, start.y + delta.dy * f,
                                   size: size, idBase: idBase)
            feed(contacts + extra, cmd: cmd)
        }
    }

    /// One empty frame (all lifted), then stream silence for `gap` seconds.
    mutating func liftAll(thenGap gap: Double = 0.5) {
        feed([])
        t += gap
    }

    /// Canonical valid 3-finger swipe: arm stationary, move, lift.
    /// delta of ±0.15 with 18 move frames comfortably exceeds all confirm thresholds.
    mutating func performValidSwipe(_ delta: (dx: Double, dy: Double), cmd: Bool = false) {
        hold(fingers(3, at: 0.5, 0.5), frames: 5, cmd: cmd)
        move(3, from: (0.5, 0.5), by: delta, frames: 18, cmd: cmd)
        liftAll()
    }
}

/// `n` finger contacts spread horizontally around centroid (cx, cy).
func fingers(_ n: Int, at cx: Double, _ cy: Double, size: Double = 0.5,
             state: ContactState = .touching, spread: Double = 0.06,
             idBase: Int32 = 1) -> [Contact] {
    (0..<n).map { i in
        Contact(deviceID: 1, fingerID: idBase + Int32(i), state: state, size: size,
                x: cx + spread * (Double(i) - Double(n - 1) / 2.0), y: cy)
    }
}

func palm(at x: Double = 0.8, _ y: Double = 0.15, id: Int32 = 90) -> Contact {
    Contact(deviceID: 1, fingerID: id, state: .touching, size: 3.0, x: x, y: y)
}

/// Displacement vector of magnitude `r` at `degrees` measured from the +x axis.
func vector(degrees: Double, magnitude r: Double) -> (dx: Double, dy: Double) {
    let rad = degrees * .pi / 180
    return (r * cos(rad), r * sin(rad))
}
