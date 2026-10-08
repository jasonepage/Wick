//
//  Achievements.swift
//  Hunch
//
//  Local, on-device achievements. Unlock IDs are stored in UserDefaults.
//

import Foundation

struct Achievement: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let icon: String
}

enum Achievements {
    static let all: [Achievement] = [
        Achievement(id: "first_solve",  title: "First Guess",     detail: "Solve your first word",            icon: "star.fill"),
        Achievement(id: "guesses_5",    title: "Sharp",           detail: "Solve in 5 guesses or fewer",      icon: "scope"),
        Achievement(id: "guesses_3",    title: "Mind Reader",     detail: "Solve in 3 guesses or fewer",      icon: "brain.head.profile"),
        Achievement(id: "no_hints",     title: "Unaided",         detail: "Solve without using a hint",       icon: "hand.raised.fill"),
        Achievement(id: "no_questions", title: "Silent",          detail: "Solve without asking the Keeper",  icon: "bubble.left"),
        Achievement(id: "streak_3",     title: "Kindling",        detail: "Reach a 3-day streak",             icon: "flame"),
        Achievement(id: "streak_7",     title: "On Fire",         detail: "Reach a 7-day streak",             icon: "flame.fill"),
        Achievement(id: "streak_30",    title: "Inferno",         detail: "Reach a 30-day streak",            icon: "flame.circle.fill"),
        Achievement(id: "solves_10",    title: "Getting Warm",    detail: "Solve 10 words",                   icon: "checkmark.seal.fill"),
        Achievement(id: "solves_50",    title: "Wordsmith",       detail: "Solve 50 words",                   icon: "crown.fill"),
        Achievement(id: "solves_100",   title: "Lexicon Legend",  detail: "Solve 100 words",                  icon: "trophy.fill")
    ]

    static func title(for id: String) -> String {
        all.first { $0.id == id }?.title ?? id
    }

    // Per-language title/detail tables keyed by achievement ID. English lives
    // in `all`; a language missing here (or an unmapped ID) falls back to it.
    // Adding a language = adding one entry to each table.

    private static let titles: [GameLanguage: [String: String]] = [
        .spanish: [
            "first_solve":  "Primera corazonada",
            "guesses_5":    "Agudo",
            "guesses_3":    "Lector de mentes",
            "no_hints":     "Sin ayuda",
            "no_questions": "Silencioso",
            "streak_3":     "Chispa",
            "streak_7":     "En llamas",
            "streak_30":    "Infierno",
            "solves_10":    "Calentando",
            "solves_50":    "Maestro de palabras",
            "solves_100":   "Leyenda del léxico",
        ],
        .french: [
            "first_solve":  "Première intuition",
            "guesses_5":    "Perspicace",
            "guesses_3":    "Devin",
            "no_hints":     "Sans aide",
            "no_questions": "Silencieux",
            "streak_3":     "Étincelle",
            "streak_7":     "En feu",
            "streak_30":    "Brasier",
            "solves_10":    "Ça chauffe",
            "solves_50":    "Maître des mots",
            "solves_100":   "Légende du lexique",
        ],
        .italian: [
            "first_solve":  "Prima intuizione",
            "guesses_5":    "Perspicace",
            "guesses_3":    "Telepate",
            "no_hints":     "Senza aiuto",
            "no_questions": "Silenzioso",
            "streak_3":     "Scintilla",
            "streak_7":     "In fiamme",
            "streak_30":    "Inferno",
            "solves_10":    "Si scalda",
            "solves_50":    "Maestro di parole",
            "solves_100":   "Leggenda del lessico",
        ],
        .german: [
            "first_solve":  "Erste Ahnung",
            "guesses_5":    "Scharfsinnig",
            "guesses_3":    "Gedankenleser",
            "no_hints":     "Ohne Hilfe",
            "no_questions": "Schweigsam",
            "streak_3":     "Funke",
            "streak_7":     "In Flammen",
            "streak_30":    "Inferno",
            "solves_10":    "Wird warm",
            "solves_50":    "Wortmeister",
            "solves_100":   "Lexikon-Legende",
        ],
    ]

    private static let details: [GameLanguage: [String: String]] = [
        .spanish: [
            "first_solve":  "Resuelve tu primera palabra",
            "guesses_5":    "Resuelve en 5 intentos o menos",
            "guesses_3":    "Resuelve en 3 intentos o menos",
            "no_hints":     "Resuelve sin usar una pista",
            "no_questions": "Resuelve sin preguntar al Guardián",
            "streak_3":     "Alcanza una racha de 3 días",
            "streak_7":     "Alcanza una racha de 7 días",
            "streak_30":    "Alcanza una racha de 30 días",
            "solves_10":    "Resuelve 10 palabras",
            "solves_50":    "Resuelve 50 palabras",
            "solves_100":   "Resuelve 100 palabras",
        ],
        .french: [
            "first_solve":  "Trouve ton premier mot",
            "guesses_5":    "Trouve en 5 essais ou moins",
            "guesses_3":    "Trouve en 3 essais ou moins",
            "no_hints":     "Trouve sans utiliser d'indice",
            "no_questions": "Trouve sans interroger le Gardien",
            "streak_3":     "Atteins une série de 3 jours",
            "streak_7":     "Atteins une série de 7 jours",
            "streak_30":    "Atteins une série de 30 jours",
            "solves_10":    "Trouve 10 mots",
            "solves_50":    "Trouve 50 mots",
            "solves_100":   "Trouve 100 mots",
        ],
        .italian: [
            "first_solve":  "Risolvi la tua prima parola",
            "guesses_5":    "Risolvi in 5 tentativi o meno",
            "guesses_3":    "Risolvi in 3 tentativi o meno",
            "no_hints":     "Risolvi senza usare un indizio",
            "no_questions": "Risolvi senza chiedere al Custode",
            "streak_3":     "Raggiungi una serie di 3 giorni",
            "streak_7":     "Raggiungi una serie di 7 giorni",
            "streak_30":    "Raggiungi una serie di 30 giorni",
            "solves_10":    "Risolvi 10 parole",
            "solves_50":    "Risolvi 50 parole",
            "solves_100":   "Risolvi 100 parole",
        ],
        .german: [
            "first_solve":  "Löse dein erstes Wort",
            "guesses_5":    "Löse in 5 Versuchen oder weniger",
            "guesses_3":    "Löse in 3 Versuchen oder weniger",
            "no_hints":     "Löse ohne einen Hinweis",
            "no_questions": "Löse, ohne den Hüter zu fragen",
            "streak_3":     "Erreiche eine 3-Tage-Serie",
            "streak_7":     "Erreiche eine 7-Tage-Serie",
            "streak_30":    "Erreiche eine 30-Tage-Serie",
            "solves_10":    "Löse 10 Wörter",
            "solves_50":    "Löse 50 Wörter",
            "solves_100":   "Löse 100 Wörter",
        ],
    ]

    static func title(for id: String, _ language: GameLanguage) -> String {
        titles[language]?[id] ?? title(for: id)
    }

    static func detail(for id: String, _ language: GameLanguage) -> String {
        details[language]?[id] ?? all.first { $0.id == id }?.detail ?? ""
    }
}
