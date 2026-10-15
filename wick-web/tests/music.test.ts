import { test } from "node:test";
import assert from "node:assert/strict";
import { wantsKiai, pulseAt, KIAI_AT_MS } from "../src/game/music.ts";

test("race music stays chill until the last minute and five seconds", () => {
  assert.equal(wantsKiai(240_000), false);
  assert.equal(wantsKiai(KIAI_AT_MS + 1), false);
});

test("the riser starts at 1:05 left so kiai lands near 1:00", () => {
  assert.equal(wantsKiai(KIAI_AT_MS), true);
  assert.equal(wantsKiai(30_000), true);
});

test("the beat pulse peaks on each beat and the downbeat only on beat 1", () => {
  const onBar = pulseAt(4.0, null, null);
  assert.ok(onBar.beat > 0.99 && onBar.down > 0.99);
  const beat2 = pulseAt(4.5, null, null);
  assert.ok(beat2.beat > 0.99 && beat2.down === 0);
  assert.ok(pulseAt(4.4, null, null).beat < 0.05);
});

test("energy is 0 on chill, rises through the riser, and is 1 on kiai with a flash", () => {
  assert.equal(pulseAt(10, null, null).energy, 0);
  assert.equal(pulseAt(10, 20, 24).energy, 0);
  const mid = pulseAt(22, 20, 24);
  assert.ok(mid.energy > 0 && mid.energy < 1 && mid.flash === 0);
  const drop = pulseAt(24, 20, 24);
  assert.equal(drop.energy, 1);
  assert.ok(drop.flash > 0.99);
  assert.ok(pulseAt(26, 20, 24).flash < 0.01);
});
