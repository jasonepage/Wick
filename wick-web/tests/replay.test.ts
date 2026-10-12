//
//  replay.test.ts: Solve Replay (3.4) timeline tests for the web port.
//
//  Mirrors HunchTests/ReplayTimelineTests.swift so both platforms are held to
//  the same rules. Runs on Node's built-in test runner, no packages:
//    npm test
//

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  bandForRank, beatEnd, bestRank, buildTimeline, duration, formatRank, guessesShown,
  makeBoard, meterFill, slotPosition, STANDARD_PACING, totalGuesses, wickTravel,
  type Pacing, type ReplayEvent, type Timeline,
} from "../src/game/replay/timeline.ts";

const g = (rank: number): ReplayEvent => ({ kind: "guess", rank });
const yes: ReplayEvent = { kind: "question", verdict: { tone: "yes", label: "Yes" } };
const no: ReplayEvent = { kind: "question", verdict: { tone: "no", label: "No" } };
const noStretch: Pacing = { ...STANDARD_PACING, minTotal: 0 };

function build(events: ReplayEvent[], outcome: "solved" | "revealed" = "solved", p?: Pacing): Timeline {
  const tl = buildTimeline(events, outcome, p);
  assert.ok(tl);
  return tl;
}

function placed(tl: Timeline): number[] {
  return tl.beats.flatMap((b) => (b.kind.kind === "place" ? b.kind.slots : []));
}

function shape(tl: Timeline): string[] {
  return tl.beats.map((b) => {
    const k = b.kind;
    switch (k.kind) {
      case "intro": return "intro";
      case "place": return k.slots.length === 1 ? `tile${k.slots[0]}` : `burst${k.slots.length}`;
      case "keeper": return `keeper${k.verdicts.length}`;
      case "finale": return k.outcome;
      case "endCard": return "end";
    }
  });
}

function longRound(guesses: number, questionEvery: number): ReplayEvent[] {
  const events: ReplayEvent[] = [];
  let best = 6000;
  for (let i = 0; i < guesses; i++) {
    if (i % 4 === 0) { best = Math.max(2, Math.floor(best * 0.82)); events.push(g(best)); }
    else events.push(g(best + 500 + i));
    if (questionEvery > 0 && i % questionEvery === 0) events.push(yes);
  }
  return [...events, g(1)];
}

const close = (a: number, b: number): void => assert.ok(Math.abs(a - b) < 1e-9, `${a} != ${b}`);

test("bands match the game's rank thresholds", () => {
  const cases: [number, string][] = [[1, "solved"], [2, "boiling"], [25, "boiling"], [26, "hot"], [100, "hot"],
    [101, "warm"], [400, "warm"], [401, "cool"], [1200, "cool"], [1201, "cold"], [0, "cold"]];
  for (const [rank, band] of cases) assert.equal(bandForRank(rank), band);
});

test("every guess gets one tile, in play order", () => {
  const tl = build([g(3000), g(800), g(900), g(40), g(1)]);
  assert.deepEqual(tl.tiles.map((x) => x.rank), [3000, 800, 900, 40, 1]);
  assert.deepEqual(tl.tiles.map((x) => x.guessNumber), [1, 2, 3, 4, 5]);
  assert.equal(tl.tiles.at(-1)?.kind, "answer");
  assert.equal(totalGuesses(tl), 5);
  assert.deepEqual(placed(tl), [0, 1, 2, 3]);
});

test("emphasis marks dips, new bests and big jumps", () => {
  const tl = build([g(3000), g(5000), g(800), g(50), g(60), g(10), g(1)]);
  assert.deepEqual(tl.tiles.slice(0, -1).map((x) => x.emphasis), [
    { kind: "newBest" }, { kind: "dip" }, { kind: "newBest" }, { kind: "bigJump", from: "cool" },
    { kind: "dip" }, { kind: "newBest" },
  ]);
  assert.deepEqual(build([g(5000), g(80), g(1)]).tiles[1]!.emphasis, { kind: "bigJump", from: "cold" });
});

test("questions in a row share one bubble", () => {
  const tl = build([yes, g(3000), yes, no, g(500), no, g(1)], "solved", noStretch);
  assert.deepEqual(shape(tl), ["intro", "keeper1", "tile0", "keeper2", "tile1", "keeper1", "solved", "end"]);
});

test("beats use the pacing and run back to back", () => {
  const p = noStretch;
  const tl = build([g(5000), g(6000), g(80), yes, g(1)], "solved", p);
  assert.deepEqual(tl.beats.map((b) => b.duration), [p.intro, p.newBest, p.dip, p.bigJump, p.keeper, p.finale, p.endCard]);
  for (let i = 1; i < tl.beats.length; i++) close(beatEnd(tl.beats[i - 1]!), tl.beats[i]!.start);
});

for (const n of [40, 90, 200, 600]) {
  test(`a ${n}-guess round fits in 60 seconds with 1 to 3 second beats`, () => {
    const tl = build(longRound(n, 3));
    assert.ok(duration(tl) <= 60 + 1e-9);
    for (const b of tl.beats) assert.ok(b.duration >= 1 - 1e-9 && b.duration <= 3 + 1e-9);
    assert.deepEqual(placed(tl), Array.from({ length: tl.tiles.length - 1 }, (_, i) => i));
    assert.equal(tl.tiles.length, n + 1);
  });
}

test("compression merges dips before new bests", () => {
  const events = Array.from({ length: 70 }, (_, i) => g(i % 10 === 0 ? 3000 - i * 30 : 9000));
  const tl = build([...events, g(1)]);
  const newBest = tl.tiles.filter((x) => x.emphasis?.kind === "newBest").map((x) => x.slot);
  assert.equal(newBest.length, 7);
  const singles = tl.beats.flatMap((b) => (b.kind.kind === "place" && b.kind.slots.length === 1 ? b.kind.slots : []));
  for (const s of newBest) assert.ok(singles.includes(s));
  assert.ok(shape(tl).some((x) => x.startsWith("burst")));
});

test("keeper bubbles go before new bests merge", () => {
  const events: ReplayEvent[] = [];
  for (let i = 0; i < 30; i++) events.push(g(5000 - i * 100), yes);
  const tl = build([...events, g(1)]);
  assert.ok(!shape(tl).some((x) => x.startsWith("keeper")));
  assert.ok(duration(tl) <= 60);
});

test("short rounds stretch a little but are not padded", () => {
  const tl = build([g(3000), g(4000), g(1)]);
  close(tl.beats[1]!.duration, 2.4);
  close(tl.beats[2]!.duration, 1.6);
  close(duration(tl), 1.5 + 2.4 + 1.6 + 3 + 3);
  assert.ok(build([g(5000), g(80), g(1)]).beats.every((b) => b.duration <= 3 + 1e-9));
});

test("revealed rounds end on a gray question mark", () => {
  const tl = build([g(3000), g(200), yes], "revealed");
  assert.equal(tl.tiles.at(-1)?.kind, "revealed");
  assert.equal(tl.tiles.at(-1)?.guessNumber, null);
  assert.deepEqual(shape(tl).slice(-3), ["keeper1", "revealed", "end"]);
  assert.equal(buildTimeline([], "revealed"), null);
  assert.equal(buildTimeline([yes, no], "revealed"), null);
  assert.deepEqual(build([g(300), g(1)], "revealed").tiles.map((x) => x.rank), [300, 0]);
});

test("first-guess solve is intro, finale, end card", () => {
  assert.deepEqual(shape(build([g(1)])), ["intro", "solved", "end"]);
});

test("tiles land in order and each hop finishes first", () => {
  const tl = build(longRound(120, 5));
  for (let i = 1; i < tl.tiles.length; i++) {
    const a = tl.tiles[i - 1]!, b = tl.tiles[i]!;
    assert.ok(a.landsAt < b.landsAt);
    assert.ok(a.landsAt + a.hop <= b.landsAt + 1e-9);
  }
});

test("Wick walks the snake one cell at a time", () => {
  const tl = build([g(3000), g(800), g(1)]);
  const [first, second, answer] = tl.tiles as [typeof tl.tiles[0], typeof tl.tiles[0], typeof tl.tiles[0]];
  assert.deepEqual(wickTravel(tl, 0), { from: 0, to: 0, progress: 1 });
  const mid = wickTravel(tl, first.landsAt + first.hop / 2);
  assert.equal(mid.from, 0); assert.equal(mid.to, 1); close(mid.progress, 0.5);
  assert.deepEqual(wickTravel(tl, second.landsAt + second.hop + 0.01), { from: 2, to: 2, progress: 1 });
  assert.deepEqual(wickTravel(tl, answer.landsAt + 1), { from: 2, to: 2, progress: 1 });
});

test("heads-up display follows the board", () => {
  const tl = build([g(3000), g(5000), g(40), g(1)]);
  assert.equal(bestRank(tl, 0), null);
  assert.equal(bestRank(tl, tl.tiles[1]!.landsAt), 3000);
  assert.equal(guessesShown(tl, tl.tiles[1]!.landsAt), 2);
  assert.equal(bestRank(tl, duration(tl)), 1);
});

test("compact ranks and meter", () => {
  assert.equal(formatRank(0), "");
  assert.equal(formatRank(14), "#14");
  assert.equal(formatRank(999), "#999");
  assert.equal(formatRank(2000), "#2k");
  assert.equal(formatRank(2345), "#2.3k");
  assert.equal(formatRank(12_345), "#12k");
  assert.equal(meterFill(1, 10_000), 1);
  close(meterFill(100, 10_000), 0.5);
  assert.equal(meterFill(10_000, 10_000), 0.04);
});

test("board: snake path, one step per slot, fits the area", () => {
  const area = { x: 120, y: 480, w: 840, h: 940 };
  const b = makeBoard(10, area);
  assert.equal(b.columns, 4); assert.equal(b.rows, 3);
  assert.deepEqual(slotPosition(b, 4), { row: 1, column: 3 });
  assert.deepEqual(slotPosition(b, 7), { row: 1, column: 0 });
  assert.equal(makeBoard(4, area).cell, 200);
  for (const n of [1, 2, 5, 17, 60, 250, 900]) {
    const bb = makeBoard(n, area);
    assert.ok(bb.x >= area.x - 1 && bb.y >= area.y - 1);
    assert.ok(bb.x + bb.columns * bb.cell <= area.x + area.w + 1 && bb.y + bb.rows * bb.cell <= area.y + area.h + 1);
    for (let s = 0; s < n - 1; s++) {
      const p = slotPosition(bb, s), q = slotPosition(bb, s + 1);
      assert.equal(Math.abs(p.row - q.row) + Math.abs(p.column - q.column), 1);
    }
  }
});
