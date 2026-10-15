//
//  RaceMusicTests.swift
//  HunchTests
//
//  3.5 race music: when the race switches from the chill loop to kiai. The
//  audio engine itself is not tested here. The web has the same rule and the
//  same tests in wick-web/tests/music.test.ts.
//

import Testing
@testable import Hunch

struct RaceMusicTests {
    @Test func staysChillWhileNobodyIsHotAndTimeIsLeft() {
        #expect(!RaceMusic.wantsKiai(youBest: 0.2, oppBest: 0.3, remainingMs: 240_000))
    }

    @Test func kiaiWhenEitherPlayerReachesHot() {
        #expect(RaceMusic.wantsKiai(youBest: RaceMusic.kiaiWarmth, oppBest: 0, remainingMs: 240_000))
        #expect(RaceMusic.wantsKiai(youBest: 0, oppBest: 0.8, remainingMs: 240_000))
        #expect(!RaceMusic.wantsKiai(youBest: RaceMusic.kiaiWarmth - 0.01, oppBest: 0, remainingMs: 240_000))
    }

    @Test func kiaiInTheLastMinute() {
        #expect(RaceMusic.wantsKiai(youBest: 0, oppBest: 0, remainingMs: RaceMusic.kiaiRemainingMs))
        #expect(!RaceMusic.wantsKiai(youBest: 0, oppBest: 0, remainingMs: RaceMusic.kiaiRemainingMs + 1))
    }
}
