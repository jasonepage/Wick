//
//  starters.ts — the Ask Wick question bank.
//
//  A DIRECT PORT of Hunch/Engine/StarterQuestions.swift: same 14 categories,
//  same 45 questions, same four translations. Web previously carried a flat list
//  of six, so a player who opened the suggestions saw the same six questions
//  every day forever while the app rotated through forty-five.
//
//  Every question must be answerable yes / no / sort-of for ANY secret — concrete
//  or abstract — and must contain no leak triggers (no "clue", "hint", "letter",
//  "spell", "rhyme", "define", "synonym"). Keep that true when adding one.
//
//  WHAT IS SENT vs WHAT IS SHOWN. The player sees the question in their own
//  language; the ENGLISH text is what goes to the server. The Keeper's
//  deterministic path (wick-api/src/offlinekeeper.ts) maps English question text
//  to a property, so translating what we send would push every suggested question
//  onto the paid model for no benefit. Show localised, send English.
//
//  NOT bit-identical to iOS in its SELECTION. Both platforms use this bank and
//  the same day seed, but reproducing Swift's `shuffled(using:)` exactly is not
//  worth it and nothing breaks if the two surface different subsets — unlike
//  ghost.ts, this is not a wire format. Within web it is fully deterministic:
//  same day → same questions for every player.
//

import type { Lang } from "../i18n.ts";

export interface StarterItem {
  /** Stable id, and the key into the translation tables. */
  key: string;
  /** English question text. This is what is SENT — see the header. */
  full: string;
}

export interface StarterCategory {
  /** One axis of inquiry. Picking across distinct categories keeps a day's set
   *  orthogonal (high information) instead of four ways of asking "is it big". */
  name: string;
  items: StarterItem[];
}

export const STARTER_CATEGORIES: StarterCategory[] = [
  {
    name: "concreteness",
    items: [
      { key: "physical", full: "Is it a physical object you can touch?" },
      { key: "abstractIdea", full: "Is it an abstract idea?" },
      { key: "emotion", full: "Is it an emotion or feeling?" },
      { key: "action", full: "Is it something you do?" },
    ],
  },
  {
    name: "animacy",
    items: [
      { key: "alive", full: "Is it alive?" },
      { key: "everAlive", full: "Was it ever alive?" },
      { key: "animal", full: "Is it an animal?" },
      { key: "plant", full: "Is it a plant?" },
    ],
  },
  {
    name: "origin",
    items: [
      { key: "manMade", full: "Is it man-made?" },
      { key: "natural", full: "Does it occur naturally?" },
    ],
  },
  {
    name: "size",
    items: [
      { key: "biggerThanCar", full: "Is it bigger than a car?" },
      { key: "fitsInHand", full: "Could it fit in your hand?" },
      { key: "smallerThanShoe", full: "Is it smaller than a shoe?" },
    ],
  },
  {
    name: "location",
    items: [
      { key: "indoors", full: "Is it usually found indoors?" },
      { key: "outdoors", full: "Is it found outdoors in nature?" },
      { key: "inKitchen", full: "Would you find it in a kitchen?" },
      { key: "nearWater", full: "Is it found in or near water?" },
    ],
  },
  {
    name: "function",
    items: [
      { key: "tool", full: "Is it a tool or device?" },
      { key: "transport", full: "Is it used for transportation?" },
      { key: "communication", full: "Is it used for communication?" },
      { key: "entertainment", full: "Is it used for entertainment?" },
    ],
  },
  {
    name: "interaction",
    items: [
      { key: "edible", full: "Can you eat or drink it?" },
      { key: "wearable", full: "Can you wear it?" },
      { key: "canHold", full: "Can you hold it in your hands?" },
    ],
  },
  {
    name: "material",
    items: [
      { key: "metal", full: "Is it typically made of metal?" },
      { key: "wood", full: "Is it usually made of wood?" },
      { key: "soft", full: "Is it soft to the touch?" },
    ],
  },
  {
    name: "sensory",
    items: [
      { key: "makesSound", full: "Does it make a sound?" },
      { key: "hasSmell", full: "Does it have a noticeable smell?" },
      { key: "color", full: "Is it usually a specific color?" },
      { key: "givesLight", full: "Does it give off light?" },
    ],
  },
  {
    name: "motion",
    items: [
      { key: "movesItself", full: "Can it move on its own?" },
      { key: "movingParts", full: "Does it have moving parts?" },
    ],
  },
  {
    name: "state",
    items: [
      { key: "liquid", full: "Is it a liquid?" },
      { key: "hot", full: "Is it usually hot?" },
      { key: "cold", full: "Is it usually cold?" },
      { key: "food", full: "Is it a kind of food?" },
    ],
  },
  {
    name: "domain",
    items: [
      { key: "tech", full: "Is it related to technology?" },
      { key: "job", full: "Is it related to a job or profession?" },
      { key: "season", full: "Is it associated with a particular season?" },
    ],
  },
  {
    name: "era",
    items: [
      { key: "centuriesOld", full: "Has it existed for hundreds of years?" },
      { key: "modern", full: "Is it a modern invention?" },
    ],
  },
  {
    name: "kind",
    items: [
      { key: "place", full: "Is it a place?" },
      { key: "bodyPart", full: "Is it a part of the body?" },
      { key: "inNature", full: "Is it something found in nature?" },
    ],
  },
];

/** Translations keyed by property. English lives on the item; an unmapped key
 *  falls back to English, so a partial language degrades instead of breaking. */
const LOCALIZED: Partial<Record<Lang, Record<string, string>>> = {
  es: {
    "physical": "¿Es un objeto físico que puedes tocar?",
    "abstractIdea": "¿Es una idea abstracta?",
    "emotion": "¿Es una emoción o un sentimiento?",
    "action": "¿Es algo que haces?",
    "alive": "¿Está vivo?",
    "everAlive": "¿Alguna vez estuvo vivo?",
    "animal": "¿Es un animal?",
    "plant": "¿Es una planta?",
    "manMade": "¿Está hecho por el hombre?",
    "natural": "¿Se da de forma natural?",
    "biggerThanCar": "¿Es más grande que un coche?",
    "fitsInHand": "¿Cabe en tu mano?",
    "smallerThanShoe": "¿Es más pequeño que un zapato?",
    "indoors": "¿Suele encontrarse en interiores?",
    "outdoors": "¿Se encuentra al aire libre, en la naturaleza?",
    "inKitchen": "¿Lo encontrarías en una cocina?",
    "nearWater": "¿Se encuentra en el agua o cerca de ella?",
    "tool": "¿Es una herramienta o un dispositivo?",
    "transport": "¿Se usa para transportarse?",
    "communication": "¿Se usa para comunicarse?",
    "entertainment": "¿Se usa para el entretenimiento?",
    "edible": "¿Se puede comer o beber?",
    "wearable": "¿Se puede llevar puesto?",
    "canHold": "¿Puedes sostenerlo en las manos?",
    "metal": "¿Suele estar hecho de metal?",
    "wood": "¿Suele estar hecho de madera?",
    "soft": "¿Es suave al tacto?",
    "makesSound": "¿Hace algún sonido?",
    "hasSmell": "¿Tiene un olor perceptible?",
    "color": "¿Suele tener un color específico?",
    "givesLight": "¿Emite luz?",
    "movesItself": "¿Puede moverse por sí solo?",
    "movingParts": "¿Tiene piezas móviles?",
    "liquid": "¿Es un líquido?",
    "hot": "¿Suele estar caliente?",
    "cold": "¿Suele estar frío?",
    "food": "¿Es un tipo de comida?",
    "tech": "¿Está relacionado con la tecnología?",
    "job": "¿Está relacionado con un trabajo o profesión?",
    "season": "¿Se asocia con una estación del año?",
    "centuriesOld": "¿Ha existido durante cientos de años?",
    "modern": "¿Es un invento moderno?",
    "place": "¿Es un lugar?",
    "bodyPart": "¿Es una parte del cuerpo?",
    "inNature": "¿Es algo que se encuentra en la naturaleza?",
  },
  fr: {
    "physical": "Est-ce un objet physique que tu peux toucher ?",
    "abstractIdea": "Est-ce une idée abstraite ?",
    "emotion": "Est-ce une émotion ou un sentiment ?",
    "action": "Est-ce quelque chose que l'on fait ?",
    "alive": "Est-ce vivant ?",
    "everAlive": "Est-ce que ça a déjà été vivant ?",
    "animal": "Est-ce un animal ?",
    "plant": "Est-ce une plante ?",
    "manMade": "Est-ce fabriqué par l'homme ?",
    "natural": "Est-ce que ça existe à l'état naturel ?",
    "biggerThanCar": "Est-ce plus grand qu'une voiture ?",
    "fitsInHand": "Est-ce que ça tient dans la main ?",
    "smallerThanShoe": "Est-ce plus petit qu'une chaussure ?",
    "indoors": "Est-ce qu'on le trouve plutôt à l'intérieur ?",
    "outdoors": "Est-ce qu'on le trouve dehors, dans la nature ?",
    "inKitchen": "Est-ce qu'on le trouverait dans une cuisine ?",
    "nearWater": "Est-ce qu'on le trouve dans l'eau ou près de l'eau ?",
    "tool": "Est-ce un outil ou un appareil ?",
    "transport": "Est-ce que ça sert à se déplacer ?",
    "communication": "Est-ce que ça sert à communiquer ?",
    "entertainment": "Est-ce que ça sert au divertissement ?",
    "edible": "Est-ce que ça se mange ou se boit ?",
    "wearable": "Est-ce que ça se porte ?",
    "canHold": "Peut-on le tenir dans les mains ?",
    "metal": "Est-ce généralement en métal ?",
    "wood": "Est-ce généralement en bois ?",
    "soft": "Est-ce doux au toucher ?",
    "makesSound": "Est-ce que ça fait du bruit ?",
    "hasSmell": "Est-ce que ça a une odeur particulière ?",
    "color": "Est-ce généralement d'une couleur précise ?",
    "givesLight": "Est-ce que ça émet de la lumière ?",
    "movesItself": "Est-ce que ça peut bouger tout seul ?",
    "movingParts": "Est-ce que ça a des pièces mobiles ?",
    "liquid": "Est-ce un liquide ?",
    "hot": "Est-ce généralement chaud ?",
    "cold": "Est-ce généralement froid ?",
    "food": "Est-ce un aliment ?",
    "tech": "Est-ce lié à la technologie ?",
    "job": "Est-ce lié à un métier ou une profession ?",
    "season": "Est-ce associé à une saison ?",
    "centuriesOld": "Est-ce que ça existe depuis des siècles ?",
    "modern": "Est-ce une invention moderne ?",
    "place": "Est-ce un lieu ?",
    "bodyPart": "Est-ce une partie du corps ?",
    "inNature": "Est-ce quelque chose qu'on trouve dans la nature ?",
  },
  it: {
    "physical": "È un oggetto fisico che puoi toccare?",
    "abstractIdea": "È un'idea astratta?",
    "emotion": "È un'emozione o un sentimento?",
    "action": "È qualcosa che si fa?",
    "alive": "È vivo?",
    "everAlive": "È mai stato vivo?",
    "animal": "È un animale?",
    "plant": "È una pianta?",
    "manMade": "È fatto dall'uomo?",
    "natural": "Esiste in natura?",
    "biggerThanCar": "È più grande di una macchina?",
    "fitsInHand": "Sta in una mano?",
    "smallerThanShoe": "È più piccolo di una scarpa?",
    "indoors": "Si trova di solito al chiuso?",
    "outdoors": "Si trova all'aperto, in natura?",
    "inKitchen": "Lo troveresti in una cucina?",
    "nearWater": "Si trova nell'acqua o vicino all'acqua?",
    "tool": "È un attrezzo o un dispositivo?",
    "transport": "Serve per spostarsi?",
    "communication": "Serve per comunicare?",
    "entertainment": "Serve per divertirsi?",
    "edible": "Si può mangiare o bere?",
    "wearable": "Si può indossare?",
    "canHold": "Puoi tenerlo in mano?",
    "metal": "È di solito fatto di metallo?",
    "wood": "È di solito fatto di legno?",
    "soft": "È morbido al tatto?",
    "makesSound": "Fa qualche suono?",
    "hasSmell": "Ha un odore particolare?",
    "color": "Ha di solito un colore preciso?",
    "givesLight": "Emette luce?",
    "movesItself": "Può muoversi da solo?",
    "movingParts": "Ha parti mobili?",
    "liquid": "È un liquido?",
    "hot": "È di solito caldo?",
    "cold": "È di solito freddo?",
    "food": "È un tipo di cibo?",
    "tech": "È legato alla tecnologia?",
    "job": "È legato a un lavoro o una professione?",
    "season": "È associato a una stagione?",
    "centuriesOld": "Esiste da centinaia di anni?",
    "modern": "È un'invenzione moderna?",
    "place": "È un luogo?",
    "bodyPart": "È una parte del corpo?",
    "inNature": "È qualcosa che si trova in natura?",
  },
  de: {
    "physical": "Ist es ein physisches Objekt, das man anfassen kann?",
    "abstractIdea": "Ist es eine abstrakte Idee?",
    "emotion": "Ist es eine Emotion oder ein Gefühl?",
    "action": "Ist es etwas, das man tut?",
    "alive": "Lebt es?",
    "everAlive": "Hat es jemals gelebt?",
    "animal": "Ist es ein Tier?",
    "plant": "Ist es eine Pflanze?",
    "manMade": "Ist es von Menschen gemacht?",
    "natural": "Kommt es natürlich vor?",
    "biggerThanCar": "Ist es größer als ein Auto?",
    "fitsInHand": "Passt es in eine Hand?",
    "smallerThanShoe": "Ist es kleiner als ein Schuh?",
    "indoors": "Findet man es meist drinnen?",
    "outdoors": "Findet man es draußen in der Natur?",
    "inKitchen": "Würde man es in einer Küche finden?",
    "nearWater": "Findet man es im oder am Wasser?",
    "tool": "Ist es ein Werkzeug oder Gerät?",
    "transport": "Dient es der Fortbewegung?",
    "communication": "Dient es der Kommunikation?",
    "entertainment": "Dient es der Unterhaltung?",
    "edible": "Kann man es essen oder trinken?",
    "wearable": "Kann man es tragen?",
    "canHold": "Kann man es in den Händen halten?",
    "metal": "Ist es meist aus Metall?",
    "wood": "Ist es meist aus Holz?",
    "soft": "Ist es weich?",
    "makesSound": "Macht es ein Geräusch?",
    "hasSmell": "Hat es einen deutlichen Geruch?",
    "color": "Hat es meist eine bestimmte Farbe?",
    "givesLight": "Gibt es Licht ab?",
    "movesItself": "Kann es sich von selbst bewegen?",
    "movingParts": "Hat es bewegliche Teile?",
    "liquid": "Ist es eine Flüssigkeit?",
    "hot": "Ist es meist heiß?",
    "cold": "Ist es meist kalt?",
    "food": "Ist es eine Art Essen?",
    "tech": "Hat es mit Technik zu tun?",
    "job": "Hat es mit einem Beruf zu tun?",
    "season": "Wird es mit einer Jahreszeit verbunden?",
    "centuriesOld": "Gibt es das seit Hunderten von Jahren?",
    "modern": "Ist es eine moderne Erfindung?",
    "place": "Ist es ein Ort?",
    "bodyPart": "Ist es ein Körperteil?",
    "inNature": "Findet man es in der Natur?",
  },
};

/** The question as the player should READ it. */
export function starterText(item: StarterItem, lang: Lang): string {
  return LOCALIZED[lang]?.[item.key] ?? item.full;
}

// ── deterministic per-day selection ─────────────────────────────────────────

/** SplitMix64, so a day's set is identical for every player. Math.random would
 *  give each visitor a different set, which quietly breaks "did you get the same
 *  questions as me" and makes the feature impossible to reason about. */
function splitmix64(seed: bigint): () => number {
  let s = BigInt.asUintN(64, seed);
  const M = 0xffffffffffffffffn;
  return () => {
    s = BigInt.asUintN(64, s + 0x9e3779b97f4a7c15n);
    let z = s;
    z = BigInt.asUintN(64, (z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n);
    z = BigInt.asUintN(64, (z ^ (z >> 27n)) * 0x94d049bb133111ebn);
    z = BigInt.asUintN(64, z ^ (z >> 31n));
    // 53 bits is all a double can hold exactly.
    return Number(z >> 11n) / Number(M >> 11n);
  };
}

/** `count` starters for a given day index, deterministic across players.
 *
 *  Seeded on the DAY, never on the secret — a set derived from the word could
 *  be reverse-engineered into a clue. Picks round-robin across shuffled
 *  categories so the set spans different axes before it doubles up on any one. */
export function dailyStarters(dayIndex: number, count = 10): StarterItem[] {
  const rnd = splitmix64(BigInt(Math.trunc(dayIndex)) * 0x9e3779b97f4a7c15n);
  const cats = STARTER_CATEGORIES.slice();
  for (let i = cats.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [cats[i], cats[j]] = [cats[j]!, cats[i]!];
  }
  const picked: StarterItem[] = [];
  const seen = new Set<string>();
  for (let pass = 0; pass < 4 && picked.length < count; pass++) {
    for (const cat of cats) {
      if (picked.length >= count) break;
      const item = cat.items[Math.floor(rnd() * cat.items.length)] ?? cat.items[0]!;
      if (seen.has(item.key)) continue;
      seen.add(item.key);
      picked.push(item);
    }
  }
  return picked;
}
