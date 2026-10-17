// SPDX-License-Identifier: MPL-2.0
//
//  The tutorial level's rules (src/game/tutorial.ts). The screen is checked by eye.
//

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  afterAnswer, afterGuess, afterLucky, afterNotAWord, freshState, lettersShown, pickAnimal,
  shouldAutoStart, stepNumber, tutorialLine, tutorialPool, TUTORIAL_ANIMALS, type TutState,
} from "../src/game/tutorial.ts";
import { readFileSync } from "node:fs";
import { TABLES, LANGS } from "../src/i18n.ts";

const pool = JSON.parse(readFileSync(new URL("../src/game/dailyPool.json", import.meta.url), "utf8")) as unknown[];

const t = (key: string, ...args: Array<string | number>): string =>
  `${key}${args.length ? "(" + args.join(",") + ")" : ""}`;
const ctx = { t, heat: "Cold", verdictLabel: (v: string) => v, secret: "horse" };

test("all ten animals are in the word pool, in every language", () => {
  const rows = tutorialPool(pool as never);
  assert.equal(rows.length, TUTORIAL_ANIMALS.length);
  for (const r of rows) for (const l of ["en", "es", "fr", "it", "de", "zh"] as const) assert.ok(r[l], `${r.en} ${l}`);
});

test("a bonus animal is never one already used", () => {
  const rows = tutorialPool(pool as never);
  const used = new Set(rows.slice(0, 9).map((r) => r.en));
  for (let i = 0; i < 20; i++) assert.equal(pickAnimal(rows, used).en, rows[9]!.en);
  // Every animal used: still returns one rather than nothing.
  assert.ok(pickAnimal(rows, new Set(TUTORIAL_ANIMALS)));
});

test("step 1 clears on any scored guess", () => {
  const c = afterGuess(freshState(), true);
  assert.equal(c.state.step, "warmer");
  assert.ok(c.advanced);
});

test("step 2 clears on a warmer guess, with a cheer", () => {
  const s: TutState = { step: "warmer", note: "none", misses: 0, verdict: "" };
  const c = afterGuess(s, true);
  assert.equal(c.state.step, "ask");
  assert.equal(c.state.note, "warmer");
  assert.ok(c.cheer);
});

test("step 2 never dead-ends: three colder guesses move on", () => {
  let s: TutState = { step: "warmer", note: "none", misses: 0, verdict: "" };
  s = afterGuess(s, false).state;
  assert.equal(s.note, "colder");
  s = afterGuess(s, false).state;
  const c = afterGuess(s, false);
  assert.equal(c.state.step, "ask");
  assert.equal(c.state.note, "movedOn");
});

test("step 3 waits for a question, not a guess", () => {
  let s: TutState = { step: "ask", note: "none", misses: 0, verdict: "" };
  s = afterGuess(s, true).state;
  assert.equal(s.step, "ask");
  assert.equal(s.note, "askInstead");
  const c = afterAnswer(s, "Yes");
  assert.equal(c.state.step, "solve");
  assert.equal(c.state.verdict, "Yes");
  assert.equal(tutorialLine(c.state, ctx), "tutAnswered(Yes) tutFindIt");
});

test("a question before step 3 does not skip it", () => {
  const c = afterAnswer(freshState(), "Yes");
  assert.equal(c.state.step, "guess");
  assert.ok(!c.advanced);
});

test("a lucky early solve keeps the step, and step 2 restarts at 1", () => {
  assert.equal(afterLucky({ step: "warmer", note: "none", misses: 2, verdict: "" }).step, "guess");
  const a = afterLucky({ step: "ask", note: "none", misses: 0, verdict: "" });
  assert.equal(a.step, "ask");
  assert.equal(tutorialLine(a, ctx), "tutLucky tutAsk");
});

test("the solve step escalates: animal after 3 misses, then letters", () => {
  let s: TutState = { step: "solve", note: "none", misses: 0, verdict: "" };
  for (let i = 0; i < 3; i++) s = afterGuess(s, false).state;
  assert.equal(tutorialLine(s, ctx), "tutItsAnAnimal");
  for (let i = 0; i < 3; i++) s = afterGuess(s, false).state;
  assert.equal(tutorialLine(s, ctx), "spellHint(H)");
  for (let i = 0; i < 3; i++) s = afterGuess(s, false).state;
  assert.equal(tutorialLine(s, ctx), "spellHint(HO)");
});

test("letters never give away the whole word", () => {
  const s: TutState = { step: "solve", note: "none", misses: 600, verdict: "" };
  assert.equal(lettersShown(s, 3), 2);
  assert.equal(lettersShown(s, 1), 1);
});

test("a typo gets the not-a-word line without losing the step", () => {
  const s = afterNotAWord({ step: "warmer", note: "none", misses: 1, verdict: "" });
  assert.equal(s.step, "warmer");
  assert.equal(tutorialLine(s, ctx), "tutNotAWord");
});

test("step numbers for the badges and the skip event", () => {
  assert.deepEqual(["guess", "warmer", "ask", "solve", "done"].map((x) => stepNumber(x as never)), [1, 2, 3, 4, 5]);
});

test("only a brand-new browser auto-starts the tutorial", () => {
  assert.ok(shouldAutoStart([], false));
  assert.ok(shouldAutoStart(["wick.lang", "wick.kid"], false));
  assert.ok(!shouldAutoStart(["wick.daily.1400"], false));
  assert.ok(!shouldAutoStart([], true));
});

test("every tutorial string exists in all six languages, with no em dash", () => {
  const keys = Object.keys(TABLES.en).filter((k) => k.startsWith("tut") || /^how.*Line$/.test(k));
  assert.ok(keys.length >= 20);
  for (const l of LANGS) {
    for (const k of keys) {
      const v = TABLES[l][k];
      assert.ok(v, `${l} ${k}`);
      assert.ok(!v.includes("\u2014") && !v.includes("\u2013"), `${l} ${k} has a dash`);
    }
  }
});
