//
//  WordBank.swift
//  Hunch
//
//  Curated secret words, tiered by "nicheness" (1 = everyday ... 4 = tricky).
//  The daily word is drawn from tiers 1–3 (fair for everyone); practice mode
//  can reach tier 4. The view model filters out any word missing from Apple's
//  embedding at runtime, so an out-of-vocabulary word can never be selected.
//

import Foundation

struct WordBank {
    struct Entry: Equatable {
        let word: String
        let tier: Int
    }

    private static let tier1 = [
        "ocean", "music", "garden", "winter", "coffee", "river", "market", "doctor",
        "animal", "school", "mountain", "family", "summer", "kitchen", "bridge", "forest",
        "island", "planet", "rocket", "guitar", "camera", "pencil", "blanket", "window",
        "dinner", "holiday", "beach", "farmer", "teacher", "painter", "butter", "cheese",
        "apple", "orange", "banana", "flower", "candle", "mirror", "ladder", "hammer",
        "pillow", "breakfast", "autumn", "morning",
        "bicycle", "umbrella", "sandwich", "balloon", "castle", "puppy", "kitten", "picnic",
        "birthday", "painting", "letter", "bottle", "basket", "pocket", "jacket", "sweater",
        "cookie", "pumpkin", "cherry", "peanut", "salad", "bedroom", "backyard", "sunshine",
        "evening", "weekend", "vacation", "railway", "village", "postcard",
        // Expansion (everyday, concrete, image-rich). Any out-of-vocabulary
        // word is skipped automatically at selection time.
        "clock", "table", "chair", "phone", "pizza", "bread", "honey", "lemon",
        "grape", "carrot", "rabbit", "horse", "tiger", "elephant", "monkey",
        "dolphin", "whale", "eagle", "owl", "spider", "snake", "turtle", "frog",
        "butterfly", "train", "airplane", "boat", "truck", "drum", "violin",
        "piano", "notebook", "spoon", "plate", "teapot", "towel"
    ]

    private static let tier2 = [
        "gravity", "harvest", "compass", "lantern", "voyage", "mineral", "justice", "melody",
        "glacier", "orchard", "volcano", "magnet", "anchor", "harbor", "soldier", "festival",
        "machine", "engine", "diamond", "crystal", "thunder", "lightning", "rainbow", "desert",
        "jungle", "meadow", "canyon", "valley", "palace", "temple", "library", "hospital",
        "factory", "telescope", "parachute", "helicopter", "submarine", "kingdom", "treasure",
        "legend", "rhythm", "symphony", "portrait", "sculpture",
        "pyramid", "fountain", "balcony", "hurricane", "tornado", "monument", "carnival",
        "orchestra", "harmony", "fortune", "courage", "freedom", "wisdom", "mystery",
        "journey", "costume", "banquet", "mansion", "cottage", "lighthouse", "windmill",
        "waterfall", "galaxy", "meteor", "asteroid", "satellite", "observatory", "aquarium",
        "stadium", "cemetery",
        // Expansion (evocative nature & time — tier 2 friendly).
        "horizon", "twilight", "blossom", "cavern", "savanna", "prairie",
        "breeze", "frost", "dawn", "dusk", "mist", "reef", "tide", "canopy",
        "summit", "ridge", "cliff", "shore"
    ]

    private static let tier3 = [
        "monsoon", "sonnet", "quartz", "ember", "tundra", "prism",
        "fossil", "nectar", "pollen", "cocoon", "antler", "quill", "parchment",
        "scroll", "dagger", "mosaic", "tapestry", "cathedral", "fortress",
        "vineyard", "equator", "plateau", "peninsula", "lagoon",
        "avalanche", "blizzard", "drought", "eclipse", "comet",
        "labyrinth", "moat", "spire", "shrine", "monastery", "sanctuary", "pendant",
        "amulet", "relic", "manuscript", "hourglass", "marsh"
    ]

    private static let tier4 = [
        "entropy", "cipher", "paradox",
        "enzyme", "neuron", "synapse", "plasma", "sediment", "magma",
        "obsidian", "granite", "marble", "alloy", "filament", "turbine", "piston", "ledger",
        "syntax", "dialect", "metaphor", "sonata",
        "forge", "nebula",
        "catalyst", "molecule", "proton", "electron", "quantum", "spectrum", "photon",
        "voltage", "circuit", "algorithm", "fractal", "theorem", "equation", "hypothesis",
        "pendulum", "antenna", "sonar",
        "radar", "helix", "polymer"
    ]

    static let all: [Entry] =
        tier1.map { Entry(word: $0, tier: 1) } +
        tier2.map { Entry(word: $0, tier: 2) } +
        tier3.map { Entry(word: $0, tier: 3) } +
        tier4.map { Entry(word: $0, tier: 4) }

    /// Words eligible to be the shared daily puzzle (kept friendly: tiers 1–2).
    static func dailyPool() -> [Entry] { all.filter { $0.tier <= 2 } }

    /// Per-language word banks, keyed by language. Add a language's bank here
    /// when its word data ships; a language without a bank falls back to
    /// English rather than crashing.
    private static let banks: [GameLanguage: [Entry]] = [
        .english: all,
        .spanish: WordBankES.all,
        .french: WordBankFR.all,
        .italian: WordBankIT.all,
        .german: WordBankDE.all,
    ]

    /// All entries for a language, falling back to the English bank.
    static func entries(for language: GameLanguage) -> [Entry] {
        banks[language] ?? all
    }

    /// Daily-eligible entries (tiers 1–2) for a language.
    static func dailyPool(for language: GameLanguage) -> [Entry] {
        entries(for: language).filter { $0.tier <= 2 }
    }

    /// The daily entry for a given day, shared by every player. Walks a
    /// per-cycle shuffle of `pool`: within any run of `pool.count` days every
    /// word appears exactly once (no repeats), and each successive pass through
    /// the pool is reshuffled so the order never feels mechanical or guessable.
    /// `pool` is passed in already filtered (e.g. to embedding-known words) so
    /// indices stay valid.
    static func dailyEntry(for day: Int, in pool: [Entry]) -> Entry {
        guard !pool.isEmpty else { return Entry(word: "ocean", tier: 1) }
        let n = pool.count
        let pos = ((day % n) + n) % n
        let cycle = Int((Double(day) / Double(n)).rounded(.down))
        let order = shuffledIndices(count: n, seed: cycleSeed(cycle))
        return pool[order[pos]]
    }

    /// The deterministic daily index into a list of `count` items for `day`.
    /// Shared so different daily lists (e.g. the bilingual pool) stay in sync
    /// across devices and languages.
    static func dailyIndex(for day: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let pos = ((day % count) + count) % count
        let cycle = Int((Double(day) / Double(count)).rounded(.down))
        return shuffledIndices(count: count, seed: cycleSeed(cycle))[pos]
    }

    /// A fixed base seed mixed with the cycle number, so each pass reshuffles
    /// but is still identical across all devices.
    private static func cycleSeed(_ cycle: Int) -> UInt64 {
        UInt64(bitPattern: Int64(cycle)) &* 0x9E3779B97F4A7C15 &+ 0xD1B54A32D192ED03
    }

    /// A deterministic Fisher–Yates permutation of 0..<count.
    private static func shuffledIndices(count: Int, seed: UInt64) -> [Int] {
        var rng = SplitMix64(seed: seed)
        var idx = Array(0..<count)
        if count > 1 {
            for i in stride(from: count - 1, to: 0, by: -1) {
                let j = Int(rng.next() % UInt64(i + 1))
                idx.swapAt(i, j)
            }
        }
        return idx
    }

    /// Whole days since the reference date — same for everyone, so the daily
    /// word is shared.
    static func dayIndex(for date: Date = Date()) -> Int {
        Int(date.timeIntervalSinceReferenceDate / 86_400)
    }

    /// A stable "puzzle number" for display/sharing.
    static func dailyNumber(for date: Date = Date()) -> Int {
        max(1, dayIndex(for: date) - 8_000)
    }

    /// The puzzle number for a given day index (mirrors `dailyNumber(for:)`).
    /// Used by the archive to label past dailies.
    static func dailyNumber(forDayIndex day: Int) -> Int {
        max(1, day - 8_000)
    }

    /// The calendar date a given day index falls on — for archive row labels.
    static func date(forDay day: Int) -> Date {
        Date(timeIntervalSinceReferenceDate: Double(day) * 86_400)
    }

    /// The first day the daily puzzle was publicly available. The archive only
    /// offers days from here onward; earlier "puzzle numbers" are a display
    /// artifact of the epoch offset and never actually shipped.
    /// NOTE: default is the dev-start day (2026-06-06, dayIndex 9287). Set this
    /// to the true public-launch day so the archive starts at the real #1.
    static let launchDayIndex = 9_287
}
