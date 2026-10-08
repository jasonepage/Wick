//
//  DailyWords.swift
//  Hunch
//
//  Secret words as multilingual translation SETS — the secret is the SAME
//  concept in every language, and switching language keeps the same word. The
//  daily draws from tiers 1-3 (a full year of unique words); practice adds tier 4.
//
//  Every side is frequency-vetted so each is virtually certain to exist in
//  Apple's word embeddings for its language.
//

import Foundation

struct DailyWord: Equatable {
    /// The same concept in every supported language, keyed by language code.
    /// English is the hub: every pair must include "en".
    let translations: [String: String]
    let tier: Int

    /// N-language initializer — the target shape as languages are added.
    init(translations: [String: String], tier: Int) {
        self.translations = translations
        self.tier = tier
    }

    /// Convenience initializers that keep the word table compact.
    init(en: String, es: String, tier: Int) {
        self.init(translations: ["en": en, "es": es], tier: tier)
    }

    init(en: String, es: String, fr: String, tier: Int) {
        self.init(translations: ["en": en, "es": es, "fr": fr], tier: tier)
    }

    init(en: String, es: String, fr: String, it: String, tier: Int) {
        self.init(translations: ["en": en, "es": es, "fr": fr, "it": it], tier: tier)
    }

    init(en: String, es: String, fr: String, it: String, de: String, tier: Int) {
        self.init(translations: ["en": en, "es": es, "fr": fr, "it": it, "de": de], tier: tier)
    }

    var en: String { translations["en"] ?? "" }

    /// This concept's word in `language`, falling back to English (the hub) if
    /// a translation is missing — never crashes on a partially-translated pair.
    func word(for language: GameLanguage) -> String {
        translations[language.rawValue] ?? en
    }
}

enum DailyWords {
    // This 396-row table of struct initializers is what makes a Release (-O)
    // build hang for minutes: the SIL optimizer folds every DailyWord(...) and its
    // dictionary. `@_optimize(none)` skips optimization for just this one builder
    // function — the rest of the app still builds at full -O. No runtime cost
    // (it runs once at launch). Without this, archiving stalls (e.g. task 37/57).
    static let all: [DailyWord] = _all()
    @_optimize(none) private static func _all() -> [DailyWord] { [
        DailyWord(en: "ocean", es: "océano", fr: "océan", it: "oceano", de: "ozean", tier: 1),
        DailyWord(en: "sea", es: "mar", fr: "mer", it: "mare", de: "meer", tier: 1),
        DailyWord(en: "river", es: "río", fr: "rivière", it: "fiume", de: "fluss", tier: 1),
        DailyWord(en: "lake", es: "lago", fr: "lac", it: "lago", de: "see", tier: 1),
        DailyWord(en: "mountain", es: "montaña", fr: "montagne", it: "montagna", de: "berg", tier: 1),
        DailyWord(en: "forest", es: "bosque", fr: "forêt", it: "foresta", de: "wald", tier: 1),
        DailyWord(en: "island", es: "isla", fr: "île", it: "isola", de: "insel", tier: 1),
        DailyWord(en: "beach", es: "playa", fr: "plage", it: "spiaggia", de: "strand", tier: 1),
        DailyWord(en: "sky", es: "cielo", fr: "ciel", it: "cielo", de: "himmel", tier: 1),
        DailyWord(en: "sun", es: "sol", fr: "soleil", it: "sole", de: "sonne", tier: 1),
        DailyWord(en: "moon", es: "luna", fr: "lune", it: "luna", de: "mond", tier: 1),
        DailyWord(en: "star", es: "estrella", fr: "étoile", it: "stella", de: "stern", tier: 1),
        DailyWord(en: "cloud", es: "nube", fr: "nuage", it: "nuvola", de: "wolke", tier: 1),
        DailyWord(en: "rain", es: "lluvia", fr: "pluie", it: "pioggia", de: "regen", tier: 1),
        DailyWord(en: "snow", es: "nieve", fr: "neige", it: "neve", de: "schnee", tier: 1),
        DailyWord(en: "wind", es: "viento", fr: "vent", it: "vento", de: "wind", tier: 1),
        DailyWord(en: "fire", es: "fuego", fr: "feu", it: "fuoco", de: "feuer", tier: 1),
        DailyWord(en: "ice", es: "hielo", fr: "glace", it: "ghiaccio", de: "eis", tier: 1),
        DailyWord(en: "tree", es: "árbol", fr: "arbre", it: "albero", de: "baum", tier: 1),
        DailyWord(en: "flower", es: "flor", fr: "fleur", it: "fiore", de: "blume", tier: 1),
        DailyWord(en: "grass", es: "hierba", fr: "herbe", it: "erba", de: "gras", tier: 1),
        DailyWord(en: "stone", es: "piedra", fr: "pierre", it: "pietra", de: "stein", tier: 1),
        DailyWord(en: "sand", es: "arena", fr: "sable", it: "sabbia", de: "sand", tier: 1),
        DailyWord(en: "dog", es: "perro", fr: "chien", it: "cane", de: "hund", tier: 1),
        DailyWord(en: "cat", es: "gato", fr: "chat", it: "gatto", de: "katze", tier: 1),
        DailyWord(en: "horse", es: "caballo", fr: "cheval", it: "cavallo", de: "pferd", tier: 1),
        DailyWord(en: "cow", es: "vaca", fr: "vache", it: "mucca", de: "kuh", tier: 1),
        DailyWord(en: "pig", es: "cerdo", fr: "cochon", it: "maiale", de: "schwein", tier: 1),
        DailyWord(en: "sheep", es: "oveja", fr: "mouton", it: "pecora", de: "schaf", tier: 1),
        DailyWord(en: "chicken", es: "pollo", fr: "poulet", it: "pollo", de: "huhn", tier: 1),
        DailyWord(en: "duck", es: "pato", fr: "canard", it: "anatra", de: "ente", tier: 1),
        DailyWord(en: "rabbit", es: "conejo", fr: "lapin", it: "coniglio", de: "kaninchen", tier: 1),
        DailyWord(en: "mouse", es: "ratón", fr: "souris", it: "topo", de: "maus", tier: 1),
        DailyWord(en: "lion", es: "león", fr: "lion", it: "leone", de: "löwe", tier: 1),
        DailyWord(en: "bear", es: "oso", fr: "ours", it: "orso", de: "bär", tier: 1),
        DailyWord(en: "wolf", es: "lobo", fr: "loup", it: "lupo", de: "wolf", tier: 1),
        DailyWord(en: "fox", es: "zorro", fr: "renard", it: "volpe", de: "fuchs", tier: 1),
        DailyWord(en: "bird", es: "pájaro", fr: "oiseau", it: "uccello", de: "vogel", tier: 1),
        DailyWord(en: "fish", es: "pez", fr: "poisson", it: "pesce", de: "fisch", tier: 1),
        DailyWord(en: "frog", es: "rana", fr: "grenouille", it: "rana", de: "frosch", tier: 1),
        DailyWord(en: "bee", es: "abeja", fr: "abeille", it: "ape", de: "biene", tier: 1),
        DailyWord(en: "ant", es: "hormiga", fr: "fourmi", it: "formica", de: "ameise", tier: 1),
        DailyWord(en: "fly", es: "mosca", fr: "mouche", it: "mosca", de: "fliege", tier: 1),
        DailyWord(en: "family", es: "familia", fr: "famille", it: "famiglia", de: "familie", tier: 1),
        DailyWord(en: "school", es: "escuela", fr: "école", it: "scuola", de: "schule", tier: 1),
        DailyWord(en: "city", es: "ciudad", fr: "ville", it: "città", de: "stadt", tier: 1),
        DailyWord(en: "town", es: "pueblo", fr: "village", it: "paese", de: "ort", tier: 1),
        DailyWord(en: "house", es: "casa", fr: "maison", it: "casa", de: "haus", tier: 1),
        DailyWord(en: "church", es: "iglesia", fr: "église", it: "chiesa", de: "kirche", tier: 1),
        DailyWord(en: "hospital", es: "hospital", fr: "hôpital", it: "ospedale", de: "krankenhaus", tier: 1),
        DailyWord(en: "kitchen", es: "cocina", fr: "cuisine", it: "cucina", de: "küche", tier: 1),
        DailyWord(en: "garden", es: "jardín", fr: "jardin", it: "giardino", de: "garten", tier: 1),
        DailyWord(en: "bridge", es: "puente", fr: "pont", it: "ponte", de: "brücke", tier: 1),
        DailyWord(en: "street", es: "calle", fr: "rue", it: "via", de: "straße", tier: 1),
        DailyWord(en: "road", es: "carretera", fr: "route", it: "strada", de: "weg", tier: 1),
        DailyWord(en: "door", es: "puerta", fr: "porte", it: "porta", de: "tür", tier: 1),
        DailyWord(en: "window", es: "ventana", fr: "fenêtre", it: "finestra", de: "fenster", tier: 1),
        DailyWord(en: "wall", es: "pared", fr: "mur", it: "muro", de: "wand", tier: 1),
        DailyWord(en: "floor", es: "suelo", fr: "sol", it: "pavimento", de: "boden", tier: 1),
        DailyWord(en: "roof", es: "techo", fr: "toit", it: "tetto", de: "dach", tier: 1),
        DailyWord(en: "table", es: "mesa", fr: "table", it: "tavolo", de: "tisch", tier: 1),
        DailyWord(en: "chair", es: "silla", fr: "chaise", it: "sedia", de: "stuhl", tier: 1),
        DailyWord(en: "bed", es: "cama", fr: "lit", it: "letto", de: "bett", tier: 1),
        DailyWord(en: "mirror", es: "espejo", fr: "miroir", it: "specchio", de: "spiegel", tier: 1),
        DailyWord(en: "clock", es: "reloj", fr: "horloge", it: "orologio", de: "uhr", tier: 1),
        DailyWord(en: "lamp", es: "lámpara", fr: "lampe", it: "lampada", de: "lampe", tier: 1),
        DailyWord(en: "key", es: "llave", fr: "clé", it: "chiave", de: "schlüssel", tier: 1),
        DailyWord(en: "box", es: "caja", fr: "boîte", it: "scatola", de: "kiste", tier: 1),
        DailyWord(en: "bottle", es: "botella", fr: "bouteille", it: "bottiglia", de: "flasche", tier: 1),
        DailyWord(en: "cup", es: "taza", fr: "tasse", it: "tazza", de: "tasse", tier: 1),
        DailyWord(en: "glass", es: "vaso", fr: "verre", it: "bicchiere", de: "glas", tier: 1),
        DailyWord(en: "plate", es: "plato", fr: "assiette", it: "piatto", de: "teller", tier: 1),
        DailyWord(en: "spoon", es: "cuchara", fr: "cuillère", it: "cucchiaio", de: "löffel", tier: 1),
        DailyWord(en: "knife", es: "cuchillo", fr: "couteau", it: "coltello", de: "messer", tier: 1),
        DailyWord(en: "book", es: "libro", fr: "livre", it: "libro", de: "buch", tier: 1),
        DailyWord(en: "pencil", es: "lápiz", fr: "crayon", it: "matita", de: "bleistift", tier: 1),
        DailyWord(en: "paper", es: "papel", fr: "papier", it: "carta", de: "papier", tier: 1),
        DailyWord(en: "bag", es: "bolsa", fr: "sac", it: "borsa", de: "tasche", tier: 1),
        DailyWord(en: "ball", es: "pelota", fr: "balle", it: "palla", de: "ball", tier: 1),
        DailyWord(en: "bread", es: "pan", fr: "pain", it: "pane", de: "brot", tier: 1),
        DailyWord(en: "cheese", es: "queso", fr: "fromage", it: "formaggio", de: "käse", tier: 1),
        DailyWord(en: "milk", es: "leche", fr: "lait", it: "latte", de: "milch", tier: 1),
        DailyWord(en: "egg", es: "huevo", fr: "œuf", it: "uovo", de: "ei", tier: 1),
        DailyWord(en: "meat", es: "carne", fr: "viande", it: "carne", de: "fleisch", tier: 1),
        DailyWord(en: "rice", es: "arroz", fr: "riz", it: "riso", de: "reis", tier: 1),
        DailyWord(en: "soup", es: "sopa", fr: "soupe", it: "zuppa", de: "suppe", tier: 1),
        DailyWord(en: "sugar", es: "azúcar", fr: "sucre", it: "zucchero", de: "zucker", tier: 1),
        DailyWord(en: "salt", es: "sal", fr: "sel", it: "sale", de: "salz", tier: 1),
        DailyWord(en: "honey", es: "miel", fr: "miel", it: "miele", de: "honig", tier: 1),
        DailyWord(en: "apple", es: "manzana", fr: "pomme", it: "mela", de: "apfel", tier: 1),
        DailyWord(en: "orange", es: "naranja", fr: "orange", it: "arancia", de: "orange", tier: 1),
        DailyWord(en: "banana", es: "plátano", fr: "banane", it: "banana", de: "banane", tier: 1),
        DailyWord(en: "lemon", es: "limón", fr: "citron", it: "limone", de: "zitrone", tier: 1),
        DailyWord(en: "coffee", es: "café", fr: "café", it: "caffè", de: "kaffee", tier: 1),
        DailyWord(en: "water", es: "agua", fr: "eau", it: "acqua", de: "wasser", tier: 1),
        DailyWord(en: "wine", es: "vino", fr: "vin", it: "vino", de: "wein", tier: 1),
        DailyWord(en: "cake", es: "pastel", fr: "gâteau", it: "torta", de: "kuchen", tier: 1),
        DailyWord(en: "head", es: "cabeza", fr: "tête", it: "testa", de: "kopf", tier: 1),
        DailyWord(en: "hair", es: "pelo", fr: "cheveux", it: "capelli", de: "haar", tier: 1),
        DailyWord(en: "face", es: "cara", fr: "visage", it: "viso", de: "gesicht", tier: 1),
        DailyWord(en: "eye", es: "ojo", fr: "œil", it: "occhio", de: "auge", tier: 1),
        DailyWord(en: "ear", es: "oreja", fr: "oreille", it: "orecchio", de: "ohr", tier: 1),
        DailyWord(en: "nose", es: "nariz", fr: "nez", it: "naso", de: "nase", tier: 1),
        DailyWord(en: "mouth", es: "boca", fr: "bouche", it: "bocca", de: "mund", tier: 1),
        DailyWord(en: "tooth", es: "diente", fr: "dent", it: "dente", de: "zahn", tier: 1),
        DailyWord(en: "neck", es: "cuello", fr: "cou", it: "collo", de: "hals", tier: 1),
        DailyWord(en: "arm", es: "brazo", fr: "bras", it: "braccio", de: "arm", tier: 1),
        DailyWord(en: "hand", es: "mano", fr: "main", it: "mano", de: "hand", tier: 1),
        DailyWord(en: "finger", es: "dedo", fr: "doigt", it: "dito", de: "finger", tier: 1),
        DailyWord(en: "leg", es: "pierna", fr: "jambe", it: "gamba", de: "bein", tier: 1),
        DailyWord(en: "foot", es: "pie", fr: "pied", it: "piede", de: "fuß", tier: 1),
        DailyWord(en: "heart", es: "corazón", fr: "cœur", it: "cuore", de: "herz", tier: 1),
        DailyWord(en: "bone", es: "hueso", fr: "os", it: "osso", de: "knochen", tier: 1),
        DailyWord(en: "skin", es: "piel", fr: "peau", it: "pelle", de: "haut", tier: 1),
        DailyWord(en: "blood", es: "sangre", fr: "sang", it: "sangue", de: "blut", tier: 1),
        DailyWord(en: "shirt", es: "camisa", fr: "chemise", it: "camicia", de: "hemd", tier: 1),
        DailyWord(en: "dress", es: "vestido", fr: "robe", it: "vestito", de: "kleid", tier: 1),
        DailyWord(en: "jacket", es: "chaqueta", fr: "veste", it: "giacca", de: "jacke", tier: 1),
        DailyWord(en: "hat", es: "sombrero", fr: "chapeau", it: "cappello", de: "hut", tier: 1),
        DailyWord(en: "shoe", es: "zapato", fr: "chaussure", it: "scarpa", de: "schuh", tier: 1),
        DailyWord(en: "car", es: "coche", fr: "voiture", it: "macchina", de: "auto", tier: 1),
        DailyWord(en: "bus", es: "autobús", fr: "bus", it: "autobus", de: "bus", tier: 1),
        DailyWord(en: "train", es: "tren", fr: "train", it: "treno", de: "zug", tier: 1),
        DailyWord(en: "boat", es: "barco", fr: "bateau", it: "barca", de: "boot", tier: 1),
        DailyWord(en: "airplane", es: "avión", fr: "avion", it: "aereo", de: "flugzeug", tier: 1),
        DailyWord(en: "winter", es: "invierno", fr: "hiver", it: "inverno", de: "winter", tier: 1),
        DailyWord(en: "summer", es: "verano", fr: "été", it: "estate", de: "sommer", tier: 1),
        DailyWord(en: "night", es: "noche", fr: "nuit", it: "notte", de: "nacht", tier: 1),
        DailyWord(en: "day", es: "día", fr: "jour", it: "giorno", de: "tag", tier: 1),
        DailyWord(en: "morning", es: "mañana", fr: "matin", it: "mattina", de: "morgen", tier: 1),
        DailyWord(en: "money", es: "dinero", fr: "argent", it: "denaro", de: "geld", tier: 1),
        DailyWord(en: "letter", es: "carta", fr: "lettre", it: "lettera", de: "brief", tier: 1),
        DailyWord(en: "word", es: "palabra", fr: "mot", it: "parola", de: "wort", tier: 1),
        DailyWord(en: "name", es: "nombre", fr: "nom", it: "nome", de: "name", tier: 1),
        DailyWord(en: "music", es: "música", fr: "musique", it: "musica", de: "musik", tier: 1),
        DailyWord(en: "desert", es: "desierto", fr: "désert", it: "deserto", de: "wüste", tier: 2),
        DailyWord(en: "valley", es: "valle", fr: "vallée", it: "valle", de: "tal", tier: 2),
        DailyWord(en: "hill", es: "colina", fr: "colline", it: "collina", de: "hügel", tier: 2),
        DailyWord(en: "jungle", es: "selva", fr: "jungle", it: "giungla", de: "dschungel", tier: 2),
        DailyWord(en: "cave", es: "cueva", fr: "grotte", it: "grotta", de: "höhle", tier: 2),
        DailyWord(en: "cliff", es: "acantilado", fr: "falaise", it: "rupe", de: "klippe", tier: 2),
        DailyWord(en: "waterfall", es: "cascada", fr: "cascade", it: "cascata", de: "wasserfall", tier: 2),
        DailyWord(en: "volcano", es: "volcán", fr: "volcan", it: "vulcano", de: "vulkan", tier: 2),
        DailyWord(en: "rainbow", es: "arcoíris", fr: "arc-en-ciel", it: "arcobaleno", de: "regenbogen", tier: 2),
        DailyWord(en: "storm", es: "tormenta", fr: "tempête", it: "tempesta", de: "sturm", tier: 2),
        DailyWord(en: "thunder", es: "trueno", fr: "tonnerre", it: "tuono", de: "donner", tier: 2),
        DailyWord(en: "lightning", es: "relámpago", fr: "éclair", it: "fulmine", de: "blitz", tier: 2),
        DailyWord(en: "fog", es: "niebla", fr: "brouillard", it: "nebbia", de: "nebel", tier: 2),
        DailyWord(en: "wave", es: "ola", fr: "vague", it: "onda", de: "welle", tier: 2),
        DailyWord(en: "root", es: "raíz", fr: "racine", it: "radice", de: "wurzel", tier: 2),
        DailyWord(en: "seed", es: "semilla", fr: "graine", it: "seme", de: "samen", tier: 2),
        DailyWord(en: "branch", es: "rama", fr: "branche", it: "ramo", de: "ast", tier: 2),
        DailyWord(en: "leaf", es: "hoja", fr: "feuille", it: "foglia", de: "blatt", tier: 2),
        DailyWord(en: "rock", es: "roca", fr: "rocher", it: "roccia", de: "fels", tier: 2),
        DailyWord(en: "gold", es: "oro", fr: "or", it: "oro", de: "gold", tier: 2),
        DailyWord(en: "silver", es: "plata", fr: "argent", it: "argento", de: "silber", tier: 2),
        DailyWord(en: "iron", es: "hierro", fr: "fer", it: "ferro", de: "eisen", tier: 2),
        DailyWord(en: "giraffe", es: "jirafa", fr: "girafe", it: "giraffa", de: "giraffe", tier: 2),
        DailyWord(en: "zebra", es: "cebra", fr: "zèbre", it: "zebra", de: "zebra", tier: 2),
        DailyWord(en: "deer", es: "ciervo", fr: "cerf", it: "cervo", de: "hirsch", tier: 2),
        DailyWord(en: "whale", es: "ballena", fr: "baleine", it: "balena", de: "wal", tier: 2),
        DailyWord(en: "dolphin", es: "delfín", fr: "dauphin", it: "delfino", de: "delfin", tier: 2),
        DailyWord(en: "shark", es: "tiburón", fr: "requin", it: "squalo", de: "hai", tier: 2),
        DailyWord(en: "eagle", es: "águila", fr: "aigle", it: "aquila", de: "adler", tier: 2),
        DailyWord(en: "owl", es: "búho", fr: "hibou", it: "gufo", de: "eule", tier: 2),
        DailyWord(en: "penguin", es: "pingüino", fr: "pingouin", it: "pinguino", de: "pinguin", tier: 2),
        DailyWord(en: "crab", es: "cangrejo", fr: "crabe", it: "granchio", de: "krabbe", tier: 2),
        DailyWord(en: "octopus", es: "pulpo", fr: "poulpe", it: "polpo", de: "krake", tier: 2),
        DailyWord(en: "butterfly", es: "mariposa", fr: "papillon", it: "farfalla", de: "schmetterling", tier: 2),
        DailyWord(en: "snail", es: "caracol", fr: "escargot", it: "lumaca", de: "schnecke", tier: 2),
        DailyWord(en: "squirrel", es: "ardilla", fr: "écureuil", it: "scoiattolo", de: "eichhörnchen", tier: 2),
        DailyWord(en: "bat", es: "murciélago", fr: "chauve-souris", it: "pipistrello", de: "fledermaus", tier: 2),
        DailyWord(en: "camel", es: "camello", fr: "chameau", it: "cammello", de: "kamel", tier: 2),
        DailyWord(en: "donkey", es: "burro", fr: "âne", it: "asino", de: "esel", tier: 2),
        DailyWord(en: "goat", es: "cabra", fr: "chèvre", it: "capra", de: "ziege", tier: 2),
        DailyWord(en: "parrot", es: "loro", fr: "perroquet", it: "pappagallo", de: "papagei", tier: 2),
        DailyWord(en: "snake", es: "serpiente", fr: "serpent", it: "serpente", de: "schlange", tier: 2),
        DailyWord(en: "turtle", es: "tortuga", fr: "tortue", it: "tartaruga", de: "schildkröte", tier: 2),
        DailyWord(en: "spider", es: "araña", fr: "araignée", it: "ragno", de: "spinne", tier: 2),
        DailyWord(en: "elephant", es: "elefante", fr: "éléphant", it: "elefante", de: "elefant", tier: 2),
        DailyWord(en: "tiger", es: "tigre", fr: "tigre", it: "tigre", de: "tiger", tier: 2),
        DailyWord(en: "monkey", es: "mono", fr: "singe", it: "scimmia", de: "affe", tier: 2),
        DailyWord(en: "pasta", es: "pasta", fr: "pâtes", it: "pasta", de: "nudeln", tier: 2),
        DailyWord(en: "tomato", es: "tomate", fr: "tomate", it: "pomodoro", de: "tomate", tier: 2),
        DailyWord(en: "potato", es: "patata", fr: "patate", it: "patata", de: "kartoffel", tier: 2),
        DailyWord(en: "carrot", es: "zanahoria", fr: "carotte", it: "carota", de: "karotte", tier: 2),
        DailyWord(en: "onion", es: "cebolla", fr: "oignon", it: "cipolla", de: "zwiebel", tier: 2),
        DailyWord(en: "garlic", es: "ajo", fr: "ail", it: "aglio", de: "knoblauch", tier: 2),
        DailyWord(en: "corn", es: "maíz", fr: "maïs", it: "mais", de: "mais", tier: 2),
        DailyWord(en: "lettuce", es: "lechuga", fr: "laitue", it: "lattuga", de: "kopfsalat", tier: 2),
        DailyWord(en: "cucumber", es: "pepino", fr: "concombre", it: "cetriolo", de: "gurke", tier: 2),
        DailyWord(en: "pumpkin", es: "calabaza", fr: "citrouille", it: "zucca", de: "kürbis", tier: 2),
        DailyWord(en: "strawberry", es: "fresa", fr: "fraise", it: "fragola", de: "erdbeere", tier: 2),
        DailyWord(en: "cherry", es: "cereza", fr: "cerise", it: "ciliegia", de: "kirsche", tier: 2),
        DailyWord(en: "grape", es: "uva", fr: "raisin", it: "uva", de: "traube", tier: 2),
        DailyWord(en: "pear", es: "pera", fr: "poire", it: "pera", de: "birne", tier: 2),
        DailyWord(en: "pineapple", es: "piña", fr: "ananas", it: "ananas", de: "ananas", tier: 2),
        DailyWord(en: "watermelon", es: "sandía", fr: "pastèque", it: "anguria", de: "wassermelone", tier: 2),
        DailyWord(en: "tea", es: "té", fr: "thé", it: "tè", de: "tee", tier: 2),
        DailyWord(en: "beer", es: "cerveza", fr: "bière", it: "birra", de: "bier", tier: 2),
        DailyWord(en: "juice", es: "jugo", fr: "jus", it: "succo", de: "saft", tier: 2),
        DailyWord(en: "oil", es: "aceite", fr: "huile", it: "olio", de: "öl", tier: 2),
        DailyWord(en: "flour", es: "harina", fr: "farine", it: "farina", de: "mehl", tier: 2),
        DailyWord(en: "cookie", es: "galleta", fr: "biscuit", it: "biscotto", de: "keks", tier: 2),
        DailyWord(en: "chocolate", es: "chocolate", fr: "chocolat", it: "cioccolato", de: "schokolade", tier: 2),
        DailyWord(en: "salad", es: "ensalada", fr: "salade", it: "insalata", de: "salat", tier: 2),
        DailyWord(en: "butter", es: "mantequilla", fr: "beurre", it: "burro", de: "butter", tier: 2),
        DailyWord(en: "bowl", es: "tazón", fr: "bol", it: "ciotola", de: "schüssel", tier: 2),
        DailyWord(en: "pot", es: "olla", fr: "casserole", it: "pentola", de: "topf", tier: 2),
        DailyWord(en: "candle", es: "vela", fr: "bougie", it: "candela", de: "kerze", tier: 2),
        DailyWord(en: "towel", es: "toalla", fr: "serviette", it: "asciugamano", de: "handtuch", tier: 2),
        DailyWord(en: "soap", es: "jabón", fr: "savon", it: "sapone", de: "seife", tier: 2),
        DailyWord(en: "brush", es: "cepillo", fr: "brosse", it: "spazzola", de: "bürste", tier: 2),
        DailyWord(en: "comb", es: "peine", fr: "peigne", it: "pettine", de: "kamm", tier: 2),
        DailyWord(en: "pillow", es: "almohada", fr: "oreiller", it: "cuscino", de: "kissen", tier: 2),
        DailyWord(en: "blanket", es: "manta", fr: "couverture", it: "coperta", de: "decke", tier: 2),
        DailyWord(en: "curtain", es: "cortina", fr: "rideau", it: "tenda", de: "vorhang", tier: 2),
        DailyWord(en: "carpet", es: "alfombra", fr: "tapis", it: "tappeto", de: "teppich", tier: 2),
        DailyWord(en: "basket", es: "cesta", fr: "panier", it: "cesto", de: "korb", tier: 2),
        DailyWord(en: "bucket", es: "cubo", fr: "seau", it: "secchio", de: "eimer", tier: 2),
        DailyWord(en: "broom", es: "escoba", fr: "balai", it: "scopa", de: "besen", tier: 2),
        DailyWord(en: "hammer", es: "martillo", fr: "marteau", it: "martello", de: "hammer", tier: 2),
        DailyWord(en: "nail", es: "clavo", fr: "clou", it: "chiodo", de: "nagel", tier: 2),
        DailyWord(en: "rope", es: "cuerda", fr: "corde", it: "corda", de: "seil", tier: 2),
        DailyWord(en: "chain", es: "cadena", fr: "chaîne", it: "catena", de: "kette", tier: 2),
        DailyWord(en: "needle", es: "aguja", fr: "aiguille", it: "ago", de: "nadel", tier: 2),
        DailyWord(en: "scissors", es: "tijeras", fr: "ciseaux", it: "forbici", de: "schere", tier: 2),
        DailyWord(en: "pen", es: "bolígrafo", fr: "stylo", it: "penna", de: "stift", tier: 2),
        DailyWord(en: "notebook", es: "cuaderno", fr: "cahier", it: "quaderno", de: "heft", tier: 2),
        DailyWord(en: "map", es: "mapa", fr: "carte", it: "mappa", de: "karte", tier: 2),
        DailyWord(en: "umbrella", es: "paraguas", fr: "parapluie", it: "ombrello", de: "regenschirm", tier: 2),
        DailyWord(en: "balloon", es: "globo", fr: "ballon", it: "palloncino", de: "luftballon", tier: 2),
        DailyWord(en: "toy", es: "juguete", fr: "jouet", it: "giocattolo", de: "spielzeug", tier: 2),
        DailyWord(en: "fork", es: "tenedor", fr: "fourchette", it: "forchetta", de: "gabel", tier: 2),
        DailyWord(en: "pants", es: "pantalón", fr: "pantalon", it: "pantaloni", de: "hose", tier: 2),
        DailyWord(en: "coat", es: "abrigo", fr: "manteau", it: "cappotto", de: "mantel", tier: 2),
        DailyWord(en: "skirt", es: "falda", fr: "jupe", it: "gonna", de: "rock", tier: 2),
        DailyWord(en: "sweater", es: "suéter", fr: "pull", it: "maglione", de: "pullover", tier: 2),
        DailyWord(en: "cap", es: "gorra", fr: "casquette", it: "berretto", de: "mütze", tier: 2),
        DailyWord(en: "boot", es: "bota", fr: "botte", it: "stivale", de: "stiefel", tier: 2),
        DailyWord(en: "scarf", es: "bufanda", fr: "écharpe", it: "sciarpa", de: "schal", tier: 2),
        DailyWord(en: "belt", es: "cinturón", fr: "ceinture", it: "cintura", de: "gürtel", tier: 2),
        DailyWord(en: "tie", es: "corbata", fr: "cravate", it: "cravatta", de: "krawatte", tier: 2),
        DailyWord(en: "ring", es: "anillo", fr: "bague", it: "anello", de: "ring", tier: 2),
        DailyWord(en: "crown", es: "corona", fr: "couronne", it: "corona", de: "krone", tier: 2),
        DailyWord(en: "sock", es: "calcetín", fr: "chaussette", it: "calzino", de: "socke", tier: 2),
        DailyWord(en: "glove", es: "guante", fr: "gant", it: "guanto", de: "handschuh", tier: 2),
        DailyWord(en: "tongue", es: "lengua", fr: "langue", it: "lingua", de: "zunge", tier: 2),
        DailyWord(en: "knee", es: "rodilla", fr: "genou", it: "ginocchio", de: "knie", tier: 2),
        DailyWord(en: "shoulder", es: "hombro", fr: "épaule", it: "spalla", de: "schulter", tier: 2),
        DailyWord(en: "truck", es: "camión", fr: "camion", it: "camion", de: "lastwagen", tier: 2),
        DailyWord(en: "bicycle", es: "bicicleta", fr: "vélo", it: "bicicletta", de: "fahrrad", tier: 2),
        DailyWord(en: "motorcycle", es: "motocicleta", fr: "moto", it: "moto", de: "motorrad", tier: 2),
        DailyWord(en: "helicopter", es: "helicóptero", fr: "hélicoptère", it: "elicottero", de: "hubschrauber", tier: 2),
        DailyWord(en: "rocket", es: "cohete", fr: "fusée", it: "razzo", de: "rakete", tier: 2),
        DailyWord(en: "submarine", es: "submarino", fr: "sous-marin", it: "sottomarino", de: "u-boot", tier: 2),
        DailyWord(en: "wheel", es: "rueda", fr: "roue", it: "ruota", de: "rad", tier: 2),
        DailyWord(en: "engine", es: "motor", fr: "moteur", it: "motore", de: "motor", tier: 2),
        DailyWord(en: "castle", es: "castillo", fr: "château", it: "castello", de: "schloss", tier: 2),
        DailyWord(en: "palace", es: "palacio", fr: "palais", it: "palazzo", de: "palast", tier: 2),
        DailyWord(en: "temple", es: "templo", fr: "temple", it: "tempio", de: "tempel", tier: 2),
        DailyWord(en: "tower", es: "torre", fr: "tour", it: "torre", de: "turm", tier: 2),
        DailyWord(en: "library", es: "biblioteca", fr: "bibliothèque", it: "biblioteca", de: "bibliothek", tier: 2),
        DailyWord(en: "museum", es: "museo", fr: "musée", it: "museo", de: "museum", tier: 2),
        DailyWord(en: "market", es: "mercado", fr: "marché", it: "mercato", de: "markt", tier: 2),
        DailyWord(en: "shop", es: "tienda", fr: "boutique", it: "negozio", de: "laden", tier: 2),
        DailyWord(en: "factory", es: "fábrica", fr: "usine", it: "fabbrica", de: "fabrik", tier: 2),
        DailyWord(en: "farm", es: "granja", fr: "ferme", it: "fattoria", de: "bauernhof", tier: 2),
        DailyWord(en: "park", es: "parque", fr: "parc", it: "parco", de: "park", tier: 2),
        DailyWord(en: "village", es: "aldea", fr: "hameau", it: "villaggio", de: "dorf", tier: 2),
        DailyWord(en: "bedroom", es: "dormitorio", fr: "chambre", it: "camera", de: "schlafzimmer", tier: 2),
        DailyWord(en: "lighthouse", es: "faro", fr: "phare", it: "faro", de: "leuchtturm", tier: 2),
        DailyWord(en: "stadium", es: "estadio", fr: "stade", it: "stadio", de: "stadion", tier: 2),
        DailyWord(en: "windmill", es: "molino", fr: "moulin", it: "mulino", de: "windmühle", tier: 2),
        DailyWord(en: "fountain", es: "fuente", fr: "fontaine", it: "fontana", de: "brunnen", tier: 2),
        DailyWord(en: "port", es: "puerto", fr: "port", it: "porto", de: "hafen", tier: 2),
        DailyWord(en: "planet", es: "planeta", fr: "planète", it: "pianeta", de: "planet", tier: 2),
        DailyWord(en: "guitar", es: "guitarra", fr: "guitare", it: "chitarra", de: "gitarre", tier: 2),
        DailyWord(en: "piano", es: "piano", fr: "piano", it: "pianoforte", de: "klavier", tier: 2),
        DailyWord(en: "violin", es: "violín", fr: "violon", it: "violino", de: "geige", tier: 2),
        DailyWord(en: "drum", es: "tambor", fr: "tambour", it: "tamburo", de: "trommel", tier: 2),
        DailyWord(en: "flute", es: "flauta", fr: "flûte", it: "flauto", de: "flöte", tier: 2),
        DailyWord(en: "trumpet", es: "trompeta", fr: "trompette", it: "tromba", de: "trompete", tier: 2),
        DailyWord(en: "bell", es: "campana", fr: "cloche", it: "campana", de: "glocke", tier: 2),
        DailyWord(en: "autumn", es: "otoño", fr: "automne", it: "autunno", de: "herbst", tier: 2),
        DailyWord(en: "spring", es: "primavera", fr: "printemps", it: "primavera", de: "frühling", tier: 2),
        DailyWord(en: "dawn", es: "amanecer", fr: "aube", it: "alba", de: "morgengrauen", tier: 2),
        DailyWord(en: "sunset", es: "atardecer", fr: "crépuscule", it: "tramonto", de: "sonnenuntergang", tier: 2),
        DailyWord(en: "horizon", es: "horizonte", fr: "horizon", it: "orizzonte", de: "horizont", tier: 2),
        DailyWord(en: "crystal", es: "cristal", fr: "cristal", it: "cristallo", de: "kristall", tier: 2),
        DailyWord(en: "diamond", es: "diamante", fr: "diamant", it: "diamante", de: "diamant", tier: 2),
        DailyWord(en: "treasure", es: "tesoro", fr: "trésor", it: "tesoro", de: "schatz", tier: 2),
        DailyWord(en: "kingdom", es: "reino", fr: "royaume", it: "regno", de: "königreich", tier: 2),
        DailyWord(en: "soldier", es: "soldado", fr: "soldat", it: "soldato", de: "soldat", tier: 2),
        DailyWord(en: "king", es: "rey", fr: "roi", it: "re", de: "könig", tier: 2),
        DailyWord(en: "queen", es: "reina", fr: "reine", it: "regina", de: "königin", tier: 2),
        DailyWord(en: "angel", es: "ángel", fr: "ange", it: "angelo", de: "engel", tier: 2),
        DailyWord(en: "ghost", es: "fantasma", fr: "fantôme", it: "fantasma", de: "geist", tier: 2),
        DailyWord(en: "dragon", es: "dragón", fr: "dragon", it: "drago", de: "drache", tier: 2),
        DailyWord(en: "giant", es: "gigante", fr: "géant", it: "gigante", de: "riese", tier: 2),
        DailyWord(en: "mango", es: "mango", fr: "mangue", it: "mango", de: "mango", tier: 2),
        DailyWord(en: "bean", es: "frijol", fr: "haricot", it: "fagiolo", de: "bohne", tier: 2),
        DailyWord(en: "coconut", es: "coco", fr: "coco", it: "cocco", de: "kokosnuss", tier: 2),
        DailyWord(en: "olive", es: "aceituna", fr: "olive", it: "oliva", de: "olive", tier: 2),
        DailyWord(en: "swamp", es: "pantano", fr: "marais", it: "palude", de: "sumpf", tier: 3),
        DailyWord(en: "meadow", es: "pradera", fr: "prairie", it: "prato", de: "wiese", tier: 3),
        DailyWord(en: "reef", es: "arrecife", fr: "récif", it: "scogliera", de: "riff", tier: 3),
        DailyWord(en: "lagoon", es: "laguna", fr: "lagune", it: "laguna", de: "lagune", tier: 3),
        DailyWord(en: "dune", es: "duna", fr: "dune", it: "duna", de: "düne", tier: 3),
        DailyWord(en: "marble", es: "mármol", fr: "marbre", it: "marmo", de: "marmor", tier: 3),
        DailyWord(en: "granite", es: "granito", fr: "granit", it: "granito", de: "granit", tier: 3),
        DailyWord(en: "copper", es: "cobre", fr: "cuivre", it: "rame", de: "kupfer", tier: 3),
        DailyWord(en: "bronze", es: "bronce", fr: "bronze", it: "bronzo", de: "bronze", tier: 3),
        DailyWord(en: "clay", es: "arcilla", fr: "argile", it: "argilla", de: "ton", tier: 3),
        DailyWord(en: "ash", es: "ceniza", fr: "cendre", it: "cenere", de: "asche", tier: 3),
        DailyWord(en: "frost", es: "escarcha", fr: "givre", it: "brina", de: "frost", tier: 3),
        DailyWord(en: "glacier", es: "glaciar", fr: "glacier", it: "ghiacciaio", de: "gletscher", tier: 3),
        DailyWord(en: "canyon", es: "cañón", fr: "canyon", it: "canyon", de: "schlucht", tier: 3),
        DailyWord(en: "crocodile", es: "cocodrilo", fr: "crocodile", it: "coccodrillo", de: "krokodil", tier: 3),
        DailyWord(en: "kangaroo", es: "canguro", fr: "kangourou", it: "canguro", de: "känguru", tier: 3),
        DailyWord(en: "hawk", es: "halcón", fr: "faucon", it: "falco", de: "falke", tier: 3),
        DailyWord(en: "ostrich", es: "avestruz", fr: "autruche", it: "struzzo", de: "strauß", tier: 3),
        DailyWord(en: "lizard", es: "lagarto", fr: "lézard", it: "lucertola", de: "eidechse", tier: 3),
        DailyWord(en: "worm", es: "gusano", fr: "ver", it: "verme", de: "wurm", tier: 3),
        DailyWord(en: "seal", es: "foca", fr: "phoque", it: "foca", de: "robbe", tier: 3),
        DailyWord(en: "dove", es: "paloma", fr: "colombe", it: "colomba", de: "taube", tier: 3),
        DailyWord(en: "rat", es: "rata", fr: "rat", it: "ratto", de: "ratte", tier: 3),
        DailyWord(en: "anchor", es: "ancla", fr: "ancre", it: "ancora", de: "anker", tier: 3),
        DailyWord(en: "lantern", es: "linterna", fr: "lanterne", it: "lanterna", de: "laterne", tier: 3),
        DailyWord(en: "compass", es: "brújula", fr: "boussole", it: "bussola", de: "kompass", tier: 3),
        DailyWord(en: "telescope", es: "telescopio", fr: "télescope", it: "telescopio", de: "teleskop", tier: 3),
        DailyWord(en: "magnet", es: "imán", fr: "aimant", it: "magnete", de: "magnet", tier: 3),
        DailyWord(en: "screw", es: "tornillo", fr: "vis", it: "vite", de: "schraube", tier: 3),
        DailyWord(en: "saw", es: "sierra", fr: "scie", it: "sega", de: "säge", tier: 3),
        DailyWord(en: "ladder", es: "escalera", fr: "échelle", it: "scala", de: "leiter", tier: 3),
        DailyWord(en: "shovel", es: "pala", fr: "pelle", it: "pala", de: "schaufel", tier: 3),
        DailyWord(en: "axe", es: "hacha", fr: "hache", it: "ascia", de: "axt", tier: 3),
        DailyWord(en: "thread", es: "hilo", fr: "fil", it: "filo", de: "faden", tier: 3),
        DailyWord(en: "ribbon", es: "cinta", fr: "ruban", it: "nastro", de: "band", tier: 3),
        DailyWord(en: "vase", es: "jarrón", fr: "vase", it: "vaso", de: "vase", tier: 3),
        DailyWord(en: "cathedral", es: "catedral", fr: "cathédrale", it: "cattedrale", de: "kathedrale", tier: 3),
        DailyWord(en: "fortress", es: "fortaleza", fr: "forteresse", it: "fortezza", de: "festung", tier: 3),
        DailyWord(en: "monument", es: "monumento", fr: "monument", it: "monumento", de: "denkmal", tier: 3),
        DailyWord(en: "mansion", es: "mansión", fr: "manoir", it: "villa", de: "villa", tier: 3),
        DailyWord(en: "cottage", es: "cabaña", fr: "chalet", it: "baita", de: "hütte", tier: 3),
        DailyWord(en: "barn", es: "granero", fr: "grange", it: "fienile", de: "scheune", tier: 3),
        DailyWord(en: "pyramid", es: "pirámide", fr: "pyramide", it: "piramide", de: "pyramide", tier: 3),
        DailyWord(en: "comet", es: "cometa", fr: "comète", it: "cometa", de: "komet", tier: 3),
        DailyWord(en: "meteor", es: "meteoro", fr: "météore", it: "meteora", de: "meteor", tier: 3),
        DailyWord(en: "galaxy", es: "galaxia", fr: "galaxie", it: "galassia", de: "galaxie", tier: 3),
        DailyWord(en: "satellite", es: "satélite", fr: "satellite", it: "satellite", de: "satellit", tier: 3),
        DailyWord(en: "eclipse", es: "eclipse", fr: "éclipse", it: "eclissi", de: "finsternis", tier: 3),
        DailyWord(en: "plum", es: "ciruela", fr: "prune", it: "prugna", de: "pflaume", tier: 3),
        DailyWord(en: "walnut", es: "nuez", fr: "noix", it: "noce", de: "walnuss", tier: 3),
        DailyWord(en: "almond", es: "almendra", fr: "amande", it: "mandorla", de: "mandel", tier: 3),
        DailyWord(en: "ginger", es: "jengibre", fr: "gingembre", it: "zenzero", de: "ingwer", tier: 3),
        DailyWord(en: "cinnamon", es: "canela", fr: "cannelle", it: "cannella", de: "zimt", tier: 3),
        DailyWord(en: "harp", es: "arpa", fr: "harpe", it: "arpa", de: "harfe", tier: 3),
        DailyWord(en: "elbow", es: "codo", fr: "coude", it: "gomito", de: "ellbogen", tier: 3),
        DailyWord(en: "electron", es: "electrón", fr: "électron", it: "elettrone", de: "elektron", tier: 4),
        DailyWord(en: "neuron", es: "neurona", fr: "neurone", it: "neurone", de: "neuron", tier: 4),
        DailyWord(en: "plasma", es: "plasma", fr: "plasma", it: "plasma", de: "plasma", tier: 4),
        DailyWord(en: "magma", es: "magma", fr: "magma", it: "magma", de: "magma", tier: 4),
        DailyWord(en: "piston", es: "pistón", fr: "piston", it: "pistone", de: "kolben", tier: 4),
        DailyWord(en: "algorithm", es: "algoritmo", fr: "algorithme", it: "algoritmo", de: "algorithmus", tier: 4),
        DailyWord(en: "equation", es: "ecuación", fr: "équation", it: "equazione", de: "gleichung", tier: 4),
        DailyWord(en: "theorem", es: "teorema", fr: "théorème", it: "teorema", de: "theorem", tier: 4),
        DailyWord(en: "fossil", es: "fósil", fr: "fossile", it: "fossile", de: "fossil", tier: 4),
        DailyWord(en: "nectar", es: "néctar", fr: "nectar", it: "nettare", de: "nektar", tier: 4),
        DailyWord(en: "pollen", es: "polen", fr: "pollen", it: "polline", de: "pollen", tier: 4),
        DailyWord(en: "cocoon", es: "capullo", fr: "cocon", it: "bozzolo", de: "kokon", tier: 4),
        DailyWord(en: "dagger", es: "daga", fr: "dague", it: "pugnale", de: "dolch", tier: 4),
        DailyWord(en: "amulet", es: "amuleto", fr: "amulette", it: "amuleto", de: "amulett", tier: 4),
        DailyWord(en: "vineyard", es: "viñedo", fr: "vignoble", it: "vigneto", de: "weinberg", tier: 4),
        DailyWord(en: "sanctuary", es: "santuario", fr: "sanctuaire", it: "santuario", de: "heiligtum", tier: 4),
        DailyWord(en: "nucleus", es: "núcleo", fr: "noyau", it: "nucleo", de: "kern", tier: 4),
        DailyWord(en: "prism", es: "prisma", fr: "prisme", it: "prisma", de: "prisma", tier: 4),
        DailyWord(en: "spectrum", es: "espectro", fr: "spectre", it: "spettro", de: "spektrum", tier: 4),
        DailyWord(en: "circuit", es: "circuito", fr: "circuit", it: "circuito", de: "schaltkreis", tier: 4),
    ] }

    /// Daily-eligible pairs (tiers 1-3) — concrete and fair for everyone.
    static let dailyPool: [DailyWord] = all.filter { $0.tier <= 3 }

    /// The shared daily pair for `day` — identical across devices and languages.
    static func daily(for day: Int) -> DailyWord {
        guard !dailyPool.isEmpty else { return DailyWord(en: "ocean", es: "océano", fr: "océan", it: "oceano", de: "ozean", tier: 1) }
        return dailyPool[WordBank.dailyIndex(for: day, count: dailyPool.count)]
    }

    /// A random practice pair up to `maxTier`.
    static func randomPractice(maxTier: Int) -> DailyWord {
        randomPracticeIndexed(maxTier: maxTier).word
    }

    /// Practice, plus WHERE in `all` the word came from. Ghost Race links carry
    /// that index rather than the word itself, so a practice round can be raced
    /// without the URL revealing the answer.
    static func randomPracticeIndexed(maxTier: Int) -> (word: DailyWord, index: Int) {
        let candidates = all.indices.filter { all[$0].tier <= maxTier }
        guard let i = candidates.randomElement() else {
            return (DailyWord(en: "ocean", es: "océano", fr: "océan", it: "oceano", de: "ozean", tier: 1), 0)
        }
        return (all[i], i)
    }

    /// The English form of `word` given that it's KNOWN to be in `language` —
    /// an exact same-language lookup, immune to cross-language homographs
    /// ("rock" is a skirt in German but a stone in English; a German round
    /// must resolve it via the German side of the pair). nil if unknown.
    static func english(of word: String, in language: GameLanguage) -> String? {
        translate(word, from: language, to: .english)
    }

    /// Exact translation when the word's language is KNOWN — the word must
    /// match `source`'s side of a pair. Use this whenever the source language
    /// is certain (Learn mode, the round's secret): it can never be misled by
    /// a homograph in some other language ("boot" is English footwear AND
    /// German for boat — Learn mode must translate the one you actually played).
    static func translate(_ word: String, from source: GameLanguage, to target: GameLanguage) -> String? {
        let w = word.lowercased()
        for pair in all where pair.translations[source.rawValue] == w {
            return pair.translations[target.rawValue]
        }
        return nil
    }

    /// If `word` is ANY supported language's form of a known pair, return its
    /// form in `language` — so a guess typed in another language ("cat" during
    /// a Spanish game) can be translated to "gato" and scored. nil when we have
    /// no translation, or when the word is already in `language`.
    ///
    /// Source language is UNKNOWN here, so English (the hub) wins homograph
    /// ties: a stray foreign guess is most often English, and "boot" typed in
    /// a Spanish round should mean footwear (EN), not a boat (DE).
    static func translate(_ word: String, to language: GameLanguage) -> String? {
        let w = word.lowercased()
        let target = language.rawValue
        if target != "en", let viaEnglish = translate(w, from: .english, to: language) {
            return viaEnglish
        }
        for pair in all {
            for (code, form) in pair.translations where code != target && code != "en" && form == w {
                return pair.translations[target]
            }
        }
        return nil
    }
}
