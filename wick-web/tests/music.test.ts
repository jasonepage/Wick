import { test } from "node:test";
import assert from "node:assert/strict";
import { wantsKiai, KIAI_WARMTH, KIAI_REMAINING_MS } from "../src/game/music.ts";

const calm = { youBest: 0.2, oppBest: 0.3, remainingMs: 240_000 };

test("race music stays chill while nobody is hot and time is left", () => {
  assert.equal(wantsKiai(calm), false);
});

test("kiai when either player reaches Hot", () => {
  assert.equal(wantsKiai({ ...calm, youBest: KIAI_WARMTH }), true);
  assert.equal(wantsKiai({ ...calm, oppBest: 0.8 }), true);
  assert.equal(wantsKiai({ ...calm, youBest: KIAI_WARMTH - 0.01 }), false);
});

test("kiai in the last minute", () => {
  assert.equal(wantsKiai({ ...calm, remainingMs: KIAI_REMAINING_MS }), true);
  assert.equal(wantsKiai({ ...calm, remainingMs: KIAI_REMAINING_MS + 1 }), false);
});
