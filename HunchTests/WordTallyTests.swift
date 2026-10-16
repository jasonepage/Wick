//
//  WordTallyTests.swift
//  HunchTests
//
//  3.6: what may leave the phone for the weekly Stats lists, and how the
//  cached lists from GET /stats/weekly are read. Pure rules only; no network.
//

import Foundation
import Testing
@testable import Hunch

struct WordTallyTests {

    @Test func onlyCoolOrColderGuessesAreSent() {
        #expect(WordTallyRules.shouldSendGuess(rank: 401))
        #expect(WordTallyRules.shouldSendGuess(rank: 5000))
        #expect(!WordTallyRules.shouldSendGuess(rank: 400))   // last Warm rank
        #expect(!WordTallyRules.shouldSendGuess(rank: 25))
        #expect(!WordTallyRules.shouldSendGuess(rank: 1))     // the answer
        #expect(!WordTallyRules.shouldSendGuess(rank: 0))     // ranking not built yet
    }

    @Test func questionsNamingTheAnswerStayHome() {
        #expect(WordTallyRules.namesAnswer("Is it a library?", answers: ["library"]))
        #expect(WordTallyRules.namesAnswer("is it cats", answers: ["cat"]))
        #expect(WordTallyRules.namesAnswer("¿Es una biblioteca?", answers: ["biblioteca", "library"]))
        #expect(WordTallyRules.namesAnswer("is it a library", answers: ["biblioteca", "library"]))
        #expect(!WordTallyRules.namesAnswer("is it alive?", answers: ["library", nil]))
        #expect(!WordTallyRules.namesAnswer("is it big", answers: [""]))
    }

    private let sample = """
    {"week":"2026-10-12","resetsAt":"2026-10-19T00:00:00.000Z","lang":"en",
     "guesses":[{"text":"ocean","count":5},{"text":"river","count":3}],
     "questions":[{"text":"Is it alive?","count":7}]}
    """

    @Test func decodesTheServerResponse() throws {
        let snap = try #require(WeeklySnapshot.decode(Data(sample.utf8)))
        #expect(snap.week == "2026-10-12")
        #expect(snap.guesses.map(\.text) == ["ocean", "river"])
        #expect(snap.questions.first?.count == 7)
        #expect(snap.resetDate == Date(timeIntervalSince1970: 1_792_368_000))
    }

    @Test func cacheGoesStaleAfterHalfAnHourOrAtTheReset() throws {
        let snap = try #require(WeeklySnapshot.decode(Data(sample.utf8)))
        let fetched = Date(timeIntervalSince1970: 1_792_000_000)   // Wed 14 Oct 2026
        #expect(snap.isFresh(fetchedAt: fetched, now: fetched.addingTimeInterval(10 * 60)))
        #expect(!snap.isFresh(fetchedAt: fetched, now: fetched.addingTimeInterval(31 * 60)))
        let reset = try #require(snap.resetDate)
        #expect(snap.isExpired(now: reset))
        #expect(!snap.isFresh(fetchedAt: reset.addingTimeInterval(-60), now: reset.addingTimeInterval(1)))
    }
}
