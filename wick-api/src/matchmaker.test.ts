import { describe, it, expect } from "vitest";
import { Matchmaker, DEFAULT_MATCHMAKER_CONFIG, type MatchmakerDeps } from "./matchmaker.js";
import { Metrics } from "./metrics.js";

const WAIT = DEFAULT_MATCHMAKER_CONFIG.botFillWaitMs; // 10 s
const T0 = 2_000_000;

function make(overrides: Partial<MatchmakerDeps> = {}): Matchmaker {
  let word = 0;
  return new Matchmaker({
    wordProvider: () => ["ember", "flame", "spark", "cinder"][word++ % 4]!,
    ...overrides,
  });
}

describe("random queue pairing (FR-9/FR-15)", () => {
  it("first player waits, second pairs immediately", () => {
    const mm = make();
    expect(mm.enqueue({ playerId: "A", mode: "casual", now: T0 })).toBeNull();
    expect(mm.isWaiting("A")).toBe(true);

    const pairing = mm.enqueue({ playerId: "B", mode: "casual", now: T0 + 500 });
    expect(pairing).not.toBeNull();
    expect(pairing!.origin).toBe("random");
    expect(pairing!.players.map((p) => p.id).sort()).toEqual(["A", "B"]);
    expect(pairing!.players.every((p) => p.kind === "human")).toBe(true);
    expect(pairing!.secret).toBeTruthy();
    expect(pairing!.botSeed).toBeUndefined();
    // Both dequeued.
    expect(mm.isWaiting("A")).toBe(false);
    expect(mm.waitingCount("casual")).toBe(0);
  });

  it("re-enqueue by a waiting player is idempotent (no self-pair, no double-add)", () => {
    const mm = make();
    mm.enqueue({ playerId: "A", mode: "casual", now: T0 });
    expect(mm.enqueue({ playerId: "A", mode: "casual", now: T0 + 100 })).toBeNull();
    expect(mm.waitingCount("casual")).toBe(1);
  });

  it("casual and ranked are separate lanes", () => {
    const mm = make();
    mm.enqueue({ playerId: "A", mode: "casual", now: T0 });
    expect(mm.enqueue({ playerId: "B", mode: "ranked", now: T0 })).toBeNull();
    expect(mm.waitingCount("casual")).toBe(1);
    expect(mm.waitingCount("ranked")).toBe(1);
  });

  it("assigns a fresh room id and word per match", () => {
    const mm = make();
    mm.enqueue({ playerId: "A", mode: "casual", now: T0 });
    const p1 = mm.enqueue({ playerId: "B", mode: "casual", now: T0 })!;
    mm.enqueue({ playerId: "C", mode: "casual", now: T0 });
    const p2 = mm.enqueue({ playerId: "D", mode: "casual", now: T0 })!;
    expect(p1.roomId).not.toBe(p2.roomId);
  });
});

describe("friend codes (FR-9) — private, no bot, no random pairing", () => {
  it("host waits on a code; a different player joining it pairs them", () => {
    const mm = make();
    expect(mm.enqueue({ playerId: "A", mode: "casual", friendCode: "wk-777", now: T0 })).toBeNull();
    expect(mm.openFriendCodes()).toContain("WK-777"); // normalized upper

    const pairing = mm.enqueue({ playerId: "B", mode: "casual", friendCode: "WK-777", now: T0 + 3000 });
    expect(pairing).not.toBeNull();
    expect(pairing!.origin).toBe("friend");
    expect(pairing!.players.map((p) => p.id).sort()).toEqual(["A", "B"]);
    expect(pairing!.botSeed).toBeUndefined();
    expect(mm.openFriendCodes()).not.toContain("WK-777");
  });

  it("host re-presenting their own code keeps waiting (no self-pair)", () => {
    const mm = make();
    mm.enqueue({ playerId: "A", mode: "casual", friendCode: "ABC", now: T0 });
    expect(mm.enqueue({ playerId: "A", mode: "casual", friendCode: "ABC", now: T0 + 10 })).toBeNull();
    expect(mm.openFriendCodes()).toEqual(["ABC"]);
  });

  it("friend rooms are never bot-filled, however long they wait", () => {
    const mm = make();
    mm.enqueue({ playerId: "A", mode: "casual", friendCode: "ABC", now: T0 });
    const filled = mm.tick(T0 + WAIT * 100);
    expect(filled).toEqual([]);
    expect(mm.isWaiting("A")).toBe(true);
  });
});

describe("friend invite host lookup + TTL (3.1)", () => {
  it("friendRoomHost reports the open host (case-insensitive), cleared on pairing", () => {
    const mm = make();
    expect(mm.friendRoomHost("abc")).toBeUndefined();
    mm.enqueue({ playerId: "A", mode: "casual", friendCode: "ABC", now: T0 });
    expect(mm.friendRoomHost("abc")).toBe("A"); // raw code, normalized internally
    mm.enqueue({ playerId: "B", mode: "casual", friendCode: "ABC", now: T0 + 1 });
    expect(mm.friendRoomHost("ABC")).toBeUndefined(); // paired → code freed
  });

  it("sweeps an abandoned friend invite once the TTL elapses", () => {
    const mm = make();
    mm.enqueue({ playerId: "A", mode: "casual", friendCode: "ABC", now: T0 });
    // Just before the TTL: still open.
    mm.tick(T0 + DEFAULT_MATCHMAKER_CONFIG.friendRoomTtlMs - 1);
    expect(mm.isWaiting("A")).toBe(true);
    // At the TTL: swept.
    mm.tick(T0 + DEFAULT_MATCHMAKER_CONFIG.friendRoomTtlMs);
    expect(mm.isWaiting("A")).toBe(false);
    expect(mm.openFriendCodes()).toEqual([]);
  });

  it("records the invite funnel: created → joined, and expired on sweep (3.1)", () => {
    const metrics = new Metrics();
    const mm = make({ metrics });
    // Host creates.
    mm.enqueue({ playerId: "A", mode: "casual", friendCode: "ABC", now: T0 });
    expect(metrics.get("invite.created.race")).toBe(1);
    // Friend joins → paired.
    mm.enqueue({ playerId: "B", mode: "casual", friendCode: "ABC", now: T0 + 1 });
    expect(metrics.get("invite.joined.race")).toBe(1);
    // A second, abandoned invite expires on the TTL sweep.
    mm.enqueue({ playerId: "C", mode: "casual", friendCode: "XYZ", now: T0 + 2 });
    mm.tick(T0 + 2 + DEFAULT_MATCHMAKER_CONFIG.friendRoomTtlMs);
    expect(metrics.get("invite.expired.race")).toBe(1);
    expect(metrics.get("invite.created")).toBe(2); // ABC + XYZ
  });
});

describe("bot-fill (FR-13, OD-3)", () => {
  it("does not fill before the wait elapses", () => {
    const mm = make();
    mm.enqueue({ playerId: "A", mode: "casual", now: T0 });
    expect(mm.tick(T0 + WAIT - 1)).toEqual([]);
    expect(mm.isWaiting("A")).toBe(true);
  });

  it("fills a lone casual waiter at the deadline with a disclosed bot", () => {
    const mm = make();
    mm.enqueue({ playerId: "A", mode: "casual", now: T0 });
    const filled = mm.tick(T0 + WAIT);
    expect(filled).toHaveLength(1);
    const p = filled[0]!;
    expect(p.origin).toBe("bot");
    expect(p.botSeed).toBeTypeOf("number");
    const human = p.players.find((x) => x.kind === "human")!;
    const bot = p.players.find((x) => x.kind === "bot")!;
    expect(human.id).toBe("A");
    expect(bot).toBeDefined();
    expect(mm.isWaiting("A")).toBe(false);
  });

  it("NEVER bot-fills ranked (FR-13) — ranked waiter keeps waiting", () => {
    const mm = make();
    mm.enqueue({ playerId: "A", mode: "ranked", now: T0 });
    const filled = mm.tick(T0 + WAIT * 10);
    expect(filled).toEqual([]);
    expect(mm.isWaiting("A")).toBe(true);
    expect(mm.waitingCount("ranked")).toBe(1);
  });

  it("a human partner arriving before the deadline pre-empts the bot", () => {
    const mm = make();
    mm.enqueue({ playerId: "A", mode: "casual", now: T0 });
    const pairing = mm.enqueue({ playerId: "B", mode: "casual", now: T0 + WAIT - 1 });
    expect(pairing!.origin).toBe("random");
    // Nothing left for the tick to bot-fill.
    expect(mm.tick(T0 + WAIT + 5)).toEqual([]);
  });
});

describe("cancel", () => {
  it("removes a random-queue waiter", () => {
    const mm = make();
    mm.enqueue({ playerId: "A", mode: "casual", now: T0 });
    mm.cancel("A");
    expect(mm.isWaiting("A")).toBe(false);
    expect(mm.tick(T0 + WAIT * 5)).toEqual([]);
  });

  it("drops a friend room hosted by the canceller", () => {
    const mm = make();
    mm.enqueue({ playerId: "A", mode: "casual", friendCode: "XYZ", now: T0 });
    mm.cancel("A");
    expect(mm.openFriendCodes()).toEqual([]);
  });
});

describe("determinism", () => {
  it("injected providers make room ids and bot seeds reproducible", () => {
    const build = () => {
      let r = 0;
      let s = 0;
      const mm = new Matchmaker({
        wordProvider: () => "ember",
        roomIdProvider: () => `R${++r}`,
        botSeedProvider: () => 100 + ++s,
      });
      mm.enqueue({ playerId: "A", mode: "casual", now: T0 });
      return mm.tick(T0 + WAIT)[0]!;
    };
    const a = build();
    const b = build();
    expect(a.roomId).toBe("R1");
    expect(a.botSeed).toBe(101);
    expect(a).toEqual(b);
  });
});

describe("shared start times (3.3)", () => {
  const SLOT = 120_000;
  const MIN = 15_000;
  const mk = () => make({ config: { startSlotMs: SLOT, minWaitMs: MIN } });

  it("schedules a lone casual player for the next slot boundary", () => {
    const mm = mk();
    expect(mm.enqueue({ playerId: "a", mode: "casual", now: 10_000 })).toBeNull();
    expect(mm.startAtFor("a")).toBe(120_000);
  });

  it("pushes a player who queues just before a boundary to the following slot", () => {
    const mm = mk();
    mm.enqueue({ playerId: "a", mode: "casual", now: 110_000 }); // 10 s before 120 s
    expect(mm.startAtFor("a")).toBe(240_000);
  });

  it("pairs two humans who arrive a minute apart, before the slot", () => {
    const mm = mk();
    expect(mm.enqueue({ playerId: "a", mode: "casual", now: 10_000 })).toBeNull();
    expect(mm.tick(60_000)).toEqual([]); // still alone, slot not reached
    const p = mm.enqueue({ playerId: "b", mode: "casual", now: 70_000 });
    expect(p?.origin).toBe("random");
    expect(mm.startAtFor("a")).toBeNull();
  });

  it("bot-fills a lone player only once the slot arrives", () => {
    const mm = mk();
    mm.enqueue({ playerId: "a", mode: "casual", now: 10_000 });
    expect(mm.tick(119_999)).toEqual([]);
    const out = mm.tick(120_000);
    expect(out).toHaveLength(1);
    expect(out[0]!.origin).toBe("bot");
  });

  it("friend rooms have no schedule", () => {
    const mm = mk();
    mm.enqueue({ playerId: "a", mode: "casual", friendCode: "ABCDE", now: 10_000 });
    expect(mm.startAtFor("a")).toBeNull();
  });
});
