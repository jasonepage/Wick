//
//  Models.swift
//  Hunch
//

import Foundation

/// A single guess and how semantically close it was to the secret word.
struct Guess: Identifiable, Equatable, Codable {
    var id = UUID()
    let word: String
    let score: Double   // 0...100 (100 = exact)
    let known: Bool     // false when the word isn't in the embedding vocabulary
    let order: Int      // 1-based guess number
    /// Position in the round's combined guess+question timeline. Optional so
    /// boards saved before the unified feed still decode (they sort as oldest).
    let seq: Int?
    /// Milliseconds of ACTIVE play from the round's start, with idle gaps
    /// clamped. This is what a Ghost Race replays against — see Ghost.swift.
    /// Optional so rounds saved before it shipped still decode; those simply
    /// can't be raced.
    var at: Int? = nil
}

/// A question the player asked the on-device keeper, and its answer.
struct AskedQuestion: Identifiable, Equatable, Codable {
    var id = UUID()
    let question: String
    let verdict: String   // "Yes", "No", "Sort of", "Can't tell"
    let reply: String
    /// Position in the round's combined guess+question timeline (see Guess.seq).
    let seq: Int?
    /// Milliseconds into the round — see Guess.at.
    var at: Int? = nil
}

/// One entry in the unified play feed — a guess or a question — so both can be
/// interleaved in the order they happened.
enum FeedItem: Identifiable {
    case guess(Guess)
    case question(AskedQuestion)

    var id: String {
        switch self {
        case .guess(let g):    return "g-\(g.id)"
        case .question(let q): return "q-\(q.id)"
        }
    }

    /// Timeline position; older/legacy items (nil seq) sort to the bottom.
    var seq: Int {
        switch self {
        case .guess(let g):    return g.seq ?? 0
        case .question(let q): return q.seq ?? 0
        }
    }
}

enum GameMode: Equatable {
    case daily
    case practice(tier: Int)
    /// Replaying a past daily from the archive. `dayIndex` is the original
    /// shared day (see WordBank.dayIndex). Ephemeral: never saved as today's
    /// board, and never touches coins, streak, or lifetime stats.
    case archive(dayIndex: Int)
    /// A Friend Duel — a curated word carried in a shared code. Language-locked
    /// and ephemeral (never saved as today's board, never touches coins, streak,
    /// stats, or history), like archive. See `DuelCode` / `startDuel`.
    case duel(DuelPayload)
}
