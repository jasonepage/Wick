//
//  LiveConfig.swift
//  Hunch — Wick 3.0 live multiplayer
//
//  Configuration for the live-duel backend. This is NEW 3.0 code: it is fully
//  isolated from the shipped 2.1 offline duel (DuelCode.swift) and does not touch
//  any single-player path. Single-player stays 100% on-device; only the live
//  head-to-head talks to the server.
//
//  The server address is not written in code. It comes from the WICK_SERVER_BASE
//  build setting (Config/Wick.xcconfig, overridable in the gitignored
//  Config/Local.xcconfig), which Config/Info.plist copies into the app bundle.
//  Self-hosters point it at their own wick-api; nothing else changes.
//

import Foundation

enum LiveConfig {
    /// WebSocket base for the live match service. `/match` is appended by the client.
    /// Read from the WICK_SERVER_BASE Info.plist key (see Config/Wick.xcconfig).
    /// Falls back to the public Wick server if the key is missing or malformed,
    /// so a build never crashes over a configuration slip.
    static let serverBase: URL = {
        let fallback = URL(string: "wss://wick-api.onrender.com")!
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "WICK_SERVER_BASE") as? String else {
            return fallback
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "ws" || scheme == "wss",
              url.host != nil else {
            return fallback
        }
        return url
    }()

    /// The same service over HTTPS, for the handful of plain request/response
    /// calls (currently just POST /validate-word). Derived from `serverBase`
    /// rather than written out again, so pointing this stack at a new host stays
    /// a one-line change — which is the whole point of the comment above.
    static var httpBase: URL? {
        guard var parts = URLComponents(url: serverBase, resolvingAgainstBaseURL: false) else { return nil }
        parts.scheme = serverBase.scheme == "ws" ? "http" : "https"
        return parts.url
    }

    /// Per-install identity slot. Phase 1 passes this as `?kid=`; it becomes the
    /// App Attest key id when attestation lands (server FR-16). Kept stable across
    /// launches so a dropped player reconnects into the SAME live match (FR-17).
    static var kid: String {
        let key = "wick.live.kid"
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: key)
        return fresh
    }
}

// MARK: - Live invite links (3.1)

/// A parsed live-invite deep link (Race) — the payload behind a
/// `guesswick.com/p/<code>?m=race` Universal Link or a `wick://race/<code>` URL.
///
/// Dare was retired in 3.3. Dare links still in circulation (`?m=dare`,
/// `wick://dare/…`) parse to nil on purpose: routing them into a Race join
/// would send a dare room code to the Race matcher and fail as "expired".
/// Returning nil lets the app simply open on Home.
/// Identifiable so it can drive a `fullScreenCover(item:)` for cold-launch routing.
struct LiveInvite: Identifiable, Equatable {
    enum Mode: String { case race }
    let id = UUID()
    let mode: Mode
    let code: String

    /// Canonical share host — the custom domain pointed at the Render service.
    static let host = "guesswick.com"

    /// App-generated code: short + unambiguous (no I/L/O/0/1). The server also
    /// guarantees uniqueness — a collision comes back as `code_taken`, and we regenerate.
    static func generateCode(length: Int = 5) -> String {
        let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<length).map { _ in alphabet.randomElement()! })
    }

    /// The tappable invite URL to share.
    var shareURL: URL {
        URL(string: "https://\(Self.host)/p/\(code)?m=\(mode.rawValue)")!
    }

    /// A friendly message to accompany the link in the share sheet (localized).
    var shareMessage: String {
        let loc = Loc(lang: .stored)
        switch mode {
        case .race: return loc.liveShareMsgRace
        }
    }

    /// Parse an incoming URL into a live invite, or nil if it isn't one.
    ///  • Universal Link: `https://<host>/p/<code>?m=race` (no `m` means race)
    ///  • Custom scheme:  `wick://race/<code>`
    /// Retired Dare links (`m=dare`, `wick://dare/…`) return nil.
    /// Returns nil for legacy `WK-`/`WR-` links (`…/d/?c=…`), which stay on the
    /// offline duel path in `HunchApp.onOpenURL`.
    static func from(url: URL) -> LiveInvite? {
        switch url.scheme?.lowercased() {
        case "https":
            let parts = url.pathComponents.filter { $0 != "/" }
            guard let pIdx = parts.firstIndex(of: "p"), pIdx + 1 < parts.count else { return nil }
            let code = parts[pIdx + 1].trimmingCharacters(in: .whitespaces)
            guard !code.isEmpty else { return nil }
            let m = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "m" })?.value
            // An unknown mode (today only the retired "dare") is not a Race.
            guard let mode = Mode(rawValue: (m ?? "race").lowercased()) else { return nil }
            return LiveInvite(mode: mode, code: code)
        case "wick":
            // wick://race/<code> — the host carries the mode, first path part the code.
            guard let mode = Mode(rawValue: (url.host ?? "").lowercased()) else { return nil }
            let parts = url.pathComponents.filter { $0 != "/" }
            guard let code = parts.first?.trimmingCharacters(in: .whitespaces), !code.isEmpty else { return nil }
            return LiveInvite(mode: mode, code: code)
        default:
            return nil
        }
    }
}
