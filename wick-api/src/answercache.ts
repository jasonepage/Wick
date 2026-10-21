// SPDX-License-Identifier: MPL-2.0
//
//  answercache.ts: saved Keeper answers (3.7).
//
//  Every Keeper answer now comes from Gemini. To keep that fast, cheap and
//  fair, a good answer is saved under (secret word, language, question), and
//  the next player who asks the same question about the same word gets the
//  same answer straight away. In a live race both players get the same
//  answer to the same question.
//
//  The question is matched in its normal form: lowercase, single spaces, no
//  punctuation at either end ("Is it alive?" and "is it  alive" are one
//  question). It uses tally.ts normalizeQuestion, so a question with digits,
//  a link, an email address or a crude word is never saved at all.
//
//  What is never saved: an "unavailable" answer (Gemini did not reply), a
//  blocked leak attempt, an answer whose model text named the word, and a
//  reply with no verdict (small talk).
//
//  Where it lives: in memory, and with a data folder (WICK_DATA_DIR, the
//  Render disk) in keeper-answers.json, so a deploy keeps them. Only the
//  COMMON ones go to disk: the daily warm-up questions, and any answer that
//  was asked for at least twice. A one-off question stays in memory only.
//
//  A wrong saved answer is wrong for everyone, so /debug/keeper-cache can
//  list a word's answers and forget one (or all of them). Changing the
//  prompt bumps KEEPER_PROMPT_VERSION in keeper.ts, which starts the file
//  fresh on the next boot.
//

import { readFileSync, writeFileSync, mkdirSync, renameSync } from "node:fs";
import { dirname } from "node:path";
import { normalizeQuestion } from "./tally.js";

export type SavedVerdict = "Yes" | "No" | "Sort of" | "IDK";
const SAVED_VERDICTS: readonly string[] = ["Yes", "No", "Sort of", "IDK"];

export function isSavedVerdict(v: unknown): v is SavedVerdict {
  return typeof v === "string" && SAVED_VERDICTS.includes(v);
}

export interface SavedAnswer {
  verdict: SavedVerdict;
  reply: string;
}

interface Entry {
  v: SavedVerdict;
  r: string;
  /** Times this answer was asked for (1 = only the call that made it). */
  n: number;
  /** Saved by the daily warm-up: always kept on disk. */
  w?: 1;
  /** When it was saved (epoch ms). */
  at: number;
}

/** The normal form of a question, or null when it should not be saved. */
export function questionKey(raw: string): string | null {
  return normalizeQuestion(raw);
}

/** One saved-answers bucket per word and language. */
export function wordKey(secret: string, lang: string): string {
  return `${lang}:${secret.normalize("NFC").trim().replace(/\s+/g, " ").toLocaleLowerCase()}`;
}

export interface AnswerCacheOptions {
  /** Keep at most this many words (least recently used go first). */
  maxWords?: number;
  /** Keep at most this many questions per word. */
  maxPerWord?: number;
  /** The prompt version; a file saved under another version is ignored. */
  version?: string;
}

export class AnswerCache {
  private readonly words = new Map<string, Map<string, Entry>>();
  private readonly maxWords: number;
  private readonly maxPerWord: number;
  private readonly version: string;
  private file: string | null = null;
  private saveTimer: ReturnType<typeof setTimeout> | null = null;
  private hits = 0;
  private misses = 0;

  constructor(private readonly now: () => number = Date.now, opts: AnswerCacheOptions = {}) {
    this.maxWords = opts.maxWords ?? 3000;
    this.maxPerWord = opts.maxPerWord ?? 300;
    this.version = opts.version ?? "1";
  }

  /** The saved answer, or null. Counts the ask, so a repeat becomes "common". */
  get(secret: string, lang: string, question: string): SavedAnswer | null {
    const q = questionKey(question);
    const wk = wordKey(secret, lang);
    const bucket = q ? this.words.get(wk) : undefined;
    const e = q && bucket ? bucket.get(q) : undefined;
    if (!e || !bucket) { this.misses++; return null; }
    this.hits++;
    e.n++;
    // Most recently used word moves to the back (Map keeps insertion order).
    this.words.delete(wk);
    this.words.set(wk, bucket);
    if (e.n === 2) this.scheduleSave(); // just became common: write it down
    return { verdict: e.v, reply: e.r };
  }

  /** Is there a saved answer? Does not count as an ask. */
  has(secret: string, lang: string, question: string): boolean {
    const q = questionKey(question);
    return Boolean(q && this.words.get(wordKey(secret, lang))?.has(q));
  }

  /** Save a good answer. Returns false when it cannot be saved. */
  put(secret: string, lang: string, question: string, a: { verdict: string; reply: string }, opts: { warm?: boolean } = {}): boolean {
    const q = questionKey(question);
    if (!q || !isSavedVerdict(a.verdict)) return false;
    const wk = wordKey(secret, lang);
    let bucket = this.words.get(wk);
    if (bucket) this.words.delete(wk);
    else bucket = new Map();
    this.words.set(wk, bucket);
    const old = bucket.get(q);
    bucket.set(q, { v: a.verdict, r: a.reply, n: old?.n ?? 1, at: this.now(), ...(opts.warm || old?.w ? { w: 1 as const } : {}) });
    this.trim(bucket);
    if (opts.warm) this.scheduleSave();
    return true;
  }

  /** Forget one question for a word, or every question when `question` is
   *  omitted. Returns how many answers were dropped. */
  forget(secret: string, lang: string, question?: string): number {
    const wk = wordKey(secret, lang);
    const bucket = this.words.get(wk);
    if (!bucket) return 0;
    let dropped = 0;
    if (question === undefined) {
      dropped = bucket.size;
      this.words.delete(wk);
    } else {
      const q = questionKey(question);
      if (q && bucket.delete(q)) dropped = 1;
      if (bucket.size === 0) this.words.delete(wk);
    }
    if (dropped) this.scheduleSave();
    return dropped;
  }

  /** A word's saved answers, most asked first (for the debug page). */
  list(secret: string, lang: string): Array<{ question: string; verdict: SavedVerdict; reply: string; asked: number; warm: boolean }> {
    const bucket = this.words.get(wordKey(secret, lang));
    if (!bucket) return [];
    return [...bucket]
      .map(([q, e]) => ({ question: q, verdict: e.v, reply: e.r, asked: e.n, warm: e.w === 1 }))
      .sort((a, b) => b.asked - a.asked || a.question.localeCompare(b.question));
  }

  stats(): { words: number; answers: number; hits: number; misses: number } {
    let answers = 0;
    for (const b of this.words.values()) answers += b.size;
    return { words: this.words.size, answers, hits: this.hits, misses: this.misses };
  }

  private trim(bucket: Map<string, Entry>): void {
    if (bucket.size > this.maxPerWord) {
      // Drop the least asked, oldest answers first; warm-up answers last.
      const order = [...bucket].sort((a, b) =>
        (a[1].w ?? 0) - (b[1].w ?? 0) || a[1].n - b[1].n || a[1].at - b[1].at);
      for (const [k] of order.slice(0, bucket.size - this.maxPerWord)) bucket.delete(k);
    }
    while (this.words.size > this.maxWords) {
      const oldest = this.words.keys().next().value;
      if (oldest === undefined) break;
      this.words.delete(oldest);
    }
  }

  // ── persistence (common answers only) ───────────────────────────────────────

  persistTo(file: string): number {
    this.file = file;
    let loaded = 0;
    try {
      const raw = JSON.parse(readFileSync(file, "utf8")) as { version?: unknown; words?: unknown };
      if (raw.version !== this.version || !raw.words || typeof raw.words !== "object") return 0;
      for (const [wk, rows] of Object.entries(raw.words as Record<string, unknown>)) {
        if (!rows || typeof rows !== "object") continue;
        const bucket = new Map<string, Entry>();
        for (const [q, e] of Object.entries(rows as Record<string, unknown>)) {
          const x = e as Partial<Entry> | null;
          if (!x || !isSavedVerdict(x.v) || typeof x.r !== "string") continue;
          bucket.set(q, {
            v: x.v,
            r: x.r,
            n: typeof x.n === "number" && x.n > 0 ? Math.floor(x.n) : 1,
            at: typeof x.at === "number" ? x.at : 0,
            ...(x.w === 1 ? { w: 1 as const } : {}),
          });
          loaded++;
        }
        if (bucket.size) { this.words.set(wk, bucket); this.trim(bucket); }
      }
    } catch {
      // No file yet, or unreadable: start empty.
    }
    return loaded;
  }

  private scheduleSave(): void {
    if (!this.file || this.saveTimer) return;
    this.saveTimer = setTimeout(() => { this.saveTimer = null; this.saveNow(); }, 10_000);
    this.saveTimer.unref?.();
  }

  saveNow(): void {
    if (!this.file) return;
    if (this.saveTimer) { clearTimeout(this.saveTimer); this.saveTimer = null; }
    try {
      const words: Record<string, Record<string, Entry>> = {};
      for (const [wk, bucket] of this.words) {
        const rows = [...bucket].filter(([, e]) => e.w === 1 || e.n >= 2);
        if (rows.length) words[wk] = Object.fromEntries(rows);
      }
      mkdirSync(dirname(this.file), { recursive: true });
      const tmp = `${this.file}.tmp`;
      writeFileSync(tmp, JSON.stringify({ version: this.version, words }));
      renameSync(tmp, this.file);
    } catch (e) {
      console.warn(`[wick-api] could not save Keeper answers: ${String(e)}`);
    }
  }
}
