//
//  RaceMusicTests.swift
//  HunchTests
//
//  3.5 race music: when the riser into kiai starts, and the beat pulse the
//  screen follows. The audio engine itself is not tested here. The web has the
//  same rules and the same tests in wick-web/tests/music.test.ts.
//

import Testing
@testable import Hunch

struct RaceMusicTests {
    @Test func staysChillUntilTheLastMinuteAndFiveSeconds() {
        #expect(!RaceMusic.wantsKiai(remainingMs: 240_000))
        #expect(!RaceMusic.wantsKiai(remainingMs: RaceMusic.kiaiAtMs + 1))
    }

    @Test func riserStartsAt105SoKiaiLandsNear100() {
        #expect(RaceMusic.wantsKiai(remainingMs: RaceMusic.kiaiAtMs))
        #expect(RaceMusic.wantsKiai(remainingMs: 30_000))
    }

    @Test func beatPeaksOnEachBeatAndDownbeatOnlyOnBeatOne() {
        let onBar = RaceMusic.pulse(at: 4.0, riserAt: nil, kiaiAt: nil)
        #expect(onBar.beat > 0.99 && onBar.down > 0.99)
        let beat2 = RaceMusic.pulse(at: 4.5, riserAt: nil, kiaiAt: nil)
        #expect(beat2.beat > 0.99 && beat2.down == 0)
        #expect(RaceMusic.pulse(at: 4.4, riserAt: nil, kiaiAt: nil).beat < 0.05)
    }

    @Test func energyRisesThroughTheRiserAndFlashesOnKiai() {
        #expect(RaceMusic.pulse(at: 10, riserAt: 20, kiaiAt: 24).energy == 0)
        let mid = RaceMusic.pulse(at: 22, riserAt: 20, kiaiAt: 24)
        #expect(mid.energy > 0 && mid.energy < 1 && mid.flash == 0)
        let drop = RaceMusic.pulse(at: 24, riserAt: 20, kiaiAt: 24)
        #expect(drop.energy == 1 && drop.flash > 0.99)
        #expect(RaceMusic.pulse(at: 26, riserAt: 20, kiaiAt: 24).flash < 0.01)
    }
}
