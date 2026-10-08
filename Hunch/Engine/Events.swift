//
//  Events.swift
//  Wick
//
//  Fire-and-forget product events (3.3). Mirrors wick-web/src/net/events.ts.
//
//  Single-player runs on the device, so the server cannot tell a solve from a
//  give-up, or one player from ten. It has to be told. These are counts, not
//  tracking: a random per-install id (hashed again on arrival), the puzzle
//  number and a guess count. Never a word, a question, or anything typed.
//
//  Cheap and allowed to fail: nothing awaits it, nothing retries, and a failure
//  is silent. Analytics must never delay or break a turn of the game.
//

import Foundation

enum WickEvent: String {
    case dailyStart = "daily_start"
    case dailySolve = "daily_solve"
    case dailyGiveup = "daily_giveup"
    case shareGrid = "share_grid"
    case shareMap = "share_map"
    case revealView = "reveal_view"
    case duelOpen = "duel_open"
    case practiceStart = "practice_start"
    case raceLinkCreated = "race_link_created"
    case raceLinkOpened = "race_link_opened"
    case raceFinished = "race_finished"
}

enum Events {
    /// Random per-install id. Not the Apple identifier, not tied to an account,
    /// and reset by deleting the app. The server hashes it before writing.
    private static let anonId: String = {
        let key = "hunch.anonId"
        if let id = UserDefaults.standard.string(forKey: key) { return id }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: key)
        return id
    }()

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 8
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()

    /// Send one event. `n` = puzzle number, `g` = guess count, when relevant.
    static func track(_ event: WickEvent, n: Int? = nil, g: Int? = nil) {
        guard let base = LiveConfig.httpBase else { return }
        var body: [String: Any] = ["e": event.rawValue, "id": anonId, "p": "ios"]
        if let n { body["n"] = n }
        if let g { body["g"] = g }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var req = URLRequest(url: base.appendingPathComponent("event"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        session.dataTask(with: req).resume()
    }
}
