// SPDX-License-Identifier: MPL-2.0
//
//  route.ts: the route analysis behind Semantic Arena (3.9).
//
//  Pure functions over a round's numbers: one small signal per guess, the
//  three Path Report stats, the coach line, the post-round category chip and
//  the two-player race comparison. No DOM, no network, no clock, no randomness:
//  the same round always gives the same answer.
//
//  WHAT MAY COME IN
//  ----------------
//  Scores 0..100, the player's OWN guess words, and similarity between the
//  player's own guesses. The race comparison takes numbers only: it has no
//  field for a word, so an opponent's guess cannot pass through it.
//
//  Similarity is on one scale on both platforms, 0 (unrelated) to 1 (the same).
//  iOS passes Apple's cosine; the server rescales Gemini's cosine through the
//  warmth window first, because Gemini runs hot (see pairSimilarity).
//
//  LOCKSTEP with Hunch/Engine/RouteAnalysis.swift: same names, same numbers.
//  HunchTests/RouteFixtures.json holds cases both test suites run.
//

import { capTrail, heatBand, type HeatBand } from "./raceshow.ts";

// ── thresholds ──────────────────────────────────────────────────────────────

/** Every tuning number in one place. Points are warmth points on the 0..100 scale. */
export const ROUTE = {
  breakthroughGain: 15,
  warmerGain: 4,
  backtrackDrop: 12,
  /** Below this change a move counts as "roughly flat". */
  flatBand: 8,
  neighborSim: 0.72,
  newDirectionSim: 0.35,
  /** "Recent guesses" for New direction. */
  recentWindow: 3,
  /** A move smaller than this repeats the last guess's warmth. */
  flatMove: 2,
  flatMovePenalty: 3,
  flatMovePenaltyCap: 15,
  /** Two guesses at or above this similarity are one direction. */
  clusterSim: 0.5,
  coachCleanEfficiency: 80,
  coachBigJump: 25,
  coachWideDirections: 4,
  coachCircleGuesses: 5,
  coachCircleDirections: 2,
  coachCircleFlatMoves: 3,
  coachBacktracks: 2,
} as const;

/** Clamp to 0..100 and round. Both platforms score in whole numbers, and web
 *  warmth arrives as a fraction, so this removes 56.99999 style noise. */
export function normScore(s: number): number {
  if (!Number.isFinite(s)) return 0;
  return Math.round(Math.max(0, Math.min(100, s)));
}

// ── strategic guess signals ─────────────────────────────────────────────────

export type GuessSignal = "breakthrough" | "warmer" | "sideways" | "sameNeighborhood" | "backtrack" | "newDirection";

export const SIGNAL_KEY: Record<GuessSignal, string> = {
  breakthrough: "signalBreakthrough",
  warmer: "signalWarmer",
  sideways: "signalSideways",
  sameNeighborhood: "signalNeighborhood",
  backtrack: "signalBacktrack",
  newDirection: "signalNewDirection",
};

/** A small glyph, so the signal never relies on color. U+FE0E keeps arrows as
 *  text instead of emoji. */
export const SIGNAL_GLYPH: Record<GuessSignal, string> = {
  breakthrough: "⇈",
  warmer: "↑",
  sideways: "↔︎",
  sameNeighborhood: "↻",
  backtrack: "↓",
  newDirection: "↗︎",
};

export interface SignalInput {
  /** The player's earlier scores, oldest first. */
  prior: readonly number[];
  /** This guess's score. */
  score: number;
  /** This guess's similarity to its earlier guesses, NEWEST first, at most
   *  three. null or missing means similarity is unavailable. */
  similarity?: readonly (number | null)[] | null;
}

/**
 * One signal for an accepted guess, or null when nothing is worth saying.
 * Without similarity only Breakthrough, Warmer and Backtrack can fire.
 * Priority: Breakthrough, Warmer, Backtrack, Same neighborhood, New direction,
 * Sideways. The first guess and the solving guess get no signal.
 */
export function classifySignal(input: SignalInput): GuessSignal | null {
  const prior = input.prior.map(normScore);
  const score = normScore(input.score);
  if (prior.length === 0 || score >= 100) return null;
  const prev = prior[prior.length - 1]!;
  const gain = score - Math.max(...prior);
  if (gain >= ROUTE.breakthroughGain) return "breakthrough";
  if (gain >= ROUTE.warmerGain) return "warmer";
  if (prev - score >= ROUTE.backtrackDrop) return "backtrack";

  const sims = input.similarity ?? [];
  const toPrev = sims[0];
  if (toPrev === null || toPrev === undefined) return null;
  const flat = Math.abs(score - prev) < ROUTE.flatBand;
  if (toPrev >= ROUTE.neighborSim && flat) return "sameNeighborhood";

  const window = Math.min(ROUTE.recentWindow, prior.length);
  const recent = sims.slice(0, window);
  if (recent.length === window && recent.every((s) => s !== null && s !== undefined && s < ROUTE.newDirectionSim)) {
    return "newDirection";
  }
  if (toPrev < ROUTE.neighborSim && flat) return "sideways";
  return null;
}

/** How a signal is emphasized. Only Breakthrough gets gold: one pulse, or a
 *  still gold state under Reduce Motion. */
export type SignalEmphasis = "none" | "pulse" | "static";
export function signalEmphasis(signal: GuessSignal, reduceMotion: boolean): SignalEmphasis {
  if (signal !== "breakthrough") return "none";
  return reduceMotion ? "static" : "pulse";
}

// ── route statistics ────────────────────────────────────────────────────────

export interface RouteGuess { word: string; score: number }

/** Pairwise similarity between the guesses, same order as the guesses. */
export type SimilarityMatrix = readonly (readonly (number | null)[])[];

export interface RouteInput {
  /** Every scored guess, oldest first. A solving guess is last, at 100. */
  guesses: readonly RouteGuess[];
  solved: boolean;
  similarity?: SimilarityMatrix | null;
}

export interface BestJump { index: number; word: string; gain: number }

export interface RouteReport {
  guessCount: number;
  solved: boolean;
  /** 0..100, or null when there is no route to measure. */
  efficiency: number | null;
  bestJump: BestJump | null;
  /** The first guess was the only scored guess. */
  firstTry: boolean;
  /** How many directions the guesses went, or null without similarity. */
  exploration: number | null;
  /** The coach line's localization key, or null for an empty round. */
  coachKey: string | null;
}

function flatMoves(scores: readonly number[]): number {
  let n = 0;
  for (let i = 1; i < scores.length; i++) {
    if (Math.abs(scores[i]! - scores[i - 1]!) < ROUTE.flatMove) n++;
  }
  return n;
}

/**
 * Efficiency: how directly the guesses moved toward the answer.
 *
 *   net      = how far the last guess got above the first
 *   needed   = 100 - first guess
 *   traveled = every warmth move added up, drops included
 *   score    = 100 * net / max(traveled, needed), minus 3 per flat move (up to 15)
 *
 * Solved, net equals needed, so a straight climb scores 100 and every drop
 * costs twice: once down, once back up. A round that stopped short is measured
 * against the full distance. It uses warmth only, so it works offline, in a
 * race, and with similarity down.
 */
export function efficiency(rawScores: readonly number[], solved: boolean): number | null {
  const scores = rawScores.map(normScore);
  if (scores.length === 0) return null;
  if (solved) scores[scores.length - 1] = 100;
  if (scores.length === 1) return solved ? 100 : null;
  const first = scores[0]!, last = scores[scores.length - 1]!;
  const needed = 100 - first;
  if (needed <= 0) return 100;
  let traveled = 0;
  for (let i = 1; i < scores.length; i++) traveled += Math.abs(scores[i]! - scores[i - 1]!);
  const net = Math.max(0, last - first);
  const base = (100 * net) / Math.max(traveled, needed);
  const penalty = Math.min(ROUTE.flatMovePenaltyCap, flatMoves(scores) * ROUTE.flatMovePenalty);
  return Math.max(0, Math.min(100, Math.round(base - penalty)));
}

/** The largest rise over the previous guess, earliest on a tie. The solving
 *  guess is skipped when any other rise exists: it almost always wins, which
 *  would make the stat say the same thing every round. */
function largestRise(scores: readonly number[], solved: boolean): { index: number; gain: number } | null {
  let best: { index: number; gain: number } | null = null;
  const end = solved ? scores.length - 1 : scores.length;
  for (let i = 1; i < end; i++) {
    const gain = scores[i]! - scores[i - 1]!;
    if (gain > 0 && (best === null || gain > best.gain)) best = { index: i, gain };
  }
  if (best === null && solved && scores.length >= 2) {
    const i = scores.length - 1;
    const gain = scores[i]! - scores[i - 1]!;
    if (gain > 0) best = { index: i, gain };
  }
  return best;
}

export function bestJump(guesses: readonly RouteGuess[], solved: boolean): BestJump | null {
  const scores = guesses.map((g) => normScore(g.score));
  const rise = largestRise(scores, solved);
  return rise ? { index: rise.index, word: guesses[rise.index]!.word, gain: rise.gain } : null;
}

/**
 * Exploration: how many directions the guesses went. Oldest first, each guess
 * joins the first direction whose opening guess it is close to, or opens a new
 * one. The solving guess is left out (it is the target, not a direction). A
 * pair with no similarity counts as different. null when there is no matrix.
 */
export function exploration(count: number, solved: boolean, similarity?: SimilarityMatrix | null): number | null {
  const n = solved ? count - 1 : count;
  if (!similarity || similarity.length < count || count <= 0) return null;
  if (n <= 0) return null;
  const leaders: number[] = [];
  for (let i = 0; i < n; i++) {
    const home = leaders.some((l) => {
      const s = similarity[i]?.[l];
      return s !== null && s !== undefined && s >= ROUTE.clusterSim;
    });
    if (!home) leaders.push(i);
  }
  return leaders.length;
}

function backtracks(scores: readonly number[]): number {
  let n = 0;
  for (let i = 1; i < scores.length; i++) {
    if (scores[i - 1]! - scores[i]! >= ROUTE.backtrackDrop) n++;
  }
  return n;
}

/** One authored line, chosen by fixed rules. Never generated, never a grade. */
export function coachKey(r: {
  scores: readonly number[]; solved: boolean; efficiency: number | null;
  jumpGain: number; exploration: number | null;
}): string | null {
  const n = r.scores.length;
  if (n === 0) return null;
  if (!r.solved) return "pathCoachUnfinished";
  if (n === 1) return "pathCoachFirstTry";
  if (r.efficiency !== null && r.efficiency >= ROUTE.coachCleanEfficiency) return "pathCoachClean";
  if (r.jumpGain >= ROUTE.coachBigJump) return "pathCoachBreakthrough";
  // Closed fast: the last guess before the answer was the warmest of the hunt.
  const hunt = r.scores.slice(0, n - 1);
  const closed = hunt[hunt.length - 1]! >= Math.max(...hunt);
  if (r.exploration !== null && r.exploration >= ROUTE.coachWideDirections && closed) return "pathCoachExplored";
  const narrow = r.exploration !== null && r.exploration <= ROUTE.coachCircleDirections;
  if (n >= ROUTE.coachCircleGuesses && (narrow || flatMoves(r.scores) >= ROUTE.coachCircleFlatMoves)) return "pathCoachCircled";
  if (backtracks(r.scores) >= ROUTE.coachBacktracks) return "pathCoachPivot";
  return "pathCoachSteady";
}

export function routeReport(input: RouteInput): RouteReport {
  const scores = input.guesses.map((g) => normScore(g.score));
  if (input.solved && scores.length > 0) scores[scores.length - 1] = 100;
  const eff = efficiency(scores, input.solved);
  const jump = bestJump(input.guesses.map((g, i) => ({ word: g.word, score: scores[i]! })), input.solved);
  const dirs = exploration(scores.length, input.solved, input.similarity);
  return {
    guessCount: scores.length,
    solved: input.solved,
    efficiency: eff,
    bestJump: jump,
    firstTry: scores.length === 1,
    exploration: dirs,
    coachKey: coachKey({ scores, solved: input.solved, efficiency: eff, jumpGain: jump?.gain ?? 0, exploration: dirs }),
  };
}

// ── the Path Report's reveal sequence ───────────────────────────────────────

export const PATH_SEQUENCE_MS = 1200;

/** When each beat starts, in ms. Reduce Motion: everything at once. */
export interface PathBeats { wick: number; word: number; route: number; routeMs: number; halo: number; stats: number; coach: number }

export function pathSequence(reduceMotion: boolean): PathBeats {
  if (reduceMotion) return { wick: 0, word: 0, route: 0, routeMs: 0, halo: 0, stats: 0, coach: 0 };
  return { wick: 0, word: 120, route: 220, routeMs: 520, halo: 740, stats: 860, coach: 1060 };
}

// ── the Path Card ───────────────────────────────────────────────────────────

/** Everything the Path Card may say beyond the heat trail. Numbers only, on
 *  purpose: there is no field for a word. */
export interface PathFacts {
  guesses: number;
  solved: boolean;
  efficiency: number | null;
  bestJump: number | null;
}

/** `scores` is every scored guess, oldest first. It takes numbers, not a
 *  report, so a guess word has no way onto the card. */
export function pathFacts(rawScores: readonly number[], solved: boolean, guesses = rawScores.length): PathFacts {
  const scores = rawScores.map(normScore);
  if (solved && scores.length > 0) scores[scores.length - 1] = 100;
  return { guesses, solved, efficiency: efficiency(scores, solved), bestJump: largestRise(scores, solved)?.gain ?? null };
}

/** The card as one spoiler-free line: its text equivalent for screen readers
 *  and its fallback when an image cannot be made. */
export function pathCardLine(
  brand: string,
  facts: PathFacts,
  host: string,
  tr: (key: string, ...args: Array<string | number>) => string,
): string {
  const parts = [brand, facts.solved ? tr("pathCardSolved", facts.guesses) : tr("pathCardUnsolved")];
  if (facts.efficiency !== null) parts.push(`${tr("pathCardEfficiency")} ${facts.efficiency}`);
  if (facts.bestJump !== null) parts.push(`${tr("pathCardJump")} +${facts.bestJump}°`);
  parts.push(host);
  return parts.join(" · ");
}

// ── category chip (post-round only) ─────────────────────────────────────────

export type BroadCategory = "animal" | "place" | "object" | "nature" | "food" | "artMusic" | "time" | "event";

/** The word tags that read true as a broad label. Tags with no honest broad
 *  label (abstract, person, bodyPart, substance) are left out: no chip beats a
 *  wrong chip. */
const BROAD: Readonly<Record<string, BroadCategory>> = {
  animal: "animal",
  structure: "place",
  naturalPlace: "place",
  object: "object",
  plant: "nature",
  naturalPhenomenon: "nature",
  food: "food",
  artMusic: "artMusic",
  timePeriod: "time",
  event: "event",
};

export const CATEGORY_KEY: Record<BroadCategory, string> = {
  animal: "pathCatAnimal",
  place: "pathCatPlace",
  object: "pathCatObject",
  nature: "pathCatNature",
  food: "pathCatFood",
  artMusic: "pathCatArtMusic",
  time: "pathCatTime",
  event: "pathCatEvent",
};

export function broadCategory(tag: string | null | undefined): BroadCategory | null {
  return tag ? BROAD[tag] ?? null : null;
}

// ── race comparison ─────────────────────────────────────────────────────────

/** One public snapshot of a seat: its guess count and best warmth (0..1). */
export interface ProgressSample { guessCount: number; best: number }

/**
 * The opponent's public progress, one sample per guess. The protocol shows
 * their guess count and best warmth so far, so this is a running best: a guess
 * that went colder is invisible. Nothing here ever sees a word.
 */
export class ProgressRecorder {
  readonly samples: ProgressSample[] = [];

  push(guessCount: number, bestWarmth: number): void {
    const count = Math.floor(guessCount);
    if (count <= 0) return;
    const best = Math.max(0, Math.min(1, bestWarmth));
    const last = this.samples[this.samples.length - 1];
    if (last && count < last.guessCount) return;
    // A guess counts at once and its warmth lands a moment later.
    if (last && count === last.guessCount) { last.best = Math.max(last.best, best); return; }
    this.samples.push({ guessCount: count, best });
  }
}

/** A running best on the 0..100 scale, one value per guess. */
export function runningBest(scores: readonly number[]): number[] {
  const out: number[] = [];
  let best = 0;
  for (const s of scores) { best = Math.max(best, normScore(s)); out.push(best); }
  return out;
}

/** The opponent's running best per guess, or null when this client did not see
 *  every guess live (a resumed match). Only the last guess may be missing: it
 *  can end the match before a snapshot goes out. */
export function opponentSeries(samples: readonly ProgressSample[], guessCount: number, finalBest: number): number[] | null {
  const count = Math.floor(guessCount);
  if (count <= 0 || samples.length > count || samples.length < count - 1) return null;
  for (let i = 0; i < samples.length; i++) if (samples[i]!.guessCount !== i + 1) return null;
  const series = samples.map((s) => s.best * 100);
  if (series.length < count) series.push(finalBest * 100);
  else series[count - 1] = Math.max(series[count - 1]!, finalBest * 100);
  return runningBest(series);
}

/** The trail node nearest to guess `index` once a trail is capped. */
export function capNode(index: number, length: number, cap = 8): number {
  if (length <= cap) return index;
  return Math.round((index * (cap - 1)) / (length - 1));
}

/** What one seat of the comparison may show. No word, no score. */
export interface ComparisonSeat {
  guessCount: number;
  solved: boolean;
  /** Only a local seat that solved has one. The protocol hides the opponent's
   *  drops, so an honest number cannot be worked out for them, and a route the
   *  other player's solve cut short is not one to grade. */
  efficiency: number | null;
  /** Heat bands, oldest first, at most eight. Green only for a solve. */
  bands: HeatBand[];
  /** Which node carries the gold marker, or null when the seat never rose. */
  jumpNode: number | null;
}

export interface PathComparison {
  you: ComparisonSeat;
  them: ComparisonSeat;
  sentenceKey: string;
}

export const COMPARE_KEYS: readonly string[] = [
  "pathCmpBreakthroughYou", "pathCmpBreakthroughThem", "pathCmpShorterYou", "pathCmpShorterThem",
  "pathCmpConverged", "pathCmpDifferent",
];

function seatBands(best: readonly number[], solved: boolean): HeatBand[] {
  return best.map((s, i) => {
    if (solved && i === best.length - 1) return "solved";
    const band = heatBand(s / 100);
    return band === "solved" ? "danger" : band;
  });
}

export interface ComparisonInput {
  /** The race ended void: nothing to compare. */
  voided: boolean;
  you: { scores: readonly number[]; guessCount: number; solved: boolean };
  them: { samples: readonly ProgressSample[]; guessCount: number; best: number; solved: boolean };
}

/**
 * The two routes side by side, or null when the race data cannot support it.
 * Both trails use the same running best, so the comparison is fair. The
 * sentence is neutral: it compares routes and never says who lost.
 */
export function comparisonOf(input: ComparisonInput): PathComparison | null {
  if (input.voided) return null;
  const yours = input.you.scores.map(normScore);
  if (input.you.solved && yours[yours.length - 1] !== 100) yours.push(100);
  if (yours.length === 0 || input.you.guessCount <= 0) return null;
  const themBest = opponentSeries(input.them.samples, input.them.guessCount, input.them.best);
  if (!themBest) return null;
  const youBest = runningBest(yours);

  const youRise = largestRise(youBest, input.you.solved);
  const themRise = largestRise(themBest, input.them.solved);
  const seat = (best: number[], rise: { index: number } | null, solved: boolean, guessCount: number, eff: number | null): ComparisonSeat => ({
    guessCount, solved, efficiency: eff,
    bands: capTrail(seatBands(best, solved)),
    jumpNode: rise ? capNode(rise.index, best.length) : null,
  });
  const you = seat(youBest, youRise, input.you.solved, input.you.guessCount, input.you.solved ? efficiency(yours, true) : null);
  const them = seat(themBest, themRise, input.them.solved, input.them.guessCount, null);

  // Typing the answer is not a breakthrough, however far it jumped.
  const big = (rise: { index: number; gain: number } | null, length: number, solved: boolean) =>
    rise && rise.gain >= ROUTE.breakthroughGain && !(solved && rise.index === length - 1) ? rise.index : null;
  const youBig = big(youRise, youBest.length, input.you.solved);
  const themBig = big(themRise, themBest.length, input.them.solved);
  let sentenceKey: string;
  if (youBig !== null && (themBig === null || youBig < themBig)) sentenceKey = "pathCmpBreakthroughYou";
  else if (themBig !== null && (youBig === null || themBig < youBig)) sentenceKey = "pathCmpBreakthroughThem";
  else if (you.solved && you.guessCount < them.guessCount) sentenceKey = "pathCmpShorterYou";
  else if (them.solved && them.guessCount < you.guessCount) sentenceKey = "pathCmpShorterThem";
  else if (you.bands[you.bands.length - 1] === them.bands[them.bands.length - 1]) sentenceKey = "pathCmpConverged";
  else sentenceKey = "pathCmpDifferent";
  return { you, them, sentenceKey };
}

/** Every localization key this module names (the tests check each table). */
export const PATH_KEYS: readonly string[] = [
  "pathTitle", "pathSolvedIn", "pathUnsolved", "pathStatEfficiency", "pathStatBestJump", "pathStatExploration",
  "pathJumpGain", "pathFirstTry", "pathDirections.one", "pathDirections.other", "pathStatNone",
  "pathEfficiencyInfo", "pathEfficiencyInfoBtn", "pathShare", "pathCmpTitle",
  "pathCoachClean", "pathCoachBreakthrough", "pathCoachExplored", "pathCoachCircled", "pathCoachPivot",
  "pathCoachFirstTry", "pathCoachUnfinished", "pathCoachSteady",
  "pathCardSolved", "pathCardUnsolved", "pathCardEfficiency", "pathCardJump", "cardBrandRace",
  ...Object.values(SIGNAL_KEY), ...Object.values(CATEGORY_KEY), ...COMPARE_KEYS,
];
