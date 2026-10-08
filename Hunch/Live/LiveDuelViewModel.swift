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
    @Published private(set) var phase: Phase = .idle
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
    @Published private(set) var banner: String?

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

    // MARK: Intents

    /// Connect and queue for a live match. Pass a `friendCode` to pair privately.
    /// `create` (3.1): true = host a fresh invite, false = join one, nil = legacy.
    func find(mode: MatchMode = .casual, friendCode: String? = nil, create: Bool? = nil) {
        resetState()
        requestedMode = mode
        let code = friendCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        requestedFriendCode = (code?.isEmpty ?? true) ? nil : code
        requestedCreate = requestedFriendCode == nil ? nil : create
        isFriendMatch = requestedFriendCode != nil
        isHosting = create == true
        phase = .searching
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
    func rematch() {
        guard isFriendMatch, let code = requestedFriendCode else { find(); return }
        find(mode: requestedMode, friendCode: code)
    }

    /// Submit a word guess. Warmth fills in when the server's `scored` frame lands.
    func submitGuess(_ raw: String) {
        let word = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .playing, !word.isEmpty else { return }
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
        client?.queue(mode: requestedMode, friendCode: requestedFriendCode, create: requestedCreate)
    }

    func matchClient(didReceive frame: ServerFrame) {
        switch frame {
        case .paired(let p):
            opponentKind = p.opponentKind
            startsAt = nil
            phase = .playing

        case .queued(let waitMs):
            startsAt = Date().addingTimeInterval(waitMs / 1000)

        case .state(let s):
            snapshot = s
            // Resuming: if the server hands us live state while we're still
            // "searching" (e.g. we quit and relaunched), adopt the match.
            if phase == .searching { phase = .playing }

        case .scored(let guess, let score, let rank, let notAWord):
            if let i = guesses.firstIndex(where: { $0.word == guess && $0.warmth == nil }) {
                if notAWord {
                    // Not a real word — it never counted; drop it, matching solo.
                    guesses.remove(at: i)
                    banner = Loc(lang: .stored).liveNotAWord
                    break
                }
                guesses[i].warmth = score
                guesses[i].rank = rank
                if score >= 100 { guesses[i].correct = true }
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

        case .result(let r, let word):
            result = r
            revealedWord = word
            phase = .finished

        case .opponentLeft:
            banner = Loc(lang: .stored).liveOppLeftHangTight

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
                banner = Loc(lang: .stored).liveInviteExpired
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
            if banner == nil { banner = Loc(lang: .stored).liveConnectionLost }
        }
    }

    func matchClient(didError message: String) {
        banner = message
        if phase == .searching { phase = .disconnected }
    }

    // MARK: Helpers

    private func resetState() {
        guesses = []
        replies = []
        snapshot = nil
        opponentKind = nil
        startsAt = nil
        result = nil
        revealedWord = nil
        banner = nil
        isHosting = false
    }

    /// Guesses are always single words, so a space or a trailing "?" marks a
    /// question — same rule the single-player board (GameView) uses.
    private static func looksLikeQuestion(_ text: String) -> Bool {
        text.hasSuffix("?") || text.contains(" ")
    }
}
