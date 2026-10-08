//
//  HintVocabulary.swift
//  Hunch
//
//  A broad, common-word vocabulary used only to source hints. Ranked by real
//  semantic similarity to the secret word, so hints are genuinely related.
//  (Duplicates with WordBank are fine — the view model de-dupes via a Set.)
//

enum HintVocabulary {
    static let words: [String] = [
        // Animals
        "dog", "cat", "horse", "cow", "sheep", "pig", "lion", "tiger", "bear", "wolf",
        "fox", "deer", "rabbit", "mouse", "frog", "snake", "eagle", "owl", "shark",
        "whale", "dolphin", "fish", "crab", "spider", "bee", "butterfly", "elephant",
        "monkey", "giraffe", "zebra", "penguin", "seal", "duck", "turtle", "lizard",
        // Food & drink
        "bread", "rice", "pasta", "soup", "salad", "meat", "chicken", "egg", "milk",
        "water", "juice", "wine", "tea", "cake", "candy", "chocolate", "sugar", "honey",
        "pizza", "sandwich", "fruit", "vegetable", "potato", "tomato", "carrot", "lemon",
        // Nature
        "tree", "grass", "leaf", "branch", "seed", "rain", "snow", "wind", "cloud",
        "sun", "moon", "star", "sky", "fire", "smoke", "stone", "rock", "sand", "hill",
        "cliff", "cave", "wave", "pond", "lake", "stream", "swamp", "field",
        // Body
        "head", "hand", "foot", "arm", "leg", "eye", "ear", "nose", "mouth", "tooth",
        "hair", "heart", "brain", "bone", "skin", "blood", "finger", "knee",
        // Objects
        "chair", "table", "bed", "door", "wall", "roof", "floor", "lamp", "clock",
        "book", "paper", "knife", "fork", "spoon", "plate", "cup", "bottle", "box",
        "bag", "key", "lock", "rope", "wheel", "nail", "brush", "soap", "towel",
        "phone", "computer", "screen", "button", "wire", "battery",
        // Places & buildings
        "city", "town", "village", "house", "store", "road", "street", "park",
        "church", "museum", "airport", "station", "prison", "hotel", "tower",
        // Transport
        "car", "bus", "train", "plane", "boat", "ship", "bike", "truck", "subway",
        // Clothing
        "shirt", "dress", "hat", "shoe", "sock", "coat", "glove", "scarf", "belt",
        "ring", "watch", "crown",
        // People & roles
        "king", "queen", "knight", "nurse", "judge", "pilot", "chef", "artist",
        "writer", "singer", "actor", "athlete", "scientist", "sailor", "hunter",
        "thief", "wizard", "doctor",
        // Abstract & feelings
        "love", "fear", "anger", "joy", "hope", "dream", "peace", "war", "time",
        "money", "art", "science", "magic", "power", "energy", "speed", "weight",
        "color", "sound", "light", "shadow", "secret", "truth", "idea", "story",
        "game", "sport", "dance", "song", "luck", "death", "life",
        // Weather & cosmos
        "storm", "lightning", "thunder", "rainbow", "comet", "galaxy", "gravity",
        // More animals
        "goat", "donkey", "camel", "hippo", "rhino", "kangaroo", "squirrel", "hedgehog",
        "otter", "beaver", "raccoon", "bat", "crow", "parrot", "peacock", "swan", "goose",
        "octopus", "jellyfish", "lobster", "snail", "ant", "moth", "beetle", "worm",
        // More food & drink
        "burger", "noodle", "cereal", "yogurt", "cheese", "bacon", "steak", "shrimp",
        "berry", "grape", "peach", "melon", "onion", "garlic", "pepper", "mushroom",
        "coffee", "beer", "soda", "pie", "donut", "biscuit", "jam", "syrup",
        // More nature & places
        "forest", "jungle", "desert", "valley", "canyon", "glacier", "volcano", "island",
        "beach", "harbor", "garden", "meadow", "marsh", "reef", "dune", "waterfall",
        "mountain", "river", "ocean", "valley", "prairie", "tundra",
        // More objects & tools
        "scissors", "needle", "thread", "ladder", "bucket", "broom", "shovel", "axe",
        "drill", "saw", "screw", "magnet", "candle", "lantern", "mirror", "comb",
        "umbrella", "wallet", "ticket", "stamp", "envelope", "notebook", "crayon", "ruler",
        // More transport & buildings
        "tractor", "scooter", "canoe", "rocket", "helicopter", "ambulance", "taxi",
        "bridge", "tunnel", "castle", "palace", "temple", "factory", "library", "stadium",
        "lighthouse", "windmill", "barn", "cottage", "tower", "fence", "gate",
        // More abstract & culture
        "memory", "wisdom", "courage", "freedom", "justice", "mercy", "honor", "fame",
        "wealth", "poverty", "danger", "safety", "silence", "noise", "rhythm", "melody",
        "poem", "novel", "movie", "theater", "festival", "holiday", "wedding", "funeral",
        "history", "future", "language", "number", "shape", "pattern", "balance", "motion"
    ]
}
