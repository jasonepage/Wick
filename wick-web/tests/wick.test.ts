// SPDX-License-Identifier: MPL-2.0
//
//  Wick's motion math: the bob, the poke, the boiling shake, the blink and the
//  dance. Pure functions only; the DOM part of wick.ts is checked by eye.
//

import { test } from "node:test";
import assert from "node:assert/strict";
import { poseAt, danceAt, boilingShake, pokeEnvelope, flamePath, faceSpec, blinkAmount, bobPeriod, SIZE } from "../src/game/wick.ts";
import { pulseAt } from "../src/game/music.ts";

const still = { pokeAt: null, reduceMotion: false, pulse: null };

test("the flame path at rest matches the old hand-drawn silhouette", () => {
  assert.equal(flamePath(0.5),
    "M60 124 C25.3 121.6 16.1 97.6 16.1 66.4 C16.1 30.4 41.6 16 60 4 C78.4 16 103.9 30.4 103.9 66.4 C103.9 97.6 94.7 121.6 60 124 Z");
});

test("the tip leans with the flicker and the base stays put", () => {
  const left = flamePath(0);
  const right = flamePath(1);
  assert.notEqual(left, right);
  assert.ok(left.startsWith("M60 124") && right.startsWith("M60 124"));
  assert.ok(left.endsWith("60 124 Z") && right.endsWith("60 124 Z"));
});

test("the bob uses the iOS periods and amplitudes", () => {
  assert.equal(bobPeriod("boiling"), 0.55);
  assert.equal(bobPeriod("idle"), 1.8);
  // A quarter period into an idle bob is the top of the bob: 0.035 of size.
  const p = poseAt({ t: 1.8 / 4, mood: "idle", ...still });
  assert.ok(Math.abs(p.y - 0.035 * SIZE) < 1e-6);
  const c = poseAt({ t: 0.8 / 4, mood: "celebrating", ...still });
  assert.ok(Math.abs(c.y - 0.07 * SIZE) < 1e-6);
});

test("a poke squashes and stretches, then dies out within 0.45 s", () => {
  assert.equal(pokeEnvelope(-0.1), 0);
  assert.ok(pokeEnvelope(0) > 0.99);
  assert.ok(pokeEnvelope(0.2) > 0 && pokeEnvelope(0.2) < pokeEnvelope(0.05));
  assert.equal(pokeEnvelope(0.45), 0);
  const poked = poseAt({ t: 10.01, mood: "idle", pokeAt: 10, reduceMotion: false, pulse: null });
  const calm = poseAt({ t: 10.01, mood: "idle", ...still });
  assert.ok(poked.sx > calm.sx * 1.1);
});

test("boiling shakes hard, harder than the freezing shiver and never still", () => {
  let maxBoil = 0, maxFreeze = 0;
  for (let t = 0; t < 3; t += 0.01) {
    const s = boilingShake(t);
    maxBoil = Math.max(maxBoil, Math.hypot(s.x, s.y));
    maxFreeze = Math.max(maxFreeze, Math.abs(poseAt({ t, mood: "freezing", ...still }).x));
  }
  assert.ok(maxBoil > 4, `boiling moves ${maxBoil}`);
  assert.ok(maxBoil > maxFreeze * 2);
  assert.ok(Math.abs(boilingShake(1.234).rot) <= 2.5);
});

test("Reduce Motion leaves only an opacity breath", () => {
  for (const mood of ["boiling", "freezing", "celebrating"] as const) {
    const p = poseAt({ t: 3.3, mood, pokeAt: 3.2, reduceMotion: true, pulse: pulseAt(3.3, null, null) });
    assert.deepEqual([p.x, p.y, p.rot, p.sx, p.sy, p.flicker], [0, 0, 0, 1, 1, 0.5]);
    assert.ok(p.opacity >= 0.86 && p.opacity <= 1);
  }
});

test("every mood has two eyes and a mouth; only some blink", () => {
  for (const mood of ["idle", "freezing", "cold", "warm", "hot", "boiling", "celebrating", "unamused"] as const) {
    const f = faceSpec(mood);
    assert.equal(f.filter((s) => s.eye).length, 2, mood);
    assert.equal(f.filter((s) => !s.eye).length, 1, mood);
  }
  assert.equal(blinkAmount(0), 0);
  assert.equal(blinkAmount(0.1), 1);
  assert.equal(blinkAmount(0.3), 0);
});

test("the dance lands on the beat and is in the air between beats", () => {
  const onBeat = danceAt(pulseAt(4.0, null, null));
  const midBeat = danceAt(pulseAt(4.25, null, null));
  assert.ok(Math.abs(onBeat.y) < 1e-6, "feet down on the beat");
  assert.ok(midBeat.y < -3, "up in the air between beats");
  assert.ok(onBeat.sy < 1 && onBeat.sx > 1, "squashed on landing");
  assert.ok(midBeat.sy > 1 && midBeat.sx < 1, "stretched in the air");
});

test("the dance steps to alternating sides and goes bigger on beat 1", () => {
  const a = danceAt(pulseAt(4.0, null, null));   // beat 1 of a bar
  const b = danceAt(pulseAt(4.5, null, null));   // beat 2
  assert.ok(Math.sign(a.x) !== Math.sign(b.x));
  const bar = danceAt(pulseAt(4.25, null, null));
  const off = danceAt(pulseAt(4.75, null, null));
  assert.ok(Math.abs(bar.y) > Math.abs(off.y));
});

test("the dance builds with energy and the drop is a big spin", () => {
  const chill = danceAt(pulseAt(4.25, null, null));
  const kiai = danceAt(pulseAt(104.25, 90, 94));
  assert.ok(Math.abs(kiai.y) > Math.abs(chill.y) * 1.5);
  const drop = danceAt(pulseAt(94.5, 90, 94));
  assert.ok(drop.y < -30, "big jump at the drop");
  assert.ok(drop.rot > 90 && drop.rot < 360, "spinning");
  const later = danceAt(pulseAt(96.0, 90, 94));
  assert.ok(Math.abs(later.rot) < 20, "the spin is over");
});

test("no music means no dance", () => {
  const p = poseAt({ t: 4.25, mood: "idle", ...still });
  const q = poseAt({ t: 4.25, mood: "idle", pokeAt: null, reduceMotion: false, pulse: pulseAt(4.25, null, null) });
  assert.notEqual(p.y, q.y);
});
