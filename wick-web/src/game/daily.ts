//
//  daily.ts — the shared daily-word engine, ported from the iOS app so the web
//  plays the EXACT same daily puzzle as iOS.
//
//  Faithful port of:
//    - Hunch/Engine/WordBank.swift  (dayIndex, dailyNumber, dailyIndex,
//      cycleSeed, shuffledIndices)
//    - Hunch/Engine/SeededRandom.swift (SplitMix64)
//    - Hunch/Engine/DailyWords.swift  (the tier≤3 daily pool, in file order)
//
//  Runs entirely in the browser — no server, no moat concern (it's the same
//  on-device determinism the iOS app uses, just in JS). 64-bit math uses BigInt.
//  VERIFIED: dayIndex 9322 → puzzle #1322 → "library" (2026-07-11), matching iOS.
//  Keep in lockstep with the Swift sources above.
//

import poolData from "./dailyPool.json";

export interface DailyWord {
  en: string;
  es: string;
  fr: string;
  it: string;
  de: string;
  tier: number;
}
export type Lang = "en" | "es" | "fr" | "it" | "de";

const POOL = poolData as DailyWord[];
const U64 = (1n << 64n) - 1n;

/** SplitMix64.next() — returns [newState, output]. */
function splitmixNext(state: bigint): [bigint, bigint] {
  const s = (state + 0x9e3779b97f4a7c15n) & U64;
  let z = s;
  z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & U64;
  z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & U64;
  return [s, (z ^ (z >> 31n)) & U64];
}

/** cycleSeed(cycle) — fixed base seed mixed with the cycle number. */
function cycleSeed(cycle: number): bigint {
  const c = BigInt.asUintN(64, BigInt(cycle)); // Int64 bit pattern → UInt64
  return (c * 0x9e3779b97f4a7c15n + 0xd1b54a32d192ed03n) & U64;
}

/** Deterministic Fisher–Yates permutation of 0..<count. */
function shuffledIndices(count: number, seed: bigint): number[] {
  let state = seed & U64;
  const idx = Array.from({ length: count }, (_, i) => i);
  for (let i = count - 1; i > 0; i--) {
    const [s, r] = splitmixNext(state);
    state = s;
    const j = Number(r % BigInt(i + 1));
    const tmp = idx[i]!;
    idx[i] = idx[j]!;
    idx[j] = tmp;
  }
  return idx;
}

/** Deterministic daily index into a list of `count` items for `day`. */
function dailyIndexFor(day: number, count: number): number {
  if (count <= 0) return 0;
  const pos = ((day % count) + count) % count;
  const cycle = Math.floor(day / count);
  return shuffledIndices(count, cycleSeed(cycle))[pos]!;
}

const REFERENCE_EPOCH = 978_307_200; // 2001-01-01 00:00:00 UTC, in unix seconds

/** Whole days since the reference date (UTC) — same for everyone. */
export function dayIndex(nowMs: number = Date.now()): number {
  return Math.floor((nowMs / 1000 - REFERENCE_EPOCH) / 86_400);
}

/** Display puzzle number for a day index. */
export function dailyNumber(day: number): number {
  return Math.max(1, day - 8_000);
}

/** The daily word for a given day index. */
export function dailyForDay(day: number): DailyWord {
  return POOL[dailyIndexFor(day, POOL.length)]!;
}

export interface DailyToday {
  dayIndex: number;
  puzzleNumber: number;
  word: DailyWord;
}

/** Today's shared daily puzzle. */
export function todaysDaily(nowMs: number = Date.now()): DailyToday {
  const d = dayIndex(nowMs);
  return { dayIndex: d, puzzleNumber: dailyNumber(d), word: dailyForDay(d) };
}

/** The calendar date (local) a given day index falls on — for archive labels.
 *  Mirrors iOS WordBank.date(forDay:). */
export function dateForDay(day: number): Date {
  return new Date((REFERENCE_EPOCH + day * 86_400) * 1000);
}

/** The first day the daily was public — the archive starts here (mirrors iOS
 *  WordBank.launchDayIndex, 2026-06-06). Earlier puzzle numbers never shipped. */
export const LAUNCH_DAY_INDEX = 9_287;

export interface PastPuzzle {
  dayIndex: number;
  puzzleNumber: number;
  word: DailyWord;
  date: Date;
}

/** Past dailies to replay: launch day … yesterday, NEWEST FIRST (today is played
 *  on the home screen). Every word is deterministic from its day index, so no
 *  archive data is stored — same as iOS ArchiveView. */
export function pastPuzzles(nowMs: number = Date.now()): PastPuzzle[] {
  const yesterday = dayIndex(nowMs) - 1;
  const out: PastPuzzle[] = [];
  for (let d = yesterday; d >= LAUNCH_DAY_INDEX; d--) {
    out.push({ dayIndex: d, puzzleNumber: dailyNumber(d), word: dailyForDay(d), date: dateForDay(d) });
  }
  return out;
}

/** A random pool word for Practice (not tied to the date). */
export function randomPractice(): DailyWord {
  return POOL[Math.floor(Math.random() * POOL.length)]!;
}

/** Pick a practice word AND its pool index, so the round can be shared as a
 *  ghost race — a practice link has to name its word somehow, and an index is
 *  the only handle that doesn't put the word itself in the URL. */
export function randomPracticeAt(): { word: DailyWord; index: number } {
  const index = Math.floor(Math.random() * POOL.length);
  return { word: POOL[index]!, index };
}

/** Resolve a pool index back to its word. Null if out of range — a hand-edited
 *  link must fail into a normal round, not a crash. */
export function practiceAt(index: number): DailyWord | null {
  return Number.isInteger(index) && index >= 0 && index < POOL.length ? POOL[index]! : null;
}

export function wordText(w: DailyWord, lang: Lang = "en"): string {
  return w[lang];
}

export const POOL_SIZE = POOL.length;
