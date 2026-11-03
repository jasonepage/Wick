// SPDX-License-Identifier: MPL-2.0
//
//  RaceShowdown.swift
//  Hunch: Wick 3.8 Race Showdown
//
//  Everything the race screen shows about the duel, worked out from public
//  match state only: each seat's best warmth, guess counts, solve flags, the
//  server's clock and the final result. No guessed word, question or exact
//  score of the other player ever comes in here, so none can go out.
//
//  Pure functions plus three small state holders (Show, TrailRecorder,
//  RematchGate). Times are milliseconds on the caller's clock.
//
//  LOCKSTEP with wick-web/src/game/raceshow.ts: same names, same numbers.
//  HunchTests/RaceShowdownTests.swift and wick-web/tests/raceshow.test.ts
//  check the same cases.
//

import Foundation

nonisolated enum RaceShowdown {

    // MARK: Heat bands

    /// The public temperature of a seat, from its best warmth. Same cut points
    /// as the Wick moods (KeeperMood.forScore): 18, 30, 45, 60, 100.
    nonisolated enum Band: String, CaseIterable, Sendable {
        case searching, trail, heating, close, danger, solved

        /// The localization key for the band's label.
        var key: String {
            switch self {
            case .searching: return "raceBandSearching"
            case .trail:     return "raceBandTrail"
            case .heating:   return "raceBandHeating"
            case .close:     return "raceBandClose"
            case .danger:    return "raceBandDanger"
            case .solved:    return "raceBandSolved"
            }
        }

        /// A score inside the band. The opponent Wick and the heat-trail dots
        /// are painted from this, never from the real score.
        var paintScore: Double {
            switch self {
            case .searching: return 10
            case .trail:     return 24
            case .heating:   return 37
            case .close:     return 52
            case .danger:    return 75
            case .solved:    return 100
            }
        }
    }

    /// Warmth (0...1) as the server's whole-number score (0...100).
    static func pct(_ warmth: Double) -> Int {
        Int((min(1, max(0, warmth)) * 100).rounded())
    }

    static func band(_ bestWarmth: Double, solved: Bool = false) -> Band {
        let s = pct(bestWarmth)
        if solved || s >= 100 { return .solved }
        if s >= 60 { return .danger }
        if s >= 45 { return .close }
        if s >= 30 { return .heating }
        if s >= 18 { return .trail }
        return .searching
    }

    // MARK: Lead

    nonisolated enum Lead: String, Sendable {
        case you, them, tied
        var key: String {
            switch self {
            case .you:  return "raceYouLead"
            case .them: return "raceTheyLead"
            case .tied: return "raceTied"
            }
        }
    }

    /// Who leads, from each seat's BEST warmth. Equal whole-number scores tie,
    /// the same way the server breaks a timeout.
    static func lead(you: Double, them: Double) -> Lead {
        let a = pct(you), b = pct(them)
        return a > b ? .you : (a < b ? .them : .tied)
    }

    // MARK: Phases and the clock

    static let finalMinuteMs = 60_000
    static let final15Ms = 15_000
    static let finalCountMs = 5_000

    nonisolated enum Phase: String, Sendable {
        case opening, finalMinute, final15, expired, result
    }

    /// The presentation phase from the server's remaining time. `.expired`
    /// means time is up but the result has not arrived: nobody has won yet.
    static func phase(remainingMs: Int, hasResult: Bool) -> Phase {
        if hasResult { return .result }
        if remainingMs <= 0 { return .expired }
        if remainingMs <= final15Ms { return .final15 }
        if remainingMs <= finalMinuteMs { return .finalMinute }
        return .opening
    }

    /// Which dance vocabulary each phase uses. nil = hold still.
    static func dance(_ phase: Phase) -> WickMotion.DanceStyle? {
        switch phase {
        case .opening:     return .groove
        case .finalMinute: return .swagger
        case .final15:     return .hype
        default:           return nil
        }
    }

    /// The last server clock and when (local time, ms) it arrived.
    nonisolated struct ClockFix: Equatable, Sendable {
        var elapsedMs: Int
        var remainingMs: Int
        var at: Double
    }

    /// The server clock carried forward to `now` between snapshots.
    static func clock(_ fix: ClockFix, now: Double) -> (elapsedMs: Int, remainingMs: Int) {
        let d = Int(max(0, now - fix.at))
        return (fix.elapsedMs + d, max(0, fix.remainingMs - d))
    }

    /// m:ss, rounded up so the clock reads 0:00 only when time is really up.
    static func fmtClock(_ ms: Int) -> String {
        let total = (max(0, ms) + 999) / 1000
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// m:ss of race time used (rounded down), for the recap's finish time.
    static func fmtElapsed(_ ms: Int) -> String {
        let total = max(0, ms) / 1000
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// 5, 4, 3, 2, 1 in the last five seconds, else nil.
    static func finalCount(_ remainingMs: Int) -> Int? {
        remainingMs > 0 && remainingMs <= finalCountMs ? (remainingMs + 999) / 1000 : nil
    }

    /// How much larger the timer is in the final 15 seconds.
    static let timerGrow = 1.18
    static let timerPulseMs = 260.0

    /// One restrained pulse each time the final-15 timer ticks to a new second.
    /// Reduced Motion: no scale change, only a short brightness dip.
    static func timerPulse(_ remainingMs: Int, rm: Bool) -> (scale: Double, opacity: Double) {
        guard remainingMs > 0, remainingMs <= final15Ms else { return (1, 1) }
        let since = Double((1000 - remainingMs % 1000) % 1000)
        let k = since < timerPulseMs ? 1 - WickMotion.smoother(since / timerPulseMs) : 0
        return rm ? (1, 1 - 0.3 * k) : (1 + 0.06 * k, 1)
    }

    // MARK: Face-off

    /// The face-off plays over the first three seconds of the real race clock.
    static let faceOffMs = 3_000
    /// "GUESS" holds this long after 1.
    static let faceOffGoMs = 700

    /// 3, 2, 1, then 0 for "GUESS", then nil when the face-off is over.
    static func faceOffStep(_ elapsedMs: Int) -> Int? {
        if elapsedMs < 1000 { return 3 }
        if elapsedMs < 2000 { return 2 }
        if elapsedMs < faceOffMs { return 1 }
        if elapsedMs < faceOffMs + faceOffGoMs { return 0 }
        return nil
    }

    /// Only a match first seen inside its opening three seconds gets it.
    static func faceOffEligible(_ firstElapsedMs: Int) -> Bool { firstElapsedMs < faceOffMs }

    /// A small pose added on top of a Wick's motion (WickMotion channel units).
    nonisolated struct Stance: Equatable, Sendable {
        var gx = 0.0, tip = 0.0, sx = 0.0, sy = 0.0
    }

    static let faceOffGlance = 7.0
    static let faceOffLean = 0.22
    static let faceOffPulseMs = 220.0

    /// The face-off pose. `side` is the direction of the other Wick: +1 for
    /// the local seat, -1 for the opponent seat. Reduced Motion keeps only the
    /// pupil glance, which is a face change.
    static func faceOffStance(_ elapsedMs: Double, side: Double, rm: Bool) -> Stance {
        var out = Stance()
        let f = Double(faceOffMs)
        guard elapsedMs >= 0, elapsedMs < f + 200 else { return out }
        let w = WickMotion.smoother(elapsedMs / 250) * (1 - WickMotion.smoother((elapsedMs - f) / 200))
        out.gx = faceOffGlance * side * w
        if rm { return out }
        out.tip = faceOffLean * side * w
        for k in 0...3 {
            let e = elapsedMs - Double(k) * 1000
            if e >= 0 && e < faceOffPulseMs {
                let p = sin(Double.pi * e / faceOffPulseMs)
                out.sx += 0.03 * p
                out.sy -= 0.045 * p
            }
        }
        return out
    }

    /// The loser's one annoyed side-eye toward the winner (local seat).
    static let sideEye = Stance(gx: 6, tip: 0, sx: 0, sy: 0)

    // MARK: Momentum events and announcements

    nonisolated enum Momentum: String, Sendable {
        case youHotter, closingIn, deadHeat, suddenHeat, finalMinute, final15

        var key: String {
            switch self {
            case .youHotter:   return "raceYoureHotter"
            case .closingIn:   return "raceClosingIn"
            case .deadHeat:    return "raceDeadHeat"
            case .suddenHeat:  return "raceSuddenHeat"
            case .finalMinute: return "raceFinalMinute"
            case .final15:     return "race15Seconds"
            }
        }

        /// When two events want the one slot, the higher rank keeps it.
        var rank: Int {
            switch self {
            case .final15:                         return 4
            case .suddenHeat:                      return 3
            case .youHotter, .closingIn, .deadHeat: return 2
            case .finalMinute:                     return 1
            }
        }
    }

    static let momentumShowMs = 800.0
    static let momentumGapMs = 2_000.0
    static let voiceGapMs = 5_000.0

    nonisolated struct Input: Sendable {
        var now: Double
        var youBest: Double
        var themBest: Double
        var youSolved = false
        var themSolved = false
        var remainingMs: Int
        var result = false
    }

    nonisolated struct Frame: Equatable, Sendable {
        var lead: Lead
        var leadChanged: Bool
        /// The Wick that just took the lead gets one attention accent.
        var accent: Lead?
        var event: Momentum?
        var eventAt: Double
        /// Localization keys to speak to VoiceOver on this update.
        var voice: [String]
        var leadChanges: Int
    }

    private static func stillTrue(_ ev: Momentum, lead: Lead, remainingMs: Int) -> Bool {
        switch ev {
        case .youHotter: return lead == .you
        case .closingIn: return lead == .them
        case .deadHeat:  return lead == .tied
        case .final15:   return remainingMs > 0
        default:         return true
        }
    }

    /// The race's momentum events, lead accents and VoiceOver lines. Feed it
    /// public state on every snapshot, scored guess and clock tick.
    nonisolated struct Show: Sendable {
        private var started = false
        private var lead: Lead = .tied
        private var lastLeader: Lead? = nil
        private var changes = 0
        private var suddenDone = false
        private var minuteDone = false
        private var fifteenDone = false
        private var show: (event: Momentum, at: Double)? = nil
        private var lastShowAt = -Double.infinity
        private var pending: Momentum? = nil
        private var voicedLead: Lead = .tied
        private var lastVoiceAt = -Double.infinity
        private var over = false

        init() {}

        private mutating func offer(_ ev: Momentum, _ now: Double) {
            if show == nil && now - lastShowAt >= RaceShowdown.momentumGapMs {
                show = (ev, now)
                lastShowAt = now
                return
            }
            if pending == nil || ev.rank >= pending!.rank { pending = ev }
        }

        mutating func update(_ inp: Input) -> Frame {
            let now = inp.now
            let youB = inp.youSolved ? 1 : inp.youBest
            let themB = inp.themSolved ? 1 : inp.themBest
            let lead = RaceShowdown.lead(you: youB, them: themB)
            var voice: [String] = []
            var leadChanged = false
            var accent: Lead? = nil

            // A solve or the result outranks everything.
            if inp.result || inp.youSolved || inp.themSolved { over = true }
            if over {
                show = nil
                pending = nil
                self.lead = lead
                return Frame(lead: lead, leadChanged: false, accent: nil, event: nil, eventAt: 0,
                             voice: voice, leadChanges: changes)
            }

            // Retire the event on screen, then let a waiting one in after the
            // gap (dropped if the race has moved on), then take this update's news.
            if let s = show, now - s.at >= RaceShowdown.momentumShowMs { show = nil }
            if show == nil, let ev = pending, now - lastShowAt >= RaceShowdown.momentumGapMs {
                pending = nil
                if RaceShowdown.stillTrue(ev, lead: lead, remainingMs: inp.remainingMs) {
                    show = (ev, now)
                    lastShowAt = now
                }
            }

            if !started {
                started = true
                self.lead = lead
                voicedLead = lead
                if lead != .tied { lastLeader = lead }
            } else if lead != self.lead {
                leadChanged = true
                self.lead = lead
                if lead != .tied {
                    accent = lead
                    if let last = lastLeader, last != lead { changes += 1 }
                    lastLeader = lead
                }
                offer(lead == .you ? .youHotter : (lead == .them ? .closingIn : .deadHeat), now)
            }

            if !suddenDone && RaceShowdown.band(youB) == .danger && RaceShowdown.band(themB) == .danger {
                suddenDone = true
                offer(.suddenHeat, now)
            }

            let phase = RaceShowdown.phase(remainingMs: inp.remainingMs, hasResult: false)
            if !minuteDone && (phase == .finalMinute || phase == .final15) {
                minuteDone = true
                // A match resumed inside the last 15 seconds skips to 15 SECONDS.
                if phase == .finalMinute { offer(.finalMinute, now); voice.append(Momentum.finalMinute.key) }
            }
            if !fifteenDone && phase == .final15 {
                fifteenDone = true
                offer(.final15, now)
                voice.append(Momentum.final15.key)
            }

            // VoiceOver: the current lead, once it differs from the last one
            // spoken and five seconds have passed since then.
            if lead != voicedLead && now - lastVoiceAt >= RaceShowdown.voiceGapMs {
                voice.insert(lead.key, at: 0)
                voicedLead = lead
                lastVoiceAt = now
            }

            return Frame(lead: lead, leadChanged: leadChanged, accent: accent,
                         event: show?.event, eventAt: show?.at ?? 0,
                         voice: voice, leadChanges: changes)
        }
    }

    // MARK: Heat trails

    /// Band transitions for both seats, this match only. Never scores.
    nonisolated struct TrailRecorder: Equatable, Sendable {
        private(set) var you: [Band] = []
        private(set) var them: [Band] = []

        /// Record a seat's band (only once it has guessed at all).
        mutating func push(_ side: Lead, _ band: Band, guessCount: Int) {
            guard guessCount > 0 else { return }
            if side == .you {
                if you.last != band { you.append(band) }
            } else if them.last != band {
                them.append(band)
            }
        }
    }

    static let trailCap = 8

    /// At most eight nodes, the share card's way: the first, the last and the
    /// ones between spread evenly.
    static func capTrail(_ trail: [Band], _ n: Int = trailCap) -> [Band] {
        guard trail.count > n else { return trail }
        var out: [Band] = []
        for i in 0..<n {
            let idx = Int((Double(i) * Double(trail.count - 1) / Double(n - 1)).rounded())
            out.append(trail[idx])
        }
        out[n - 1] = trail[trail.count - 1]
        return out
    }

    // MARK: The opponent seat

    /// What the opponent's seat may show. Built field by field from the public
    /// snapshot, so nothing else can reach the screen.
    nonisolated struct OpponentSeat: Equatable, Sendable {
        var band: Band
        var guessCount: Int
        /// The score that paints the opponent Wick: its band's, or nil before
        /// it has guessed (resting purple).
        var paintScore: Double?
        var solved: Bool
        var connected: Bool
    }

    static func opponentSeat(bestWarmth: Double, guessCount: Int, solved: Bool, connected: Bool) -> OpponentSeat {
        let count = max(0, guessCount)
        let b = band(bestWarmth, solved: solved)
        return OpponentSeat(band: b, guessCount: count,
                            paintScore: count > 0 || solved ? b.paintScore : nil,
                            solved: solved, connected: connected)
    }

    // MARK: Result and recap

    nonisolated enum Outcome: String, Sendable { case win, loss, draw, void }
    /// Solved races get the new 3.8 lines; every other ending keeps its copy.
    nonisolated enum Headline: String, Sendable { case turnedGreen, gotThereFirst, won, lost, draw, void }

    nonisolated struct RecapPlayer: Sendable {
        var id: String
        var solvedAtMs: Int?
        var bestWarmth: Double
        var guessCount: Int
    }

    nonisolated struct Recap: Equatable, Sendable {
        var outcome: Outcome
        var headline: Headline
        var youGreen: Bool
        var themGreen: Bool
        var youBand: Band
        var themBand: Band
        var youGuesses: Int
        var themGuesses: Int
        /// The winning solve time, or nil when nobody solved.
        var finishMs: Int?
    }

    /// `reason` is the EndReason raw value: solved, timeout, forfeit or void.
    static func recap(reason: String, winner: String?, draw: Bool, players: [RecapPlayer], myId: String) -> Recap {
        let me = players.first { $0.id == myId }
        let them = players.first { $0.id != myId }
        let outcome: Outcome = reason == "void" ? .void
            : (draw || winner == nil) ? .draw
            : (winner == myId ? .win : .loss)
        let youGreen = me?.solvedAtMs != nil
        let themGreen = them?.solvedAtMs != nil
        let headline: Headline
        switch outcome {
        case .void: headline = .void
        case .draw: headline = .draw
        default:
            if reason == "solved" { headline = outcome == .win ? .turnedGreen : .gotThereFirst }
            else { headline = outcome == .win ? .won : .lost }
        }
        let winnerP = winner.flatMap { w in players.first { $0.id == w } }
        return Recap(outcome: outcome, headline: headline, youGreen: youGreen, themGreen: themGreen,
                     youBand: band(me?.bestWarmth ?? 0, solved: youGreen),
                     themBand: band(them?.bestWarmth ?? 0, solved: themGreen),
                     youGuesses: me?.guessCount ?? 0, themGuesses: them?.guessCount ?? 0,
                     finishMs: reason == "solved" ? winnerP?.solvedAtMs : nil)
    }

    // MARK: Rematch

    /// One rematch request per recap: a second tap does nothing.
    nonisolated struct RematchGate: Sendable {
        private(set) var requested = false
        init() {}
        /// True the first time; false for every tap after it.
        mutating func request() -> Bool {
            if requested { return false }
            requested = true
            return true
        }
        mutating func reset() { requested = false }
    }

    /// Every localization key the race uses (the tests check each table).
    static var keys: [String] {
        ["raceFaceOffTitle", "raceFaceOffGo", "raceFoundVoice"]
        + Band.allCases.map(\.key)
        + [Lead.you.key, Lead.them.key, Lead.tied.key]
        + [Momentum.youHotter, .closingIn, .deadHeat, .suddenHeat, .finalMinute, .final15].map(\.key)
        + ["raceYouTurnedGreen", "raceTheyGotThere", "raceSomeoneNew", "raceRematch", "raceSeatYou", "raceSeatOpponent",
           "raceReconnecting", "raceSeatVoice",
           "raceRecapFinish", "raceRecapGuesses", "raceRecapBest", "raceRecapLeadChanges",
           "raceRecapTrail", "raceShareResult", "raceShareWon", "raceShareLost", "raceShareDraw",
           "raceWaitingRematch", "raceConnLostTitle", "raceConnLostBody", "raceTimeUpWaiting"]
    }
}
