// SPDX-License-Identifier: MPL-2.0
//
//  Golden numbers for the 3.8 motion director. HunchTests/WickMotionTests.swift
//  carries the same values (printed by `node tests/wickmotion.golden.ts`), so
//  any drift between wickmotion.ts and WickMotion.swift fails a test.
//

import {
  type ClipName, type Motion, type MotionInput, type WickDanceStyle,
  CLIPS, MotionDirector, clipInto, danceInto, hash01, idleBody, motionZero, phraseInto,
} from "../src/game/wickmotion.ts";
import { pulseAt } from "../src/game/music.ts";

const pick = (m: Motion): number[] => [m.x, m.y, m.rot, m.sx, m.sy, m.tip, m.tu, m.gx, m.gy, m.bl, m.br, m.ll, m.lr];
const input = (o: Partial<MotionInput>): MotionInput => ({ mood: "idle", rm: false, solveE: null, transitionE: null, pulse: null, ...o });

export function golden(): Record<string, number[]> {
  const out: Record<string, number[]> = {};
  for (const c of Object.keys(CLIPS) as ClipName[]) {
    const m = motionZero();
    clipInto(c, 0.2, 1, m);
    out[`clip:${c}@0.2`] = pick(m);
  }
  for (const s of ["groove", "swagger", "hype"] as WickDanceStyle[]) {
    const m = motionZero();
    phraseInto(s, 5.3, m, 1);
    out[`phrase:${s}@5.3`] = pick(m);
  }
  { const m = motionZero(); danceInto(pulseAt(240.3, 236, 240), m, "swagger"); out["drop@240.3"] = pick(m); }
  { const m = motionZero(); danceInto({ beat: 0.4, down: 0, energy: 0.6, flash: 0, time: 13.37 }, m); out["auto@13.37"] = pick(m); }
  { const m = motionZero(); idleBody(7.7, 1234, "warm", m); out["idle:warm@7.7"] = pick(m); }
  out["hash01(1234,5)"] = [hash01(1234, 5)];
  {
    const d = new MotionDirector(77);
    const m = motionZero();
    d.sample(0, input({ mood: "warm" }), m);
    d.cue(1, null);
    d.sample(1, input({ mood: "hot", transitionE: 0 }), m);
    d.sample(1.3, input({ mood: "hot", transitionE: 0.3 }), m);
    out["director:caught@1.3"] = pick(m);
    d.cue(1.35, "near");                       // interrupt mid-clip
    d.sample(1.4, input({ mood: "boiling", transitionE: 0.05 }), m);
    out["director:near@1.4"] = pick(m);
  }
  return out;
}

if (import.meta.url === `file://${process.argv[1]}`) console.log(JSON.stringify(golden()));
