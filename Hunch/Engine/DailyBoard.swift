// SPDX-License-Identifier: MPL-2.0
//
//  DailyBoard.swift
//  Wick
//
//  3.6: today's race board. Everyone plays the same daily word, so every
//  solver races everyone else, even when nobody is online at the same time.
//
//  When the daily is solved, the app sends the puzzle number, the guess
//  count, the hints used, the active play time and the language, with the
//  player's per-install id (the same one live races use). The server ranks
//  by fewest guesses (each hint counts one extra), then time, keeps only the
//  first result per phone per day, and names each phone with a safe auto
//  name like "Violet Otter" that the player can reroll. See
//  wick-api/src/board.ts.
//
//  If the phone is offline at the solve, the result waits in UserDefaults
//  and goes out the next time the board is opened that day.
//

import Foundation

/// One row on the board, as GET /board returns it.
nonisolated struct BoardRow: Codable, Hashable, Sendable {
    let rank: Int
    let id: String
    let name: String
    let g: Int
    let h: Int
    let ms: Int
    let lang: String
    /// Gave up instead of solving. Older servers leave it out.
    let gu: Bool?

    var gaveUp: Bool { gu == true }
}

nonisolated struct BoardSnapshot: Codable, Sendable {
    let n: Int
    let total: Int
    let top: [BoardRow]
    let me: BoardRow?
}

nonisolated struct BoardSubmitReply: Codable, Sendable {
    let ok: Bool
    let rank: Int?
    let total: Int?
    let name: String?
    let id: String?
    let reason: String?
}

/// Pure helpers, testable without the network.
nonisolated enum BoardFormat {
    /// "4:10", or "1:02:05" past an hour.
    static func time(ms: Int) -> String {
        let s = max(0, ms) / 1000
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    /// The flag for a row's language (Chinese is web only).
    static func flag(_ lang: String) -> String {
        switch lang {
        case "es": return "🇪🇸"
        case "fr": return "🇫🇷"
        case "it": return "🇮🇹"
        case "de": return "🇩🇪"
        case "zh": return "🇨🇳"
        default: return "🇺🇸"
        }
    }
}

@MainActor
@Observable
final class DailyBoard {
    static let shared = DailyBoard()

    private(set) var snapshot: BoardSnapshot?
    private(set) var loading = false
    private(set) var failed = false
    /// The auto name the server gave this phone. Nil until the first solve.
    private(set) var myName: String?

    @ObservationIgnored private let defaults = UserDefaults.standard
    private let nameKey = "wick.board.name"
    private let rerollKey = "wick.board.r"
    private let pendingKey = "wick.board.pending"
    private func idKey(_ n: Int) -> String { "wick.board.id.\(n)" }

    private init() {
        myName = defaults.string(forKey: nameKey)
    }

    /// This phone's public row id on puzzle `n`, once it is on the board.
    func myId(_ n: Int) -> String? { defaults.string(forKey: idKey(n)) }

    /// My row in the current snapshot, when the server sent it.
    var myRow: BoardRow? { snapshot?.me }

    private var reroll: Int { defaults.integer(forKey: rerollKey) }

    // MARK: - Submit

    /// Send a finished daily, solved or given up. Safe to call twice: the
    /// server keeps the first, so a give-up stays a give-up.
    func submit(n: Int, guesses: Int, hints: Int, ms: Int, lang: GameLanguage, gaveUp: Bool = false) async {
        guard myId(n) == nil else { return }
        let body: [String: Any] = ["n": n, "g": guesses, "h": hints, "ms": ms,
                                   "lang": lang.rawValue, "kid": LiveConfig.kid, "r": reroll, "gu": gaveUp]
        defaults.set(body, forKey: pendingKey)
        await sendPending()
        await refresh(n: n)
    }

    /// Retry a result that could not be sent at the solve.
    private func sendPending() async {
        guard let body = defaults.dictionary(forKey: pendingKey),
              let n = body["n"] as? Int, let base = LiveConfig.httpBase else { return }
        if myId(n) != nil || n < WordBank.dailyNumber() - 1 {
            defaults.removeObject(forKey: pendingKey)   // already on, or too old to count
            return
        }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var req = URLRequest(url: base.appendingPathComponent("board"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        req.timeoutInterval = 10
        guard let result = try? await URLSession.shared.data(for: req),
              let reply = try? JSONDecoder().decode(BoardSubmitReply.self, from: result.0) else { return }
        let http = result.1
        if reply.ok, let id = reply.id {
            defaults.set(id, forKey: idKey(n))
            if let name = reply.name { myName = name; defaults.set(name, forKey: nameKey) }
            defaults.removeObject(forKey: pendingKey)
        } else if let code = (http as? HTTPURLResponse)?.statusCode, (400..<500).contains(code), code != 429 {
            defaults.removeObject(forKey: pendingKey)   // the server said no (too fast, not today): drop it
        }
    }

    // MARK: - Read

    func refresh(n: Int) async {
        await sendPending()
        guard !loading, let base = LiveConfig.httpBase,
              var parts = URLComponents(url: base.appendingPathComponent("board"), resolvingAgainstBaseURL: false)
        else { return }
        var items = [URLQueryItem(name: "n", value: String(n))]
        if let me = myId(n) { items.append(URLQueryItem(name: "me", value: me)) }
        parts.queryItems = items
        guard let url = parts.url else { return }
        loading = true
        defer { loading = false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            snapshot = try JSONDecoder().decode(BoardSnapshot.self, from: data)
            failed = false
        } catch {
            failed = snapshot == nil
        }
    }

    // MARK: - Name

    /// Roll a new auto name. Renames today's entry too, if there is one.
    func rerollName(n: Int) async {
        guard let base = LiveConfig.httpBase else { return }
        let next = reroll + 1
        let body: [String: Any] = ["n": n, "kid": LiveConfig.kid, "r": next]
        var req = URLRequest(url: base.appendingPathComponent("board/name"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 10
        guard let result = try? await URLSession.shared.data(for: req),
              let obj = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any],
              obj["ok"] as? Bool == true, let name = obj["name"] as? String else { return }
        defaults.set(next, forKey: rerollKey)
        myName = name
        defaults.set(name, forKey: nameKey)
        await refresh(n: n)
    }
}
