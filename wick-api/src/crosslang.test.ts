//
//  crosslang.test.ts: two players race the same concept in different languages.
//
//  A Spanish seat and an English seat share one room. Each hunts the pool
//  entry in its own language, each is scored in its own language, and the end
//  screen shows both words. Bots always play the English form.
//

import { describe, it, expect } from "vitest";
import { MatchHub, type Client } from "./hub.js";
import type { ServerFrame, ClientFrame } from "./protocol.js";
import { keeperAnswer } from "./keeper.js";
import { toMatchWord, MATCH_WORDS, makeWordProvider } from "./words.js";

class Fake implements Client {
  frames: ServerFrame[] = [];
  constructor(public id: string) {}
  send(f: ServerFrame): void { this.frames.push(f); }
  close(): void { /* no-op */ }
  last<T extends ServerFrame["t"]>(t: T): Extract<ServerFrame, { t: T }> | undefined {
    for (let i = this.frames.length - 1; i >= 0; i--) if (this.frames[i]!.t === t) return this.frames[i] as never;
    return undefined;
  }
}

const RIVER = { en: "river", es: "río", fr: "rivière", it: "fiume", de: "fluss", zh: "河" };

function makeHub(scored: Array<{ secret: string; guess: string; lang?: string }>, asked: Array<{ secret: string; lang?: string; secretEn?: string }> = []) {
  return new MatchHub({
    now: () => 1_000_000,
    attest: () => true,
    matchmaker: { wordProvider: () => RIVER },
    scoreWarmth: async (secret, guess, lang) => { scored.push({ secret, guess, lang }); return { score: 40, rank: 300 }; },
    answerKeeper: async (secret, _q, lang, secretEn) => { asked.push({ secret, lang, secretEn }); return { verdict: "Yes", reply: "" }; },
  });
}

describe("cross-language race", () => {
  it("each seat hunts, is scored in, and solves with its own language", () => {
    const scored: Array<{ secret: string; guess: string; lang?: string }> = [];
    const asked: Array<{ secret: string; lang?: string; secretEn?: string }> = [];
    const hub = makeHub(scored, asked);
    const es = new Fake("ES"), en = new Fake("EN");
    hub.connect(es); hub.connect(en);
    hub.receive(es, { t: "queue", mode: "casual", lang: "es" } as ClientFrame);
    hub.receive(en, { t: "queue", mode: "casual" } as ClientFrame);
    expect(es.last("paired")).toBeTruthy();

    // Scored against the seat's own form of the word, in its own language.
    hub.receive(es, { t: "guess", guess: "agua" });
    hub.receive(en, { t: "guess", guess: "water" });
    expect(scored).toEqual([
      { secret: "río", guess: "agua", lang: "es" },
      { secret: "river", guess: "water", lang: "en" },
    ]);
    // A guess that is not a Spanish word is rejected for the Spanish seat.
    hub.receive(es, { t: "guess", guess: "xyzzyq" });
    expect(es.last("scored")?.notAWord).toBe(true);

    // The Keeper gets the seat's word, its language, and the English form.
    hub.receive(es, { t: "ask", question: "Is it alive?" });
    expect(asked).toEqual([{ secret: "río", lang: "es", secretEn: "river" }]);

    // Solving with the Spanish word ends the race; both end screens carry both words.
    hub.receive(es, { t: "guess", guess: "Río" });
    const rEs = es.last("result")!, rEn = en.last("result")!;
    expect(rEs.word).toBe("río");
    expect(rEn.word).toBe("river");
    expect(rEs.words).toEqual({ es: "río", en: "river" });
    expect(rEs.result.reason).toBe("solved");
  });

  it("the other seat's word does not solve yours", () => {
    const hub = makeHub([]);
    const es = new Fake("ES"), en = new Fake("EN");
    hub.connect(es); hub.connect(en);
    hub.receive(es, { t: "queue", mode: "casual", lang: "es" } as ClientFrame);
    hub.receive(en, { t: "queue", mode: "casual" } as ClientFrame);
    hub.receive(en, { t: "guess", guess: "río" }); // the English seat typing the Spanish word
    expect(en.last("result")).toBeUndefined();
    hub.receive(en, { t: "guess", guess: "river" });
    expect(en.last("result")?.word).toBe("river");
  });

  it("an accent-free spelling solves an accented word", () => {
    const hub = makeHub([]);
    const es = new Fake("ES"), en = new Fake("EN");
    hub.connect(es); hub.connect(en);
    hub.receive(es, { t: "queue", mode: "casual", lang: "es" } as ClientFrame);
    hub.receive(en, { t: "queue", mode: "casual" } as ClientFrame);
    hub.receive(es, { t: "guess", guess: "rio" });
    expect(es.last("result")?.word).toBe("río");
  });

  it("a Chinese seat hunts the Chinese form", () => {
    const scored: Array<{ secret: string; guess: string; lang?: string }> = [];
    const hub = makeHub(scored);
    const zh = new Fake("ZH"), en = new Fake("EN");
    hub.connect(zh); hub.connect(en);
    hub.receive(zh, { t: "queue", mode: "casual", lang: "zh" } as ClientFrame);
    hub.receive(en, { t: "queue", mode: "casual" } as ClientFrame);
    hub.receive(zh, { t: "guess", guess: "水" });
    expect(scored[0]).toEqual({ secret: "河", guess: "水", lang: "zh" });
    hub.receive(zh, { t: "guess", guess: "河" });
    expect(zh.last("result")?.word).toBe("河");
    expect(en.last("result")?.words).toEqual({ zh: "河", en: "river" });
  });

  it("a bot opponent plays the English form", () => {
    const scored: Array<{ secret: string; guess: string; lang?: string }> = [];
    let t = 1_000_000;
    const hub = new MatchHub({
      now: () => t,
      attest: () => true,
      matchmaker: { wordProvider: () => RIVER, config: { botFillWaitMs: 10, startSlotMs: 0 } },
      scoreWarmth: async (secret, guess, lang) => { scored.push({ secret, guess, lang }); return { score: 1 }; },
    });
    const de = new Fake("DE");
    hub.connect(de);
    hub.receive(de, { t: "queue", mode: "casual", lang: "de" } as ClientFrame);
    t += 50;
    hub.tick();
    expect(de.last("paired")?.opponentKind).toBe("bot");
    hub.receive(de, { t: "guess", guess: "wasser" });
    expect(scored[0]).toEqual({ secret: "fluss", guess: "wasser", lang: "de" });
    hub.receive(de, { t: "guess", guess: "fluss" });
    expect(de.last("result")?.word).toBe("fluss");
    expect(de.last("result")?.words).toEqual({ de: "fluss", en: "river" });
  });
});

describe("match word pool", () => {
  it("every entry has all five languages and a bare string widens to all", () => {
    expect(MATCH_WORDS.length).toBeGreaterThan(400);
    for (const w of MATCH_WORDS) for (const l of ["en", "es", "fr", "it", "de", "zh"] as const) expect(w[l].length).toBeGreaterThan(0);
    expect(new Set(MATCH_WORDS.map((w) => w.en)).size).toBe(MATCH_WORDS.length);
    expect(toMatchWord("ember").de).toBe("ember");
    expect(makeWordProvider(() => 0)().en).toBe(MATCH_WORDS[0]!.en);
  });
});

describe("keeper in another language", () => {
  it("asks the model for a Spanish reply with an English tag, and strips the tag", async () => {
    let system = "";
    const r = await keeperAnswer("río", "¿Es grande?", async (sys) => { system = sys; return { text: "Yes, puede ser muy grande." }; }, "es", "river");
    expect(system).toContain("Spanish");
    expect(system).toContain('"Yes", "No", "Sort of" or "I don\'t know"');
    expect(r.verdict).toBe("Yes");
    expect(r.reply).toBe("Puede ser muy grande");
  });
  it("still blocks a leak in either form and never echoes either word", async () => {
    const leak = await keeperAnswer("río", "does it rhyme with river?", async () => ({ text: "Yes" }), "es", "river");
    expect(leak.source).toBe("leak");
    const echo = await keeperAnswer("río", "¿Es agua?", async () => ({ text: "Yes, un río es agua." }), "es", "river");
    expect(echo.verdict).toBe("Yes");
    expect(echo.reply).not.toContain("río");
  });
  it("uses the deterministic engine through the English form, verdict only", async () => {
    const r = await keeperAnswer("río", "Is it alive?", async () => { throw new Error("should not call the model"); }, "es", "river");
    expect(r.source).toBe("deterministic");
    expect(r.reply).toBe("");
    expect(["Yes", "No", "Sort of"]).toContain(r.verdict);
  });
});
