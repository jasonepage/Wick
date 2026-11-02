//
//  KeeperSolveTests.swift
//  HunchTests
//
//  The solved sequence timing and the share card trail, mirrored from
//  wick-web/tests/wick.test.ts.
//

import Testing
@testable import Hunch

struct KeeperSolveTests {

    @Test func shockedThroughTheReleaseThenSlyAndNeverLeavesGreen() {
        #expect(KeeperSolve.face(0.05, reduceMotion: false) == .shocked)
        #expect(KeeperSolve.face(KeeperSolve.release - 0.01, reduceMotion: false) == .shocked)
        #expect(KeeperSolve.face(KeeperSolve.release + 0.01, reduceMotion: false) == .sly)
        #expect(KeeperSolve.face(KeeperSolve.done + 10, reduceMotion: false) == .sly)
        #expect(KeeperSolve.face(1.0, reduceMotion: false, firstGuess: true) == .shocked)
        #expect(KeeperSolve.face(0.2, reduceMotion: true) == .shocked)
        #expect(KeeperSolve.face(0.6, reduceMotion: true) == .sly)
        // The color is the celebrating body color for every face: solved green.
        let green = KeeperRGB.body(for: .celebrating)
        #expect(green.g > green.r && green.g > green.b)
    }

    @Test func oneSquashOneReboundOneRing() {
        #expect(KeeperSolve.scale(0.1) == KeeperSolve.Scale(sx: 1, sy: 1))
        var maxSy = 0.0, minSy = 9.0
        var e = 0.42
        while e < 0.82 {
            let sc = KeeperSolve.scale(e)
            maxSy = max(maxSy, sc.sy); minSy = min(minSy, sc.sy)
            e += 0.01
        }
        #expect(abs(maxSy - 1.08) < 0.02)
        #expect(minSy < 0.92)
        #expect(KeeperSolve.scale(0.9) == KeeperSolve.Scale(sx: 1, sy: 1))
        #expect(KeeperSolve.ring(0.1, reduceMotion: false) == nil)
        let r = KeeperSolve.ring(0.5, reduceMotion: false)
        #expect((r?.opacity ?? 0) > 0 && (r?.r ?? 0) > 0.5)
        #expect(KeeperSolve.ring(0.9, reduceMotion: false) == nil)
        #expect(KeeperSolve.ring(0.5, reduceMotion: true) != nil)
    }

    @Test func animatorRunsTheSequenceOnceAndHoldsGreenSly() {
        let a = KeeperFaceAnimator()
        _ = a.frame(t: 0, mood: .warm, race: false, reduceMotion: false)
        _ = a.frame(t: 1, mood: .celebrating, race: false, reduceMotion: false)
        #expect(a.solveElapsed(at: 1.1) != nil)
        let early = a.frame(t: 1.3, mood: .celebrating, race: false, reduceMotion: false)
        #expect(early.name == .shocked)
        #expect(!a.takeSolveDone(at: 1.3, reduceMotion: false))
        let late = a.frame(t: 1 + KeeperSolve.done + 0.5, mood: .celebrating, race: false, reduceMotion: false)
        #expect(late.name == .sly)
        #expect(a.takeSolveDone(at: 1 + KeeperSolve.done + 0.5, reduceMotion: false))
        #expect(!a.takeSolveDone(at: 1 + KeeperSolve.done + 1, reduceMotion: false), "fires once")
        // A Wick born solved shows the final pose and never fires done.
        let b = KeeperFaceAnimator()
        let born = b.frame(t: 0, mood: .celebrating, race: false, reduceMotion: false)
        #expect(born.name == .sly)
        #expect(!b.takeSolveDone(at: 5, reduceMotion: false))
    }

    @Test func shareCardTrailEndsGreenWithARing() {
        let many: [Double] = [3, 5, 9, 12, 20, 25, 33, 40, 48, 55, 61, 70, 100]
        let trail = HeatTrailNode.trail(many)
        #expect(trail.count == 8)
        #expect(trail.first?.score == 3)
        #expect(trail.last?.score == 100)
        #expect(trail.last?.ring == true)
        #expect((trail.last?.radius ?? 0) > (trail.first?.radius ?? 0))
        #expect(HeatTrailNode.trail([10, 20, 30]).count == 3)
    }
}
