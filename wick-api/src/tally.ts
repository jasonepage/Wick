// SPDX-License-Identifier: MPL-2.0
//
//  tally.ts: this week's most guessed words and most asked Keeper questions,
//  across every player (3.6, the Stats page).
//
//  What comes in: a guessed word or a yes/no question, its language, and
//  (from the app) when it was played. Nothing else. No player id, no IP
//  address and no device token is ever stored or returned.
//
//  Where it comes from:
//    - web solo: POST /warmth and POST /keeper already carry the text
//    - live races (iOS and web): the hub's guess and ask frames
//    - iOS solo: POST /tally, sent by the app (it scores on the phone, so the
//      server would never see those words otherwise)
//
//  Spoilers. Everyone plays the same daily, so a plain "most guessed" list
//  fills up with words close to the day's answer. Callers that know the heat
//  only pass guesses that read Cool or colder (rank above 400, or a score
//  under 30 when there is no rank), never the solving word, and never a
//  question that names the answer. The iOS app applies the same rule before
//  it sends anything.
//
//  Privacy on free text. A question is shown only once it has come from at
//  least MIN_COUNT different senders this week, so one person's odd question
//  never shows up on everyone's Stats page. "Different senders" is checked
//  with a salted hash kept in memory only: the salt is random per process,
//  the hashes are never written to disk or returned, and they are thrown away
//  at the weekly reset or on restart. Questions with digits, links or email
//  addresses are dropped, and so is anything with a slur or a crude word.
//
//  The week starts Monday 00:00 UTC. Counts live in memory and, with a data
//  folder (WICK_DATA_DIR, the Render disk), in one small JSON file there so a
//  deploy does not wipe the week. Only questions that already clear the show
//  line are written to that file; the rest stay in memory.
//

import { createHash, randomBytes } from "node:crypto";
import { readFileSync, writeFileSync, mkdirSync, renameSync } from "node:fs";
import { dirname } from "node:path";
import { type Lang, LANGS, isLang } from "./lang.js";
import { isBlockedSecret } from "./moderation.js";

export type TallyKind = "guess" | "question";

/** A word must reach this many senders before it is shown. */
export const MIN_COUNT = 3;
/** How many rows each list returns. */
export const TOP_N = 10;
/** Rank cutoff for "cool or colder" (the Warm band ends at rank 400; see
 *  HunchTheme.rankLabel and warmthservice's R_WARM). */
export const COLD_RANK = 400;
/** Score cutoff when there is no rank (the Warm band starts at 30). */
export const COLD_SCORE = 30;

const MAX_KEYS_PER_LIST = 20_000;
const MAX_SEEN = 500_000;
const DAY_MS = 86_400_000;

/** Monday 00:00 UTC of the week holding `ms`. */
export function weekStartUtc(ms: number): number {
  const d = new Date(ms);
  const midnight = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
  const sinceMonday = (d.getUTCDay() + 6) % 7;
  return midnight - sinceMonday * DAY_MS;
}

/** True when a scored guess is cold enough to show without hinting at the answer. */
export function isColdEnough(r: { score: number | null | undefined; rank?: number | null }): boolean {
  if (typeof r.rank === "number" && r.rank > 0) return r.rank > COLD_RANK;
  return typeof r.score === "number" && r.score < COLD_SCORE;
}

/** Lowercased single word, or null when it is not a plain word or is crude. */
export function normalizeGuess(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const w = raw.trim().toLowerCase();
  if (!/^\p{L}[\p{L}\p{M}'\-]{0,31}$/u.test(w)) return null;
  if (isBlockedSecret(w)) return null;
  return w;
}

/** The canonical form of a question (lowercase, single spaces, no outer
 *  punctuation), or null when it should never be counted. */
export function normalizeQuestion(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const q = raw
    .toLowerCase()
    .replace(/\s+/gu, " ")
    .replace(/^[\s\p{P}\p{S}]+|[\s\p{P}\p{S}]+$/gu, "");
  if (q.length < 3 || q.length > 100) return null;
  if (/\d{3,}/.test(q)) return null;                       // phone numbers, codes
  if (/@|https?:|www\.|\.(com|net|org|io|app)\b/.test(q)) return null; // emails, links
  const words = q.split(/[^\p{L}\p{M}'0-9]+/u).filter(Boolean);
  if (words.length === 0 || words.length > 15) return null;
  if (words.some((w) => isBlockedSecret(w))) return null;
  return q;
}

/** How a counted question is shown: first letter up, a question mark on the end. */
export function displayQuestion(norm: string): string {
  const first = norm.charAt(0).toLocaleUpperCase();
  return `${first}${norm.slice(1)}?`;
}

/** Does `text` name any of `secrets`, as a word or the start of one ("cats"
 *  for "cat")? Mirrors WordTallyRules.namesAnswer in the iOS app. */
export function mentionsSecret(text: string, secrets: (string | undefined)[]): boolean {
  const words = text.toLowerCase().split(/[^\p{L}\p{M}'0-9]+/u).filter(Boolean);
  for (const s of secrets) {
    const t = s?.trim().toLowerCase();
    if (!t) continue;
    if (words.some((w) => w === t || (t.length >= 3 && w.startsWith(t)))) return true;
    // A multi-word or non-spaced secret (Chinese): plain substring.
    if ((/\s/.test(t) || !/^[\p{Script=Latin}'\-]+$/u.test(t)) && text.toLowerCase().includes(t)) return true;
  }
  return false;
}

export interface TallyRow { text: string; count: number }

export interface WeeklySnapshot {
  /** Monday the week started, as YYYY-MM-DD (UTC). */
  week: string;
  /** When the lists reset, ISO 8601. */
  resetsAt: string;
  lang: Lang;
  guesses: TallyRow[];
  questions: TallyRow[];
}

type Lists = Record<TallyKind, Map<Lang, Map<string, number>>>;

function emptyLists(): Lists {
  return { guess: new Map(), question: new Map() };
}

export class WeeklyTally {
  private week: number;
  private lists: Lists = emptyLists();
  private seen = new Set<string>();
  private readonly salt = randomBytes(16).toString("hex");
  private file: string | null = null;
  private saveTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(private readonly now: () => number, private readonly minCount = MIN_COUNT) {
    this.week = weekStartUtc(now());
  }

  /** Start a new week when Monday has passed. */
  private roll(): void {
    const w = weekStartUtc(this.now());
    if (w === this.week) return;
    this.week = w;
    this.lists = emptyLists();
    this.seen.clear();
    this.scheduleSave();
  }

  /**
   * Count one guess or question. `source` (an IP or a race player id) is used
   * only to count each sender once per item per week; it is hashed with a
   * per-process salt and never stored on disk. `at` (epoch ms) lets a late
   * sender's item from last week be dropped instead of landing in this one.
   * Returns true when the item was counted.
   */
  add(kind: TallyKind, raw: unknown, lang: unknown, opts: { source?: string; at?: number } = {}): boolean {
    this.roll();
    if (!isLang(lang)) return false;
    if (typeof opts.at === "number" && Number.isFinite(opts.at) && opts.at < this.week) return false;
    const key = kind === "guess" ? normalizeGuess(raw) : normalizeQuestion(raw);
    if (!key) return false;

    if (opts.source) {
      const h = createHash("sha256")
        .update(`${this.salt}|${this.week}|${kind}|${lang}|${key}|${opts.source}`)
        .digest("hex")
        .slice(0, 16);
      if (this.seen.has(h)) return false;
      if (this.seen.size < MAX_SEEN) this.seen.add(h);
    }

    let list = this.lists[kind].get(lang);
    if (!list) { list = new Map(); this.lists[kind].set(lang, list); }
    if (!list.has(key) && list.size >= MAX_KEYS_PER_LIST) {
      // Make room by dropping the one-offs; they can never be shown anyway.
      for (const [k, n] of list) if (n <= 1) list.delete(k);
      if (list.size >= MAX_KEYS_PER_LIST) return false;
    }
    list.set(key, (list.get(key) ?? 0) + 1);
    this.scheduleSave();
    return true;
  }

  private top(kind: TallyKind, lang: Lang, n: number): TallyRow[] {
    const list = this.lists[kind].get(lang);
    if (!list) return [];
    return [...list]
      .filter(([, c]) => c >= this.minCount)
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .slice(0, n)
      .map(([k, count]) => ({ text: kind === "question" ? displayQuestion(k) : k, count }));
  }

  /** This week's lists for one language. Counts only. */
  snapshot(lang: Lang, n = TOP_N): WeeklySnapshot {
    this.roll();
    return {
      week: new Date(this.week).toISOString().slice(0, 10),
      resetsAt: new Date(this.week + 7 * DAY_MS).toISOString(),
      lang,
      guesses: this.top("guess", lang, n),
      questions: this.top("question", lang, n),
    };
  }

  // ── persistence (counts only; the sender hashes never leave memory) ─────────

  persistTo(file: string): number {
    this.file = file;
    let loaded = 0;
    try {
      const raw = JSON.parse(readFileSync(file, "utf8")) as { week?: unknown; guess?: unknown; question?: unknown };
      if (raw.week !== this.week) return 0; // last week's file: start fresh
      for (const kind of ["guess", "question"] as const) {
        const byLang = raw[kind];
        if (!byLang || typeof byLang !== "object") continue;
        for (const lang of LANGS) {
          const rows = (byLang as Record<string, unknown>)[lang];
          if (!rows || typeof rows !== "object") continue;
          const list = new Map<string, number>();
          for (const [k, v] of Object.entries(rows as Record<string, unknown>)) {
            if (typeof v === "number" && v > 0 && list.size < MAX_KEYS_PER_LIST) { list.set(k, Math.floor(v)); loaded++; }
          }
          if (list.size) this.lists[kind].set(lang, list);
        }
      }
    } catch {
      // No file yet, or unreadable: start empty.
    }
    return loaded;
  }

  private scheduleSave(): void {
    if (!this.file || this.saveTimer) return;
    this.saveTimer = setTimeout(() => { this.saveTimer = null; this.saveNow(); }, 5000);
    this.saveTimer.unref?.();
  }

  saveNow(): void {
    if (!this.file) return;
    if (this.saveTimer) { clearTimeout(this.saveTimer); this.saveTimer = null; }
    try {
      const out: Record<string, unknown> = { week: this.week };
      for (const kind of ["guess", "question"] as const) {
        const byLang: Record<string, Record<string, number>> = {};
        for (const [lang, list] of this.lists[kind]) {
          // A question below the show line is one person's free text: keep it
          // in memory only. Guesses are dictionary words, so all of them stay.
          const rows = kind === "question" ? [...list].filter(([, n]) => n >= this.minCount) : [...list];
          byLang[lang] = Object.fromEntries(rows);
        }
        out[kind] = byLang;
      }
      mkdirSync(dirname(this.file), { recursive: true });
      const tmp = `${this.file}.tmp`;
      writeFileSync(tmp, JSON.stringify(out));
      renameSync(tmp, this.file);
    } catch (e) {
      console.warn(`[wick-api] could not save the weekly tally: ${String(e)}`);
    }
  }
}
