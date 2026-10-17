// SPDX-License-Identifier: MPL-2.0
//
//  board.ts: today's race board (3.6). Everyone plays the same daily word, so
//  every solver is racing everyone else, even with nobody online at the same
//  time.
//
//  Ranking: fewest guesses first, where each hint counts as one extra guess
//  (the hint's word is already one of the guesses), then the faster time,
//  then whoever finished first. Players who gave up are on the board too, below
//  every solver, in the order they gave up. Because only the first result per
//  player counts, giving up and then solving in one guess (say, in another
//  language) leaves you as a give-up.
//
//  Names: no accounts and nothing typed. Each phone or browser gets a name
//  like "Violet Otter" picked from two safe word lists by a hash of its id and
//  a reroll number the player can bump. Only the hash of the id is kept.
//
//  Trust: an iPhone solve happens on the phone, so the server takes the
//  result on trust, with sanity checks: the puzzle must be today's, the time
//  must be possible for that many guesses, and each id gets one entry a day
//  (the first one counts, so replaying in another language changes nothing).
//
//  The puzzle number is the same one the app uses: whole UTC days since
//  1 January 2001, minus 8000 (WordBank.dailyNumber in the iOS app).
//
//  Kept in memory and, with a data folder (WICK_DATA_DIR), in board.json so a
//  deploy does not wipe the day. Only the last few days are kept.
//

import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, mkdirSync, renameSync } from "node:fs";
import { dirname } from "node:path";
import { type Lang, isLang } from "./lang.js";

const REF_EPOCH_S = 978_307_200; // 2001-01-01T00:00:00Z, Apple's reference date
const DAY_MS = 86_400_000;
/** Late finishers: yesterday's puzzle still counts this long after midnight UTC. */
export const GRACE_MS = 2 * 3_600_000;
/** The fastest believable pace: at least this long per guess, and never under MIN_MS. */
export const MIN_MS_PER_GUESS = 1_500;
export const MIN_MS = 3_000;
const MAX_ENTRIES_PER_DAY = 50_000;
const KEEP_DAYS = 7;

/** The daily puzzle number at `ms` (mirrors WordBank.dailyNumber). */
export function puzzleNumber(ms: number): number {
  return Math.max(1, Math.floor((ms / 1000 - REF_EPOCH_S) / 86_400) - 8_000);
}

/** When puzzle `n` started (ms). */
export function puzzleStart(n: number): number {
  return (n + 8_000) * DAY_MS + REF_EPOCH_S * 1000;
}

export const ADJECTIVES = [
  "Amber", "Arctic", "Brave", "Bright", "Calm", "Clever", "Cosmic", "Cozy",
  "Crimson", "Daring", "Dusty", "Eager", "Electric", "Fuzzy", "Gentle", "Golden",
  "Happy", "Hidden", "Jolly", "Lucky", "Lunar", "Mellow", "Misty", "Nimble",
  "Noble", "Olive", "Plucky", "Polar", "Quick", "Quiet", "Rapid", "Rosy",
  "Rusty", "Silver", "Sleepy", "Snowy", "Solar", "Speedy", "Spicy", "Starry",
  "Sunny", "Swift", "Teal", "Tidy", "Velvet", "Violet", "Witty", "Zesty",
] as const;

export const ANIMALS = [
  "Badger", "Beaver", "Bison", "Cobra", "Comet", "Condor", "Coyote", "Crane",
  "Dolphin", "Eagle", "Falcon", "Ferret", "Finch", "Fox", "Gecko", "Heron",
  "Hornet", "Jaguar", "Koala", "Lark", "Lemur", "Lynx", "Marmot", "Moose",
  "Newt", "Ocelot", "Orca", "Otter", "Owl", "Panda", "Puffin", "Quail",
  "Rabbit", "Raven", "Salmon", "Seal", "Sparrow", "Squid", "Stoat", "Swan",
  "Tapir", "Tiger", "Toucan", "Turtle", "Walrus", "Wolf", "Wombat", "Yak",
] as const;

/** Short, stable, one-way hash of a player's id. */
export function hashId(raw: string): string {
  return createHash("sha256").update(`board|${raw}`).digest("hex").slice(0, 16);
}

/** "Violet Otter": from the id hash and the player's reroll number. */
export function nameFor(idHash: string, reroll: number): string {
  const h = createHash("sha256").update(`${idHash}:${reroll}`).digest();
  return `${ADJECTIVES[h[0]! % ADJECTIVES.length]} ${ANIMALS[h[1]! % ANIMALS.length]}`;
}

/** Why a result is impossible, or null when it is believable. A give-up can
 *  have zero guesses and any time. */
export function checkResult(g: unknown, h: unknown, ms: unknown, gaveUp = false): string | null {
  if (!Number.isInteger(g) || (g as number) < (gaveUp ? 0 : 1) || (g as number) > 300) return "bad_guesses";
  if (!Number.isInteger(h) || (h as number) < 0 || (h as number) > (g as number)) return "bad_hints";
  if (!Number.isInteger(ms) || (ms as number) < 0 || (ms as number) > DAY_MS) return "bad_time";
  if (!gaveUp && (ms as number) < Math.max(MIN_MS, MIN_MS_PER_GUESS * (g as number))) return "too_fast";
  return null;
}

interface Entry {
  /** Hash of the player's id. Never returned; the public id is its first 8 characters. */
  key: string;
  name: string;
  g: number;
  h: number;
  ms: number;
  lang: Lang;
  at: number;
  /** Gave up instead of solving. */
  gu: boolean;
}

export interface BoardRow { rank: number; id: string; name: string; g: number; h: number; ms: number; lang: Lang; gu: boolean }
export interface BoardSnapshot { n: number; total: number; top: BoardRow[]; me?: BoardRow }

export type SubmitResult =
  | { ok: true; rank: number; total: number; name: string; id: string; already: boolean }
  | { ok: false; reason: string };

function score(e: Entry): number { return e.g + e.h; }
function compare(a: Entry, b: Entry): number {
  if (a.gu !== b.gu) return a.gu ? 1 : -1;   // every solver above every give-up
  if (a.gu) return a.at - b.at;              // give-ups in the order they gave up
  return score(a) - score(b) || a.ms - b.ms || a.at - b.at;
}

export class RaceBoard {
  private readonly days = new Map<number, Map<string, Entry>>();
  /** Sorted standings per day, rebuilt lazily after a change. */
  private readonly sorted = new Map<number, Entry[]>();
  private file: string | null = null;
  private saveTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(private readonly now: () => number) {}

  /** Is puzzle `n` open for results right now? */
  isOpen(n: number): boolean {
    const t = this.now();
    const cur = puzzleNumber(t);
    if (n === cur) return true;
    return n === cur - 1 && t - puzzleStart(cur) < GRACE_MS;
  }

  submit(input: { n: unknown; g: unknown; h: unknown; ms: unknown; lang: unknown; kid: unknown; r: unknown; gu?: unknown }): SubmitResult {
    const { n } = input;
    if (!Number.isInteger(n) || !this.isOpen(n as number)) return { ok: false, reason: "not_today" };
    if (typeof input.kid !== "string" || input.kid.length < 8 || input.kid.length > 128) return { ok: false, reason: "bad_id" };
    const gaveUp = input.gu === true;
    const bad = checkResult(input.g, input.h, input.ms, gaveUp);
    if (bad) return { ok: false, reason: bad };
    const reroll = Number.isInteger(input.r) && (input.r as number) >= 0 && (input.r as number) < 10_000 ? (input.r as number) : 0;
    const day = this.day(n as number);
    const key = hashId(input.kid);
    const existing = day.get(key);
    if (existing) return this.result(n as number, existing, true);
    if (day.size >= MAX_ENTRIES_PER_DAY) return { ok: false, reason: "full" };
    const entry: Entry = {
      key, name: nameFor(key, reroll),
      g: input.g as number, h: input.h as number, ms: input.ms as number,
      lang: isLang(input.lang) ? input.lang : "en", at: this.now(), gu: gaveUp,
    };
    day.set(key, entry);
    this.sorted.delete(n as number);
    this.prune();
    this.scheduleSave();
    return this.result(n as number, entry, false);
  }

  /** A new name for the player's entry on puzzle `n`. Returns the name, or null. */
  rename(n: unknown, kid: unknown, r: unknown): string | null {
    if (!Number.isInteger(n) || typeof kid !== "string" || !Number.isInteger(r) || (r as number) < 0 || (r as number) >= 10_000) return null;
    const key = hashId(kid);
    const name = nameFor(key, r as number);
    const e = this.days.get(n as number)?.get(key);
    if (e) { e.name = name; this.scheduleSave(); }
    return name;
  }

  snapshot(n: number, topN = 50, meId?: string): BoardSnapshot {
    const list = this.standings(n);
    const row = (e: Entry, i: number): BoardRow => ({ rank: i + 1, id: e.key.slice(0, 8), name: e.name, g: e.g, h: e.h, ms: e.ms, lang: e.lang, gu: e.gu });
    const out: BoardSnapshot = { n, total: list.length, top: list.slice(0, topN).map(row) };
    if (meId) {
      const i = list.findIndex((e) => e.key.startsWith(meId));
      if (i >= 0) out.me = row(list[i]!, i);
    }
    return out;
  }

  private standings(n: number): Entry[] {
    let s = this.sorted.get(n);
    if (!s) {
      s = [...(this.days.get(n)?.values() ?? [])].sort(compare);
      this.sorted.set(n, s);
    }
    return s;
  }

  private result(n: number, e: Entry, already: boolean): SubmitResult {
    const list = this.standings(n);
    return { ok: true, rank: list.indexOf(e) + 1, total: list.length, name: e.name, id: e.key.slice(0, 8), already };
  }

  private day(n: number): Map<string, Entry> {
    let d = this.days.get(n);
    if (!d) { d = new Map(); this.days.set(n, d); }
    return d;
  }

  private prune(): void {
    const oldest = puzzleNumber(this.now()) - KEEP_DAYS;
    for (const n of this.days.keys()) {
      if (n < oldest) { this.days.delete(n); this.sorted.delete(n); }
    }
  }

  // ── persistence ─────────────────────────────────────────────────────────────

  persistTo(file: string): number {
    this.file = file;
    let loaded = 0;
    try {
      const raw = JSON.parse(readFileSync(file, "utf8")) as Record<string, unknown>;
      for (const [k, rows] of Object.entries(raw)) {
        const n = Number(k);
        if (!Number.isInteger(n) || !Array.isArray(rows)) continue;
        const day = this.day(n);
        for (const r of rows as Partial<Entry>[]) {
          const gu = r.gu === true;
          if (typeof r.key !== "string" || typeof r.name !== "string" || checkResult(r.g, r.h, r.ms, gu)) continue;
          day.set(r.key, { key: r.key, name: r.name, g: r.g!, h: r.h!, ms: r.ms!, lang: isLang(r.lang) ? r.lang : "en", at: Number(r.at) || 0, gu });
          loaded++;
        }
      }
      this.prune();
    } catch {
      // No file yet, or unreadable: start empty.
    }
    return loaded;
  }

  private scheduleSave(): void {
    if (!this.file || this.saveTimer) return;
    this.saveTimer = setTimeout(() => { this.saveTimer = null; this.saveNow(); }, 3000);
    this.saveTimer.unref?.();
  }

  saveNow(): void {
    if (!this.file) return;
    if (this.saveTimer) { clearTimeout(this.saveTimer); this.saveTimer = null; }
    try {
      const out: Record<string, Entry[]> = {};
      for (const [n, day] of this.days) out[n] = [...day.values()];
      mkdirSync(dirname(this.file), { recursive: true });
      const tmp = `${this.file}.tmp`;
      writeFileSync(tmp, JSON.stringify(out));
      renameSync(tmp, this.file);
    } catch (e) {
      console.warn(`[wick-api] could not save the race board: ${String(e)}`);
    }
  }
}
