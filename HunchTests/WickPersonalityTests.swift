//
//  WickPersonalityTests.swift
//  HunchTests
//
//  Mirrors wick-web/tests/wickpersonality.test.ts so the two ports stay in step.
//

import Testing
@testable import Hunch

struct WickPersonalityTests {

    @Test func topicRecognitionIsNarrow() {
        #expect(WickPersonality.topic(forGuess: "pizza") == .food)
        #expect(WickPersonality.topic(forGuess: "Bitcoin") == .money)
        #expect(WickPersonality.topic(forGuess: "astronaut") == .space)
        #expect(WickPersonality.topic(forGuess: "ordinary") == nil)
    }

    @Test func dramaticInformationBeatsFlavor() {
        var state = WickPersonalityState()
        let near = WickPersonality.reaction(
            forGuess: WickGuessReactionInput(word: "pizza", score: 88, previousBest: 20, guessCount: 4, coldStreak: 0),
            state: &state)
        #expect(near?.kind == .near)
        #expect(near?.face == .shocked)
    }

    @Test func aTopicPerformsOnce() {
        var state = WickPersonalityState()
        let first = WickPersonality.reaction(
            forGuess: WickGuessReactionInput(word: "pizza", score: 15, previousBest: 18, guessCount: 3, coldStreak: 1),
            state: &state)
        let second = WickPersonality.reaction(
            forGuess: WickGuessReactionInput(word: "cake", score: 16, previousBest: 18, guessCount: 4, coldStreak: 2),
            state: &state)
        #expect(first?.kind == .topic)
        #expect(second == nil)
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
