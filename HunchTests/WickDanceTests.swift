// SPDX-License-Identifier: MPL-2.0
//
//  WickDanceTests.swift
//  HunchTests
//
//  Wick's boiling shake and his dance to the race music. The web has the same
//  numbers and the same tests in wick-web/tests/wick.test.ts.
//

import Testing
@testable import Hunch

struct WickDanceTests {
    private func pulse(_ t: Double, riserAt: Double? = nil, kiaiAt: Double? = nil) -> RaceMusic.Pulse {
        RaceMusic.pulse(at: t, riserAt: riserAt, kiaiAt: kiaiAt)
    }

    @Test func boilingShakesHardButStaysReadable() {
        var most = 0.0
        for i in 0..<300 {
            let m = WickDance.boilingShake(t: Double(i) * 0.01, size: 72)
            most = max(most, (m.x * m.x + m.y * m.y).squareRoot())
            #expect(abs(m.rotation) <= 2.5)
        }
        #expect(most > 2.4)          // much more than the old 0.8 point vibrate
        #expect(most < 72 * 0.06)    // but he stays where he is
    }

    @Test func noMusicMeansNoDance() {
        #expect(WickDance.move(for: .none, size: 72) == .still)
    }

    @Test func danceLandsOnTheBeatAndIsInTheAirBetween() {
        let onBeat = WickDance.move(for: pulse(4.0), size: 100)
        let midBeat = WickDance.move(for: pulse(4.25), size: 100)
        #expect(abs(onBeat.y) < 1e-6)
        #expect(midBeat.y < -3)
        #expect(onBeat.scaleY < 1 && onBeat.scaleX > 1)
        #expect(midBeat.scaleY > 1 && midBeat.scaleX < 1)
    }

    @Test func danceStepsToAlternatingSidesAndGoesBiggerOnBeatOne() {
        let a = WickDance.move(for: pulse(4.0), size: 100)
        let b = WickDance.move(for: pulse(4.5), size: 100)
        #expect((a.x < 0) != (b.x < 0))
        let bar = WickDance.move(for: pulse(4.25), size: 100)
        let off = WickDance.move(for: pulse(4.75), size: 100)
        #expect(abs(bar.y) > abs(off.y))
    }

    @Test func danceBuildsWithEnergyAndTheDropIsABigSpin() {
        let chill = WickDance.move(for: pulse(4.25), size: 100)
        let kiai = WickDance.move(for: pulse(104.25, riserAt: 90, kiaiAt: 94), size: 100)
        #expect(abs(kiai.y) > abs(chill.y) * 1.5)
        let drop = WickDance.move(for: pulse(94.5, riserAt: 90, kiaiAt: 94), size: 100)
        #expect(drop.y < -30)
        #expect(drop.rotation > 90 && drop.rotation < 360)
        let later = WickDance.move(for: pulse(96.0, riserAt: 90, kiaiAt: 94), size: 100)
        #expect(abs(later.rotation) < 20)
    }
}
