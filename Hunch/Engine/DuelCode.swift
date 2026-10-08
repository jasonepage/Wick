//
//  DuelCode.swift
//  Hunch
//
//  Encodes/decodes the short codes players exchange for Friend Duels — fully
//  offline, no backend. A DUEL code carries everything the friend's device needs
//  to reconstruct the exact same puzzle (mode + language + which curated word); a
//  RESULT code carries a finished score so the challenger can render a head-to-head.
//
//  Curated words only (v1): the payload is a small *index* into
//  `WordBank.entries(for:)`, so codes stay tiny and the friend resolves the same
//  secret deterministically. The recipient can't read the word from the code
//  (it's an obfuscated index, not text).
//
//  Wire format (bit-packed → XOR salt → Base62, with a human prefix):
//    DUEL   "WK-…"  [version:4][kind:2=0][mode:2][lang:4][wordIndex:18] + [checksum:8]
//    RESULT "WR-…"  [version:4][kind:2=1][lang:4][wordIndex:18][solved:1][gaveUp:1][guesses:12] + [checksum:8]
//
//  Vocab-drift guard: indices are stable only within a schema version. Appending
//  new words to a bank keeps old codes valid; REORDERING a bank requires bumping
//  `schemaVersion` (a bumped/foreign code fails to decode rather than resolving to
//  the wrong word). Mirrored by `debug/duel_tracer.py` — keep them in lockstep.
//

import Foundation

enum DuelMode: Int, Equatable {
    case dare = 0   // retired in 3.3; kept so old codes still decode, then ignored
    case race = 1   // Wick picks; neither sees it; both play the same word
}

struct DuelPayload: Equatable {
    var mode: DuelMode
    var language: GameLanguage
    var wordIndex: Int
}

struct DuelResult: Equatable {
    var language: GameLanguage
    var wordIndex: Int      // identifies which duel this result is for
    var solved: Bool
    var gaveUp: Bool
    var guessCount: Int
}

enum DuelCode {

    static let schemaVersion = 1
    static let duelPrefix = "WK-"
    static let resultPrefix = "WR-"

    private static let salt: UInt64 = 0x5F3A_9C2E_17B4_D6A1

    private static let kindDuel: UInt64 = 0
    private static let kindResult: UInt64 = 1

    // Field widths (bits)
    private static let versionBits: UInt64 = 4
    private static let kindBits: UInt64 = 2
    private static let modeBits: UInt64 = 2
    private static let langBits: UInt64 = 4
    private static let wordBits: UInt64 = 18
    private static let solvedBits: UInt64 = 1
    private static let gaveUpBits: UInt64 = 1
    private static let guessBits: UInt64 = 12
    private static let checkBits: UInt64 = 8

    // Total packed width per kind (payload + checksum). Salt is masked to this so
    // codes stay short (no high-bit spill from the 63-bit salt).
    private static let duelTotalBits: UInt64 = 4 + 2 + 2 + 4 + 18 + 8      // 38
    private static let resultTotalBits: UInt64 = 4 + 2 + 4 + 18 + 1 + 1 + 12 + 8  // 50

    // MARK: - Language index (explicit, NOT enum order — order must never shift)

    private static let languageOrder: [GameLanguage] = [.english, .spanish, .french, .italian, .german]

    private static func index(of language: GameLanguage) -> UInt64 {
        UInt64(languageOrder.firstIndex(of: language) ?? 0)
    }
    private static func language(at index: UInt64) -> GameLanguage? {
        let i = Int(index)
        return languageOrder.indices.contains(i) ? languageOrder[i] : nil
    }

    // MARK: - Encode

    static func encode(_ p: DuelPayload) -> String? {
        guard (0..<(1 << Int(wordBits))).contains(p.wordIndex) else { return nil }
        var v: UInt64 = UInt64(schemaVersion)
        v = (v << kindBits)  | kindDuel
        v = (v << modeBits)  | UInt64(p.mode.rawValue)
        v = (v << langBits)  | index(of: p.language)
        v = (v << wordBits)  | UInt64(p.wordIndex)
        return duelPrefix + pack(v, totalBits: duelTotalBits)
    }

    static func encode(_ r: DuelResult) -> String? {
        guard (0..<(1 << Int(wordBits))).contains(r.wordIndex) else { return nil }
        let guesses = min(max(r.guessCount, 0), (1 << Int(guessBits)) - 1)
        var v: UInt64 = UInt64(schemaVersion)
        v = (v << kindBits)   | kindResult
        v = (v << langBits)   | index(of: r.language)
        v = (v << wordBits)   | UInt64(r.wordIndex)
        v = (v << solvedBits) | (r.solved ? 1 : 0)
        v = (v << gaveUpBits) | (r.gaveUp ? 1 : 0)
        v = (v << guessBits)  | UInt64(guesses)
        return resultPrefix + pack(v, totalBits: resultTotalBits)
    }

    // MARK: - Decode

    static func decodeDuel(_ code: String) -> DuelPayload? {
        guard let v = unpack(code, prefix: duelPrefix, totalBits: duelTotalBits) else { return nil }
        var x = v
        let wordIndex = x & mask(wordBits);            x >>= wordBits
        let lang      = x & mask(langBits);            x >>= langBits
        let mode      = x & mask(modeBits);            x >>= modeBits
        let kind      = x & mask(kindBits);            x >>= kindBits
        let version   = x & mask(versionBits)
        guard version == UInt64(schemaVersion), kind == kindDuel,
              let language = language(at: lang),
              let m = DuelMode(rawValue: Int(mode)) else { return nil }
        return DuelPayload(mode: m, language: language, wordIndex: Int(wordIndex))
    }

    static func decodeResult(_ code: String) -> DuelResult? {
        guard let v = unpack(code, prefix: resultPrefix, totalBits: resultTotalBits) else { return nil }
        var x = v
        let guesses = x & mask(guessBits);   x >>= guessBits
        let gaveUp  = x & mask(gaveUpBits);  x >>= gaveUpBits
        let solved  = x & mask(solvedBits);  x >>= solvedBits
        let wordIndex = x & mask(wordBits);  x >>= wordBits
        let lang    = x & mask(langBits);    x >>= langBits
        let kind    = x & mask(kindBits);    x >>= kindBits
        let version = x & mask(versionBits)
        guard version == UInt64(schemaVersion), kind == kindResult,
              let language = language(at: lang) else { return nil }
        return DuelResult(language: language, wordIndex: Int(wordIndex),
                          solved: solved == 1, gaveUp: gaveUp == 1, guessCount: Int(guesses))
    }

    /// True if the string looks like either kind of duel code (cheap pre-check).
    static func looksLikeCode(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return t.hasPrefix(duelPrefix) || t.hasPrefix(resultPrefix)
    }

    // MARK: - Bit / Base62 plumbing

    private static func mask(_ bits: UInt64) -> UInt64 { (1 << bits) - 1 }

    /// Sum of the 8 low bytes, mod 256 — a light typo check (not security).
    private static func checksum(_ payload: UInt64) -> UInt64 {
        var h: UInt64 = 0, x = payload
        for _ in 0..<8 { h = (h &+ (x & 0xFF)) & 0xFF; x >>= 8 }
        return h & 0xFF
    }

    private static func pack(_ payload: UInt64, totalBits: UInt64) -> String {
        let full = (payload << checkBits) | checksum(payload)
        return base62(full ^ (salt & mask(totalBits)))
    }

    private static func unpack(_ code: String, prefix: String, totalBits: UInt64) -> UInt64? {
        var t = code.trimmingCharacters(in: .whitespacesAndNewlines)
        // Accept a bare code or one with the prefix, case-insensitively on the prefix.
        if t.uppercased().hasPrefix(prefix) { t = String(t.dropFirst(prefix.count)) }
        guard let obf = base62Decode(t) else { return nil }
        let full = obf ^ (salt & mask(totalBits))
        let cs = full & mask(checkBits)
        let payload = full >> checkBits
        guard checksum(payload) == cs else { return nil }
        return payload
    }

    private static let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    private static let alphabetIndex: [Character: UInt64] = {
        var m: [Character: UInt64] = [:]
        for (i, c) in alphabet.enumerated() { m[c] = UInt64(i) }
        return m
    }()

    private static func base62(_ value: UInt64) -> String {
        if value == 0 { return String(alphabet[0]) }
        var v = value, chars: [Character] = []
        while v > 0 { chars.append(alphabet[Int(v % 62)]); v /= 62 }
        return String(chars.reversed())
    }

    private static func base62Decode(_ s: String) -> UInt64? {
        guard !s.isEmpty else { return nil }
        var v: UInt64 = 0
        for c in s {
            guard let d = alphabetIndex[c] else { return nil }
            let (m, ov1) = v.multipliedReportingOverflow(by: 62)
            guard !ov1 else { return nil }
            let (a, ov2) = m.addingReportingOverflow(d)
            guard !ov2 else { return nil }
            v = a
        }
        return v
    }
}
