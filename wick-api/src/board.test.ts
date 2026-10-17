import { describe, it, expect } from "vitest";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { RaceBoard, puzzleNumber, puzzleStart, nameFor, hashId, checkResult, ADJECTIVES, ANIMALS, GRACE_MS } from "./board.js";

// Saturday 17 October 2026, 15:00 UTC.
const NOW = Date.UTC(2026, 9, 17, 15);
const N = puzzleNumber(NOW);
const ok = (kid: string, g: number, ms: number, h = 0, extra: Record<string, unknown> = {}) =>
  ({ n: N, g, h, ms, lang: "en", kid: `${kid}-install-id`, r: 0, ...extra });

describe("puzzle number", () => {
  it("matches the iOS app (whole UTC days since 2001 minus 8000)", () => {
    // WordBank.dayIndex = floor(timeIntervalSinceReferenceDate / 86400)
    const dayIndex = Math.floor((NOW / 1000 - 978_307_200) / 86_400);
    expect(N).toBe(dayIndex - 8000);
    expect(puzzleNumber(puzzleStart(N))).toBe(N);
    expect(puzzleNumber(puzzleStart(N) - 1)).toBe(N - 1);
  });
});

describe("names", () => {
  it("come from the safe lists and change with a reroll", () => {
    const k = hashId("abc-install-id");
    const a = nameFor(k, 0);
    const [adj, animal] = a.split(" ");
    expect(ADJECTIVES).toContain(adj);
    expect(ANIMALS).toContain(animal);
    expect(nameFor(k, 0)).toBe(a);
    const others = new Set([1, 2, 3, 4, 5].map((r) => nameFor(k, r)));
    expect(others.size).toBeGreaterThan(1);
  });
});

describe("sanity checks", () => {
  it("rejects impossible results", () => {
    expect(checkResult(1, 0, 2_000)).toBe("too_fast");
    expect(checkResult(10, 0, 9_000)).toBe("too_fast");
    expect(checkResult(0, 0, 60_000)).toBe("bad_guesses");
    expect(checkResult(5, 6, 60_000)).toBe("bad_hints");
    expect(checkResult(5, 1, 60_000)).toBeNull();
  });
});

describe("RaceBoard", () => {
  it("ranks by guesses plus hints, then time, then who finished first", () => {
    let t = NOW;
    const b = new RaceBoard(() => t);
    b.submit(ok("seven", 7, 60_000));          // 7, 1:00
    t += 1000; b.submit(ok("sixslow", 6, 330_000)); // 6, 5:30
    t += 1000; b.submit(ok("sixfast", 6, 250_000)); // 6, 4:10
    t += 1000; b.submit(ok("hinted", 5, 100_000, 2)); // 5 + 2 hints = 7, 1:40
    const s = b.snapshot(N);
    expect(s.total).toBe(4);
    expect(s.top.map((r) => [r.g, r.h, r.ms])).toEqual([[6, 0, 250_000], [6, 0, 330_000], [7, 0, 60_000], [5, 2, 100_000]]);
    expect(s.top.map((r) => r.rank)).toEqual([1, 2, 3, 4]);
  });

  it("keeps the first result per player, so replaying changes nothing", () => {
    const b = new RaceBoard(() => NOW);
    const first = b.submit(ok("me", 9, 200_000));
    const again = b.submit(ok("me", 3, 60_000));
    expect(first.ok && again.ok && again.already).toBe(true);
    expect(b.snapshot(N).top).toHaveLength(1);
    expect(b.snapshot(N).top[0]!.g).toBe(9);
  });

  it("only takes today's puzzle, plus yesterday's for a short grace", () => {
    const b = new RaceBoard(() => NOW);
    expect(b.submit(ok("a", 5, 60_000, 0, { n: N - 1 }))).toMatchObject({ ok: false, reason: "not_today" });
    expect(b.submit(ok("a", 5, 60_000, 0, { n: N + 1 }))).toMatchObject({ ok: false, reason: "not_today" });
    const early = new RaceBoard(() => puzzleStart(N) + GRACE_MS - 1000);
    expect(early.submit(ok("a", 5, 60_000, 0, { n: N - 1 })).ok).toBe(true);
  });

  it("returns your own row by public id, never the full hash", () => {
    const b = new RaceBoard(() => NOW);
    for (let i = 0; i < 60; i++) b.submit(ok(`p${i}`, 4 + (i % 5), 60_000 + i * 1000));
    const mine = b.submit(ok("late", 20, 900_000));
    expect(mine.ok).toBe(true);
    if (!mine.ok) return;
    const s = b.snapshot(N, 50, mine.id);
    expect(s.top).toHaveLength(50);
    expect(s.me).toMatchObject({ rank: 61, g: 20, name: mine.name });
    expect(JSON.stringify(s)).not.toContain(hashId("late-install-id"));
  });

  it("renames today's entry on a reroll", () => {
    const b = new RaceBoard(() => NOW);
    const r = b.submit(ok("me", 5, 60_000));
    const name = b.rename(N, "me-install-id", 3);
    expect(name).toBe(nameFor(hashId("me-install-id"), 3));
    expect(b.snapshot(N).top[0]!.name).toBe(name);
    expect(r.ok && r.name).not.toBe(undefined);
  });

  it("survives a restart through the data file", () => {
    const file = join(mkdtempSync(join(tmpdir(), "board-")), "board.json");
    const a = new RaceBoard(() => NOW);
    a.persistTo(file);
    a.submit(ok("x", 5, 60_000));
    a.submit(ok("y", 4, 90_000));
    a.saveNow();
    const b = new RaceBoard(() => NOW);
    expect(b.persistTo(file)).toBe(2);
    expect(b.snapshot(N).top.map((r) => r.g)).toEqual([4, 5]);
  });

  it("puts give-ups below every solver, and a give-up blocks a later solve", () => {
    let t = NOW;
    const b = new RaceBoard(() => t);
    expect(b.submit({ ...ok("quitter", 3, 1_000), gu: true }).ok).toBe(true); // a give-up skips the speed check
    t += 1000; b.submit(ok("slow", 30, 900_000));
    t += 1000; b.submit({ ...ok("quitter2", 0, 5_000), gu: true });          // gave up without guessing
    t += 1000;
    const cheat = b.submit(ok("quitter", 1, 3_000));                          // then "solves" in one
    expect(cheat).toMatchObject({ ok: true, already: true });
    const s = b.snapshot(N);
    expect(s.top.map((r) => [r.g, r.gu])).toEqual([[30, false], [3, true], [0, true]]);
  });
});
