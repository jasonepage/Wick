//
//  timeline.ts: Solve Replay (3.4) for the web: the pure timing logic.
//
//  A line-for-line port of Hunch/Replay/ReplayTimeline.swift and
//  ReplayBoard.swift, so a round replays the same way on web and iOS. KEEP IN
//  LOCKSTEP with those files: same pacing numbers, same compression levels,
//  same snake board.
//
//  Turns the round's ordered guesses and Keeper questions into "beats" (one
//  beat = one moment of the video) with start times, plus when each tile lands
//  and how long Wick takes to hop off it. scene.ts only asks "what is happening
//  at time t?" and draws the answer.
//
//  Shape crosses over, content never does: this file decides WHEN a guessed
//  word may be shown, never what the words mean. Each guess event may carry
//  the word the player typed as a label. On a daily round the answer and the
//  closest guesses are masked here, once, when the timeline is built, so no
//  later layer can leak them. On a practice round everything shows.
//

// ── heat bands ──────────────────────────────────────────────────────────────

/** Coldest first. Thresholds mirror HunchTheme.rankLabel. */
export const BAND_ORDER = ["cold", "cool", "warm", "hot", "boiling", "solved"] as const;
export type Band = (typeof BAND_ORDER)[number];

export function bandForRank(rank: number): Band {
  if (rank === 1) return "solved";
  if (rank >= 2 && rank <= 25) return "boiling";
  if (rank >= 26 && rank <= 100) return "hot";
  if (rank >= 101 && rank <= 400) return "warm";
  if (rank >= 401 && rank <= 1200) return "cool";
  return "cold"; // also rank 0 ("not ready")
}

export function bandIndex(b: Band): number {
  return BAND_ORDER.indexOf(b);
}

/** The canonical heat token, for t("heat." + token). */
export function bandToken(b: Band): string {
  return { cold: "Cold", cool: "Cool", warm: "Warm", hot: "Hot", boiling: "Boiling", solved: "Solved!" }[b];
}

// ── inputs ──────────────────────────────────────────────────────────────────

export type VerdictTone = "yes" | "no" | "sortOf" | "other";

export function toneFor(verdict: string): VerdictTone {
  const v = verdict.toLowerCase();
  if (v === "yes") return "yes";
  if (v === "no") return "no";
  if (v === "sort of") return "sortOf";
  return "other";
}

export interface Verdict { tone: VerdictTone; label: string }

export type ReplayEvent =
  /** A scored guess. 1 = the answer, 0 = rank unknown. `exact` false means
   *  the rank is an estimate from the score: color the tile, print no number.
   *  `label` is the word the player typed, in the play language. */
  | { kind: "guess"; rank: number; exact?: boolean; label?: string }
  | { kind: "question"; verdict: Verdict };

export type Outcome = "solved" | "revealed";

// ── spoilers ────────────────────────────────────────────────────────────────

/** On a round where the answer must stay secret (today's daily), a guess
 *  ranked this close or closer is masked: its rank and heat still show, but the
 *  word is drawn as dots, because "coral #3" gives the word away. Rank 1 is the
 *  answer itself; 2 to 11 are the ten closest words. One edit here changes the
 *  rule on the web; keep ReplayTimeline.swift's spoilerRankLimit the same. */
export const SPOILER_RANK_LIMIT = 11;

/** Which words a replay may print. Decided once, from the game mode. */
export interface WordPolicy {
  /** True on a practice round: the answer may appear on the final tile and the
   *  end card, and every guess shows its word. False on a daily round: the
   *  answer never appears anywhere and the closest guesses are masked. */
  showAnswer: boolean;
  /** The answer, for the final tile and the end card. Only used when
   *  `showAnswer` is true; a revealed round has no rank-1 event to take it from. */
  answer?: string;
}

export const HIDE_ANSWER: WordPolicy = { showAnswer: false };

/** Whether a daily replay must hide this guess's word. Inexact ranks are
 *  estimates from the score, so a boiling-hot estimate is masked too. */
export function isSpoiler(rank: number, exact: boolean): boolean {
  if (rank <= 0) return false;
  if (rank <= SPOILER_RANK_LIMIT) return true;
  return !exact && bandForRank(rank) === "boiling";
}

// ── tiles and beats ─────────────────────────────────────────────────────────

export type Emphasis =
  | { kind: "dip" }
  | { kind: "newBest" }
  | { kind: "bigJump"; from: Band };

export type TileKind = "guess" | "answer" | "revealed";

export interface Tile {
  slot: number;
  /** 1-based, null for the revealed "?". */
  guessNumber: number | null;
  /** 1 for the answer, 0 for the revealed "?" or an unknown rank. */
  rank: number;
  /** Whether `rank` is the real rank (safe to print on the tile). */
  exact: boolean;
  kind: TileKind;
  emphasis: Emphasis | null;
  /** The word to print on the tile, or null when there is none to print. For
   *  the answer and revealed tiles this is the answer, set only when the
   *  timeline's `showAnswer` is true. */
  label: string | null;
  /** True when the word was withheld as a spoiler: draw dots in its place. */
  masked: boolean;
  /** When the tile starts popping in (seconds). */
  landsAt: number;
  /** How long Wick takes to hop to the next cell. 0 for the last tile. */
  hop: number;
}

export function tileBand(t: Tile): Band {
  return t.kind === "revealed" ? "cold" : bandForRank(t.rank);
}

export type BeatKind =
  | { kind: "intro" }
  | { kind: "place"; slots: number[] }
  | { kind: "keeper"; verdicts: Verdict[] }
  | { kind: "finale"; outcome: Outcome }
  | { kind: "endCard" };

export interface Beat { kind: BeatKind; start: number; duration: number }
export const beatEnd = (b: Beat): number => b.start + b.duration;

// ── pacing ──────────────────────────────────────────────────────────────────

export interface Pacing {
  intro: number; dip: number; newBest: number; bigJump: number; keeper: number;
  finale: number; endCard: number;
  burstBase: number; burstPerTile: number; burstTail: number;
  maxBeat: number; minTotal: number; maxTotal: number; maxStretch: number;
  hopLead: number; hop: number; finaleLand: number;
}

export const STANDARD_PACING: Pacing = {
  intro: 1.5, dip: 1.0, newBest: 1.5, bigJump: 2.5, keeper: 1.2,
  finale: 3.0, endCard: 3.0,
  burstBase: 1.2, burstPerTile: 0.12, burstTail: 0.25,
  maxBeat: 3.0, minTotal: 30, maxTotal: 60, maxStretch: 1.6,
  hopLead: 0.12, hop: 0.4, finaleLand: 0.45,
};

// ── timeline ────────────────────────────────────────────────────────────────

export interface Timeline {
  tiles: Tile[];
  beats: Beat[];
  outcome: Outcome;
  /** Whether the answer may be drawn (final tile, end card). See WordPolicy. */
  showAnswer: boolean;
  /** The answer for the end card. Always null when `showAnswer` is false. */
  answer: string | null;
}

export const duration = (tl: Timeline): number => {
  const last = tl.beats[tl.beats.length - 1];
  return last ? beatEnd(last) : 0;
};
export const finalSlot = (tl: Timeline): number => tl.tiles.length - 1;
export const totalGuesses = (tl: Timeline): number =>
  tl.tiles.reduce((m, t) => Math.max(m, t.guessNumber ?? 0), 0);

/** The beat playing at t; the last beat holds after the end. */
export function beatIndex(tl: Timeline, t: number): number {
  for (let i = 0; i < tl.beats.length; i++) if (t < beatEnd(tl.beats[i]!)) return i;
  return tl.beats.length - 1;
}

export function landedCount(tl: Timeline, t: number): number {
  let n = 0;
  for (const tile of tl.tiles) if (tile.landsAt <= t) n++;
  return n;
}

/** Best (lowest) rank on the board at t, or null before any guess. */
export function bestRank(tl: Timeline, t: number): number | null {
  let best: number | null = null;
  for (const tile of tl.tiles) {
    if (tile.landsAt <= t && tile.rank > 0) best = Math.min(best ?? Infinity, tile.rank);
  }
  return best;
}

/** The tile holding the best rank at t (first one to reach it). */
export function bestTile(tl: Timeline, t: number): Tile | null {
  const best = bestRank(tl, t);
  if (best === null) return null;
  return tl.tiles.find((x) => x.rank === best && x.landsAt <= t) ?? null;
}

export function guessesShown(tl: Timeline, t: number): number {
  let shown = 0;
  for (const tile of tl.tiles) if (tile.landsAt <= t && tile.guessNumber) shown = Math.max(shown, tile.guessNumber);
  return shown;
}

export interface Travel { from: number; to: number; progress: number }

/** Where Wick is: hopping `from` one cell `to` the next. Still when from == to. */
export function wickTravel(tl: Timeline, t: number): Travel {
  let last: Tile | null = null;
  for (const tile of tl.tiles) {
    if (tile.landsAt <= t) last = tile; else break;
  }
  if (!last) return { from: 0, to: 0, progress: 1 };
  if (last.slot >= finalSlot(tl) || last.hop <= 0) return { from: last.slot, to: last.slot, progress: 1 };
  const p = (t - last.landsAt) / last.hop;
  if (p >= 1) return { from: last.slot + 1, to: last.slot + 1, progress: 1 };
  return { from: last.slot, to: last.slot + 1, progress: Math.max(0, p) };
}

// ── building ────────────────────────────────────────────────────────────────

type Unit = { kind: "tile"; index: number } | { kind: "keeper"; verdicts: Verdict[] };
interface Middle { kind: BeatKind; duration: number }

/** Compression levels, gentlest first. */
type Level = "dips" | "dipsNoKeeper" | "allButBigJumps";
const LEVELS: Level[] = ["dips", "dipsNoKeeper", "allButBigJumps"];
const BURST_SIZES = [1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 128, Number.MAX_SAFE_INTEGER];

function canBurst(level: Level, e: Emphasis): boolean {
  return level === "allButBigJumps" ? e.kind !== "bigJump" : e.kind === "dip";
}

function single(e: Emphasis, p: Pacing): number {
  return e.kind === "dip" ? p.dip : e.kind === "newBest" ? p.newBest : p.bigJump;
}

export function burstDuration(count: number, p: Pacing): number {
  return Math.min(p.maxBeat, p.burstBase + p.burstPerTile * count);
}

const sum = (m: Middle[]): number => m.reduce((a, x) => a + x.duration, 0);

function compose(units: Unit[], tiles: Tile[], level: Level, maxBurst: number, p: Pacing): Middle[] {
  const out: Middle[] = [];
  let run: number[] = [];
  const one = (i: number): Middle => ({
    kind: { kind: "place", slots: [tiles[i]!.slot] },
    duration: single(tiles[i]!.emphasis ?? { kind: "dip" }, p),
  });
  const flush = (): void => {
    if (!run.length) return;
    const cap = Math.max(1, Math.min(maxBurst, run.length));
    const pieces = Math.ceil(run.length / cap);
    const base = Math.floor(run.length / pieces);
    const extra = run.length % pieces;
    let index = 0;
    for (let k = 0; k < pieces; k++) {
      const size = base + (k < extra ? 1 : 0);
      const chunk = run.slice(index, index + size);
      index += size;
      out.push(chunk.length === 1
        ? one(chunk[0]!)
        : { kind: { kind: "place", slots: chunk.map((i) => tiles[i]!.slot) }, duration: burstDuration(chunk.length, p) });
    }
    run = [];
  };
  for (const u of units) {
    if (u.kind === "tile") {
      const e = tiles[u.index]!.emphasis;
      if (e && canBurst(level, e)) run.push(u.index);
      else { flush(); out.push(one(u.index)); }
    } else {
      // A dropped bubble does not break a run of mergeable tiles.
      if (level !== "dips") continue;
      flush();
      out.push({ kind: { kind: "keeper", verdicts: u.verdicts }, duration: p.keeper });
    }
  }
  flush();
  return out;
}

function schedule(slots: number[], start: number, dur: number, tiles: Tile[], p: Pacing): void {
  if (slots.length === 1) {
    const t = tiles[slots[0]!]!;
    t.landsAt = start + p.hopLead;
    t.hop = Math.min(p.hop, Math.max(0.1, dur - p.hopLead - 0.1));
    return;
  }
  const usable = Math.max(0.2, dur - p.hopLead - p.burstTail);
  const step = usable / slots.length;
  slots.forEach((s, i) => {
    const t = tiles[s]!;
    t.landsAt = start + p.hopLead + step * i;
    t.hop = step;
  });
}

/** Builds the replay, or null when there is nothing to show (a reveal with no
 *  scored guesses). */
export function buildTimeline(events: ReplayEvent[], outcome: Outcome, p: Pacing = STANDARD_PACING,
  words: WordPolicy = HIDE_ANSWER): Timeline | null {
  const tiles: Tile[] = [];
  const units: Unit[] = [];
  let verdicts: Verdict[] = [];
  let best = Infinity;
  let guessNumber = 0;
  let answerNumber: number | null = null;
  const showAnswer = words.showAnswer;
  let answer: string | null = showAnswer ? (words.answer ?? null) : null;
  const flushVerdicts = (): void => {
    if (verdicts.length) { units.push({ kind: "keeper", verdicts }); verdicts = []; }
  };

  for (const e of events) {
    if (e.kind === "question") { verdicts.push(e.verdict); continue; }
    if (e.rank === 1) {
      // The answer ends a solved round; on a revealed round it can't happen.
      if (outcome === "solved") {
        answerNumber = guessNumber + 1;
        if (showAnswer && e.label) answer = answer ?? e.label;
        break;
      }
      continue;
    }
    guessNumber++;
    flushVerdicts();
    let emphasis: Emphasis;
    if (e.rank > 0 && e.rank < best) {
      const oldBand = bandForRank(best === Infinity ? 0 : best);
      const jumped = best !== Infinity && bandIndex(bandForRank(e.rank)) - bandIndex(oldBand) >= 2;
      emphasis = jumped ? { kind: "bigJump", from: oldBand } : { kind: "newBest" };
      best = e.rank;
    } else {
      emphasis = { kind: "dip" };
    }
    const exact = e.exact ?? true;
    const masked = !showAnswer && isSpoiler(e.rank, exact);
    tiles.push({ slot: tiles.length, guessNumber, rank: e.rank, exact,
      kind: "guess", emphasis, label: masked ? null : (e.label ?? null), masked, landsAt: 0, hop: 0 });
    units.push({ kind: "tile", index: tiles.length - 1 });
  }
  flushVerdicts();

  if (outcome === "solved") {
    tiles.push({ slot: tiles.length, guessNumber: answerNumber ?? guessNumber + 1, rank: 1, exact: true,
      kind: "answer", emphasis: null, label: answer, masked: !showAnswer, landsAt: 0, hop: 0 });
  } else {
    if (!tiles.length) return null;
    tiles.push({ slot: tiles.length, guessNumber: null, rank: 0, exact: true,
      kind: "revealed", emphasis: null, label: answer, masked: !showAnswer, landsAt: 0, hop: 0 });
  }

  // Fit the middle into the budget, compressing as little as possible.
  const fixed = p.intro + p.finale + p.endCard;
  const budget = Math.max(0, p.maxTotal - fixed);
  let middle: Middle[] = [];
  search: for (const level of LEVELS) {
    for (const size of BURST_SIZES) {
      middle = compose(units, tiles, level, size, p);
      if (sum(middle) <= budget + 1e-9) break search;
    }
  }

  // Short round: stretch a little toward the minimum, never padding.
  const middleTotal = sum(middle);
  if (middleTotal > 0 && fixed + middleTotal < p.minTotal) {
    const factor = Math.min(p.maxStretch, (p.minTotal - fixed) / middleTotal);
    middle = middle.map((m) => ({ ...m, duration: Math.max(m.duration, Math.min(p.maxBeat, m.duration * factor)) }));
  }

  const beats: Beat[] = [{ kind: { kind: "intro" }, start: 0, duration: p.intro }];
  let t = p.intro;
  for (const m of middle) {
    if (m.kind.kind === "place") schedule(m.kind.slots, t, m.duration, tiles, p);
    beats.push({ kind: m.kind, start: t, duration: m.duration });
    t += m.duration;
  }
  const last = tiles[tiles.length - 1]!;
  last.landsAt = t + p.finaleLand;
  last.hop = 0;
  beats.push({ kind: { kind: "finale", outcome }, start: t, duration: p.finale });
  t += p.finale;
  beats.push({ kind: { kind: "endCard" }, start: t, duration: p.endCard });
  return { tiles, beats, outcome, showAnswer, answer };
}

// ── formatting ──────────────────────────────────────────────────────────────

/** Compact rank for a tile: "#14", "#340", "#2.3k", "#12k". Empty for 0. */
export function formatRank(rank: number): string {
  if (rank <= 0) return "";
  if (rank < 1000) return `#${rank}`;
  if (rank < 10_000) {
    const tenths = Math.round(rank / 100);
    return tenths % 10 === 0 ? `#${tenths / 10}k` : `#${Math.floor(tenths / 10)}.${tenths % 10}k`;
  }
  return `#${Math.round(rank / 1000)}k`;
}

/** Meter fill 0..1 on a log scale. Same curve as HunchTheme.rankFill. */
export function meterFill(rank: number, maxRank: number): number {
  if (rank <= 0 || maxRank <= 1) return 0;
  if (rank === 1) return 1;
  const f = 1 - Math.log(rank) / Math.log(maxRank);
  return Math.max(0.04, Math.min(1, f));
}

// ── board ───────────────────────────────────────────────────────────────────

export interface Rect { x: number; y: number; w: number; h: number }

/** Sokoban-style grid. Tiles follow a snake path so each slot is one step
 *  from the last. Picks the column count that gives the biggest cells. */
export interface Board { count: number; columns: number; rows: number; cell: number; x: number; y: number }

export function makeBoard(count: number, area: Rect, maxCell = 200, maxColumns = 24): Board {
  const n = Math.max(1, count);
  let bestC = 1, bestR = n, bestCell = -1;
  for (let c = 1; c <= Math.max(1, Math.min(maxColumns, n)); c++) {
    const r = Math.ceil(n / c);
    const size = Math.min(area.w / c, area.h / r, maxCell);
    let better = false;
    if (size > bestCell + 0.5) better = true;
    else if (Math.abs(size - bestCell) <= 0.5) {
      const shape = Math.abs(c - r), bestShape = Math.abs(bestC - bestR);
      better = shape < bestShape || (shape === bestShape && c > bestC);
    }
    if (better) { bestC = c; bestR = r; bestCell = size; }
  }
  const cell = Math.max(1, Math.floor(bestCell));
  return {
    count: n, columns: bestC, rows: bestR, cell,
    x: Math.round(area.x + area.w / 2 - (bestC * cell) / 2),
    y: Math.round(area.y + area.h / 2 - (bestR * cell) / 2),
  };
}

export function boardFrame(b: Board): Rect {
  return { x: b.x, y: b.y, w: b.columns * b.cell, h: b.rows * b.cell };
}

export function slotPosition(b: Board, slot: number): { row: number; column: number } {
  const row = Math.floor(slot / b.columns);
  const i = slot % b.columns;
  return { row, column: row % 2 === 0 ? i : b.columns - 1 - i };
}

export function slotRect(b: Board, slot: number): Rect {
  const p = slotPosition(b, slot);
  return { x: b.x + p.column * b.cell, y: b.y + p.row * b.cell, w: b.cell, h: b.cell };
}

export function slotCenter(b: Board, slot: number): { x: number; y: number } {
  const r = slotRect(b, slot);
  return { x: r.x + r.w / 2, y: r.y + r.h / 2 };
}
