import { describe, it, expect } from "vitest";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  WeeklyTally, weekStartUtc, isColdEnough, normalizeGuess, normalizeQuestion,
  displayQuestion, mentionsSecret, MIN_COUNT,
} from "./tally.js";
import { MatchHub, type Client, type PlayedInfo } from "./hub.js";
import type { ServerFrame } from "./protocol.js";

// Wednesday 14 October 2026, 15:00 UTC. That week started Monday the 12th.
const WED = Date.UTC(2026, 9, 14, 15);
const MON = Date.UTC(2026, 9, 12);
const NEXT_MON = Date.UTC(2026, 9, 19);

describe("weekStartUtc", () => {
  it("is Monday 00:00 UTC", () => {
    expect(weekStartUtc(WED)).toBe(MON);
    expect(weekStartUtc(MON)).toBe(MON);
    expect(weekStartUtc(NEXT_MON - 1)).toBe(MON); // Sunday 23:59:59.999
    expect(weekStartUtc(NEXT_MON)).toBe(NEXT_MON);
  });
});

describe("spoiler rule", () => {
  it("keeps only cool or colder guesses", () => {
    expect(isColdEnough({ score: 20, rank: 401 })).toBe(true);
    expect(isColdEnough({ score: 40, rank: 400 })).toBe(false); // last Warm rank
    expect(isColdEnough({ score: 90, rank: 2 })).toBe(false);
    expect(isColdEnough({ score: 29 })).toBe(true);              // no rank: by score
    expect(isColdEnough({ score: 30 })).toBe(false);
    expect(isColdEnough({ score: 100 })).toBe(false);            // the answer
  });

  it("spots a question that names the answer", () => {
    expect(mentionsSecret("Is it a library?", ["library"])).toBe(true);
    expect(mentionsSecret("is it in a library", ["LIBRARY"])).toBe(true);
    expect(mentionsSecret("is it a librarian", ["library"])).toBe(false);
    expect(mentionsSecret("is it cats", ["cat"])).toBe(true);
    expect(mentionsSecret("是图书馆吗", ["图书馆"])).toBe(true);
    expect(mentionsSecret("is it alive", ["ember", undefined])).toBe(false);
  });
});

describe("normalizing", () => {
  it("guesses are one plain lowercase word", () => {
    expect(normalizeGuess("  Ocean ")).toBe("ocean");
    expect(normalizeGuess("café")).toBe("café");
    expect(normalizeGuess("two words")).toBeNull();
    expect(normalizeGuess("abc123")).toBeNull();
    expect(normalizeGuess("shit")).toBeNull(); // crude words never go on a public list
  });

  it("questions fold case, spacing and outer punctuation", () => {
    expect(normalizeQuestion("  Is it   ALIVE??? ")).toBe("is it alive");
    expect(normalizeQuestion("is it alive")).toBe("is it alive");
    expect(displayQuestion("is it alive")).toBe("Is it alive?");
  });

  it("drops questions that could carry personal details or crude words", () => {
    expect(normalizeQuestion("is it 555 1234")).toBeNull();
    expect(normalizeQuestion("is it me@example.com")).toBeNull();
    expect(normalizeQuestion("is it on https://x.y")).toBeNull();
    expect(normalizeQuestion("is it a fucking dog")).toBeNull();
    expect(normalizeQuestion("?")).toBeNull();
    expect(normalizeQuestion("a ".repeat(60))).toBeNull();
  });
});

describe("WeeklyTally", () => {
  it(`hides anything under ${MIN_COUNT} senders and ranks the rest`, () => {
    const t = new WeeklyTally(() => WED);
    for (const ip of ["1", "2", "3", "4"]) t.add("guess", "ocean", "en", { source: ip });
    for (const ip of ["1", "2", "3"]) t.add("guess", "river", "en", { source: ip });
    for (const ip of ["1", "2"]) t.add("guess", "rare", "en", { source: ip });
    for (const ip of ["1", "2", "3"]) t.add("question", "Is it alive?", "en", { source: ip });
    t.add("question", "is my name jason", "en", { source: "1" });

    const s = t.snapshot("en");
    expect(s.week).toBe("2026-10-12");
    expect(s.resetsAt).toBe("2026-10-19T00:00:00.000Z");
    expect(s.guesses).toEqual([{ text: "ocean", count: 4 }, { text: "river", count: 3 }]);
    expect(s.questions).toEqual([{ text: "Is it alive?", count: 3 }]);
  });

  it("counts each sender once per item, so one person cannot push a list", () => {
    const t = new WeeklyTally(() => WED);
    for (let i = 0; i < 50; i++) t.add("question", "is it secret stuff", "en", { source: "same-ip" });
    expect(t.snapshot("en").questions).toEqual([]);
  });

  it("keeps languages apart", () => {
    const t = new WeeklyTally(() => WED, 1);
    t.add("guess", "mar", "es");
    t.add("guess", "sea", "en");
    expect(t.snapshot("es").guesses).toEqual([{ text: "mar", count: 1 }]);
    expect(t.snapshot("en").guesses).toEqual([{ text: "sea", count: 1 }]);
    expect(t.add("guess", "sea", "xx")).toBe(false);
  });

  it("resets on Monday and drops items stamped last week", () => {
    let now = WED;
    const t = new WeeklyTally(() => now, 1);
    t.add("guess", "ocean", "en");
    expect(t.add("guess", "river", "en", { at: MON - 1000 })).toBe(false);
    expect(t.snapshot("en").guesses.map((r) => r.text)).toEqual(["ocean"]);
    now = NEXT_MON + 60_000;
    expect(t.snapshot("en").guesses).toEqual([]);
    expect(t.snapshot("en").week).toBe("2026-10-19");
  });

  it("returns counts only: no ids, no hashes", () => {
    const t = new WeeklyTally(() => WED, 1);
    t.add("guess", "ocean", "en", { source: "203.0.113.9" });
    const json = JSON.stringify(t.snapshot("en"));
    expect(json).not.toContain("203.0.113.9");
    expect(Object.keys(t.snapshot("en")).sort()).toEqual(["guesses", "lang", "questions", "resetsAt", "week"]);
  });

  it("survives a restart through the data file, but not into a new week", () => {
    const dir = mkdtempSync(join(tmpdir(), "tally-"));
    const file = join(dir, "tally.json");
    const a = new WeeklyTally(() => WED, 1);
    a.persistTo(file);
    a.add("guess", "ocean", "en", { source: "203.0.113.9" });
    a.add("question", "is it alive", "en", { source: "203.0.113.9" });
    a.saveNow();
    a.add("question", "is it my cat bob", "en", { source: "198.51.100.1" });
    // A question under the show line stays in memory only.
    const strict = new WeeklyTally(() => WED, 2);
    strict.persistTo(join(dir, "strict.json"));
    strict.add("question", "is it my cat bob", "en", { source: "198.51.100.1" });
    strict.add("question", "is it alive", "en", { source: "198.51.100.1" });
    strict.add("question", "is it alive", "en", { source: "198.51.100.2" });
    strict.saveNow();
    const strictDisk = readFileSync(join(dir, "strict.json"), "utf8");
    expect(strictDisk).not.toContain("cat bob");
    expect(strictDisk).toContain("is it alive");
    a.saveNow();
    const disk = readFileSync(file, "utf8");
    expect(disk).not.toContain("203.0.113.9");

    const b = new WeeklyTally(() => WED, 1);
    expect(b.persistTo(file)).toBe(3);
    expect(b.snapshot("en").guesses).toEqual([{ text: "ocean", count: 1 }]);

    const c = new WeeklyTally(() => NEXT_MON + 1, 1);
    expect(c.persistTo(file)).toBe(0);
  });
});

// ── the race hook ─────────────────────────────────────────────────────────────

class Fake implements Client {
  frames: ServerFrame[] = [];
  constructor(public id: string) {}
  send(f: ServerFrame): void { this.frames.push(f); }
  close(): void {}
}

describe("MatchHub onPlayed (race guesses and questions)", () => {
  const flush = () => new Promise((r) => setTimeout(r, 0));

  it("reports scored guesses and answered questions with the room secret", async () => {
    const seen: PlayedInfo[] = [];
    const hub = new MatchHub({
      now: () => 1_000_000,
      scoreWarmth: async () => ({ score: 12, rank: 900 }),
      answerKeeper: async () => ({ verdict: "No", reply: "Nope." }),
      onPlayed: (p) => seen.push(p),
      matchmaker: {
        wordProvider: () => "ember",
        roomIdProvider: () => "room-1",
        botSeedProvider: () => 1,
      },
    });
    const a = new Fake("A");
    const b = new Fake("B");
    hub.connect(a);
    hub.connect(b);
    hub.receive(a, { t: "queue", mode: "casual" });
    hub.receive(b, { t: "queue", mode: "casual" });
    hub.receive(a, { t: "guess", guess: "ocean" });
    hub.receive(a, { t: "ask", question: "is it alive?" });
    await flush();

    expect(seen).toHaveLength(2);
    expect(seen[0]).toMatchObject({ kind: "guess", text: "ocean", lang: "en", score: 12, rank: 900 });
    expect(seen[0]!.secrets).toContain("ember");
    expect(seen[1]).toMatchObject({ kind: "question", text: "is it alive?", lang: "en" });
  });
});
