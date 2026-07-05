import Foundation
import Testing
@testable import TilerCore

// Shift modifier (add-thirds-lock-help): ⇧ at confirmation turns left/right into
// third-width actions; combines with ⌘; ignored for up.
@Suite("Shift modifier") struct ShiftModifierTests {

    @Test func shiftLeftSwipeEmitsThirdWidth() {
        var sim = Sim()
        sim.performValidSwipe((dx: -0.15, dy: 0), shift: true)
        #expect(sim.actions == [GestureAction(direction: .left, nextDisplay: false, thirdWidth: true)])
    }

    @Test func shiftRightSwipeEmitsThirdWidth() {
        var sim = Sim()
        sim.performValidSwipe((dx: 0.15, dy: 0), shift: true)
        #expect(sim.actions == [GestureAction(direction: .right, nextDisplay: false, thirdWidth: true)])
    }

    @Test func shiftAndCmdCombine() {
        var sim = Sim()
        sim.performValidSwipe((dx: -0.15, dy: 0), cmd: true, shift: true)
        #expect(sim.actions == [GestureAction(direction: .left, nextDisplay: true, thirdWidth: true)])
    }

    @Test func plainSwipesStayHalfWidth() {
        var sim = Sim()
        sim.performValidSwipe((dx: 0.15, dy: 0))
        #expect(sim.actions == [GestureAction(direction: .right, nextDisplay: false, thirdWidth: false)])
    }

    @Test func shiftUpSwipeEmitsThirdWidthCenterThird() {
        var sim = Sim()
        sim.performValidSwipe((dx: 0, dy: 0.15), shift: true)
        #expect(sim.actions == [GestureAction(direction: .up, nextDisplay: false, thirdWidth: true)])
    }

    @Test func cmdUpStillEmitsNothingEvenWithShift() {
        var sim = Sim()
        sim.performValidSwipe((dx: 0, dy: 0.15), cmd: true, shift: true)
        #expect(sim.actions.isEmpty)
    }

    // Old golden fixtures predate thirdWidth: decoding must default it to false.
    @Test func decodingWithoutThirdWidthDefaultsFalse() throws {
        let json = Data(#"{"direction":"left","nextDisplay":false}"#.utf8)
        let action = try JSONDecoder().decode(GestureAction.self, from: json)
        #expect(action == GestureAction(direction: .left, nextDisplay: false, thirdWidth: false))
    }
}
