//
//  WordBankFR.swift
//  Hunch
//
//  French secret words, tiered by "nicheness" (1 = everyday … 4 = tricky),
//  frequency-vetted against the wordfreq French corpus and kept concrete and
//  image-rich in the daily tiers (1–2). Mirrors WordBank (English). Words missing
//  from Apple's French embedding are filtered out at selection time, so an
//  out-of-vocabulary word can never be picked.
//
//  Reuses WordBank.Entry and WordBank's language-agnostic daily-selection helpers.
//

import Foundation

enum WordBankFR {

    // Everyday, concrete, high-frequency — the shared daily pool draws from tiers 1–2.
    static let tier1 = [
        "océan", "mer", "rivière", "lac", "plage", "montagne", "forêt", "île", "vallée", "désert",
        "soleil", "lune", "étoile", "nuage", "pluie", "neige", "feu", "arbre", "fleur", "pierre",
        "chien", "chat", "cheval", "lapin", "animal",
        "famille", "école", "ville", "village", "marché", "église", "hôpital", "cuisine", "jardin", "pont",
        "rue", "porte", "fenêtre", "table", "chaise", "miroir", "horloge", "téléphone", "livre", "clé",
        "pain", "fromage", "lait", "œuf", "pomme", "orange", "café", "miel", "sucre",
        "hiver", "été", "nuit", "train", "voiture", "bateau", "avion", "médecin", "professeur",
    ]

    // Evocative but familiar — still daily-eligible.
    static let tier2 = [
        "château", "palais", "temple", "bibliothèque", "usine", "phare", "moulin", "fontaine", "port", "stade",
        "guitare", "piano", "violon", "tambour", "fusée", "télescope", "sous-marin", "hélicoptère", "caméra", "vélo",
        "tigre", "éléphant", "singe", "baleine", "dauphin", "aigle", "hibou", "serpent", "tortue", "grenouille",
        "araignée", "papillon", "automne", "printemps", "aube", "crépuscule", "horizon",
        "citron", "raisin", "carotte", "citrouille", "cerise", "salade", "gâteau", "glace",
        "volcan", "cascade", "grotte", "colline", "jungle", "arc-en-ciel", "trésor", "royaume", "soldat",
        "diamant", "cristal", "ballon", "chapeau", "chaussure", "parapluie",
    ]

    // Practice only — less common but still concrete.
    static let tier3 = [
        "boussole", "lanterne", "ancre", "bougie", "marteau", "échelle", "oreiller", "couverture", "serviette", "cuillère",
        "assiette", "cahier", "crayon", "bouteille", "panier", "gant", "veste", "beurre", "comète", "éclipse",
        "brise", "brouillard", "marée", "falaise", "récif", "lagune", "plateau", "prairie", "canyon", "glacier",
        "cathédrale", "forteresse", "monument", "manoir", "orchestre", "pyramide",
    ]

    // Practice only — tricky, technical, or niche by design.
    static let tier4 = [
        "entropie", "paradoxe", "syntaxe", "dialecte", "métaphore", "théorème", "équation", "algorithme", "molécule",
        "électron", "proton", "neurone", "plasma", "magma", "obsidienne", "granit", "marbre", "filament", "turbine",
        "piston", "pendule", "hélice", "polymère", "fossile", "nectar", "pollen", "cocon", "parchemin", "dague",
        "mosaïque", "tapisserie", "amulette", "relique", "vignoble", "sanctuaire",
    ]

    static let all: [WordBank.Entry] =
        tier1.map { WordBank.Entry(word: $0, tier: 1) } +
        tier2.map { WordBank.Entry(word: $0, tier: 2) } +
        tier3.map { WordBank.Entry(word: $0, tier: 3) } +
        tier4.map { WordBank.Entry(word: $0, tier: 4) }
}
