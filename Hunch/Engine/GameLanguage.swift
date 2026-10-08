//
//  GameLanguage.swift
//  Hunch
//
//  The language a round is played in. Drives which word embedding, word bank,
//  rank vocabulary, and Keeper prompt are used.
//
//  1.8: data-driven. Each case carries metadata (NLLanguage, native name, flag,
//  fallback/probe words, localized names), and every picker iterates `all` —
//  so adding a language is one new case plus one `Meta` entry (plus its word
//  data). Play and Learn languages are now independent choices.
//

import Foundation
import NaturalLanguage

enum GameLanguage: String, CaseIterable, Codable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case italian = "it"
    case german = "de"

    var id: String { rawValue }

    /// Every supported language, in picker order. Pickers iterate this —
    /// never hardcode cases in UI.
    static var all: [GameLanguage] { allCases }

    // MARK: - Metadata

    /// Everything the app needs to know about a language, in one place.
    struct Meta {
        /// The Natural Language language used for embeddings, lemmas, tagging.
        let nl: NLLanguage
        /// The language's name in itself ("Español", "Français").
        let nativeName: String
        /// Flag paired with the native name in pickers. Flags aren't 1:1 with
        /// languages, so the flag never appears without the name.
        let flag: String
        /// A safe, in-vocabulary fallback secret if word selection comes up empty.
        let fallbackWord: String
        /// A common word used to probe whether the embedding exists on-device.
        let probeWord: String
        /// This language's name in each UI language, keyed by language code
        /// ("Spanish" in English, "espagnol" in French). Falls back to nativeName.
        let localizedNames: [String: String]
    }

    private static let metadata: [GameLanguage: Meta] = [
        .english: Meta(
            nl: .english,
            nativeName: "English",
            flag: "🇺🇸",
            fallbackWord: "ocean",
            probeWord: "house",
            // French and Italian names carry their article ("l'anglais",
            // "l'inglese") because sentences naming a language there need one.
            localizedNames: ["en": "English", "es": "inglés", "fr": "l'anglais", "it": "l'inglese", "de": "Englisch"]
        ),
        .spanish: Meta(
            nl: .spanish,
            nativeName: "Español",
            flag: "🇪🇸",
            fallbackWord: "océano",
            probeWord: "casa",
            localizedNames: ["en": "Spanish", "es": "español", "fr": "l'espagnol", "it": "lo spagnolo", "de": "Spanisch"]
        ),
        .french: Meta(
            nl: .french,
            nativeName: "Français",
            flag: "🇫🇷",
            fallbackWord: "océan",
            probeWord: "maison",
            localizedNames: ["en": "French", "es": "francés", "fr": "le français", "it": "il francese", "de": "Französisch"]
        ),
        .italian: Meta(
            nl: .italian,
            nativeName: "Italiano",
            flag: "🇮🇹",
            fallbackWord: "oceano",
            probeWord: "casa",
            localizedNames: ["en": "Italian", "es": "italiano", "fr": "l'italien", "it": "l'italiano", "de": "Italienisch"]
        ),
        .german: Meta(
            nl: .german,
            nativeName: "Deutsch",
            flag: "🇩🇪",
            fallbackWord: "ozean",
            probeWord: "haus",
            localizedNames: ["en": "German", "es": "alemán", "fr": "l'allemand", "it": "il tedesco", "de": "Deutsch"]
        ),
    ]

    var meta: Meta { Self.metadata[self]! }

    var nl: NLLanguage { meta.nl }
    var nativeName: String { meta.nativeName }
    var flag: String { meta.flag }
    var fallbackWord: String { meta.fallbackWord }
    var probeWord: String { meta.probeWord }

    /// Label for the language picker: "🇪🇸 Español".
    var pickerLabel: String { "\(flag) \(nativeName)" }

    /// Kept for existing call sites; pickers should prefer `pickerLabel`.
    var displayName: String { nativeName }

    /// This language's name as written in `language` — "Spanish" when the UI
    /// is English, "Inglés" when it's Spanish. Falls back to the native name.
    func name(in language: GameLanguage) -> String {
        meta.localizedNames[language.rawValue] ?? nativeName
    }

    // MARK: - Persistence

    /// Persisted PLAY language choice.
    static let storageKey = "hunch.language"
    /// Persisted LEARN language choice (independent of play since 1.8).
    static let learnStorageKey = "hunch.learnLanguage"

    /// The persisted play choice if the player has picked one; otherwise the
    /// device language (when we support it), else English.
    static var stored: GameLanguage {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let lang = GameLanguage(rawValue: raw) {
            return lang
        }
        return deviceDefault
    }

    /// The persisted learn choice, if any and still valid alongside `playing`.
    static func storedLearn(playing: GameLanguage) -> GameLanguage? {
        guard let raw = UserDefaults.standard.string(forKey: learnStorageKey),
              let lang = GameLanguage(rawValue: raw),
              lang != playing else { return nil }
        return lang
    }

    /// Default learn language while playing `playing`: English pairs with the
    /// first non-English language; everything else pairs back to English (the
    /// hub language the accuracy layer pivots through).
    static func defaultLearn(playing: GameLanguage) -> GameLanguage {
        playing == .english
            ? (all.first { $0 != .english } ?? .english)
            : .english
    }

    /// Best match for the device's preferred language among the languages we
    /// support. Falls back to English. Used only until the player picks one.
    static var deviceDefault: GameLanguage {
        let code = Locale.preferredLanguages.first
            .flatMap { Locale(identifier: $0).language.languageCode?.identifier }
        return all.first { $0.rawValue == code } ?? .english
    }
}
