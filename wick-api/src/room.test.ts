import { describe, it, expect } from "vitest";
import {
  Room,
  normalizeWord,
  DEFAULT_ROOM_CONFIG,
  type RoomSeed,
  type MatchResult,
} from "./room.js";

const T0 = 1_000_000; // arbitrary fixed epoch-ms start
const CAP = DEFAULT_ROOM_CONFIG.capMs; // 5 min
const GRACE = DEFAULT_ROOM_CONFIG.reconnectGraceMs; // 15 s

function seed(overrides: Partial<RoomSeed> = {}): RoomSeed {
  return {
    roomId: "r1",
    mode: "casual",
    secret: "ember",
    players: [
      { id: "A", kind: "human" },
      { id: "B", kind: "human" },
    ],
    now: T0,
    ...overrides,
  };
}

function endedResult(evts: { type: string }[]): MatchResult {
  const e = evts.find((x) => x.type === "ended") as { type: "ended"; result: MatchResult } | undefined;
  if (!e) throw new Error("no ended event");
  return e.result;
}

describe("normalizeWord", () => {
  it("is case- and whitespace-insensitive", () => {
    expect(normalizeWord("  EmBer ")).toBe("ember");
    expect(normalizeWord("two  words")).toBe("two words");
  });
  it("preserves diacritics (é ≠ e)", () => {
    expect(normalizeWord("café")).not.toBe(normalizeWord("cafe"));
  });
});

describe("construction guards", () => {
  it("rejects duplicate player ids", () => {
    expect(() =>
      new Room(seed({ players: [{ id: "A", kind: "human" }, { id: "A", kind: "human" }] })),
    ).toThrow();
  });
  it("rejects an empty secret", () => {
    expect(() => new Room(seed({ secret: "   " }))).toThrow();
  });
});

describe("first-solve win (FR-31) with server-stamped time (C8)", () => {
  it("first correct guess ends the match and wins", () => {
    const room = new Room(seed());
    const evts = room.applyGuess({ playerId: "B", guess: "Ember", now: T0 + 4200 });
    const res = endedResult(evts);
    expect(res.reason).toBe("solved");
    expect(res.winner).toBe("B");
    expect(res.draw).toBe(false);
    // Solve time is server-stamped relative to t0, not client-reported.
    const b = res.players.find((p) => p.id === "B")!;
    expect(b.solvedAtMs).toBe(4200);
    expect(b.bestWarmth).toBe(1);
    expect(room.isActive()).toBe(false);
  });

  it("ignores a second solve after the match has ended", () => {
    const room = new Room(seed());
    room.applyGuess({ playerId: "A", guess: "ember", now: T0 + 1000 });
    const evts = room.applyGuess({ playerId: "B", guess: "ember", now: T0 + 1200 });
    expect(evts.find((e) => e.type === "ended")).toBeUndefined();
    expect(room.getResult()!.winner).toBe("A");
  });

  it("incorrect guesses count but do not win", () => {
    const room = new Room(seed());
    const evts = room.applyGuess({ playerId: "A", guess: "flame", warmth: 0.6, now: T0 + 500 });
    expect(evts.some((e) => e.type === "ended")).toBe(false);
    const snap = room.snapshotFor("B", T0 + 500);
    expect(snap.opponent.guessCount).toBe(1);
    expect(snap.opponent.bestWarmth).toBeCloseTo(0.6);
    expect(snap.opponent.solved).toBe(false);
  });
});

describe("time cap → warmest-best-guess tie-break (FR-31/FR-33)", () => {
  it("at the cap the warmer player wins", () => {
    const room = new Room(seed());
    room.applyGuess({ playerId: "A", guess: "flame", warmth: 0.42, now: T0 + 1000 });
    room.applyGuess({ playerId: "B", guess: "spark", warmth: 0.71, now: T0 + 2000 });
    const evts = room.tick(T0 + CAP);
    const res = endedResult(evts);
    expect(res.reason).toBe("timeout");
    expect(res.winner).toBe("B");
  });

  it("exact warmth tie at the cap is a draw", () => {
    const room = new Room(seed());
    room.applyProgress({ playerId: "A", warmth: 0.5, now: T0 + 1000 });
    room.applyProgress({ playerId: "B", warmth: 0.5, now: T0 + 1000 });
    const res = endedResult(room.tick(T0 + CAP + 1));
    expect(res.reason).toBe("timeout");
    expect(res.winner).toBeNull();
    expect(res.draw).toBe(true);
  });

  it("does not resolve before the cap", () => {
    const room = new Room(seed());
    expect(room.tick(T0 + CAP - 1)).toEqual([]);
    expect(room.isActive()).toBe(true);
  });

  it("warmth is monotonic (a later colder report cannot lower best)", () => {
    const room = new Room(seed());
    room.applyProgress({ playerId: "A", warmth: 0.8, now: T0 + 100 });
    room.applyProgress({ playerId: "A", warmth: 0.2, now: T0 + 200 });
    expect(room.snapshotFor("A", T0 + 200).you.bestWarmth).toBeCloseTo(0.8);
  });

  it("clamps out-of-range warmth to [0,1]", () => {
    const room = new Room(seed());
    room.applyProgress({ playerId: "A", warmth: 5, now: T0 + 100 });
    room.applyProgress({ playerId: "B", warmth: -3, now: T0 + 100 });
    expect(room.snapshotFor("A", T0 + 100).you.bestWarmth).toBe(1);
    expect(room.snapshotFor("B", T0 + 100).you.bestWarmth).toBe(0);
  });
});

describe("disconnect resolution (FR-17, OD-8 grace)", () => {
  it("notifies the opponent on drop but does not end during grace", () => {
    const room = new Room(seed());
    const evts = room.applyDisconnect({ playerId: "A", now: T0 + 1000 });
    expect(evts.some((e) => e.type === "opponentLeft")).toBe(true);
    expect(evts.some((e) => e.type === "ended")).toBe(false);
    expect(room.isActive()).toBe(true);
  });

  it("reconnect within grace resumes the match", () => {
    const room = new Room(seed());
    room.applyDisconnect({ playerId: "A", now: T0 + 1000 });
    const evts = room.applyReconnect({ playerId: "A", now: T0 + 1000 + GRACE - 1 });
    expect(evts.some((e) => e.type === "state")).toBe(true);
    expect(room.isActive()).toBe(true);
    expect(room.snapshotFor("B", T0 + 1000 + GRACE - 1).opponent.connected).toBe(true);
  });

  it("grace expiry forfeits to the remaining player", () => {
    const room = new Room(seed());
    room.applyDisconnect({ playerId: "A", now: T0 + 1000 });
    const res = endedResult(room.tick(T0 + 1000 + GRACE));
    expect(res.reason).toBe("forfeit");
    expect(res.winner).toBe("B");
  });

  it("reconnect after grace is too late (forfeit stands)", () => {
    const room = new Room(seed());
    room.applyDisconnect({ playerId: "A", now: T0 + 1000 });
    const evts = room.applyReconnect({ playerId: "A", now: T0 + 1000 + GRACE + 5 });
    // The reconnect call itself triggers resolveDue → forfeit.
    expect(endedResult(evts).reason).toBe("forfeit");
    expect(room.getResult()!.winner).toBe("B");
  });

  it("both players gone past grace → void (no winner)", () => {
    const room = new Room(seed());
    room.applyDisconnect({ playerId: "A", now: T0 + 1000 });
    room.applyDisconnect({ playerId: "B", now: T0 + 1000 });
    const res = endedResult(room.tick(T0 + 1000 + GRACE));
    expect(res.reason).toBe("void");
    expect(res.winner).toBeNull();
    expect(res.draw).toBe(true);
  });

  it("a solve during grace still wins (solve beats a pending forfeit)", () => {
    const room = new Room(seed());
    room.applyDisconnect({ playerId: "B", now: T0 + 1000 });
    const res = endedResult(room.applyGuess({ playerId: "A", guess: "ember", now: T0 + 1000 + 5 }));
    expect(res.reason).toBe("solved");
    expect(res.winner).toBe("A");
  });
});

describe("bot opponent labelling (FR-13/C9) carries into the result", () => {
  it("keeps the opponentKind honest post-match", () => {
    const room = new Room(seed({ players: [
      { id: "A", kind: "human" },
      { id: "BOT", kind: "bot" },
    ] }));
    expect(room.snapshotFor("A", T0).opponent.kind).toBe("bot");
    const res = endedResult(room.applyGuess({ playerId: "A", guess: "ember", now: T0 + 900 }));
    expect(res.players.find((p) => p.id === "BOT")!.kind).toBe("bot");
  });
});

describe("secret never leaks (FR-4)", () => {
  it("is absent from snapshots and results (deep scan)", () => {
    const room = new Room(seed({ secret: "ember" }));
    room.applyGuess({ playerId: "A", guess: "flame", warmth: 0.3, now: T0 + 100 });
    const res = endedResult(room.tick(T0 + CAP));
    const blob = JSON.stringify({
      snapA: room.snapshotFor("A", T0 + CAP),
      snapB: room.snapshotFor("B", T0 + CAP),
      res,
    });
    expect(blob.toLowerCase()).not.toContain("ember");
  });
});

describe("clock view", () => {
  it("remaining never goes negative and elapsed is server-relative", () => {
    const room = new Room(seed());
    const snap = room.snapshotFor("A", T0 + CAP + 99999);
    expect(snap.clock.remainingMs).toBe(0);
    expect(snap.clock.elapsedMs).toBe(CAP + 99999);
    expect(snap.clock.capMs).toBe(CAP);
  });
});

describe("unlimited free guesses (FR-32)", () => {
  it("accepts many guesses with no cap on count", () => {
    const room = new Room(seed());
    for (let i = 0; i < 50; i++) {
      room.applyGuess({ playerId: "A", guess: `wrong${i}`, warmth: i / 100, now: T0 + i });
    }
    expect(room.snapshotFor("B", T0 + 60).opponent.guessCount).toBe(50);
    expect(room.isActive()).toBe(true);
  });
});
