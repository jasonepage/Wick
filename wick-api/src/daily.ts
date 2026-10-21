// SPDX-License-Identifier: MPL-2.0
//
//  daily.ts: which word is the daily puzzle on a given day (3.7).
//
//  The server only needs this to answer the common Keeper questions for the
//  daily word before players arrive (keeperwarm.ts). It is a port of
//  wick-web/src/game/daily.ts, which is itself a port of the iOS WordBank,
//  and it reads the same pool (dailypool.json is a copy of
//  wick-web/src/game/dailyPool.json; daily.test.ts fails if they differ).
//  Checked: day 9322 is puzzle #1322 "library", day 9421 is #1421 "park".
//

import poolData from "./dailypool.json" with { type: "json" };

export interface DailyWord {
  en: string;
  es: string;
  fr: string;
  it: string;
  de: string;
  zh: string;
  tier: number;
}

const POOL = poolData as DailyWord[];
const U64 = (1n << 64n) - 1n;
const REFERENCE_EPOCH = 978_307_200; // 2001-01-01 00:00:00 UTC, in unix seconds

function splitmixNext(state: bigint): [bigint, bigint] {
  const s = (state + 0x9e3779b97f4a7c15n) & U64;
  let z = s;
  z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & U64;
  z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & U64;
  return [s, (z ^ (z >> 31n)) & U64];
}

function cycleSeed(cycle: number): bigint {
  const c = BigInt.asUintN(64, BigInt(cycle));
  return (c * 0x9e3779b97f4a7c15n + 0xd1b54a32d192ed03n) & U64;
}

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

function dailyIndexFor(day: number, count: number): number {
  if (count <= 0) return 0;
  const pos = ((day % count) + count) % count;
  const cycle = Math.floor(day / count);
  return shuffledIndices(count, cycleSeed(cycle))[pos]!;
}

/** Whole UTC days since 1 January 2001. */
export function dayIndex(nowMs: number): number {
  return Math.floor((nowMs / 1000 - REFERENCE_EPOCH) / 86_400);
}

/** When day `day` starts (epoch ms). */
export function dayStartMs(day: number): number {
  return (REFERENCE_EPOCH + day * 86_400) * 1000;
}

/** The daily word for a day index. */
export function dailyForDay(day: number): DailyWord {
  return POOL[dailyIndexFor(day, POOL.length)]!;
}
