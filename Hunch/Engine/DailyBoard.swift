// SPDX-License-Identifier: MPL-2.0
//
//  DailyBoard.swift
//  Wick
//
//  3.6: today's race board. Everyone plays the same daily word, so every
//  solver races everyone else, even when nobody is online at the same time.
//
//  Nothing is posted on its own. When a daily is finished (solved or given
//  up), the app only remembers the first result of the day on this phone.
//  The player sees it on the board screen and chooses to tap Submit. Only
//  then does the app send the puzzle number, the guess count, the hints, the
//  active play time and the language, with the per-install id live races use.
//  The server ranks by fewest guesses (each hint counts one extra), then
//  time, keeps one result per phone per day, and shows each phone under a
//  safe auto name like "Violet Otter" that the player can reroll. See
//  wick-api/src/board.ts.
//
//  Only the first finished round of the day is offered, so giving up and then
//  re-solving in another language can't be submitted as a solve.
//
//  If the phone is offline when the player taps Submit, the result waits and
//  goes out as soon as it can: when the network comes back while the app is
//  open, when the app returns to the screen, or when the board is opened.
//  The server takes today's puzzle and yesterday's.
//

import Foundation
import Network

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

/// A finished daily on this phone, waiting for the player to submit it.
nonisolated struct BoardResult: Codable, Equatable, Sendable {
    let n: Int
    let g: Int
    let h: Int
    let ms: Int
    let lang: String
    let gaveUp: Bool
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
    /// A send is in flight, so the network monitor and the foreground hook
    /// cannot send the same result twice at once.
    @ObservationIgnored private var sending = false

    @ObservationIgnored private let defaults = UserDefaults.standard
    private let nameKey = "wick.board.name"
    private let rerollKey = "wick.board.r"
    private let pendingKey = "wick.board.pending"
    private func idKey(_ n: Int) -> String { "wick.board.id.\(n)" }
    /// The result as sent, kept for the day so it can be sent again if the
    /// server ever loses it (a deploy without its data disk, say).
    private func sentKey(_ n: Int) -> String { "wick.board.sent.\(n)" }
    private func resultKey(_ n: Int) -> String { "wick.board.result.\(n)" }

    @ObservationIgnored private let pathMonitor = NWPathMonitor()

    private init() {
        myName = defaults.string(forKey: nameKey)
        // Signal came back while the app is open: send a waiting result.
        pathMonitor.pathUpdateHandler = { path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await DailyBoard.shared.sendWaiting() }
        }
        pathMonitor.start(queue: DispatchQueue(label: "wick.board.path"))
    }

    /// Send a result that is waiting (solved offline), then refresh that
    /// day's board. Cheap when nothing is waiting. Called when the app comes
    /// to the foreground and when the network comes back.
    func sendWaiting() async {
        guard let n = defaults.dictionary(forKey: pendingKey)?["n"] as? Int else { return }
        if await sendPending() { await refresh(n: n) }
    }

    /// This phone's public row id on puzzle `n`, once it is on the board.
    func myId(_ n: Int) -> String? { defaults.string(forKey: idKey(n)) }

    /// My row in the current snapshot, when the server sent it.
    var myRow: BoardRow? { snapshot?.me }

    private var reroll: Int { defaults.integer(forKey: rerollKey) }

    // MARK: - The day's result

    /// Remember a finished daily. Only the first one of the day sticks, so a
    /// give-up can't be swapped for a re-solve in another language.
    func record(_ r: BoardResult) {
        guard defaults.data(forKey: resultKey(r.n)) == nil,
              let data = try? JSONEncoder().encode(r) else { return }
        defaults.set(data, forKey: resultKey(r.n))
    }

    /// The remembered first result for puzzle `n`, if any.
    func recorded(_ n: Int) -> BoardResult? {
        defaults.data(forKey: resultKey(n)).flatMap { try? JSONDecoder().decode(BoardResult.self, from: $0) }
    }

    /// The player is not on puzzle `n`'s board yet (on this phone).
    func notSubmitted(_ n: Int) -> Bool { myId(n) == nil && defaults.dictionary(forKey: pendingKey)?["n"] as? Int != n }

    // MARK: - Submit (only when the player taps Submit)

    private(set) var submitting = false

    func submit(_ r: BoardResult) async {
        guard myId(r.n) == nil, !submitting else { return }
        submitting = true
        defer { submitting = false }
        let body: [String: Any] = ["n": r.n, "g": r.g, "h": r.h, "ms": r.ms,
                                   "lang": r.lang, "kid": LiveConfig.kid, "r": reroll, "gu": r.gaveUp]
        defaults.set(body, forKey: pendingKey)
        await sendPending()
        await refresh(n: r.n)
    }

    /// Retry a result that could not be sent at the solve. True when it went
    /// onto the board just now.
    @discardableResult
    private func sendPending() async -> Bool {
        guard !sending, let body = defaults.dictionary(forKey: pendingKey),
              let n = body["n"] as? Int, let base = LiveConfig.httpBase else { return false }
        if myId(n) != nil || n < WordBank.dailyNumber() - 1 {
            defaults.removeObject(forKey: pendingKey)   // already on, or too old to count
            return false
        }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return false }
        sending = true
        defer { sending = false }
        var req = URLRequest(url: base.appendingPathComponent("board"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        req.timeoutInterval = 10
        guard let result = try? await URLSession.shared.data(for: req),
              let reply = try? JSONDecoder().decode(BoardSubmitReply.self, from: result.0) else { return false }
        let http = result.1
        if reply.ok, let id = reply.id {
            defaults.set(id, forKey: idKey(n))
            defaults.set(body, forKey: sentKey(n))
            if let name = reply.name { myName = name; defaults.set(name, forKey: nameKey) }
            defaults.removeObject(forKey: pendingKey)
            return true
        } else if let code = (http as? HTTPURLResponse)?.statusCode, (400..<500).contains(code), code != 429 {
            defaults.removeObject(forKey: pendingKey)   // the server said no (too fast, too old): drop it
        }
        return false
    }

    // MARK: - Read

    func refresh(n: Int, retried: Bool = false) async {
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
            let snap = try JSONDecoder().decode(BoardSnapshot.self, from: data)
            snapshot = snap
            failed = false
            // We were on today's board but the server no longer has us: send
            // the same result again, once.
            if !retried, snap.me == nil, myId(n) != nil, let sent = defaults.dictionary(forKey: sentKey(n)) {
                defaults.removeObject(forKey: idKey(n))
                defaults.removeObject(forKey: sentKey(n))
                defaults.set(sent, forKey: pendingKey)
                loading = false
                await refresh(n: n, retried: true)
            }
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
