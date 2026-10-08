//
//  RoundHistory.swift
//  Hunch
//
//  A permanent, on-device record of every finished round — the groundwork for
//  2.0's archive (replay past dailies), a stats calendar, percentile-style
//  comparisons, and richer share cards. Invisible in 1.8: we only WRITE here.
//
//  Data you don't record is gone forever, so we start recording now. Local
//  only (UserDefaults as JSON), no network, consistent with the app's privacy
//  story. Capped so it can never grow unbounded.
//

import Foundation

/// One finished round (solved or given up). Unfinished rounds are not recorded.
struct RoundRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    /// When the round finished.
    let date: Date
    /// The shared daily index the round was played on (`WordBank.dayIndex()`).
    let dayIndex: Int
    /// The daily puzzle number, nil for practice rounds.
    let puzzleNumber: Int?
    /// "daily" or "practice".
    let mode: String
    /// The word's difficulty tier.
    let tier: Int
    /// Language code the round was played in ("en", "es", …).
    let language: String
    /// The secret in the played language…
    let word: String
    /// …and its English hub form, so an archive can group the same concept
    /// across languages.
    let wordEN: String
    /// true = solved; false = the player revealed the answer.
    let solved: Bool
    let guessCount: Int
    let questionCount: Int
    let hintsUsed: Int
    /// Per-guess closeness scores (0-100) in play order — enough to rebuild a
    /// heat grid for any past round without storing the guessed words.
    let scores: [Double]
}

enum RoundHistory {
    private static let storageKey = "hunch.roundHistory"
    /// Plenty for years of play; keeps the JSON blob bounded.
    private static let cap = 5000

    private(set) static var records: [RoundRecord] = load()

    /// Appends a finished round and persists. Newest last.
    static func record(_ r: RoundRecord) {
        records.append(r)
        if records.count > cap { records.removeFirst(records.count - cap) }
        save()
    }

    /// The record for a given daily (any language), if that day was finished.
    static func daily(dayIndex: Int) -> RoundRecord? {
        records.last { $0.mode == "daily" && $0.dayIndex == dayIndex }
    }

    /// Best-known outcome for a day across the live daily AND any archive
    /// replays — prefers a solved record, else the most recent attempt. Drives
    /// the archive list's per-day status markers. nil = never finished.
    static func outcome(dayIndex: Int) -> RoundRecord? {
        let relevant = records.filter {
            $0.dayIndex == dayIndex && ($0.mode == "daily" || $0.mode == "archive")
        }
        return relevant.first { $0.solved } ?? relevant.last
    }

    // MARK: - Persistence

    private static func load() -> [RoundRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([RoundRecord].self, from: data)
        else { return [] }
        return decoded
    }

    private static func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
