//
//  stats.ts — local daily statistics for the web client (parity with iOS StatsView).
//
//  Pure + read-only: it derives everything from the per-day rounds main.ts already
//  persists under `wick.daily.<puzzleNumber>` (see saveDaily/loadDaily). It writes
//  NOTHING — the daily blobs stay the single source of truth, so stats can never
//  drift from results. Practice rounds aren't persisted, so they never count (matching
//  iOS: only the daily feeds stats). Fully on-device; no network, no new storage keys.
//

const DAILY_KEY_RE = /^wick\.daily\.(\d+)$/;

export interface DailyStat {
  puzzleNumber: number;
  solved: boolean;
  revealed: boolean;
  /** Guesses made in the round (includes the winning guess on a solve). */
  guessCount: number;
}

export interface DistBucket {
  label: string;
  /** Inclusive guess-count range this bucket covers. */
  lo: number;
  hi: number;
  count: number;
}

export interface StatsSummary {
  /** Rounds finished (solved or revealed). In-progress rounds don't count. */
  played: number;
  wins: number;
  /** 0..100, rounded. 0 when nothing's been played. */
  winPct: number;
  currentStreak: number;
  maxStreak: number;
  distribution: DistBucket[];
  /** Largest bucket count, for bar scaling (>= 1 so callers can divide safely). */
  maxBucketCount: number;
}

/** Read every persisted daily round from localStorage, newest puzzle first. Safe if
 *  storage is disabled or a blob is malformed (those rows are skipped). */
export function readDailyStats(): DailyStat[] {
  const out: DailyStat[] = [];
  let store: Storage;
  try {
    store = window.localStorage;
  } catch {
    return out;
  }
  for (let i = 0; i < store.length; i++) {
    const key = store.key(i);
    if (!key) continue;
    const m = DAILY_KEY_RE.exec(key);
    if (!m) continue;
    const numStr = m[1];
    if (numStr === undefined) continue;
    try {
      const rawVal = store.getItem(key);
      if (!rawVal) continue;
      const o = JSON.parse(rawVal) as { guesses?: unknown; solved?: unknown; revealed?: unknown };
      out.push({
        puzzleNumber: Number(numStr),
        solved: o.solved === true,
        revealed: o.revealed === true,
        guessCount: Array.isArray(o.guesses) ? o.guesses.length : 0,
      });
    } catch {
      /* skip a malformed row */
    }
  }
  out.sort((a, b) => b.puzzleNumber - a.puzzleNumber);
  return out;
}

const BUCKETS: ReadonlyArray<{ label: string; lo: number; hi: number }> = [
  { label: "1–3", lo: 1, hi: 3 },
  { label: "4–6", lo: 4, hi: 6 },
  { label: "7–10", lo: 7, hi: 10 },
  { label: "11–15", lo: 11, hi: 15 },
  { label: "16+", lo: 16, hi: Infinity },
];

/** Compute the stats summary. `todayPuzzleNumber` anchors the current streak so that
 *  not having played *today* yet doesn't break a streak that's intact through
 *  yesterday (the standard daily-game convention). */
export function computeStats(
  todayPuzzleNumber: number,
  rows: DailyStat[] = readDailyStats(),
): StatsSummary {
  const finished = rows.filter((r) => r.solved || r.revealed);
  const played = finished.length;
  const wins = finished.filter((r) => r.solved).length;
  const winPct = played > 0 ? Math.round((wins / played) * 100) : 0;

  const solvedSet = new Set(rows.filter((r) => r.solved).map((r) => r.puzzleNumber));

  // Current streak: start at today if it's solved, else yesterday, then walk back
  // while each preceding puzzle number is also a solve.
  let currentStreak = 0;
  let n = solvedSet.has(todayPuzzleNumber) ? todayPuzzleNumber : todayPuzzleNumber - 1;
  while (solvedSet.has(n)) {
    currentStreak++;
    n--;
  }

  // Max streak: the longest run of consecutive solved puzzle numbers.
  const solvedSorted = [...solvedSet].sort((a, b) => a - b);
  let maxStreak = 0;
  let run = 0;
  let prev = Number.NaN;
  for (const p of solvedSorted) {
    run = p === prev + 1 ? run + 1 : 1;
    if (run > maxStreak) maxStreak = run;
    prev = p;
  }

  const distribution: DistBucket[] = BUCKETS.map((b) => ({
    label: b.label,
    lo: b.lo,
    hi: b.hi,
    count: finished.filter((r) => r.solved && r.guessCount >= b.lo && r.guessCount <= b.hi).length,
  }));
  const maxBucketCount = Math.max(1, ...distribution.map((d) => d.count));

  return { played, wins, winPct, currentStreak, maxStreak, distribution, maxBucketCount };
}
