//
//  WordAttributes.swift
//  Hunch
//
//  Ground-truth facts about each secret word, used to make the Keeper accurate.
//
//  The on-device model is small and unreliable at INFERRING a word's properties
//  — it will happily call "courage" man-made or alive. The fix is to stop asking
//  it to guess: we tag each word with a CATEGORY, turn that category into a short
//  block of authoritative facts, and inject those facts into the Keeper's prompt.
//  The model then answers questions from correct premises instead of hallucinating.
//
//  Authoring is cheap: one category word per secret. The fact sentence is shared
//  per category, so you never write per-word prose. Untagged words simply fall
//  back to the model's own reasoning (no worse than before).
//

import Foundation

/// Coarse semantic class of a secret word. Chosen for the axes the model gets
/// wrong most often (concrete vs abstract, alive vs not, man-made vs natural).
enum WordCategory: String {
    case object            // tangible man-made thing (guitar, hammer, bottle)
    case structure         // built place/building (castle, library, bridge)
    case naturalPlace      // landform / natural place / celestial body (ocean, canyon, galaxy)
    case animal            // living animal (puppy, kitten)
    case plant             // living plant (flower)
    case person            // a human being (doctor, teacher)
    case food              // food or drink (apple, coffee, sandwich)
    case substance         // material / mineral (diamond, crystal, mineral)
    case bodyPart          // part of a body
    case naturalPhenomenon // weather / natural event (thunder, rainbow, gravity)
    case timePeriod        // season / time of day / span (winter, morning, weekend)
    case event             // occasion / activity (birthday, journey, festival)
    case artMusic          // art or music form (melody, painting, symphony)
    case abstract          // concept / quality / feeling (courage, justice, freedom)

    /// Authoritative facts injected into the Keeper's prompt. Written as plain
    /// truths the model must obey over its own guesses. Never names or hints at
    /// the word itself — only its general nature.
    var facts: String {
        switch self {
        case .object:
            return "It is a tangible, usually man-made physical object you could touch or hold. It is not alive."
        case .structure:
            return "It is a man-made place, building, or structure. It is not alive and is far too big to hold in your hand."
        case .naturalPlace:
            return "It is a natural place, landform, or body in nature. It is not man-made, not alive, and far too large to hold."
        case .animal:
            return "It is a living animal."
        case .plant:
            return "It is a living plant. It is not man-made."
        case .person:
            return "It is a person — a living human being. It is not man-made."
        case .food:
            return "It is a food or drink: a physical thing you can eat or taste. It is not man-made machinery and may be natural."
        case .substance:
            return "It is a physical material or substance. It is not alive."
        case .bodyPart:
            return "It is a part of a living body. It is not man-made."
        case .naturalPhenomenon:
            return "It is a natural phenomenon or event, not a solid object you can hold. It is not man-made and not alive."
        case .timePeriod:
            return "It is a period or unit of time, not a physical object. It has no size, color, material, or smell, and is not alive or man-made."
        case .event:
            return "It is an event, occasion, or activity, not a physical object you can hold. It is not alive and has no material or color."
        case .artMusic:
            return "It is a form of art or music — an abstract human creation, not a solid object you can hold. It is not alive."
        case .abstract:
            return "It is an abstract concept, quality, or feeling, not a physical object. It is not alive, not man-made, and has no size, color, smell, or material."
        }
    }
}

extension WordCategory {
    /// Whether the word has a tangible physical body. Drives the blanket rule:
    /// bodiless things can't be hot, edible, made of metal, bigger than a car, …
    var isPhysical: Bool {
        switch self {
        case .object, .structure, .naturalPlace, .animal, .plant,
             .person, .food, .substance, .bodyPart:
            return true
        case .naturalPhenomenon, .timePeriod, .event, .artMusic, .abstract:
            return false
        }
    }
}

/// The property a starter question asks about. Used to answer chip taps
/// deterministically from the word's category — instant, free of model
/// variance, and always correct — falling back to the model only when the
/// category can't decide.
enum StarterProperty {
    case physical, abstractIdea, emotion, action
    case alive, everAlive, animal, plant
    case manMade, natural
    case biggerThanCar, fitsInHand, smallerThanShoe
    case indoors, outdoors, inKitchen, nearWater
    case tool, transport, communication, entertainment
    case edible, wearable, canHold
    case metal, wood, soft
    case makesSound, hasSmell, color, givesLight
    case movesItself, movingParts
    case liquid, hot, cold, food
    case tech, job, season
    case centuriesOld, modern
    case place, bodyPart, inNature
}

/// Loads word tag data (categories + object sets) from the bundled
/// `WordData.json` — the SINGLE SOURCE OF TRUTH shared with
/// `debug/wick_tracer.py`. Edit that JSON, never inline lists here, so the Swift
/// engine and the Python verification tracer can never drift apart.
enum WordData {
    private struct Payload: Decodable {
        let categories: [String: String]
        let sets: [String: [String]]
    }
    private static let payload: Payload = {
        guard let url = Bundle.main.url(forResource: "WordData", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Payload.self, from: data) else {
            assertionFailure("WordData.json missing or malformed — Keeper accuracy layer will defer everything to the model")
            return Payload(categories: [:], sets: [:])
        }
        return decoded
    }()
    /// The object/animal refinement set with this name (empty if absent).
    static func set(_ name: String) -> Set<String> { Set(payload.sets[name] ?? []) }
    /// word -> category, decoded once.
    static let categories: [String: WordCategory] = payload.categories.reduce(into: [:]) { dict, pair in
        if let category = WordCategory(rawValue: pair.value) { dict[pair.key] = category }
    }
}

enum WordAttributes {

    // Per-word refinements for the coarse `.object` category, whose members vary
    // too much to answer some questions from the category alone (a car, a hammer,
    // and a drinking glass are all "objects").

    /// Objects whose purpose is carrying people or goods.
    static let vehicles = WordData.set("vehicles")
    /// Objects that are electronic or mechanical technology.
    static let techObjects = WordData.set("techObjects")
    /// Objects typically made of wood.
    static let woodenObjects = WordData.set("woodenObjects")
    /// Objects whose material genuinely varies — let the model judge "made of wood?".
    static let ambiguousWoodObjects = WordData.set("ambiguousWoodObjects")
    /// Objects that are recent inventions (or too mixed in age to call). Everyday
    /// clothing, tools, vessels, and instruments are otherwise centuries old, so
    /// these are the exceptions to that rule.
    static let modernObjects = WordData.set("modernObjects")
    /// Objects that typically make a sound — instruments, bells, phones, and
    /// motorized machines. Other objects (a ring, a table, a glass) are silent.
    static let soundMakingObjects = WordData.set("soundMakingObjects")
    /// Animals that don't vocalize — every other animal is treated as making a sound.
    static let silentAnimals = WordData.set("silentAnimals")
    /// Animals clearly smaller than a shoe.
    static let smallAnimals = WordData.set("smallAnimals")
    /// Animals clearly bigger than a shoe (mid-size ones defer to the model).
    static let bigAnimals = WordData.set("bigAnimals")
    /// Animals that plausibly live indoors (pets, pests, aquarium). "Found
    /// indoors?" defers to the model for these; every other animal is outdoors.
    static let indoorAnimals = WordData.set("indoorAnimals")
    /// Objects clearly smaller than a shoe.
    static let smallObjects = WordData.set("smallObjects")
    /// Objects clearly bigger than a shoe (mid-size ones defer to the model).
    static let bigObjects = WordData.set("bigObjects")
    /// Body parts clearly smaller than a shoe.
    static let smallBodyParts = WordData.set("smallBodyParts")
    /// Body parts clearly bigger than a shoe (mid-size ones defer to the model).
    static let bigBodyParts = WordData.set("bigBodyParts")
    /// Objects you actually wear — clothing, footwear, and accessories/jewelry.
    /// Every other object is not wearable (a bucket, a lamp, a spoon). Drives a
    /// deterministic "Can you wear it?", which the model otherwise gets wrong.
    static let wearableObjects = WordData.set("wearableObjects")
    /// Substances that ARE metals — everything else in `.substance` (stone, ice,
    /// clay, diamond, sand…) is not. Drives a deterministic "made of metal?".
    static let metalSubstances = WordData.set("metalSubstances")
    /// Animals people ride or use to haul — the only animals that answer anything
    /// but "No" to "used for transportation?". A tiger, a fish, an owl do not.
    static let rideableAnimals = WordData.set("rideableAnimals")
    /// The few secrets that genuinely emit their own light. Everything else
    /// answers "No" to "does it give off light?" (a tiger, a plum, a mirror).
    static let lightGivers = WordData.set("lightGivers")
    /// Whole plant foods that grow in the wild/on a plant — fruit, veg, nuts.
    /// These answer "found outdoors in nature?" with Yes and "usually hot?" with
    /// No. Processed foods (bread, cheese, pizza) are neither, and drinks that
    /// are served hot (coffee, tea, soup) keep deferring "hot" to the model.
    static let produceFoods = WordData.set("produceFoods")
    /// The only animals actually bigger than a car. Every other animal — a
    /// butterfly, a tiger, a horse — answers "No" to "bigger than a car?".
    static let hugeAnimals = WordData.set("hugeAnimals")
    /// Objects genuinely bigger than a car (big vehicles). Furniture, instruments,
    /// tools etc. are not — so a bed, a piano, a ladder answer "No".
    static let biggerThanCarObjects = WordData.set("biggerThanCarObjects")
    /// Secrets that are usually hot / usually cold. Drives "usually hot?" and
    /// "usually cold?" deterministically. Anything in neither set (a season, a
    /// metal, a room) keeps deferring, so summer/winter stay model-decided.
    static let hotThings = WordData.set("hotThings")
    static let coldThings = WordData.set("coldThings")
    /// Objects that are reliably metal — blades, fasteners, and hardware. Answers
    /// "made of metal?" with Yes; other objects (a pillow, a bottle) stay deferred
    /// since their material genuinely varies.
    static let metalObjects = WordData.set("metalObjects")
    /// Objects used to communicate or record language — writing tools, mail,
    /// and phones. Drives "used for communication?" → Yes; other objects (a
    /// bucket, a hammer) are not communication tools.
    static let communicationObjects = WordData.set("communicationObjects")
    /// Objects with mechanical moving parts — motors, vehicles, and clockwork.
    /// Drives "does it have moving parts?" → Yes. One-piece objects and all
    /// non-objects (food, body parts, landforms) have none.
    static let mechanicalObjects = WordData.set("mechanicalObjects")
    /// Objects found in a kitchen — cookware, tableware, and utensils. Drives
    /// "found in a kitchen?" → Yes for these (all food is Yes too); every other
    /// object answers No.
    static let kitchenObjects = WordData.set("kitchenObjects")
    /// Objects that are soft to the touch — textiles and plush goods. Drives
    /// "is it soft?" → Yes. Hard objects answer No; anything else defers.
    static let softObjects = WordData.set("softObjects")
    /// Objects that are hard/rigid — metal hardware, tableware, glass, and
    /// machinery. Drives "is it soft?" → No. Neither soft nor hard → defer.
    static let hardObjects = WordData.set("hardObjects")
    /// Natural places that are bodies of water — "is it soft?" is genuinely
    /// fuzzy for these (water yields), so they defer; solid landforms answer No.
    static let waterBodies = WordData.set("waterBodies")
    /// Words that ARE a liquid regardless of category — drinks, molten/organic
    /// fluids, rain. Drives "is it a liquid?" → Yes; everything else is solid.
    static let liquids = WordData.set("liquids")
    /// Objects that are hand tools / implements. Drives "is it a tool?" → Yes for
    /// these; every other object and all non-objects answer No.
    static let toolObjects = WordData.set("toolObjects")
    /// The four seasons. Drives "is it associated with a season?" → Yes; other
    /// times of day/week answer No.
    static let seasons = WordData.set("seasons")

    /// A confident yes/no/sort-of for a (word, category, property) triple, or nil
    /// when we can't reliably decide (caller should ask the model, which still
    /// receives the category facts). The word refines the coarse `.object` class.
    static func deterministicVerdict(word: String, language: GameLanguage = .english, category c: WordCategory, property p: StarterProperty) -> String? {
        let w = englishForm(word, language: language)
        // Blanket rule: a thing with no physical body cannot have any of these.
        // NB: hot/cold are deliberately excluded — a season (timePeriod) like
        // winter/summer genuinely has a temperature, so let the model decide.
        let needsBody: Set<StarterProperty> = [
            .biggerThanCar, .fitsInHand, .smallerThanShoe, .edible, .wearable,
            .canHold, .metal, .wood, .soft, .liquid, .food,
            .inKitchen, .nearWater, .indoors, .outdoors, .movesItself, .movingParts,
        ]
        let bodiless: Set<WordCategory> = [.abstract, .timePeriod, .event, .artMusic]
        if bodiless.contains(c) && needsBody.contains(p) { return "No" }

        switch p {
        case .physical:
            return c.isPhysical ? "Yes" : "No"
        case .abstractIdea:
            switch c {
            case .abstract: return "Yes"
            case .timePeriod, .event, .artMusic: return "Sort of"
            // Natural phenomena (frost, thunder, rainbow, gravity) are physical,
            // observable events — not human concepts like justice. So they answer
            // "No" via the default below, not "Sort of".
            default: return "No"
            }
        case .emotion:
            return c == .abstract ? nil : "No"   // only some abstracts are emotions
        case .action:
            switch c {
            case .event: return "Sort of"
            case .abstract: return nil
            default: return "No"
            }
        case .alive:
            switch c {
            case .animal, .plant, .person: return "Yes"
            case .bodyPart: return "Sort of"
            default: return "No"
            }
        case .everAlive:
            switch c {
            case .animal, .plant, .person, .bodyPart: return "Yes"
            case .food: return "Sort of"
            default: return "No"
            }
        case .animal:
            return c == .animal ? "Yes" : "No"
        case .plant:
            switch c {
            case .plant: return "Yes"
            case .food: return nil      // could be plant-based; let model decide
            default: return "No"
            }
        case .manMade:
            switch c {
            case .object, .structure: return "Yes"
            case .artMusic, .event: return "Sort of"
            case .food: return nil
            default: return "No"
            }
        case .natural:
            switch c {
            case .naturalPlace, .animal, .plant, .naturalPhenomenon,
                 .substance, .bodyPart, .person, .timePeriod: return "Yes"
            case .food: return "Sort of"
            default: return "No"
            }
        case .place:
            switch c {
            case .naturalPlace, .structure: return "Yes"
            default: return "No"
            }
        case .bodyPart:
            return c == .bodyPart ? "Yes" : "No"
        case .inNature:
            switch c {
            case .naturalPlace, .animal, .plant, .naturalPhenomenon, .substance: return "Yes"
            case .bodyPart: return "Sort of"
            case .food: return produceFoods.contains(w) ? "Yes" : "No"  // fruit/veg grows in the wild; bread doesn't
            default: return "No"
            }
        case .food:
            return c == .food ? "Yes" : "No"
        case .liquid:
            if liquids.contains(w) { return "Yes" }   // water, oil, soup, magma, blood, rain…
            switch c {
            case .structure, .naturalPlace, .animal, .plant, .person, .bodyPart,
                 .object, .substance:                  // stone, iron, sand… are solid
                return "No"
            case .food: return produceFoods.contains(w) ? "No" : nil   // solid produce No; other foods defer
            default: return nil
            }
        case .transport:
            // Vehicles carry people; other objects don't. Only rideable/pack
            // animals count (horse, camel…) — a tiger or a fish does not. Roads
            // and rails (structures) genuinely vary, so defer only those.
            switch c {
            case .object: return vehicles.contains(w) ? "Yes" : "No"
            case .animal: return rideableAnimals.contains(w) ? "Sort of" : "No"
            case .structure: return nil
            default: return "No"
            }
        case .movesItself:
            // Moving under its own power is a property of living movers.
            switch c {
            case .animal, .person: return "Yes"
            case .naturalPhenomenon: return nil   // wind/tide move; thunder doesn't
            default: return "No"
            }
        case .tech:
            // Electronic/mechanical objects are "technology"; a phone yes, a
            // drinking glass no. Nothing natural, alive, edible, or abstract counts.
            switch c {
            case .object: return techObjects.contains(w) ? "Yes" : "No"
            default: return "No"
            }
        case .wood:
            // Material varies per object; answer the ones we're sure of and
            // defer genuinely mixed cases (doors, boats) to the model.
            switch c {
            case .object:
                if woodenObjects.contains(w) { return "Yes" }
                if ambiguousWoodObjects.contains(w) { return nil }
                return "No"
            case .structure, .plant: return nil   // cabins, trees — mixed
            default: return "No"                  // body parts, food, nature, etc.
            }
        case .indoors:
            // Nature and most animals live outdoors; likely pets defer to the
            // model, and furniture/objects vary, so defer those too.
            switch c {
            case .naturalPlace, .naturalPhenomenon: return "No"
            case .animal: return indoorAnimals.contains(w) ? nil : "No"
            default: return nil
            }
        case .outdoors:
            switch c {
            case .naturalPlace, .naturalPhenomenon: return "Yes"
            case .animal: return indoorAnimals.contains(w) ? nil : "Yes"
            default: return nil
            }
        case .centuriesOld:
            // Natural things and living kinds have been around for ages, and so
            // have everyday objects (clothing, tools, vessels) — except modern
            // inventions, which we defer to the model.
            switch c {
            case .naturalPlace, .naturalPhenomenon, .substance, .animal, .plant,
                 .bodyPart, .person, .timePeriod, .food: return "Yes"
            case .object: return modernObjects.contains(w) ? nil : "Yes"
            default: return nil
            }
        case .modern:
            // Inverse of centuriesOld.
            switch c {
            case .naturalPlace, .naturalPhenomenon, .substance, .animal, .plant,
                 .bodyPart, .person, .timePeriod, .food: return "No"
            case .object: return modernObjects.contains(w) ? nil : "No"
            default: return nil
            }
        case .makesSound:
            // Instruments, bells, phones, and engines make noise; most objects
            // are silent. Animals vocalize unless they're on the silent list.
            switch c {
            case .object: return soundMakingObjects.contains(w) ? "Yes" : "No"
            case .animal: return silentAnimals.contains(w) ? "No" : "Yes"
            default: return nil
            }
        case .smallerThanShoe:
            // Sizes we're sure of for animals and objects; mid-size ones vary, so
            // defer those. (Bodiless things are handled by the blanket rule above.)
            switch c {
            case .animal:
                if smallAnimals.contains(w) { return "Yes" }
                if bigAnimals.contains(w) { return "No" }
                return nil
            case .object:
                if smallObjects.contains(w) { return "Yes" }
                if bigObjects.contains(w) { return "No" }
                return nil
            case .bodyPart:
                if smallBodyParts.contains(w) { return "Yes" }
                if bigBodyParts.contains(w) { return "No" }
                return nil
            default: return nil
            }
        case .wearable:
            // Only clothing/accessories are worn; every other object (and every
            // non-object physical thing — food, animal, body part) is not.
            switch c {
            case .object: return wearableObjects.contains(w) ? "Yes" : "No"
            default: return "No"
            }
        case .metal:
            // Nothing living or edible is metal; a natural place isn't either.
            // Some substances are metals (iron, gold…); objects and structures
            // vary too much (a spoon vs. a pillow), so defer only those.
            switch c {
            case .food, .animal, .plant, .person, .bodyPart, .naturalPlace, .naturalPhenomenon:
                return "No"
            case .substance:
                return metalSubstances.contains(w) ? "Yes" : "No"
            case .object:
                return metalObjects.contains(w) ? "Yes" : nil   // hardware = Yes; else model decides
            case .structure:
                return nil
            default:
                return "No"
            }
        case .biggerThanCar:
            // Foods, body parts, materials, and (ordinary) people are never
            // bigger than a car; natural places always are. Objects, structures,
            // animals, and weather genuinely vary — defer those.
            switch c {
            case .food, .bodyPart, .substance, .person: return "No"
            case .naturalPlace: return "Yes"
            case .animal: return hugeAnimals.contains(w) ? "Yes" : "No"
            case .object: return biggerThanCarObjects.contains(w) ? "Yes" : "No"
            case .structure, .naturalPhenomenon: return nil
            default: return "No"
            }
        case .givesLight:
            // A tiny, curated set truly emits light; everything else does not.
            return lightGivers.contains(w) ? "Yes" : "No"
        case .hot:
            // Curated hot/cold sets settle the clear cases; raw produce is never
            // hot. Body parts are ~body-temp and everyday objects are room-temp,
            // so both answer No unless explicitly in hotThings (a running engine).
            // Anything left (a season, a metal, a structure) genuinely varies, so
            // let the model decide (summer/winter stay model-decided).
            if hotThings.contains(w) { return "Yes" }
            if coldThings.contains(w) { return "No" }
            if c == .food, produceFoods.contains(w) { return "No" }
            if bodiless.contains(c) { return "No" }   // no body → not hot (summer handled above)
            if c == .bodyPart { return "No" }         // body parts sit at body temperature
            if c == .object { return "No" }           // objects are room-temp unless in hotThings
            return nil
        case .cold:
            if coldThings.contains(w) { return "Yes" }
            if hotThings.contains(w) { return "No" }
            if c == .food, produceFoods.contains(w) { return "No" }
            if bodiless.contains(c) { return "No" }   // no body → not cold (winter handled above)
            if c == .bodyPart { return "No" }         // body parts sit at body temperature
            if c == .object { return "No" }           // objects are room-temp unless in coldThings
            return nil
        case .communication:
            // Writing tools, mail, and phones communicate; other objects and
            // all non-objects (an apple, a tiger, a mountain) do not.
            switch c {
            case .object: return communicationObjects.contains(w) ? "Yes" : "No"
            default: return "No"
            }
        case .movingParts:
            // Only mechanical objects (motors, vehicles, clockwork) have moving
            // parts; solid objects and all edible/living/natural things do not.
            // Structures vary (a windmill has them, a wall doesn't) — defer those.
            switch c {
            case .object: return mechanicalObjects.contains(w) ? "Yes" : "No"
            case .structure: return nil
            default: return "No"
            }
        case .edible:
            // Food is edible; body parts, objects, structures, materials, and
            // places are not. Animals and plants genuinely vary (a chicken vs a
            // lion), so those defer to the model.
            switch c {
            case .food: return "Yes"
            case .bodyPart, .object, .structure, .substance,
                 .naturalPlace, .naturalPhenomenon, .person: return "No"
            case .animal, .plant: return nil
            default: return "No"   // bodiless already handled by the blanket rule
            }
        case .inKitchen:
            // Food and kitchenware belong in a kitchen; every other object and
            // all non-objects do not.
            switch c {
            case .food: return "Yes"
            case .object: return kitchenObjects.contains(w) ? "Yes" : "No"
            default: return "No"
            }
        case .soft:
            // Textiles/plush are soft; metal, glass, and machinery are hard.
            // Water bodies are arguably soft, so they defer; solid landforms are
            // hard. Anything else (a body part, a substance) defers to the model.
            switch c {
            case .object:
                if softObjects.contains(w) { return "Yes" }
                if hardObjects.contains(w) { return "No" }
                return nil
            case .naturalPlace:
                return waterBodies.contains(w) ? nil : "No"
            default:
                return nil
            }
        case .entertainment:
            // A rock, a body part, a season, a natural phenomenon, or a raw
            // foodstuff is not "used for entertainment." Objects (a ball vs. a
            // bucket), art/music, events, animals, structures, and people vary —
            // defer those to the model.
            switch c {
            case .food, .substance, .bodyPart, .naturalPhenomenon, .timePeriod:
                return "No"
            default:
                return nil
            }
        case .job:
            // A job or profession is a people-role, not a thing. Concrete non-person
            // nouns (a pumpkin, a towel, a river, a hand) are not a profession, so
            // answer No. A person may be a profession (doctor) or not (child), and a
            // structure can be a workplace (office, hospital) — defer those, plus
            // events/art/abstract, to the model.
            switch c {
            case .food, .plant, .animal, .bodyPart, .naturalPlace,
                 .naturalPhenomenon, .substance, .object, .timePeriod:
                return "No"
            default:
                return nil
            }
        case .color:
            // Every physical thing has some color; a concept, a time, an event, or
            // a piece of music does not. Natural phenomena vary (a rainbow and fire
            // have color; gravity and wind do not), so those defer.
            if c.isPhysical { return "Yes" }
            if c == .naturalPhenomenon { return nil }
            return "No"
        case .tool:
            // Only a hand tool or implement is "a tool". Every other object (a bell,
            // a bottle, an instrument) and every non-object is not.
            switch c {
            case .object: return toolObjects.contains(w) ? "Yes" : "No"
            default: return "No"
            }
        case .season:
            // The seasons themselves are Yes; other times of day/week are No, as are
            // objects, materials, body parts, people, and bodiless concepts. Produce,
            // plants, animals, places, and weather have fuzzy seasonal ties — defer.
            switch c {
            case .timePeriod: return seasons.contains(w) ? "Yes" : "No"
            case .object, .structure, .substance, .bodyPart, .person,
                 .abstract, .event, .artMusic: return "No"
            default: return nil
            }
        case .fitsInHand:
            // Bodiless things are already handled by the blanket rule above. Big
            // places, buildings, people, and weather don't fit in a hand; the size
            // sets settle the clear objects/animals/body parts; food and materials
            // vary too much, so those defer.
            switch c {
            case .naturalPlace, .structure, .person, .naturalPhenomenon: return "No"
            case .object:   return smallObjects.contains(w) ? "Yes" : (bigObjects.contains(w) ? "No" : nil)
            case .animal:   return smallAnimals.contains(w) ? "Yes" : (bigAnimals.contains(w) ? "No" : nil)
            case .bodyPart: return smallBodyParts.contains(w) ? "Yes" : (bigBodyParts.contains(w) ? "No" : nil)
            default: return nil
            }
        // Functional, material, and sensory properties aren't reliably derivable
        // from a coarse category — defer to the model (which has the facts).
        default:
            return nil
        }
    }



    /// Category by word. Only the daily pool (tiers 1–2) is tagged today; any
    /// untagged word falls back to the model's own reasoning. Extend freely.
    static let categories: [String: WordCategory] = WordData.categories

    /// The English form of a word — lets any language's target (e.g. "gato",
    /// "chat", "gatto", "katze") resolve to the English-keyed category data
    /// ("cat"), so accuracy works in every supported language.
    ///
    /// Pass the round's `language` when it isn't English: the word's
    /// same-language pair is looked up FIRST, so cross-language homographs
    /// can't mislead the tags ("rock" is a skirt in a German round, not a
    /// stone; "camera" is a bedroom in an Italian round, not a device).
    static func englishForm(_ word: String, language: GameLanguage = .english) -> String {
        let w = word.lowercased()
        if language != .english, let en = DailyWords.english(of: w, in: language) {
            return en
        }
        if categories[w] != nil { return w }
        return DailyWords.translate(w, to: .english) ?? w
    }

    /// Ground-truth facts for a word, or nil if untagged (model reasons alone).
    static func facts(for word: String, language: GameLanguage = .english) -> String? {
        categories[englishForm(word, language: language)]?.facts
    }

    /// The tagged category for a word, or nil if untagged.
    static func category(for word: String, language: GameLanguage = .english) -> WordCategory? {
        categories[englishForm(word, language: language)]
    }
}
