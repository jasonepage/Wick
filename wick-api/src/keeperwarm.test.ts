import { describe, it, expect } from "vitest";
import { AnswerCache } from "./answercache.js";
import { keeperAnswer, type KeeperOptions } from "./keeper.js";
import { DailyWarmer, LEAD_MS, warmDay, warmQuestions } from "./keeperwarm.js";
import { dailyForDay, dayStartMs } from "./daily.js";
import { STARTER_QUESTIONS } from "./starterquestions.js";
import type { Lang } from "./lang.js";

const PARK_DAY = 9421;

function fakeAnswer(calls: string[], text = "Yes, usually.") {
  return (secret: string, q: string, lang: Lang, secretEn: string | undefined, opts: KeeperOptions) => {
    return keeperAnswer(secret, q, async () => { calls.push(`${lang}:${secret}:${q}`); return { text }; }, lang, secretEn, opts);
  };
}

describe("daily warm-up", () => {
  it("asks the starters plus this week's most asked, once each, never naming the word", () => {
    const qs = warmQuestions(dailyForDay(PARK_DAY), "en", ["Is it alive?", "Can you walk a dog there?", "Is it a park?"]);
    expect(qs).toContain("Can you walk a dog there?");
    expect(qs.filter((q) => q.toLowerCase().startsWith("is it alive"))).toHaveLength(1);
    expect(qs.some((q) => /park/i.test(q))).toBe(false);
    expect(qs).toHaveLength(STARTER_QUESTIONS.length + 1);
  });

  it("saves every answer for the daily word, and a second run costs nothing", async () => {
    const cache = new AnswerCache();
    const calls: string[] = [];
    const deps = { now: Date.now, cache, answer: fakeAnswer(calls), mostAsked: () => [], langs: ["en"] as const };
    const r = await warmDay(PARK_DAY, "en", deps);
    expect(r.modelCalls).toBe(STARTER_QUESTIONS.length);
    expect(r.saved).toBe(STARTER_QUESTIONS.length);
    expect(calls.every((c) => c.startsWith("en:park:"))).toBe(true);
    // A player tapping a suggestion now gets the saved answer.
    const tap = await keeperAnswer("park", "Is it alive?", async () => ({ text: "No" }), "en", undefined, { cache });
    expect(tap.source).toBe("cache");
    const again = await warmDay(PARK_DAY, "en", deps);
    expect(again.modelCalls).toBe(0);
    expect(again.alreadySaved).toBe(STARTER_QUESTIONS.length);
  });

  it("sends the word the way a Spanish round does (Spanish secret plus English form)", async () => {
    const cache = new AnswerCache();
    const calls: string[] = [];
    await warmDay(PARK_DAY, "es", { now: Date.now, cache, answer: fakeAnswer(calls), mostAsked: () => [], langs: ["es"] });
    const es = dailyForDay(PARK_DAY).es;
    expect(calls[0]).toBe(`es:${es}:${STARTER_QUESTIONS[0]}`);
    expect(cache.has(es, "es", STARTER_QUESTIONS[0]!)).toBe(true);
  });

  it("stops after repeated failures and retries on the next tick", async () => {
    const cache = new AnswerCache();
    let down = true;
    const answer = (secret: string, q: string, lang: Lang, secretEn: string | undefined, opts: KeeperOptions) =>
      keeperAnswer(secret, q, async () => (down ? { error: "HTTP 503" } : { text: "No." }), lang, secretEn, opts);
    const logs: string[] = [];
    const w = new DailyWarmer({ now: () => dayStartMs(PARK_DAY) + 3_600_000, cache, answer, mostAsked: () => [], langs: ["en"], log: (m) => logs.push(m) });
    const first = await w.tick();
    expect(first[0]!.stopped).toBe(true);
    expect(first[0]!.modelCalls).toBe(5);
    expect(logs[0]).toContain("will retry");
    expect(logs[0]).not.toMatch(/park/i); // the log never spoils the word
    down = false;
    const second = await w.tick();
    expect(second[0]!.stopped).toBe(false);
    expect(await w.tick()).toEqual([]); // done for today
  });

  it("warms tomorrow's word in the last hours before midnight UTC", () => {
    const mk = (now: number) => new DailyWarmer({ now: () => now, cache: new AnswerCache(), answer: fakeAnswer([]), mostAsked: () => [], langs: ["en"] });
    const midnight = dayStartMs(PARK_DAY + 1);
    expect(mk(midnight - LEAD_MS - 60_000).daysDue()).toEqual([PARK_DAY]);
    expect(mk(midnight - LEAD_MS + 60_000).daysDue()).toEqual([PARK_DAY, PARK_DAY + 1]);
  });
});
