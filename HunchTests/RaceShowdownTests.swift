// SPDX-License-Identifier: MPL-2.0
//
//  RaceShowdownTests.swift
//  HunchTests
//
//  The 3.8 Race Showdown state (RaceShowdown.swift). The same cases run on
//  the web in wick-web/tests/raceshow.test.ts, so both clients agree.
//

import Foundation
import Testing
@testable import Hunch

@MainActor
struct RaceShowdownTests {
    typealias R = RaceShowdown

    private func inp(_ now: Double, you: Double = 0, them: Double = 0, youSolved: Bool = false,
                     themSolved: Bool = false, remaining: Int = 300_000, result: Bool = false) -> R.Input {
        R.Input(now: now, youBest: you, themBest: them, youSolved: youSolved, themSolved: themSolved,
                remainingMs: remaining, result: result)
    }

    @Test func bandsFollowTheExistingWarmthThresholds() {
        let cases: [(Double, R.Band)] = [
            (0, .searching), (0.17, .searching), (0.18, .trail), (0.29, .trail), (0.3, .heating),
            (0.44, .heating), (0.45, .close), (0.59, .close), (0.6, .danger), (0.99, .danger), (1, .solved),
        ]
        for (w, b) in cases { #expect(R.band(w) == b, "warmth \(w)") }
        #expect(R.band(0.2, solved: true) == .solved)
    }

    @Test func bandPaintScoresLandInTheirOwnBandAndMood() {
        let mood: [R.Band: KeeperMood] = [
            .searching: .freezing, .trail: .cold, .heating: .warm, .close: .hot, .danger: .boiling, .solved: .celebrating,
        ]
        for b in R.Band.allCases {
            #expect(R.band(b.paintScore / 100) == b)
            #expect(KeeperMood.forScore(b.paintScore) == mood[b])
        }
    }

    @Test func leadUsesBestWarmthNotTheLatestGuess() {
        #expect(R.lead(you: 0.5, them: 0.45) == .you)
        var show = R.Show()
        #expect(show.update(inp(0, you: 0.5, them: 0.45)).lead == .you)
        #expect(R.lead(you: 0.2, them: 0.45) == .them)
    }

    @Test func equalWholeNumberScoresTie() {
        #expect(R.lead(you: 0.42, them: 0.42) == .tied)
        #expect(R.lead(you: 0.42000001, them: 0.41999999) == .tied)
        #expect(R.lead(you: 0.43, them: 0.42) == .you)
        #expect(R.lead(you: 0, them: 0) == .tied)
    }

    @Test func leadChangeShowsOneEventThenWaitsOutTheGap() {
        var s = R.Show()
        _ = s.update(inp(0))
        let a = s.update(inp(1000, you: 0.3))
        #expect(a.event == .youHotter)
        #expect(a.accent == .you)
        #expect(a.leadChanged)
        let b = s.update(inp(1500, you: 0.3, them: 0.5))
        #expect(b.event == .youHotter)
        #expect(b.accent == .them)
        #expect(s.update(inp(1000 + R.momentumShowMs, you: 0.3, them: 0.5)).event == nil)
        #expect(s.update(inp(2999, you: 0.3, them: 0.5)).event == nil)
        let e = s.update(inp(1000 + R.momentumGapMs, you: 0.3, them: 0.5))
        #expect(e.event == .closingIn)
        #expect(e.leadChanges == 1)
    }

    @Test func aDelayedLeadEventThatIsNoLongerTrueIsDropped() {
        var s = R.Show()
        _ = s.update(inp(0))
        _ = s.update(inp(100, you: 0.3))
        _ = s.update(inp(500, you: 0.3, them: 0.3))
        #expect(s.update(inp(2200, you: 0.4, them: 0.3)).event == .youHotter)

        var g = R.Show()
        _ = g.update(inp(0))
        _ = g.update(inp(100, you: 0.3))
        _ = g.update(inp(500, you: 0.3, them: 0.3))
        _ = g.update(inp(900, you: 0.35, them: 0.3))
        let h = g.update(inp(2200, you: 0.35, them: 0.35))
        #expect(h.event == .deadHeat)
        #expect(h.eventAt == 2200)
    }

    @Test func solveAndResultOutrankEveryEvent() {
        var s = R.Show()
        _ = s.update(inp(0))
        #expect(s.update(inp(100, you: 0.3)).event == .youHotter)
        let f = s.update(inp(200, you: 1, youSolved: true))
        #expect(f.event == nil)
        #expect(f.voice.isEmpty)
        let g = s.update(inp(5000, you: 1, youSolved: true, remaining: 10_000, result: true))
        #expect(g.event == nil)
        #expect(g.voice.isEmpty)
    }

    @Test func suddenHeatFiresOnceWhenBothReachTheTopBand() {
        var s = R.Show()
        _ = s.update(inp(0))
        _ = s.update(inp(100, you: 0.6, them: 0.59))
        #expect(s.update(inp(3000, you: 0.6, them: 0.6)).event == .deadHeat)
        #expect(s.update(inp(5000, you: 0.6, them: 0.6)).event == .suddenHeat)
        #expect(s.update(inp(9000, you: 0.7, them: 0.6)).event != .suddenHeat)
    }

    @Test func phasesSwitchOnTheServersRemainingTime() {
        #expect(R.phase(remainingMs: 300_000, hasResult: false) == .opening)
        #expect(R.phase(remainingMs: 60_001, hasResult: false) == .opening)
        #expect(R.phase(remainingMs: 60_000, hasResult: false) == .finalMinute)
        #expect(R.phase(remainingMs: 15_001, hasResult: false) == .finalMinute)
        #expect(R.phase(remainingMs: 15_000, hasResult: false) == .final15)
        #expect(R.phase(remainingMs: 1, hasResult: false) == .final15)
        #expect(R.phase(remainingMs: 0, hasResult: false) == .expired)
        #expect(R.phase(remainingMs: 0, hasResult: true) == .result)
        #expect(R.dance(.opening) == .groove)
        #expect(R.dance(.finalMinute) == .swagger)
        #expect(R.dance(.final15) == .hype)
        #expect(R.dance(.expired) == nil)
    }

    @Test func finalMinuteAndFifteenSecondsAnnounceOnce() {
        var s = R.Show()
        _ = s.update(inp(0, remaining: 61_000))
        let a = s.update(inp(1000, remaining: 60_000))
        #expect(a.event == .finalMinute)
        #expect(a.voice == ["raceFinalMinute"])
        #expect(s.update(inp(4000, remaining: 57_000)).voice.isEmpty)
        let b = s.update(inp(46_000, remaining: 15_000))
        #expect(b.event == .final15)
        #expect(b.voice == ["race15Seconds"])
        let c = s.update(inp(50_000, remaining: 11_000))
        #expect(c.event == nil)
        #expect(c.voice.isEmpty)
    }

    @Test func aMatchResumedInTheLast15SecondsSkipsFinalMinute() {
        var s = R.Show()
        let f = s.update(inp(0, remaining: 12_000))
        #expect(f.event == .final15)
        #expect(f.voice == ["race15Seconds"])
    }

    @Test func voiceOverHearsALeadChangeAtMostEveryFiveSeconds() {
        var s = R.Show()
        _ = s.update(inp(0))
        #expect(s.update(inp(1000, you: 0.3)).voice == ["raceYouLead"])
        #expect(s.update(inp(2000, you: 0.3, them: 0.4)).voice.isEmpty)
        #expect(s.update(inp(5999, you: 0.3, them: 0.4)).voice.isEmpty)
        #expect(s.update(inp(6000, you: 0.3, them: 0.4)).voice == ["raceTheyLead"])
        _ = s.update(inp(7000, you: 0.5, them: 0.4))
        #expect(s.update(inp(11_500, you: 0.5, them: 0.5)).voice == ["raceTied"])
    }

    @Test func timeoutNeverDeclaresAWinnerLocally() {
        #expect(R.phase(remainingMs: 0, hasResult: false) == .expired)
        var s = R.Show()
        _ = s.update(inp(0, you: 0.5, them: 0.4, remaining: 1000))
        let f = s.update(inp(1000, you: 0.5, them: 0.4, remaining: 0))
        #expect(f.lead == .you)
        #expect(f.event == nil)
        let r = R.recap(reason: "timeout", winner: "me", draw: false, players: [
            .init(id: "me", solvedAtMs: nil, bestWarmth: 0.5, guessCount: 9),
            .init(id: "op", solvedAtMs: nil, bestWarmth: 0.4, guessCount: 7),
        ], myId: "me")
        #expect(!r.youGreen)
        #expect(!r.themGreen)
        #expect(r.finishMs == nil)
        #expect(r.headline == .won)
    }

    @Test func aLocalSolveStaysGreenAndALossMakesOnlyTheOpponentGreen() {
        let win = R.recap(reason: "solved", winner: "me", draw: false, players: [
            .init(id: "me", solvedAtMs: 84_200, bestWarmth: 1, guessCount: 12),
            .init(id: "op", solvedAtMs: nil, bestWarmth: 0.62, guessCount: 15),
        ], myId: "me")
        #expect(win.outcome == .win)
        #expect(win.headline == .turnedGreen)
        #expect(win.youGreen && !win.themGreen)
        #expect(win.youBand == .solved)
        #expect(win.themBand == .danger)
        #expect(win.finishMs == 84_200)

        let loss = R.recap(reason: "solved", winner: "op", draw: false, players: [
            .init(id: "me", solvedAtMs: nil, bestWarmth: 0.48, guessCount: 10),
            .init(id: "op", solvedAtMs: 70_000, bestWarmth: 1, guessCount: 9),
        ], myId: "me")
        #expect(loss.outcome == .loss)
        #expect(loss.headline == .gotThereFirst)
        #expect(!loss.youGreen && loss.themGreen)
        #expect(loss.youBand == .close)
        #expect(loss.finishMs == 70_000)

        let draw = R.recap(reason: "timeout", winner: nil, draw: true, players: [
            .init(id: "me", solvedAtMs: nil, bestWarmth: 0.4, guessCount: 4),
            .init(id: "op", solvedAtMs: nil, bestWarmth: 0.4, guessCount: 5),
        ], myId: "me")
        #expect(draw.outcome == .draw)
        #expect(draw.headline == .draw)
        #expect(!draw.youGreen && !draw.themGreen)

        #expect(R.recap(reason: "void", winner: nil, draw: false, players: [], myId: "me").outcome == .void)
    }

    @Test func heatTrailsCollapseRepeatsAndCapAtEight() {
        var r = R.TrailRecorder()
        r.push(.you, .searching, guessCount: 0)
        #expect(r.you.isEmpty)
        for b in [R.Band.searching, .searching, .trail, .trail, .heating, .danger, .danger, .solved] {
            r.push(.you, b, guessCount: 1)
        }
        #expect(r.you == [.searching, .trail, .heating, .danger, .solved])
        let long: [R.Band] = [.searching, .trail, .searching, .trail, .heating, .trail, .heating, .close, .heating, .danger, .solved]
        let capped = R.capTrail(long)
        #expect(capped.count == 8)
        #expect(capped.first == .searching)
        #expect(capped.last == .solved)
        #expect(R.capTrail([.trail, .close]) == [.trail, .close])
    }

    @Test func theOpponentSeatOnlyCarriesPublicProgress() {
        // OpponentView has no word or question fields to pass, and the seat is
        // built from four public numbers only.
        let view = OpponentView(kind: .human, guessCount: 11, bestWarmth: 0.47, solved: false, connected: true)
        let seat = R.opponentSeat(bestWarmth: view.bestWarmth, guessCount: view.guessCount,
                                  solved: view.solved, connected: view.connected)
        #expect(seat.band == .close)
        #expect(seat.paintScore == R.Band.close.paintScore)
        #expect(Mirror(reflecting: seat).children.compactMap(\.label).sorted()
                == ["band", "connected", "guessCount", "paintScore", "solved"])
        #expect(!String(describing: seat).contains("47"))
        #expect(R.opponentSeat(bestWarmth: 0, guessCount: 0, solved: false, connected: true).paintScore == nil)
    }

    @Test func rematchCannotBeSubmittedTwice() {
        var g = R.RematchGate()
        #expect(g.request())
        #expect(!g.request())
        #expect(g.requested)
        g.reset()
        #expect(g.request())
    }

    @Test func faceOffCounts321Guess() {
        #expect(R.faceOffStep(0) == 3)
        #expect(R.faceOffStep(999) == 3)
        #expect(R.faceOffStep(1000) == 2)
        #expect(R.faceOffStep(2999) == 1)
        #expect(R.faceOffStep(3000) == 0)
        #expect(R.faceOffStep(3699) == 0)
        #expect(R.faceOffStep(3700) == nil)
        #expect(R.faceOffEligible(400))
        #expect(!R.faceOffEligible(R.faceOffMs))
    }

    @Test func faceOffGlancesLeansAndPulses() {
        let you = R.faceOffStance(800, side: 1, rm: false), them = R.faceOffStance(800, side: -1, rm: false)
        #expect(you.gx > 0 && them.gx < 0)
        #expect(you.tip > 0 && them.tip < 0)
        let hit = R.faceOffStance(1110, side: 1, rm: false)
        #expect(hit.sy < 0 && hit.sx > 0)
        #expect(R.faceOffStance(3300, side: 1, rm: false) == R.Stance())
        // Same numbers as the web (raceshow.ts).
        #expect(abs(you.gx - 7) < 1e-9)
        #expect(abs(you.tip - 0.22) < 1e-9)
        #expect(abs(hit.sy - (-0.045)) < 1e-9)
    }

    @Test func reducedMotionHasNoTranslationRotationShakeOrJump() {
        for ms in stride(from: 0.0, through: 4000, by: 10) {
            let s = R.faceOffStance(ms, side: 1, rm: true)
            #expect(s.tip == 0 && s.sx == 0 && s.sy == 0)
            #expect(Mirror(reflecting: s).children.compactMap(\.label).sorted() == ["gx", "sx", "sy", "tip"])
        }
        for ms in stride(from: 0, through: 16_000, by: 7) { #expect(R.timerPulse(ms, rm: true).scale == 1) }
        #expect(R.timerPulse(14_990, rm: true).opacity < 1)
    }

    @Test func finalFifteenPulsesOncePerSecondWithBigNumeralsFromFive() {
        #expect(R.timerPulse(20_000, rm: false).scale == 1)
        #expect(R.timerPulse(14_000, rm: false).scale > 1.05)
        #expect(R.timerPulse(14_500, rm: false).scale == 1)
        #expect(R.finalCount(5_001) == nil)
        #expect(R.finalCount(5_000) == 5)
        #expect(R.finalCount(4_001) == 5)
        #expect(R.finalCount(1) == 1)
        #expect(R.finalCount(0) == nil)
    }

    @Test func theClockCarriesForwardAndReadsLikeTheServer() {
        let fix = R.ClockFix(elapsedMs: 10_000, remainingMs: 290_000, at: 50_000)
        let a = R.clock(fix, now: 50_400), b = R.clock(fix, now: 49_000)
        #expect(a.elapsedMs == 10_400 && a.remainingMs == 289_600)
        #expect(b.elapsedMs == 10_000 && b.remainingMs == 290_000)
        #expect(R.clock(fix, now: 400_000).remainingMs == 0)
        #expect(R.fmtClock(300_000) == "5:00")
        #expect(R.fmtClock(134_001) == "2:15")
        #expect(R.fmtClock(134_000) == "2:14")
        #expect(R.fmtClock(0) == "0:00")
        #expect(R.fmtElapsed(84_999) == "1:24")
        #expect(R.fmtElapsed(0) == "0:00")
    }

    @Test func everyLanguageTableHasTheRaceKeys() {
        func ph(_ s: String) -> [String] {
            let re = try! NSRegularExpression(pattern: "%@|%d")
            return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { (s as NSString).substring(with: $0.range) }.sorted()
        }
        for lang in GameLanguage.allCases {
            let table = Loc.tables[lang.rawValue] ?? [:]
            for k in R.keys {
                let v = table[k] ?? ""
                #expect(!v.isEmpty, "\(lang.rawValue) is missing \(k)")
                #expect(ph(v) == ph(Loc.en[k] ?? ""), "\(lang.rawValue) \(k) placeholders")
                #expect(!v.contains("\u{2014}"), "\(lang.rawValue) \(k) has an em dash")
            }
        }
    }
}
