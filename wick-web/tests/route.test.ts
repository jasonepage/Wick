// SPDX-License-Identifier: MPL-2.0
//
//  route.test.ts: Semantic Arena route analysis (3.9).
//
//  The cases in HunchTests/RouteFixtures.json also run on iOS in
//  HunchTests/RouteAnalysisTests.swift, so both clients agree to the number.
//

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  ROUTE, classifySignal, signalEmphasis, routeReport, efficiency, bestJump, exploration, pathFacts, pathCardLine,
  pathSequence, broadCategory, comparisonOf, ProgressRecorder, opponentSeries, capNode, PATH_KEYS, PATH_SEQUENCE_MS,
  CATEGORY_KEY, SIGNAL_KEY, SIGNAL_GLYPH, hitMoment, talkBack, newTalkState,
  type GuessSignal, type ProgressSample, type RouteGuess,
} from "../src/game/route.ts";
import { WORD_CATEGORIES } from "../src/game/wordcategories.ts";
import { TABLES, LANGS, t } from "../src/i18n.ts";
import { shareCardSVG, revealSVG } from "../src/game/revealcard.ts";
import { PALETTE, wickStillMarkup } from "../src/game/wickface.ts";

interface Fixtures {
  signals: { name: string; prior: number[]; score: number; similarity: (number | null)[] | null; expect: GuessSignal | null }[];
  routes: {
    name: string; guesses: [string, number][]; solved: boolean; similarity: (number | null)[][] | null;
    expect: { efficiency: number | null; jumpIndex: number | null; jumpGain: number | null; jumpWord: string | null; firstTry: boolean; exploration: number | null; coach: string | null };
  }[];
  comparisons: {
    name: string; voided: boolean;
    you: { scores: number[]; guessCount: number; solved: boolean };
    them: { samples: [number, number][]; guessCount: number; best: number; solved: boolean };
    expect: null | { sentence: string; you: Record<string, unknown>; them: Record<string, unknown> };
  }[];
  hits: { name: string; prior: number[]; score: number; gain: number | null; tier: number | null }[];
  talk: { name: string; steps: [GuessSignal, number, string | null][] }[];
  categories: [string, string | null][];
}
const fx = JSON.parse(readFileSync(new URL("../../HunchTests/RouteFixtures.json", import.meta.url), "utf8")) as Fixtures;

const guessesOf = (g: [string, number][]): RouteGuess[] => g.map(([word, score]) => ({ word, score }));
const samplesOf = (s: [number, number][]): ProgressSample[] => s.map(([guessCount, best]) => ({ guessCount, best }));

for (const c of fx.signals) {
  test(`signal: ${c.name}`, () => {
    assert.equal(classifySignal({ prior: c.prior, score: c.score, similarity: c.similarity }), c.expect);
  });
}

for (const c of fx.routes) {
  test(`route: ${c.name}`, () => {
    const r = routeReport({ guesses: guessesOf(c.guesses), solved: c.solved, similarity: c.similarity });
    assert.equal(r.efficiency, c.expect.efficiency, "efficiency");
    assert.equal(r.bestJump?.index ?? null, c.expect.jumpIndex, "jump index");
    assert.equal(r.bestJump?.gain ?? null, c.expect.jumpGain, "jump gain");
    assert.equal(r.bestJump?.word ?? null, c.expect.jumpWord, "jump word");
    assert.equal(r.firstTry, c.expect.firstTry, "first try");
    assert.equal(r.exploration, c.expect.exploration, "exploration");
    assert.equal(r.coachKey, c.expect.coach, "coach");
  });
}

for (const c of fx.comparisons) {
  test(`comparison: ${c.name}`, () => {
    const got = comparisonOf({ voided: c.voided, you: c.you, them: { ...c.them, samples: samplesOf(c.them.samples) } });
    if (c.expect === null) { assert.equal(got, null); return; }
    assert.ok(got);
    assert.equal(got.sentenceKey, c.expect.sentence);
    assert.deepEqual({ ...got.you }, c.expect.you);
    assert.deepEqual({ ...got.them }, c.expect.them);
  });
}

for (const c of fx.hits) {
  test(`hit: ${c.name}`, () => {
    const got = hitMoment(c.prior, c.score);
    assert.equal(got?.gain ?? null, c.gain);
    assert.equal(got?.tier ?? null, c.tier);
  });
}

for (const c of fx.talk) {
  test(`talk: ${c.name}`, () => {
    const state = newTalkState();
    for (const [signal, guess, want] of c.steps) {
      assert.equal(talkBack(state, signal, guess)?.key ?? null, want, `${signal} on guess ${guess}`);
    }
  });
}

test("a hit is exactly a Breakthrough, so the line and the burst agree", () => {
  for (const prior of [[10], [20, 40], [55, 10, 30]]) {
    for (let score = 0; score < 100; score++) {
      assert.equal(hitMoment(prior, score) !== null, classifySignal({ prior, score }) === "breakthrough", `${prior} to ${score}`);
    }
  }
});

test("every signal can talk, and Wick never repeats a line in a round", () => {
  for (const signal of Object.keys(SIGNAL_KEY) as GuessSignal[]) {
    const state = newTalkState();
    const seen: string[] = [];
    for (let guess = 3; guess < 60; guess += 3) {
      const key = talkBack(state, signal, guess)?.key;
      if (key) seen.push(key);
    }
    assert.ok(seen.length >= 2, `${signal} said ${seen.length}`);
    assert.equal(new Set(seen).size, seen.length, `${signal} repeated itself`);
  }
});

test("Wick's lines are fixed text: no word or score can get into them", () => {
  const ph = /%@|%d/;
  for (const k of PATH_KEYS.filter((x) => x.startsWith("talk"))) {
    for (const lang of LANGS) assert.ok(!ph.test(TABLES[lang][k]!), `${lang} ${k} has a slot`);
  }
  assert.equal(talkBack.length, 3, "signal state, signal and guess number only");
});

for (const [tag, want] of fx.categories) {
  test(`category: ${tag}`, () => assert.equal(broadCategory(tag), want));
}

test("category: nothing known means no chip", () => {
  assert.equal(broadCategory(undefined), null);
  assert.equal(broadCategory(null), null);
  assert.equal(broadCategory(""), null);
  assert.equal(broadCategory(WORD_CATEGORIES["zzzz-not-a-word"]), null);
  // Abstract words never get forced into FEELING.
  assert.equal(broadCategory(WORD_CATEGORIES["courage"]), null);
  assert.equal(broadCategory(WORD_CATEGORIES["cat"]), "animal");
});

test("the web category table matches WordData.json, the iOS source of truth", () => {
  const data = JSON.parse(readFileSync(new URL("../../Hunch/Engine/WordData.json", import.meta.url), "utf8")) as { categories: Record<string, string> };
  assert.deepEqual(WORD_CATEGORIES, data.categories);
});

test("the same input always gives the same report", () => {
  const input = {
    guesses: guessesOf([["a", 10], ["b", 44], ["c", 12], ["d", 70], ["e", 100]]),
    solved: true,
    similarity: [[1, 0.2, 0.9, 0.1, 0.4], [0.2, 1, 0.3, 0.1, 0.4], [0.9, 0.3, 1, 0.1, 0.4], [0.1, 0.1, 0.1, 1, 0.4], [0.4, 0.4, 0.4, 0.4, 1]],
  };
  const first = JSON.stringify(routeReport(input));
  for (let i = 0; i < 20; i++) assert.equal(JSON.stringify(routeReport(input)), first);
});

test("the classifier never reads past its three recent guesses", () => {
  const a = classifySignal({ prior: [30, 30, 30, 30], score: 31, similarity: [0.1, 0.1, 0.1, 0.99] });
  assert.equal(a, "newDirection");
});

test("thresholds match the brief", () => {
  assert.equal(ROUTE.breakthroughGain, 15);
  assert.equal(ROUTE.warmerGain, 4);
  assert.equal(ROUTE.backtrackDrop, 12);
  assert.equal(ROUTE.neighborSim, 0.72);
  assert.equal(ROUTE.newDirectionSim, 0.35);
});

test("efficiency: edges", () => {
  assert.equal(efficiency([], false), null);
  assert.equal(efficiency([], true), null);
  assert.equal(efficiency([100], true), 100);
  assert.equal(efficiency([55], false), null);
  // A solve is measured to 100 even when the last score was reported lower.
  assert.equal(efficiency([40, 99], true), 100);
  // Web warmth noise does not change the answer.
  assert.equal(efficiency([0.57 * 100, 100], true), efficiency([57, 100], true));
});

test("exploration: needs a matrix and a guess that is not the answer", () => {
  assert.equal(exploration(3, false, null), null);
  assert.equal(exploration(0, false, []), null);
  assert.equal(exploration(1, true, [[1]]), null);
  assert.equal(exploration(1, false, [[1]]), 1);
  // A matrix that came back short (the server caps at 60) is not guessed from.
  assert.equal(exploration(3, false, [[1, 0], [0, 1]]), null);
});

test("best jump: the first try and a falling route have none", () => {
  assert.equal(bestJump([{ word: "a", score: 100 }], true), null);
  assert.equal(bestJump([{ word: "a", score: 40 }, { word: "b", score: 30 }], false), null);
});

test("reduce motion: one still gold state and an instant report", () => {
  assert.equal(signalEmphasis("breakthrough", false), "pulse");
  assert.equal(signalEmphasis("breakthrough", true), "static");
  for (const s of ["warmer", "sideways", "sameNeighborhood", "backtrack", "newDirection"] as GuessSignal[]) {
    assert.equal(signalEmphasis(s, false), "none");
    assert.equal(signalEmphasis(s, true), "none");
  }
  const still = pathSequence(true);
  assert.ok(Object.values(still).every((v) => v === 0));
  const b = pathSequence(false);
  assert.ok(b.wick <= b.word && b.word <= b.route && b.route <= b.halo && b.halo <= b.stats && b.stats <= b.coach, "beats run in order");
  assert.ok(b.coach < PATH_SEQUENCE_MS, "ends inside the brief's 1.2 seconds");
  assert.ok(b.route + b.routeMs <= PATH_SEQUENCE_MS);
});

test("signals never rely on color: every one has a glyph and a label", () => {
  for (const s of Object.keys(SIGNAL_KEY) as GuessSignal[]) {
    assert.ok(SIGNAL_GLYPH[s].length > 0);
    assert.ok(TABLES.en[SIGNAL_KEY[s]]);
  }
});

test("path facts carry numbers only", () => {
  const f = pathFacts([10, 60, 100], true);
  assert.deepEqual(Object.keys(f).sort(), ["bestJump", "efficiency", "guesses", "solved"]);
  assert.deepEqual(f, { guesses: 3, solved: true, efficiency: 100, bestJump: 50 });
  // The same numbers the report shows.
  const r = routeReport({ guesses: guessesOf([["spark", 10], ["flame", 60], ["ember", 100]]), solved: true });
  assert.equal(f.efficiency, r.efficiency);
  assert.equal(f.bestJump, r.bestJump?.gain);
  assert.deepEqual(pathFacts([], false), { guesses: 0, solved: false, efficiency: null, bestJump: null });
});

test("path card text equivalent is spoiler free and works without a stat", () => {
  const line = pathCardLine("WICK DAILY #248", { guesses: 7, solved: true, efficiency: 72, bestJump: 24 }, "guesswick.com", t);
  assert.equal(line, "WICK DAILY #248 · SOLVED IN 7 · EFFICIENCY 72 · BEST JUMP +24° · guesswick.com");
  const bare = pathCardLine("WICK PRACTICE", { guesses: 1, solved: false, efficiency: null, bestJump: null }, "guesswick.com", t);
  assert.equal(bare, "WICK PRACTICE · NOT SOLVED · guesswick.com");
});

test("recorder: a guess counts first and its warmth lands after", () => {
  const r = new ProgressRecorder();
  r.push(0, 0.5);          // nothing guessed yet
  r.push(1, 0);            // the guess counted
  r.push(1, 0.3);          // then its warmth arrived
  r.push(1, 0.3);          // a heartbeat snapshot
  r.push(2, 0.3);
  r.push(1, 0.9);          // an out of order frame changes nothing
  assert.deepEqual(r.samples, [{ guessCount: 1, best: 0.3 }, { guessCount: 2, best: 0.3 }]);
});

test("recorder and comparison have no way to hold an opponent word", () => {
  const r = new ProgressRecorder();
  r.push(1, 0.2); r.push(2, 0.5);
  const cmp = comparisonOf({
    voided: false,
    you: { scores: [10, 100], guessCount: 2, solved: true },
    them: { samples: r.samples, guessCount: 2, best: 0.5, solved: false },
  });
  assert.ok(cmp);
  const allowed = ["bands", "efficiency", "guessCount", "jumpNode", "solved"];
  assert.deepEqual(Object.keys(cmp.them).sort(), allowed);
  assert.deepEqual(Object.keys(cmp.you).sort(), allowed);
  assert.equal(cmp.them.efficiency, null, "their drops are hidden, so no Efficiency is claimed");
  // Only a band or a count leaves: never the exact warmth.
  assert.ok(!JSON.stringify(cmp.them).includes("0.5"));
  assert.ok(!JSON.stringify(cmp.them).includes("50"));
});

test("a route cut short by the other player's solve is not graded", () => {
  const cmp = comparisonOf({
    voided: false,
    you: { scores: [8, 11, 6], guessCount: 3, solved: false },
    them: { samples: [{ guessCount: 1, best: 0.1 }, { guessCount: 2, best: 0.2 }, { guessCount: 3, best: 0.2 }], guessCount: 4, best: 1, solved: true },
  });
  assert.ok(cmp);
  assert.equal(cmp.you.efficiency, null);
});

test("green only for a solve", () => {
  const cmp = comparisonOf({
    voided: false,
    you: { scores: [10, 99], guessCount: 2, solved: false },
    them: { samples: [{ guessCount: 1, best: 0.2 }, { guessCount: 2, best: 0.996 }], guessCount: 2, best: 0.996, solved: false },
  });
  assert.ok(cmp);
  assert.ok(!cmp.you.bands.includes("solved"));
  assert.ok(!cmp.them.bands.includes("solved"));
});

test("opponent series only trusts what it saw", () => {
  assert.deepEqual(opponentSeries([], 1, 1), [100], "a first-guess solve needs no snapshot");
  assert.deepEqual(opponentSeries([{ guessCount: 1, best: 0.2 }], 2, 0.1), [20, 20], "best never falls");
  assert.equal(opponentSeries([], 2, 0.5), null);
  assert.equal(opponentSeries([{ guessCount: 2, best: 0.2 }], 2, 0.2), null);
});

test("capNode keeps the marker on the nearest node", () => {
  assert.equal(capNode(3, 5), 3);
  assert.equal(capNode(0, 15), 0);
  assert.equal(capNode(14, 15), 7);
  assert.equal(capNode(8, 15), 4);
});

test("every language table has the path keys, same placeholders, no em dash, no emoji", () => {
  const ph = (s: string) => (s.match(/%@|%d/g) ?? []).sort();
  for (const lang of LANGS) {
    for (const k of PATH_KEYS) {
      const v = TABLES[lang][k];
      assert.ok(typeof v === "string" && v.length > 0, `${lang} is missing ${k}`);
      assert.deepEqual(ph(v), ph(TABLES.en[k]!), `${lang} ${k} placeholders`);
      assert.ok(!v.includes("\u2014"), `${lang} ${k} has an em dash`);
      assert.ok(!/\p{Extended_Pictographic}/u.test(v), `${lang} ${k} has an emoji`);
    }
  }
  assert.equal(Object.keys(CATEGORY_KEY).length, 8);
});

test("coach lines stay away from grades and intelligence", () => {
  const banned = /\b(smart|dumb|stupid|genius|bad|terrible|failed|wrong|intelligen)/i;
  for (const k of PATH_KEYS.filter((x) => x.startsWith("pathCoach") || x.startsWith("pathCmp"))) {
    assert.ok(!banned.test(TABLES.en[k]!), k);
  }
});

// ── spoiler and privacy rules ──

const ROUND: [string, number][] = [["pencil", 12], ["orchard", 8], ["stone", 30], ["river", 22], ["forest", 45], ["cloud", 18], ["meadow", 60], ["ember", 100]];

test("daily Path Card: no answer, no guess, and every required part", () => {
  const scores = ROUND.map(([, s]) => s);
  const path = pathFacts(scores, true);
  const brand = "WICK DAILY #1436";
  const alt = pathCardLine(brand, path, "guesswick.com", t);
  const svg = shareCardSVG({ puzzleNumber: 1436, brand, guesses: 8, solved: true, heat: scores, host: "guesswick.com", path, alt });
  for (const [word] of ROUND) {
    assert.ok(!svg.toLowerCase().includes(`>${word}<`), `${word} is on the card`);
    assert.ok(!svg.toLowerCase().includes(`"${word}"`), `${word} is on the card`);
    assert.ok(!alt.toLowerCase().includes(word), `${word} is in the text equivalent`);
  }
  assert.match(svg, /WICK DAILY #1436/);
  assert.match(svg, /SOLVED IN 8/);
  assert.match(svg, /EFFICIENCY/);
  assert.match(svg, />53</);
  assert.match(svg, /BEST JUMP/);
  assert.match(svg, />\+42\u00B0</);
  assert.match(svg, /guesswick\.com/);
  assert.match(svg, /<polyline/);
  assert.match(svg, /role="img"/);
  assert.ok(svg.includes(wickStillMarkup("sly", PALETTE.solved, "card-s", { sparks: true })), "solved green Wick");
});

test("Path Card ends green only for a solve", () => {
  const svg = shareCardSVG({
    puzzleNumber: 0, brand: "WICK PRACTICE", guesses: 3, solved: false, heat: [10, 20, 30], host: "guesswick.com",
    path: pathFacts([10, 20, 30], false),
  });
  assert.match(svg, /NOT SOLVED/);
  assert.ok(!svg.includes("#4D9E47"), "no solved green on an unsolved card");
  assert.ok(!svg.includes("SOLVED IN"));
});

test("Path Card with nothing measured leaves those stats off", () => {
  const svg = shareCardSVG({
    puzzleNumber: 0, brand: "WICK PRACTICE", guesses: 1, solved: false, heat: [30], host: "guesswick.com",
    path: pathFacts([30], false),
  });
  assert.ok(!svg.includes("EFFICIENCY"));
  assert.ok(!svg.includes("BEST JUMP"));
});

test("the 3.8 card is unchanged when it is not a Path Card", () => {
  const svg = shareCardSVG({ puzzleNumber: 1, brand: "WICK DAILY #1", guesses: 3, solved: true, heat: [10, 20, 100], host: "guesswick.com" });
  assert.match(svg, /3 GUESSES/);
  assert.match(svg, /Can you turn Wick green\?/);
  assert.ok(!svg.includes("<polyline"));
});

test("Path Report map: draws the route in order and halos the pivotal guess", () => {
  const points = [
    { word: "pencil", score: 12, radius: 0.9, angle: 0, x: 0.9, y: 0 },
    { word: "meadow", score: 60, radius: 0.3, angle: 1, x: 0.1, y: 0.2 },
    { word: "ember", score: 100, radius: 0, angle: 0, x: 0, y: 0 },
  ];
  const svg = revealSVG(points, "ember", { pivot: 1, beats: pathSequence(false) });
  assert.match(svg, /class="rv-route"/);
  assert.match(svg, /class="rv-halo"/);
  const plain = revealSVG(points, "ember");
  assert.ok(!plain.includes("rv-route") && !plain.includes("rv-halo"), "the old map is untouched");
  assert.ok(!revealSVG(points, "ember", { pivot: null, beats: pathSequence(true) }).includes("rv-halo"));
});

test("the category can only reach the post-round report", () => {
  const src = readFileSync(new URL("../src/main.ts", import.meta.url), "utf8");
  const start = src.indexOf("async function screenReveal()");
  const end = src.indexOf("function ", start + 30);
  assert.ok(start > 0 && end > start);
  const uses = [...src.matchAll(/broadCategory\(|WORD_CATEGORIES\[/g)].map((m) => m.index);
  assert.ok(uses.length > 0);
  for (const at of uses) assert.ok(at > start && at < end, "used outside the Path Report");
});

test("no signal names a category or a word", () => {
  for (const key of Object.values(SIGNAL_KEY)) {
    for (const cat of Object.values(CATEGORY_KEY)) {
      assert.ok(!TABLES.en[key]!.toUpperCase().includes(TABLES.en[cat]!), `${key} names ${cat}`);
    }
  }
});

test("the race screen builds its comparison from numbers only", () => {
  const src = readFileSync(new URL("../src/main.ts", import.meta.url), "utf8");
  const start = src.indexOf("const comparison = comparisonOf({");
  const call = src.slice(start, src.indexOf("});", start));
  assert.ok(start > 0);
  assert.ok(!/\.word\b|\bword\b|words\b|guess:/.test(call), "no word goes into the comparison");
});
