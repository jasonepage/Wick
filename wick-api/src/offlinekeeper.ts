//
//  offlinekeeper.ts — the deterministic Keeper (SRS FR-19 "deterministic-first").
//
//  Faithful TypeScript port of debug/wick_tracer.py, which itself mirrors the iOS
//  Hunch/Engine {WordAttributes.deterministicVerdict, OfflineKeeper.property/reply}.
//  Answers the common yes/no questions about a curated word INSTANTLY, offline,
//  free, and identically to the app — no LLM. Only deferred cases (unknown word,
//  unmapped question, or a genuinely ambiguous verdict) fall through to Gemini.
//
//  Data: worddata.json (categories + property sets) is the SAME file the app and
//  the tracer read. Keep this port in lockstep with wick_tracer.py.
//

import data from "./worddata.json" with { type: "json" };

type Verdict = "Yes" | "No" | "Sort of";

const CATEGORIES: Record<string, string> = data.categories as Record<string, string>;
const RAW_SETS: Record<string, string[]> = data.sets as Record<string, string[]>;

// camelCase set names (in JSON) → the CONST names the verdict logic uses.
const ALIAS: Record<string, string> = {
  vehicles: "VEHICLES", techObjects: "TECH_OBJECTS", woodenObjects: "WOODEN_OBJECTS",
  ambiguousWoodObjects: "AMBIG_WOOD", modernObjects: "MODERN_OBJECTS", soundMakingObjects: "SOUND_OBJECTS",
  silentAnimals: "SILENT_ANIMALS", smallAnimals: "SMALL_ANIMALS", bigAnimals: "BIG_ANIMALS",
  indoorAnimals: "INDOOR_ANIMALS", smallObjects: "SMALL_OBJECTS", bigObjects: "BIG_OBJECTS",
  smallBodyParts: "SMALL_BODYPARTS", bigBodyParts: "BIG_BODYPARTS", wearableObjects: "WEARABLE_OBJECTS",
  metalSubstances: "METAL_SUBSTANCES", rideableAnimals: "RIDEABLE_ANIMALS", lightGivers: "LIGHT_GIVERS",
  produceFoods: "PRODUCE_FOODS", hugeAnimals: "HUGE_ANIMALS", biggerThanCarObjects: "BIGGER_THAN_CAR_OBJECTS",
  hotThings: "HOT_THINGS", coldThings: "COLD_THINGS", metalObjects: "METAL_OBJECTS",
  communicationObjects: "COMMUNICATION_OBJECTS", mechanicalObjects: "MECHANICAL_OBJECTS",
  kitchenObjects: "KITCHEN_OBJECTS", softObjects: "SOFT_OBJECTS", hardObjects: "HARD_OBJECTS",
  waterBodies: "WATER_BODIES", liquids: "LIQUIDS", toolObjects: "TOOL_OBJECTS", seasons: "SEASONS",
};

const S: Record<string, Set<string>> = {};
for (const [camel, konst] of Object.entries(ALIAS)) {
  S[konst] = new Set(RAW_SETS[camel] ?? []);
}
function has(setName: string, w: string): boolean {
  return S[setName]!.has(w);
}

const PHYSICAL_CATS = new Set([
  "object", "structure", "naturalPlace", "animal", "plant", "person", "food", "substance", "bodyPart",
]);

// ── deterministic verdict (port of WordAttributes.deterministicVerdict) ────────

function deterministicVerdict(w: string, c: string, p: string): Verdict | null {
  const needsBody = new Set([
    "biggerThanCar", "fitsInHand", "smallerThanShoe", "edible", "wearable", "canHold", "metal", "wood",
    "soft", "liquid", "food", "inKitchen", "nearWater", "indoors", "outdoors", "movesItself", "movingParts",
  ]);
  const bodiless = new Set(["abstract", "timePeriod", "event", "artMusic"]);
  if (bodiless.has(c) && needsBody.has(p)) return "No";

  switch (p) {
    case "physical": return PHYSICAL_CATS.has(c) ? "Yes" : "No";
    case "abstractIdea":
      if (c === "abstract") return "Yes";
      if (c === "timePeriod" || c === "event" || c === "artMusic") return "Sort of";
      return "No";
    case "emotion": return c === "abstract" ? null : "No";
    case "action":
      if (c === "event") return "Sort of";
      if (c === "abstract") return null;
      return "No";
    case "alive":
      if (c === "animal" || c === "plant" || c === "person") return "Yes";
      if (c === "bodyPart") return "Sort of";
      return "No";
    case "everAlive":
      if (c === "animal" || c === "plant" || c === "person" || c === "bodyPart") return "Yes";
      if (c === "food") return "Sort of";
      return "No";
    case "animal": return c === "animal" ? "Yes" : "No";
    case "plant":
      if (c === "plant") return "Yes";
      if (c === "food") return null;
      return "No";
    case "manMade":
      if (c === "object" || c === "structure") return "Yes";
      if (c === "artMusic" || c === "event") return "Sort of";
      if (c === "food") return null;
      return "No";
    case "natural":
      if (["naturalPlace", "animal", "plant", "naturalPhenomenon", "substance", "bodyPart", "person", "timePeriod"].includes(c)) return "Yes";
      if (c === "food") return "Sort of";
      return "No";
    case "place": return c === "naturalPlace" || c === "structure" ? "Yes" : "No";
    case "bodyPart": return c === "bodyPart" ? "Yes" : "No";
    case "inNature":
      if (["naturalPlace", "animal", "plant", "naturalPhenomenon", "substance"].includes(c)) return "Yes";
      if (c === "bodyPart") return "Sort of";
      if (c === "food") return has("PRODUCE_FOODS", w) ? "Yes" : "No";
      return "No";
    case "wearable":
      if (c === "object") return has("WEARABLE_OBJECTS", w) ? "Yes" : "No";
      return "No";
    case "food": return c === "food" ? "Yes" : "No";
    case "liquid":
      if (has("LIQUIDS", w)) return "Yes";
      if (["structure", "naturalPlace", "animal", "plant", "person", "bodyPart", "object", "substance"].includes(c)) return "No";
      if (c === "food") return has("PRODUCE_FOODS", w) ? "No" : null;
      return null;
    case "transport":
      if (c === "object") return has("VEHICLES", w) ? "Yes" : "No";
      if (c === "animal") return has("RIDEABLE_ANIMALS", w) ? "Sort of" : "No";
      if (c === "structure") return null;
      return "No";
    case "metal":
      if (["food", "animal", "plant", "person", "bodyPart", "naturalPlace", "naturalPhenomenon"].includes(c)) return "No";
      if (c === "substance") return has("METAL_SUBSTANCES", w) ? "Yes" : "No";
      if (c === "object") return has("METAL_OBJECTS", w) ? "Yes" : null;
      if (c === "structure") return null;
      return "No";
    case "biggerThanCar":
      if (["food", "bodyPart", "substance", "person"].includes(c)) return "No";
      if (c === "naturalPlace") return "Yes";
      if (c === "animal") return has("HUGE_ANIMALS", w) ? "Yes" : "No";
      if (c === "object") return has("BIGGER_THAN_CAR_OBJECTS", w) ? "Yes" : "No";
      if (c === "structure" || c === "naturalPhenomenon") return null;
      return "No";
    case "givesLight": return has("LIGHT_GIVERS", w) ? "Yes" : "No";
    case "hot":
      if (has("HOT_THINGS", w)) return "Yes";
      if (has("COLD_THINGS", w)) return "No";
      if (c === "food" && has("PRODUCE_FOODS", w)) return "No";
      if (["abstract", "timePeriod", "event", "artMusic", "bodyPart", "object"].includes(c)) return "No";
      return null;
    case "cold":
      if (has("COLD_THINGS", w)) return "Yes";
      if (has("HOT_THINGS", w)) return "No";
      if (c === "food" && has("PRODUCE_FOODS", w)) return "No";
      if (["abstract", "timePeriod", "event", "artMusic", "bodyPart", "object"].includes(c)) return "No";
      return null;
    case "communication":
      if (c === "object") return has("COMMUNICATION_OBJECTS", w) ? "Yes" : "No";
      return "No";
    case "movingParts":
      if (c === "object") return has("MECHANICAL_OBJECTS", w) ? "Yes" : "No";
      if (c === "structure") return null;
      return "No";
    case "edible":
      if (c === "food") return "Yes";
      if (["bodyPart", "object", "structure", "substance", "naturalPlace", "naturalPhenomenon", "person"].includes(c)) return "No";
      if (c === "animal" || c === "plant") return null;
      return "No";
    case "inKitchen":
      if (c === "food") return "Yes";
      if (c === "object") return has("KITCHEN_OBJECTS", w) ? "Yes" : "No";
      return "No";
    case "soft":
      if (c === "object") {
        if (has("SOFT_OBJECTS", w)) return "Yes";
        if (has("HARD_OBJECTS", w)) return "No";
        return null;
      }
      if (c === "naturalPlace") return has("WATER_BODIES", w) ? null : "No";
      return null;
    case "movesItself":
      if (c === "animal" || c === "person") return "Yes";
      if (c === "naturalPhenomenon") return null;
      return "No";
    case "tech":
      if (c === "object") return has("TECH_OBJECTS", w) ? "Yes" : "No";
      return "No";
    case "wood":
      if (c === "object") {
        if (has("WOODEN_OBJECTS", w)) return "Yes";
        if (has("AMBIG_WOOD", w)) return null;
        return "No";
      }
      if (c === "structure" || c === "plant") return null;
      return "No";
    case "indoors":
      if (c === "naturalPlace" || c === "naturalPhenomenon") return "No";
      if (c === "animal") return has("INDOOR_ANIMALS", w) ? null : "No";
      return null;
    case "outdoors":
      if (c === "naturalPlace" || c === "naturalPhenomenon") return "Yes";
      if (c === "animal") return has("INDOOR_ANIMALS", w) ? null : "Yes";
      return null;
    case "centuriesOld":
      if (["naturalPlace", "naturalPhenomenon", "substance", "animal", "plant", "bodyPart", "person", "timePeriod", "food"].includes(c)) return "Yes";
      if (c === "object") return has("MODERN_OBJECTS", w) ? null : "Yes";
      return null;
    case "modern":
      if (["naturalPlace", "naturalPhenomenon", "substance", "animal", "plant", "bodyPart", "person", "timePeriod", "food"].includes(c)) return "No";
      if (c === "object") return has("MODERN_OBJECTS", w) ? null : "No";
      return null;
    case "makesSound":
      if (c === "object") return has("SOUND_OBJECTS", w) ? "Yes" : "No";
      if (c === "animal") return has("SILENT_ANIMALS", w) ? "No" : "Yes";
      return null;
    case "smallerThanShoe":
      if (c === "animal") return has("SMALL_ANIMALS", w) ? "Yes" : has("BIG_ANIMALS", w) ? "No" : null;
      if (c === "object") return has("SMALL_OBJECTS", w) ? "Yes" : has("BIG_OBJECTS", w) ? "No" : null;
      if (c === "bodyPart") return has("SMALL_BODYPARTS", w) ? "Yes" : has("BIG_BODYPARTS", w) ? "No" : null;
      return null;
    case "entertainment":
      if (["food", "substance", "bodyPart", "naturalPhenomenon", "timePeriod"].includes(c)) return "No";
      return null;
    case "color":
      if (PHYSICAL_CATS.has(c)) return "Yes";
      if (c === "naturalPhenomenon") return null;
      return "No";
    case "tool":
      if (c === "object") return has("TOOL_OBJECTS", w) ? "Yes" : "No";
      return "No";
    case "season":
      if (c === "timePeriod") return has("SEASONS", w) ? "Yes" : "No";
      if (["object", "structure", "substance", "bodyPart", "person", "abstract", "event", "artMusic"].includes(c)) return "No";
      return null;
    case "fitsInHand":
      if (["naturalPlace", "structure", "person", "naturalPhenomenon"].includes(c)) return "No";
      if (c === "object") return has("SMALL_OBJECTS", w) ? "Yes" : has("BIG_OBJECTS", w) ? "No" : null;
      if (c === "animal") return has("SMALL_ANIMALS", w) ? "Yes" : has("BIG_ANIMALS", w) ? "No" : null;
      if (c === "bodyPart") return has("SMALL_BODYPARTS", w) ? "Yes" : has("BIG_BODYPARTS", w) ? "No" : null;
      return null;
    case "job":
      if (["food", "plant", "animal", "bodyPart", "naturalPlace", "naturalPhenomenon", "substance", "object", "timePeriod"].includes(c)) return "No";
      return null;
    default:
      return null;
  }
}

// ── question → property (port of OfflineKeeper.property, English) ──────────────

const PROP_MAP: Array<[string, string[]]> = [
  ["everAlive", ["ever alive", "was it alive", "once alive", "used to be alive", "ever living", "once living", "was it living"]],
  ["alive", ["alive", "still living", "is it living", "a living thing"]],
  ["animal", ["an animal", "is it animal", "a creature", "a beast", "a mammal", "a bird", "an insect", "a fish"]],
  ["plant", ["a plant", "is it plant", "vegetation", "a flower or"]],
  ["bodyPart", ["body part", "part of the body", "part of your body", "part of a body", "anatomy", "body-part"]],
  ["emotion", ["an emotion", "is it emotion", "a feeling", "emotional", "how you feel"]],
  ["abstractIdea", ["abstract", "an idea", "a concept", "concept", "a notion", "intangible", "in your mind", "just an idea"]],
  ["action", ["an action", "something you do", "an activity", "a verb", "is it an action", "an act"]],
  ["manMade", ["man-made", "manmade", "man made", "manufactured", "made by people", "made by humans", "made by man", "artificial", "human-made", "human made", "built by", "made in a factory"]],
  ["inNature", ["in nature", "in the wild", "in the wilderness", "out in nature", "in the wild?", "found in the wild"]],
  ["natural", ["occur naturally", "occurs naturally", "found in nature", "naturally occurring", "made by nature", "natural", "naturally"]],
  ["place", ["a place", "is it a place", "a location", "somewhere you can", "geographic", "a spot you can go"]],
  ["biggerThanCar", ["bigger than a car", "bigger than car", "larger than a car", "bigger than a house", "huge", "enormous", "gigantic", "very big", "very large", "massive"]],
  ["smallerThanShoe", ["smaller than a shoe", "smaller than shoe", "tiny", "very small", "smaller than your hand"]],
  ["fitsInHand", ["fit in your hand", "fit in a hand", "fit in hand", "fits in your hand", "fits in a hand", "fits in hand", "handheld", "hold it in your hand", "fit in the palm", "fit in your palm"]],
  ["inKitchen", ["kitchen"]],
  ["nearWater", ["near water", "in water", "underwater", "by water", "around water", "in or near water"]],
  ["indoors", ["indoors", "indoor", "inside a house", "inside a building", "found inside"]],
  ["outdoors", ["outdoors", "outdoor", "outside"]],
  ["transport", ["transport", "a vehicle", "get around", "used to travel", "for travel", "ride in", "ride on", "for getting around"]],
  ["communication", ["communicat", "send a message", "for talking", "used to talk", "used for talking"]],
  ["entertainment", ["entertain", "for fun", "play with", "for playing", "a hobby", "a game you play"]],
  ["tool", ["a tool", "is it a tool", "a device", "an instrument", "a utensil", "a gadget", "tool or device", "a piece of equipment"]],
  ["edible", ["can you eat", "edible", "can you drink", "do you eat", "good to eat", "safe to eat", "eat it", "drink it", "taste it", "eat or drink"]],
  ["wearable", ["wearable", "do you wear", "can you wear", "is it clothing", "clothes", "put it on", "worn on", "worn by"]],
  ["canHold", ["hold it", "can you hold", "pick it up", "carry it", "hold in your hands", "held in", "can you carry"]],
  ["metal", ["metal", "metallic", "made of metal", "made of iron", "made of steel"]],
  ["wood", ["wood", "wooden", "made of wood"]],
  ["soft", ["soft", "fluffy", "squishy", "soft to the touch"]],
  ["liquid", ["a liquid", "is it liquid", "a fluid", "is it fluid"]],
  ["givesLight", ["give off light", "gives off light", "give light", "gives light", "glow", "glows", "shine", "shines", "luminous", "light up", "lights up", "emit light", "emits light"]],
  ["makesSound", ["make a sound", "makes a sound", "make sound", "makes noise", "make noise", "a noise", "can you hear it", "audible", "is it loud"]],
  ["hasSmell", ["a smell", "smell", "a scent", "scent", "odor", "odour", "aroma", "fragran"]],
  ["color", ["a color", "a colour", "specific color", "specific colour", "colorful", "colourful", "what color", "what colour"]],
  ["movingParts", ["moving parts", "parts that move", "mechanical parts", "has parts"]],
  ["movesItself", ["move on its own", "move by itself", "moves itself", "move itself", "self-propelled", "moves on its own", "moves by itself"]],
  ["food", ["a food", "a kind of food", "is it food", "foodstuff", "a dish", "a meal", "edible food"]],
  ["hot", ["is it hot", "usually hot", "very hot", "warm to the touch", "gives off heat", "hot to the touch", "is it warm"]],
  ["cold", ["is it cold", "usually cold", "very cold", "freezing", "icy", "chilly", "cold to the touch"]],
  ["tech", ["technolog", "electronic", "digital", "a computer", "high-tech", "is it tech", "tech?"]],
  ["job", ["a job", "a profession", "an occupation", "a career", "kind of work", "for work", "a trade"]],
  ["season", ["a season", "time of year", "associated with a season"]],
  ["centuriesOld", ["centuries", "hundreds of years", "ancient", "very old", "thousands of years", "from long ago", "old invention"]],
  ["modern", ["modern", "recent invention", "invented recently", "a new invention", "recently invented", "a recent invention"]],
  ["physical", ["physical", "can you touch", "tangible", "a real object", "a solid object", "an object", "touch it", "is it an object", "a thing you can touch"]],
];

function mapProperty(question: string): string | null {
  const q = question.toLowerCase();
  for (const [prop, triggers] of PROP_MAP) {
    if (triggers.some((t) => q.includes(t))) return prop;
  }
  return null;
}

// ── flavor replies (port of OfflineKeeper.reply, English) ──────────────────────

const REPLIES: Record<Verdict, string[]> = {
  Yes: ["That's right.", "Indeed.", "Quite so.", "Yes, truly."],
  No: ["Not that.", "Afraid not.", "No, it isn't.", "Far from it."],
  "Sort of": ["It depends.", "Partly.", "In a way.", "Sort of, yes."],
};

function hash(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function flavorReply(verdict: Verdict, seed: string): string {
  const bank = REPLIES[verdict];
  return bank[hash(seed) % bank.length]!;
}

// ── public API ────────────────────────────────────────────────────────────────

export interface DeterministicAnswer {
  verdict: Verdict;
  reply: string;
}

/** The word's category, or null if untagged. */
export function categoryOf(word: string): string | null {
  return CATEGORIES[word.trim().toLowerCase()] ?? null;
}

/**
 * Answer a question deterministically, or null to defer to the LLM (unknown
 * word, unmapped question, or ambiguous verdict). Mirrors the iOS ground-truth
 * path exactly.
 */
export function deterministicAnswer(secret: string, question: string): DeterministicAnswer | null {
  const w = secret.trim().toLowerCase();
  const cat = CATEGORIES[w];
  if (!cat) return null;
  const prop = mapProperty(question);
  if (!prop) return null;
  const verdict = deterministicVerdict(w, cat, prop);
  if (!verdict) return null;
  return { verdict, reply: flavorReply(verdict, question) };
}
