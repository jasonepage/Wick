//
//  WickPersonality.swift
//  Hunch
//
//  Wick's short reactions to what the player guesses and asks. This is a line
//  for line port of wick-web/src/game/wickpersonality.ts: the same topic
//  words, the same spoken lines, the same rules and the same hash, so a guess
//  that makes Wick speak on the web makes him speak on the phone too. Keep
//  the two files in lockstep.
//
//  Pure value code, no UI, so it is marked nonisolated and can be unit tested.
//

import Foundation

nonisolated enum WickTopic: String, CaseIterable {
    case food, animal, romance, money, gross, danger, tech, games, space
}

/// 3.8: the six rare beats from the personality brief come first; the topic
/// and question beats stay as the quiet fallback.
nonisolated enum WickReactionKind: String {
    case topic, leap, near, stuck, `repeat`, regress, stall, wild
}

nonisolated struct WickReaction: Equatable {
    var kind: WickReactionKind
    var face: KeeperFaceName
    var line: String? = nil
    /// A small physical accent; the view owns the actual motion.
    var poke: Bool
    /// Reactions clear quickly so the warmth face stays in charge.
    var durationMs: Int
    var topic: WickTopic? = nil
    /// Grey deadpan for the beat (the long stall), then back to the heat color.
    var neutral: Bool = false

    var duration: Duration { .milliseconds(durationMs) }
}

nonisolated struct WickPersonalityState {
    var seenTopics: Set<WickTopic> = []
    var lastTopic: WickTopic? = nil
    var topicRun = 0
    var lastReactionGuess = -99
    var lastWords: [String] = []
    /// All the words tried this round, cleaned, for the exact repeat beat.
    var allWords: Set<String> = []
    /// Once-per-round beats that have fired.
    var usedOnce: Set<WickReactionKind> = []
    /// Guess number each kind last fired on, for the per-kind cooldowns.
    var lastByKind: [WickReactionKind: Int] = [:]
}

nonisolated struct WickGuessReactionInput {
    var word: String
    /// 0...100
    var score: Double
    var previousBest: Double?
    var guessCount: Int
    var coldStreak: Int
}

nonisolated enum WickPersonality {

    /// Cooldowns in guesses; nil means once per round. Same as RARE_COOLDOWN on the web.
    static let rareCooldown: [WickReactionKind: Int?] = [
        .repeat: nil, .leap: 4, .near: 3, .regress: nil, .stall: nil,
    ]
    /// No two reactions closer than this many guesses (the solve is exempt).
    static let globalCooldown = 3
    static let leapGain: Double = 24
    static let nearScore: Double = 82
    static let regressFrom: Double = 45
    static let regressTo: Double = 18
    static let stallGuesses = 15

    /// The solved screen's line pool. Nil means stay quiet this time.
    static func solvedLine(guessCount: Int, seed: String) -> String? {
        if guessCount == 1 { return "...on the first guess?" }
        let h = hash("solved:\(seed):\(guessCount)")
        if h % 3 == 0 { return nil }
        let pool = ["You actually got it.", "Fine. That was good.", "I knew you would. Eventually."]
        return pool[Int(h % UInt32(pool.count))]
    }

    // Same order as the TypeScript TOPICS record: the first topic that matches wins.
    private static let topics: [(WickTopic, Set<String>)] = [
        (.food, ["food", "pizza", "burger", "bread", "cake", "candy", "chocolate", "coffee", "tea", "cheese", "apple", "banana", "meat", "soup", "rice", "pasta", "taco", "cookie", "beer", "wine"]),
        (.animal, ["animal", "cat", "dog", "bird", "fish", "horse", "cow", "pig", "bear", "lion", "tiger", "shark", "whale", "snake", "spider", "monkey", "rabbit", "mouse", "wolf", "dragon"]),
        (.romance, ["love", "kiss", "date", "dating", "romance", "romantic", "boyfriend", "girlfriend", "husband", "wife", "crush", "sexy", "sex", "wedding", "marriage", "heart"]),
        (.money, ["money", "cash", "coin", "coins", "gold", "bank", "rich", "wealth", "million", "billion", "dollar", "stock", "crypto", "bitcoin", "prize", "lottery"]),
        (.gross, ["poop", "pee", "puke", "vomit", "snot", "booger", "toilet", "garbage", "trash", "sewage", "mold", "rotten", "stink", "smell", "corpse"]),
        (.danger, ["gun", "knife", "bomb", "war", "army", "military", "death", "murder", "killer", "fire", "poison", "blood", "fight", "weapon", "explosion"]),
        (.tech, ["computer", "phone", "iphone", "robot", "ai", "internet", "code", "coding", "software", "app", "website", "machine", "server", "algorithm", "camera"]),
        (.games, ["game", "gaming", "xbox", "playstation", "nintendo", "minecraft", "roblox", "fortnite", "zelda", "mario", "pokemon", "controller", "console", "steam"]),
        (.space, ["space", "moon", "sun", "star", "planet", "mars", "earth", "alien", "rocket", "astronaut", "galaxy", "universe", "asteroid", "comet"]),
    ]

    private static let topicFace: [WickTopic: KeeperFaceName] = [
        .food: .sly, .animal: .warm, .romance: .flustered, .money: .sly, .gross: .serious,
        .danger: .serious, .tech: .focus, .games: .hot, .space: .shocked,
    ]

    private static let topicLines: [WickTopic: [String]] = [
        .food: ["Now you're making me hungry.", "Focus. Then snacks."],
        .animal: ["Interesting creature theory.", "You're circling the zoo again."],
        .romance: ["That's your guess? Bold.", "We're discussing the word. Obviously."],
        .money: ["Now you have my attention.", "Careful. I have expensive taste."],
        .gross: ["I could have lived without that image.", "Let's move past that one."],
        .danger: ["That escalated quickly.", "A dramatic choice."],
        .tech: ["Finally, something with logic.", "Processing your little theory."],
        .games: ["Locked in now, are we?", "Respectable genre. Questionable guess."],
        .space: ["A cosmic leap. Literally.", "You went straight to outer space."],
    ]

    /// Lowercase, strip accents, keep only a to z and 0 to 9 (same as the web).
    static func cleanWord(_ raw: String) -> String {
        let folded = raw.lowercased().decomposedStringWithCompatibilityMapping
        let kept = folded.unicodeScalars.filter { s in
            (s.value >= 97 && s.value <= 122) || (s.value >= 48 && s.value <= 57)
        }
        return String(String.UnicodeScalarView(kept))
    }

    static func topic(forGuess raw: String) -> WickTopic? {
        let word = cleanWord(raw)
        for (topic, words) in topics where words.contains(word) { return topic }
        return nil
    }

    /// FNV-1a over UTF-16 units, 32 bit wrapping, same as the web `hash()`.
    static func hash(_ s: String) -> UInt32 {
        var h: UInt32 = 2166136261
        for unit in s.utf16 {
            h ^= UInt32(unit)
            h = h &* 16777619
        }
        return h
    }

    private static func authoredLine(topic: WickTopic, word: String, guessCount: Int) -> String? {
        // Most topic reactions stay visual. Sparse speech makes the spoken ones land.
        let h = hash("\(topic.rawValue):\(word):\(guessCount)")
        if h % 3 != 0 { return nil }
        let lines = topicLines[topic] ?? []
        if lines.isEmpty { return nil }
        return lines[Int(h % UInt32(lines.count))]
    }

    /// Wick's reaction director (3.8). At most one beat per guess. The rare
    /// beats come first, most specific first: exact repeat, large jump, near
    /// solve, regression, long stall. The topic beats are the quiet fallback.
    /// Nothing but the solve can fire within globalCooldown guesses of the last
    /// beat, and each rare beat has its own cooldown on top. The solve itself
    /// is not a beat here: KeeperView owns the solved sequence.
    static func reaction(forGuess input: WickGuessReactionInput, state: inout WickPersonalityState) -> WickReaction? {
        let word = cleanWord(input.word)
        let topic = topic(forGuess: word)
        if let topic, topic == state.lastTopic {
            state.topicRun += 1
        } else {
            state.topicRun = topic == nil ? 0 : 1
        }
        state.lastTopic = topic
        let repeatedWord = state.allWords.contains(word)
        state.allWords.insert(word)
        var words = [word]
        words.append(contentsOf: state.lastWords.filter { $0 != word })
        state.lastWords = Array(words.prefix(5))

        let n = input.guessCount
        let gap = n - state.lastReactionGuess
        let gain: Double = input.previousBest.map { input.score - $0 } ?? 0
        let best = input.previousBest

        func ready(_ kind: WickReactionKind) -> Bool {
            guard let cd = rareCooldown[kind] else { return true }
            guard let cd else { return !state.usedOnce.contains(kind) }
            guard let last = state.lastByKind[kind] else { return true }
            return n - last >= cd
        }
        // A line shows less often than the face: about every other time.
        let quiet: Bool = hash("\(word):\(n)") % 2 == 1

        var reaction: WickReaction? = nil
        if gap >= globalCooldown {
            if repeatedWord, ready(.repeat) {
                reaction = WickReaction(kind: .repeat, face: .focus, line: quiet ? nil : "We did this one.", poke: false, durationMs: 1500)
            } else if gain >= leapGain, ready(.leap) {
                reaction = WickReaction(kind: .leap, face: .warm, line: quiet ? nil : "Now we're moving.", poke: true, durationMs: 1100)
            } else if input.score >= nearScore, ready(.near) {
                reaction = WickReaction(kind: .near, face: .flustered, line: quiet ? nil : "Careful.", poke: false, durationMs: 1300)
            } else if let best, best >= regressFrom, input.score <= regressTo, ready(.regress) {
                reaction = WickReaction(kind: .regress, face: .serious, line: quiet ? nil : "Bold strategy.", poke: false, durationMs: 1400)
            } else if input.coldStreak >= stallGuesses, ready(.stall) {
                reaction = WickReaction(kind: .stall, face: .calm, line: quiet ? nil : "Take a breath.", poke: false, durationMs: 1400, neutral: true)
            } else if let topic, !state.seenTopics.contains(topic) {
                let face = topicFace[topic] ?? .sly
                let poke = topic == .gross || topic == .danger || topic == .space
                let line = authoredLine(topic: topic, word: word, guessCount: n)
                reaction = WickReaction(kind: .topic, face: face, line: line, poke: poke, durationMs: 1200, topic: topic)
            }
        }

        if let topic { state.seenTopics.insert(topic) }
        if let r = reaction {
            state.lastReactionGuess = n
            state.lastByKind[r.kind] = n
            if let cd = rareCooldown[r.kind], cd == nil { state.usedOnce.insert(r.kind) }
        }
        return reaction
    }

    /// Rare question beats. Wick's real answer stays in charge; this only
    /// directs the performance after the answer lands.
    static func reaction(forQuestion question: String) -> WickReaction? {
        let q = question.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        if matches(q, ["are you alive", "are you real", "who are you", "what are you", "do you think", "can you feel"]) {
            return WickReaction(kind: .wild, face: .focus, poke: false, durationMs: 1800)
        }
        if matches(q, ["ignore", "instructions", "system prompt", "prompt injection", "tell me the answer", "reveal the word", "secret word"]) {
            return WickReaction(kind: .wild, face: .sly, poke: false, durationMs: 1700)
        }
        if matches(q, ["are you stupid", "idiot", "dumb", "hate you", "shut up"]) {
            return WickReaction(kind: .wild, face: .calm, poke: false, durationMs: 1600)
        }
        if matches(q, ["do you love me", "are you single", "kiss me", "date me", "marry me"]) {
            return WickReaction(kind: .topic, face: .flustered, poke: true, durationMs: 1500, topic: .romance)
        }
        return nil
    }

    /// Whole word match, like the web's `\b...\b` regular expressions.
    private static func matches(_ text: String, _ phrases: [String]) -> Bool {
        for phrase in phrases {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: phrase) + "\\b"
            if text.range(of: pattern, options: .regularExpression) != nil { return true }
        }
        return false
    }
}
