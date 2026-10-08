//
//  matchmaker.ts — pairs waiting players into matches (SRS FR-9/13/15, SDS §3/§5).
//
//  Three ways into a match:
//   1. Random queue (FR-9): two waiting players of the same mode are paired FIFO.
//      The casual pool is ALL players (free + Pro) — live play is free precisely
//      to keep this pool large (FR-15).
//   2. Friend code (FR-9): a private room keyed by a shared code — first player
//      waits, the second to present the code joins. No random pairing, no bot.
//   3. Bounded-wait bot-fill (FR-13, OD-3 ~10 s — NOT yet confirmed by Jason):
//      a *casual* player who finds no human within the wait is paired with a
//      disclosed bot so a match still starts. RANKED IS NEVER BOT-FILLED (FR-13);
//      ranked itself is phase 2 (entitlement-gated), so this module only leaves
//      the seam — it will happily queue "ranked" and pair ranked-with-ranked, but
//      never fills ranked with a bot.
//
//  Pure & deterministic: no wall clock, no global RNG. `now` is passed in; room
//  ids, bot seeds, and the secret word all come from injected providers so the
//  word list stays OUT of this module (the server owns the small multiplayer word
//  pool — never a single-player daily word, so the C1 moat holds). The server
//  polls `tick(now)` to trigger bot-fill for waiters past their deadline.
//

import type { MatchMode, PlayerSeed } from "./room.js";
import { Metrics } from "./metrics.js";

/** A formed match the server should turn into a Room (and, if `botSeed` is set,
 *  a Bot driving the bot seat). */
export interface Pairing {
  roomId: string;
  mode: MatchMode;
  /** The answer for this match, from the injected word provider. Held server-side. */
  secret: string;
  /** Exactly two seats with honesty labels (FR-13/C9). */
  players: [PlayerSeed, PlayerSeed];
  /** Present iff one seat is a bot — the deterministic seed for its play. */
  botSeed?: number;
  /** How the pairing came about (useful for the server + tests). */
  origin: "random" | "friend" | "bot";
}

export interface MatchmakerConfig {
  /** Wait before a lone casual player is offered a bot (FR-13, OD-3). Default 10 s.
   *  Only used when `startSlotMs` is 0 (the legacy per-player wait). */
  botFillWaitMs: number;
  /** 3.3 shared start times. When > 0, casual Quick Match players all wait for
   *  the next wall-clock slot boundary (every `startSlotMs`) instead of a
   *  private timer, so two people who open the app a minute apart still land
   *  in the same race. A lone player past their slot gets the bot. 0 = off. */
  startSlotMs: number;
  /** With shared slots: a player who queues less than this before a boundary is
   *  pushed to the following slot, so nobody gets bot-filled 1 s after tapping. */
  minWaitMs: number;
  /** How long an unjoined friend invite stays open before it's swept (3.1). A host
   *  who never gets a joiner shouldn't hold a code forever. Default 30 min. */
  friendRoomTtlMs: number;
}

export const DEFAULT_MATCHMAKER_CONFIG: MatchmakerConfig = {
  botFillWaitMs: 10_000,
  startSlotMs: 0,
  minWaitMs: 15_000,
  friendRoomTtlMs: 30 * 60_000,
};

export interface MatchmakerDeps {
  /** Supplies the secret word for a new match. The server injects this so the
   *  word pool lives outside this module. */
  wordProvider: () => string;
  /** Unique room id per match. Defaults to a deterministic counter (tests);
   *  production injects a random/opaque id. */
  roomIdProvider?: () => string;
  /** Deterministic bot seed per bot-filled match. Defaults to a counter. */
  botSeedProvider?: () => number;
  config?: Partial<MatchmakerConfig>;
  /** Invite-funnel counters (3.1). Defaults to a throwaway instance. */
  metrics?: Metrics;
}

interface QueueEntry {
  playerId: string;
  enqueuedAtWall: number;
  /** Wall time at which this waiter is bot-filled if still alone (casual only). */
  startAtWall: number;
}

interface FriendRoom {
  code: string;
  hostId: string;
  createdAtWall: number;
}

export class Matchmaker {
  readonly config: MatchmakerConfig;
  private readonly wordProvider: () => string;
  private readonly nextRoomId: () => string;
  private readonly nextBotSeed: () => number;
  private readonly metrics: Metrics;

  /** FIFO random-queue, per mode. Invariant: at most one entry per mode survives
   *  an enqueue (a partner present ⇒ immediate pairing). */
  private readonly queues: Map<MatchMode, QueueEntry[]> = new Map();
  /** Open friend rooms awaiting a second player, keyed by code. */
  private readonly friendRooms: Map<string, FriendRoom> = new Map();

  constructor(deps: MatchmakerDeps) {
    this.config = { ...DEFAULT_MATCHMAKER_CONFIG, ...(deps.config ?? {}) };
    this.wordProvider = deps.wordProvider;

    let roomCounter = 0;
    this.nextRoomId = deps.roomIdProvider ?? (() => `room-${++roomCounter}`);
    let seedCounter = 0;
    this.nextBotSeed = deps.botSeedProvider ?? (() => ++seedCounter);
    this.metrics = deps.metrics ?? new Metrics();
  }

  /**
   * Put a player into matchmaking. Returns a `Pairing` if a partner was already
   * waiting (paired immediately), otherwise `null` (the player is now waiting).
   * Idempotent for a player already waiting in the same lane.
   */
  enqueue(args: {
    playerId: string;
    mode: MatchMode;
    friendCode?: string;
    now: number;
  }): Pairing | null {
    const { playerId, mode, now } = args;
    const friendCode = normalizeCode(args.friendCode);

    if (friendCode) return this.enqueueFriend(playerId, mode, friendCode, now);
    return this.enqueueRandom(playerId, mode, now);
  }

  private enqueueRandom(playerId: string, mode: MatchMode, now: number): Pairing | null {
    const q = this.queue(mode);

    // Already waiting? Idempotent — do not double-add or self-pair.
    if (q.some((e) => e.playerId === playerId)) return null;

    // Pair with the earliest different waiter.
    const partnerIdx = q.findIndex((e) => e.playerId !== playerId);
    if (partnerIdx >= 0) {
      const [partner] = q.splice(partnerIdx, 1);
      return this.makePairing({
        mode,
        origin: "random",
        players: [
          { id: partner!.playerId, kind: "human" },
          { id: playerId, kind: "human" },
        ],
      });
    }

    q.push({ playerId, enqueuedAtWall: now, startAtWall: this.startAt(now) });
    return null;
  }

  /** When a player queued at `now` would start if nobody shows up: the next
   *  shared slot boundary at least `minWaitMs` away, or the legacy private wait. */
  startAt(now: number): number {
    const { startSlotMs, minWaitMs, botFillWaitMs } = this.config;
    if (startSlotMs <= 0) return now + botFillWaitMs;
    const earliest = now + minWaitMs;
    return Math.ceil(earliest / startSlotMs) * startSlotMs;
  }

  /** The scheduled start for a waiting player, or null if they are not in a
   *  random queue (friend rooms have no schedule). */
  startAtFor(playerId: string): number | null {
    for (const q of this.queues.values()) {
      const e = q.find((x) => x.playerId === playerId);
      if (e) return e.startAtWall;
    }
    return null;
  }

  private enqueueFriend(
    playerId: string,
    mode: MatchMode,
    code: string,
    now: number,
  ): Pairing | null {
    const room = this.friendRooms.get(code);
    if (!room) {
      this.friendRooms.set(code, { code, hostId: playerId, createdAtWall: now });
      this.metrics.invite("created", "race");
      return null;
    }
    if (room.hostId === playerId) return null; // host re-presenting the code — still waiting

    this.friendRooms.delete(code);
    this.metrics.invite("joined", "race");
    return this.makePairing({
      mode,
      origin: "friend",
      players: [
        { id: room.hostId, kind: "human" },
        { id: playerId, kind: "human" },
      ],
    });
  }

  /**
   * Advance time. Any *casual* waiter past `botFillWaitMs` is paired with a bot
   * (FR-13). Ranked waiters are never bot-filled and keep waiting. Friend rooms
   * never bot-fill. Returns every pairing formed this tick.
   */
  tick(now: number): Pairing[] {
    const out: Pairing[] = [];

    // Defensive: pair any two same-mode humans that somehow both lingered.
    for (const [mode, q] of this.queues) {
      while (q.length >= 2) {
        const a = q.shift()!;
        const b = q.shift()!;
        out.push(
          this.makePairing({
            mode,
            origin: "random",
            players: [
              { id: a.playerId, kind: "human" },
              { id: b.playerId, kind: "human" },
            ],
          }),
        );
      }
    }

    // Bot-fill lone CASUAL waiters past the deadline.
    const casual = this.queues.get("casual");
    if (casual) {
      const remaining: QueueEntry[] = [];
      for (const entry of casual) {
        if (now >= entry.startAtWall) {
          out.push(
            this.makePairing({
              mode: "casual",
              origin: "bot",
              players: [
                { id: entry.playerId, kind: "human" },
                { id: `bot:${entry.playerId}`, kind: "bot" },
              ],
              withBot: true,
            }),
          );
        } else {
          remaining.push(entry);
        }
      }
      this.queues.set("casual", remaining);
    }

    // Sweep abandoned friend invites (a host who never got a joiner) past their TTL
    // so codes don't leak forever (3.1). Disconnect already drops a host's room;
    // this covers a host who stays connected but is never joined.
    for (const [code, room] of this.friendRooms) {
      if (now - room.createdAtWall >= this.config.friendRoomTtlMs) {
        this.friendRooms.delete(code);
        this.metrics.invite("expired", "race");
      }
    }

    return out;
  }

  /** Remove a player from any random queue and drop any friend room they host. */
  cancel(playerId: string): void {
    for (const [mode, q] of this.queues) {
      this.queues.set(
        mode,
        q.filter((e) => e.playerId !== playerId),
      );
    }
    for (const [code, room] of this.friendRooms) {
      if (room.hostId === playerId) this.friendRooms.delete(code);
    }
  }

  // ── introspection (tests / ops) ─────────────────────────────────────────────

  waitingCount(mode: MatchMode): number {
    return this.queue(mode).length;
  }

  isWaiting(playerId: string): boolean {
    for (const q of this.queues.values()) {
      if (q.some((e) => e.playerId === playerId)) return true;
    }
    for (const room of this.friendRooms.values()) {
      if (room.hostId === playerId) return true;
    }
    return false;
  }

  openFriendCodes(): string[] {
    return [...this.friendRooms.keys()];
  }

  /** The host currently waiting on a friend code, or undefined if none is open.
   *  Lets the hub tell CREATE (code must be free → else `code_taken`) apart from
   *  JOIN (code must be live → else `no_such_invite`) for 3.1 invite links. Uses the
   *  same normalization as `enqueue`, so callers pass the raw code. */
  friendRoomHost(code: string): string | undefined {
    const norm = normalizeCode(code);
    return norm ? this.friendRooms.get(norm)?.hostId : undefined;
  }

  // ── internals ────────────────────────────────────────────────────────────────

  private queue(mode: MatchMode): QueueEntry[] {
    let q = this.queues.get(mode);
    if (!q) {
      q = [];
      this.queues.set(mode, q);
    }
    return q;
  }

  private makePairing(args: {
    mode: MatchMode;
    origin: Pairing["origin"];
    players: [PlayerSeed, PlayerSeed];
    withBot?: boolean;
  }): Pairing {
    const pairing: Pairing = {
      roomId: this.nextRoomId(),
      mode: args.mode,
      secret: this.wordProvider(),
      players: args.players,
      origin: args.origin,
    };
    if (args.withBot) pairing.botSeed = this.nextBotSeed();
    return pairing;
  }
}

function normalizeCode(code: string | undefined): string | undefined {
  if (!code) return undefined;
  const t = code.trim().toUpperCase();
  return t.length ? t : undefined;
}
