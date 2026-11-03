// SPDX-License-Identifier: MPL-2.0
//
//  The 3.8 motion director (wickmotion.ts), checked against the motion brief
//  (docs/wick/CLAUDE_3.8_MOTION_DIRECTOR.md). HunchTests/WickMotionTests.swift
//  makes the same checks, and its golden numbers come from this file's
//  GOLDEN section.
//

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  BASE, CHANNELS, CLIPS, DANCE, DROP_DUR, MOOD_CLIP, TRANSITION, TRANSITION_DUR,
  type ClipName, type Motion, type MotionInput, type MotionMood, type WickDanceStyle,
  MotionDirector, attentionAt, clipForCue, clipInto, colorWipe, danceInto, hash01, idleBody, motionZero,
  phraseInto, track,
} from "../src/game/wickmotion.ts";
import { pulseAt } from "../src/game/music.ts";
import { golden } from "./wickmotion.golden.ts";

const BODY = ["x", "y", "rot", "sx", "sy"] as const;
const FACE = ["gx", "gy", "bl", "br", "ll", "lr"] as const;
const firstMove = (keys: readonly number[] | undefined): number => {
  if (!keys) return Infinity;
  for (let i = 0; i < keys.length; i += 2) if (keys[i + 1] !== 0) return keys[i - 2] ?? 0;
  return Infinity;
};
const lastKey = (keys: readonly number[] | undefined): number => (keys ? keys[keys.length - 2]! : 0);
const input = (o: Partial<MotionInput> = {}): MotionInput => ({ mood: "idle", rm: false, solveE: null, transitionE: null, pulse: null, ...o });

// ── idle life ───────────────────────────────────────────────────────────────

test("idle: 1.0-1.8% breath, counter-scaled width, root under 1.2%, tip drift 2-4%", () => {
  for (const mood of Object.keys(BASE) as MotionMood[]) {
    let maxSy = 0, maxY = 0, maxTip = 0, sxOpp = true;
    for (let t = 0; t < 12; t += 0.01) {
      const m = motionZero();
      idleBody(t, 1234, mood, m);
      maxSy = Math.max(maxSy, Math.abs(m.sy));
      maxY = Math.max(maxY, Math.abs(m.y));
      maxTip = Math.max(maxTip, Math.abs(m.tip));
      if (m.sy * m.sx > 1e-12) sxOpp = false;
    }
    assert.ok(maxSy >= 0.0099 && maxSy <= 0.018 + 1e-9, `${mood} breath ${maxSy}`);
    assert.ok(maxY <= 0.012, `${mood} root ${maxY}`);
    assert.ok(sxOpp, `${mood} width counter-scales`);
    // tip 1.0 is ~3.8% of his width; drift must sit in 2-4%.
    assert.ok(maxTip * 3.83 >= 2 && maxTip * 3.83 <= 4, `${mood} tip ${maxTip * 3.83}%`);
  }
});

test("attention: one event every 3.5-7 s, never two at once, repeatable per seed", () => {
  const cur = { n: -1, start: 0 };
  const ev = { kind: "glance" as const, n: 0, start: 0, dur: 0, side: 0 } as Parameters<typeof attentionAt>[3];
  const starts: number[] = [];
  const kinds = new Set<string>();
  for (let t = 0; t < 120; t += 0.01) {
    if (attentionAt(t, 42, cur, ev) && starts[starts.length - 1] !== ev.start) {
      starts.push(ev.start);
      kinds.add(ev.kind);
      if (ev.kind === "glance") assert.ok(ev.dur >= 0.45 && ev.dur <= 0.7);
      if (ev.kind === "blink") assert.ok(ev.dur >= 0.17 && ev.dur <= 0.23);
    }
  }
  for (let i = 1; i < starts.length; i++) {
    const gap = starts[i]! - starts[i - 1]!;
    assert.ok(gap >= 3.5 - 1e-9 && gap <= 7 + 1e-9, `gap ${gap}`);
  }
  assert.equal(kinds.size, 4, "all four kinds appear");
  assert.equal(hash01(42, 7), hash01(42, 7));
  assert.notEqual(hash01(42, 7), hash01(43, 7));
});

test("attention waits 800 ms after a guess", () => {
  const cur = { n: -1, start: 0 };
  const ev = { kind: "glance", n: 0, start: 0, dur: 0, side: 0 } as Parameters<typeof attentionAt>[3];
  for (let t = 0; t < 20; t += 0.01) if (attentionAt(t, 9, cur, ev)) break;
  const s = ev.start, mid = s + ev.dur / 2;
  const quiet = new MotionDirector(9), loud = new MotionDirector(9);
  const a = motionZero(), b = motionZero();
  quiet.sample(0, input(), a); loud.sample(0, input(), b);
  quiet.cue(s - 0.3, null);                // a plain guess on an idle Wick: no clip, only the quiet window
  quiet.sample(mid, input(), a); loud.sample(mid, input(), b);
  const ch = ev.kind === "glance" ? "gy" : ev.kind === "brow" ? (ev.side < 0.5 ? "bl" : "br") : ev.kind === "blink" ? "ll" : "tip";
  assert.ok(Math.abs(b[ch] - a[ch]) > 0.05, `${ev.kind}: the event plays when nothing happened`);
  for (const c of CHANNELS) {
    const z = motionZero();
    idleBody(mid, 9, "idle", z);
    assert.ok(Math.abs(a[c] - z[c]) < 1e-9, `after a guess only the idle body moves (${c})`);
  }
});

// ── reaction clips ──────────────────────────────────────────────────────────

const DURATIONS: Partial<Record<ClipName, number>> = {
  "deflate": 0.62, "cold-shoulder": 0.52, "inspect": 0.68, "interest": 0.56, "caught": 0.65, "hide-panic": 0.76,
};

test("each temperature has its own entrance clip with the brief's duration", () => {
  assert.deepEqual(
    [MOOD_CLIP.grey, MOOD_CLIP.freezing, MOOD_CLIP.cold, MOOD_CLIP.warm, MOOD_CLIP.hot, MOOD_CLIP.boiling],
    ["deflate", "cold-shoulder", "inspect", "interest", "caught", "hide-panic"]);
  for (const [name, d] of Object.entries(DURATIONS)) assert.equal(CLIPS[name as ClipName].dur, d, name);
  assert.equal(MOOD_CLIP.celebrating, null, "the solve keeps its own sequence");
});

test("every clip ends where the base pose takes over (all tracks end at 0)", () => {
  for (const [name, c] of Object.entries(CLIPS)) {
    for (const ch of CHANNELS) {
      const k = c.tracks[ch];
      if (!k) continue;
      assert.equal(k[k.length - 1], 0, `${name}.${ch}`);
      assert.ok(lastKey(k) <= c.dur + 1e-9, `${name}.${ch} inside the clip`);
    }
    assert.ok(c.baseIn[1] <= c.dur + 1e-9, `${name} base lands inside the clip`);
  }
});

test("eyes and brows lead the body; the tip settles last", () => {
  for (const name of ["deflate", "inspect", "caught", "turn-away", "interest", "hide-panic"] as ClipName[]) {
    const c = CLIPS[name];
    const face = Math.min(...FACE.map((ch) => firstMove(c.tracks[ch])), firstMove(c.tracks.tu));
    const body = Math.min(...BODY.map((ch) => firstMove(c.tracks[ch])));
    if (name === "deflate") continue;     // deflate's body arrives through the base ramp (baseIn 0.04)
    assert.ok(body - face >= 0.03 - 1e-9, `${name}: face ${face} body ${body}`);
  }
  assert.ok(CLIPS.deflate.baseIn[0] - firstMove(CLIPS.deflate.tracks.gy) >= 0.04 - 1e-9, "deflate: eyes fall 40 ms first");
  for (const name of ["cold-shoulder", "inspect", "caught", "hide-panic", "turn-away"] as ClipName[]) {
    const c = CLIPS[name];
    const bodyEnd = Math.max(...BODY.map((ch) => lastKey(c.tracks[ch])));
    assert.ok(lastKey(c.tracks.tip) >= bodyEnd, `${name}: tip ${lastKey(c.tracks.tip)} body ${bodyEnd}`);
  }
});

test("hide-panic: a 90 ms freeze, then one 3-frame shake that shrinks", () => {
  const c = CLIPS["hide-panic"];
  for (let e = 0; e <= 0.09; e += 0.01) for (const ch of ["x", "y", "rot"] as const) assert.equal(track(c.tracks[ch] ?? [], e), 0);
  const x = c.tracks.x!;
  const peaks = [x[5]!, x[7]!, x[9]!];
  assert.ok(Math.abs(peaks[0]!) > Math.abs(peaks[1]!) && Math.abs(peaks[1]!) > Math.abs(peaks[2]!), "decreasing");
  assert.ok(x[8]! - x[2]! <= 3.5 / 60 + 0.02, "about three frames");
});

test("caught keeps half its recoil; overshoots stay within 16%", () => {
  const rot = CLIPS.caught.tracks.rot!;
  const peak = Math.min(...rot.filter((_, i) => i % 2 === 1));
  assert.ok(peak <= -2, "recoils 2 degrees");
  assert.ok((BASE.hot.rot ?? 0) / peak >= 0.4 && (BASE.hot.rot ?? 0) / peak <= 0.6, "holds about half");
  for (const [name, c] of Object.entries(CLIPS)) {
    for (const ch of ["x", "rot"] as const) {
      const k = c.tracks[ch];
      if (!k) continue;
      const vals = k.filter((_, i) => i % 2 === 1);
      const main = vals.reduce((a, v) => (Math.abs(v) > Math.abs(a) ? v : a), 0);
      const after = vals.slice(vals.indexOf(main));
      const over = after.filter((v) => Math.sign(v) === -Math.sign(main));
      if (name === "hide-panic" || name === "cold-shoulder") continue;   // the shake and the shiver are the action
      for (const v of over) assert.ok(Math.abs(v) <= Math.abs(main) * 0.16 + 1e-9, `${name}.${ch} overshoot ${v} of ${main}`);
      assert.ok(over.length <= 1, `${name}.${ch}: one corrective rebound at most`);
    }
  }
});

test("personality beats pick their physical clips; near is hide-panic at 70%", () => {
  assert.deepEqual(clipForCue("cold", "repeat"), { clip: "judge", amp: 1 });
  assert.deepEqual(clipForCue("warm", "leap"), { clip: "perk", amp: 1 });
  assert.deepEqual(clipForCue("boiling", "near"), { clip: "hide-panic", amp: 0.7 });
  assert.deepEqual(clipForCue("hot", "regress"), { clip: "turn-away", amp: 1 });
  assert.deepEqual(clipForCue("grey", "stall"), { clip: "deflate", amp: 1 });
  assert.deepEqual(clipForCue("idle", "question"), { clip: "face-lead", amp: 1 });
  assert.deepEqual(clipForCue("cold", "topic"), { clip: "inspect", amp: 1 }, "a topic beat keeps the temperature entrance");
  assert.equal(clipForCue("celebrating", null), null);
  const qa = CLIPS["face-lead"].tracks;
  assert.ok(Math.max(...(qa.sy ?? []).filter((_, i) => i % 2 === 1).map(Math.abs)) <= 0.01, "one tiny silhouette accent");
});

// ── the director ────────────────────────────────────────────────────────────

function run(d: MotionDirector, t: number, o: Partial<MotionInput> = {}): Motion {
  const m = motionZero();
  d.sample(t, input(o), m);
  return m;
}

test("a mood change ramps the base pose instead of snapping", () => {
  const d = new MotionDirector(1);
  run(d, 0, { mood: "idle" });
  const a = run(d, 1, { mood: "grey" });
  const b = run(d, 1 + 1 / 60, { mood: "grey" });
  assert.ok(Math.abs(b.sy - a.sy) < 0.01);
  const later = run(d, 3, { mood: "grey" });
  assert.ok(Math.abs(later.sy - (BASE.grey.sy ?? 0)) < 0.02, "and holds the deadpan pose");
});

test("a rapid second guess interrupts from the pose on screen, never from rest", () => {
  const d = new MotionDirector(5);
  run(d, 0, { mood: "warm" });
  d.cue(1, null);
  let prev = run(d, 1, { mood: "hot" });
  for (let t = 1 + 1 / 60; t < 1.25; t += 1 / 60) prev = run(d, t, { mood: "hot" });
  d.cue(1.25, null);                       // mid-recoil
  const before = prev;
  const after = run(d, 1.25 + 1 / 60, { mood: "boiling" });
  for (const ch of ["x", "rot", "sx", "sy"] as const) {
    const jump = Math.abs(after[ch] - before[ch]);
    const limit = ch === "rot" ? 0.6 : 0.012;
    assert.ok(jump < limit, `${ch} jumped ${jump}`);
  }
  assert.equal(d.activeClip(1.3), "hide-panic");
});

test("priority: solve over everything; a reaction quiets the dance and the idle", () => {
  const d = new MotionDirector(3);
  run(d, 0, { mood: "warm" });
  const solving = run(d, 1, { mood: "celebrating", solveE: 0.5, pulse: pulseAt(1, null, null) });
  for (const ch of CHANNELS) assert.ok(Math.abs(solving[ch]) < 1e-12, `solve zeroes ${ch}`);

  const dancer = new MotionDirector(3), plain = new MotionDirector(3);
  const p = pulseAt(4.2, null, null);
  run(dancer, 0, { mood: "cold", pulse: p }); run(plain, 0, { mood: "cold" });
  dancer.cue(4, null); plain.cue(4, null);
  const a = run(dancer, 4.3, { mood: "cold", pulse: p, style: "swagger" });
  const b = run(plain, 4.3, { mood: "cold" });
  // Mid-clip the dance is fully suppressed; only the idle differs (and it is suppressed too).
  for (const ch of ["x", "rot"] as const) assert.ok(Math.abs(a[ch] - b[ch]) < 1e-6, `${ch} ${a[ch]} vs ${b[ch]}`);
});

test("Reduced Motion: no translation, no rotation, at most 2% scale", () => {
  for (const clip of Object.keys(CLIPS) as ClipName[]) {
    const d = new MotionDirector(7);
    run(d, 0, { mood: "idle", rm: true });
    d.cue(1, null);
    const mood: MotionMood = (Object.keys(MOOD_CLIP) as MotionMood[]).find((m) => MOOD_CLIP[m] === clip) ?? "idle";
    for (let t = 1; t < 2; t += 0.01) {
      const m = run(d, t, { mood, rm: true, transitionE: t - 1, pulse: pulseAt(t, 0, 0.5) });
      assert.ok(m.x === 0 && m.y === 0 && m.rot === 0);
      assert.ok(Math.abs(m.sx) <= 0.02 && Math.abs(m.sy) <= 0.02);
    }
  }
});

// ── transition and colour ───────────────────────────────────────────────────

test("transition: anticipate, compress behind the lids, release with a small overshoot, tip last", () => {
  const sy = (e: number) => track(TRANSITION.sy!, e);
  assert.ok(sy(0.07) > 0, "anticipates 1-2%");
  assert.ok(sy(0.07) >= 0.01 && sy(0.07) <= 0.02);
  assert.ok(sy(0.22) < -0.035, "smallest at 150-240 ms");
  const over = Math.max(...[0.28, 0.3, 0.31, 0.32].map(sy));
  assert.ok(over > 0 && over <= 0.04 * 0.16, `overshoot ${over}`);
  assert.equal(sy(0.36), 0, "silhouette settled by 360 ms");
  assert.equal(lastKey(TRANSITION.tip), TRANSITION_DUR, "the tip settles last, at 440 ms");
});

test("colour travels up the flame and finishes behind the lids", () => {
  const w: [number, number, number] = [0, 0, 0];
  colorWipe(0.12, false, w);
  assert.ok(w[2] > w[1] && w[1] > w[0], `bottom first ${w}`);
  colorWipe(0.24, false, w);
  assert.ok(w.every((v) => v > 0.999), `done by 240 ms ${w}`);
  colorWipe(0.15, true, w);
  assert.ok(w[0] === w[1] && w[1] === w[2], "Reduced Motion is one crossfade");
});

// ── dance ───────────────────────────────────────────────────────────────────

const STYLES: WickDanceStyle[] = ["groove", "swagger", "hype"];
function phrase(style: WickDanceStyle, beats: number): Motion {
  const m = motionZero();
  phraseInto(style, beats, m, 1);
  return m;
}

test("no spin anywhere: every phrase and the drop stay within 12 degrees", () => {
  for (const s of STYLES) for (let b = 0; b < 16; b += 0.02) assert.ok(Math.abs(phrase(s, b).rot) <= 12, `${s} ${b}`);
  for (let t = 240; t < 242; t += 0.01) {
    const m = motionZero();
    danceInto(pulseAt(t, 236, 240), m, "swagger");
    assert.ok(Math.abs(m.rot) <= 12, `drop ${t} rot ${m.rot}`);
  }
});

test("groove: root never above 5%, rotation within 5 degrees, no jump every beat", () => {
  let hops = 0;
  for (let b = 0; b < 8; b += 0.01) {
    const m = phrase("groove", b);
    assert.ok(m.y >= -0.05, `y ${m.y}`);
    assert.ok(Math.abs(m.rot) <= 5 + 1e-9, `rot ${m.rot}`);
  }
  for (const k of DANCE.groove) if (k.hop > 0) hops++;
  assert.ok(hops <= 1);
});

test("swagger: beats 4 and 8 are planted, and he does not hop on every beat", () => {
  const keys = DANCE.swagger;
  assert.equal(keys[3]!.hop, 0); assert.equal(keys[7]!.hop, 0);
  assert.ok(keys.filter((k) => k.hop > 0).length <= 2);
  // On beat 4 and 8 he holds: barely any movement in the first 40% of the beat.
  for (const beat of [3, 7]) {
    const a = phrase("swagger", beat + 0.02), b = phrase("swagger", beat + 0.4);
    assert.ok(Math.abs(b.x - a.x) < 0.02 && Math.abs(b.rot - a.rot) < 2, `beat ${beat + 1} is planted`);
  }
  assert.ok(Math.abs(keys[0]!.rot) >= 7 && Math.abs(keys[0]!.rot) <= 9, "beat 1: a 7-9 degree plant");
});

test("hype: crouch on 5, launch to 22% on 6, land with 10-12% squash on 7", () => {
  const k = DANCE.hype;
  assert.ok(k[4]!.sy <= -0.08, "crouch");
  assert.ok(k[5]!.y <= -0.2 && k[5]!.y >= -0.22, "launch");
  assert.ok(k[6]!.land >= 0.1 && k[6]!.land <= 0.12, "landing squash");
  assert.ok(k[7]!.hold >= 0.5, "hero hold");
});

test("the three phrases are distinct with the music off", () => {
  const sig = (s: WickDanceStyle) => [0.5, 1.5, 4.5, 5.5, 6.5].map((b) => phrase(s, b)).map((m) => [m.x, m.y, m.rot].map((v) => v.toFixed(3)).join()).join("|");
  assert.notEqual(sig("groove"), sig("swagger"));
  assert.notEqual(sig("swagger"), sig("hype"));
});

test("the tip trails the body", () => {
  // Find swagger's biggest rotation, then check the tip's matching extreme comes later.
  let rotPeak = 0, rotAt = 0, tipPeak = 0, tipAt = 0;
  for (let b = 0; b < 3; b += 0.005) {
    const m = phrase("swagger", b);
    if (Math.abs(m.rot) > Math.abs(rotPeak) && b < 2.2) { rotPeak = m.rot; rotAt = b; }
  }
  for (let b = rotAt; b < rotAt + 1; b += 0.005) {
    const m = phrase("swagger", b);
    if (Math.sign(m.tip) === -Math.sign(rotPeak) && Math.abs(m.tip) > Math.abs(tipPeak)) { tipPeak = m.tip; tipAt = b; }
  }
  assert.ok(tipAt > rotAt, `tip peak at ${tipAt}, body at ${rotAt}`);
});

test("energy changes the vocabulary, not every number: the riser crouches, the drop lands", () => {
  const chill = motionZero(), riser = motionZero(), drop = motionZero(), land = motionZero();
  danceInto(pulseAt(4.25, null, null), chill, "swagger");
  danceInto({ beat: 0, down: 0, energy: 0.96, flash: 0, time: 4 }, riser, "swagger");
  danceInto(pulseAt(240.3, 236, 240), drop, "swagger");
  danceInto(pulseAt(240.5, 236, 240), land, "swagger");
  assert.ok(riser.y > 0 && riser.sy < 0 && riser.sx > 0, "crouch");
  assert.ok(drop.y <= -0.2, `launch ${drop.y}`);
  assert.ok(land.sy <= -0.1, `land ${land.sy}`);
  assert.ok(DROP_DUR <= 1);
  void chill;
});

// ── golden numbers for HunchTests/WickMotionTests.swift ──────────────────────

test("golden numbers are finite (the same set HunchTests/WickMotionTests.swift checks)", () => {
  const g = golden();
  assert.ok(Object.keys(g).length >= 15);
  for (const [k, v] of Object.entries(g)) for (const x of v) assert.ok(Number.isFinite(x), k);
});
