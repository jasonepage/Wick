// SPDX-License-Identifier: MPL-2.0
//
//  RouteAnalysis.swift
//  Hunch: Wick 3.9 Semantic Arena
//
//  The route analysis behind 3.9. Pure functions over a round's numbers: one
//  small signal per guess, the three Path Report stats, the coach line, the
//  post-round category chip and the two-player race comparison. No SwiftUI, no
//  network, no clock, no randomness: the same round always gives the same answer.
//
//  What may come in: scores 0...100, the player's OWN guess words, and
//  similarity between the player's own guesses (0 unrelated, 1 the same). The
//  race comparison takes numbers only: it has no field for a word, so an
//  opponent's guess cannot pass through it.
//
//  LOCKSTEP with wick-web/src/game/route.ts: same names, same numbers.
//  HunchTests/RouteFixtures.json holds cases both test suites run.
//

import Foundation

nonisolated enum RouteAnalysis {

    // MARK: Thresholds

    /// Every tuning number in one place. Points are warmth points on 0...100.
    static let breakthroughGain = 15
    static let warmerGain = 4
    static let backtrackDrop = 12
    /// Below this change a move counts as "roughly flat".
    static let flatBand = 8
    static let neighborSim = 0.72
    static let newDirectionSim = 0.35
    /// "Recent guesses" for New direction.
    static let recentWindow = 3
    /// A move smaller than this repeats the last guess's warmth.
    static let flatMove = 2
    static let flatMovePenalty = 3
    static let flatMovePenaltyCap = 15
    /// Two guesses at or above this similarity are one direction.
    static let clusterSim = 0.5
    static let coachCleanEfficiency = 80
    static let coachBigJump = 25
    static let coachWideDirections = 4
    static let coachCircleGuesses = 5
    static let coachCircleDirections = 2
    static let coachCircleFlatMoves = 3
    static let coachBacktracks = 2

    /// Clamp to 0...100 and round to a whole number.
    static func normScore(_ s: Double) -> Int {
        guard s.isFinite else { return 0 }
        return Int(max(0, min(100, s)).rounded())
    }

    // MARK: Strategic guess signals

    nonisolated enum Signal: String, CaseIterable, Sendable {
        case breakthrough, warmer, sideways, sameNeighborhood, backtrack, newDirection

        /// The localization key for the signal's label.
        var key: String {
            switch self {
            case .breakthrough:     return "signalBreakthrough"
            case .warmer:           return "signalWarmer"
            case .sideways:         return "signalSideways"
            case .sameNeighborhood: return "signalNeighborhood"
            case .backtrack:        return "signalBacktrack"
            case .newDirection:     return "signalNewDirection"
            }
        }

        /// A small glyph, so the signal never relies on color.
        var symbol: String {
            switch self {
            case .breakthrough:     return "chevron.up.2"
            case .warmer:           return "arrow.up"
            case .sideways:         return "arrow.left.and.right"
            case .sameNeighborhood: return "arrow.clockwise"
            case .backtrack:        return "arrow.down"
            case .newDirection:     return "arrow.up.right"
            }
        }
    }

    /// One signal for an accepted guess, or nil when nothing is worth saying.
    /// `prior` is the player's earlier scores, oldest first. `similarity` is
    /// this guess's similarity to its earlier guesses, NEWEST first, at most
    /// three; nil means similarity is unavailable, and then only Breakthrough,
    /// Warmer and Backtrack can fire. The first guess and the solving guess get
    /// no signal. Priority: Breakthrough, Warmer, Backtrack, Same neighborhood,
    /// New direction, Sideways.
    static func classify(prior rawPrior: [Double], score rawScore: Double, similarity: [Double?]?) -> Signal? {
        let prior = rawPrior.map(normScore)
        let score = normScore(rawScore)
        guard let prev = prior.last, let best = prior.max(), score < 100 else { return nil }
        let gain = score - best
        if gain >= breakthroughGain { return .breakthrough }
        if gain >= warmerGain { return .warmer }
        if prev - score >= backtrackDrop { return .backtrack }

        let sims = similarity ?? []
        guard let first = sims.first, let toPrev = first else { return nil }
        let flat = abs(score - prev) < flatBand
        if toPrev >= neighborSim && flat { return .sameNeighborhood }

        let window = min(recentWindow, prior.count)
        let recent = sims.prefix(window)
        if recent.count == window, recent.allSatisfy({ s in
            guard let s else { return false }
            return s < newDirectionSim
        }) {
            return .newDirection
        }
        if toPrev < neighborSim && flat { return .sideways }
        return nil
    }

    /// How a signal is emphasized. Only Breakthrough gets gold: one pulse, or
    /// a still gold state under Reduce Motion.
    nonisolated enum Emphasis: Sendable { case none, pulse, still }

    static func emphasis(_ signal: Signal, reduceMotion: Bool) -> Emphasis {
        guard signal == .breakthrough else { return .none }
        return reduceMotion ? .still : .pulse
    }

    // MARK: Route statistics

    nonisolated struct BestJump: Equatable, Sendable {
        var index: Int
        var word: String
        var gain: Int
    }

    nonisolated struct Report: Equatable, Sendable {
        var guessCount: Int
        var solved: Bool
        /// 0...100, or nil when there is no route to measure.
        var efficiency: Int?
        var bestJump: BestJump?
        /// The first guess was the only scored guess.
        var firstTry: Bool
        /// How many directions the guesses went, or nil without similarity.
        var exploration: Int?
        /// The coach line's localization key, or nil for an empty round.
        var coachKey: String?
    }

    private static func flatMoves(_ scores: [Int]) -> Int {
        guard scores.count > 1 else { return 0 }
        var n = 0
        for i in 1..<scores.count where abs(scores[i] - scores[i - 1]) < flatMove { n += 1 }
        return n
    }

    /// Efficiency: how directly the guesses moved toward the answer.
    ///
    ///     net      = how far the last guess got above the first
    ///     needed   = 100 - first guess
    ///     traveled = every warmth move added up, drops included
    ///     score    = 100 * net / max(traveled, needed), minus 3 per flat move (up to 15)
    ///
    /// Solved, net equals needed, so a straight climb scores 100 and every drop
    /// costs twice: once down, once back up. A round that stopped short is
    /// measured against the full distance. It uses warmth only, so it works
    /// offline, in a race, and with similarity down.
    static func efficiency(_ rawScores: [Double], solved: Bool) -> Int? {
        var scores = rawScores.map(normScore)
        guard let lastIndex = scores.indices.last else { return nil }
        if solved { scores[lastIndex] = 100 }
        if scores.count == 1 { return solved ? 100 : nil }
        let first = scores[0], last = scores[lastIndex]
        let needed = 100 - first
        if needed <= 0 { return 100 }
        var traveled = 0
        for i in 1..<scores.count { traveled += abs(scores[i] - scores[i - 1]) }
        let net = max(0, last - first)
        let base = 100.0 * Double(net) / Double(max(traveled, needed))
        let penalty = min(flatMovePenaltyCap, flatMoves(scores) * flatMovePenalty)
        return max(0, min(100, Int((base - Double(penalty)).rounded())))
    }

    /// The largest rise over the previous guess, earliest on a tie. The
    /// solving guess is skipped when any other rise exists: it almost always
    /// wins, which would make the stat say the same thing every round.
    private static func largestRise(_ scores: [Int], solved: Bool) -> (index: Int, gain: Int)? {
        var best: (index: Int, gain: Int)? = nil
        let end = solved ? scores.count - 1 : scores.count
        if end > 1 {
            for i in 1..<end {
                let gain = scores[i] - scores[i - 1]
                if gain > 0 && (best == nil || gain > best!.gain) { best = (i, gain) }
            }
        }
        if best == nil, solved, scores.count >= 2 {
            let i = scores.count - 1
            let gain = scores[i] - scores[i - 1]
            if gain > 0 { best = (i, gain) }
        }
        return best
    }

    static func bestJump(words: [String], scores: [Int], solved: Bool) -> BestJump? {
        guard let rise = largestRise(scores, solved: solved) else { return nil }
        return BestJump(index: rise.index, word: words[rise.index], gain: rise.gain)
    }

    /// Exploration: how many directions the guesses went. Oldest first, each
    /// guess joins the first direction whose opening guess it is close to, or
    /// opens a new one. The solving guess is left out (it is the target, not a
    /// direction). A pair with no similarity counts as different. nil when
    /// there is no matrix.
    static func exploration(count: Int, solved: Bool, similarity: [[Double?]]?) -> Int? {
        let n = solved ? count - 1 : count
        guard let similarity, similarity.count >= count, count > 0, n > 0 else { return nil }
        var leaders: [Int] = []
        for i in 0..<n {
            let home = leaders.contains { l in
                guard i < similarity.count, l < similarity[i].count, let s = similarity[i][l] else { return false }
                return s >= clusterSim
            }
            if !home { leaders.append(i) }
        }
        return leaders.count
    }

    private static func backtracks(_ scores: [Int]) -> Int {
        guard scores.count > 1 else { return 0 }
        var n = 0
        for i in 1..<scores.count where scores[i - 1] - scores[i] >= backtrackDrop { n += 1 }
        return n
    }

    /// One authored line, chosen by fixed rules. Never generated, never a grade.
    static func coachKey(scores: [Int], solved: Bool, efficiency: Int?, jumpGain: Int, exploration: Int?) -> String? {
        let n = scores.count
        if n == 0 { return nil }
        if !solved { return "pathCoachUnfinished" }
        if n == 1 { return "pathCoachFirstTry" }
        if let efficiency, efficiency >= coachCleanEfficiency { return "pathCoachClean" }
        if jumpGain >= coachBigJump { return "pathCoachBreakthrough" }
        // Closed fast: the last guess before the answer was the warmest of the hunt.
        let hunt = Array(scores.dropLast())
        let closed = (hunt.last ?? 0) >= (hunt.max() ?? 0)
        if let exploration, exploration >= coachWideDirections, closed { return "pathCoachExplored" }
        let narrow = exploration.map { $0 <= coachCircleDirections } ?? false
        if n >= coachCircleGuesses && (narrow || flatMoves(scores) >= coachCircleFlatMoves) { return "pathCoachCircled" }
        if backtracks(scores) >= coachBacktracks { return "pathCoachPivot" }
        return "pathCoachSteady"
    }

    /// `words` and `scores` are every scored guess, oldest first; a solving
    /// guess is last. `similarity` is pairwise, same order, nil when unknown.
    static func report(words: [String], scores rawScores: [Double], solved: Bool, similarity: [[Double?]]?) -> Report {
        var scores = rawScores.map(normScore)
        if solved, let last = scores.indices.last { scores[last] = 100 }
        let eff = efficiency(scores.map(Double.init), solved: solved)
        let jump = bestJump(words: words, scores: scores, solved: solved)
        let dirs = exploration(count: scores.count, solved: solved, similarity: similarity)
        return Report(guessCount: scores.count, solved: solved, efficiency: eff, bestJump: jump,
                      firstTry: scores.count == 1, exploration: dirs,
                      coachKey: coachKey(scores: scores, solved: solved, efficiency: eff,
                                         jumpGain: jump?.gain ?? 0, exploration: dirs))
    }

    // MARK: The Path Report's reveal sequence

    static let pathSequenceMs = 1200

    /// When each beat starts, in milliseconds. Reduce Motion: everything at once.
    nonisolated struct PathBeats: Equatable, Sendable {
        var wick: Int
        var word: Int
        var route: Int
        var routeMs: Int
        var halo: Int
        var stats: Int
        var coach: Int
    }

    static func pathSequence(reduceMotion: Bool) -> PathBeats {
        if reduceMotion { return PathBeats(wick: 0, word: 0, route: 0, routeMs: 0, halo: 0, stats: 0, coach: 0) }
        return PathBeats(wick: 0, word: 120, route: 220, routeMs: 520, halo: 740, stats: 860, coach: 1060)
    }

    // MARK: The Path Card

    /// Everything the Path Card may say beyond the heat trail. Numbers only,
    /// on purpose: there is no field for a word.
    nonisolated struct PathFacts: Equatable, Sendable {
        var guesses: Int
        var solved: Bool
        var efficiency: Int?
        var bestJump: Int?
    }

    /// `scores` is every scored guess, oldest first. It takes numbers, not a
    /// report, so a guess word has no way onto the card.
    static func pathFacts(scores rawScores: [Double], solved: Bool, guesses: Int? = nil) -> PathFacts {
        var scores = rawScores.map(normScore)
        if solved, let last = scores.indices.last { scores[last] = 100 }
        return PathFacts(guesses: guesses ?? scores.count, solved: solved,
                         efficiency: efficiency(scores.map(Double.init), solved: solved),
                         bestJump: largestRise(scores, solved: solved)?.gain)
    }

    // MARK: Category chip (post-round only)

    nonisolated enum BroadCategory: String, CaseIterable, Sendable {
        case animal, place, object, nature, food, artMusic, time, event

        var key: String {
            switch self {
            case .animal:   return "pathCatAnimal"
            case .place:    return "pathCatPlace"
            case .object:   return "pathCatObject"
            case .nature:   return "pathCatNature"
            case .food:     return "pathCatFood"
            case .artMusic: return "pathCatArtMusic"
            case .time:     return "pathCatTime"
            case .event:    return "pathCatEvent"
            }
        }
    }

    /// The word tags that read true as a broad label, by the tag's raw name.
    /// Tags with no honest broad label (abstract, person, bodyPart, substance)
    /// are left out: no chip beats a wrong chip.
    static func broadCategory(tag: String?) -> BroadCategory? {
        switch tag {
        case "animal":                    return .animal
        case "structure", "naturalPlace": return .place
        case "object":                    return .object
        case "plant", "naturalPhenomenon": return .nature
        case "food":                      return .food
        case "artMusic":                  return .artMusic
        case "timePeriod":                return .time
        case "event":                     return .event
        default:                          return nil
        }
    }

    // MARK: Race comparison

    /// One public snapshot of a seat: its guess count and best warmth (0...1).
    nonisolated struct ProgressSample: Equatable, Sendable {
        var guessCount: Int
        var best: Double
    }

    /// The opponent's public progress, one sample per guess. The protocol
    /// shows their guess count and best warmth so far, so this is a running
    /// best: a guess that went colder is invisible. Nothing here sees a word.
    nonisolated struct ProgressRecorder: Equatable, Sendable {
        private(set) var samples: [ProgressSample] = []

        mutating func push(guessCount: Int, bestWarmth: Double) {
            guard guessCount > 0 else { return }
            let best = max(0, min(1, bestWarmth))
            if let last = samples.last {
                if guessCount < last.guessCount { return }
                // A guess counts at once and its warmth lands a moment later.
                if guessCount == last.guessCount {
                    samples[samples.count - 1].best = max(last.best, best)
                    return
                }
            }
            samples.append(ProgressSample(guessCount: guessCount, best: best))
        }
    }

    /// A running best on the 0...100 scale, one value per guess.
    static func runningBest(_ scores: [Double]) -> [Int] {
        var out: [Int] = []
        var best = 0
        for s in scores {
            best = max(best, normScore(s))
            out.append(best)
        }
        return out
    }

    /// The opponent's running best per guess, or nil when this device did not
    /// see every guess live (a resumed match). Only the last guess may be
    /// missing: it can end the match before a snapshot goes out.
    static func opponentSeries(_ samples: [ProgressSample], guessCount: Int, finalBest: Double) -> [Int]? {
        guard guessCount > 0, samples.count <= guessCount, samples.count >= guessCount - 1 else { return nil }
        for (i, s) in samples.enumerated() where s.guessCount != i + 1 { return nil }
        var series = samples.map { $0.best * 100 }
        if series.count < guessCount {
            series.append(finalBest * 100)
        } else {
            series[guessCount - 1] = max(series[guessCount - 1], finalBest * 100)
        }
        return runningBest(series)
    }

    /// The trail node nearest to guess `index` once a trail is capped.
    static func capNode(_ index: Int, length: Int, cap: Int = RaceShowdown.trailCap) -> Int {
        if length <= cap { return index }
        return Int((Double(index * (cap - 1)) / Double(length - 1)).rounded())
    }

    /// What one seat of the comparison may show. No word, no score.
    nonisolated struct ComparisonSeat: Equatable, Sendable {
        var guessCount: Int
        var solved: Bool
        /// Only a local seat that solved has one. The protocol hides the
        /// opponent's drops, so an honest number cannot be worked out for them,
        /// and a route the other player's solve cut short is not one to grade.
        var efficiency: Int?
        /// Heat bands, oldest first, at most eight. Green only for a solve.
        var bands: [RaceShowdown.Band]
        /// Which node carries the gold marker, or nil when the seat never rose.
        var jumpNode: Int?
    }

    nonisolated struct Comparison: Equatable, Sendable {
        var you: ComparisonSeat
        var them: ComparisonSeat
        var sentenceKey: String
    }

    private static func seatBands(_ best: [Int], solved: Bool) -> [RaceShowdown.Band] {
        best.enumerated().map { i, s in
            if solved && i == best.count - 1 { return .solved }
            let band = RaceShowdown.band(Double(s) / 100)
            return band == .solved ? .danger : band
        }
    }

    private static func seat(_ best: [Int], rise: (index: Int, gain: Int)?, solved: Bool,
                             guessCount: Int, efficiency: Int?) -> ComparisonSeat {
        ComparisonSeat(guessCount: guessCount, solved: solved, efficiency: efficiency,
                       bands: RaceShowdown.capTrail(seatBands(best, solved: solved)),
                       jumpNode: rise.map { capNode($0.index, length: best.count) })
    }

    /// The two routes side by side, or nil when the race data cannot support
    /// it. Both trails use the same running best, so the comparison is fair.
    /// The sentence is neutral: it compares routes and never says who lost.
    static func comparison(voided: Bool,
                           youScores: [Double], youGuessCount: Int, youSolved: Bool,
                           themSamples: [ProgressSample], themGuessCount: Int, themBest: Double,
                           themSolved: Bool) -> Comparison? {
        if voided { return nil }
        var yours = youScores.map { Double(normScore($0)) }
        if youSolved && yours.last != 100 { yours.append(100) }
        guard !yours.isEmpty, youGuessCount > 0 else { return nil }
        guard let themRun = opponentSeries(themSamples, guessCount: themGuessCount, finalBest: themBest) else { return nil }
        let youRun = runningBest(yours)

        let youRise = largestRise(youRun, solved: youSolved)
        let themRise = largestRise(themRun, solved: themSolved)
        let you = seat(youRun, rise: youRise, solved: youSolved, guessCount: youGuessCount,
                       efficiency: youSolved ? efficiency(yours, solved: true) : nil)
        let them = seat(themRun, rise: themRise, solved: themSolved, guessCount: themGuessCount, efficiency: nil)

        // Typing the answer is not a breakthrough, however far it jumped.
        func big(_ rise: (index: Int, gain: Int)?, length: Int, solved: Bool) -> Int? {
            guard let rise, rise.gain >= breakthroughGain, !(solved && rise.index == length - 1) else { return nil }
            return rise.index
        }
        let youBig = big(youRise, length: youRun.count, solved: youSolved)
        let themBig = big(themRise, length: themRun.count, solved: themSolved)
        let key: String
        if let y = youBig, themBig == nil || y < themBig! {
            key = "pathCmpBreakthroughYou"
        } else if let t = themBig, youBig == nil || t < youBig! {
            key = "pathCmpBreakthroughThem"
        } else if you.solved && you.guessCount < them.guessCount {
            key = "pathCmpShorterYou"
        } else if them.solved && them.guessCount < you.guessCount {
            key = "pathCmpShorterThem"
        } else if you.bands.last == them.bands.last {
            key = "pathCmpConverged"
        } else {
            key = "pathCmpDifferent"
        }
        return Comparison(you: you, them: them, sentenceKey: key)
    }

    /// Every localization key this file names (the tests check each table).
    static var keys: [String] {
        ["pathTitle", "pathSolvedIn", "pathUnsolved", "pathStatEfficiency", "pathStatBestJump", "pathStatExploration",
         "pathJumpGain", "pathFirstTry", "pathDirections.one", "pathDirections.other", "pathStatNone",
         "pathEfficiencyInfo", "pathEfficiencyInfoBtn", "pathShare", "pathCmpTitle",
         "pathCoachClean", "pathCoachBreakthrough", "pathCoachExplored", "pathCoachCircled", "pathCoachPivot",
         "pathCoachFirstTry", "pathCoachUnfinished", "pathCoachSteady",
         "pathCardSolved", "pathCardUnsolved", "pathCardEfficiency", "pathCardJump", "cardBrandRace",
         "pathCmpBreakthroughYou", "pathCmpBreakthroughThem", "pathCmpShorterYou", "pathCmpShorterThem",
         "pathCmpConverged", "pathCmpDifferent"]
        + Signal.allCases.map(\.key)
        + BroadCategory.allCases.map(\.key)
    }
}
