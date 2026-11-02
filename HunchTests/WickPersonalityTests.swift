//
//  WickPersonalityTests.swift
//  HunchTests
//
//  Mirrors wick-web/tests/wickpersonality.test.ts so the two ports stay in step.
//

import Testing
@testable import Hunch

struct WickPersonalityTests {

    private func g(_ word: String, _ score: Double, _ previousBest: Double?, _ guessCount: Int, _ coldStreak: Int = 0) -> WickGuessReactionInput {
        WickGuessReactionInput(word: word, score: score, previousBest: previousBest, guessCount: guessCount, coldStreak: coldStreak)
    }

    @Test func topicRecognitionIsNarrow() {
        #expect(WickPersonality.topic(forGuess: "pizza") == .food)
        #expect(WickPersonality.topic(forGuess: "Bitcoin") == .money)
        #expect(WickPersonality.topic(forGuess: "astronaut") == .space)
        #expect(WickPersonality.topic(forGuess: "ordinary") == nil)
    }

    @Test func nearSolveWearsFlusteredAndBeatsTopic() {
        var state = WickPersonalityState()
        let near = WickPersonality.reaction(forGuess: g("pizza", 88, 80, 4), state: &state)
        #expect(near?.kind == .near)
        #expect(near?.face == .flustered)
    }

    @Test func priorityOrder() {
        var s = WickPersonalityState()
        _ = WickPersonality.reaction(forGuess: g("rock", 10, nil, 1), state: &s)
        #expect(WickPersonality.reaction(forGuess: g("rock", 90, 10, 5), state: &s)?.kind == .repeat)
        s = WickPersonalityState()
        #expect(WickPersonality.reaction(forGuess: g("tree", 90, 50, 4), state: &s)?.kind == .leap)
        s = WickPersonalityState()
        #expect(WickPersonality.reaction(forGuess: g("tree", 85, 80, 4), state: &s)?.kind == .near)
        s = WickPersonalityState()
        #expect(WickPersonality.reaction(forGuess: g("tree", 5, 50, 4, 16), state: &s)?.kind == .regress)
        s = WickPersonalityState()
        #expect(WickPersonality.reaction(forGuess: g("pizza", 12, 14, 20, 16), state: &s)?.kind == .stall)
        s = WickPersonalityState()
        #expect(WickPersonality.reaction(forGuess: g("pizza", 12, 14, 4, 2), state: &s)?.kind == .topic)
    }

    @Test func globalCooldownIsThreeGuesses() {
        var s = WickPersonalityState()
        #expect(WickPersonality.reaction(forGuess: g("a", 90, 50, 1), state: &s)?.kind == .leap)
        #expect(WickPersonality.reaction(forGuess: g("b", 95, 90, 2), state: &s) == nil)
        #expect(WickPersonality.reaction(forGuess: g("c", 96, 95, 3), state: &s) == nil)
        #expect(WickPersonality.reaction(forGuess: g("d", 97, 96, 4), state: &s)?.kind == .near)
    }

    @Test func perBeatCooldowns() {
        var s = WickPersonalityState()
        _ = WickPersonality.reaction(forGuess: g("x", 10, nil, 1), state: &s)
        #expect(WickPersonality.reaction(forGuess: g("x", 10, 10, 4), state: &s)?.kind == .repeat)
        #expect(WickPersonality.reaction(forGuess: g("x", 10, 10, 8), state: &s) == nil)
        var l = WickPersonalityState()
        #expect(WickPersonality.reaction(forGuess: g("a", 40, 10, 1), state: &l)?.kind == .leap)
        #expect(WickPersonality.reaction(forGuess: g("b", 70, 40, 4), state: &l) == nil)
        #expect(WickPersonality.reaction(forGuess: g("c", 95, 70, 5), state: &l)?.kind == .leap)
        var n = WickPersonalityState()
        #expect(WickPersonality.reaction(forGuess: g("a", 85, 80, 1), state: &n)?.kind == .near)
        #expect(WickPersonality.reaction(forGuess: g("b", 86, 85, 4), state: &n)?.kind == .near)
    }

    @Test func stallGoesGreyAndLinesAreRarerThanFaces() {
        var s = WickPersonalityState()
        let stall = WickPersonality.reaction(forGuess: g("q", 10, 12, 20, 15), state: &s)
        #expect(stall?.kind == .stall)
        #expect(stall?.neutral == true)
        var withLine = 0
        for i in 0..<40 {
            var st = WickPersonalityState()
            if WickPersonality.reaction(forGuess: g("w\(i)", 85, 80, i + 1), state: &st)?.line != nil { withLine += 1 }
        }
        #expect(withLine > 0 && withLine < 40)
    }

    @Test func solvedLinePool() {
        #expect(WickPersonality.solvedLine(guessCount: 1, seed: "daily:5") == "...on the first guess?")
        var seen = Set<String?>()
        for i in 2..<40 { seen.insert(WickPersonality.solvedLine(guessCount: i, seed: "daily:5")) }
        #expect(seen.contains(nil))
        #expect(seen.count >= 3)
    }

    @Test func hashMatchesTheWeb() {
        // Values computed with the web hash() in wickpersonality.ts.
        #expect(WickPersonality.hash("a") == 0xE40C292C)
        #expect(WickPersonality.hash("food:pizza:3") == 0x086F35B6)
    }

    @Test func questionBeatsUseWholeWords() {
        #expect(WickPersonality.reaction(forQuestion: "Are you real?")?.face == .focus)
        #expect(WickPersonality.reaction(forQuestion: "is it dumber than a rock")?.face == nil)
        #expect(WickPersonality.reaction(forQuestion: "is it dumb")?.face == .calm)
    }
}
