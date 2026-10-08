//
//  dare.ts — Live Dare: the asymmetric sibling of Room (Race).
//
//  In a Dare, one player (the SETTER) picks the secret word and then SPECTATES;
//  the other (the GUESSER) races the clock to solve the word the setter chose,
//  live. The setter never guesses. It's a challenge ("can you get my word?"),
//  not a symmetric race — so it gets its own small state machine rather than
//  bending Room's first-to-solve/warmest-wins logic.
//
//  Like room.ts this is a PURE state machine: it holds no timers and never reads
//  the wall clock — `now` (epoch ms) is injected, and the hub calls `tick()` on an
//  interval. Server-authoritative: the solve check is instant; warmth is scored
//  server-side and attached to the guess afterwards.
//
//  Visibility: the guesser never learns the word (server holds it; scores warmth).
//  The setter, who chose the word, sees the guesser's actual guesses + warmth —
//  that's the fun of watching a friend warm up — and the word (they know it).
//

import { normalizeWord } from "./room.js";

export interface DareConfig {
  /** Match cap (ms). The guesser must solve within this or the dare fails. */
  capMs: number;
}

export const DEFAULT_DARE_CONFIG: DareConfig = {
  capMs: 5 * 60 * 1000,
};

export type DareRole = "setter" | "guesser";

/** One guess the guesser made (warmth filled in after server scoring). */
export interface DareGuess {
  word: string;
  /** 0..1 warmth, or null until the server scores it. */
  warmth: number | null;
  /** Contexto rank (# reference words closer), when available. */
  rank?: number;
  solved: boolean;
  /** ms since t0. */
  atMs: number;
}

export interface DareResult {
  solved: boolean;
  /** ms since t0 of the solve, or null if never solved. */
  solvedAtMs: number | null;
  guessCount: number;
  /** The word, revealed in the result (the match is over). */
  word: string;
  /** ms since t0 at which the dare resolved. */
  endedAtMs: number;
}

export interface DareSnapshot {
  roomId: string;
  status: "active" | "ended";
  role: DareRole;
  /** The guesser's guesses (both roles may see the words — the guesser typed
   *  them, the setter chose the word). Newest last. */
  guesses: DareGuess[];
  guessCount: number;
  bestWarmth: number;
  solved: boolean;
  /** Same shape as the race ClockView (incl. t0Ms) so clients share one decoder. */
  clock: { t0Ms: number; elapsedMs: number; remainingMs: number; capMs: number };
  /** The word — ONLY included for the setter (they chose it). */
  word?: string;
  result: DareResult | null;
}

export type DareEvent = { type: "state" } | { type: "ended"; result: DareResult };

export interface DareSeed {
  roomId: string;
  /** The setter's chosen secret. */
  word: string;
  setterId: string;
  guesserId: string;
  /** Wall-clock (epoch ms) match start. */
  now: number;
  config?: Partial<DareConfig>;
}

export class DareRoom {
  readonly roomId: string;
  readonly setterId: string;
  readonly guesserId: string;
  readonly t0Wall: number;
  private readonly secret: string;
  private readonly config: DareConfig;

  private status: "active" | "ended" = "active";
  private guesses: DareGuess[] = [];
  private solvedAtMs: number | null = null;
  private endedAtMs: number | null = null;

  constructor(seed: DareSeed) {
    this.roomId = seed.roomId;
    this.setterId = seed.setterId;
    this.guesserId = seed.guesserId;
    this.t0Wall = seed.now;
    this.secret = normalizeWord(seed.word);
    this.config = { ...DEFAULT_DARE_CONFIG, ...(seed.config ?? {}) };
  }

  isActive(): boolean {
    return this.status === "active";
  }

  playerIds(): [string, string] {
    return [this.setterId, this.guesserId];
  }

  /** True only if this player is allowed to guess (the guesser). */
  canGuess(playerId: string): boolean {
    return playerId === this.guesserId;
  }

  /** The setter's word — hub-only (for server-side warmth scoring). */
  word(): string {
    return this.secret;
  }

  /** The guesser submits a word. Solve is INSTANT and authoritative; warmth is
   *  scored later via `applyWarmth`. Guesses from the setter are ignored. */
  applyGuess(args: { playerId: string; guess: string; now: number }): DareEvent[] {
    if (this.status !== "active" || args.playerId !== this.guesserId) return [];
    const atMs = Math.max(0, args.now - this.t0Wall);
    const solved = normalizeWord(args.guess) === this.secret;
    this.guesses.push({ word: args.guess, warmth: solved ? 1 : null, solved, atMs });
    if (solved) {
      this.solvedAtMs = atMs;
      return this.end(args.now);
    }
    return [{ type: "state" }];
  }

  /** Attach server-scored warmth (0..1) + rank to the most recent unscored guess
   *  of that word. */
  applyWarmth(args: { guess: string; warmth: number; rank?: number }): DareEvent[] {
    if (this.status !== "active") return [];
    const w = clamp01(args.warmth);
    for (let i = this.guesses.length - 1; i >= 0; i--) {
      const g = this.guesses[i]!;
      if (g.warmth === null && normalizeWord(g.word) === normalizeWord(args.guess)) {
        g.warmth = w;
        if (args.rank !== undefined) g.rank = args.rank;
        return [{ type: "state" }];
      }
    }
    return [];
  }

  /** Advance the clock: end the dare (failed) if the cap is reached. */
  tick(now: number): DareEvent[] {
    if (this.status !== "active") return [];
    if (now - this.t0Wall >= this.config.capMs) return this.end(now);
    return [];
  }

  /** End immediately (e.g. a player left). */
  forceEnd(now: number): DareEvent[] {
    if (this.status !== "active") return [];
    return this.end(now);
  }

  private end(now: number): DareEvent[] {
    this.status = "ended";
    this.endedAtMs = Math.max(0, now - this.t0Wall);
    return [{ type: "ended", result: this.result() }];
  }

  private result(): DareResult {
    return {
      solved: this.solvedAtMs !== null,
      solvedAtMs: this.solvedAtMs,
      guessCount: this.guesses.filter((g) => !g.solved).length + (this.solvedAtMs !== null ? 1 : 0),
      word: this.secret,
      endedAtMs: this.endedAtMs ?? 0,
    };
  }

  private bestWarmth(): number {
    let best = 0;
    for (const g of this.guesses) if (g.warmth !== null && g.warmth > best) best = g.warmth;
    if (this.solvedAtMs !== null) best = 1;
    return best;
  }

  snapshotFor(playerId: string, now: number): DareSnapshot {
    const role: DareRole = playerId === this.setterId ? "setter" : "guesser";
    const elapsedMs = Math.max(0, now - this.t0Wall);
    const remainingMs = Math.max(0, this.config.capMs - elapsedMs);
    const snap: DareSnapshot = {
      roomId: this.roomId,
      status: this.status,
      role,
      guesses: this.guesses.map((g) => ({ ...g })),
      guessCount: this.guesses.length,
      bestWarmth: this.bestWarmth(),
      solved: this.solvedAtMs !== null,
      clock: { t0Ms: this.t0Wall, elapsedMs, remainingMs, capMs: this.config.capMs },
      result: this.status === "ended" ? this.result() : null,
    };
    if (role === "setter") snap.word = this.secret;
    return snap;
  }
}

function clamp01(x: number): number {
  return Math.max(0, Math.min(1, x));
}
