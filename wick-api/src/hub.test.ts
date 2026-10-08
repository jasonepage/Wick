import { describe, it, expect, beforeEach } from "vitest";
import { MatchHub, type Client } from "./hub.js";
import type { ServerFrame } from "./protocol.js";
import { Bot } from "./bot.js";
import { DEFAULT_ROOM_CONFIG } from "./room.js";
import { DEFAULT_MATCHMAKER_CONFIG } from "./matchmaker.js";
import { Metrics } from "./metrics.js";

const CAP = DEFAULT_ROOM_CONFIG.capMs;
const WAIT = DEFAULT_MATCHMAKER_CONFIG.botFillWaitMs;
const T0 = 3_000_000;

class Fake implements Client {
  frames: ServerFrame[] = [];
  closed = false;
  constructor(public id: string) {}
  send(f: ServerFrame): void {
    this.frames.push(f);
  }
  close(): void {
    this.closed = true;
  }
  last<T extends ServerFrame["t"]>(t: T): Extract<ServerFrame, { t: T }> | undefined {
    for (let i = this.frames.length - 1; i >= 0; i--) {
      if (this.frames[i]!.t === t) return this.frames[i] as Extract<ServerFrame, { t: T }>;
    }
    return undefined;
  }
  has(t: ServerFrame["t"]): boolean {
    return this.frames.some((f) => f.t === t);
  }
}

/** A bot seed that is guaranteed to solve, for deterministic bot-win tests. */
function solvingSeed(secret = "ember"): number {
  for (let s = 1; s < 5000; s++) if (new Bot({ secret, seed: s }).solves()) return s;
  throw new Error("no solving seed");
}

let clock = { t: T0 };
function makeHub(attestAllow = true) {
  clock = { t: T0 };
  let word = 0;
  return new MatchHub({
    now: () => clock.t,
    attest: () => attestAllow,
    matchmaker: {
      wordProvider: () => "ember",
      roomIdProvider: (() => {
        let n = 0;
        return () => `room-${++n}`;
      })(),
      botSeedProvider: () => solvingSeed(),
    },
  });
}

describe("two-human casual match", () => {
  let hub: MatchHub;
  let a: Fake;
  let b: Fake;
  beforeEach(() => {
    hub = makeHub();
    a = new Fake("A");
    b = new Fake("B");
    hub.connect(a);
    hub.connect(b);
  });

  it("pairs on the second queue and opens with state", () => {
    hub.receive(a, { t: "queue", mode: "casual" });
    expect(a.has("paired")).toBe(false); // still waiting
    hub.receive(b, { t: "queue", mode: "casual" });

    expect(a.last("paired")!.opponentKind).toBe("human");
    expect(b.last("paired")!.opponentKind).toBe("human");
    expect(a.has("state")).toBe(true);
    expect(b.has("state")).toBe(true);
    expect(hub.activeRoomCount()).toBe(1);
  });

  it("a solve ends the match, notifies both, and cleans up", () => {
    hub.receive(a, { t: "queue", mode: "casual" });
    hub.receive(b, { t: "queue", mode: "casual" });
    clock.t += 4000;
    hub.receive(b, { t: "guess", guess: "ember", warmth: 1 });

    const ra = a.last("result");
    const rb = b.last("result");
    expect(ra?.result.winner).toBe("B");
    expect(rb?.result.winner).toBe("B");
    expect(ra?.result.reason).toBe("solved");
    expect(hub.activeRoomCount()).toBe(0); // cleaned up
  });

  it("opponent progress reaches the other player's state (FR-8)", () => {
    hub.receive(a, { t: "queue", mode: "casual" });
    hub.receive(b, { t: "queue", mode: "casual" });
    hub.receive(a, { t: "question", warmth: 0.55 });
    const bView = b.last("state")!;
    expect(bView.state.opponent.bestWarmth).toBeCloseTo(0.55);
  });

  it("never leaks the secret mid-match, and reveals it only in the final result", () => {
    hub.receive(a, { t: "queue", mode: "casual" });
    hub.receive(b, { t: "queue", mode: "casual" });
    hub.receive(a, { t: "guess", guess: "flame", warmth: 0.4 });
    // Mid-match: the secret appears in NO frame.
    const midBlob = JSON.stringify([...a.frames, ...b.frames]).toLowerCase();
    expect(midBlob).not.toContain("ember");
    // End the match → the result frame (and only it) reveals the word.
    clock.t += CAP;
    hub.tick();
    expect(a.last("result")!.word).toBe("ember");
    expect(b.last("result")!.word).toBe("ember");
  });
});

describe("bot-fill (FR-13) end to end", () => {
  it("fills a lone casual player at the wait deadline with a disclosed bot", () => {
    const hub = makeHub();
    const a = new Fake("A");
    hub.connect(a);
    hub.receive(a, { t: "queue", mode: "casual" });

    clock.t = T0 + WAIT - 1;
    hub.tick();
    expect(a.has("paired")).toBe(false);

    clock.t = T0 + WAIT;
    hub.tick();
    expect(a.last("paired")!.opponentKind).toBe("bot");
    expect(hub.activeRoomCount()).toBe(1);
  });

  it("a solving bot eventually wins if the human is idle", () => {
    const hub = makeHub();
    const a = new Fake("A");
    hub.connect(a);
    hub.receive(a, { t: "queue", mode: "casual" });
    clock.t = T0 + WAIT;
    hub.tick(); // pairs with bot

    for (let t = 0; t <= CAP && hub.activeRoomCount() > 0; t += 500) {
      clock.t = T0 + WAIT + t;
      hub.tick();
    }
    const res = a.last("result");
    expect(res).toBeDefined();
    expect(res!.result.reason).toBe("solved");
    expect(res!.result.winner).toBe("bot:A");
  });
});

describe("friend codes", () => {
  it("pairs two players sharing a code, privately", () => {
    const hub = makeHub();
    const a = new Fake("A");
    const b = new Fake("B");
    hub.connect(a);
    hub.connect(b);
    hub.receive(a, { t: "queue", mode: "casual", friendCode: "PLAY-1" });
    expect(a.has("paired")).toBe(false);
    hub.receive(b, { t: "queue", mode: "casual", friendCode: "PLAY-1" });
    expect(a.last("paired")!.opponentKind).toBe("human");
    expect(b.last("paired")!.opponentKind).toBe("human");
  });
});

describe("friend invite intents (3.1 links)", () => {
  it("JOIN (create:false) an unknown code → no_such_invite, no match", () => {
    const hub = makeHub();
    const a = new Fake("A");
    hub.connect(a);
    hub.receive(a, { t: "queue", mode: "casual", friendCode: "NOPE", create: false });
    expect(a.last("error")!.code).toBe("no_such_invite");
    expect(a.has("paired")).toBe(false);
    expect(hub.activeRoomCount()).toBe(0);
  });

  it("CREATE (create:true) a code someone else is already hosting → code_taken", () => {
    const hub = makeHub();
    const a = new Fake("A");
    const b = new Fake("B");
    hub.connect(a);
    hub.connect(b);
    hub.receive(a, { t: "queue", mode: "casual", friendCode: "DUP", create: true }); // hosts
    hub.receive(b, { t: "queue", mode: "casual", friendCode: "DUP", create: true }); // collides
    expect(b.last("error")!.code).toBe("code_taken");
    expect(b.has("paired")).toBe(false);
    expect(hub.activeRoomCount()).toBe(0); // no cross-join
  });

  it("CREATE then JOIN pairs the two (host / join)", () => {
    const hub = makeHub();
    const a = new Fake("A");
    const b = new Fake("B");
    hub.connect(a);
    hub.connect(b);
    hub.receive(a, { t: "queue", mode: "casual", friendCode: "OK", create: true });
    expect(a.has("paired")).toBe(false); // hosting, waiting
    hub.receive(b, { t: "queue", mode: "casual", friendCode: "OK", create: false });
    expect(a.last("paired")!.opponentKind).toBe("human");
    expect(b.last("paired")!.opponentKind).toBe("human");
    expect(hub.activeRoomCount()).toBe(1);
  });

  it("the host re-presenting its own code with create:true keeps waiting (no self-collision)", () => {
    const hub = makeHub();
    const a = new Fake("A");
    hub.connect(a);
    hub.receive(a, { t: "queue", mode: "casual", friendCode: "MINE", create: true });
    hub.receive(a, { t: "queue", mode: "casual", friendCode: "MINE", create: true });
    expect(a.has("error")).toBe(false);
    expect(a.has("paired")).toBe(false);
  });
});

describe("disconnect / forfeit (FR-17)", () => {
  it("notifies the opponent and forfeits after grace", () => {
    const hub = makeHub();
    const a = new Fake("A");
    const b = new Fake("B");
    hub.connect(a);
    hub.connect(b);
    hub.receive(a, { t: "queue", mode: "casual" });
    hub.receive(b, { t: "queue", mode: "casual" });

    hub.disconnect(a);
    expect(b.has("opponentLeft")).toBe(true);
    expect(hub.activeRoomCount()).toBe(1); // still in grace

    clock.t = T0 + DEFAULT_ROOM_CONFIG.reconnectGraceMs;
    hub.tick();
    expect(b.last("result")!.result.reason).toBe("forfeit");
    expect(b.last("result")!.result.winner).toBe("B");
    expect(hub.activeRoomCount()).toBe(0);
  });

  it("reconnect within grace keeps the match alive", () => {
    const hub = makeHub();
    const a = new Fake("A");
    const b = new Fake("B");
    hub.connect(a);
    hub.connect(b);
    hub.receive(a, { t: "queue", mode: "casual" });
    hub.receive(b, { t: "queue", mode: "casual" });

    hub.disconnect(a);
    clock.t = T0 + 2000;
    const a2 = new Fake("A"); // same id reconnects
    hub.connect(a2);
    // Reconnecting re-issues the handshake so the client can resume (FR-17).
    expect(a2.has("paired")).toBe(true);
    expect(a2.has("state")).toBe(true);
    clock.t = T0 + DEFAULT_ROOM_CONFIG.reconnectGraceMs + 5000;
    hub.tick();
    // Still active (reconnected) — not forfeited by the grace check.
    expect(b.has("result")).toBe(false);
    expect(hub.activeRoomCount()).toBe(1);
  });
});

describe("guards", () => {
  it("rejects a guess when not in a match", () => {
    const hub = makeHub();
    const a = new Fake("A");
    hub.connect(a);
    hub.receive(a, { t: "guess", guess: "ember" });
    expect(a.last("error")!.code).toBe("no_match");
  });

  it("re-queue while already in a match RESUMES it (paired + state, no error)", () => {
    const hub = makeHub();
    const a = new Fake("A");
    const b = new Fake("B");
    hub.connect(a);
    hub.connect(b);
    hub.receive(a, { t: "queue", mode: "casual" });
    hub.receive(b, { t: "queue", mode: "casual" });

    const before = a.frames.length;
    hub.receive(a, { t: "queue", mode: "casual" }); // e.g. app relaunched, re-queues
    const after = a.frames.slice(before);
    expect(after.some((f) => f.t === "error")).toBe(false);
    expect(after.some((f) => f.t === "paired")).toBe(true);
    expect(after.some((f) => f.t === "state")).toBe(true);
    expect(hub.activeRoomCount()).toBe(1); // same match, not a new one
  });

  it("a failing attest gate errors and closes the socket (FR-16)", () => {
    const hub = makeHub(false);
    const a = new Fake("A");
    hub.connect(a);
    hub.receive(a, { t: "queue", mode: "casual" });
    expect(a.last("error")!.code).toBe("attest_failed");
    expect(a.closed).toBe(true);
  });
});

describe("server-authoritative warmth (live match, round 2)", () => {
  function hubWithScorer(
    scoreWarmth: (s: string, g: string) => Promise<{ score: number; rank?: number }>,
  ): MatchHub {
    clock = { t: T0 };
    return new MatchHub({
      now: () => clock.t,
      scoreWarmth,
      matchmaker: {
        wordProvider: () => "ember",
        roomIdProvider: (() => { let n = 0; return () => `room-${++n}`; })(),
        botSeedProvider: () => solvingSeed(),
      },
    });
  }
  const flush = () => new Promise((r) => setTimeout(r, 0));

  it("scores a non-solving guess server-side → `scored` to guesser + opponent progress", async () => {
    const hub = hubWithScorer(async (_s, g) => ({ score: g === "close" ? 70 : 12 }));
    const a = new Fake("A");
    const b = new Fake("B");
    hub.connect(a);
    hub.connect(b);
    hub.receive(a, { t: "queue", mode: "casual" });
    hub.receive(b, { t: "queue", mode: "casual" });

    hub.receive(a, { t: "guess", guess: "close" }); // not the secret
    // guess count is instant; warmth is async
    expect(b.last("state")!.state.opponent.guessCount).toBe(1);
    await flush();

    const scored = a.last("scored");
    expect(scored).toBeDefined();
    expect(scored!.guess).toBe("close");
    expect(scored!.score).toBe(70);
    expect(b.last("state")!.state.opponent.bestWarmth).toBeCloseTo(0.7);
  });

  it("rejects a non-word guess (notAWord) so it never counts", () => {
    const hub = hubWithScorer(async () => ({ score: 70 }));
    const a = new Fake("A");
    const b = new Fake("B");
    hub.connect(a);
    hub.connect(b);
    hub.receive(a, { t: "queue", mode: "casual" });
    hub.receive(b, { t: "queue", mode: "casual" });
    hub.receive(a, { t: "guess", guess: "zxqwv" }); // gibberish
    const scored = a.last("scored");
    expect(scored!.notAWord).toBe(true);
    expect(scored!.guess).toBe("zxqwv");
    // the opponent never sees a guess increment for a rejected non-word
    expect(b.last("state")?.state.opponent.guessCount ?? 0).toBe(0);
  });

  it("ignores client-reported warmth (server is authoritative)", async () => {
    const hub = hubWithScorer(async () => ({ score: 5 })); // server says cold…
    const a = new Fake("A");
    const b = new Fake("B");
    hub.connect(a);
    hub.connect(b);
    hub.receive(a, { t: "queue", mode: "casual" });
    hub.receive(b, { t: "queue", mode: "casual" });
    hub.receive(a, { t: "guess", guess: "sneaky", warmth: 0.99 }); // …client claims hot
    await flush();
    expect(a.last("scored")!.score).toBe(5);
    expect(b.last("state")!.state.opponent.bestWarmth).toBeCloseTo(0.05);
  });

  it("never scores the winning guess (solve is instant, no embedding wait)", async () => {
    let calls = 0;
    const hub = hubWithScorer(async () => { calls++; return { score: 50 }; });
    const a = new Fake("A");
    const b = new Fake("B");
    hub.connect(a);
    hub.connect(b);
    hub.receive(a, { t: "queue", mode: "casual" });
    hub.receive(b, { t: "queue", mode: "casual" });
    hub.receive(a, { t: "guess", guess: "ember" }); // exact solve
    await flush();
    expect(a.last("result")!.result.winner).toBe("A");
    expect(calls).toBe(0);
  });
});

describe("in-match Keeper (ask/answer, FR-19)", () => {
  function hubWithKeeper(
    answerKeeper: (s: string, q: string) => Promise<{ verdict: string; reply: string }>,
  ): MatchHub {
    clock = { t: T0 };
    return new MatchHub({
      now: () => clock.t,
      answerKeeper,
      matchmaker: {
        wordProvider: () => "ember",
        roomIdProvider: (() => { let n = 0; return () => `room-${++n}`; })(),
        botSeedProvider: () => solvingSeed(),
      },
    });
  }
  const flush = () => new Promise((r) => setTimeout(r, 0));

  it("answers only the asker, on the room secret, revealing nothing to the opponent", async () => {
    let sawSecret = "";
    const hub = hubWithKeeper(async (secret, q) => {
      sawSecret = secret;
      return { verdict: q.includes("alive") ? "No" : "Sort of", reply: "It isn't alive." };
    });
    const a = new Fake("A");
    const b = new Fake("B");
    hub.connect(a);
    hub.connect(b);
    hub.receive(a, { t: "queue", mode: "casual" });
    hub.receive(b, { t: "queue", mode: "casual" });

    hub.receive(a, { t: "ask", question: "is it alive?" });
    await flush();

    const ans = a.last("answer");
    expect(sawSecret).toBe("ember"); // Keeper ran on the real room secret
    expect(ans).toBeDefined();
    expect(ans!.verdict).toBe("No");
    expect(ans!.question).toBe("is it alive?");
    expect(b.has("answer")).toBe(false); // opponent learns nothing
    // and asking never moved the warmth bar (guesses only)
    expect(b.last("state")!.state.opponent.bestWarmth).toBe(0);
  });

  it("rejects an ask when not in a match", () => {
    const hub = hubWithKeeper(async () => ({ verdict: "No", reply: "" }));
    const a = new Fake("A");
    hub.connect(a);
    hub.receive(a, { t: "ask", question: "is it alive?" });
    expect(a.last("error")!.code).toBe("no_match");
  });
});

describe("Live Dare", () => {
  function dareHub(
    scoreWarmth?: (s: string, g: string) => Promise<{ score: number; rank?: number }>,
  ): MatchHub {
    clock = { t: T0 };
    return new MatchHub({
      now: () => clock.t,
      scoreWarmth: scoreWarmth ?? (async () => ({ score: 0 })),
      matchmaker: {
        wordProvider: () => "ember",
        roomIdProvider: (() => { let n = 0; return () => `room-${++n}`; })(),
        botSeedProvider: () => 1,
      },
    });
  }
  const flush = () => new Promise((r) => setTimeout(r, 0));

  it("rejects a setter's word that isn't a real word, before any code is registered", () => {
    clock = { t: T0 };
    const hub = new MatchHub({
      now: () => clock.t,
      // stand-in dictionary: only "library" is a word
      isPlayableSecret: (w) => w.toLowerCase() === "library",
      matchmaker: {
        wordProvider: () => "ember",
        roomIdProvider: (() => { let n = 0; return () => `room-${++n}`; })(),
        botSeedProvider: () => 1,
      },
    });
    const s = new Fake("S");
    const g = new Fake("G");
    hub.connect(s);
    hub.connect(g);

    hub.receive(s, { t: "dare", role: "setter", code: "PLAY-9", word: "zxcvbn" });
    expect(s.last("error")?.code).toBe("not_a_word");

    // and the code must NOT have been registered — a guesser joining it fails
    hub.receive(g, { t: "dare", role: "guesser", code: "PLAY-9" });
    expect(g.last("error")?.code).toBe("no_such_invite");

    // the same setter can immediately retry with a real word, and then the code
    // works — asserted on the outcome, since a success sends no frame that would
    // overwrite the earlier error.
    hub.receive(s, { t: "dare", role: "setter", code: "PLAY-9", word: "library" });
    hub.receive(g, { t: "dare", role: "guesser", code: "PLAY-9" });
    expect(g.has("dareStart")).toBe(true);
  });

  it("pairs a setter + guesser on a code; setter sees the word, guesser doesn't", () => {
    const hub = dareHub();
    const s = new Fake("S");
    const g = new Fake("G");
    hub.connect(s);
    hub.connect(g);
    hub.receive(s, { t: "dare", role: "setter", code: "PLAY-1", word: "library" });
    expect(s.has("dareStart")).toBe(false); // waiting for the guesser
    hub.receive(g, { t: "dare", role: "guesser", code: "play-1" }); // code case-insensitive

    expect(s.last("dareStart")!.role).toBe("setter");
    expect(g.last("dareStart")!.role).toBe("guesser");
    expect(s.last("dareState")!.state.word).toBe("library"); // setter sees it
    expect(g.last("dareState")!.state.word).toBeUndefined(); // guesser never does
    expect(hub.activeDareCount()).toBe(1);
  });

  it("scores the guesser's warmth server-side and streams it to both", async () => {
    const hub = dareHub(async (_s, gword) => ({ score: gword === "book" ? 55 : 5 }));
    const s = new Fake("S");
    const g = new Fake("G");
    hub.connect(s);
    hub.connect(g);
    hub.receive(s, { t: "dare", role: "setter", code: "C", word: "library" });
    hub.receive(g, { t: "dare", role: "guesser", code: "C" });

    hub.receive(g, { t: "guess", guess: "zxqwv" }); // gibberish → rejected, not added
    expect(g.last("error")!.code).toBe("not_a_word");
    expect(g.last("dareState")?.state.guesses.length ?? 0).toBe(0);

    hub.receive(g, { t: "guess", guess: "book" });
    await flush();
    expect(g.last("dareState")!.state.guesses.at(-1)!.warmth).toBeCloseTo(0.55);
    expect(s.last("dareState")!.state.guesses.at(-1)!.word).toBe("book"); // setter watches
  });

  it("the setter cannot guess", async () => {
    const hub = dareHub(async () => ({ score: 99 }));
    const s = new Fake("S");
    const g = new Fake("G");
    hub.connect(s);
    hub.connect(g);
    hub.receive(s, { t: "dare", role: "setter", code: "C", word: "library" });
    hub.receive(g, { t: "dare", role: "guesser", code: "C" });
    hub.receive(s, { t: "guess", guess: "library" }); // setter tries to solve their own word
    await flush();
    expect(hub.activeDareCount()).toBe(1); // ignored, dare still going
  });

  it("a solve ends the dare and reveals the word to both", () => {
    const hub = dareHub();
    const s = new Fake("S");
    const g = new Fake("G");
    hub.connect(s);
    hub.connect(g);
    hub.receive(s, { t: "dare", role: "setter", code: "C", word: "library" });
    hub.receive(g, { t: "dare", role: "guesser", code: "C" });
    clock.t += 5000;
    hub.receive(g, { t: "guess", guess: "library" });

    expect(g.last("dareEnd")!.result.solved).toBe(true);
    expect(s.last("dareEnd")!.result.word).toBe("library");
    expect(hub.activeDareCount()).toBe(0);
  });

  it("the guesser's live frames never leak the word", () => {
    const hub = dareHub();
    const s = new Fake("S");
    const g = new Fake("G");
    hub.connect(s);
    hub.connect(g);
    hub.receive(s, { t: "dare", role: "setter", code: "C", word: "ember" });
    hub.receive(g, { t: "dare", role: "guesser", code: "C" });
    hub.receive(g, { t: "guess", guess: "flame" });
    const blob = JSON.stringify(g.frames).toLowerCase();
    expect(blob).not.toContain("ember");
  });

  it("a guesser joining a code with no live setter → no_such_invite (3.1)", () => {
    const hub = dareHub();
    const g = new Fake("G");
    hub.connect(g);
    hub.receive(g, { t: "dare", role: "guesser", code: "GONE" });
    expect(g.last("error")!.code).toBe("no_such_invite");
    expect(hub.activeDareCount()).toBe(0);
  });

  it("a second setter on a code already daring → code_taken (3.1)", () => {
    const hub = dareHub();
    const s1 = new Fake("S1");
    const s2 = new Fake("S2");
    hub.connect(s1);
    hub.connect(s2);
    hub.receive(s1, { t: "dare", role: "setter", code: "DUP", word: "library" });
    hub.receive(s2, { t: "dare", role: "setter", code: "DUP", word: "book" });
    expect(s2.last("error")!.code).toBe("code_taken");
  });
});

describe("invite funnel telemetry (3.1)", () => {
  function hubWithMetrics(metrics: Metrics): MatchHub {
    clock = { t: T0 };
    return new MatchHub({
      now: () => clock.t,
      metrics,
      matchmaker: {
        wordProvider: () => "ember",
        roomIdProvider: (() => { let n = 0; return () => `room-${++n}`; })(),
        botSeedProvider: () => 1,
      },
    });
  }

  it("counts the race funnel: created, joined, code_taken, no_such_invite", () => {
    const m = new Metrics();
    const hub = hubWithMetrics(m);
    const a = new Fake("A"), c = new Fake("C"), d = new Fake("D"), e = new Fake("E");
    [a, c, d, e].forEach((x) => hub.connect(x));
    hub.receive(a, { t: "queue", mode: "casual", friendCode: "DUP", create: true });  // created
    hub.receive(c, { t: "queue", mode: "casual", friendCode: "DUP", create: true });  // code_taken (A hosting)
    hub.receive(d, { t: "queue", mode: "casual", friendCode: "NOPE", create: false }); // no_such_invite
    hub.receive(e, { t: "queue", mode: "casual", friendCode: "DUP", create: false });  // joined (pairs A+E)
    expect(m.get("invite.created.race")).toBe(1);
    expect(m.get("invite.code_taken.race")).toBe(1);
    expect(m.get("invite.no_such_invite.race")).toBe(1);
    expect(m.get("invite.joined.race")).toBe(1);
  });

  it("counts the dare funnel: created, joined, code_taken, no_such_invite", () => {
    const m = new Metrics();
    const hub = hubWithMetrics(m);
    const s = new Fake("S"), s2 = new Fake("S2"), g = new Fake("G"), g2 = new Fake("G2");
    [s, s2, g, g2].forEach((x) => hub.connect(x));
    hub.receive(s, { t: "dare", role: "setter", code: "D1", word: "library" });  // created
    hub.receive(s2, { t: "dare", role: "setter", code: "D1", word: "book" });    // code_taken
    hub.receive(g2, { t: "dare", role: "guesser", code: "GONE" });               // no_such_invite
    hub.receive(g, { t: "dare", role: "guesser", code: "D1" });                  // joined (pairs S+G)
    expect(m.get("invite.created.dare")).toBe(1);
    expect(m.get("invite.code_taken.dare")).toBe(1);
    expect(m.get("invite.no_such_invite.dare")).toBe(1);
    expect(m.get("invite.joined.dare")).toBe(1);
  });
});
