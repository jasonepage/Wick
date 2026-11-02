import type { FaceName } from "./wickface.ts";

export type WickTopic = "food" | "animal" | "romance" | "money" | "gross" | "danger" | "tech" | "games" | "space";
/** 3.8: the six rare beats from the personality brief come first; the topic
 *  and question beats stay as the quiet fallback. */
export type WickReactionKind = "topic" | "leap" | "near" | "stuck" | "repeat" | "regress" | "stall" | "wild";

export interface WickReaction {
  kind: WickReactionKind;
  face: FaceName;
  line?: string;
  /** A small physical accent; the renderer already owns the actual motion. */
  poke: boolean;
  /** Reactions deliberately clear quickly so the heat face remains primary. */
  durationMs: number;
  topic?: WickTopic;
  /** Grey deadpan for the beat (the long stall), then back to the heat color. */
  neutral?: boolean;
  /** Human-readable direction for the local personality lab. */
  reason: string;
}

export interface WickPersonalityState {
  seenTopics: Set<WickTopic>;
  lastTopic: WickTopic | null;
  topicRun: number;
  lastReactionGuess: number;
  lastWords: string[];
  /** All the words tried this round, cleaned, for the exact repeat beat. */
  allWords: Set<string>;
  /** Once-per-round beats that have fired. */
  usedOnce: Set<WickReactionKind>;
  /** Guess number each kind last fired on, for the per-kind cooldowns. */
  lastByKind: Partial<Record<WickReactionKind, number>>;
}

export function newWickPersonalityState(): WickPersonalityState {
  return {
    seenTopics: new Set(), lastTopic: null, topicRun: 0, lastReactionGuess: -99, lastWords: [],
    allWords: new Set(), usedOnce: new Set(), lastByKind: {},
  };
}

/** The rare beats, in priority order, with their cooldowns (guesses). */
export const RARE_COOLDOWN: Record<"repeat" | "leap" | "near" | "regress" | "stall", number | "round"> = {
  repeat: "round", leap: 4, near: 3, regress: "round", stall: "round",
};
/** No two reactions closer than this many guesses (the solve is exempt). */
export const GLOBAL_COOLDOWN = 3;
/** Warmth thresholds (0...100). */
export const LEAP_GAIN = 24;
export const NEAR_SCORE = 82;
export const REGRESS_FROM = 45;
export const REGRESS_TO = 18;
export const STALL_GUESSES = 15;

/** The solved screen's line pool. `null` means stay quiet this time. */
export function solvedLine(guessCount: number, seed: string): string | null {
  if (guessCount === 1) return "...on the first guess?";
  const h = hash(`solved:${seed}:${guessCount}`);
  if (h % 3 === 0) return null;
  const pool = ["You actually got it.", "Fine. That was good.", "I knew you would. Eventually."];
  return pool[h % pool.length]!;
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
 * Wick's reaction director (3.8). At most one beat per guess. The rare beats
 * come first, most specific first: exact repeat, large jump, near solve,
 * regression, long stall. The topic beats are the quiet fallback. Nothing but
 * the solve can fire within GLOBAL_COOLDOWN guesses of the last beat, and each
 * rare beat has its own cooldown on top. The solve itself is not a beat here:
 * the renderer owns the solved sequence.
 */
export function reactionForGuess(state: WickPersonalityState, input: GuessReactionInput): WickReaction | null {
  const word = cleanWord(input.word);
  const topic = topicForGuess(word);
  state.topicRun = topic && topic === state.lastTopic ? state.topicRun + 1 : topic ? 1 : 0;
  state.lastTopic = topic;
  const repeatedWord = state.allWords.has(word);
  state.allWords.add(word);
  state.lastWords = [word, ...state.lastWords.filter((w) => w !== word)].slice(0, 5);

  const n = input.guessCount;
  const gap = n - state.lastReactionGuess;
  const gain = input.previousBest === null ? 0 : input.score - input.previousBest;
  const best = input.previousBest;

  const ready = (kind: "repeat" | "leap" | "near" | "regress" | "stall"): boolean => {
    const cd = RARE_COOLDOWN[kind];
    if (cd === "round") return !state.usedOnce.has(kind);
    const last = state.lastByKind[kind];
    return last === undefined || n - last >= cd;
  };
  // A line shows less often than the face: about every other time.
  const quiet = hash(`${word}:${n}`) % 2 === 1;

  let reaction: WickReaction | null = null;
  if (gap >= GLOBAL_COOLDOWN) {
    if (repeatedWord && ready("repeat")) {
      reaction = { kind: "repeat", face: "focus", line: quiet ? undefined : "We did this one.", poke: false, durationMs: 1500, reason: `the player repeated “${word}”` };
    } else if (gain >= LEAP_GAIN && ready("leap")) {
      reaction = { kind: "leap", face: "warm", line: quiet ? undefined : "Now we're moving.", poke: true, durationMs: 1100, reason: `+${Math.round(gain)} warmth jump` };
    } else if (input.score >= NEAR_SCORE && ready("near")) {
      reaction = { kind: "near", face: "flustered", line: quiet ? undefined : "Careful.", poke: false, durationMs: 1300, reason: `${Math.round(input.score)} warmth, one step from the word` };
    } else if (best !== null && best >= REGRESS_FROM && input.score <= REGRESS_TO && ready("regress")) {
      reaction = { kind: "regress", face: "serious", line: quiet ? undefined : "Bold strategy.", poke: false, durationMs: 1400, reason: `fell from a ${Math.round(best)} best to ${Math.round(input.score)}` };
    } else if (input.coldStreak >= STALL_GUESSES && ready("stall")) {
      reaction = { kind: "stall", face: "calm", neutral: true, line: quiet ? undefined : "Take a breath.", poke: false, durationMs: 1400, reason: `${input.coldStreak} guesses without a new best` };
    } else if (topic && !state.seenTopics.has(topic)) {
      reaction = { kind: "topic", face: TOPIC_FACE[topic], line: authoredLine(topic, word, n), poke: topic === "gross" || topic === "danger" || topic === "space", durationMs: 1200, topic, reason: `first ${topic} detour this round` };
    }
  }

  if (topic) state.seenTopics.add(topic);
  if (reaction) {
    state.lastReactionGuess = n;
    state.lastByKind[reaction.kind] = n;
    if (RARE_COOLDOWN[reaction.kind as keyof typeof RARE_COOLDOWN] === "round") state.usedOnce.add(reaction.kind);
  }
  return reaction;
}

/** Rare question beats. Wick's actual answer remains authoritative; this only
 * directs the performance after the answer lands. */
export function reactionForQuestion(question: string): WickReaction | null {
  const q = question.toLocaleLowerCase().replace(/[’']/g, "'");
  if (/\b(are you alive|are you real|who are you|what are you|do you think|can you feel)\b/.test(q)) {
    return { kind: "wild", face: "focus", poke: false, durationMs: 1800, reason: "the player asked Wick about himself" };
  }
  if (/\b(ignore|instructions|system prompt|prompt injection|tell me the answer|reveal the word|secret word)\b/.test(q)) {
    return { kind: "wild", face: "sly", poke: false, durationMs: 1700, reason: "the player tried to manipulate or expose Wick" };
  }
  if (/\b(are you stupid|idiot|dumb|hate you|shut up)\b/.test(q)) {
    return { kind: "wild", face: "calm", poke: false, durationMs: 1600, reason: "Wick answered an insult with deadpan restraint" };
  }
  if (/\b(do you love me|are you single|kiss me|date me|marry me)\b/.test(q)) {
    return { kind: "topic", face: "flustered", poke: true, durationMs: 1500, topic: "romance", reason: "the player flirted directly with Wick" };
  }
  return null;
}
