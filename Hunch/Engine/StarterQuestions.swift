//
//  StarterQuestions.swift
//  Hunch
//
//  A bank of broad, word-independent yes/no questions used to scaffold the
//  start of a round. At round start we surface ~10 of them as tappable chips
//  so new players aren't staring at a blank prompt and learn that the Keeper
//  can be interrogated.
//
//  Each item has a SHORT chip label (shown on the pill, e.g. "Wearable?") and
//  the FULL question (sent to the Keeper, e.g. "Can you wear it?"). The short
//  label keeps the UI clean — no mid-word truncation.
//
//  LEAK SAFETY — important:
//  The daily selection is seeded ONLY by the day index, never by the secret
//  word. If we chose questions based on the answer (e.g. only showing
//  "Is it an animal?" when the word is an animal), the *selection itself* would
//  leak information before the player taps anything. By seeding off the date,
//  every player sees the same set for a given day, and the set reveals nothing.
//
//  COVERAGE — the bank is grouped into orthogonal categories (animacy, size,
//  location, function, …). The daily picker takes ONE question from each of N
//  distinct categories, so the 10 starters always partition the space of words
//  rather than clustering on one axis.
//

import Foundation

enum StarterQuestions {

    /// A single starter: a short pill label, the full question text, and the
    /// property it asks about (used to answer deterministically from tags).
    struct Item: Hashable {
        let chip: String           // shown on the pill
        let full: String           // sent to the Keeper
        let key: StarterProperty   // property for deterministic answering
    }

    /// One axis of inquiry. Picking across distinct categories keeps the daily
    /// set orthogonal (high information), not redundant.
    struct Category {
        let name: String
        let items: [Item]
    }

    /// The bank. Every question must be answerable as yes / no / sort-of for ANY
    /// secret word (concrete or abstract), and free of leak triggers (no "clue",
    /// "hint", "letter", "spell", "rhyme", "define", "synonym").
    static let categories: [Category] = [
        Category(name: "concreteness", items: [
            Item(chip: "Physical?", full: "Is it a physical object you can touch?", key: .physical),
            Item(chip: "Abstract?", full: "Is it an abstract idea?", key: .abstractIdea),
            Item(chip: "Emotion?", full: "Is it an emotion or feeling?", key: .emotion),
            Item(chip: "An action?", full: "Is it something you do?", key: .action),
        ]),
        Category(name: "animacy", items: [
            Item(chip: "Alive?", full: "Is it alive?", key: .alive),
            Item(chip: "Ever alive?", full: "Was it ever alive?", key: .everAlive),
            Item(chip: "An animal?", full: "Is it an animal?", key: .animal),
            Item(chip: "A plant?", full: "Is it a plant?", key: .plant),
        ]),
        Category(name: "origin", items: [
            Item(chip: "Man-made?", full: "Is it man-made?", key: .manMade),
            Item(chip: "Natural?", full: "Does it occur naturally?", key: .natural),
        ]),
        Category(name: "size", items: [
            Item(chip: "Bigger than a car?", full: "Is it bigger than a car?", key: .biggerThanCar),
            Item(chip: "Fits in a hand?", full: "Could it fit in your hand?", key: .fitsInHand),
            Item(chip: "Smaller than a shoe?", full: "Is it smaller than a shoe?", key: .smallerThanShoe),
        ]),
        Category(name: "location", items: [
            Item(chip: "Indoors?", full: "Is it usually found indoors?", key: .indoors),
            Item(chip: "Outdoors?", full: "Is it found outdoors in nature?", key: .outdoors),
            Item(chip: "In a kitchen?", full: "Would you find it in a kitchen?", key: .inKitchen),
            Item(chip: "Near water?", full: "Is it found in or near water?", key: .nearWater),
        ]),
        Category(name: "function", items: [
            Item(chip: "A tool?", full: "Is it a tool or device?", key: .tool),
            Item(chip: "Transport?", full: "Is it used for transportation?", key: .transport),
            Item(chip: "Communication?", full: "Is it used for communication?", key: .communication),
            Item(chip: "Entertainment?", full: "Is it used for entertainment?", key: .entertainment),
        ]),
        Category(name: "interaction", items: [
            Item(chip: "Edible?", full: "Can you eat or drink it?", key: .edible),
            Item(chip: "Wearable?", full: "Can you wear it?", key: .wearable),
            Item(chip: "Can hold it?", full: "Can you hold it in your hands?", key: .canHold),
        ]),
        Category(name: "material", items: [
            Item(chip: "Metal?", full: "Is it typically made of metal?", key: .metal),
            Item(chip: "Wood?", full: "Is it usually made of wood?", key: .wood),
            Item(chip: "Soft?", full: "Is it soft to the touch?", key: .soft),
        ]),
        Category(name: "sensory", items: [
            Item(chip: "Makes a sound?", full: "Does it make a sound?", key: .makesSound),
            Item(chip: "Has a smell?", full: "Does it have a noticeable smell?", key: .hasSmell),
            Item(chip: "A color?", full: "Is it usually a specific color?", key: .color),
            Item(chip: "Gives light?", full: "Does it give off light?", key: .givesLight),
        ]),
        Category(name: "motion", items: [
            Item(chip: "Moves itself?", full: "Can it move on its own?", key: .movesItself),
            Item(chip: "Moving parts?", full: "Does it have moving parts?", key: .movingParts),
        ]),
        Category(name: "state", items: [
            Item(chip: "Liquid?", full: "Is it a liquid?", key: .liquid),
            Item(chip: "Hot?", full: "Is it usually hot?", key: .hot),
            Item(chip: "Cold?", full: "Is it usually cold?", key: .cold),
            Item(chip: "Food?", full: "Is it a kind of food?", key: .food),
        ]),
        Category(name: "domain", items: [
            Item(chip: "Tech?", full: "Is it related to technology?", key: .tech),
            Item(chip: "A job?", full: "Is it related to a job or profession?", key: .job),
            Item(chip: "A season?", full: "Is it associated with a particular season?", key: .season),
        ]),
        Category(name: "era", items: [
            Item(chip: "Centuries old?", full: "Has it existed for hundreds of years?", key: .centuriesOld),
            Item(chip: "Modern?", full: "Is it a modern invention?", key: .modern),
        ]),
        Category(name: "kind", items: [
            Item(chip: "A place?", full: "Is it a place?", key: .place),
            Item(chip: "Body part?", full: "Is it a part of the body?", key: .bodyPart),
            Item(chip: "In nature?", full: "Is it something found in nature?", key: .inNature),
        ]),
    ]

    /// Returns `count` starter items for the given day, deterministic across
    /// devices and players (same input → same output). Picks from distinct
    /// categories first to maximize coverage.
    ///
    /// - Parameters:
    ///   - count: how many chips to surface (default 10).
    ///   - dayIndex: the shared daily seed (`WordBank.dayIndex()`), NOT the word.
    static func daily(count: Int = 10, dayIndex: Int) -> [Item] {
        // Seed a small, portable PRNG so the result is identical on every
        // device for a given day (Swift's SystemRandomNumberGenerator is not).
        var rng = SplitMix64(seed: UInt64(bitPattern: Int64(dayIndex)) &* 0x9E3779B97F4A7C15)

        let shuffledCategories = categories.shuffled(using: &rng)
        var picked: [Item] = []
        var pass = 0
        while picked.count < count && pass < 4 {
            for category in shuffledCategories where picked.count < count {
                let item = category.items.randomElement(using: &rng) ?? category.items[0]
                if !picked.contains(item) { picked.append(item) }
            }
            pass += 1
        }
        return picked
    }

    /// Per-language question texts keyed by property. English lives on the
    /// `Item` itself; anything unmapped falls back to the English `full`, so a
    /// partially-translated language degrades gracefully. Adding a language =
    /// adding one table.
    private static let localized: [GameLanguage: [StarterProperty: String]] = [
        .spanish: [
            .physical:        "¿Es un objeto físico que puedes tocar?",
            .abstractIdea:    "¿Es una idea abstracta?",
            .emotion:         "¿Es una emoción o un sentimiento?",
            .action:          "¿Es algo que haces?",
            .alive:           "¿Está vivo?",
            .everAlive:       "¿Alguna vez estuvo vivo?",
            .animal:          "¿Es un animal?",
            .plant:           "¿Es una planta?",
            .manMade:         "¿Está hecho por el hombre?",
            .natural:         "¿Se da de forma natural?",
            .biggerThanCar:   "¿Es más grande que un coche?",
            .fitsInHand:      "¿Cabe en tu mano?",
            .smallerThanShoe: "¿Es más pequeño que un zapato?",
            .indoors:         "¿Suele encontrarse en interiores?",
            .outdoors:        "¿Se encuentra al aire libre, en la naturaleza?",
            .inKitchen:       "¿Lo encontrarías en una cocina?",
            .nearWater:       "¿Se encuentra en el agua o cerca de ella?",
            .tool:            "¿Es una herramienta o un dispositivo?",
            .transport:       "¿Se usa para transportarse?",
            .communication:   "¿Se usa para comunicarse?",
            .entertainment:   "¿Se usa para el entretenimiento?",
            .edible:          "¿Se puede comer o beber?",
            .wearable:        "¿Se puede llevar puesto?",
            .canHold:         "¿Puedes sostenerlo en las manos?",
            .metal:           "¿Suele estar hecho de metal?",
            .wood:            "¿Suele estar hecho de madera?",
            .soft:            "¿Es suave al tacto?",
            .makesSound:      "¿Hace algún sonido?",
            .hasSmell:        "¿Tiene un olor perceptible?",
            .color:           "¿Suele tener un color específico?",
            .givesLight:      "¿Emite luz?",
            .movesItself:     "¿Puede moverse por sí solo?",
            .movingParts:     "¿Tiene piezas móviles?",
            .liquid:          "¿Es un líquido?",
            .hot:             "¿Suele estar caliente?",
            .cold:            "¿Suele estar frío?",
            .food:            "¿Es un tipo de comida?",
            .tech:            "¿Está relacionado con la tecnología?",
            .job:             "¿Está relacionado con un trabajo o profesión?",
            .season:          "¿Se asocia con una estación del año?",
            .centuriesOld:    "¿Ha existido durante cientos de años?",
            .modern:          "¿Es un invento moderno?",
            .place:           "¿Es un lugar?",
            .bodyPart:        "¿Es una parte del cuerpo?",
            .inNature:        "¿Es algo que se encuentra en la naturaleza?",
        ],
        .french: [
            .physical:        "Est-ce un objet physique que tu peux toucher ?",
            .abstractIdea:    "Est-ce une idée abstraite ?",
            .emotion:         "Est-ce une émotion ou un sentiment ?",
            .action:          "Est-ce quelque chose que l'on fait ?",
            .alive:           "Est-ce vivant ?",
            .everAlive:       "Est-ce que ça a déjà été vivant ?",
            .animal:          "Est-ce un animal ?",
            .plant:           "Est-ce une plante ?",
            .manMade:         "Est-ce fabriqué par l'homme ?",
            .natural:         "Est-ce que ça existe à l'état naturel ?",
            .biggerThanCar:   "Est-ce plus grand qu'une voiture ?",
            .fitsInHand:      "Est-ce que ça tient dans la main ?",
            .smallerThanShoe: "Est-ce plus petit qu'une chaussure ?",
            .indoors:         "Est-ce qu'on le trouve plutôt à l'intérieur ?",
            .outdoors:        "Est-ce qu'on le trouve dehors, dans la nature ?",
            .inKitchen:       "Est-ce qu'on le trouverait dans une cuisine ?",
            .nearWater:       "Est-ce qu'on le trouve dans l'eau ou près de l'eau ?",
            .tool:            "Est-ce un outil ou un appareil ?",
            .transport:       "Est-ce que ça sert à se déplacer ?",
            .communication:   "Est-ce que ça sert à communiquer ?",
            .entertainment:   "Est-ce que ça sert au divertissement ?",
            .edible:          "Est-ce que ça se mange ou se boit ?",
            .wearable:        "Est-ce que ça se porte ?",
            .canHold:         "Peut-on le tenir dans les mains ?",
            .metal:           "Est-ce généralement en métal ?",
            .wood:            "Est-ce généralement en bois ?",
            .soft:            "Est-ce doux au toucher ?",
            .makesSound:      "Est-ce que ça fait du bruit ?",
            .hasSmell:        "Est-ce que ça a une odeur particulière ?",
            .color:           "Est-ce généralement d'une couleur précise ?",
            .givesLight:      "Est-ce que ça émet de la lumière ?",
            .movesItself:     "Est-ce que ça peut bouger tout seul ?",
            .movingParts:     "Est-ce que ça a des pièces mobiles ?",
            .liquid:          "Est-ce un liquide ?",
            .hot:             "Est-ce généralement chaud ?",
            .cold:            "Est-ce généralement froid ?",
            .food:            "Est-ce un aliment ?",
            .tech:            "Est-ce lié à la technologie ?",
            .job:             "Est-ce lié à un métier ou une profession ?",
            .season:          "Est-ce associé à une saison ?",
            .centuriesOld:    "Est-ce que ça existe depuis des siècles ?",
            .modern:          "Est-ce une invention moderne ?",
            .place:           "Est-ce un lieu ?",
            .bodyPart:        "Est-ce une partie du corps ?",
            .inNature:        "Est-ce quelque chose qu'on trouve dans la nature ?",
        ],
        .italian: [
            .physical:        "È un oggetto fisico che puoi toccare?",
            .abstractIdea:    "È un'idea astratta?",
            .emotion:         "È un'emozione o un sentimento?",
            .action:          "È qualcosa che si fa?",
            .alive:           "È vivo?",
            .everAlive:       "È mai stato vivo?",
            .animal:          "È un animale?",
            .plant:           "È una pianta?",
            .manMade:         "È fatto dall'uomo?",
            .natural:         "Esiste in natura?",
            .biggerThanCar:   "È più grande di una macchina?",
            .fitsInHand:      "Sta in una mano?",
            .smallerThanShoe: "È più piccolo di una scarpa?",
            .indoors:         "Si trova di solito al chiuso?",
            .outdoors:        "Si trova all'aperto, in natura?",
            .inKitchen:       "Lo troveresti in una cucina?",
            .nearWater:       "Si trova nell'acqua o vicino all'acqua?",
            .tool:            "È un attrezzo o un dispositivo?",
            .transport:       "Serve per spostarsi?",
            .communication:   "Serve per comunicare?",
            .entertainment:   "Serve per divertirsi?",
            .edible:          "Si può mangiare o bere?",
            .wearable:        "Si può indossare?",
            .canHold:         "Puoi tenerlo in mano?",
            .metal:           "È di solito fatto di metallo?",
            .wood:            "È di solito fatto di legno?",
            .soft:            "È morbido al tatto?",
            .makesSound:      "Fa qualche suono?",
            .hasSmell:        "Ha un odore particolare?",
            .color:           "Ha di solito un colore preciso?",
            .givesLight:      "Emette luce?",
            .movesItself:     "Può muoversi da solo?",
            .movingParts:     "Ha parti mobili?",
            .liquid:          "È un liquido?",
            .hot:             "È di solito caldo?",
            .cold:            "È di solito freddo?",
            .food:            "È un tipo di cibo?",
            .tech:            "È legato alla tecnologia?",
            .job:             "È legato a un lavoro o una professione?",
            .season:          "È associato a una stagione?",
            .centuriesOld:    "Esiste da centinaia di anni?",
            .modern:          "È un'invenzione moderna?",
            .place:           "È un luogo?",
            .bodyPart:        "È una parte del corpo?",
            .inNature:        "È qualcosa che si trova in natura?",
        ],
        .german: [
            .physical:        "Ist es ein physisches Objekt, das man anfassen kann?",
            .abstractIdea:    "Ist es eine abstrakte Idee?",
            .emotion:         "Ist es eine Emotion oder ein Gefühl?",
            .action:          "Ist es etwas, das man tut?",
            .alive:           "Lebt es?",
            .everAlive:       "Hat es jemals gelebt?",
            .animal:          "Ist es ein Tier?",
            .plant:           "Ist es eine Pflanze?",
            .manMade:         "Ist es von Menschen gemacht?",
            .natural:         "Kommt es natürlich vor?",
            .biggerThanCar:   "Ist es größer als ein Auto?",
            .fitsInHand:      "Passt es in eine Hand?",
            .smallerThanShoe: "Ist es kleiner als ein Schuh?",
            .indoors:         "Findet man es meist drinnen?",
            .outdoors:        "Findet man es draußen in der Natur?",
            .inKitchen:       "Würde man es in einer Küche finden?",
            .nearWater:       "Findet man es im oder am Wasser?",
            .tool:            "Ist es ein Werkzeug oder Gerät?",
            .transport:       "Dient es der Fortbewegung?",
            .communication:   "Dient es der Kommunikation?",
            .entertainment:   "Dient es der Unterhaltung?",
            .edible:          "Kann man es essen oder trinken?",
            .wearable:        "Kann man es tragen?",
            .canHold:         "Kann man es in den Händen halten?",
            .metal:           "Ist es meist aus Metall?",
            .wood:            "Ist es meist aus Holz?",
            .soft:            "Ist es weich?",
            .makesSound:      "Macht es ein Geräusch?",
            .hasSmell:        "Hat es einen deutlichen Geruch?",
            .color:           "Hat es meist eine bestimmte Farbe?",
            .givesLight:      "Gibt es Licht ab?",
            .movesItself:     "Kann es sich von selbst bewegen?",
            .movingParts:     "Hat es bewegliche Teile?",
            .liquid:          "Ist es eine Flüssigkeit?",
            .hot:             "Ist es meist heiß?",
            .cold:            "Ist es meist kalt?",
            .food:            "Ist es eine Art Essen?",
            .tech:            "Hat es mit Technik zu tun?",
            .job:             "Hat es mit einem Beruf zu tun?",
            .season:          "Wird es mit einer Jahreszeit verbunden?",
            .centuriesOld:    "Gibt es das seit Hunderten von Jahren?",
            .modern:          "Ist es eine moderne Erfindung?",
            .place:           "Ist es ein Ort?",
            .bodyPart:        "Ist es ein Körperteil?",
            .inNature:        "Findet man es in der Natur?",
        ],
    ]

    /// The full question text in the given language, falling back to English.
    static func localizedFull(_ item: Item, _ language: GameLanguage) -> String {
        localized[language]?[item.key] ?? item.full
    }
}
