//
//  bot.ts — algorithmic opponent for empty queues (SRS FR-13, SDS §3 botengine).
//
//  Ships in phase 1 as the launch fill-in: at launch there is no ghost trace data
//  to replay (OD-4, bots-first — NOT yet confirmed by Jason), so a queued player
//  who finds no human within the bounded wait is paired with a bot instead. The
//  bot is ALWAYS disclosed as non-live (C9) — that labelling lives in the Room via
//  `kind: "bot"`; this module only produces the bot's *play*.
//
//  It is a PURE, deterministic planner. Given a secret, a seed, and a config it
//  precomputes a timeline of guesses with human-like pacing (gradual warming, a
//  few cold guesses, plateaus) and — for a fraction of matches — an eventual
//  solve. It reads no wall clock and no global RNG (Math.random is unavailable in
//  this runtime anyway); the driver polls `due(elapsedMs)` and forwards each step
//  to `Room.applyGuess`. Same seed ⇒ same match, so tests are stable and two
//  players who (hypothetically) drew the same bot seed would see identical play.
//
//  Fairness: a bot must not always win. `solveProbability` (default 0.7) leaves a
//  real chance the human beats it or it plays to the timeout, and solve times are
//  spread across the match so a human can out-race it. These are feel knobs, not
//  spec requirements — tune freely.
//

import { normalizeWord } from "./room.js";

/** One scheduled bot action, timed relative to the match start (t0). */
export interface BotStep {
  /** ms since t0 at which the bot performs this guess. */
  atMs: number;
  /** The word the bot "guesses". The solve step carries the real secret; every
   *  other step carries a sentinel guaranteed not to match (so it counts as a
   *  wrong guess and only moves the warmth bar). */
  guess: string;
  /** Client-style warmth this guess reports, 0..1. */
  warmth: number;
  /** True only for the final, correct guess (if this bot is destined to solve). */
  solves: boolean;
}

export interface BotConfig {
  /** Probability this bot ever solves; otherwise it plays to the cap. Default 0.7. */
  solveProbability: number;
  /** Match cap (ms) so the plan stays inside the room's lifetime. Default 5 min. */
  capMs: number;
  /** Earliest the bot makes its first guess. Default 1.5 s. */
  minFirstGuessMs: number;
  /** Inter-guess gap range (ms) — human-ish thinking time. Default 2.5–9 s. */
  guessGapMsRange: [number, number];
  /** If the bot solves, the window (ms since t0) its solve lands in.
   *  Default 20 s .. 85% of the cap. */
  solveWindowMs: [number, number];
  /** If the bot does NOT solve, the warmth ceiling it plateaus at. Default 0.5–0.85. */
  maxWarmthNoSolve: [number, number];
}

export const DEFAULT_BOT_CONFIG: BotConfig = {
  solveProbability: 0.7,
  capMs: 5 * 60 * 1000,
  minFirstGuessMs: 1500,
  guessGapMsRange: [2500, 9000],
  solveWindowMs: [20_000, Math.floor(5 * 60 * 1000 * 0.85)],
  maxWarmthNoSolve: [0.5, 0.85],
};

export interface BotSeed {
  secret: string;
  /** Deterministic seed (e.g. derived from the room id). */
  seed: number;
  config?: Partial<BotConfig>;
}

/** Deterministic PRNG (mulberry32). Small, fast, good enough for pacing noise. */
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export class Bot {
  readonly secret: string;
  readonly config: BotConfig;
  readonly willSolve: boolean;
  private readonly steps: BotStep[];
  private cursor = 0;

  constructor(seed: BotSeed) {
    this.secret = normalizeWord(seed.secret);
    this.config = { ...DEFAULT_BOT_CONFIG, ...(seed.config ?? {}) };
    const rand = mulberry32(seed.seed);
    this.willSolve = rand() < this.config.solveProbability;
    this.steps = this.plan(rand);
  }

  /** The full precomputed timeline (read-only; handy for tests/inspection). */
  plan_(): readonly BotStep[] {
    return this.steps;
  }

  /** Does this bot ever submit the correct answer? */
  solves(): boolean {
    return this.willSolve;
  }

  /**
   * Steps whose scheduled time has arrived since the last call, in order. The
   * driver calls this on its tick and forwards each to `Room.applyGuess`. Stateful
   * cursor so each step is returned exactly once; deterministic given the seed.
   */
  due(elapsedMs: number): BotStep[] {
    const out: BotStep[] = [];
    while (this.cursor < this.steps.length && this.steps[this.cursor]!.atMs <= elapsedMs) {
      out.push(this.steps[this.cursor]!);
      this.cursor += 1;
    }
    return out;
  }

  // ── planning ──────────────────────────────────────────────────────────────

  private plan(rand: () => number): BotStep[] {
    const c = this.config;
    const lerp = (a: number, b: number) => a + (b - a) * rand();

    // Decide the solve time (or the effective end for a non-solver).
    const target = this.willSolve
      ? clamp(lerp(c.solveWindowMs[0], c.solveWindowMs[1]), c.minFirstGuessMs + 1000, c.capMs - 500)
      : c.capMs; // a non-solver keeps guessing right up to the cap

    const warmthCeiling = this.willSolve
      ? 1
      : clamp(lerp(c.maxWarmthNoSolve[0], c.maxWarmthNoSolve[1]), 0, 0.95);

    const steps: BotStep[] = [];
    let t = c.minFirstGuessMs + lerp(0, 800);
    let i = 0;

    // Emit wrong guesses with gradually-warming, slightly noisy warmth until we
    // reach the target time.
    while (t < target - 250) {
      const progress = clamp(t / target, 0, 1);
      // Ease-in warmth trend with a little jitter, kept monotonic-ish but never
      // exceeding the ceiling (the Room also enforces a monotonic best).
      const trend = warmthCeiling * easeInOut(progress);
      const jitter = (rand() - 0.5) * 0.08;
      const warmth = clamp(trend + jitter, 0, warmthCeiling);
      steps.push({
        atMs: Math.round(t),
        guess: `__bot_wrong_${i}__`, // never equals a real secret
        warmth,
        solves: false,
      });
      i += 1;
      t += lerp(c.guessGapMsRange[0], c.guessGapMsRange[1]);
    }

    if (this.willSolve) {
      steps.push({ atMs: Math.round(target), guess: this.secret, warmth: 1, solves: true });
    } else {
      // A final near-ceiling guess right before the cap so the strip stays alive.
      const last = Math.min(target - 100, Math.round(t));
      if (steps.length === 0 || last > steps[steps.length - 1]!.atMs) {
        steps.push({
          atMs: Math.max(c.minFirstGuessMs, last),
          guess: `__bot_wrong_final__`,
          warmth: warmthCeiling,
          solves: false,
        });
      }
    }

    return steps;
  }
}

function clamp(x: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, x));
}

/** Smooth ease-in-out in [0,1]. */
function easeInOut(x: number): number {
  const t = clamp(x, 0, 1);
  return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
}
