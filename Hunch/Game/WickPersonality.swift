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

nonisolated enum WickReactionKind: String {
    case topic, leap, near, stuck, `repeat`, wild
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

    var duration: Duration { .milliseconds(durationMs) }
}

nonisolated struct WickPersonalityState {
    var seenTopics: Set<WickTopic> = []
    var lastTopic: WickTopic? = nil
    var topicRun = 0
    var lastReactionGuess = -99
    var lastWords: [String] = []
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

    /// Wick's restrained reaction director. Priority is dramatic game
    /// information, then repeated behavior, then a once per round topic beat.
    static func reaction(forGuess input: WickGuessReactionInput, state: inout WickPersonalityState) -> WickReaction? {
        let word = cleanWord(input.word)
        let topic = topic(forGuess: word)
        if let topic, topic == state.lastTopic {
            state.topicRun += 1
        } else {
            state.topicRun = topic == nil ? 0 : 1
        }
        state.lastTopic = topic
        let repeatedWord = state.lastWords.contains(word)
        var words = [word]
        words.append(contentsOf: state.lastWords.filter { $0 != word })
        state.lastWords = Array(words.prefix(5))

        let gap = input.guessCount - state.lastReactionGuess
        let gain: Double = input.previousBest.map { input.score - $0 } ?? 0
        var reaction: WickReaction? = nil

        if input.score >= 82 {
            reaction = WickReaction(kind: .near, face: .shocked, poke: true, durationMs: 1250)
        } else if gain >= 24 {
            let line: String? = gain >= 38 ? "Okay. That was a real move." : nil
            reaction = WickReaction(kind: .leap, face: .shocked, line: line, poke: true, durationMs: 1050)
        } else if repeatedWord {
            reaction = WickReaction(kind: .repeat, face: .calm, line: "You already tried that angle.", poke: false, durationMs: 1500)
        } else if state.topicRun == 3, let topic {
            reaction = WickReaction(kind: .repeat, face: .calm, line: "Still on \(topic.rawValue)? Commit to the theory, then.", poke: false, durationMs: 1700, topic: topic)
        } else if input.coldStreak >= 4, input.coldStreak % 3 == 1 {
            reaction = WickReaction(kind: .stuck, face: .calm, line: "New angle. You're circling.", poke: false, durationMs: 1650)
        } else if let topic, !state.seenTopics.contains(topic), gap >= 2 {
            let face = topicFace[topic] ?? .sly
            let poke = topic == .gross || topic == .danger || topic == .space
            let line = authoredLine(topic: topic, word: word, guessCount: input.guessCount)
            reaction = WickReaction(kind: .topic, face: face, line: line, poke: poke, durationMs: 1200, topic: topic)
        } else if let best = input.previousBest, input.score <= 8, best >= 55, gap >= 3 {
            reaction = WickReaction(kind: .wild, face: .calm, line: "That was a spectacular detour.", poke: false, durationMs: 1500)
        }

        if let topic { state.seenTopics.insert(topic) }
        if reaction != nil { state.lastReactionGuess = input.guessCount }
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
