// SPDX-License-Identifier: MPL-2.0
//
//  WickDanceTests.swift
//  HunchTests
//
//  Wick's dance to the race music (3.8 phrases). The web has the same checks
//  in wick-web/tests/wickmotion.test.ts.
//

import Testing
@testable import Hunch

@MainActor
struct WickDanceTests {
    private func pulse(_ t: Double, riserAt: Double? = nil, kiaiAt: Double? = nil) -> RaceMusic.Pulse {
        RaceMusic.pulse(at: t, riserAt: riserAt, kiaiAt: kiaiAt)
    }

    @Test func oldBoilingShakeStillAvailableForReplay() {
        var most = 0.0
        for i in 0..<300 {
            let m = WickDance.boilingShake(t: Double(i) * 0.01, size: 72)
            most = max(most, (m.x * m.x + m.y * m.y).squareRoot())
            #expect(abs(m.rotation) <= 2.5)
        }
        #expect(most > 2.4)
    }

    @Test func noMusicMeansNoDance() {
        #expect(WickDance.move(for: .none, size: 72) == .still)
    }

    @Test func noSpinAnywhereIncludingTheDrop() {
        for style in WickDance.Style.allCases {
            var t = 0.0
            while t < 8 {
                #expect(abs(WickDance.move(for: pulse(t), size: 100, style: style).rotation) <= 12)
                t += 0.01
            }
        }
        var t = 240.0
        while t < 242 {
            #expect(abs(WickDance.move(for: pulse(t, riserAt: 236, kiaiAt: 240), size: 100).rotation) <= 12)
            t += 0.01
        }
    }

    @Test func theDropLaunchesAndLands() {
        let up = WickDance.move(for: pulse(240.3, riserAt: 236, kiaiAt: 240), size: 100)
        let land = WickDance.move(for: pulse(240.5, riserAt: 236, kiaiAt: 240), size: 100)
        #expect(up.y <= -20)
        #expect(land.scaleY <= 0.9)
    }

    @Test func riserAnticipatesTheDropWithAGroundedCrouch() {
        let p = RaceMusic.Pulse(beat: 0, down: 0, energy: 0.96, flash: 0, time: 4)
        let crouch = WickDance.move(for: p, size: 100, style: .swagger)
        #expect(crouch.y > 0)
        #expect(crouch.scaleX > 1 && crouch.scaleY < 1)
    }

    @Test func swaggerPlantsOnBeatsFourAndEight() {
        for beat in [3.0, 7.0] {
            let a = WickDance.move(for: pulse((beat + 0.02) * 0.5), size: 100, style: .swagger)
            let b = WickDance.move(for: pulse((beat + 0.4) * 0.5), size: 100, style: .swagger)
            #expect(abs(b.x - a.x) < 2 && abs(b.rotation - a.rotation) < 2)
        }
    }

    @Test func groovesStaysLowAndSmall() {
        var t = 0.0
        while t < 4 {
            let m = WickDance.move(for: pulse(t), size: 100, style: .groove)
            #expect(m.y >= -5)
            #expect(abs(m.rotation) <= 5.0001)
            t += 0.005
        }
    }
}
