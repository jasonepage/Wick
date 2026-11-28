// SPDX-License-Identifier: MPL-2.0
//
//  Wick's motion math: the bob, the poke, the boiling shake, the blink and the
//  dance. Pure functions only; the DOM part of wick.ts is checked by eye.
//

import { test } from "node:test";
import assert from "node:assert/strict";
import { poseAt, boilingShake, pokeEnvelope, flameBendAt, flamePath, coreFlamePath, blinkAmount, SIZE } from "../src/game/wick.ts";
import { FACES, faceFor, faceDrawList, eyeShapes, lerpFace, swapBlink, swapMorph, PALETTE, moodFor } from "../src/game/wickface.ts";
import { pulseAt } from "../src/game/music.ts";

const still = { pokeAt: null, reduceMotion: false, pulse: null };

test("the flame has an asymmetric licking crown, a high tip, and an anchored base", () => {
  const d = flamePath(0, "idle", 0.5);
  assert.ok(d.startsWith("M60 124") && d.endsWith("60 124 Z"));
  assert.ok(d.includes(" 48 4 "), "the dominant lick leans left");
  assert.match(d, / 6[23](?:\.\d)? 24 C6[78](?:\.\d)? 20 7[67](?:\.\d)? 14 8[12](?:\.\d)? 14/, "the shallow valley rises into a shorter second lick");
  assert.ok(coreFlamePath(0, "idle", 0.5).includes("47") && coreFlamePath(0, "idle", 0.5).includes("53"), "the hot core repeats both licks");
});

test("the tips bend independently with time and reactions; the base stays put", () => {
  const left = flamePath(0, "warm", 0);
  const right = flamePath(0.4, "warm", 1);
  assert.notEqual(left, right);
  for (const d of [left, right, flamePath(0, "idle", 0.5, FACES.shocked.tip), flamePath(0, "idle", 0.5, FACES.flustered.tip)]) {
    assert.ok(d.startsWith("M60 124") && d.endsWith("60 124 Z"));
  }
  assert.ok(flamePath(0, "idle", 0.5, FACES.shocked.tip).includes(" -2 "), "Shocked spikes the dominant tip upward");
  const bend = flameBendAt(0.37, "hot");
  assert.notEqual(Math.sign(bend.mainTip), Math.sign(bend.secondaryTip), "the licks counter-waver");
  assert.ok(Math.abs(bend.mainTip) > Math.abs(bend.mainMid), "the main tip travels farther than its middle");
});

test("flame flow scales with heat, speeds up, lags the core, and stays calm with Reduce Motion", () => {
  const travel = (mood: "freezing" | "boiling", dt: number): number => {
    const a = flameBendAt(0, mood), b = flameBendAt(dt, mood);
    return Math.abs(b.mainTip - a.mainTip) + Math.abs(b.secondaryTip - a.secondaryTip);
  };
  assert.ok(travel("boiling", 0.15) > travel("freezing", 0.15) * 3, "boiling whips harder and faster");
  assert.notDeepEqual(flameBendAt(0.5, "hot"), flameBendAt(0.5, "hot", 0.5, false, 1 / 3), "the core lags by a third-cycle");
  const rm = flameBendAt(0.5, "boiling", 0.5, true);
  const full = flameBendAt(0.5, "boiling");
  assert.ok(Math.abs(rm.mainTip) < Math.abs(full.mainTip), "Reduced Motion keeps a small calm waver");
  for (const mood of ["idle", "freezing", "cold", "cool", "warm"] as const) {
    assert.equal(flameBendAt(1.5, mood).split, 0, `${mood} never grows a third tip`);
  }
  assert.equal(rm.split, 0, "Reduced Motion never changes the silhouette topology");
  const boil = Array.from({ length: 300 }, (_, i) => flameBendAt(i / 50, "boiling"));
  assert.ok(boil.some((b) => b.split > 0.9), "boiling grows and rejoins a third tip");
  const commandCounts = boil.map((_, i) => (flamePath(i / 50, "boiling", 0.5).match(/C/g) ?? []).length);
  assert.equal(new Set(commandCounts).size, 1, "the connected outline keeps one topology");
  assert.ok(boil.some((b) => Math.abs(b.thirdTip) > Math.abs(b.thirdMid)), "the third tip travels farther than its middle");
});

test("3.8: the idle breathes instead of bobbing: root travel stays under 1.2%", () => {
  let maxY = 0;
  for (let t = 0; t < 8; t += 0.02) maxY = Math.max(maxY, Math.abs(poseAt({ t, mood: "boiling", ...still }).y));
  assert.ok(maxY <= 0.012 * SIZE, `root travels ${maxY}`);
  assert.ok(maxY > 0.004 * SIZE, "but he is not frozen");
});

test("a tap squashes once and dies out within 0.45 s, with no wobble", () => {
  assert.equal(pokeEnvelope(-0.1), 0);
  assert.ok(pokeEnvelope(0) > 0.99);
  assert.ok(pokeEnvelope(0.2) > 0 && pokeEnvelope(0.2) < pokeEnvelope(0.05));
  assert.equal(pokeEnvelope(0.45), 0);
  const poked = poseAt({ t: 10.01, mood: "idle", pokeAt: 10, reduceMotion: false, pulse: null });
  const calm = poseAt({ t: 10.01, mood: "idle", ...still });
  assert.ok(poked.sy < calm.sy * 0.93, "squashed");
  assert.ok(Math.abs(poked.rot - calm.rot) < 1e-9, "no rotation wobble");
});

test("3.8: no endless shaking: freezing is still and boiling only trembles", () => {
  let maxBoil = 0, maxFreeze = 0;
  for (let t = 0; t < 3; t += 0.01) {
    maxBoil = Math.max(maxBoil, Math.abs(poseAt({ t, mood: "boiling", ...still }).x));
    maxFreeze = Math.max(maxFreeze, Math.abs(poseAt({ t, mood: "freezing", ...still }).x));
  }
  assert.equal(maxFreeze, 0, "no continuous shiver");
  assert.ok(maxBoil > 0 && maxBoil < 0.008 * SIZE, `ambient tremor ${maxBoil}`);
  // The old shake survives only for the replay renderer.
  assert.ok(Math.abs(boilingShake(1.234).rot) <= 2.5);
});

test("Reduce Motion leaves only an opacity breath", () => {
  for (const mood of ["boiling", "freezing", "celebrating"] as const) {
    const p = poseAt({ t: 3.3, mood, pokeAt: 3.2, reduceMotion: true, pulse: pulseAt(3.3, null, null) });
    assert.deepEqual([p.x, p.y, p.rot, p.sx, p.sy, p.flicker], [0, 0, 0, 1, 1, 0.5]);
    assert.ok(p.opacity >= 0.78 && p.opacity <= 1);
  }
});

test("each game state wears its face", () => {
  assert.equal(faceFor({ mood: "idle" }), "sly");
  assert.equal(faceFor({ mood: "freezing" }), "serious");
  assert.equal(faceFor({ mood: "cold" }), "focus");
  assert.equal(faceFor({ mood: "warm" }), "warm");
  assert.equal(faceFor({ mood: "hot" }), "hot");
  assert.equal(faceFor({ mood: "boiling" }), "flustered");
  assert.equal(faceFor({ mood: "celebrating" }), "shocked", "solved stays Shocked");
  assert.equal(faceFor({ mood: "cold", race: true }), "serious");
  assert.equal(faceFor({ mood: "boiling", race: true }), "serious");
  assert.equal(faceFor({ mood: "celebrating", race: true }), "shocked");
  assert.equal(faceFor({ mood: "warm", focus: true }), "focus");
  assert.equal(faceFor({ mood: "cold", race: true, focus: true }), "focus");
  assert.equal(faceFor({ mood: "unamused" }), "calm");
});

test("every face draws the same 19 slots and has readable eyes", () => {
  for (const [name, f] of Object.entries(FACES)) {
    const items = faceDrawList(f, f.eyes.map((e) => e.closed), PALETTE.keeper);
    assert.equal(items.length, 19, name);
    const whites = [items[8]!, items[11]!];
    assert.ok(whites.every((w) => w.d.length > 20), `${name} has readable eyes`);
    assert.ok(items[14]!.d.length > 100, `${name} has a brow keyline`);
    assert.ok(items[15]!.d.length > 100, `${name} has sleek brows`);
  }
  assert.ok(faceDrawList(FACES.flustered, [0, 0], PALETTE.keeper)[18]!.d.length > 0, "Flustered sweats");
  assert.equal(faceDrawList(FACES.sly, [0, 0], PALETTE.keeper)[18]!.d, "", "Sly does not");
});

test("a blink shuts the eye fully and the lash line shows only when shut", () => {
  const e = FACES.sly.eyes[0]!;
  assert.ok(eyeShapes(e, 0).white.length > 20);
  assert.equal(eyeShapes(e, 1).white, "");
  assert.equal(eyeShapes(e, 0).lashOpacity, 0);
  assert.equal(eyeShapes(e, 1).lashOpacity, 1);
  assert.equal(blinkAmount(0), 0);
  assert.equal(blinkAmount(0.1), 1);
  assert.equal(blinkAmount(0.3), 0);
});

test("changing faces: eyes shut first, the face morphs behind them, then they open", () => {
  assert.equal(swapBlink(0), 0);
  assert.ok(swapBlink(0.035) > 0.4 && swapBlink(0.035) < 0.6, "closing over 70 ms");
  assert.equal(swapBlink(0.07), 1);
  assert.equal(swapBlink(0.239), 1, "shut until 240 ms");
  assert.equal(swapBlink(0.36), 0, "open by 360 ms");
  assert.equal(swapMorph(0.07), 0, "nothing moves before the lids are shut");
  assert.equal(swapMorph(0.24), 1, "and it is all done behind them");
  const mid = lerpFace(FACES.sly, FACES.serious, 0.5);
  const a = FACES.sly.brows[0]!.c[0]![1]!, b = FACES.serious.brows[0]!.c[0]![1]!;
  assert.ok(Math.abs(mid.brows[0]!.c[0]![1]! - (a + b) / 2) < 1e-9);
});

// The dance tests moved to tests/wickmotion.test.ts with the 3.8 phrases.

test("no music means no dance", () => {
  const p = poseAt({ t: 4.25, mood: "idle", ...still });
  const q = poseAt({ t: 4.25, mood: "idle", pokeAt: null, reduceMotion: false, pulse: pulseAt(4.25, null, null) });
  assert.notEqual(p.y, q.y);
});

// 3.7: the Home and welcome Wick show off every face, one every 5 seconds.
test("showcase walks through all six faces in order, then starts over", async () => {
  const { showcaseFace, SHOWCASE_SECONDS, SHOWCASE_ORDER } = await import("../src/game/wick.ts");
  assert.equal(SHOWCASE_SECONDS, 5);
  assert.deepEqual([...SHOWCASE_ORDER], ["sly", "flustered", "shocked", "calm", "serious", "focus"]);
  assert.equal(showcaseFace(0), "sly");
  assert.equal(showcaseFace(4.9), "sly");
  assert.equal(showcaseFace(5), "flustered");
  assert.equal(showcaseFace(27), "focus");
  assert.equal(showcaseFace(30), "sly");
});


// ── 3.8: the solved sequence and the share card ───────────────────────────────
import { solveFace, solveScale, solveRing, SOLVE_DONE, SOLVE_RELEASE, wickStillMarkup } from "../src/game/wickface.ts";
import { heatTrail, shareCardSVG } from "../src/game/revealcard.ts";

test("solved: Shocked through the release, then Sly, and never leaves green", () => {
  assert.equal(solveFace(0.05, false), "shocked");
  assert.equal(solveFace(SOLVE_RELEASE - 0.01, false), "shocked");
  assert.equal(solveFace(SOLVE_RELEASE + 0.01, false), "sly");
  assert.equal(solveFace(SOLVE_DONE + 10, false), "sly");
  assert.equal(solveFace(1.0, false, true), "shocked", "a first guess holds the shock longer");
  assert.equal(solveFace(0.2, true), "shocked");
  assert.equal(solveFace(0.6, true), "sly");
  // The color never changes during the sequence: it is the celebrating mood,
  // which is solved green for every face.
  assert.equal(faceFor({ mood: "celebrating" }), "shocked");
  assert.equal(moodFor({ score: 100 }), "celebrating");
});

test("solved: one squash, a rebound to 1.08, no spin, and one ring", () => {
  assert.deepEqual(solveScale(0.1), { sx: 1, sy: 1 });
  let maxSy = 0, minSy = 9;
  for (let e = 0.42; e < 0.82; e += 0.01) { const s = solveScale(e); maxSy = Math.max(maxSy, s.sy); minSy = Math.min(minSy, s.sy); }
  assert.ok(Math.abs(maxSy - 1.08) < 0.02, `rebounds to ${maxSy}`);
  assert.ok(minSy < 0.92, `compresses to ${minSy}`);
  assert.deepEqual(solveScale(0.9), { sx: 1, sy: 1 });
  assert.equal(solveRing(0.1, false), null);
  const r = solveRing(0.5, false)!;
  assert.ok(r.opacity > 0 && r.r > 0.5);
  assert.equal(solveRing(0.9, false), null);
  assert.ok(solveRing(0.5, true), "reduced motion still gets the ring");
});

test("share card: 5 to 8 nodes from real guesses, ending green on a solve", () => {
  const many = [3, 5, 9, 12, 20, 25, 33, 40, 48, 55, 61, 70, 100];
  const trail = heatTrail(many);
  assert.equal(trail.length, 8);
  assert.equal(trail[0]!.score, 3);
  assert.equal(trail[7]!.score, 100);
  assert.ok(trail[7]!.ring, "the solve node carries a ring, not only a color");
  assert.ok(trail[7]!.r > trail[0]!.r, "size changes with heat");
  assert.equal(heatTrail([10, 20, 30]).length, 3);
  const svg = shareCardSVG({ puzzleNumber: 248, brand: "WICK DAILY #248", guesses: 7, solved: true, heat: many, host: "guesswick.com" });
  assert.match(svg, /WICK DAILY #248/);
  assert.match(svg, /7 GUESSES/);
  assert.match(svg, /guesswick\.com/);
  assert.match(svg, /Can you turn Wick green\?/);
  assert.ok(svg.includes(wickStillMarkup("sly", PALETTE.solved, "card-s", { sparks: true })), "green Sly Wick with sparks");
  assert.ok(!svg.includes("secret"), "no word on the card");
});
