//
//  Ghost.swift
//  Hunch
//
//  Ghost Race — the codec for "race me on this word" links.
//  A DIRECT PORT of wick-web/src/game/ghost.ts. The two must stay byte-identical:
//  a link made on web has to decode on iOS and vice versa, so any change here
//  needs the same change there, and the round-trip vectors at the bottom of this
//  file are the contract.
//
//  The rule that shapes the format:
//
//      SHAPE CROSSES OVER. CONTENT NEVER DOES.
//
//  Numbers only. No guess, no question, no reply, no secret ever enters a link,
//  so one cannot leak the answer even when decoded by hand — which anyone can do,
//  because it isn't encrypted and doesn't need to be. That's a property of the
//  format, not a promise about behaviour.
//
//  Per action the receiver learns: WHEN it happened, guess or question, whether
//  it improved the sender's best, and the heat band they stood at afterwards.
//  Enough to feel the race; useless for solving the word.
//
//  Encoding — one integer per action:
//
//      (dt << 5) | (kind << 4) | (improved << 3) | band
//
//  where dt is deciseconds since the PREVIOUS action. Deltas keep the numbers
//  small, so base36 gives 2-3 characters each and a whole round fits in a URL.
//

import Foundation

enum GhostRaceMode: String {
    case daily = "d"
    case practice = "p"
}

struct GhostAction: Equatable {
    /// Milliseconds into the round.
    let t: Int
    /// 0 = guess, 1 = question.
    let kind: Int
    /// 1 if this action improved the sender's best.
    let improved: Int
    /// The sender's BEST band so far, after this action. 0 = Freezing … 6 = Solved.
    let band: Int
}

struct GhostRun: Equatable, Identifiable {
    /// Stable within a session — fullScreenCover(item:) needs an id, and a run
    /// is fully described by its encoding.
    var id: String { Ghost.encode(self) }

    let mode: GhostRaceMode
    /// Puzzle number for `.daily`, shared-pool index for `.practice`.
    /// Never the word itself.
    let ref: Int
    let solved: Bool
    let actions: [GhostAction]

    /// Round length in milliseconds.
    var durationMs: Int { actions.last?.t ?? 0 }
}

enum Ghost {

    /// Bumped in lockstep with ghost.ts. v1 had no practice mode and carried a
    /// bare puzzle number; it is still decoded so links shared before v2 work.
    static let version = 2

    /// A round longer than this is junk or an attack.
    static let maxActions = 300

    /// How many words iOS and web share, in the same order, from index 0.
    ///
    /// VERIFIED, not assumed: `Hunch/Engine/DailyWords.swift` holds 381 entries and
    /// `wick-web/src/game/dailyPool.json` holds 359, and the first 359 are identical
    /// in identical order. The extra 22 are the tier-4 practice-only words the web
    /// client does not carry.
    ///
    /// So a practice race link may only reference an index BELOW this. Sending one
    /// above it would put the two players on different words while both boards
    /// looked completely normal — the worst kind of bug, because nobody could tell
    /// it had happened. `practiceRef` is the only sanctioned way to build one.
    static let sharedPoolCount = 359

    /// The pool index to put in a practice link, or nil when the word is outside
    /// the range web can resolve (in which case: offer no link).
    static func practiceRef(poolIndex: Int) -> Int? {
        (0..<sharedPoolCount).contains(poolIndex) ? poolIndex : nil
    }

    /// 0 = Freezing … 5 = Boiling, 6 = Solved. Mirrors bandOf() in ghost.ts and
    /// the thresholds in HunchTheme.label(for:).
    static func band(forScore s: Double) -> Int {
        if s >= 100 { return 6 }
        if s >= 60 { return 5 }
        if s >= 45 { return 4 }
        if s >= 30 { return 3 }
        if s >= 18 { return 2 }
        if s >= 8 { return 1 }
        return 0
    }

    // MARK: - Encode

    static func encode(_ run: GhostRun) -> String {
        var prev = 0
        var parts: [String] = []
        parts.reserveCapacity(min(run.actions.count, maxActions))
        for a in run.actions.prefix(maxActions) {
            // Rounds to nearest deciseconds, exactly as the TS side does.
            let dt = max(0, Int((Double(a.t - prev) / 100.0).rounded()))
            prev = a.t
            let packed = dt * 32 + (a.kind << 4) + (a.improved << 3) + (a.band & 7)
            parts.append(String(packed, radix: 36))
        }
        let ref = String(run.ref, radix: 36)
        return "\(version)-\(run.mode.rawValue)\(ref)-\(run.solved ? 1 : 0)-\(parts.joined(separator: "."))"
    }

    /// The full shareable URL.
    ///
    /// PATH form, not a query. Universal Links match on path only, so `/r/<run>`
    /// is what allows an installed app to receive the link at all; `?r=` never
    /// could. Keep in step with raceLink() in wick-web/src/main.ts.
    static func link(_ run: GhostRun, base: String = "https://guesswick.com") -> String {
        "\(base)/r/\(encode(run))"
    }

    // MARK: - Decode

    /// Returns nil for anything malformed. A bad link must fail quietly into a
    /// normal round, never into a broken board.
    static func decode(_ raw: String) -> GhostRun? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let bits = s.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard bits.count == 4 else { return nil }

        guard let ver = Int(bits[0]), ver == version || ver == 1 else { return nil }
        guard bits[2] == "0" || bits[2] == "1" else { return nil }

        var mode: GhostRaceMode = .daily
        var refStr = bits[1]
        if ver == 2 {
            guard let tag = refStr.first, let m = GhostRaceMode(rawValue: String(tag)) else { return nil }
            mode = m
            refStr = String(refStr.dropFirst())
        }
        guard let ref = Int(refStr, radix: 36), ref >= 0, ref <= 1_000_000 else { return nil }

        let body = bits[3]
        guard !body.isEmpty else { return nil }
        let chunks = body.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard !chunks.isEmpty, chunks.count <= maxActions else { return nil }

        var t = 0
        var actions: [GhostAction] = []
        actions.reserveCapacity(chunks.count)
        for c in chunks {
            guard let packed = Int(c, radix: 36), packed >= 0 else { return nil }
            let dt = packed / 32
            let rest = packed % 32
            let band = rest & 7
            guard band <= 6 else { return nil }
            t += dt * 100
            actions.append(GhostAction(t: t, kind: (rest >> 4) & 1, improved: (rest >> 3) & 1, band: band))
        }
        return GhostRun(mode: mode, ref: ref, solved: bits[2] == "1", actions: actions)
    }

    /// Pull a run out of a tapped link. Accepts three shapes:
    ///   • `https://guesswick.com/r/<run>` — the Universal Link we hand out.
    ///   • `https://guesswick.com/?r=<run>` — the older query form, still in the wild.
    ///   • `wick://r/<run>` — the custom-scheme fallback. Universal Links do not fire
    ///     when a link is typed into Safari's address bar, when it is tapped from a
    ///     page already on guesswick.com, or while iOS holds a stale association, so
    ///     the web challenge screen offers this form instead. It has none of those
    ///     failure modes.
    static func from(url: URL) -> GhostRun? {
        var parts = url.pathComponents.filter { $0 != "/" }
        // wick://r/<run> puts the "r" in host, not in pathComponents.
        if url.scheme?.lowercased() == "wick", let host = url.host, !host.isEmpty {
            parts.insert(host, at: 0)
        }
        if parts.count >= 2, parts[0] == "r", let run = decode(parts[1]) {
            return run
        }
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let r = comps.queryItems?.first(where: { $0.name == "r" })?.value {
            return decode(r)
        }
        return nil
    }

    // MARK: - Build

    /// Assemble a run from a played round.
    ///
    /// `events` must be the guesses AND questions already merged into the order
    /// they actually happened, each with its offset from the round start. Order is
    /// the whole point: a ghost replayed out of order is a ghost that lies.
    /// Returns nil when there is nothing to replay.
    static func build(
        mode: GhostRaceMode,
        ref: Int,
        solved: Bool,
        events: [(atMs: Int, isQuestion: Bool, score: Double?)]
    ) -> GhostRun? {
        guard !events.isEmpty else { return nil }
        var best = -1.0
        var actions: [GhostAction] = []
        actions.reserveCapacity(min(events.count, maxActions))
        for e in events.prefix(maxActions) {
            var improved = 0
            if let s = e.score, s > best { best = s; improved = 1 }
            actions.append(GhostAction(
                t: e.atMs,
                kind: e.isQuestion ? 1 : 0,
                improved: improved,
                band: band(forScore: max(0, best))
            ))
        }
        return GhostRun(mode: mode, ref: ref, solved: solved, actions: actions)
    }

    /// "4:12"
    static func formatDuration(ms: Int) -> String {
        let total = max(0, Int((Double(ms) / 1000.0).rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Cross-platform contract
    //
    // These vectors were produced by the TypeScript encoder in wick-web and must
    // decode to exactly these values here. If a change breaks them, web and iOS
    // have drifted and links will silently misbehave across platforms.
    //
    //   "2-d11o-1-11k.3uy.1o2.142.6rw.88e"
    //       → daily, ref 1356, solved, 6 actions,
    //         t = 4200, 19800, 26500, 31000, 58400, 91700 ms
    //         kinds = guess, guess, question, guess, guess, guess
    //         bands = 0, 2, 2, 2, 4, 6
    //
    //   "1-11o-1-11k.3uy"    → v1 fallback: daily, ref 1356, solved, 2 actions
    //   "2-p6l-0-8a.8i"      → practice, pool index 237, unsolved, 2 actions
    //
    // A quick check, runnable in a scratch target:
    //   assert(Ghost.encode(Ghost.decode("2-d11o-1-11k.3uy.1o2.142.6rw.88e")!)
    //          == "2-d11o-1-11k.3uy.1o2.142.6rw.88e")
}
