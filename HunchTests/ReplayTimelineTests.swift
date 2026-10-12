//
//  ReplayTimelineTests.swift
//  HunchTests
//
//  Solve Replay (3.4): the pure logic that turns a round into beats. The
//  video render itself is not tested here; it only draws what these
//  functions return.
//

import CoreGraphics
import Foundation
import Testing
@testable import Hunch

// MARK: - Helpers

private func g(_ rank: Int) -> ReplayEvent { .guess(rank: rank) }
private let yes = ReplayEvent.question(ReplayVerdict(tone: .yes, label: "Yes"))
private let no = ReplayEvent.question(ReplayVerdict(tone: .no, label: "No"))

/// Pacing with stretching turned off, so durations are the raw values.
private var noStretch: ReplayPacing {
    var p = ReplayPacing.standard
    p.minTotal = 0
    return p
}

/// Every slot placed by a beat, in order.
private func placedSlots(_ t: ReplayTimeline) -> [Int] {
    var out: [Int] = []
    for beat in t.beats {
        if case .place(let slots) = beat.kind { out += slots }
    }
    return out
}

/// The kinds of beat, flattened to short labels for easy comparison.
private func shape(_ t: ReplayTimeline) -> [String] {
    t.beats.map { beat in
        switch beat.kind {
        case .intro:              return "intro"
        case .place(let s):       return s.count == 1 ? "tile\(s[0])" : "burst\(s.count)"
        case .keeper(let v):      return "keeper\(v.count)"
        case .finale(.solved):    return "solved"
        case .finale(.revealed):  return "revealed"
        case .endCard:            return "end"
        }
    }
}

/// A long, messy round: a slow climb with lots of dips and questions.
private func longRound(guesses: Int, questionEvery: Int) -> [ReplayEvent] {
    var events: [ReplayEvent] = []
    var best = 6000
    for i in 0..<guesses {
        if i % 4 == 0 {
            best = max(2, Int(Double(best) * 0.82))
            events.append(g(best))
        } else {
            events.append(g(best + 500 + i))
        }
        if questionEvery > 0, i % questionEvery == 0 { events.append(yes) }
    }
    return events + [g(1)]
}

// MARK: - Heat bands

struct ReplayBandTests {
    @Test func thresholdsMatchTheGame() {
        #expect(ReplayBand(rank: 1) == .solved)
        #expect(ReplayBand(rank: 2) == .boiling)
        #expect(ReplayBand(rank: 25) == .boiling)
        #expect(ReplayBand(rank: 26) == .hot)
        #expect(ReplayBand(rank: 100) == .hot)
        #expect(ReplayBand(rank: 101) == .warm)
        #expect(ReplayBand(rank: 400) == .warm)
        #expect(ReplayBand(rank: 401) == .cool)
        #expect(ReplayBand(rank: 1200) == .cool)
        #expect(ReplayBand(rank: 1201) == .cold)
        #expect(ReplayBand(rank: 0) == .cold)
    }
}

// MARK: - Timeline

struct ReplayTimelineTests {

    @Test func everyGuessGetsOneTileInPlayOrder() throws {
        let t = try #require(ReplayTimeline.build(events: [g(3000), g(800), g(900), g(40), g(1)],
                                                  outcome: .solved))
        #expect(t.tiles.map(\.rank) == [3000, 800, 900, 40, 1])
        #expect(t.tiles.map(\.slot) == [0, 1, 2, 3, 4])
        #expect(t.tiles.map(\.guessNumber) == [1, 2, 3, 4, 5])
        #expect(t.tiles.last?.kind == .answer)
        #expect(t.totalGuesses == 5)
        // The answer is placed by the finale, not by a place beat.
        #expect(placedSlots(t) == [0, 1, 2, 3])
    }

    @Test func emphasisMarksDipsNewBestsAndBigJumps() throws {
        // cold, dip, cool (one band up), hot (two bands up), dip, boiling (one up)
        let t = try #require(ReplayTimeline.build(
            events: [g(3000), g(5000), g(800), g(50), g(60), g(10), g(1)], outcome: .solved))
        #expect(t.tiles.compactMap(\.emphasis) == [
            .newBest, .dip, .newBest, .bigJump(from: .cool), .dip, .newBest,
        ])
    }

    @Test func coldStraightToHotIsABigJump() throws {
        let t = try #require(ReplayTimeline.build(events: [g(5000), g(80), g(1)], outcome: .solved))
        #expect(t.tiles[1].emphasis == .bigJump(from: .cold))
    }

    @Test func questionsInARowShareOneBubble() throws {
        let t = try #require(ReplayTimeline.build(
            events: [yes, g(3000), yes, no, g(500), no, g(1)], outcome: .solved, pacing: noStretch))
        #expect(shape(t) == ["intro", "keeper1", "tile0", "keeper2", "tile1", "keeper1", "solved", "end"])
        guard case .keeper(let verdicts) = t.beats[3].kind else {
            Issue.record("expected a keeper beat")
            return
        }
        #expect(verdicts.map(\.tone) == [.yes, .no])
    }

    @Test func beatsUseThePacingAndRunBackToBack() throws {
        let p = noStretch
        let t = try #require(ReplayTimeline.build(
            events: [g(5000), g(6000), g(80), yes, g(1)], outcome: .solved, pacing: p))
        #expect(t.beats.map(\.duration) == [p.intro, p.newBest, p.dip, p.bigJump, p.keeper,
                                            p.finale, p.endCard])
        #expect(t.beats.first?.start == 0)
        for (a, b) in zip(t.beats, t.beats.dropFirst()) {
            #expect(abs(a.end - b.start) < 1e-9)
        }
        #expect(abs(t.duration - t.beats.map(\.duration).reduce(0, +)) < 1e-9)
    }

    @Test(arguments: [40, 90, 200, 600])
    func longRoundsFitInSixtySeconds(guesses: Int) throws {
        let t = try #require(ReplayTimeline.build(events: longRound(guesses: guesses, questionEvery: 3),
                                                  outcome: .solved))
        #expect(t.duration <= 60 + 1e-9)
        for beat in t.beats {
            #expect(beat.duration >= 1 - 1e-9 && beat.duration <= 3 + 1e-9)
        }
        // Compression never drops or reorders a tile.
        #expect(placedSlots(t) == Array(0..<(t.tiles.count - 1)))
        #expect(t.tiles.count == guesses + 1)
    }

    @Test func compressionMergesDipsBeforeNewBests() throws {
        // 70 guesses: a new best every 10th, dips in between. Played one per
        // beat it would be 73.5 seconds of middle, so the dips must merge.
        var events: [ReplayEvent] = []
        for i in 0..<70 { events.append(g(i % 10 == 0 ? 3000 - i * 30 : 9000)) }
        let t = try #require(ReplayTimeline.build(events: events + [g(1)], outcome: .solved))

        let newBestSlots = t.tiles.filter { $0.emphasis == .newBest }.map(\.slot)
        #expect(newBestSlots.count == 7)
        let singles = t.beats.compactMap { beat -> Int? in
            if case .place(let s) = beat.kind, s.count == 1 { return s[0] }
            return nil
        }
        for slot in newBestSlots { #expect(singles.contains(slot)) }
        #expect(shape(t).contains { $0.hasPrefix("burst") })
        #expect(t.duration <= 60)
    }

    @Test func keeperBubblesAreDroppedBeforeNewBestsMerge() throws {
        // So many questions that bubbles alone would blow the budget.
        var events: [ReplayEvent] = []
        for i in 0..<30 {
            events.append(g(5000 - i * 100))
            events.append(yes)
        }
        let t = try #require(ReplayTimeline.build(events: events + [g(1)], outcome: .solved))
        #expect(!shape(t).contains { $0.hasPrefix("keeper") })
        #expect(t.duration <= 60)
    }

    @Test func shortRoundsStretchALittleButAreNotPadded() throws {
        let t = try #require(ReplayTimeline.build(events: [g(3000), g(4000), g(1)], outcome: .solved))
        // Factor capped at 1.6: new best 1.5 -> 2.4, dip 1.0 -> 1.6.
        #expect(abs(t.beats[1].duration - 2.4) < 1e-9)
        #expect(abs(t.beats[2].duration - 1.6) < 1e-9)
        #expect(t.duration < 30)
        #expect(abs(t.duration - (1.5 + 2.4 + 1.6 + 3 + 3)) < 1e-9)
    }

    @Test func stretchingNeverPassesThreeSeconds() throws {
        let t = try #require(ReplayTimeline.build(events: [g(5000), g(80), g(1)], outcome: .solved))
        #expect(t.beats.allSatisfy { $0.duration <= 3 + 1e-9 })
    }

    @Test func firstGuessSolveIsJustIntroFinaleAndEndCard() throws {
        let t = try #require(ReplayTimeline.build(events: [g(1)], outcome: .solved))
        #expect(shape(t) == ["intro", "solved", "end"])
        #expect(t.tiles.count == 1)
        #expect(t.tiles[0].guessNumber == 1)
    }

    @Test func revealedEndsOnAGrayQuestionMark() throws {
        let t = try #require(ReplayTimeline.build(events: [g(3000), g(200), yes], outcome: .revealed))
        let last = try #require(t.tiles.last)
        #expect(last.kind == .revealed)
        #expect(last.guessNumber == nil)
        #expect(last.rank == 0)
        #expect(t.outcome == .revealed)
        #expect(Array(shape(t).suffix(3)) == ["keeper1", "revealed", "end"])
        #expect(t.totalGuesses == 2)
    }

    @Test func revealedWithNoGuessesHasNothingToReplay() {
        #expect(ReplayTimeline.build(events: [], outcome: .revealed) == nil)
        #expect(ReplayTimeline.build(events: [yes, no], outcome: .revealed) == nil)
    }

    @Test func aSolvedRankOnARevealedRoundIsIgnored() throws {
        let t = try #require(ReplayTimeline.build(events: [g(300), g(1)], outcome: .revealed))
        #expect(t.tiles.map(\.rank) == [300, 0])
    }

    @Test func solvedWithoutAnAnswerEventStillEndsInGold() throws {
        let t = try #require(ReplayTimeline.build(events: [g(300), g(40)], outcome: .solved))
        #expect(t.tiles.last?.kind == .answer)
        #expect(t.tiles.last?.guessNumber == 3)
    }

    @Test func tilesLandInOrderAndHopsFinishFirst() throws {
        let t = try #require(ReplayTimeline.build(events: longRound(guesses: 120, questionEvery: 5),
                                                  outcome: .solved))
        for (a, b) in zip(t.tiles, t.tiles.dropFirst()) {
            #expect(a.landsAt < b.landsAt)
            #expect(a.landsAt + a.hop <= b.landsAt + 1e-9)
        }
        #expect(t.tiles.last?.hop == 0)
        // Each tile lands inside the beat that places it.
        for beat in t.beats {
            guard case .place(let slots) = beat.kind else { continue }
            for s in slots {
                #expect(t.tiles[s].landsAt >= beat.start && t.tiles[s].landsAt < beat.end)
            }
        }
    }

    @Test func wickWalksTheSnakeOneCellAtATime() throws {
        let t = try #require(ReplayTimeline.build(events: [g(3000), g(800), g(1)], outcome: .solved))
        let first = t.tiles[0], second = t.tiles[1], answer = t.tiles[2]

        #expect(t.wickTravel(at: 0) == ReplayTimeline.Travel(from: 0, to: 0, progress: 1))
        let mid = t.wickTravel(at: first.landsAt + first.hop / 2)
        #expect(mid.from == 0 && mid.to == 1)
        #expect(abs(mid.progress - 0.5) < 1e-9)
        #expect(t.wickTravel(at: first.landsAt + first.hop + 0.01) == ReplayTimeline.Travel(from: 1, to: 1, progress: 1))
        #expect(t.wickTravel(at: second.landsAt + second.hop + 0.01) == ReplayTimeline.Travel(from: 2, to: 2, progress: 1))
        // He ends up standing on the answer.
        #expect(t.wickTravel(at: answer.landsAt + 1) == ReplayTimeline.Travel(from: 2, to: 2, progress: 1))
        #expect(t.wickTravel(at: t.duration + 5) == ReplayTimeline.Travel(from: 2, to: 2, progress: 1))
    }

    @Test func headsUpDisplayFollowsTheBoard() throws {
        let t = try #require(ReplayTimeline.build(events: [g(3000), g(5000), g(40), g(1)], outcome: .solved))
        #expect(t.bestRank(at: 0) == nil)
        #expect(t.guessesShown(at: 0) == 0)
        #expect(t.bestRank(at: t.tiles[1].landsAt) == 3000)
        #expect(t.guessesShown(at: t.tiles[1].landsAt) == 2)
        #expect(t.bestRank(at: t.tiles[2].landsAt) == 40)
        #expect(t.bestRank(at: t.duration) == 1)
        #expect(t.landedCount(at: t.duration) == 4)
    }

    @Test func beatLookupHoldsTheLastFrame() throws {
        let t = try #require(ReplayTimeline.build(events: [g(3000), g(1)], outcome: .solved))
        #expect(t.beatIndex(at: -1) == 0)
        #expect(t.beatIndex(at: 0) == 0)
        #expect(t.beatIndex(at: t.beats[1].start) == 1)
        #expect(t.beatIndex(at: t.duration + 10) == t.beats.count - 1)
    }
}

// MARK: - Formatting

struct ReplayFormatTests {
    @Test func compactRanks() {
        #expect(ReplayFormat.rank(0) == "")
        #expect(ReplayFormat.rank(14) == "#14")
        #expect(ReplayFormat.rank(999) == "#999")
        #expect(ReplayFormat.rank(2000) == "#2k")
        #expect(ReplayFormat.rank(2345) == "#2.3k")
        #expect(ReplayFormat.rank(12_345) == "#12k")
    }

    @Test func meterFillIsLogScaled() {
        #expect(ReplayFormat.fill(rank: 1, maxRank: 10_000) == 1)
        #expect(ReplayFormat.fill(rank: 0, maxRank: 10_000) == 0)
        #expect(abs(ReplayFormat.fill(rank: 100, maxRank: 10_000) - 0.5) < 1e-9)
        #expect(ReplayFormat.fill(rank: 10_000, maxRank: 10_000) == 0.04)
    }
}

// MARK: - Board

struct ReplayBoardTests {
    private let area = CGRect(x: 120, y: 480, width: 840, height: 940)

    /// [row, column] of a slot.
    private func cell(_ b: ReplayBoard, _ slot: Int) -> [Int] {
        let p = b.position(of: slot)
        return [p.row, p.column]
    }

    @Test func snakePathTurnsAtEachRowEnd() {
        let b = ReplayBoard(count: 10, area: area)
        #expect(b.columns == 4 && b.rows == 3)
        #expect(cell(b, 0) == [0, 0])
        #expect(cell(b, 3) == [0, 3])
        #expect(cell(b, 4) == [1, 3])
        #expect(cell(b, 7) == [1, 0])
        #expect(cell(b, 8) == [2, 0])
    }

    @Test(arguments: [1, 2, 5, 17, 60, 250, 900])
    func everyStepIsOneCellAndTheBoardFits(count: Int) {
        let b = ReplayBoard(count: count, area: area)
        #expect(b.cell >= 1)
        #expect(area.insetBy(dx: -1, dy: -1).contains(b.frame))
        #expect(b.columns * b.rows >= count)
        for s in 0..<max(0, count - 1) {
            let p = b.position(of: s), q = b.position(of: s + 1)
            #expect(abs(p.row - q.row) + abs(p.column - q.column) == 1)
        }
    }

    @Test func smallRoundsGetBigTiles() {
        #expect(ReplayBoard(count: 4, area: area).cell == 200)
    }
}

// MARK: - From stored rounds

@MainActor
struct ReplayEventsTests {
    @Test func interleavesBySeqAndDropsUnknownWords() {
        // Stored order is by closeness, not play order (see GameViewModel.submit).
        let guesses = [
            Guess(word: "answer", score: 100, known: true, order: 3, seq: 4),
            Guess(word: "warm", score: 40, known: true, order: 2, seq: 2),
            Guess(word: "cold", score: 10, known: true, order: 1, seq: 0),
            Guess(word: "zzz", score: 0, known: false, order: 4, seq: nil),
        ]
        let questions = [
            AskedQuestion(question: "Is it big?", verdict: "No", reply: "", seq: 3),
            AskedQuestion(question: "Is it alive?", verdict: "Yes", reply: "", seq: 1),
        ]
        let events = ReplayEvents.from(
            guesses: guesses, questions: questions,
            rank: { $0 >= 100 ? 1 : Int(1000 - $0 * 10) },
            verdictLabel: { $0.uppercased() })
        #expect(events == [
            .guess(rank: 900),
            .question(ReplayVerdict(tone: .yes, label: "YES")),
            .guess(rank: 600),
            .question(ReplayVerdict(tone: .no, label: "NO")),
            .guess(rank: 1),
        ])
    }
}
