// SPDX-License-Identifier: MPL-2.0
//
//  keeperwarm.ts: answer the daily word's common questions early (3.7).
//
//  Everyone plays the same daily word, and most rounds start with the same
//  questions. So once a day the server asks Gemini the common questions about
//  the daily word itself and saves the answers (answercache.ts). The first
//  players of the day then get those answers instantly, and every player gets
//  the same ones.
//
//  The common questions: the 45 suggested questions (starterquestions.ts)
//  plus this week's "Most asked questions" from the Stats page (tally.ts).
//
//  When: tomorrow's word is warmed in the last LEAD_MS before midnight UTC, so
//  it is ready when the day turns over, and today's word is warmed on boot if
//  it was missed. A question that already has a saved answer costs nothing,
//  so a restart does not pay twice.
//
//  Cost: about 55 short Gemini calls per language per day. English only by
//  default; WICK_KEEPER_WARM_LANGS="en,es" adds languages, and
//  WICK_KEEPER_WARM=0 turns it off. Each run logs how many calls it made.
//

import { dailyForDay, dayIndex, dayStartMs, type DailyWord } from "./daily.js";
import { STARTER_QUESTIONS } from "./starterquestions.js";
import { questionKey, type AnswerCache } from "./answercache.js";
import { mentionsSecret } from "./tally.js";
import type { KeeperOptions, KeeperResult } from "./keeper.js";
import type { Lang } from "./lang.js";

/** Start warming tomorrow's word this long before midnight UTC. */
export const LEAD_MS = 2 * 3_600_000;
/** Stop a run after this many model failures in a row (try again next tick). */
const MAX_FAILS_IN_A_ROW = 5;

export type AnswerFn = (
  secret: string,
  question: string,
  lang: Lang,
  secretEn: string | undefined,
  opts: KeeperOptions,
) => Promise<KeeperResult>;

export interface WarmDeps {
  now: () => number;
  cache: AnswerCache;
  answer: AnswerFn;
  /** This week's most asked questions for a language (display text is fine). */
  mostAsked: (lang: Lang) => string[];
  langs: readonly Lang[];
  /** Pause between model calls, to stay well under rate limits. */
  gapMs?: number;
  sleep?: (ms: number) => Promise<void>;
  log?: (msg: string) => void;
}

export interface WarmReport {
  day: number;
  lang: Lang;
  questions: number;
  alreadySaved: number;
  modelCalls: number;
  saved: number;
  failed: number;
  /** True when the run stopped early after repeated failures. */
  stopped: boolean;
}

/** The secret for a language, sent the same way the clients send it. */
function secretFor(w: DailyWord, lang: Lang): { secret: string; secretEn?: string } {
  if (lang === "en") return { secret: w.en };
  return { secret: w[lang], secretEn: w.en };
}

/** The questions to warm for a word, deduplicated, never naming the word. */
export function warmQuestions(w: DailyWord, lang: Lang, mostAsked: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const q of [...STARTER_QUESTIONS, ...mostAsked]) {
    const k = questionKey(q);
    if (!k || seen.has(k)) continue;
    if (mentionsSecret(q, [w.en, w[lang]])) continue;
    seen.add(k);
    out.push(q);
  }
  return out;
}

/** Ask every common question about day `day`'s word in one language. */
export async function warmDay(day: number, lang: Lang, deps: WarmDeps): Promise<WarmReport> {
  const w = dailyForDay(day);
  const { secret, secretEn } = secretFor(w, lang);
  const qs = warmQuestions(w, lang, deps.mostAsked(lang));
  const sleep = deps.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  const r: WarmReport = { day, lang, questions: qs.length, alreadySaved: 0, modelCalls: 0, saved: 0, failed: 0, stopped: false };
  let failsInARow = 0;
  for (const q of qs) {
    if (deps.cache.has(secret, lang, q)) { r.alreadySaved++; continue; }
    const res = await deps.answer(secret, q, lang, secretEn, { cache: deps.cache, warm: true });
    if (res.source === "llm" || res.source === "unavailable") r.modelCalls++;
    if (res.source === "unavailable") {
      r.failed++;
      if (++failsInARow >= MAX_FAILS_IN_A_ROW) { r.stopped = true; break; }
    } else {
      failsInARow = 0;
      if (deps.cache.has(secret, lang, q)) r.saved++;
    }
    if (deps.gapMs) await sleep(deps.gapMs);
  }
  return r;
}

/** Decides which days need warming and runs one warm-up at a time. */
export class DailyWarmer {
  private readonly done = new Set<string>();
  private running = false;

  constructor(private readonly deps: WarmDeps) {}

  /** The days to warm right now: today, plus tomorrow near midnight UTC. */
  daysDue(): number[] {
    const now = this.deps.now();
    const today = dayIndex(now);
    const days = [today];
    if (dayStartMs(today + 1) - now <= LEAD_MS) days.push(today + 1);
    return days;
  }

  /** Warm whatever is due and not done yet. Safe to call often. */
  async tick(): Promise<WarmReport[]> {
    if (this.running) return [];
    this.running = true;
    const reports: WarmReport[] = [];
    try {
      const today = dayIndex(this.deps.now());
      for (const k of [...this.done]) if (Number(k.split(":")[0]) < today) this.done.delete(k);
      for (const day of this.daysDue()) {
        for (const lang of this.deps.langs) {
          const key = `${day}:${lang}`;
          if (this.done.has(key)) continue;
          const r = await warmDay(day, lang, this.deps);
          reports.push(r);
          if (!r.stopped) this.done.add(key);
          this.deps.log?.(
            `[keeper-warm] puzzle #${Math.max(1, day - 8000)} (${lang}): ${r.questions} questions, ` +
              `${r.alreadySaved} already saved, ${r.modelCalls} Gemini calls, ${r.saved} saved, ${r.failed} failed` +
              (r.stopped ? " (stopped early, will retry)" : ""),
          );
        }
      }
    } finally {
      this.running = false;
    }
    return reports;
  }
}
