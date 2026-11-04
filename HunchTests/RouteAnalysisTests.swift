// SPDX-License-Identifier: MPL-2.0
//
//  RouteAnalysisTests.swift
//  HunchTests
//
//  The 3.9 route analysis (RouteAnalysis.swift). The cases in
//  RouteFixtures.json also run on the web in wick-web/tests/route.test.ts, so
//  both clients agree to the number.
//

import Foundation
import Testing
@testable import Hunch

@MainActor
struct RouteAnalysisTests {
    typealias R = RouteAnalysis

    private static let fixtures: [String: Any] = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("RouteFixtures.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json
    }()

    private func list(_ key: String) -> [[String: Any]] {
        Self.fixtures[key] as? [[String: Any]] ?? []
    }

    private func optionalNumbers(_ v: Any?) -> [Double?]? {
        guard let a = v as? [Any] else { return nil }
        return a.map { $0 as? Double }
    }

    private func matrix(_ v: Any?) -> [[Double?]]? {
        guard let rows = v as? [[Any]] else { return nil }
        return rows.map { $0.map { $0 as? Double } }
    }

    @Test func fixturesLoaded() {
        #expect(!list("signals").isEmpty)
        #expect(!list("routes").isEmpty)
        #expect(!list("comparisons").isEmpty)
    }

    @Test func signalsMatchTheWeb() {
        for c in list("signals") {
            let got = R.classify(prior: c["prior"] as? [Double] ?? [], score: c["score"] as? Double ?? 0,
                                 similarity: optionalNumbers(c["similarity"]))
            #expect(got?.rawValue == c["expect"] as? String, "\(c["name"] ?? "")")
        }
    }

    @Test func routesMatchTheWeb() {
        for c in list("routes") {
            let name = "\(c["name"] ?? "")"
            let pairs = c["guesses"] as? [[Any]] ?? []
            let r = R.report(words: pairs.map { $0[0] as? String ?? "" }, scores: pairs.map { $0[1] as? Double ?? 0 },
                             solved: c["solved"] as? Bool ?? false, similarity: matrix(c["similarity"]))
            let e = c["expect"] as? [String: Any] ?? [:]
            #expect(r.efficiency == e["efficiency"] as? Int, "\(name) efficiency")
            #expect(r.bestJump?.index == e["jumpIndex"] as? Int, "\(name) jump index")
            #expect(r.bestJump?.gain == e["jumpGain"] as? Int, "\(name) jump gain")
            #expect(r.bestJump?.word == e["jumpWord"] as? String, "\(name) jump word")
            #expect(r.firstTry == e["firstTry"] as? Bool, "\(name) first try")
            #expect(r.exploration == e["exploration"] as? Int, "\(name) exploration")
            #expect(r.coachKey == e["coach"] as? String, "\(name) coach")
        }
    }

    @Test func comparisonsMatchTheWeb() {
        for c in list("comparisons") {
            let name = "\(c["name"] ?? "")"
            let you = c["you"] as? [String: Any] ?? [:]
            let them = c["them"] as? [String: Any] ?? [:]
            let samples = (them["samples"] as? [[Double]] ?? []).map { R.ProgressSample(guessCount: Int($0[0]), best: $0[1]) }
            let got = R.comparison(voided: c["voided"] as? Bool ?? false,
                                   youScores: you["scores"] as? [Double] ?? [],
                                   youGuessCount: you["guessCount"] as? Int ?? 0,
                                   youSolved: you["solved"] as? Bool ?? false,
                                   themSamples: samples,
                                   themGuessCount: them["guessCount"] as? Int ?? 0,
                                   themBest: them["best"] as? Double ?? 0,
                                   themSolved: them["solved"] as? Bool ?? false)
            guard let e = c["expect"] as? [String: Any] else {
                #expect(got == nil, "\(name)")
                continue
            }
            #expect(got?.sentenceKey == e["sentence"] as? String, "\(name) sentence")
            for (seat, want) in [(got?.you, e["you"]), (got?.them, e["them"])] {
                let w = want as? [String: Any] ?? [:]
                #expect(seat?.bands.map(\.rawValue) == w["bands"] as? [String], "\(name) bands")
                #expect(seat?.jumpNode == w["jumpNode"] as? Int, "\(name) jump node")
                #expect(seat?.efficiency == w["efficiency"] as? Int, "\(name) efficiency")
                #expect(seat?.guessCount == w["guessCount"] as? Int, "\(name) guess count")
                #expect(seat?.solved == w["solved"] as? Bool, "\(name) solved")
            }
        }
    }

    @Test func categoriesMatchTheWeb() {
        for pair in Self.fixtures["categories"] as? [[Any]] ?? [] {
            #expect(R.broadCategory(tag: pair[0] as? String)?.rawValue == pair[1] as? String, "\(pair[0])")
        }
        #expect(R.broadCategory(tag: nil) == nil)
    }

    @Test func abstractWordsNeverGetAChip() {
        #expect(R.broadCategory(tag: WordAttributes.category(for: "courage")?.rawValue) == nil)
        #expect(R.broadCategory(tag: WordAttributes.category(for: "cat")?.rawValue) == .animal)
    }

    @Test func sameInputSameReport() {
        let words = ["a", "b", "c", "d"], scores = [10.0, 44, 12, 100]
        let first = R.report(words: words, scores: scores, solved: true, similarity: nil)
        for _ in 0..<20 { #expect(R.report(words: words, scores: scores, solved: true, similarity: nil) == first) }
    }

    @Test func efficiencyEdges() {
        #expect(R.efficiency([], solved: false) == nil)
        #expect(R.efficiency([], solved: true) == nil)
        #expect(R.efficiency([100], solved: true) == 100)
        #expect(R.efficiency([55], solved: false) == nil)
        #expect(R.efficiency([40, 99], solved: true) == 100)
    }

    @Test func reduceMotionIsStill() {
        #expect(R.emphasis(.breakthrough, reduceMotion: false) == .pulse)
        #expect(R.emphasis(.breakthrough, reduceMotion: true) == .still)
        for s in R.Signal.allCases where s != .breakthrough {
            #expect(R.emphasis(s, reduceMotion: false) == .none)
            #expect(R.emphasis(s, reduceMotion: true) == .none)
        }
        #expect(R.pathSequence(reduceMotion: true) == R.PathBeats(wick: 0, word: 0, route: 0, routeMs: 0, halo: 0, stats: 0, coach: 0))
        let b = R.pathSequence(reduceMotion: false)
        #expect(b.wick <= b.word && b.word <= b.route && b.route <= b.halo && b.halo <= b.stats && b.stats <= b.coach)
        #expect(b.coach < R.pathSequenceMs)
        #expect(b.route + b.routeMs <= R.pathSequenceMs)
    }

    @Test func recorderTakesLateWarmth() {
        var r = R.ProgressRecorder()
        r.push(guessCount: 0, bestWarmth: 0.5)
        r.push(guessCount: 1, bestWarmth: 0)
        r.push(guessCount: 1, bestWarmth: 0.3)
        r.push(guessCount: 2, bestWarmth: 0.3)
        r.push(guessCount: 1, bestWarmth: 0.9)
        #expect(r.samples == [R.ProgressSample(guessCount: 1, best: 0.3), R.ProgressSample(guessCount: 2, best: 0.3)])
    }

    @Test func noExactOpponentScoreLeaves() {
        let c = R.comparison(voided: false, youScores: [10, 100], youGuessCount: 2, youSolved: true,
                             themSamples: [R.ProgressSample(guessCount: 1, best: 0.2), R.ProgressSample(guessCount: 2, best: 0.5)],
                             themGuessCount: 2, themBest: 0.5, themSolved: false)
        #expect(c?.them.efficiency == nil, "their drops are hidden, so no Efficiency is claimed")
        #expect(c?.them.bands == [.trail, .close])
    }

    @Test func aRouteCutShortIsNotGraded() {
        let c = R.comparison(voided: false, youScores: [8, 11, 6], youGuessCount: 3, youSolved: false,
                             themSamples: [R.ProgressSample(guessCount: 1, best: 0.1), R.ProgressSample(guessCount: 2, best: 0.2),
                                           R.ProgressSample(guessCount: 3, best: 0.2)],
                             themGuessCount: 4, themBest: 1, themSolved: true)
        #expect(c != nil)
        #expect(c?.you.efficiency == nil)
    }

    @Test func greenOnlyForASolve() {
        let c = R.comparison(voided: false, youScores: [10, 99], youGuessCount: 2, youSolved: false,
                             themSamples: [R.ProgressSample(guessCount: 1, best: 0.2), R.ProgressSample(guessCount: 2, best: 0.996)],
                             themGuessCount: 2, themBest: 0.996, themSolved: false)
        #expect(c?.you.bands.contains(.solved) == false)
        #expect(c?.them.bands.contains(.solved) == false)
    }

    @Test func everyTableHasThePathKeys() {
        func ph(_ s: String) -> [String] {
            var out: [String] = []
            var rest = Substring(s)
            while let r = rest.range(of: "%") {
                let next = rest.index(after: r.lowerBound)
                if next < rest.endIndex { out.append(String(rest[next])) }
                rest = rest[next...]
            }
            return out.sorted()
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
