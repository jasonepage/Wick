//
//  clues.test.ts: Wick's timed race clues (3.9).
//

import { describe, it, expect, beforeEach } from "vitest";
import {
  dueSlot,
  pickKind,
  pickWarmerWord,
  targetRank,
  parseLadder,
  namesSecret,
  writeClueLadder,
  _clearLadders,
  CLUE_START_MS,
  CLUE_EVERY_MS,
  MAX_WORD_CLUES,
  WORD_FLOOR_RANK,
} from "./clues.js";
import { MatchHub, type Client } from "./hub.js";
import type { ServerFrame, ClientFrame } from "./protocol.js";
import { parseClientFrame } from "./protocol.js";

const CAP = 5 * 60_000;

describe("dueSlot", () => {
  it("nothing before two minutes", () => {
    expect(dueSlot(0, -1, CAP)).toBeNull();
    expect(dueSlot(CLUE_START_MS - 1, -1, CAP)).toBeNull();
  });
  it("one slot every 30 seconds after that, each only once", () => {
    expect(dueSlot(CLUE_START_MS, -1, CAP)).toBe(0);
    expect(dueSlot(CLUE_START_MS + 5_000, 0, CAP)).toBeNull();
    expect(dueSlot(CLUE_START_MS + CLUE_EVERY_MS, 0, CAP)).toBe(1);
  });
  it("a stalled tick skips to the newest slot instead of bursting", () => {
    expect(dueSlot(CLUE_START_MS + 3 * CLUE_EVERY_MS + 1, 0, CAP)).toBe(3);
  });
  it("never at or after the cap", () => {
    // 2:00 + 6 × 0:30 = 5:00, the cap itself.
    expect(dueSlot(CAP, 4, CAP)).toBeNull();
    expect(dueSlot(CAP - 1, 4, CAP)).toBe(5);
  });
});

describe("pickKind", () => {
  it("warmer words first while nobody is close", () => {
    expect(pickKind({ bestRank: 800, wordsSent: 0, hintsSent: 0, hintsAvailable: 3 })).toBe("word");
  });
  it("written clues once someone is close", () => {
    expect(pickKind({ bestRank: 25, wordsSent: 0, hintsSent: 0, hintsAvailable: 3 })).toBe("hint");
  });
  it("written clues after the warmer words run out", () => {
    expect(pickKind({ bestRank: 800, wordsSent: MAX_WORD_CLUES, hintsSent: 0, hintsAvailable: 3 })).toBe("hint");
  });
  it("falls back to the other kind, then to nothing", () => {
    expect(pickKind({ bestRank: 25, wordsSent: 0, hintsSent: 0, hintsAvailable: 0 })).toBe("word");
    expect(pickKind({ bestRank: 800, wordsSent: MAX_WORD_CLUES, hintsSent: 3, hintsAvailable: 3 })).toBeNull();
    // At the floor there is no warmer word worth giving.
    expect(pickKind({ bestRank: WORD_FLOOR_RANK, wordsSent: 0, hintsSent: 3, hintsAvailable: 3 })).toBeNull();
  });
});

describe("pickWarmerWord", () => {
  const nearest = Array.from({ length: 600 }, (_, i) => `w${i + 2}`); // w{rank}
  it("lands about halfway to the answer", () => {
    expect(targetRank(400)).toBe(200);
    expect(pickWarmerWord(nearest, 400, new Set(), ["secret"])).toEqual({ word: "w200", rank: 200 });
  });
  it("never closer than the floor", () => {
    expect(pickWarmerWord(nearest, 20, new Set(), ["secret"])!.rank).toBe(WORD_FLOOR_RANK);
  });
  it("skips used words and words naming the secret", () => {
    const list = ["pelicans", "gull", "heron"];
    expect(pickWarmerWord(list, 4, new Set(["gull"]), ["pelican"])).toEqual({ word: "heron", rank: 4 });
  });
});

describe("parseLadder", () => {
  it("reads a plain array and a fenced one", () => {
    expect(parseLadder('["I live by the sea.", "I am a big bird."]', ["pelican"], false)).toEqual([
      { text: "I live by the sea." },
      { text: "I am a big bird." },
    ]);
    expect(parseLadder('```json\n["I eat fish."]\n```', ["pelican"], false)).toEqual([{ text: "I eat fish." }]);
  });
  it("drops a clue that names the secret, and a help line that does", () => {
    const raw = JSON.stringify([
      { clue: "I am a pelican.", help: "x" },
      { clue: "I eat fish.", help: "我吃鱼。" },
      { clue: "My beak is a bag.", help: "我是鹈鹕。" },
    ]);
    expect(parseLadder(raw, ["pelican", "鹈鹕"], true)).toEqual([
      { text: "I eat fish.", help: "我吃鱼。" },
      { text: "My beak is a bag." },
    ]);
  });
  it("cleans dashes and curly quotes, and survives junk", () => {
    expect(parseLadder('["I\u2019m big \u2014 and white."]', ["pelican"], false)).toEqual([{ text: "I'm big, and white." }]);
    expect(parseLadder("no json here", ["pelican"], false)).toEqual([]);
  });
  it("Chinese secrets are caught without word breaks", () => {
    expect(namesSecret("这是一条河流", "河")).toBe(true);
  });
});

describe("writeClueLadder", () => {
  beforeEach(() => _clearLadders());
  it("asks the model once per word, and asks again after a failure", async () => {
    let calls = 0;
    const ok = async () => { calls++; return { text: '["I eat fish."]' }; };
    await writeClueLadder("pelican", "en", undefined, undefined, ok);
    await writeClueLadder("pelican", "en", undefined, undefined, ok);
    expect(calls).toBe(1);
    let fails = 0;
    const bad = async () => { fails++; return { error: "down" }; };
    expect(await writeClueLadder("heron", "en", undefined, undefined, bad)).toEqual([]);
    await writeClueLadder("heron", "en", undefined, undefined, bad);
    expect(fails).toBe(2);
  });
});

// ── the hub ───────────────────────────────────────────────────────────────────

class Fake implements Client {
  frames: ServerFrame[] = [];
  constructor(public id: string) {}
  send(f: ServerFrame): void { this.frames.push(f); }
  close(): void { /* no-op */ }
  clues() { return this.frames.filter((f) => f.t === "clue") as Extract<ServerFrame, { t: "clue" }>[]; }
}

const PELICAN = { en: "pelican", es: "pelícano", fr: "pélican", it: "pellicano", de: "pelikan", zh: "鹈鹕" };

async function race(opts: { rank?: number; ladder?: boolean } = {}) {
  let t = 1_000_000;
  const helps: Array<string | undefined> = [];
  const hub = new MatchHub({
    now: () => t,
    attest: () => true,
    matchmaker: { wordProvider: () => PELICAN },
    scoreWarmth: async () => ({ score: 50, rank: opts.rank ?? 800 }),
    nearestWords: async (_s, lang) => Array.from({ length: 600 }, (_, i) => `${lang}${i + 2}`),
    writeClues: async (_s, lang, _en, help) => {
      helps.push(help);
      return opts.ladder === false ? [] : [{ text: `${lang} one` }, { text: `${lang} two` }, { text: `${lang} three` }];
    },
  });
  const a = new Fake("A"), b = new Fake("B");
  hub.connect(a); hub.connect(b);
  hub.receive(a, { t: "queue", mode: "casual", help: "zh" } as ClientFrame);
  hub.receive(b, { t: "queue", mode: "casual", lang: "es" } as ClientFrame);
  await Promise.resolve(); await Promise.resolve();
  const at = async (ms: number) => { t = 1_000_000 + ms; hub.tick(); await Promise.resolve(); };
  return { hub, a, b, at, helps, guess: async (c: Fake, g: string) => { hub.receive(c, { t: "guess", guess: g }); await new Promise((r) => setTimeout(r, 0)); } };
}

describe("race clues in the hub", () => {
  it("nothing for two minutes, then the same kind of clue to both seats at once", async () => {
    const { a, b, at, guess, helps } = await race();
    expect(helps).toEqual(["zh", undefined]);
    await guess(a, "bird");
    await at(CLUE_START_MS - 1_000);
    expect(a.clues()).toHaveLength(0);
    await at(CLUE_START_MS);
    expect(a.clues()).toEqual([{ t: "clue", n: 1, kind: "word", text: "en400", rank: 400 }]);
    expect(b.clues()).toEqual([{ t: "clue", n: 1, kind: "word", text: "es400", rank: 400 }]);
    // Three warmer words, then written clues.
    await at(CLUE_START_MS + CLUE_EVERY_MS);
    await at(CLUE_START_MS + 2 * CLUE_EVERY_MS);
    await at(CLUE_START_MS + 3 * CLUE_EVERY_MS);
    expect(a.clues().map((c) => c.kind)).toEqual(["word", "word", "word", "hint"]);
    expect(a.clues()[3]).toEqual({ t: "clue", n: 4, kind: "hint", text: "en one" });
    expect(b.clues()[3]!.text).toBe("es one");
  });

  it("goes straight to written clues when someone is close", async () => {
    const { a, at, guess } = await race({ rank: 12 });
    await guess(a, "heron");
    await at(CLUE_START_MS);
    expect(a.clues()[0]).toMatchObject({ kind: "hint", text: "en one" });
  });

  it("keeps to warmer words when the model is down", async () => {
    const { a, at } = await race({ ladder: false });
    for (let k = 0; k < 6; k++) await at(CLUE_START_MS + k * CLUE_EVERY_MS);
    expect(a.clues().map((c) => c.kind)).toEqual(["word", "word", "word"]);
  });

  it("re-sends the race's clues to a player who reconnects", async () => {
    const { hub, a, at } = await race();
    await at(CLUE_START_MS);
    hub.disconnect(a);
    const again = new Fake("A");
    hub.connect(again);
    expect(again.clues()).toHaveLength(1);
  });
});

describe("queue frame", () => {
  it("keeps the hunt language and the menu language", () => {
    expect(parseClientFrame('{"t":"queue","mode":"casual","lang":"es","help":"zh"}')).toEqual({
      t: "queue",
      mode: "casual",
      lang: "es",
      help: "zh",
    });
  });
});
