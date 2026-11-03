// SPDX-License-Identifier: MPL-2.0
//
//  raceshow.test.ts: Race Showdown presentation state (3.8).
//
//  The same cases run on iOS in HunchTests/RaceShowdownTests.swift.
//

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  heatBand, leadOf, racePhase, phaseDance, clockAt, fmtRaceClock, fmtElapsed, finalCount, timerPulse,
  faceOffStep, faceOffEligible, faceOffStance, RaceShow, TrailRecorder, capTrail, opponentSeat,
  recapOf, RematchGate, RACE_KEYS, BAND_SCORE, MOMENTUM_SHOW_MS, MOMENTUM_GAP_MS, FACEOFF_MS,
  type RaceInput, type HeatBand,
} from "../src/game/raceshow.ts";
import { TABLES, LANGS } from "../src/i18n.ts";
import { moodFor } from "../src/game/wickface.ts";

const base = (o: Partial<RaceInput>): RaceInput => ({
  now: 0, youBest: 0, themBest: 0, youSolved: false, themSolved: false, remainingMs: 300_000, result: false, ...o,
});

test("bands follow the existing warmth thresholds", () => {
  const cases: Array<[number, HeatBand]> = [
    [0, "searching"], [0.17, "searching"], [0.18, "trail"], [0.29, "trail"], [0.3, "heating"],
    [0.44, "heating"], [0.45, "close"], [0.59, "close"], [0.6, "danger"], [0.99, "danger"], [1, "solved"],
  ];
  for (const [w, b] of cases) assert.equal(heatBand(w), b, `warmth ${w}`);
  assert.equal(heatBand(0.2, true), "solved");
});

test("band paint scores land in their own band and Wick mood", () => {
  const mood: Record<HeatBand, string> = {
    searching: "freezing", trail: "cold", heating: "warm", close: "hot", danger: "boiling", solved: "celebrating",
  };
  for (const [b, s] of Object.entries(BAND_SCORE) as Array<[HeatBand, number]>) {
    assert.equal(heatBand(s / 100), b);
    assert.equal(moodFor({ score: s }), mood[b]);
  }
});

test("lead uses best warmth, not the latest guess", () => {
  // You: latest 0.20, best 0.50. Them: latest 0.45, best 0.45.
  assert.equal(leadOf(0.5, 0.45), "you");
  const show = new RaceShow();
  const f = show.update(base({ youBest: 0.5, themBest: 0.45 }));
  assert.equal(f.lead, "you");
  assert.equal(leadOf(0.2, 0.45), "them");
});

test("equal whole-number scores are TIED", () => {
  assert.equal(leadOf(0.42, 0.42), "tied");
  assert.equal(leadOf(0.42000001, 0.41999999), "tied");   // float noise on the same score
  assert.equal(leadOf(0.43, 0.42), "you");
  assert.equal(leadOf(0, 0), "tied");
});

test("a lead change shows one event, then waits out the two-second gap", () => {
  const s = new RaceShow();
  s.update(base({ now: 0 }));
  const a = s.update(base({ now: 1000, youBest: 0.3 }));
  assert.equal(a.event, "youHotter");
  assert.equal(a.accent, "you");
  assert.equal(a.leadChanged, true);
  const b = s.update(base({ now: 1500, youBest: 0.3, themBest: 0.5 }));
  assert.equal(b.event, "youHotter", "first event still on screen");
  assert.equal(b.accent, "them");
  const c = s.update(base({ now: 1000 + MOMENTUM_SHOW_MS, youBest: 0.3, themBest: 0.5 }));
  assert.equal(c.event, null, "gone after 800 ms");
  const d = s.update(base({ now: 2999, youBest: 0.3, themBest: 0.5 }));
  assert.equal(d.event, null, "still inside the gap");
  const e = s.update(base({ now: 1000 + MOMENTUM_GAP_MS, youBest: 0.3, themBest: 0.5 }));
  assert.equal(e.event, "closingIn");
  assert.equal(e.leadChanges, 1);
});

test("a delayed lead event that is no longer true is dropped", () => {
  const s = new RaceShow();
  s.update(base({ now: 0 }));
  s.update(base({ now: 100, youBest: 0.3 }));                    // YOU'RE HOTTER
  s.update(base({ now: 500, youBest: 0.3, themBest: 0.3 }));     // DEAD HEAT waits
  const f = s.update(base({ now: 2200, youBest: 0.4, themBest: 0.3 }));
  // Lead went back to you before the slot opened. The queued DEAD HEAT is
  // stale and the new YOU'RE HOTTER replaced it in the slot.
  assert.equal(f.event, "youHotter");
  const g = new RaceShow();
  g.update(base({ now: 0 }));
  g.update(base({ now: 100, youBest: 0.3 }));                    // YOU'RE HOTTER
  g.update(base({ now: 500, youBest: 0.3, themBest: 0.3 }));     // DEAD HEAT waits
  g.update(base({ now: 900, youBest: 0.35, themBest: 0.3 }));    // replaced by YOU'RE HOTTER
  // Tied again when the slot opens: the queued YOU'RE HOTTER is stale and
  // never shows; the new DEAD HEAT does.
  const h = g.update(base({ now: 2200, youBest: 0.35, themBest: 0.35 }));
  assert.equal(h.event, "deadHeat");
  assert.equal(h.eventAt, 2200);
});

test("solve and result outrank every event", () => {
  const s = new RaceShow();
  s.update(base({ now: 0 }));
  assert.equal(s.update(base({ now: 100, youBest: 0.3 })).event, "youHotter");
  const f = s.update(base({ now: 200, youBest: 1, youSolved: true }));
  assert.equal(f.event, null);
  assert.deepEqual(f.voice, []);
  const g = s.update(base({ now: 5000, youBest: 1, youSolved: true, result: true, remainingMs: 10_000 }));
  assert.equal(g.event, null);
  assert.deepEqual(g.voice, []);
});

test("SUDDEN HEAT fires once when both reach the highest non-solved band", () => {
  const s = new RaceShow();
  s.update(base({ now: 0 }));
  s.update(base({ now: 100, youBest: 0.6, themBest: 0.59 }));
  const f = s.update(base({ now: 3000, youBest: 0.6, themBest: 0.6 }));
  assert.equal(f.event, "deadHeat", "tie came in the same update, same instant");
  const g = s.update(base({ now: 5000, youBest: 0.6, themBest: 0.6 }));
  assert.equal(g.event, "suddenHeat");
  const h = s.update(base({ now: 9000, youBest: 0.7, themBest: 0.6 }));
  assert.notEqual(h.event, "suddenHeat");
});

test("phases switch on the server's remaining time", () => {
  assert.equal(racePhase(300_000, false), "opening");
  assert.equal(racePhase(60_001, false), "opening");
  assert.equal(racePhase(60_000, false), "finalMinute");
  assert.equal(racePhase(15_001, false), "finalMinute");
  assert.equal(racePhase(15_000, false), "final15");
  assert.equal(racePhase(1, false), "final15");
  assert.equal(racePhase(0, false), "expired");
  assert.equal(racePhase(0, true), "result");
  assert.equal(phaseDance("opening"), "groove");
  assert.equal(phaseDance("finalMinute"), "swagger");
  assert.equal(phaseDance("final15"), "hype");
  assert.equal(phaseDance("expired"), null);
});

test("FINAL MINUTE and 15 SECONDS each announce once", () => {
  const s = new RaceShow();
  s.update(base({ now: 0, remainingMs: 61_000 }));
  const a = s.update(base({ now: 1000, remainingMs: 60_000 }));
  assert.equal(a.event, "finalMinute");
  assert.deepEqual(a.voice, ["raceFinalMinute"]);
  assert.deepEqual(s.update(base({ now: 4000, remainingMs: 57_000 })).voice, []);
  const b = s.update(base({ now: 46_000, remainingMs: 15_000 }));
  assert.equal(b.event, "final15");
  assert.deepEqual(b.voice, ["race15Seconds"]);
  const c = s.update(base({ now: 50_000, remainingMs: 11_000 }));
  assert.equal(c.event, null);
  assert.deepEqual(c.voice, []);
});

test("a match resumed inside the last 15 seconds skips FINAL MINUTE", () => {
  const s = new RaceShow();
  const f = s.update(base({ now: 0, remainingMs: 12_000 }));
  assert.equal(f.event, "final15");
  assert.deepEqual(f.voice, ["race15Seconds"]);
});

test("screen readers hear a lead change at most once every five seconds", () => {
  const s = new RaceShow();
  s.update(base({ now: 0 }));
  assert.deepEqual(s.update(base({ now: 1000, youBest: 0.3 })).voice, ["raceYouLead"]);
  assert.deepEqual(s.update(base({ now: 2000, youBest: 0.3, themBest: 0.4 })).voice, []);
  assert.deepEqual(s.update(base({ now: 5999, youBest: 0.3, themBest: 0.4 })).voice, []);
  assert.deepEqual(s.update(base({ now: 6000, youBest: 0.3, themBest: 0.4 })).voice, ["raceTheyLead"]);
  // A flip and flip back inside the gap says nothing at all.
  s.update(base({ now: 7000, youBest: 0.5, themBest: 0.4 }));
  assert.deepEqual(s.update(base({ now: 11_500, youBest: 0.5, themBest: 0.5 })).voice, ["raceTied"]);
});

test("timeout never declares a winner locally", () => {
  assert.equal(racePhase(0, false), "expired");
  const s = new RaceShow();
  s.update(base({ now: 0, remainingMs: 1000, youBest: 0.5, themBest: 0.4 }));
  const f = s.update(base({ now: 1000, remainingMs: 0, youBest: 0.5, themBest: 0.4 }));
  assert.equal(f.lead, "you", "the lead is still only a lead");
  assert.equal(f.event, null);
  const r = recapOf({
    reason: "timeout", winner: "me", draw: false,
    players: [
      { id: "me", solvedAtMs: null, bestWarmth: 0.5, guessCount: 9 },
      { id: "op", solvedAtMs: null, bestWarmth: 0.4, guessCount: 7 },
    ],
  }, "me");
  assert.equal(r.youGreen, false);
  assert.equal(r.themGreen, false);
  assert.equal(r.finishMs, null);
  assert.equal(r.headline, "won");
});

test("a local solve stays green; a loss makes only the opponent green", () => {
  const players = [
    { id: "me", solvedAtMs: 84_200, bestWarmth: 1, guessCount: 12 },
    { id: "op", solvedAtMs: null, bestWarmth: 0.62, guessCount: 15 },
  ];
  const win = recapOf({ reason: "solved", winner: "me", draw: false, players }, "me");
  assert.equal(win.outcome, "win");
  assert.equal(win.headline, "turnedGreen");
  assert.equal(win.youGreen, true);
  assert.equal(win.themGreen, false);
  assert.equal(win.youBand, "solved");
  assert.equal(win.themBand, "danger");
  assert.equal(win.finishMs, 84_200);

  const loss = recapOf({ reason: "solved", winner: "op", draw: false, players: [
    { id: "me", solvedAtMs: null, bestWarmth: 0.48, guessCount: 10 },
    { id: "op", solvedAtMs: 70_000, bestWarmth: 1, guessCount: 9 },
  ] }, "me");
  assert.equal(loss.outcome, "loss");
  assert.equal(loss.headline, "gotThereFirst");
  assert.equal(loss.youGreen, false);
  assert.equal(loss.themGreen, true);
  assert.equal(loss.youBand, "close");
  assert.equal(loss.finishMs, 70_000);

  const draw = recapOf({ reason: "timeout", winner: null, draw: true, players: [
    { id: "me", solvedAtMs: null, bestWarmth: 0.4, guessCount: 4 },
    { id: "op", solvedAtMs: null, bestWarmth: 0.4, guessCount: 5 },
  ] }, "me");
  assert.equal(draw.outcome, "draw");
  assert.equal(draw.headline, "draw");
  assert.equal(draw.youGreen || draw.themGreen, false);

  const voided = recapOf({ reason: "void", winner: null, draw: false, players: [] }, "me");
  assert.equal(voided.outcome, "void");
});

test("heat trails collapse repeats and cap at eight nodes", () => {
  const r = new TrailRecorder();
  r.push("you", "searching", 0);             // no guesses yet: nothing recorded
  assert.deepEqual(r.you, []);
  for (const b of ["searching", "searching", "trail", "trail", "heating", "danger", "danger", "solved"] as HeatBand[]) r.push("you", b, 1);
  assert.deepEqual(r.you, ["searching", "trail", "heating", "danger", "solved"]);
  const long: HeatBand[] = ["searching", "trail", "searching", "trail", "heating", "trail", "heating", "close", "heating", "danger", "solved"];
  const capped = capTrail(long);
  assert.equal(capped.length, 8);
  assert.equal(capped[0], "searching");
  assert.equal(capped[7], "solved");
  assert.deepEqual(capTrail(["trail", "close"]), ["trail", "close"]);
});

test("the opponent seat only carries public progress", () => {
  const leaky = {
    kind: "human", guessCount: 11, bestWarmth: 0.47, solved: false, connected: true,
    guesses: ["secretguess"], question: "is it an animal?", word: "tiger", score: 47,
  };
  const seat = opponentSeat(leaky);
  assert.deepEqual(Object.keys(seat).sort(), ["band", "connected", "guessCount", "paintScore", "solved"]);
  assert.equal(seat.band, "close");
  assert.equal(seat.paintScore, BAND_SCORE.close, "painted by band, never the real score");
  const text = JSON.stringify(seat);
  for (const leak of ["secretguess", "animal", "tiger", "47"]) assert.ok(!text.includes(leak), `leaked ${leak}`);
  assert.equal(opponentSeat({ guessCount: 0, bestWarmth: 0, solved: false, connected: true }).paintScore, null);
});

test("rematch cannot be submitted twice", () => {
  const g = new RematchGate();
  assert.equal(g.request(), true);
  assert.equal(g.request(), false);
  assert.equal(g.requested, true);
  g.reset();
  assert.equal(g.request(), true);
});

test("face-off counts 3, 2, 1, GUESS over the first seconds of the real clock", () => {
  assert.equal(faceOffStep(0), 3);
  assert.equal(faceOffStep(999), 3);
  assert.equal(faceOffStep(1000), 2);
  assert.equal(faceOffStep(2999), 1);
  assert.equal(faceOffStep(3000), 0);
  assert.equal(faceOffStep(3699), 0);
  assert.equal(faceOffStep(3700), null);
  assert.equal(faceOffEligible(400), true);
  assert.equal(faceOffEligible(FACEOFF_MS), false);
});

test("face-off: pupils glance in, tips lean in, planted pulses", () => {
  const you = faceOffStance(800, 1, false), them = faceOffStance(800, -1, false);
  assert.ok(you.gx > 0 && them.gx < 0, "pupils toward each other");
  assert.ok(you.tip > 0 && them.tip < 0, "tips lean in");
  const hit = faceOffStance(1110, 1, false);
  assert.ok(hit.sy < 0 && hit.sx > 0, "a squash, planted");
  const after = faceOffStance(3300, 1, false);
  assert.deepEqual(after, { gx: 0, tip: 0, sx: 0, sy: 0 }, "faces forward on GUESS");
});

test("Reduced Motion: no translation, rotation, shake or jump", () => {
  for (let ms = 0; ms <= 4000; ms += 10) {
    const s = faceOffStance(ms, 1, true);
    assert.equal(s.tip, 0);
    assert.equal(s.sx, 0);
    assert.equal(s.sy, 0);
    // A Stance has no x, y or rotation at all.
    assert.deepEqual(Object.keys(s).sort(), ["gx", "sx", "sy", "tip"]);
  }
  for (let ms = 0; ms <= 16_000; ms += 7) assert.equal(timerPulse(ms, true).scale, 1);
  assert.ok(timerPulse(14_990, true).opacity < 1, "reduced motion pulses brightness only");
});

test("final 15: one pulse per whole second, big numerals from 5", () => {
  assert.equal(timerPulse(20_000, false).scale, 1);
  assert.ok(timerPulse(14_000, false).scale > 1.05, "pulse lands as the second ticks");
  assert.equal(timerPulse(14_500, false).scale, 1, "and is over well before the next");
  assert.equal(finalCount(5_001), null);
  assert.equal(finalCount(5_000), 5);
  assert.equal(finalCount(4_001), 5);
  assert.equal(finalCount(1), 1);
  assert.equal(finalCount(0), null);
});

test("the clock carries forward between snapshots and reads like the server", () => {
  const fix = { elapsedMs: 10_000, remainingMs: 290_000, at: 50_000 };
  assert.deepEqual(clockAt(fix, 50_400), { elapsedMs: 10_400, remainingMs: 289_600 });
  assert.deepEqual(clockAt(fix, 49_000), { elapsedMs: 10_000, remainingMs: 290_000 });
  assert.equal(clockAt(fix, 400_000).remainingMs, 0);
  assert.equal(fmtRaceClock(300_000), "5:00");
  assert.equal(fmtRaceClock(134_001), "2:15");
  assert.equal(fmtRaceClock(134_000), "2:14");
  assert.equal(fmtRaceClock(0), "0:00");
  assert.equal(fmtElapsed(84_999), "1:24");
  assert.equal(fmtElapsed(0), "0:00");
});

test("every language table has the race keys, same placeholders, no em dash", () => {
  const ph = (s: string) => (s.match(/%@|%d/g) ?? []).sort();
  for (const lang of LANGS) {
    for (const k of RACE_KEYS) {
      const v = TABLES[lang][k];
      assert.ok(typeof v === "string" && v.length > 0, `${lang} is missing ${k}`);
      assert.deepEqual(ph(v), ph(TABLES.en[k]!), `${lang} ${k} placeholders`);
      assert.ok(!v.includes("\u2014"), `${lang} ${k} has an em dash`);
      assert.ok(!/\p{Extended_Pictographic}/u.test(v), `${lang} ${k} has an emoji`);
    }
  }
});
