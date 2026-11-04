//
//  LiveDuelViewModel.swift
//  Hunch — Wick 3.0 live multiplayer
//
//  The screen-facing state for a live duel. Owns a MatchClient, translates its
//  frames into published state, and exposes intent methods (find / guess / ask /
//  leave). SwiftUI observes this; it never sees a raw frame.
//
//  Server-authoritative by design (C8): warmth for a guess arrives later via a
//  `scored` frame (shown as "…" until then — no misleading placeholder number),
//  and solve/timing are decided by the server. Asking Wick costs time, not
//  warmth — the bar only moves on guesses.
//

import Foundation
import Combine
import UIKit

@MainActor
final class LiveDuelViewModel: ObservableObject, MatchClientDelegate {

    enum Phase: Equatable {
        case idle          // not connected
        case searching     // queued, waiting for a pairing
        case playing       // paired, match live
        case finished      // result is in
        case disconnected  // dropped / errored out
    }

    struct Guess: Identifiable, Equatable {
        let id = UUID()
        let word: String
        var warmth: Double?   // nil = server hasn't scored it yet
        var rank: Int?        // Contexto rank (# closer words), when available
        var correct: Bool
    }

    struct Reply: Identifiable, Equatable {
        let id = UUID()
        let question: String
        var verdict: String   // "…" while the Keeper is thinking
        var text: String
        var pending: Bool
    }

    // MARK: Published state
    @Published private(set) var phase: Phase = .idle {
        // 3.5 race music: plays while a match is live, on every path in or out
        // (paired, resumed, finished, left, dropped).
        didSet {
            guard phase != oldValue else { return }
            if phase == .playing { RaceMusic.shared.start() } else { RaceMusic.shared.stop() }
        }
    }
    @Published private(set) var guesses: [Guess] = []
    @Published private(set) var replies: [Reply] = []
    @Published private(set) var snapshot: StateSnapshot?
    @Published private(set) var opponentKind: OpponentKind?
    /// 3.3 shared start: when the next Quick Match race starts, from the server's
    /// wait duration (not its wall clock, so a skewed device clock can't break it).
    /// nil for friend matches and before the server has replied.
    @Published private(set) var startsAt: Date?
    @Published private(set) var result: MatchResult?
    /// The secret, revealed by the server once the match ends.
    @Published private(set) var revealedWord: String?
    /// In a cross-language race: the opponent's form of the word and their
    /// language's name, for the end screen. nil when both played the same language.
    @Published private(set) var opponentWord: (word: String, language: String)?
    @Published private(set) var banner: String?

    // MARK: 3.8 Race Showdown state (RaceShowdown.swift does the thinking)

    /// The latest momentum frame: lead, the event on screen, lead changes.
    @Published private(set) var raceFrame: RaceShowdown.Frame?
    /// The presentation phase from the server's remaining time.
    @Published private(set) var racePhase: RaceShowdown.Phase = .opening
    /// This match opened inside its first three seconds: play the face-off.
    @Published private(set) var faceOff = false
    /// Reaction cues for the two seat Wicks (a scored guess, a new lead).
    @Published private(set) var youCue = 0
    @Published private(set) var youCueKind: String? = nil
    @Published private(set) var oppCue = 0
    @Published private(set) var oppCueKind: String? = nil
    /// Everything the recap shows, captured when the result lands. It stays
    /// on screen while a friend rematch waits for the other player.
    @Published private(set) var recapInfo: RecapInfo?
    /// A friend rematch was tapped and is waiting for the other player.
    @Published private(set) var waitingRematch = false

    struct RecapInfo {
        var recap: RaceShowdown.Recap
        var reason: EndReason
        var word: String?
        var opponentWord: (word: String, language: String)?
        var leadChanges: Int
        var youTrail: [RaceShowdown.Band]
        var themTrail: [RaceShowdown.Band]
        /// The local Wick's last non-solved score, for where his color starts.
        var youStartScore: Double?
        /// 3.9: your own scored guesses, oldest first, for your Path Card.
        var youScores: [Double]
        /// 3.9: the two routes side by side, when the race data supports it.
        var comparison: RouteAnalysis.Comparison?
    }

    private var raceShow = RaceShowdown.Show()
    private var trails = RaceShowdown.TrailRecorder()
    /// 3.9: the opponent's public progress, one sample per guess.
    private var oppProgress = RouteAnalysis.ProgressRecorder()
    private var clockFix: RaceShowdown.ClockFix?
    private var oppSeen = 0
    private var rematchGate = RaceShowdown.RematchGate()
    private var raceTask: Task<Void, Never>?

    /// This device's player id (used to read the winner out of a result).
    let myId = LiveConfig.kid

    private var client: MatchClient?
    private var requestedMode: MatchMode = .casual
    private var requestedFriendCode: String?
    private var requestedCreate: Bool?

    /// Whether this search is a private friend match (drives the searching copy).
    private(set) var isFriendMatch = false
    /// True when THIS device created the invite — the searching screen then shows
    /// the code + a Share affordance instead of "finding an opponent" (3.1).
    private(set) var isHosting = false

    /// The friend/invite code for this search (nil for Quick Match) — the view uses
    /// it to build the shareable link.
    var friendCode: String? { requestedFriendCode }

    // MARK: Derived helpers

    var isSolvedByMe: Bool { snapshot?.you.solved ?? false }
    var opponentWarmth: Double { snapshot?.opponent.bestWarmth ?? 0 }
    var opponentGuesses: Int { snapshot?.opponent.guessCount ?? 0 }
    var remainingMs: Int { snapshot?.clock.remainingMs ?? 0 }

    /// True only once a result exists AND this device is the winner.
    var didIWin: Bool {
        guard let result else { return false }
        return result.winner == myId
    }
    var isDraw: Bool { result?.draw ?? false }

    /// Warmer/colder read on the latest scored guess — drives the hero pill,
    /// like the single-player board's trajectory.
    enum Trajectory { case first, closest, colder }
    var latestTrajectory: Trajectory? {
        guard let latest = guesses.first, let w = latest.warmth, !latest.correct else { return nil }
        let others = guesses.dropFirst().compactMap { $0.warmth }
        if others.isEmpty { return .first }
        return w >= (others.max() ?? 0) ? .closest : .colder
    }

    // MARK: Race Showdown helpers

    /// Milliseconds on the wall clock: the race state's time base.
    nonisolated static func nowMs() -> Double { Date().timeIntervalSince1970 * 1000 }

    /// The server clock carried forward to `now`, or nil before the first snapshot.
    func raceClock(_ now: Double = LiveDuelViewModel.nowMs()) -> (elapsedMs: Int, remainingMs: Int)? {
        clockFix.map { RaceShowdown.clock($0, now: now) }
    }

    /// The local seat's best warmth (0...1): the server's, or a fresher scored guess.
    var youBest: Double {
        max(snapshot?.you.bestWarmth ?? 0, (guesses.compactMap { $0.warmth }.max() ?? 0) / 100)
    }
    var youSolved: Bool { snapshot?.you.solved == true || guesses.contains { $0.correct } }
    var youScoredCount: Int { max(snapshot?.you.guessCount ?? 0, guesses.filter { $0.warmth != nil }.count) }
    /// The opponent seat: public progress only, painted by band.
    var opponentSeat: RaceShowdown.OpponentSeat {
        let o = snapshot?.opponent
        return RaceShowdown.opponentSeat(bestWarmth: o?.bestWarmth ?? 0, guessCount: o?.guessCount ?? 0,
                                         solved: o?.solved ?? false, connected: o?.connected ?? true)
    }

    /// When the race clock read 0, on the wall clock (ms), while the face-off
    /// plays; nil otherwise. The seat Wicks pose from it every frame.
    var faceOffOrigin: Double? {
        guard faceOff, let fix = clockFix else { return nil }
        return fix.at - Double(fix.elapsedMs)
    }

    /// Feed public state into the momentum machine and act on what it says.
    private func raceStep() {
        guard phase == .playing, let snap = snapshot, let c = raceClock() else { return }
        let f = raceShow.update(.init(now: Self.nowMs(), youBest: youBest, themBest: snap.opponent.bestWarmth,
                                      youSolved: youSolved, themSolved: snap.opponent.solved,
                                      remainingMs: c.remainingMs, result: false))
        // The Wick that just took the lead gets one attention accent (the perk clip).
        if f.accent == .you { youCueKind = "leap"; youCue += 1 }
        if f.accent == .them { oppCueKind = "leap"; oppCue += 1 }
        if f != raceFrame { raceFrame = f }
        let p = RaceShowdown.phase(remainingMs: c.remainingMs, hasResult: false)
        if p != racePhase { racePhase = p }
        let loc = Loc(lang: .storedUI)
        for k in f.voice { announce(loc.key(k)) }
    }

    /// Step the race ten times a second while it is live.
    private func startRaceLoop() {
        raceTask?.cancel()
        raceTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, self.phase == .playing else { return }
                self.raceStep()
            }
        }
    }

    private func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    // MARK: Intents

    /// The recap's primary button: a friend rematch on the same code (the
    /// recap stays up until both have tapped), or a new Quick Match. A second
    /// tap does nothing.
    func playAgain() {
        guard rematchGate.request() else { return }
        if isFriendMatch, let code = requestedFriendCode {
            waitingRematch = true
            find(mode: requestedMode, friendCode: code, keepRecap: true)
        } else {
            find()
        }
    }

    /// Connect and queue for a live match. Pass a `friendCode` to pair privately.
    /// `create` (3.1): true = host a fresh invite, false = join one, nil = legacy.
    /// `keepRecap` (3.8): stay on the recap until the pairing opens the face-off.
    func find(mode: MatchMode = .casual, friendCode: String? = nil, create: Bool? = nil, keepRecap: Bool = false) {
        resetState(keepRecap: keepRecap)
        requestedMode = mode
        let code = friendCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        requestedFriendCode = (code?.isEmpty ?? true) ? nil : code
        requestedCreate = requestedFriendCode == nil ? nil : create
        isFriendMatch = requestedFriendCode != nil
        isHosting = create == true
        if !keepRecap { phase = .searching }
        let c = MatchClient()
        c.delegate = self
        client = c
        c.connect()
    }

    /// Host a friend Race: generate a code, host it, and offer the share link.
    func hostInvite() { find(mode: .casual, friendCode: LiveInvite.generateCode(), create: true) }

    /// Join a friend's Race invite by its code.
    func joinInvite(code: String) { find(mode: .casual, friendCode: code, create: false) }

    /// Rematch the same friend on the same code — both players tapping "Rematch"
    /// re-present the code and re-pair (legacy first-hosts/second-joins; no new link
    /// to exchange). Falls back to Quick Match if this wasn't a friend match.
    func rematch() { playAgain() }

    /// Submit a word guess. Warmth fills in when the server's `scored` frame lands.
    func submitGuess(_ raw: String) {
        let word = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .playing, racePhase != .expired, !word.isEmpty else { return }
        guesses.insert(Guess(word: word, warmth: nil, correct: false), at: 0)
        client?.guess(word)
    }

    /// Ask Wick a yes/no question. The reply lands via an `answer` frame.
    func askWick(_ raw: String) {
        let question = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .playing, !question.isEmpty else { return }
        replies.insert(
            Reply(question: question, verdict: "…", text: "Wick is thinking…", pending: true),
            at: 0
        )
        client?.ask(question)
    }

    /// A single text field can route by shape: a question goes to Wick, a word is
    /// a guess. Mirrors the web client's `looksLikeQuestion`.
    func submit(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if Self.looksLikeQuestion(text) {
            askWick(text)
        } else {
            submitGuess(text)
        }
    }

    /// Leave the match / cancel the search and tear down the connection.
    func leave() {
        client?.close()
        client = nil
        resetState()
        phase = .idle
    }

    func dismissBanner() { banner = nil }

    // MARK: MatchClientDelegate

    func matchClientDidOpen() {
        // Queue as soon as the socket is up (with the friend code + create/join
        // intent if this is a private match).
        // Race in the play language: the server pairs across languages and
        // scores each seat in its own.
        client?.queue(mode: requestedMode, friendCode: requestedFriendCode, create: requestedCreate, lang: GameLanguage.stored.rawValue)
    }

    func matchClient(didReceive frame: ServerFrame) {
        switch frame {
        case .paired(let p):
            opponentKind = p.opponentKind
            startsAt = nil
            // A rematch kept the last recap up until now: clear it.
            waitingRematch = false
            result = nil
            revealedWord = nil
            opponentWord = nil
            recapInfo = nil
            phase = .playing

        case .queued(let waitMs):
            startsAt = Date().addingTimeInterval(waitMs / 1000)

        case .state(let s):
            snapshot = s
            // Resuming: if the server hands us live state while we're still
            // "searching" (e.g. we quit and relaunched), adopt the match.
            if phase == .searching { phase = .playing }
            RaceMusic.shared.update(remainingMs: s.clock.remainingMs)
            // 3.8: the clock, the face-off, the opponent's cue and both trails.
            let first = clockFix == nil
            clockFix = RaceShowdown.ClockFix(elapsedMs: s.clock.elapsedMs, remainingMs: s.clock.remainingMs, at: Self.nowMs())
            if first {
                faceOff = RaceShowdown.faceOffEligible(s.clock.elapsedMs)
                oppSeen = s.opponent.guessCount
                if faceOff { announce(Loc(lang: .storedUI).raceFoundVoice) }
                startRaceLoop()
            }
            // The opponent Wick only moves when their public progress changes.
            if s.opponent.guessCount != oppSeen {
                oppSeen = s.opponent.guessCount
                oppCueKind = nil
                oppCue += 1
            }
            trails.push(.you, RaceShowdown.band(youBest, solved: youSolved), guessCount: youScoredCount)
            trails.push(.them, RaceShowdown.band(s.opponent.bestWarmth, solved: s.opponent.solved),
                        guessCount: s.opponent.guessCount)
            oppProgress.push(guessCount: s.opponent.guessCount, bestWarmth: s.opponent.bestWarmth)
            raceStep()

        case .scored(let guess, let score, let rank, let notAWord):
            if let i = guesses.firstIndex(where: { $0.word == guess && $0.warmth == nil }) {
                if notAWord {
                    // Not a real word — it never counted; drop it, matching solo.
                    guesses.remove(at: i)
                    banner = Loc(lang: .storedUI).liveNotAWord
                    break
                }
                guesses[i].warmth = score
                guesses[i].rank = rank
                if score >= 100 { guesses[i].correct = true }
                // 3.8: one reaction per scored guess, and the local trail.
                youCueKind = nil
                youCue += 1
                trails.push(.you, RaceShowdown.band(youBest, solved: youSolved), guessCount: youScoredCount)
                raceStep()
                // Same feel + sound as the single-player board: a solved chime, a
                // sparkle when this is a new best, otherwise the pitched "warmer"
                // note (score IS the 0…100 closeness the tone scale expects).
                if score >= 100 {
                    Feedback.play(.solved)
                } else {
                    let others = guesses.enumerated()
                        .filter { $0.offset != i }
                        .compactMap { $0.element.warmth }
                    let isNewBest = others.isEmpty || score >= (others.max() ?? 0)
                    Feedback.play(isNewBest ? .newClosest(closeness: score) : .guessScored(closeness: score))
                }
            }

        case .answer(let question, let verdict, let reply):
            if let i = replies.firstIndex(where: { $0.question == question && $0.pending }) {
                replies[i].verdict = verdict
                replies[i].text = reply
                replies[i].pending = false
            }

        case .result(let r, let word, let words):
            // What the other seat was hunting, when it was another language.
            opponentWord = words?.first { $0.value != word }.map { entry in
                (entry.value, GameLanguage(rawValue: entry.key)?.nativeName ?? entry.key)
            }
            result = r
            revealedWord = word
            // 3.8: the recap, from the server's result only.
            let recap = RaceShowdown.recap(
                reason: r.reason.rawValue, winner: r.winner, draw: r.draw,
                players: r.players.map { .init(id: $0.id, solvedAtMs: $0.solvedAtMs, bestWarmth: $0.bestWarmth, guessCount: $0.guessCount) },
                myId: myId)
            // 3.9: your route from your own scores, theirs from public progress.
            // The word that solved a race never comes back scored, so add it.
            var youScores = guesses.reversed().compactMap { $0.warmth }
            if recap.youGreen && youScores.last != 100 { youScores.append(100) }
            let comparison = RouteAnalysis.comparison(
                voided: r.reason.rawValue == "void",
                youScores: youScores, youGuessCount: recap.youGuesses, youSolved: recap.youGreen,
                themSamples: oppProgress.samples, themGuessCount: recap.themGuesses,
                themBest: r.players.first { $0.id != myId }?.bestWarmth ?? 0, themSolved: recap.themGreen)
            recapInfo = RecapInfo(recap: recap, reason: r.reason, word: word, opponentWord: opponentWord,
                                  leadChanges: raceFrame?.leadChanges ?? 0,
                                  youTrail: trails.you, themTrail: trails.them,
                                  youStartScore: guesses.first { $0.warmth != nil && !$0.correct }?.warmth,
                                  youScores: youScores, comparison: comparison)
            rematchGate = RaceShowdown.RematchGate()
            waitingRematch = false
            raceTask?.cancel()
            phase = .finished

        case .opponentLeft:
            banner = Loc(lang: .storedUI).liveOppLeftHangTight

        case .error(let code, let message):
            // "already_in_match" is now handled as a resume server-side; never
            // surface it as an error to the player.
            if code == "already_in_match" { return }
            // 3.1 invite errors: a code collision while hosting → regenerate + re-host
            // (silent, astronomically rare); a dead/expired invite while joining → a
            // friendly nudge on the disconnected screen.
            if code == "code_taken", requestedCreate == true {
                find(mode: .casual, friendCode: LiveInvite.generateCode(), create: true)
                return
            }
            if code == "no_such_invite" {
                banner = Loc(lang: .storedUI).liveInviteExpired
                phase = .disconnected
                return
            }
            banner = message
            if code == "attest_failed" { phase = .disconnected }
        }
    }

    func matchClientDidClose(clean: Bool) {
        // A clean close after a result is expected; otherwise we dropped.
        if phase == .searching || phase == .playing {
            phase = .disconnected
            if banner == nil { banner = Loc(lang: .storedUI).liveConnectionLost }
        } else if waitingRematch && !clean {
            // The rematch could not connect: let the button work again.
            waitingRematch = false
            rematchGate.reset()
            banner = Loc(lang: .storedUI).liveConnectionLost
        }
    }

    func matchClient(didError message: String) {
        banner = message
        if phase == .searching { phase = .disconnected }
    }

    // MARK: Helpers

    private func resetState(keepRecap: Bool = false) {
        guesses = []
        replies = []
        snapshot = nil
        opponentKind = nil
        startsAt = nil
        if !keepRecap {
            result = nil
            revealedWord = nil
            opponentWord = nil
            recapInfo = nil
            waitingRematch = false
        }
        banner = nil
        isHosting = false
        raceTask?.cancel()
        raceTask = nil
        raceShow = RaceShowdown.Show()
        trails = RaceShowdown.TrailRecorder()
        oppProgress = RouteAnalysis.ProgressRecorder()
        clockFix = nil
        raceFrame = nil
        racePhase = .opening
        faceOff = false
        oppSeen = 0
        youCueKind = nil
        oppCueKind = nil
    }

    /// Guesses are always single words, so a space or a trailing "?" marks a
    /// question — same rule the single-player board (GameView) uses.
    private static func looksLikeQuestion(_ text: String) -> Bool {
        text.hasSuffix("?") || text.contains(" ")
    }
}
