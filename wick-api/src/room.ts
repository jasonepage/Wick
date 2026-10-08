//
//  room.ts — Wick live-match state machine (server-authoritative).
//
//  This is the heart of free live multiplayer (SRS FR-8/11/17/31/32/33, SDS §5).
//  It is a PURE state machine: it holds no timers and never reads the wall clock
//  itself. Every method takes an explicit `now` (epoch ms) so the server stamps
//  authoritative time (C8) and so the logic is fully deterministic under test.
//  The owning WS/server layer is responsible for actually calling `tick(now)` on
//  a cadence and for fanning out the snapshots/results this module returns.
//
//  Authority boundary (C8 — never trust the client):
//   - The SERVER holds the match secret (assigned per-match by the matchmaker;
//     this is a multiplayer word, NOT a single-player daily word, so the C1 moat
//     is intact). A solve is verified server-side by exact normalized match of
//     the player's submitted guess against the secret, and the solve TIME is the
//     server's own `now`. This is the decisive win path and is not client-forgeable.
//   - `warmth` (0..1 hot/cold closeness) is a SEMANTIC value the on-device engine
//     produces; the server has no embedding model (that engine is the moat, C1),
//     so it cannot recompute warmth. Warmth is therefore client-reported, used
//     only for the live opponent strip and the *timeout* tie-break (FR-31). The
//     server validates it (clamp 0..1, keep the monotonic best) but ultimately
//     trusts it for that soft, non-solve fallback path.
//     >> FLAG (relates to OD-1, NOT yet confirmed by Jason): tie-break-by-warmth
//        is the one place a client could influence a *timeout* outcome by
//        over-reporting warmth. The decisive path (actually submitting the secret)
//        is fully authoritative. If OD-1's tie-break needs to be cheat-proof, it
//        must switch to a server-observable signal (e.g. fewest guesses) — noted.
//
//  The secret word is never placed in any snapshot, result, or (per FR-4) log.
//

// ─────────────────────────────────────────────────────────────────────────────
// Public types
// ─────────────────────────────────────────────────────────────────────────────

export type PlayerId = string;

/** Opponent honesty label (C9). "human" = a real live player. */
export type OpponentKind = "human" | "bot" | "ghost";

export type MatchMode = "casual" | "ranked";

export interface RoomConfig {
  /** FR-33 max match duration. Default 5 min (OD-3, unconfirmed). */
  capMs: number;
  /** OD-8 reconnect grace before forfeit/void. Default ~15 s (unconfirmed). */
  reconnectGraceMs: number;
}

export const DEFAULT_ROOM_CONFIG: RoomConfig = {
  capMs: 5 * 60 * 1000,
  reconnectGraceMs: 15 * 1000,
};

export type RoomStatus = "active" | "ended";

/**
 * Why a match ended.
 *  - "solved":  someone submitted the secret first (FR-31 primary path).
 *  - "timeout": FR-33 cap reached with neither solving → warmth tie-break (FR-31).
 *  - "forfeit": one player dropped and never returned within grace → other wins (FR-17).
 *  - "void":    can't be fairly resolved (both dropped) → no winner (FR-17).
 */
export type EndReason = "solved" | "timeout" | "forfeit" | "void";

export interface PlayerSeed {
  id: PlayerId;
  /** "human" for a live person; "bot"/"ghost" for a disclosed fill-in (FR-13, C9). */
  kind: OpponentKind;
}

export interface RoomSeed {
  roomId: string;
  mode: MatchMode;
  /** The answer. Held server-side only; never leaves this module (FR-4). */
  secret: string;
  /** Exactly two players (one may be a bot/ghost). */
  players: [PlayerSeed, PlayerSeed];
  /** Wall-clock (epoch ms) authoritative match start `t0` (C8). */
  now: number;
  config?: Partial<RoomConfig>;
}

/** Per-player outcome in the authoritative result. */
export interface PlayerResult {
  id: PlayerId;
  kind: OpponentKind;
  /** Server-stamped ms-since-t0 of first correct guess, or null if never solved. */
  solvedAtMs: number | null;
  /** Best (max) warmth reported over the match, 0..1. */
  bestWarmth: number;
  guessCount: number;
}

export interface MatchResult {
  reason: EndReason;
  /** Winner's PlayerId, or null for a draw/void. */
  winner: PlayerId | null;
  draw: boolean;
  players: [PlayerResult, PlayerResult];
  /** ms since t0 at which the room resolved. */
  endedAtMs: number;
}

/** What a single player is allowed to see about themselves. */
export interface SelfView {
  guessCount: number;
  bestWarmth: number;
  solved: boolean;
  solvedAtMs: number | null;
}

/** What a player may see about their opponent: PROGRESS ONLY (FR-8) — never the
 *  opponent's guessed words, questions, or the secret. */
export interface OpponentView {
  kind: OpponentKind;
  guessCount: number;
  bestWarmth: number;
  solved: boolean;
  connected: boolean;
}

export interface ClockView {
  t0Ms: number;
  elapsedMs: number;
  remainingMs: number;
  capMs: number;
}

export interface StateSnapshot {
  roomId: string;
  status: RoomStatus;
  you: SelfView;
  opponent: OpponentView;
  clock: ClockView;
  result: MatchResult | null;
}

/** Events the WS layer should react to (fan out / close the socket). */
export type RoomEvent =
  | { type: "state" } // progress changed — re-snapshot and fan out to both
  | { type: "opponentLeft"; playerId: PlayerId } // `playerId` is the one who left
  | { type: "ended"; result: MatchResult };

// ─────────────────────────────────────────────────────────────────────────────
// Internal player state
// ─────────────────────────────────────────────────────────────────────────────

interface PlayerState {
  id: PlayerId;
  kind: OpponentKind;
  connected: boolean;
  /** Wall-clock ms when the player dropped; null while connected. */
  disconnectedAtWall: number | null;
  guessCount: number;
  bestWarmth: number;
  /** ms-since-t0 of first correct guess; null until solved. */
  solvedAtMs: number | null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/** Normalize a word for exact solve comparison. Unicode-safe, case- and
 *  whitespace-insensitive. Diacritics are intentionally PRESERVED (é ≠ e can be
 *  a different word across the 5 supported languages). */
export function normalizeWord(w: string): string {
  return w
    .normalize("NFC")
    .trim()
    .replace(/\s+/g, " ")
    .toLocaleLowerCase();
}

function clamp01(x: number): number {
  if (Number.isNaN(x)) return 0;
  if (x < 0) return 0;
  if (x > 1) return 1;
  return x;
}

// ─────────────────────────────────────────────────────────────────────────────
// Room
// ─────────────────────────────────────────────────────────────────────────────

export class Room {
  readonly roomId: string;
  readonly mode: MatchMode;
  readonly config: RoomConfig;

  /** Authoritative match start, wall-clock epoch ms (C8). */
  readonly t0Wall: number;

  private readonly secret: string; // never exposed
  private readonly players: [PlayerState, PlayerState];
  private status: RoomStatus = "active";
  private result: MatchResult | null = null;

  constructor(seed: RoomSeed) {
    if (seed.players[0].id === seed.players[1].id) {
      throw new Error("room: both players share an id");
    }
    if (normalizeWord(seed.secret).length === 0) {
      throw new Error("room: empty secret");
    }
    this.roomId = seed.roomId;
    this.mode = seed.mode;
    this.config = { ...DEFAULT_ROOM_CONFIG, ...(seed.config ?? {}) };
    this.t0Wall = seed.now;
    this.secret = normalizeWord(seed.secret);
    this.players = [makePlayer(seed.players[0]), makePlayer(seed.players[1])];
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  isActive(): boolean {
    return this.status === "active";
  }

  getStatus(): RoomStatus {
    return this.status;
  }

  /** The authoritative result, or null while still active. */
  getResult(): MatchResult | null {
    return this.result;
  }

  playerIds(): [PlayerId, PlayerId] {
    return [this.players[0].id, this.players[1].id];
  }

  // ── Mutations (each takes authoritative `now`) ───────────────────────────────

  /**
   * Apply a guess from `playerId`. The server verifies the solve against the
   * secret (exact normalized match) and stamps the solve time from `now` (C8).
   * The first correct guess ends the match (FR-31). Incorrect guesses still
   * count toward the visible guess count (FR-8) and may carry a warmth update.
   * Guesses are unlimited and free (FR-32).
   */
  applyGuess(args: {
    playerId: PlayerId;
    guess: string;
    /** Optional client-reported hot/cold warmth for this guess, 0..1. */
    warmth?: number;
    now: number;
  }): RoomEvent[] {
    const events = this.resolveDue(args.now);
    if (this.status === "ended") return events;

    const p = this.playerById(args.playerId);
    if (!p) return events;

    p.guessCount += 1;
    if (args.warmth !== undefined) {
      p.bestWarmth = Math.max(p.bestWarmth, clamp01(args.warmth));
    }

    const correct = normalizeWord(args.guess) === this.secret;
    if (correct && p.solvedAtMs === null) {
      p.solvedAtMs = args.now - this.t0Wall;
      p.bestWarmth = 1; // solving is maximal warmth
      // First solve wins (FR-31).
      return this.end("solved", args.now);
    }

    // Progress changed; ask the caller to re-fan-out state.
    return [...events, { type: "state" }];
  }

  /**
   * Apply a standalone warmth/progress update (e.g. from a question or a guess
   * whose text the client withheld). Progress only — never affects the solve.
   * Warmth is clamped and kept as a monotonic best (FR-8 opponent strip).
   */
  applyProgress(args: { playerId: PlayerId; warmth: number; now: number }): RoomEvent[] {
    const events = this.resolveDue(args.now);
    if (this.status === "ended") return events;
    const p = this.playerById(args.playerId);
    if (!p) return events;
    p.bestWarmth = Math.max(p.bestWarmth, clamp01(args.warmth));
    return [...events, { type: "state" }];
  }

  /**
   * Mark a player disconnected (FR-17). Starts the reconnect grace window; the
   * match does NOT end immediately — the opponent is notified so the UI can show
   * the gentle "flame flickered" state, and if the player never returns within
   * `reconnectGraceMs` the match resolves (forfeit/void) on a later tick/apply.
   * A bot/ghost never disconnects.
   */
  applyDisconnect(args: { playerId: PlayerId; now: number }): RoomEvent[] {
    const events = this.resolveDue(args.now);
    if (this.status === "ended") return events;
    const p = this.playerById(args.playerId);
    if (!p || !p.connected) return events;
    p.connected = false;
    p.disconnectedAtWall = args.now;
    // Resolve immediately in case grace is 0 or already elapsed via `now`.
    const post = this.resolveDue(args.now);
    return [...events, { type: "opponentLeft", playerId: p.id }, ...post];
  }

  /** A dropped player returned within grace (FR-17): resume the match. */
  applyReconnect(args: { playerId: PlayerId; now: number }): RoomEvent[] {
    const events = this.resolveDue(args.now);
    if (this.status === "ended") return events;
    const p = this.playerById(args.playerId);
    if (!p || p.connected) return events;
    // Only reconnect if still within grace; otherwise the match has (or will)
    // resolve as a forfeit and reconnection is too late.
    if (p.disconnectedAtWall !== null &&
        args.now - p.disconnectedAtWall >= this.config.reconnectGraceMs) {
      return events; // too late — let resolveDue forfeit it
    }
    p.connected = true;
    p.disconnectedAtWall = null;
    return [...events, { type: "state" }];
  }

  /**
   * Advance time with no other input. The WS layer calls this on a cadence so
   * the 5-min cap (FR-33) and the reconnect grace (FR-17) resolve even when no
   * frames are arriving. Idempotent once ended.
   */
  tick(now: number): RoomEvent[] {
    return this.resolveDue(now);
  }

  /**
   * The frame a given player is allowed to see (FR-8/11). Opponent data is
   * progress-only; the secret and the opponent's guesses are never included.
   * Requires `now` to render the live clock.
   */
  snapshotFor(playerId: PlayerId, now: number): StateSnapshot {
    const me = this.playerById(playerId);
    if (!me) throw new Error(`room: unknown player ${playerId}`);
    const other = this.opponentOf(playerId);

    const elapsedMs = Math.max(0, now - this.t0Wall);
    const remainingMs = Math.max(0, this.config.capMs - elapsedMs);

    return {
      roomId: this.roomId,
      status: this.status,
      you: {
        guessCount: me.guessCount,
        bestWarmth: me.bestWarmth,
        solved: me.solvedAtMs !== null,
        solvedAtMs: me.solvedAtMs,
      },
      opponent: {
        kind: other.kind,
        guessCount: other.guessCount,
        bestWarmth: other.bestWarmth,
        solved: other.solvedAtMs !== null,
        connected: other.connected,
      },
      clock: { t0Ms: this.t0Wall, elapsedMs, remainingMs, capMs: this.config.capMs },
      result: this.result,
    };
  }

  // ── Internal resolution ──────────────────────────────────────────────────────

  /** Check disconnect grace (FR-17) then the time cap (FR-33). Disconnect is
   *  checked first: a grace expiry that lands before the cap should forfeit. */
  private resolveDue(now: number): RoomEvent[] {
    if (this.status === "ended") return [];

    // 1) Disconnect grace (FR-17).
    const graceExpired = (p: PlayerState) =>
      !p.connected &&
      p.disconnectedAtWall !== null &&
      now - p.disconnectedAtWall >= this.config.reconnectGraceMs;

    const [a, b] = this.players;
    const aGone = graceExpired(a);
    const bGone = graceExpired(b);
    if (aGone && bGone) return this.end("void", now); // both gone → no fair winner
    if (aGone) return this.end("forfeit", now, b.id);
    if (bGone) return this.end("forfeit", now, a.id);

    // 2) Time cap (FR-33) → warmest-best-guess tie-break (FR-31).
    const elapsed = now - this.t0Wall;
    if (elapsed >= this.config.capMs) return this.end("timeout", now);

    return [];
  }

  /** Finalize the match. `forcedWinner` is used by forfeit; otherwise the winner
   *  is derived from state per the end reason (FR-31). */
  private end(reason: EndReason, now: number, forcedWinner?: PlayerId): RoomEvent[] {
    const [a, b] = this.players;
    let winner: PlayerId | null;

    switch (reason) {
      case "solved": {
        // The player who just solved is the one with a solve time; if (defensively)
        // both are set, the smaller time wins.
        winner = pickBySolveTime(a, b);
        break;
      }
      case "timeout": {
        // Neither solved: warmest best guess wins; exact tie = draw (FR-31).
        if (a.bestWarmth > b.bestWarmth) winner = a.id;
        else if (b.bestWarmth > a.bestWarmth) winner = b.id;
        else winner = null; // draw
        break;
      }
      case "forfeit": {
        winner = forcedWinner ?? null;
        break;
      }
      case "void": {
        winner = null;
        break;
      }
    }

    this.status = "ended";
    this.result = {
      reason,
      winner,
      draw: winner === null,
      players: [toResult(a), toResult(b)],
      endedAtMs: Math.max(0, now - this.t0Wall),
    };
    return [{ type: "ended", result: this.result }];
  }

  private playerById(id: PlayerId): PlayerState | undefined {
    return this.players[0].id === id
      ? this.players[0]
      : this.players[1].id === id
        ? this.players[1]
        : undefined;
  }

  private opponentOf(id: PlayerId): PlayerState {
    return this.players[0].id === id ? this.players[1] : this.players[0];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// small pure helpers
// ─────────────────────────────────────────────────────────────────────────────

function makePlayer(seed: PlayerSeed): PlayerState {
  return {
    id: seed.id,
    kind: seed.kind,
    connected: true,
    disconnectedAtWall: null,
    guessCount: 0,
    bestWarmth: 0,
    solvedAtMs: null,
  };
}

function toResult(p: PlayerState): PlayerResult {
  return {
    id: p.id,
    kind: p.kind,
    solvedAtMs: p.solvedAtMs,
    bestWarmth: p.bestWarmth,
    guessCount: p.guessCount,
  };
}

/** Winner among (possibly) solved players — earliest solve time wins. */
function pickBySolveTime(a: PlayerState, b: PlayerState): PlayerId | null {
  if (a.solvedAtMs !== null && b.solvedAtMs !== null) {
    if (a.solvedAtMs < b.solvedAtMs) return a.id;
    if (b.solvedAtMs < a.solvedAtMs) return b.id;
    return null; // dead heat (server processes sequentially, so effectively unreachable)
  }
  if (a.solvedAtMs !== null) return a.id;
  if (b.solvedAtMs !== null) return b.id;
  return null;
}
