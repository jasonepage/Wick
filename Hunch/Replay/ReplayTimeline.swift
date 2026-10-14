//
//  ReplayTimeline.swift
//  Hunch
//
//  Solve Replay (3.4), part 1: the pure timing logic.
//
//  Turns the round's ordered guesses and Keeper questions into a list of
//  "beats" (one beat = one moment of the video) with start times, plus the
//  exact moment each tile lands and how long Wick takes to hop off it. The
//  scene in ReplayScene.swift only asks this file "what is happening at time
//  t?" and draws the answer, so everything here is plain values and can be
//  unit tested without rendering a single frame.
//
//  THE RULES IT FOLLOWS
//  --------------------
//  * Every known guess gets a tile, in play order, so the board matches the
//    real guess count. Guesses that did not beat the best so far ("dips") go
//    by quickly; new bests get a longer beat; a big jump (two or more heat
//    bands hotter than the best so far, like Cold straight to Hot) gets the
//    longest beat and the drama.
//  * Keeper questions in a row become ONE speech bubble beat that shows only
//    the verdicts. The question text never reaches this file.
//  * Beats are 1 to 3 seconds. The whole video aims for 30 to 60 seconds.
//    Too long: ordinary guesses get squeezed into fast-forward bursts until it
//    fits. Too short: beats stretch a little, but nothing is padded with
//    empty time.
//  * Solved: the last tile is the gold answer. Revealed: the last tile is a
//    dim "?" and there is no gold.
//
//  Shape crosses over, content never does (see RevealShareCard.swift): this
//  file decides WHEN a guessed word may be shown, never what the words mean.
//  Each guess event may carry the word the player typed as a label. On a
//  daily round the answer and the closest guesses are masked here, once,
//  when the timeline is built, so no later layer can leak them. On a
//  practice round everything shows.
//

import Foundation

// MARK: - Heat bands

/// The heat bands, coldest first. Thresholds mirror `HunchTheme.rankLabel`.
nonisolated enum ReplayBand: Int, Comparable, CaseIterable, Sendable {
    case cold, cool, warm, hot, boiling, solved

    init(rank: Int) {
        switch rank {
        case 1:          self = .solved
        case 2...25:     self = .boiling
        case 26...100:   self = .hot
        case 101...400:  self = .warm
        case 401...1200: self = .cool
        default:         self = .cold     // also rank 0 ("not ready yet")
        }
    }

    static func < (lhs: ReplayBand, rhs: ReplayBand) -> Bool { lhs.rawValue < rhs.rawValue }

    /// The canonical HunchTheme token, for `Loc.heat(_:)`.
    var token: String {
        switch self {
        case .cold:    return "Cold"
        case .cool:    return "Cool"
        case .warm:    return "Warm"
        case .hot:     return "Hot"
        case .boiling: return "Boiling"
        case .solved:  return "Solved!"
        }
    }
}

// MARK: - Inputs

/// How a Keeper verdict should be colored. The label itself is already
/// localized by the caller (`GameViewModel.displayVerdict`).
nonisolated enum ReplayVerdictTone: Equatable, Sendable {
    case yes, no, sortOf, other

    init(token: String) {
        switch token.lowercased() {
        case "yes":     self = .yes
        case "no":      self = .no
        case "sort of": self = .sortOf
        default:        self = .other
        }
    }
}

nonisolated struct ReplayVerdict: Equatable, Sendable {
    let tone: ReplayVerdictTone
    let label: String
}

/// One thing the player did, in play order.
nonisolated enum ReplayEvent: Equatable, Sendable {
    /// A scored guess. 1 = the answer, 0 = rank list not ready. `label` is
    /// the word the player typed, in the play language.
    case guess(rank: Int, label: String? = nil)
    case question(ReplayVerdict)
}

// MARK: - Spoilers

/// Which words a replay may print. Decided once, from the game mode.
nonisolated struct ReplayWordPolicy: Equatable, Sendable {
    /// True on a practice round: the answer may appear on the final tile and
    /// the end card, and every guess shows its word. False on a daily round:
    /// the answer never appears anywhere and the closest guesses are masked.
    var showAnswer: Bool
    /// The answer, for the final tile and the end card. Only used when
    /// `showAnswer` is true; a revealed round has no rank-1 event to take it
    /// from.
    var answer: String? = nil

    static let hideAnswer = ReplayWordPolicy(showAnswer: false)
}

nonisolated enum ReplaySpoiler {
    /// On a round where the answer must stay secret (today's daily), a guess
    /// ranked this close or closer is masked: its rank and heat still show,
    /// but the word is drawn as dots, because "coral #3" gives the word
    /// away. Rank 1 is the answer itself; 2 to 11 are the ten closest words.
    /// One edit here changes the rule on iOS; keep timeline.ts's
    /// SPOILER_RANK_LIMIT the same.
    static let rankLimit = 11

    /// Whether a daily replay must hide this guess's word.
    static func isSpoiler(rank: Int) -> Bool {
        rank > 0 && rank <= rankLimit
    }
}

nonisolated enum ReplayOutcome: Equatable, Sendable {
    case solved
    case revealed
}

// MARK: - Tiles

nonisolated struct ReplayTile: Equatable, Sendable {

    nonisolated enum Emphasis: Equatable, Sendable {
        /// Did not beat the best so far.
        case dip
        /// Closer than anything before it.
        case newBest
        /// A new best two or more heat bands hotter than the old best.
        case bigJump(from: ReplayBand)

        var isBigJump: Bool {
            if case .bigJump = self { return true }
            return false
        }
    }

    nonisolated enum Kind: Equatable, Sendable {
        case guess(Emphasis)
        /// Solved: the gold goal tile.
        case answer
        /// Gave up: a dim "?" in the last slot.
        case revealed
    }

    /// Board cell along the snake path. Equal to the tile's index.
    let slot: Int
    /// 1-based guess number, nil for the revealed "?".
    let guessNumber: Int?
    /// 1 for the answer, 0 for the revealed "?" (or a rank that was not ready).
    let rank: Int
    let kind: Kind
    /// The word to print on the tile, or nil when there is none to print.
    /// For the answer and revealed tiles this is the answer, set only when
    /// the timeline's `showAnswer` is true.
    var label: String? = nil
    /// True when the word was withheld as a spoiler: draw dots in its place.
    var masked: Bool = false
    /// When the tile starts popping in (seconds from the start of the video).
    var landsAt: Double = 0
    /// How long Wick takes to hop from this tile's cell to the next one.
    /// 0 for the last tile: Wick stays standing on it.
    var hop: Double = 0

    var band: ReplayBand { kind == .revealed ? .cold : ReplayBand(rank: rank) }

    var emphasis: Emphasis? {
        if case .guess(let e) = kind { return e }
        return nil
    }
}

// MARK: - Beats

nonisolated struct ReplayBeat: Equatable, Sendable {

    nonisolated enum Kind: Equatable, Sendable {
        /// Title fades in, Wick drops onto the first cell.
        case intro
        /// Places these tile slots. Two or more is a fast-forward burst.
        case place([Int])
        /// Wick's speech bubble with the verdicts of questions asked in a row.
        case keeper([ReplayVerdict])
        /// The last tile (gold answer or "?") rises under Wick.
        case finale(ReplayOutcome)
        /// "Play free at guesswick.com".
        case endCard
    }

    let kind: Kind
    let start: Double
    let duration: Double
    var end: Double { start + duration }
}

// MARK: - Pacing

/// Every timing knob in one place. Tests pass custom values to check the
/// compression and stretching rules in isolation.
nonisolated struct ReplayPacing: Equatable, Sendable {
    var intro = 1.5
    var dip = 1.0
    var newBest = 1.5
    var bigJump = 2.5
    var keeper = 1.2
    var finale = 3.0
    var endCard = 3.0
    /// A burst of n tiles lasts burstBase + burstPerTile * n, capped at maxBeat.
    var burstBase = 1.2
    var burstPerTile = 0.12
    /// Quiet time at the end of a burst so the last tile can settle.
    var burstTail = 0.25
    var maxBeat = 3.0
    var minTotal = 30.0
    var maxTotal = 60.0
    /// Short rounds stretch each beat by at most this factor.
    var maxStretch = 1.6
    /// Wick crouches this long before each hop.
    var hopLead = 0.12
    /// A normal hop from one cell to the next.
    var hop = 0.4
    /// When the finale's last tile rises, measured from the finale's start.
    var finaleLand = 0.45

    static let standard = ReplayPacing()
}

// MARK: - Timeline

nonisolated struct ReplayTimeline: Equatable, Sendable {
    /// Every tile in slot order. The last one is the answer or the "?".
    let tiles: [ReplayTile]
    let beats: [ReplayBeat]
    let outcome: ReplayOutcome
    /// Whether the answer may be drawn (final tile, end card). See
    /// ReplayWordPolicy.
    var showAnswer: Bool = false
    /// The answer for the end card. Always nil when `showAnswer` is false.
    var answer: String? = nil

    var duration: Double { beats.last?.end ?? 0 }
    var finalSlot: Int { tiles.count - 1 }
    /// Guesses in the round, including the answer when solved.
    var totalGuesses: Int { tiles.compactMap(\.guessNumber).max() ?? 0 }

    /// The beat playing at time t. Before 0 is the first beat, after the end
    /// is the last one, so the final frame holds.
    func beatIndex(at t: Double) -> Int? {
        guard !beats.isEmpty else { return nil }
        for (i, b) in beats.enumerated() where t < b.end { return i }
        return beats.count - 1
    }

    /// Tiles that have started landing by time t. Tiles land in slot order.
    func landedCount(at t: Double) -> Int {
        var n = 0
        for tile in tiles where tile.landsAt <= t { n += 1 }
        return n
    }

    /// The best (lowest) rank on the board at time t, nil before any guess.
    func bestRank(at t: Double) -> Int? {
        var best: Int?
        for tile in tiles where tile.landsAt <= t && tile.rank > 0 {
            best = min(best ?? .max, tile.rank)
        }
        return best
    }

    /// The highest guess number on the board at time t.
    func guessesShown(at t: Double) -> Int {
        var shown = 0
        for tile in tiles where tile.landsAt <= t {
            if let n = tile.guessNumber { shown = max(shown, n) }
        }
        return shown
    }

    /// Where Wick is: hopping `from` one cell `to` the next, `progress` 0...1.
    /// When he is standing still, from == to.
    nonisolated struct Travel: Equatable, Sendable {
        let from: Int
        let to: Int
        let progress: Double
    }

    func wickTravel(at t: Double) -> Travel {
        var last: ReplayTile?
        for tile in tiles {
            if tile.landsAt <= t { last = tile } else { break }
        }
        guard let tile = last else { return Travel(from: 0, to: 0, progress: 1) }
        guard tile.slot < finalSlot, tile.hop > 0 else {
            return Travel(from: tile.slot, to: tile.slot, progress: 1)
        }
        let p = (t - tile.landsAt) / tile.hop
        if p >= 1 { return Travel(from: tile.slot + 1, to: tile.slot + 1, progress: 1) }
        return Travel(from: tile.slot, to: tile.slot + 1, progress: max(0, p))
    }

    // MARK: - Building

    /// Builds the replay, or returns nil when there is nothing to show (a
    /// reveal with no scored guesses).
    static func build(events: [ReplayEvent],
                      outcome: ReplayOutcome,
                      pacing: ReplayPacing = .standard,
                      words: ReplayWordPolicy = .hideAnswer) -> ReplayTimeline? {

        // 1. Walk the events into tiles and the "middle" units between the
        //    intro and the finale.
        var tiles: [ReplayTile] = []
        var units: [Unit] = []
        var verdicts: [ReplayVerdict] = []
        var best = Int.max
        var guessNumber = 0
        var answerNumber: Int?
        let showAnswer = words.showAnswer
        var answer: String? = showAnswer ? words.answer : nil

        func flushVerdicts() {
            guard !verdicts.isEmpty else { return }
            units.append(.keeper(verdicts))
            verdicts = []
        }

        walk: for event in events {
            switch event {
            case .question(let v):
                verdicts.append(v)

            case .guess(let rank, let label):
                if rank == 1 {
                    // The answer ends a solved round. On a revealed round it
                    // cannot happen, so it is ignored rather than trusted.
                    if outcome == .solved {
                        answerNumber = guessNumber + 1
                        if showAnswer, answer == nil { answer = label }
                        break walk
                    }
                    continue
                }
                guessNumber += 1
                flushVerdicts()

                let emphasis: ReplayTile.Emphasis
                if rank > 0 && rank < best {
                    let oldBand = ReplayBand(rank: best)
                    let jumped = best != .max
                        && ReplayBand(rank: rank).rawValue - oldBand.rawValue >= 2
                    emphasis = jumped ? .bigJump(from: oldBand) : .newBest
                    best = rank
                } else {
                    emphasis = .dip
                }
                let masked = !showAnswer && ReplaySpoiler.isSpoiler(rank: rank)
                tiles.append(ReplayTile(slot: tiles.count, guessNumber: guessNumber,
                                        rank: rank, kind: .guess(emphasis),
                                        label: masked ? nil : label, masked: masked))
                units.append(.tile(tiles.count - 1))
            }
        }
        // Questions after the last guess still get their bubble.
        flushVerdicts()

        switch outcome {
        case .solved:
            tiles.append(ReplayTile(slot: tiles.count,
                                    guessNumber: answerNumber ?? guessNumber + 1,
                                    rank: 1, kind: .answer,
                                    label: answer, masked: !showAnswer))
        case .revealed:
            guard !tiles.isEmpty else { return nil }
            tiles.append(ReplayTile(slot: tiles.count, guessNumber: nil,
                                    rank: 0, kind: .revealed,
                                    label: answer, masked: !showAnswer))
        }

        // 2. Fit the middle into the time budget, compressing as little as
        //    possible. Levels go from gentle to aggressive; within a level,
        //    bursts grow until it fits.
        let fixed = pacing.intro + pacing.finale + pacing.endCard
        let budget = max(0, pacing.maxTotal - fixed)
        var middle: [Middle] = []
        search: for level in Level.allCases {
            for size in burstSizes {
                middle = compose(units, tiles: tiles, level: level, maxBurst: size, pacing: pacing)
                if total(middle) <= budget + 1e-9 { break search }
            }
        }

        // 3. Short round: stretch a little toward the minimum, never padding.
        let middleTotal = total(middle)
        if middleTotal > 0, fixed + middleTotal < pacing.minTotal {
            let factor = min(pacing.maxStretch, (pacing.minTotal - fixed) / middleTotal)
            middle = middle.map { m in
                var m = m
                m.duration = max(m.duration, min(pacing.maxBeat, m.duration * factor))
                return m
            }
        }

        // 4. Lay the beats end to end and schedule each tile's landing.
        var beats: [ReplayBeat] = [ReplayBeat(kind: .intro, start: 0, duration: pacing.intro)]
        var t = pacing.intro
        for m in middle {
            let beat = ReplayBeat(kind: m.kind, start: t, duration: m.duration)
            if case .place(let slots) = m.kind {
                schedule(slots, in: beat, tiles: &tiles, pacing: pacing)
            }
            beats.append(beat)
            t += m.duration
        }

        tiles[tiles.count - 1].landsAt = t + pacing.finaleLand
        tiles[tiles.count - 1].hop = 0
        beats.append(ReplayBeat(kind: .finale(outcome), start: t, duration: pacing.finale))
        t += pacing.finale
        beats.append(ReplayBeat(kind: .endCard, start: t, duration: pacing.endCard))

        return ReplayTimeline(tiles: tiles, beats: beats, outcome: outcome,
                              showAnswer: showAnswer, answer: answer)
    }

    // MARK: - Building helpers

    private nonisolated enum Unit {
        case tile(Int)
        case keeper([ReplayVerdict])
    }

    private nonisolated struct Middle {
        var kind: ReplayBeat.Kind
        var duration: Double
    }

    /// Compression levels, gentlest first.
    private nonisolated enum Level: CaseIterable {
        /// Only dips can be merged into bursts. Keeper bubbles stay.
        case dips
        /// Same, but Keeper bubbles are dropped.
        case dipsNoKeeper
        /// Everything except big jumps can be merged.
        case allButBigJumps

        func canBurst(_ e: ReplayTile.Emphasis) -> Bool {
            switch self {
            case .dips, .dipsNoKeeper: return e == .dip
            case .allButBigJumps:      return !e.isBigJump
            }
        }

        var keepsKeeper: Bool { self == .dips }
    }

    /// Largest burst tried at each step. 1 means no merging at all.
    private static let burstSizes = [1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 128, Int.max]

    private static func total(_ middle: [Middle]) -> Double {
        middle.reduce(0) { $0 + $1.duration }
    }

    private static func singleDuration(_ e: ReplayTile.Emphasis, _ p: ReplayPacing) -> Double {
        switch e {
        case .dip:     return p.dip
        case .newBest: return p.newBest
        case .bigJump: return p.bigJump
        }
    }

    static func burstDuration(_ count: Int, _ p: ReplayPacing) -> Double {
        min(p.maxBeat, p.burstBase + p.burstPerTile * Double(count))
    }

    private static func compose(_ units: [Unit], tiles: [ReplayTile], level: Level,
                                maxBurst: Int, pacing: ReplayPacing) -> [Middle] {
        var out: [Middle] = []
        var run: [Int] = []

        func single(_ i: Int) -> Middle {
            Middle(kind: .place([tiles[i].slot]),
                   duration: singleDuration(tiles[i].emphasis ?? .dip, pacing))
        }

        // Splits a run of mergeable tiles into near-equal chunks no bigger
        // than maxBurst. A chunk of one plays as a normal beat.
        func flush() {
            guard !run.isEmpty else { return }
            let cap = max(1, min(maxBurst, run.count))
            let pieces = (run.count + cap - 1) / cap
            let base = run.count / pieces
            let extra = run.count % pieces
            var index = 0
            for p in 0..<pieces {
                let size = base + (p < extra ? 1 : 0)
                let chunk = Array(run[index..<(index + size)])
                index += size
                if chunk.count == 1 {
                    out.append(single(chunk[0]))
                } else {
                    out.append(Middle(kind: .place(chunk.map { tiles[$0].slot }),
                                      duration: burstDuration(chunk.count, pacing)))
                }
            }
            run = []
        }

        for unit in units {
            switch unit {
            case .tile(let i):
                if let e = tiles[i].emphasis, level.canBurst(e) {
                    run.append(i)
                } else {
                    flush()
                    out.append(single(i))
                }
            case .keeper(let verdicts):
                // A dropped bubble does not break a run of mergeable tiles.
                guard level.keepsKeeper else { continue }
                flush()
                out.append(Middle(kind: .keeper(verdicts), duration: pacing.keeper))
            }
        }
        flush()
        return out
    }

    /// Single tile: Wick crouches, hops off, the tile pops in where he stood.
    /// Burst: tiles land one after another and Wick dashes from cell to cell.
    private static func schedule(_ slots: [Int], in beat: ReplayBeat,
                                 tiles: inout [ReplayTile], pacing: ReplayPacing) {
        let lead = pacing.hopLead
        if slots.count == 1 {
            let s = slots[0]
            tiles[s].landsAt = beat.start + lead
            tiles[s].hop = min(pacing.hop, max(0.1, beat.duration - lead - 0.1))
            return
        }
        let usable = max(0.2, beat.duration - lead - pacing.burstTail)
        let step = usable / Double(slots.count)
        for (i, s) in slots.enumerated() {
            tiles[s].landsAt = beat.start + lead + step * Double(i)
            tiles[s].hop = step
        }
    }
}

// MARK: - Formatting

nonisolated enum ReplayFormat {
    /// Compact rank for a tile: "#14", "#340", "#2.3k", "#12k". Empty for 0.
    static func rank(_ rank: Int) -> String {
        guard rank > 0 else { return "" }
        if rank < 1000 { return "#\(rank)" }
        if rank < 10_000 {
            let tenths = Int((Double(rank) / 100).rounded())   // 2345 -> 23
            return tenths % 10 == 0 ? "#\(tenths / 10)k" : "#\(tenths / 10).\(tenths % 10)k"
        }
        return "#\(Int((Double(rank) / 1000).rounded()))k"
    }

    /// Meter fill 0...1 on a log scale. Same curve as `HunchTheme.rankFill`.
    static func fill(rank: Int, maxRank: Int) -> Double {
        guard rank > 0, maxRank > 1 else { return 0 }
        if rank == 1 { return 1 }
        let f = 1.0 - (log(Double(rank)) / log(Double(maxRank)))
        return max(0.04, min(1.0, f))
    }
}
