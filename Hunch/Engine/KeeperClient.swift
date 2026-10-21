//
//  KeeperClient.swift
//  Hunch
//
//  3.7: iPhone solo asks the Wick server's Keeper (POST /keeper), the same
//  Gemini Keeper the web game and live races use, with the same saved
//  answers. So a question about today's word gets the same answer on every
//  iPhone and on the web, and the common ones come back instantly.
//
//  What is sent: the secret word, its English form, the round's language,
//  the question, and the round's earlier questions and verdicts (so Wick
//  stays consistent). No id of any kind. The privacy policy says so.
//
//  When the server can't be reached (offline, or the server is down), this
//  returns nil and QuestionService falls back to Apple's on-device model.
//

import Foundation

enum KeeperClient {

    /// A server answer: a canonical verdict token ("Yes", "No", "Sort of",
    /// "IDK", "Won't say") and Wick's short reply line.
    struct Answer: Equatable {
        let verdict: String
        let reply: String
    }

    /// Short timeout: a player is waiting, and the on-device model is the
    /// fallback. A saved answer comes back in well under a second.
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 12
        cfg.timeoutIntervalForResource = 15
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()

    /// The earlier questions as the server wants them: oldest first, newest
    /// 12, only real verdicts. `history` is newest first (GameViewModel.questions).
    static func historyPayload(_ history: [AskedQuestion]) -> [[String: String]] {
        let real: [AskedQuestion] = history.filter { q in
            q.verdict == "Yes" || q.verdict == "No" || q.verdict == "Sort of" || q.verdict == "IDK"
        }
        let newest: [AskedQuestion] = Array(real.prefix(12))
        let oldestFirst: [AskedQuestion] = Array(newest.reversed())
        return oldestFirst.map { q in ["q": q.question, "v": q.verdict] }
    }

    /// Ask the server. nil when it can't be reached, answers badly, or says
    /// Gemini itself was unavailable (so the caller can try the on-device model).
    static func ask(question: String, secret: String, secretEnglish: String?,
                    language: GameLanguage, history: [AskedQuestion]) async -> Answer? {
        guard let base = LiveConfig.httpBase else { return nil }
        var body: [String: Any] = [
            "secret": secret,
            "question": String(question.prefix(280)),
            "lang": language.rawValue,
            "history": historyPayload(history),
        ]
        if let en = secretEnglish, en != secret { body["secretEn"] = en }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: base.appendingPathComponent("keeper"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        do {
            let (respData, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any] else { return nil }
            let source: String = json["source"] as? String ?? ""
            if source == "unavailable" { return nil }
            let verdict: String = json["verdict"] as? String ?? ""
            let reply: String = json["reply"] as? String ?? ""
            if verdict.isEmpty && reply.isEmpty { return nil }
            return Answer(verdict: verdict, reply: reply)
        } catch {
            return nil
        }
    }
}
