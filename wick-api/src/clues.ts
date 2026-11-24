//
//  clues.ts: Wick's timed clues in live races (3.9).
//
//  Two players who both know "it's a bird" but cannot find the English word
//  used to sit stuck until the clock ran out. Now, once a race has gone a
//  minute and a half, Wick drops a clue every 20 seconds, and both players get
//  the same kind of clue at the same moment, each in the language they hunt in:
//
//    - first, one WARMER WORD: a real word about halfway between the leader's
//      best rank and the answer, so whoever is behind catches up and the
//      leader loses little. Never closer than rank WORD_FLOOR_RANK.
//    - then GEMINI CLUES (straight away if someone is already at rank
//      CLOSE_RANK or better): a ladder of four written clues that start with
//      what kind of thing it is and end almost giving it away ("I'm a big
//      bird." ... "I'm the fancy bird with the giant shiny tail fan."), without
//      ever spelling it. Simple everyday words, so a second-language player can
//      follow, with an optional line in the player's menu language under it.
//
//  Everything here is pure except writeClueLadder(), which calls the model
//  through an injectable `generate`. The hub owns the timing and the sending.
//

import type { Lang } from "./lang.js";
import { leaksSecret, noDashes, type GenerateFn, geminiGenerate } from "./keeper.js";
import { isBlockedGuess } from "./moderation.js";
import { normalizeWord } from "./room.js";

/** No clues before this much of the race has gone. */
export const CLUE_START_MS = 90_000;
/** One clue drop every this often after the start. */
export const CLUE_EVERY_MS = 20_000;
/** At most this many warmer words in one race. */
export const MAX_WORD_CLUES = 1;
/** How many written clues Gemini writes per word (the ladder). */
export const LADDER_SIZE = 4;
/** Someone at this rank or better is close: switch to written clues. */
export const CLOSE_RANK = 30;
/** A warmer word is never closer to the answer than this rank. */
export const WORD_FLOOR_RANK = 15;
/** The rank used for a player who has not landed a scored guess yet. */
export const UNKNOWN_RANK = 2000;

export type ClueKind = "word" | "hint";

/** One rung of the written-clue ladder. `help` is the same clue in the
 *  player's menu language, when that differs from the language they hunt in. */
export interface ClueLine {
  text: string;
  help?: string;
}

/** The clue drop due at `elapsedMs`, as a 0-based slot, or null when none is
 *  due. `lastSlot` is the last slot already handled (-1 before the first).
 *  Only the newest due slot is returned, so a stalled tick never fires a burst.
 *  A slot that would land at or after the cap is never due. */
export function dueSlot(elapsedMs: number, lastSlot: number, capMs: number): number | null {
  if (elapsedMs < CLUE_START_MS) return null;
  const slot = Math.floor((elapsedMs - CLUE_START_MS) / CLUE_EVERY_MS);
  if (slot <= lastSlot) return null;
  if (CLUE_START_MS + slot * CLUE_EVERY_MS >= capMs) return null;
  return slot;
}

/** Which kind of clue a drop should be. Written clues once anyone is close or
 *  the warmer words are used up; warmer words before that. Falls back to the
 *  other kind when the wanted one has nothing left. Null when both are out. */
export function pickKind(args: {
  bestRank: number;
  wordsSent: number;
  hintsSent: number;
  hintsAvailable: number;
}): ClueKind | null {
  const wordsLeft = args.wordsSent < MAX_WORD_CLUES && args.bestRank > WORD_FLOOR_RANK + 1;
  const hintsLeft = args.hintsSent < args.hintsAvailable;
  const wantHint = args.bestRank <= CLOSE_RANK || args.wordsSent >= MAX_WORD_CLUES;
  if (wantHint) return hintsLeft ? "hint" : wordsLeft ? "word" : null;
  return wordsLeft ? "word" : hintsLeft ? "hint" : null;
}

/** The rank a warmer word should have: halfway from the leader's best rank to
 *  the answer, never closer than WORD_FLOOR_RANK. */
export function targetRank(bestRank: number): number {
  return Math.max(WORD_FLOOR_RANK, Math.floor(Math.min(bestRank, UNKNOWN_RANK) / 2));
}

/** Pick a warmer word from `nearest` (closest first; index i has rank i + 2).
 *  Starts at the target rank and walks outward (colder first, then warmer but
 *  never past the floor) past words already used, blocked words, and words
 *  that name the secret. Returns the word and its rank, or null. */
export function pickWarmerWord(
  nearest: readonly string[],
  bestRank: number,
  used: ReadonlySet<string>,
  secretForms: readonly string[],
): { word: string; rank: number } | null {
  if (nearest.length === 0) return null;
  const want = targetRank(bestRank);
  const ok = (i: number): boolean => {
    const w = nearest[i];
    if (!w) return false;
    if (used.has(w)) return false;
    if (isBlockedGuess(w)) return false;
    return !secretForms.some((f) => namesSecret(w, f));
  };
  const start = Math.min(Math.max(want - 2, 0), nearest.length - 1);
  const floorIdx = WORD_FLOOR_RANK - 2;
  // Colder first: a word a bit further out still helps and gives less away.
  for (let i = start; i < nearest.length && i < start + 200; i++) if (ok(i)) return { word: nearest[i]!, rank: i + 2 };
  for (let i = start - 1; i >= floorIdx && i >= 0; i--) if (ok(i)) return { word: nearest[i]!, rank: i + 2 };
  return null;
}

/** True if `text` names the secret: the word itself or an obvious form of it.
 *  Chinese has no spaces, so there it is a plain "contains". */
export function namesSecret(text: string, secret: string): boolean {
  const s = normalizeWord(secret);
  if (!s) return false;
  if (/[㐀-鿿]/.test(s)) return text.includes(s);
  return leaksSecret(text, s);
}

/** Short words that are allowed even when the secret starts or ends with them
 *  ("pelican" ends in "can", "carpet" starts with "car" is still a giveaway,
 *  so only true filler words are here). */
const FILLER = new Set([
  "the", "and", "are", "can", "for", "you", "not", "but", "has", "had", "was", "who",
  "use", "out", "all", "one", "its", "our", "his", "her", "any", "may", "own", "too",
  "very", "have", "with", "that", "this", "from", "they", "them", "your", "when",
]);

/** True if `text` uses a piece of the secret: a word the secret starts or
 *  ends with ("nut" or "hazel" for "hazelnut"), or any 5+ letter word inside
 *  it. Compound words are easy to give away this way. */
export function usesWordPart(text: string, secret: string): boolean {
  const s = normalizeWord(secret);
  if (s.length < 5 || /[\u3400-\u9fff]/.test(s)) return false;
  const tokens = text.toLowerCase().split(/[^a-z\u00e0-\u00ff]+/).filter((t) => t.length >= 3);
  for (const t of tokens) {
    if (t === s || FILLER.has(t) || t.length > s.length - 2) continue;
    if (s.startsWith(t) || s.endsWith(t)) return true;
    if (t.length >= 5 && s.includes(t)) return true;
  }
  return false;
}

/** Text that reads like the prompt or a note about the game, not a clue. */
export function looksLikeInstructions(text: string): boolean {
  return /secret|\bword\b|\bclues?\b|never write|any form|json|rhyme|letters?\b|spell/i.test(text);
}

/** A clue line players may see: no form of the secret, no piece of it, and
 *  nothing that reads like the instructions. */
export function clueIsSafe(text: string, forms: readonly string[]): boolean {
  if (looksLikeInstructions(text)) return false;
  return !forms.some((f) => namesSecret(text, f) || usesWordPart(text, f));
}

// ── the written-clue ladder (Gemini) ─────────────────────────────────────────

const LANG_NAME: Record<string, string> = {
  en: "English",
  es: "Spanish",
  fr: "French",
  it: "Italian",
  de: "German",
  zh: "Simplified Chinese",
  ja: "Japanese",
  ko: "Korean",
  pt: "Portuguese",
  ru: "Russian",
  vi: "Vietnamese",
  ar: "Arabic",
  hi: "Hindi",
};

/** The menu languages a clue's help line can be written in. */
export function isHelpLang(x: unknown): x is string {
  return typeof x === "string" && x in LANG_NAME;
}

/** Bump when the prompt changes so saved ladders made under the old one go. */
export const CLUE_PROMPT_VERSION = "3.9-4"; // 3.9-4: no plain-text fallback, no word pieces

export function ladderInstructions(secret: string, lang: Lang, help?: string): string {
  const name = LANG_NAME[lang] ?? "English";
  const helpLine = help
    ? `\nAlso give each clue in ${LANG_NAME[help]}, for a player whose first language is ${LANG_NAME[help]}. The ${LANG_NAME[help]} line must not name the word either.`
    : "";
  const shape = help
    ? `[${Array(LADDER_SIZE).fill(`{"clue": "...", "help": "..."}`).join(", ")}]`
    : `[${Array(LADDER_SIZE).fill(`"..."`).join(", ")}]`;
  return `You write clues for a word guessing race. The secret word is "${secret}" (${name}).
Write exactly ${LADDER_SIZE} clues in ${name}, as if the thing itself is talking ("I ...").
The players have under three minutes and may know the language only a little, so the clues must be BIG, not subtle.
Clue 1 says plainly what kind of thing it is (an animal, a bird, a fruit, a vegetable, a tool, a place, a feeling, and so on).
Clue 2 gives its most famous look, feature or use.
Clue 3 is very clear: what people know it for, where you see it, what it does.
Clue 4 almost gives it away: describe it so clearly that anyone who knows the thing will name it at once.
For example, if the word were "peacock": "I'm a big bird." / "My tail feathers have blue and green eye spots." / "I spread my huge tail open like a fan to show off." / "I'm the fancy bird with the giant shiny tail fan."
Use very simple, common words that a beginner learning ${name} would know. One short sentence each, at most 14 words.
Never write the secret word, any form of it, a word that contains it, its spelling, its letters, its length, or a rhyme.
Never use a piece of the word either: for "pancake", never write pan or cake; for "hazelnut", never write hazel or nut.
Each clue is only the thing talking about itself. Do not talk about the game, the word, the player or these rules.
No em dashes, no quotation marks inside the clues, no emoji.${helpLine}
Reply with only a JSON array and nothing else: ${shape}`;
}

/** Turn the model's reply into ladder lines, dropping any that name the
 *  secret (in any of its forms) or are empty. Tolerates a ```json fence. */
export function parseLadder(raw: string, forms: readonly string[], wantHelp: boolean): ClueLine[] {
  const body = raw.replace(/^```(?:json)?\s*/i, "").replace(/\s*```\s*$/, "").trim();
  let arr = jsonArray(body);
  // An object wrapping the list ({"clues": [...]}) is fine too.
  if (!arr) {
    const obj = jsonValue(body);
    if (obj && typeof obj === "object" && !Array.isArray(obj)) {
      arr = Object.values(obj as Record<string, unknown>).find(Array.isArray) as unknown[] | undefined ?? null;
    }
  }
  // A list cut off partway: keep every clue that finished ("..." pairs, or
  // the values after "clue": / "help": in the object form).
  if (!arr && body.trimStart().startsWith("[")) {
    const objs = [...body.matchAll(/\{\s*"clue"\s*:\s*"((?:[^"\\]|\\.)*)"(?:\s*,\s*"help"\s*:\s*"((?:[^"\\]|\\.)*)")?\s*\}/g)];
    if (objs.length > 0) {
      arr = objs.map((m) => ({ clue: unescapeJson(m[1]!), ...(m[2] !== undefined ? { help: unescapeJson(m[2]) } : {}) }));
    } else {
      const strs = [...body.matchAll(/"((?:[^"\\]|\\.)*)"/g)].map((m) => unescapeJson(m[1]!));
      if (strs.length > 0) arr = strs;
    }
  }
  // Not JSON at all: no clues. Reading loose lines once showed players a
  // line of the prompt itself as a clue, so plain text is never trusted.
  if (!arr) arr = [];
  const out: ClueLine[] = [];
  for (const item of arr.slice(0, LADDER_SIZE)) {
    let text = "";
    let help: string | undefined;
    if (typeof item === "string") text = item;
    else if (item && typeof item === "object") {
      const o = item as Record<string, unknown>;
      if (typeof o.clue === "string") text = o.clue;
      if (wantHelp && typeof o.help === "string") help = o.help;
    }
    text = tidy(text);
    help = help ? tidy(help) : undefined;
    if (!text || text.length > 140) continue;
    if (!clueIsSafe(text, forms)) continue;
    if (help && (help.length > 140 || !clueIsSafe(help, forms))) help = undefined;
    out.push(help ? { text, help } : { text });
  }
  return out;
}

function unescapeJson(s: string): string {
  const v = jsonValue(`"${s}"`);
  return typeof v === "string" ? v : s;
}

function jsonValue(s: string): unknown {
  try {
    return JSON.parse(s);
  } catch {
    return undefined;
  }
}

/** The first JSON array in `s`, or null. */
function jsonArray(s: string): unknown[] | null {
  const whole = jsonValue(s);
  if (Array.isArray(whole)) return whole;
  const m = s.match(/\[[\s\S]*\]/);
  if (!m) return null;
  const inner = jsonValue(m[0]);
  return Array.isArray(inner) ? inner : null;
}

function tidy(s: string): string {
  return noDashes(
    s
      .replace(/[\u2018\u2019]/g, "'")
      .replace(/[\u201C\u201D"]/g, "")
      .replace(/\s+/g, " ")
      .trim(),
  );
}

/** How clue writing is going, for /healthz. No words, no players: counts and
 *  the last failure's reason only. */
const stats = { requested: 0, ok: 0, empty: 0, failed: 0, lastError: "" as string, lastErrorAt: 0 };
export function clueStats(): typeof stats {
  return { ...stats };
}
function noteFailure(kind: "empty" | "failed", detail: string): void {
  stats[kind]++;
  stats.lastError = `${kind}: ${detail}`.slice(0, 240);
  stats.lastErrorAt = Date.now();
  console.warn(`[clues] ladder ${kind}: ${detail.slice(0, 240)}`);
}

/** Ladders already written, keyed by word, language and help language. A
 *  failed or empty ladder is not kept, so the next race tries again. */
const ladderCache = new Map<string, Promise<ClueLine[]>>();
const LADDER_CACHE_MAX = 2000;

/** Write (or reuse) the clue ladder for a race seat. `secret` is the word in
 *  the seat's language; `secretEn` its English form, also kept out of clues.
 *  Resolves to [] when the model is unavailable. */
export function writeClueLadder(
  secret: string,
  lang: Lang,
  secretEn?: string,
  help?: string,
  generate: GenerateFn = (system, user) => geminiGenerate(system, user, 1024, 0),
): Promise<ClueLine[]> {
  const helpLang = help && help !== lang && isHelpLang(help) ? help : undefined;
  const key = `${CLUE_PROMPT_VERSION}|${lang}|${helpLang ?? ""}|${normalizeWord(secret)}`;
  const hit = ladderCache.get(key);
  if (hit) return hit;
  const forms = [secret, ...(secretEn && secretEn !== secret ? [secretEn] : [])];
  stats.requested++;
  const p = generate(ladderInstructions(secret, lang, helpLang), "Write the clues.").then((r) => {
    if ("error" in r) {
      noteFailure("failed", r.error);
      ladderCache.delete(key);
      return [] as ClueLine[];
    }
    const lines = parseLadder(r.text, forms, Boolean(helpLang));
    if (lines.length === 0) {
      // Never log the clue text: it may name the word. Its shape is enough.
      noteFailure("empty", `${lang}, ${r.text.length} chars, starts ${JSON.stringify(r.text.slice(0, 12).replace(/[a-z]/gi, "a"))}`);
      ladderCache.delete(key);
    } else {
      stats.ok++;
    }
    return lines;
  }, (e: unknown) => {
    noteFailure("failed", String(e));
    ladderCache.delete(key);
    return [] as ClueLine[];
  });
  if (ladderCache.size >= LADDER_CACHE_MAX) {
    const oldest = ladderCache.keys().next().value;
    if (oldest !== undefined) ladderCache.delete(oldest);
  }
  ladderCache.set(key, p);
  return p;
}

/** Test seam: forget every saved ladder. */
export function _clearLadders(): void {
  ladderCache.clear();
}
