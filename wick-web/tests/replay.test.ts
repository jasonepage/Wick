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
  bandForRank, beatEnd, bestRank, buildTimeline, duration, formatRank, guessesShown, isSpoiler,
  makeBoard, meterFill, slotPosition, SPOILER_RANK_LIMIT, STANDARD_PACING, totalGuesses, wickTravel,
  type Pacing, type ReplayEvent, type Timeline, type WordPolicy,
} from "../src/game/replay/timeline.ts";

const g = (rank: number): ReplayEvent => ({ kind: "guess", rank });
const yes: ReplayEvent = { kind: "question", verdict: { tone: "yes", label: "Yes" } };
const no: ReplayEvent = { kind: "question", verdict: { tone: "no", label: "No" } };
const noStretch: Pacing = { ...STANDARD_PACING, minTotal: 0 };

function build(events: ReplayEvent[], outcome: "solved" | "revealed" = "solved", p?: Pacing, words?: WordPolicy): Timeline {
  const tl = buildTimeline(events, outcome, p, words);
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

// ── words and spoilers ──────────────────────────────────────────────────────

const w = (rank: number, label: string, exact = true): ReplayEvent => ({ kind: "guess", rank, label, exact });
const SECRET = "coral";
/** A solved round with cold, warm and top-10 guesses, ending on the answer. */
const solvedRound: ReplayEvent[] = [w(3000, "pebble"), w(400, "reef"), yes, w(11, "kelp"), w(2, "anemone"), w(60, "tide"), w(1, SECRET)];
const practice: WordPolicy = { showAnswer: true, answer: SECRET };

/** Every string a frame could print from the timeline. */
function allStrings(tl: Timeline): string[] {
  const out: string[] = [];
  for (const t of tl.tiles) if (t.label !== null) out.push(t.label);
  for (const b of tl.beats) if (b.kind.kind === "keeper") for (const v of b.kind.verdicts) out.push(v.label);
  if (tl.answer !== null) out.push(tl.answer);
  return out;
}

test("the spoiler threshold is the top 10 after the answer", () => {
  assert.equal(SPOILER_RANK_LIMIT, 11);
  assert.equal(isSpoiler(1, true), true);
  assert.equal(isSpoiler(11, true), true);
  assert.equal(isSpoiler(12, true), false);
  assert.equal(isSpoiler(0, true), false);
  // An estimated rank in the boiling band is masked too: it could be the top 10.
  assert.equal(isSpoiler(15, false), true);
  assert.equal(isSpoiler(60, false), false);
});

test("a daily replay never contains the answer and masks the top 10", () => {
  const tl = build(solvedRound, "solved", STANDARD_PACING);
  assert.equal(tl.showAnswer, false);
  assert.equal(tl.answer, null);
  for (const s of allStrings(tl)) assert.notEqual(s, SECRET);
  for (const tile of tl.tiles) {
    if (tile.kind !== "guess") { assert.equal(tile.label, null); continue; }
    if (tile.rank <= SPOILER_RANK_LIMIT) { assert.equal(tile.label, null); assert.equal(tile.masked, true); }
    else { assert.equal(tile.masked, false); }
  }
  assert.deepEqual(tl.tiles.map((x) => x.label), ["pebble", "reef", null, null, "tide", null]);
  // Even a policy that shows the answer cannot leak it through the event list by mistake: the
  // default policy is to hide.
  assert.equal(buildTimeline(solvedRound, "solved")!.answer, null);
});

test("a daily reveal never shows the answer either", () => {
  const tl = build([w(3000, "pebble"), w(5, "kelp")], "revealed", STANDARD_PACING);
  assert.equal(tl.answer, null);
  assert.deepEqual(tl.tiles.map((x) => x.label), ["pebble", null, null]);
  assert.equal(tl.tiles.at(-1)?.masked, true);
});

test("a practice replay shows every word, the answer on the final tile and the end card", () => {
  const tl = build(solvedRound, "solved", STANDARD_PACING, practice);
  assert.equal(tl.showAnswer, true);
  assert.equal(tl.answer, SECRET);
  assert.deepEqual(tl.tiles.map((x) => x.label), ["pebble", "reef", "kelp", "anemone", "tide", SECRET]);
  assert.ok(tl.tiles.every((x) => !x.masked));
  // The answer comes from the rank-1 event when the policy does not name it.
  assert.equal(build(solvedRound, "solved", STANDARD_PACING, { showAnswer: true }).answer, SECRET);
  // A revealed practice round takes the answer from the policy.
  const rv = build([w(3000, "pebble")], "revealed", STANDARD_PACING, practice);
  assert.equal(rv.tiles.at(-1)?.label, SECRET);
  assert.equal(rv.answer, SECRET);
});

test("Chinese words travel as labels unchanged", () => {
  const tl = build([w(2000, "石头"), w(300, "珊瑚礁岛"), w(1, "珊瑚")], "solved", STANDARD_PACING, { showAnswer: true });
  assert.deepEqual(tl.tiles.map((x) => x.label), ["石头", "珊瑚礁岛", "珊瑚"]);
});

test("question text rides along in the bubble on every round and gets reading time", () => {
  const asked: ReplayEvent = { kind: "question", verdict: { tone: "yes", label: "Yes", question: "Is it alive?" } };
  const tl = build([g(3000), asked, no, g(1)], "solved", noStretch);
  const keeper = tl.beats.find((b) => b.kind.kind === "keeper")!;
  assert.equal(keeper.duration, STANDARD_PACING.keeperText);
  assert.equal(keeper.kind.kind === "keeper" && keeper.kind.verdicts[0]!.question, "Is it alive?");
  assert.equal(keeper.kind.kind === "keeper" && keeper.kind.verdicts[1]!.question, undefined);
  // Chips-only bubbles (older saved rounds) keep the short beat.
  assert.equal(build([g(3000), no, g(1)], "solved", noStretch).beats[2]!.duration, STANDARD_PACING.keeper);
  // The daily spoiler rule is about words, not questions: the text is kept on a daily.
  const daily = build([g(3000), asked, g(1)], "solved", STANDARD_PACING);
  const kb = daily.beats.find((b) => b.kind.kind === "keeper")!;
  assert.equal(kb.kind.kind === "keeper" && kb.kind.verdicts[0]!.question, "Is it alive?");
});
