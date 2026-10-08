//
//  WordBankIT.swift
//  Hunch
//
//  Italian secret words, tiered by "nicheness" (1 = everyday … 4 = tricky),
//  frequency-vetted against the wordfreq Italian corpus and kept concrete and
//  image-rich in the daily tiers (1–2). Mirrors WordBank (English). Words missing
//  from Apple's Italian embedding are filtered out at selection time, so an
//  out-of-vocabulary word can never be picked.
//
//  Reuses WordBank.Entry and WordBank's language-agnostic daily-selection helpers.
//

import Foundation

enum WordBankIT {

    // Everyday, concrete, high-frequency — the shared daily pool draws from tiers 1–2.
    static let tier1 = [
        "oceano", "mare", "fiume", "lago", "spiaggia", "montagna", "foresta", "isola", "valle", "deserto",
        "sole", "luna", "stella", "nuvola", "pioggia", "neve", "fuoco", "albero", "fiore", "pietra",
        "cane", "gatto", "cavallo", "coniglio", "animale",
        "famiglia", "scuola", "città", "paese", "mercato", "chiesa", "ospedale", "cucina", "giardino", "ponte",
        "strada", "porta", "finestra", "tavolo", "sedia", "specchio", "orologio", "telefono", "libro", "chiave",
        "pane", "formaggio", "latte", "uovo", "mela", "arancia", "caffè", "miele", "zucchero",
        "inverno", "estate", "notte", "treno", "macchina", "barca", "aereo", "medico", "insegnante",
    ]

    // Evocative but familiar — still daily-eligible.
    static let tier2 = [
        "castello", "palazzo", "tempio", "biblioteca", "fabbrica", "faro", "mulino", "fontana", "porto", "stadio",
        "chitarra", "pianoforte", "violino", "tamburo", "razzo", "telescopio", "sottomarino", "elicottero", "fotocamera", "bicicletta",
        "tigre", "elefante", "scimmia", "balena", "delfino", "aquila", "gufo", "serpente", "tartaruga", "rana",
        "ragno", "farfalla", "autunno", "primavera", "alba", "tramonto", "orizzonte",
        "limone", "uva", "carota", "zucca", "ciliegia", "insalata", "torta", "gelato",
        "vulcano", "cascata", "grotta", "collina", "giungla", "arcobaleno", "tesoro", "regno", "soldato",
        "diamante", "cristallo", "palloncino", "cappello", "scarpa", "ombrello",
    ]

    // Practice only — less common but still concrete.
    static let tier3 = [
        "bussola", "lanterna", "ancora", "candela", "martello", "scala", "cuscino", "coperta", "asciugamano", "cucchiaio",
        "piatto", "quaderno", "matita", "bottiglia", "cesto", "guanto", "giacca", "burro", "cometa", "eclissi",
        "brezza", "nebbia", "marea", "rupe", "scogliera", "laguna", "altopiano", "prato", "canyon", "ghiacciaio",
        "cattedrale", "fortezza", "monumento", "villa", "orchestra", "piramide",
    ]

    // Practice only — tricky, technical, or niche by design.
    static let tier4 = [
        "entropia", "paradosso", "sintassi", "dialetto", "metafora", "teorema", "equazione", "algoritmo", "molecola",
        "elettrone", "protone", "neurone", "plasma", "magma", "ossidiana", "granito", "marmo", "filamento", "turbina",
        "pistone", "pendolo", "elica", "polimero", "fossile", "nettare", "polline", "bozzolo", "pergamena", "pugnale",
        "mosaico", "arazzo", "amuleto", "reliquia", "vigneto", "santuario",
    ]

    static let all: [WordBank.Entry] =
        tier1.map { WordBank.Entry(word: $0, tier: 1) } +
        tier2.map { WordBank.Entry(word: $0, tier: 2) } +
        tier3.map { WordBank.Entry(word: $0, tier: 3) } +
        tier4.map { WordBank.Entry(word: $0, tier: 4) }
}
