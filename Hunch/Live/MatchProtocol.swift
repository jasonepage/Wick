//
//  MatchProtocol.swift
//  Hunch — Wick 3.0 live multiplayer
//
//  The WS /match wire contract, mirrored 1:1 from the server's TypeScript
//  (`wick-api/src/protocol.ts` + `room.ts`). Small JSON frames, metadata only:
//  the client never sees the secret, the opponent's guesses, or the answer — the
//  server is authoritative for solve, warmth, and timing (C8).
//
//  Keep these types in lockstep with protocol.ts / room.ts. The web client
//  (wick-web) re-exports the same shapes from the server, so all three platforms
//  share one contract.
//

import Foundation

// MARK: - Shared enums (room.ts)

/// Honesty label for the opponent seat (FR-13, C9).
enum OpponentKind: String, Codable, Equatable {
    case human, bot, ghost
}

enum MatchMode: String, Codable, Equatable {
    case casual, ranked
}

/// Why a match ended (room.ts EndReason).
enum EndReason: String, Codable, Equatable {
    case solved
    case timeout
    case forfeit
    case void
}

// MARK: - State snapshot (room.ts StateSnapshot)

/// What a player may see about themselves.
struct SelfView: Codable, Equatable {
    var guessCount: Int
    var bestWarmth: Double        // 0..1
    var solved: Bool
    var solvedAtMs: Int?
}

/// What a player may see about their opponent: PROGRESS ONLY (FR-8) — never the
/// opponent's guessed words, questions, or the secret.
struct OpponentView: Codable, Equatable {
    var kind: OpponentKind
    var guessCount: Int
    var bestWarmth: Double        // 0..1
    var solved: Bool
    var connected: Bool
}

struct ClockView: Codable, Equatable {
    var t0Ms: Int
    var elapsedMs: Int
    var remainingMs: Int
    var capMs: Int
}

struct StateSnapshot: Codable, Equatable {
    var roomId: String
    var status: String            // "active" | "ended"
    var you: SelfView
    var opponent: OpponentView
    var clock: ClockView
    var result: MatchResult?
}

// MARK: - Result (room.ts MatchResult)

struct PlayerResult: Codable, Equatable, Identifiable {
    var id: String
    var kind: OpponentKind
    var solvedAtMs: Int?
    var bestWarmth: Double        // 0..1
    var guessCount: Int
}

struct MatchResult: Codable, Equatable {
    var reason: EndReason
    /// Winner's PlayerId, or nil for a draw/void.
    var winner: String?
    var draw: Bool
    var players: [PlayerResult]   // exactly two
    var endedAtMs: Int
}

// MARK: - Server → client frames (protocol.ts)

struct PairedFrame: Codable, Equatable {
    var roomId: String
    var opponentKind: OpponentKind
    var mode: MatchMode
    /// Opaque per-match handle — NOT the answer. The client never needs the word;
    /// it types guesses and the server scores them.
    var wordId: String
}

/// A parsed inbound frame. Mirrors protocol.ts ServerFrame.
enum ServerFrame: Equatable {
    case paired(PairedFrame)
    /// 3.3 shared start: waiting in Quick Match; `waitMs` until the race starts.
    case queued(waitMs: Double)
    case state(StateSnapshot)
    /// The final result, plus the revealed secret (safe: the match has ended).
    case result(MatchResult, word: String)
    /// The server's authoritative warmth (0..100) + Contexto rank for a guess.
    case scored(guess: String, score: Double, rank: Int?, notAWord: Bool)
    /// The Keeper's reply to an in-match `ask` (verdict + short persona line).
    case answer(question: String, verdict: String, reply: String)
    case opponentLeft
    case error(code: String, message: String)

    /// Parse a text frame; returns nil if it isn't a recognized ServerFrame.
    static func parse(_ text: String) -> ServerFrame? {
        guard let data = text.data(using: .utf8) else { return nil }
        let dec = JSONDecoder()
        guard let probe = try? dec.decode(TypeProbe.self, from: data) else { return nil }
        switch probe.t {
        case "paired":
            return (try? dec.decode(PairedFrame.self, from: data)).map(ServerFrame.paired)
        case "queued":
            return (try? dec.decode(QueuedWrap.self, from: data)).map { .queued(waitMs: $0.waitMs) }
        case "state":
            return (try? dec.decode(StateWrap.self, from: data)).map { .state($0.state) }
        case "result":
            return (try? dec.decode(ResultWrap.self, from: data)).map { .result($0.result, word: $0.word) }
        case "scored":
            return (try? dec.decode(ScoredWrap.self, from: data)).map { .scored(guess: $0.guess, score: $0.score, rank: $0.rank, notAWord: $0.notAWord ?? false) }
        case "answer":
            return (try? dec.decode(AnswerWrap.self, from: data)).map {
                .answer(question: $0.question, verdict: $0.verdict, reply: $0.reply)
            }
        case "opponentLeft":
            return .opponentLeft
        case "error":
            return (try? dec.decode(ErrorWrap.self, from: data)).map { .error(code: $0.code, message: $0.message) }
        default:
            return nil
        }
    }

    private struct TypeProbe: Codable { let t: String }
    private struct QueuedWrap: Codable { let waitMs: Double }
    private struct StateWrap: Codable { let state: StateSnapshot }
    private struct ResultWrap: Codable { let result: MatchResult; let word: String }
    private struct ScoredWrap: Codable { let guess: String; let score: Double; let rank: Int?; let notAWord: Bool? }
    private struct AnswerWrap: Codable { let question: String; let verdict: String; let reply: String }
    private struct ErrorWrap: Codable { let code: String; let message: String }
}

// MARK: - Client → server frames (protocol.ts)

/// An outbound frame. Mirrors protocol.ts ClientFrame. Encoded by hand so the
/// wire JSON matches the server's `parseClientFrame` exactly.
enum ClientFrame {
    case queue(mode: MatchMode, friendCode: String?, create: Bool?)
    case guess(_ word: String, warmth: Double?)
    case question(warmth: Double)
    case ask(_ question: String)
    case heartbeat

    func encoded() -> String? {
        var obj: [String: Any]
        switch self {
        case let .queue(mode, friendCode, create):
            obj = ["t": "queue", "mode": mode.rawValue]
            if let friendCode { obj["friendCode"] = friendCode }
            if let create { obj["create"] = create }
        case let .guess(word, warmth):
            obj = ["t": "guess", "guess": word]
            if let warmth { obj["warmth"] = warmth }
        case let .question(warmth):
            obj = ["t": "question", "warmth": warmth]
        case let .ask(question):
            obj = ["t": "ask", "question": question]
        case .heartbeat:
            obj = ["t": "heartbeat"]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: obj) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
