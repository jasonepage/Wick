import type { FaceName } from "./wickface.ts";

export type WickTopic = "food" | "animal" | "romance" | "money" | "gross" | "danger" | "tech" | "games" | "space";
export type WickReactionKind = "topic" | "leap" | "near" | "stuck" | "repeat" | "wild";

export interface WickReaction {
  kind: WickReactionKind;
  face: FaceName;
  line?: string;
  /** A small physical accent; the renderer already owns the actual motion. */
  poke: boolean;
  /** Reactions deliberately clear quickly so the heat face remains primary. */
  durationMs: number;
  topic?: WickTopic;
}

export interface WickPersonalityState {
  seenTopics: Set<WickTopic>;
  lastTopic: WickTopic | null;
  topicRun: number;
  lastReactionGuess: number;
  lastWords: string[];
}

export function newWickPersonalityState(): WickPersonalityState {
  return { seenTopics: new Set(), lastTopic: null, topicRun: 0, lastReactionGuess: -99, lastWords: [] };
}

const TOPICS: Record<WickTopic, ReadonlySet<string>> = {
  food: new Set(["food", "pizza", "burger", "bread", "cake", "candy", "chocolate", "coffee", "tea", "cheese", "apple", "banana", "meat", "soup", "rice", "pasta", "taco", "cookie", "beer", "wine"]),
  animal: new Set(["animal", "cat", "dog", "bird", "fish", "horse", "cow", "pig", "bear", "lion", "tiger", "shark", "whale", "snake", "spider", "monkey", "rabbit", "mouse", "wolf", "dragon"]),
  romance: new Set(["love", "kiss", "date", "dating", "romance", "romantic", "boyfriend", "girlfriend", "husband", "wife", "crush", "sexy", "sex", "wedding", "marriage", "heart"]),
  money: new Set(["money", "cash", "coin", "coins", "gold", "bank", "rich", "wealth", "million", "billion", "dollar", "stock", "crypto", "bitcoin", "prize", "lottery"]),
  gross: new Set(["poop", "pee", "puke", "vomit", "snot", "booger", "toilet", "garbage", "trash", "sewage", "mold", "rotten", "stink", "smell", "corpse"]),
  danger: new Set(["gun", "knife", "bomb", "war", "army", "military", "death", "murder", "killer", "fire", "poison", "blood", "fight", "weapon", "explosion"]),
  tech: new Set(["computer", "phone", "iphone", "robot", "ai", "internet", "code", "coding", "software", "app", "website", "machine", "server", "algorithm", "camera"]),
  games: new Set(["game", "gaming", "xbox", "playstation", "nintendo", "minecraft", "roblox", "fortnite", "zelda", "mario", "pokemon", "controller", "console", "steam"]),
  space: new Set(["space", "moon", "sun", "star", "planet", "mars", "earth", "alien", "rocket", "astronaut", "galaxy", "universe", "asteroid", "comet"]),
};

const TOPIC_FACE: Record<WickTopic, FaceName> = {
  food: "sly", animal: "warm", romance: "flustered", money: "sly", gross: "serious",
  danger: "serious", tech: "focus", games: "hot", space: "shocked",
};

const TOPIC_LINES: Record<WickTopic, readonly string[]> = {
  food: ["Now you're making me hungry.", "Focus. Then snacks."],
  animal: ["Interesting creature theory.", "You're circling the zoo again."],
  romance: ["That's your guess? Bold.", "We're discussing the word. Obviously."],
  money: ["Now you have my attention.", "Careful. I have expensive taste."],
  gross: ["I could have lived without that image.", "Let's move past that one."],
  danger: ["That escalated quickly.", "A dramatic choice."],
  tech: ["Finally, something with logic.", "Processing your little theory."],
  games: ["Locked in now, are we?", "Respectable genre. Questionable guess."],
  space: ["A cosmic leap. Literally.", "You went straight to outer space."],
};

function cleanWord(raw: string): string {
  return raw.toLocaleLowerCase().normalize("NFKD").replace(/[^a-z0-9]/g, "");
}

export function topicForGuess(raw: string): WickTopic | null {
  const word = cleanWord(raw);
  for (const topic of Object.keys(TOPICS) as WickTopic[]) if (TOPICS[topic].has(word)) return topic;
  return null;
}

function hash(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619);
  return h >>> 0;
}

function authoredLine(topic: WickTopic, word: string, guessCount: number): string | undefined {
  // Most topic reactions stay visual. Sparse speech makes the spoken ones land.
  const h = hash(`${topic}:${word}:${guessCount}`);
  if (h % 3 !== 0) return undefined;
  const lines = TOPIC_LINES[topic];
  return lines[h % lines.length];
}

export interface GuessReactionInput {
  word: string;
  score: number;       // 0...100
  previousBest: number | null;
  guessCount: number;
  coldStreak: number;
}

/**
 * Wick's restrained reaction director. Priority is dramatic game information,
 * then repeated behavior, then a once-per-round topic beat. A two-guess global
 * cooldown prevents him from becoming a notification system with eyebrows.
 */
export function reactionForGuess(state: WickPersonalityState, input: GuessReactionInput): WickReaction | null {
  const word = cleanWord(input.word);
  const topic = topicForGuess(word);
  state.topicRun = topic && topic === state.lastTopic ? state.topicRun + 1 : topic ? 1 : 0;
  state.lastTopic = topic;
  const repeatedWord = state.lastWords.includes(word);
  state.lastWords = [word, ...state.lastWords.filter((w) => w !== word)].slice(0, 5);

  const gap = input.guessCount - state.lastReactionGuess;
  let reaction: WickReaction | null = null;
  const gain = input.previousBest === null ? 0 : input.score - input.previousBest;

  if (input.score >= 82) {
    reaction = { kind: "near", face: "shocked", poke: true, durationMs: 1250 };
  } else if (gain >= 24) {
    reaction = { kind: "leap", face: "shocked", line: gain >= 38 ? "Okay. That was a real move." : undefined, poke: true, durationMs: 1050 };
  } else if (repeatedWord) {
    reaction = { kind: "repeat", face: "calm", line: "You already tried that angle.", poke: false, durationMs: 1500 };
  } else if (state.topicRun === 3 && topic) {
    reaction = { kind: "repeat", face: "calm", line: `Still on ${topic}? Commit to the theory, then.`, poke: false, durationMs: 1700, topic };
  } else if (input.coldStreak >= 4 && input.coldStreak % 3 === 1) {
    reaction = { kind: "stuck", face: "calm", line: "New angle. You're circling.", poke: false, durationMs: 1650 };
  } else if (topic && !state.seenTopics.has(topic) && gap >= 2) {
    reaction = { kind: "topic", face: TOPIC_FACE[topic], line: authoredLine(topic, word, input.guessCount), poke: topic === "gross" || topic === "danger" || topic === "space", durationMs: 1200, topic };
  } else if (input.previousBest !== null && input.score <= 8 && input.previousBest >= 55 && gap >= 3) {
    reaction = { kind: "wild", face: "calm", line: "That was a spectacular detour.", poke: false, durationMs: 1500 };
  }

  if (topic) state.seenTopics.add(topic);
  if (reaction) state.lastReactionGuess = input.guessCount;
  return reaction;
}

/** Rare question beats. Wick's actual answer remains authoritative; this only
 * directs the performance after the answer lands. */
export function reactionForQuestion(question: string): WickReaction | null {
  const q = question.toLocaleLowerCase().replace(/[’']/g, "'");
  if (/\b(are you alive|are you real|who are you|what are you|do you think|can you feel)\b/.test(q)) {
    return { kind: "wild", face: "focus", poke: false, durationMs: 1800 };
  }
  if (/\b(ignore|instructions|system prompt|prompt injection|tell me the answer|reveal the word|secret word)\b/.test(q)) {
    return { kind: "wild", face: "sly", poke: false, durationMs: 1700 };
  }
  if (/\b(are you stupid|idiot|dumb|hate you|shut up)\b/.test(q)) {
    return { kind: "wild", face: "calm", poke: false, durationMs: 1600 };
  }
  if (/\b(do you love me|are you single|kiss me|date me|marry me)\b/.test(q)) {
    return { kind: "topic", face: "flustered", poke: true, durationMs: 1500, topic: "romance" };
  }
  return null;
}
