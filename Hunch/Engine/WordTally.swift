// SPDX-License-Identifier: MPL-2.0
//
//  WordTally.swift
//  Wick
//
//  3.6: the weekly Stats lists. "Top guesses this week" and "Most asked
//  questions", across every player.
//
//  Solo rounds score on the phone, so the server never sees those words
//  unless the app says so. When the player leaves "Add my words to weekly
//  stats" on (Settings, on by default), the app sends:
//
//    - a guess that reads Cool or colder (rank above 400), never a warm one
//      and never the answer, so the shared list cannot hint at today's word
//    - a question the player typed to the Keeper, unless it names the answer
//      (tapped starter chips are left out; everyone gets the same ones)
//
//  Each send is the text, the round's language and a timestamp. No id of any
//  kind. Live races are counted by the server itself, so nothing is sent
//  from here for them. Fire and forget, like Events: nothing awaits it,
//  nothing retries.
//
//  WeeklyStats fetches the lists for StatsView and caches them, so opening
//  Stats does not hit the server every time.
//

import Foundation

/// The pure rules: what may leave the phone. Nonisolated so tests can call it.
nonisolated enum WordTallyRules {
    /// The last rank of the Warm band (HunchTheme.rankLabel). Anything at or
    /// inside it stays on the phone. Mirrors COLD_RANK in wick-api/src/tally.ts.
    static let coldRank = 400

    /// True for a guess that may go on the shared list. A rank of 0 means the
    /// ranking is not built yet; we cannot tell the heat, so it stays home.
    static func shouldSendGuess(rank: Int) -> Bool {
        rank > coldRank
    }

    /// Does the question name the answer (or start a word with it, like
    /// "cats" for "cat")? Compared word by word, lowercased.
    static func namesAnswer(_ question: String, answers: [String?]) -> Bool {
        let lower = question.lowercased()
        let words = lower
            .split(whereSeparator: { !$0.isLetter && $0 != "'" })
            .map(String.init)
        for raw in answers {
            guard let a = raw?.trimmingCharacters(in: .whitespaces).lowercased(), !a.isEmpty else { continue }
            if a.contains(" ") {
                if lower.contains(a) { return true }
                continue
            }
            if words.contains(where: { $0 == a || (a.count >= 3 && $0.hasPrefix(a)) }) { return true }
        }
        return false
    }
}

enum WordTally {
    /// The Settings switch. On unless the player turned it off.
    static let shareKey = "wick.shareWords"
    static var isOn: Bool {
        UserDefaults.standard.object(forKey: shareKey) as? Bool ?? true
    }

    static func guess(_ word: String, language: GameLanguage) {
        send(kind: "g", text: word, language: language)
    }

    static func question(_ text: String, language: GameLanguage) {
        send(kind: "q", text: text, language: language)
    }

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 8
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()

    private static func send(kind: String, text: String, language: GameLanguage) {
        guard isOn, let base = LiveConfig.httpBase else { return }
        let body: [String: Any] = [
            "k": kind,
            "t": String(text.prefix(140)),
            "l": language.rawValue,
            "at": Int(Date().timeIntervalSince1970 * 1000),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var req = URLRequest(url: base.appendingPathComponent("tally"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        session.dataTask(with: req).resume()
    }
}

/// One week's lists as GET /stats/weekly returns them. Counts only.
nonisolated struct WeeklySnapshot: Codable, Equatable, Sendable {
    nonisolated struct Row: Codable, Hashable, Sendable {
        let text: String
        let count: Int
    }

    let week: String
    let resetsAt: String
    let lang: String
    let guesses: [Row]
    let questions: [Row]

    /// How long a fetched list is trusted before Stats asks again.
    static let maxAge: TimeInterval = 30 * 60

    static func decode(_ data: Data) -> WeeklySnapshot? {
        try? JSONDecoder().decode(WeeklySnapshot.self, from: data)
    }

    /// When these lists reset (next Monday 00:00 UTC).
    var resetDate: Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: resetsAt) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: resetsAt)
    }

    /// Past the Monday reset: these are last week's lists.
    func isExpired(now: Date) -> Bool {
        guard let reset = resetDate else { return false }
        return now >= reset
    }

    /// Is a copy fetched at `fetchedAt` still good at `now`?
    func isFresh(fetchedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) <= Self.maxAge && !isExpired(now: now)
    }
}

/// This week's lists for StatsView, cached per language so opening Stats
/// does not hit the server every time.
@MainActor
@Observable
final class WeeklyStats {
    static let shared = WeeklyStats()

    /// The lists for the language last asked for. Nil until the first load.
    private(set) var snapshot: WeeklySnapshot?
    private(set) var loading = false
    /// The last fetch failed and there is nothing current to show.
    private(set) var failed = false

    @ObservationIgnored private let defaults = UserDefaults.standard
    private func cacheKey(_ lang: GameLanguage) -> String { "wick.weekly.\(lang.rawValue)" }
    private func stampKey(_ lang: GameLanguage) -> String { "wick.weekly.\(lang.rawValue).at" }

    private init() {}

    /// Show the cache at once, then fetch only if it is stale.
    func refreshIfStale(language: GameLanguage, now: Date = Date()) async {
        var cached: WeeklySnapshot?
        if let data = defaults.data(forKey: cacheKey(language)),
           let snap = WeeklySnapshot.decode(data),
           !snap.isExpired(now: now) {
            cached = snap
            snapshot = snap
            failed = false
            if let at = defaults.object(forKey: stampKey(language)) as? Date,
               snap.isFresh(fetchedAt: at, now: now) {
                return
            }
        } else {
            snapshot = nil   // nothing current for this language (or last week's)
        }

        guard !loading, let base = LiveConfig.httpBase,
              var parts = URLComponents(url: base.appendingPathComponent("stats/weekly"), resolvingAgainstBaseURL: false)
        else { return }
        parts.queryItems = [URLQueryItem(name: "lang", value: language.rawValue)]
        guard let url = parts.url else { return }

        loading = true
        defer { loading = false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let snap = WeeklySnapshot.decode(data) else {
                failed = cached == nil
                return
            }
            defaults.set(data, forKey: cacheKey(language))
            defaults.set(now, forKey: stampKey(language))
            snapshot = snap
            failed = false
        } catch {
            failed = cached == nil   // offline: keep showing the cache if we have one
        }
    }
}
