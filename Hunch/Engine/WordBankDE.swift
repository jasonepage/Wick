//
//  WordBankDE.swift
//  Hunch
//
//  German secret words, tiered by "nicheness" (1 = everyday … 4 = tricky),
//  frequency-vetted against the wordfreq German corpus and kept concrete and
//  image-rich in the daily tiers (1–2). Stored lowercase to match the embedding
//  and guess normalization. Mirrors WordBank (English). Words missing from
//  Apple's German embedding are filtered out at selection time, so an
//  out-of-vocabulary word can never be picked.
//
//  Reuses WordBank.Entry and WordBank's language-agnostic daily-selection helpers.
//

import Foundation

enum WordBankDE {

    // Everyday, concrete, high-frequency — the shared daily pool draws from tiers 1–2.
    static let tier1 = [
        "ozean", "meer", "fluss", "see", "strand", "berg", "wald", "insel", "tal", "wüste",
        "sonne", "mond", "stern", "wolke", "regen", "schnee", "feuer", "baum", "blume", "stein",
        "hund", "katze", "pferd", "kaninchen", "tier",
        "familie", "schule", "stadt", "dorf", "markt", "kirche", "krankenhaus", "küche", "garten", "brücke",
        "straße", "tür", "fenster", "tisch", "stuhl", "spiegel", "uhr", "telefon", "buch", "schlüssel",
        "brot", "käse", "milch", "ei", "apfel", "orange", "kaffee", "honig", "zucker",
        "winter", "sommer", "nacht", "zug", "auto", "boot", "flugzeug", "arzt", "lehrer",
    ]

    // Evocative but familiar — still daily-eligible.
    static let tier2 = [
        "schloss", "palast", "tempel", "bibliothek", "fabrik", "leuchtturm", "windmühle", "brunnen", "hafen", "stadion",
        "gitarre", "klavier", "geige", "trommel", "rakete", "teleskop", "u-boot", "hubschrauber", "kamera", "fahrrad",
        "tiger", "elefant", "affe", "wal", "delfin", "adler", "eule", "schlange", "schildkröte", "frosch",
        "spinne", "schmetterling", "herbst", "frühling", "morgengrauen", "sonnenuntergang", "horizont",
        "zitrone", "traube", "karotte", "kürbis", "kirsche", "salat", "kuchen", "eis",
        "vulkan", "wasserfall", "höhle", "hügel", "dschungel", "regenbogen", "schatz", "königreich", "soldat",
        "diamant", "kristall", "luftballon", "hut", "schuh", "regenschirm",
    ]

    // Practice only — less common but still concrete.
    static let tier3 = [
        "kompass", "laterne", "anker", "kerze", "hammer", "leiter", "kissen", "decke", "handtuch", "löffel",
        "teller", "heft", "bleistift", "flasche", "korb", "handschuh", "jacke", "butter", "komet", "finsternis",
        "brise", "nebel", "flut", "klippe", "riff", "lagune", "hochebene", "wiese", "schlucht", "gletscher",
        "kathedrale", "festung", "denkmal", "villa", "orchester", "pyramide",
    ]

    // Practice only — tricky, technical, or niche by design.
    static let tier4 = [
        "entropie", "paradox", "syntax", "dialekt", "metapher", "theorem", "gleichung", "algorithmus", "molekül",
        "elektron", "proton", "neuron", "plasma", "magma", "obsidian", "granit", "marmor", "filament", "turbine",
        "kolben", "pendel", "propeller", "polymer", "fossil", "nektar", "pollen", "kokon", "pergament", "dolch",
        "mosaik", "wandteppich", "amulett", "reliquie", "weinberg", "heiligtum",
    ]

    static let all: [WordBank.Entry] =
        tier1.map { WordBank.Entry(word: $0, tier: 1) } +
        tier2.map { WordBank.Entry(word: $0, tier: 2) } +
        tier3.map { WordBank.Entry(word: $0, tier: 3) } +
        tier4.map { WordBank.Entry(word: $0, tier: 4) }
}
