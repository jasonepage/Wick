// SPDX-License-Identifier: MPL-2.0
//
//  wickmotion.ts: Wick's motion director (3.8).
//
//  Every frame is the sum of five channels, highest priority first:
//
//    5. solve        the solved sequence (wickface.ts SOLVE_*) owns everything
//    4. transition   the face and colour change: blink, compress, release
//    3. reaction     a short authored clip after a guess or a question
//    2. dance        the beat-locked phrase, only while race music plays
//    1. idle life    breath, tip drift, blinks and small attention events
//
//  A higher channel fades the lower ones out (120 ms) and back in (150 ms)
//  instead of cutting them, and a new reaction starts from the pose on screen
//  (the old clip's remainder is carried and faded), never from rest.
//
//  Everything here is pure data and arithmetic: no DOM, no timers, no random
//  numbers. "Random" choices come from hash01(seed, n), so a session's idle is
//  irregular but repeatable. The director keeps a little state (when things
//  started), but the same events and the same frame times always give the
//  same frames, so the Motion Studio can scrub it.
//
//  Units: x and y are fractions of Wick's width (y down), rot is degrees around
//  the base, sx and sy are scale DELTAS (0 is rest), tip is the flame tip's
//  lean from -1 to 1 (one unit is about 4% of his width), tu raises the tip
//  (viewBox units, negative is taller). The face accents are in the face art's
//  units: gx and gy move both pupils, bl and br move a brow (negative is up),
//  ll and lr close a lid (0 to 1) or, below 0, lift it.
//
//  KEEP IN LOCKSTEP with Hunch/Theme/WickMotion.swift: the same tables, the
//  same arithmetic, the same order. HunchTests/WickMotionTests.swift checks the
//  golden numbers printed by tests/wickmotion.test.ts.
//

import { SOLVE_DONE } from "./wickface.ts";

// ── types ───────────────────────────────────────────────────────────────────

export type MotionMood = "idle" | "freezing" | "cold" | "warm" | "hot" | "boiling" | "celebrating" | "grey";

export const CHANNELS = ["x", "y", "rot", "sx", "sy", "tip", "tu", "gx", "gy", "bl", "br", "ll", "lr"] as const;
export type Channel = typeof CHANNELS[number];

/** One frame of motion. `glow` is a brightness/opacity factor (Reduced Motion breath). */
export type Motion = Record<Channel, number> & { glow: number };

export function motionZero(): Motion {
  return { x: 0, y: 0, rot: 0, sx: 0, sy: 0, tip: 0, tu: 0, gx: 0, gy: 0, bl: 0, br: 0, ll: 0, lr: 0, glow: 1 };
}
export function motionReset(m: Motion): void {
  for (const c of CHANNELS) m[c] = 0;
  m.glow = 1;
}
export function motionAdd(out: Motion, m: Motion, w: number): void {
  if (w === 0) return;
  for (const c of CHANNELS) out[c] += m[c] * w;
}
export function motionCopy(out: Motion, m: Motion): void {
  for (const c of CHANNELS) out[c] = m[c];
  out.glow = m.glow;
}

export type WickDanceStyle = "groove" | "swagger" | "hype";

/** What the director needs to know about the music (music.ts Pulse). */
export interface MotionPulse { beat: number; down: number; energy: number; flash: number; time: number }

// ── small math ──────────────────────────────────────────────────────────────

export const clamp = (v: number, lo: number, hi: number): number => Math.max(lo, Math.min(hi, v));
/** Quintic smootherstep: zero speed and zero acceleration at both ends. */
export function smoother(u: number): number {
  const x = clamp(u, 0, 1);
  return x * x * x * (x * (x * 6 - 15) + 10);
}

/** A repeatable number in [0, 1) for (seed, n). Same bits as WickMotion.hash01. */
export function hash01(seed: number, n: number): number {
  let h = (seed ^ Math.imul(n + 1, 0x9e3779b1)) >>> 0;
  h = Math.imul(h ^ (h >>> 16), 0x85ebca6b) >>> 0;
  h = Math.imul(h ^ (h >>> 13), 0xc2b2ae35) >>> 0;
  h = (h ^ (h >>> 16)) >>> 0;
  return h / 4294967296;
}

/** A keyframe track [t0, v0, t1, v1, ...] at `e` seconds. Holds the first value
 *  before the first key and the last after the last; smootherstep between, so
 *  every key is a held pose. Overshoot is always an explicit key. */
export function track(keys: readonly number[], e: number): number {
  const n = keys.length;
  if (n < 2) return 0;
  if (e <= keys[0]!) return keys[1]!;
  for (let i = 2; i < n; i += 2) {
    const t1 = keys[i]!;
    if (e <= t1) {
      const t0 = keys[i - 2]!, v0 = keys[i - 1]!, v1 = keys[i + 1]!;
      const u = t1 > t0 ? (e - t0) / (t1 - t0) : 1;
      return v0 + (v1 - v0) * smoother(u);
    }
  }
  return keys[n - 1]!;
}

type Tracks = Partial<Record<Channel, readonly number[]>>;

function addTracks(out: Motion, tracks: Tracks, e: number, w: number): void {
  for (const c of CHANNELS) {
    const k = tracks[c];
    if (k) out[c] += track(k, e) * w;
  }
}

// ── 1. base pose per mood ───────────────────────────────────────────────────

/** The pose each mood rests in. Reactions arrive here and hold it. */
export const BASE: Record<MotionMood, Partial<Record<Channel, number>>> = {
  idle: {},
  celebrating: {},
  grey: { y: 0.008, sx: 0.02, sy: -0.04, tip: -0.32, tu: 1.5, gy: 8, ll: 0.14, lr: 0.14 },
  freezing: { sx: -0.012, sy: -0.008, ll: 0.12, lr: 0.12 },
  cold: { rot: 0.6, tip: 0.08, bl: 3 },
  warm: { sx: -0.004, sy: 0.01, tu: -1, bl: -3, br: -3 },
  hot: { x: -0.012, rot: -1, sx: 0.004, sy: -0.006, bl: 2, br: 2 },
  boiling: { sy: -0.004, gx: 6 },
};
/** A mood change without a reaction lands with the transition's release. */
export const BASE_WINDOW: readonly [number, number] = [0.15, 0.4];
/** The tip arrives later and settles last. */
export const TIP_LAG = 0.08;
export const TIP_EXTRA = 0.1;

// ── 2. idle life ────────────────────────────────────────────────────────────

/** Breath period (s) and vertical scale amplitude per mood. */
export const BREATH: Record<MotionMood, readonly [number, number]> = {
  idle: [3.2, 0.013], freezing: [3.6, 0.010], cold: [3.4, 0.011], warm: [3.0, 0.015],
  hot: [2.9, 0.016], boiling: [2.8, 0.018], celebrating: [3.0, 0.015], grey: [3.6, 0.010],
};

/** Breath, tip drift and (boiling only) a small ambient tremor, added to `out`. */
export function idleBody(lt: number, seed: number, mood: MotionMood, out: Motion, w = 1): void {
  if (w === 0) return;
  const [period, amp] = BREATH[mood];
  const b = Math.sin((2 * Math.PI * lt) / period + 2 * Math.PI * hash01(seed, 1));
  out.sy += amp * b * w;
  out.sx += -0.55 * amp * b * w;            // counter-scale: he breathes, he does not inflate
  out.y += -0.5 * amp * b * w;              // at most 0.9% of his size
  const q = 3.4 + 1.8 * hash01(seed, 2);    // 3.4 to 5.2 s
  out.tip += (0.62 * Math.sin((2 * Math.PI * lt) / q + 2 * Math.PI * hash01(seed, 3))
    + 0.16 * Math.sin((2 * Math.PI * lt) / (q * 0.61) + 2 * Math.PI * hash01(seed, 4))) * w;
  if (mood === "boiling") {
    out.x += 0.006 * (Math.sin(lt * 71) * 0.6 + Math.sin(lt * 113) * 0.4) * w;
    out.rot += 0.35 * Math.sin(lt * 97) * w;
  }
}

/** Reduced Motion: no movement, only a soft brightness breath. */
export function idleGlow(lt: number): number {
  return 0.86 + 0.14 * (Math.sin((lt * 2 * Math.PI) / 2.4) + 1) / 2;
}

export type AttentionKind = "glance" | "brow" | "blink" | "listen";
export const ATTENTION_KINDS: readonly AttentionKind[] = ["glance", "brow", "blink", "listen"];
/** Seconds between attention events (start to start), and the first one. */
export const ATTN_GAP: readonly [number, number] = [3.5, 7];
/** No attention event starts this soon after a guess, or after a keystroke. */
export const ATTN_QUIET_AFTER_GUESS = 0.8;
export const TYPING_QUIET = 1.6;

export interface AttnCursor { n: number; start: number }
export interface AttnEvent { kind: AttentionKind; n: number; start: number; dur: number; side: number }

/** The attention event running at local time `lt`, if any. `cur` caches where
 *  the schedule is so a long session does not rescan from the start. */
export function attentionAt(lt: number, seed: number, cur: AttnCursor, out: AttnEvent): boolean {
  if (cur.n < 0 || lt < cur.start) { cur.n = 0; cur.start = 2 + 1.5 * hash01(seed, 100); }
  for (;;) {
    const next = cur.start + ATTN_GAP[0] + (ATTN_GAP[1] - ATTN_GAP[0]) * hash01(seed, 300 + cur.n);
    if (next > lt) break;
    cur.n++;
    cur.start = next;
  }
  if (lt < cur.start) return false;
  const n = cur.n;
  const kind = ATTENTION_KINDS[Math.min(3, Math.floor(hash01(seed, 200 + n) * 4))]!;
  const r = hash01(seed, 500 + n);
  const dur = kind === "glance" ? 0.45 + 0.25 * r : kind === "blink" ? 0.17 + 0.06 * r : 0.9;
  if (lt - cur.start >= dur) return false;
  out.kind = kind; out.n = n; out.start = cur.start; out.dur = dur; out.side = hash01(seed, 400 + n);
  return true;
}

/** Up over `a` s, down over `b` s, inside a window of `dur` s. */
function env(e: number, dur: number, a: number, b: number): number {
  return smoother(e / a) * smoother((dur - e) / b);
}
/** An asymmetric slow blink lasting `d` s. */
export function blinkShape(e: number, d: number): number {
  if (e < 0) return 0;
  if (e < 0.07) return e / 0.07;
  if (e < d - 0.1) return 1;
  if (e < d) return (d - e) / 0.1;
  return 0;
}

export function attentionInto(ev: AttnEvent, lt: number, out: Motion, w: number): void {
  const e = lt - ev.start;
  switch (ev.kind) {
    case "glance": {                       // toward the input field, then back
      const k = env(e, ev.dur, 0.15, 0.15) * w;
      out.gy += 13 * k; out.gx += 3 * k;
      break;
    }
    case "brow": {                         // one brow lifts, holds, eases down
      const k = env(e, ev.dur, 0.2, 0.35) * w;
      if (ev.side < 0.5) out.bl -= 16 * k; else out.br -= 16 * k;
      break;
    }
    case "blink":                          // asymmetric: one lid leads by 30 ms
      out.ll += blinkShape(e, ev.dur) * w;
      out.lr += blinkShape(e - 0.03, ev.dur - 0.03) * w;
      break;
    case "listen":                         // the tip leans toward the interface
      out.tip += 0.4 * env(e, ev.dur, 0.25, 0.35) * w;
      break;
  }
}

// ── 3. reaction clips ───────────────────────────────────────────────────────

export type ClipName =
  | "deflate" | "cold-shoulder" | "inspect" | "interest" | "caught" | "hide-panic"
  | "judge" | "perk" | "turn-away" | "face-lead";

export interface ClipDef {
  dur: number;
  /** When the new mood's base pose ramps in, in clip seconds. */
  baseIn: readonly [number, number];
  tracks: Tracks;
}

/**
 * The authored clips. Every track ends at 0: the base pose of the new mood
 * (BASE, ramped in over `baseIn`) is what he holds afterwards. Eyes and brows
 * lead by 30 to 60 ms, the body anticipates, acts once, overshoots 8 to 16%
 * at most, and the tip settles last.
 */
export const CLIPS: Record<ClipName, ClipDef> = {
  // Grey: eyes fall first, he sinks and widens, the tip goes slack. No bounce back.
  "deflate": {
    dur: 0.62, baseIn: [0.04, 0.4],
    tracks: {
      gy: [0, 0, 0.04, 7, 0.2, 4, 0.4, 0],
      sy: [0, 0, 0.3, -0.006, 0.5, 0],
      sx: [0, 0, 0.3, 0.003, 0.5, 0],
      tip: [0, 0, 0.12, 0.06, 0.62, 0],
    },
  },
  // Blue: a quick inward squeeze, one restrained shiver, a late tip twitch.
  "cold-shoulder": {
    dur: 0.52, baseIn: [0.1, 0.4],
    tracks: {
      sy: [0, 0, 0.05, 0.008, 0.12, -0.02, 0.3, -0.012, 0.45, 0],
      sx: [0, 0, 0.05, -0.004, 0.12, -0.03, 0.3, -0.02, 0.45, 0],
      x: [0, 0, 0.14, 0, 0.19, -0.012, 0.25, 0.009, 0.31, 0],
      rot: [0, 0, 0.14, 0, 0.19, -0.6, 0.25, 0.45, 0.31, 0],
      tip: [0, 0, 0.3, 0, 0.36, 0.28, 0.44, -0.06, 0.52, 0],
      ll: [0, 0, 0.06, 0.12, 0.4, 0.04, 0.52, 0],
      lr: [0, 0, 0.06, 0.12, 0.4, 0.04, 0.52, 0],
    },
  },
  // Teal: lean in and to the side, eyes on the result, one brow down, hold 250 ms.
  "inspect": {
    dur: 0.68, baseIn: [0.47, 0.68],
    tracks: {
      rot: [0, 0, 0.04, 0, 0.1, -0.6, 0.23, 2.7, 0.47, 2.5, 0.6, -0.25, 0.68, 0],
      x: [0, 0, 0.04, 0, 0.1, -0.004, 0.23, 0.02, 0.47, 0.018, 0.6, -0.002, 0.68, 0],
      sx: [0, 0, 0.04, 0, 0.1, -0.004, 0.23, 0.025, 0.47, 0.022, 0.62, 0],
      sy: [0, 0, 0.04, 0, 0.1, -0.01, 0.23, 0.015, 0.47, 0.012, 0.62, 0],
      gx: [0, 0, 0.13, 8, 0.47, 8, 0.62, 0],
      gy: [0, 0, 0.13, 10, 0.47, 10, 0.62, 0],
      bl: [0, 0, 0.14, 10, 0.47, 10, 0.66, 0],
      br: [0, 0, 0.14, -5, 0.47, -5, 0.66, 0],
      tip: [0, 0, 0.12, 0, 0.3, -0.32, 0.55, -0.18, 0.68, 0],
    },
  },
  // Yellow: the tip perks first, he rises a little and narrows, one small settle.
  "interest": {
    dur: 0.56, baseIn: [0.3, 0.56],
    tracks: {
      tu: [0, 0, 0.08, -3.5, 0.24, -2.5, 0.56, 0],
      y: [0, 0, 0.04, 0, 0.1, 0.004, 0.23, -0.025, 0.38, 0.003, 0.56, 0],
      sx: [0, 0, 0.04, 0, 0.1, 0.008, 0.23, -0.02, 0.38, 0.003, 0.56, 0],
      sy: [0, 0, 0.04, 0, 0.1, -0.012, 0.23, 0.02, 0.38, -0.003, 0.56, 0],
      bl: [0, 0, 0.05, -6, 0.4, -5, 0.56, 0],
      br: [0, 0, 0.05, -6, 0.4, -5, 0.56, 0],
      gx: [0, 0, 0.05, -9, 0.4, -9, 0.56, 0],
    },
  },
  // Orange: eyes widen first, then a 3% recoil and 2 degrees away; he only
  // comes halfway back (the hot base pose keeps the other half).
  "caught": {
    dur: 0.65, baseIn: [0.4, 0.65],
    tracks: {
      ll: [0, 0, 0.04, -0.35, 0.2, -0.35, 0.45, 0],
      lr: [0, 0, 0.04, -0.35, 0.2, -0.35, 0.45, 0],
      bl: [0, 0, 0.04, -8, 0.22, -6, 0.45, 2, 0.65, 0],
      br: [0, 0, 0.04, -8, 0.22, -6, 0.45, 2, 0.65, 0],
      rot: [0, 0, 0.06, 0, 0.1, 0.35, 0.22, -2.1, 0.4, -1.8, 0.55, 0.12, 0.65, 0],
      x: [0, 0, 0.06, 0, 0.1, 0.003, 0.22, -0.028, 0.4, -0.024, 0.55, 0.002, 0.65, 0],
      sy: [0, 0, 0.06, 0, 0.1, 0.006, 0.22, -0.018, 0.4, -0.012, 0.55, 0],
      sx: [0, 0, 0.06, 0, 0.1, -0.003, 0.22, 0.01, 0.4, 0.008, 0.55, 0],
      tip: [0, 0, 0.14, 0, 0.3, 0.35, 0.5, -0.08, 0.65, 0],
    },
  },
  // Red: a 90 ms freeze, one sharp 3-frame shake, the tip snaps away and
  // over-corrects once, the eyes slide sideways into controlled fluster.
  "hide-panic": {
    dur: 0.76, baseIn: [0.3, 0.62],
    tracks: {
      x: [0, 0, 0.09, 0, 0.107, 0.022, 0.123, -0.015, 0.14, 0.007, 0.16, 0],
      rot: [0, 0, 0.09, 0, 0.107, 1.6, 0.123, -1.1, 0.14, 0.5, 0.16, 0],
      tip: [0, 0, 0.1, 0, 0.17, -0.6, 0.32, 0.24, 0.48, -0.05, 0.62, 0],
      tu: [0, 0, 0.1, 0, 0.17, -2, 0.4, 0],
      gx: [0, 0, 0.16, 0, 0.32, 8, 0.62, 0],
      bl: [0, 0, 0.03, -6, 0.3, -2, 0.62, 0],
      br: [0, 0, 0.03, -8, 0.3, -3, 0.62, 0],
      sy: [0, 0, 0.09, 0, 0.16, -0.015, 0.3, 0.004, 0.45, 0],
      sx: [0, 0, 0.09, 0, 0.16, 0.01, 0.3, -0.002, 0.45, 0],
    },
  },
  // repeat: a slow judgment blink, then one brow lift.
  "judge": {
    dur: 0.9, baseIn: [0, 0.3],
    tracks: {
      ll: [0, 0, 0.09, 1, 0.13, 1, 0.21, 0],
      lr: [0, 0, 0.03, 0, 0.12, 1, 0.16, 1, 0.24, 0],
      br: [0, 0, 0.3, 0, 0.42, -12, 0.72, -12, 0.9, 0],
      sy: [0, 0, 0.3, 0, 0.42, 0.006, 0.9, 0],
    },
  },
  // leap: the tip snaps up and he leans in. No generic bounce.
  "perk": {
    dur: 0.6, baseIn: [0.3, 0.6],
    tracks: {
      tu: [0, 0, 0.04, 0, 0.09, -4.5, 0.28, -3, 0.6, 0],
      tip: [0, 0, 0.09, 0, 0.14, 0.18, 0.24, -0.06, 0.34, 0],
      sx: [0, 0, 0.06, -0.005, 0.16, 0.022, 0.45, 0.018, 0.6, 0],
      sy: [0, 0, 0.06, -0.008, 0.16, 0.018, 0.45, 0.014, 0.6, 0],
      bl: [0, 0, 0.04, -6, 0.45, -5, 0.6, 0],
      br: [0, 0, 0.04, -6, 0.45, -5, 0.6, 0],
      gy: [0, 0, 0.04, -3, 0.45, -3, 0.6, 0],
    },
  },
  // regress: the eyes go first, then the body turns 2 to 3 degrees away.
  "turn-away": {
    dur: 0.8, baseIn: [0.6, 0.8],
    tracks: {
      gx: [0, 0, 0.08, -12, 0.62, -12, 0.8, 0],
      rot: [0, 0, 0.08, 0, 0.13, 0.3, 0.28, -2.6, 0.6, -2.4, 0.74, 0.2, 0.8, 0],
      x: [0, 0, 0.08, 0, 0.13, 0.002, 0.28, -0.012, 0.6, -0.01, 0.8, 0],
      tip: [0, 0, 0.18, 0, 0.36, 0.26, 0.6, 0.1, 0.8, 0],
      bl: [0, 0, 0.08, 3, 0.6, 3, 0.8, 0],
    },
  },
  // a wild question: the face leads, one tiny silhouette accent.
  "face-lead": {
    dur: 0.5, baseIn: [0, 0.3],
    tracks: {
      bl: [0, 0, 0.06, -9, 0.3, -7, 0.5, 0],
      br: [0, 0, 0.06, -6, 0.3, -5, 0.5, 0],
      gy: [0, 0, 0.06, -4, 0.35, -4, 0.5, 0],
      sy: [0, 0, 0.12, 0, 0.2, 0.01, 0.34, 0],
    },
  },
};

/** The entrance each temperature plays when a guess lands. */
export const MOOD_CLIP: Record<MotionMood, ClipName | null> = {
  grey: "deflate", freezing: "cold-shoulder", cold: "inspect", warm: "interest",
  hot: "caught", boiling: "hide-panic", idle: null, celebrating: null,
};

/** The physical clip for a cue. A personality beat (wickpersonality.ts kinds)
 *  wins over the temperature entrance; "question" is any Ask Wick reaction. */
export function clipForCue(mood: MotionMood, kind: string | null): { clip: ClipName; amp: number } | null {
  switch (kind) {
    case "repeat": return { clip: "judge", amp: 1 };
    case "leap": return { clip: "perk", amp: 1 };
    case "near": return { clip: "hide-panic", amp: 0.7 };
    case "regress": return { clip: "turn-away", amp: 1 };
    case "stall": return { clip: "deflate", amp: 1 };
    case "question": return { clip: "face-lead", amp: 1 };
    default: {
      const c = MOOD_CLIP[mood];
      return c ? { clip: c, amp: 1 } : null;
    }
  }
}

/** Reduced Motion keeps the face, the pupils, the brows and the tip, and at
 *  most a 2% scale change. */
export function reduceMotionClamp(m: Motion): void {
  m.x = 0; m.y = 0; m.rot = 0;
  m.sx = clamp(m.sx, -0.02, 0.02);
  m.sy = clamp(m.sy, -0.02, 0.02);
}

export function clipInto(name: ClipName, e: number, amp: number, out: Motion, w = 1): void {
  addTracks(out, CLIPS[name].tracks, e, amp * w);
}

// ── 4. face and colour transition ───────────────────────────────────────────

export const TRANSITION_DUR = 0.44;
/** 0-70 ms anticipate, 70-240 compress behind closed lids, 240-360 release
 *  with a small overshoot, 360-440 the tip catches up. */
export const TRANSITION: Tracks = {
  sy: [0, 0, 0.07, 0.015, 0.2, -0.04, 0.24, -0.04, 0.31, 0.005, 0.36, 0],
  sx: [0, 0, 0.07, -0.008, 0.2, 0.025, 0.24, 0.025, 0.31, -0.003, 0.36, 0],
  tip: [0, 0, 0.1, 0, 0.22, -0.16, 0.34, 0.12, 0.44, 0],
  tu: [0, 0, 0.1, 0, 0.22, 1.2, 0.34, -0.8, 0.44, 0],
};

/** The colour travels up the flame: bottom stop, middle (also the face's
 *  shading), top, all done behind the lids by 240 ms. Reduced Motion is one
 *  plain 300 ms crossfade. Returns [top, middle, bottom] in 0..1. */
export function colorWipe(e: number, rm: boolean, out: [number, number, number]): void {
  if (rm) { const u = smoother(e / 0.3); out[0] = u; out[1] = u; out[2] = u; return; }
  out[2] = smoother((e - 0.07) / 0.1);
  out[1] = smoother((e - 0.1) / 0.1);
  out[0] = smoother((e - 0.13) / 0.11);
}

// ── 5. dance phrases ────────────────────────────────────────────────────────

/** One beat of a phrase: where he is ON the beat, how he gets there. */
export interface DanceKey {
  x: number; y: number; rot: number; sx: number; sy: number; tip: number;
  gx: number; bl: number; br: number;
  /** Peak hop while travelling INTO this key (fraction of size). */
  hop: number;
  /** Squash on arriving at this key. */
  land: number;
  /** Fraction of the beat he holds the previous key before moving to this one. */
  hold: number;
}
const K = (o: Partial<DanceKey>): DanceKey => ({ x: 0, y: 0, rot: 0, sx: 0, sy: 0, tip: 0, gx: 0, bl: 0, br: 0, hop: 0, land: 0, hold: 0.25, ...o });

/** Eight beats each. Positive x and rot lean right; positive tip leans right. */
export const DANCE: Record<WickDanceStyle, readonly DanceKey[]> = {
  // Restrained confidence. Never above 5% of his size, never past 5 degrees.
  groove: [
    K({ x: -0.035, rot: -4, sx: 0.008, sy: -0.01, tip: 0.1, land: 0.02 }),          // 1 settle left, eyes forward
    K({ tip: 0.35, sx: -0.005, sy: 0.01, hold: 0.2 }),                               // 2 centre, tip trails right
    K({ x: 0.028, rot: 3.2, tip: -0.1, land: 0.015 }),                               // 3 settle right, smaller
    K({ br: -10, hold: 0.35 }),                                                      // 4 centre hold, brow accent
    K({ x: -0.045, y: -0.02, rot: -4.4, tip: 0.3, hop: 0.012, hold: 0.2 }),          // 5 deeper left, tiny float
    K({ sx: 0.018, sy: -0.03, land: 0.02 }),                                         // 6 centre, controlled squash
    K({ x: 0.035, rot: 4, tip: -0.25, gx: -10 }),                                    // 7 right lean, eyes opposite
    K({ land: 0.02, hold: 0.35 }),                                                   // 8 plant, ready to loop
  ],
  // The signature: hard plants and almost motionless holds.
  swagger: [
    K({ x: -0.07, rot: -8, sx: 0.015, sy: -0.025, gx: 12, land: 0.04, hold: 0.2 }), // 1 strong left plant, eyes right
    K({ sx: -0.02, sy: 0.035, tip: -0.45, hop: 0.03, hold: 0.15 }),                  // 2 tall centre pass, tip still left
    K({ x: 0.07, rot: 8, gx: -6, br: -6, land: 0.04, hold: 0.2 }),                   // 3 strong right plant, smirk peaks
    K({ x: 0.005, rot: 0.5, hold: 0.45 }),                                           // 4 brief centre hold
    K({ x: -0.05, rot: -6, sx: 0.035, sy: -0.06, hold: 0.2 }),                       // 5 low left compression
    K({ x: 0.02, rot: 3, sx: -0.022, sy: 0.04, tip: -0.4, hop: 0.05, hold: 0.05 }),  // 6 diagonal release
    K({ x: 0.075, rot: 9, gx: 4, br: -16, land: 0.035, hold: 0.2 }),                 // 7 right hero pose, brow up
    K({ sy: -0.01, land: 0.05, hold: 0.3 }),                                         // 8 weighted landing, reset
  ],
  // Final energy: bigger travel, then one connected crouch, launch, arc, land.
  hype: [
    K({ x: -0.09, rot: -9, sx: 0.018, sy: -0.03, gx: 12, land: 0.05, hold: 0.15 }), // 1
    K({ sx: -0.024, sy: 0.04, tip: -0.5, hop: 0.05, hold: 0.1 }),                    // 2
    K({ x: 0.09, rot: 9, br: -8, land: 0.05, hold: 0.15 }),                          // 3
    K({ hold: 0.4 }),                                                                // 4
    K({ y: 0.02, sx: 0.06, sy: -0.1, hold: 0.15 }),                                  // 5 crouch
    K({ x: 0.03, y: -0.22, rot: 4, sx: -0.05, sy: 0.08, tip: -0.6, hold: 0 }),       // 6 launch, 22% up
    K({ x: 0.06, rot: 2, hop: 0.06, land: 0.11, hold: 0 }),                          // 7 arc down, land, recoil
    K({ x: 0.02, rot: 1, br: -10, hold: 0.6 }),                                      // 8 hero hold
  ],
};

export const BEAT = 0.5;
/** The tip follows the body this many seconds late. */
export const DANCE_TIP_LAG = 0.08;

const PHRASE_CH = ["x", "y", "rot", "sx", "sy", "tip", "gx", "bl", "br"] as const;
const keyOf = (s: WickDanceStyle, i: number): DanceKey => DANCE[s][((i % 8) + 8) % 8]!;

/** Body rotation of a phrase at `beats` (float beats), with the settle. */
function phraseRot(s: WickDanceStyle, beats: number): number {
  const k = Math.floor(beats), ph = beats - k;
  const a = keyOf(s, k), b = keyOf(s, k + 1), p = keyOf(s, k - 1);
  const u = smoother((ph - b.hold) / (1 - b.hold));
  let rot = a.rot + (b.rot - a.rot) * u;
  if (ph < 0.35) rot += (a.rot - p.rot) * 0.12 * Math.sin((Math.PI * ph) / 0.35);
  return rot;
}

/** One phrase at `beats` into the music, added to `out` with weight `w`. */
export function phraseInto(s: WickDanceStyle, beats: number, out: Motion, w: number): void {
  if (w === 0) return;
  const k = Math.floor(beats), ph = beats - k;
  const a = keyOf(s, k), b = keyOf(s, k + 1), p = keyOf(s, k - 1);
  const u = smoother((ph - b.hold) / (1 - b.hold));
  for (const c of PHRASE_CH) out[c] += (a[c] + (b[c] - a[c]) * u) * w;
  out.y -= b.hop * Math.sin(Math.PI * u) * w;
  if (ph < 0.3) {                                   // land: one quick squash after the beat
    const s2 = a.land * Math.sin((Math.PI * ph) / 0.3) * w;
    out.sy -= s2; out.sx += 0.6 * s2;
  }
  if (ph < 0.35) {                                  // one corrective rebound past the plant
    const r = 0.12 * Math.sin((Math.PI * ph) / 0.35) * w;
    out.x += (a.x - p.x) * r;
    out.rot += (a.rot - p.rot) * r;
  }
  // The tip trails the body: opposite its rotation of a moment ago.
  out.tip += -clamp(phraseRot(s, beats - DANCE_TIP_LAG / BEAT) / 18, -0.6, 0.6) * w;
}

/** The music drop: launch, arc, land, recoil, settle. No rotation at all. */
export const DROP_DUR = 0.8;
export const DROP: Tracks = {
  y: [0, 0.02, 0.06, 0.02, 0.3, -0.22, 0.5, 0, 0.6, 0.006, 0.75, 0],
  sy: [0, -0.1, 0.06, -0.1, 0.18, 0.08, 0.4, 0.03, 0.5, -0.11, 0.6, 0.012, 0.75, 0],
  sx: [0, 0.06, 0.06, 0.06, 0.18, -0.05, 0.4, -0.02, 0.5, 0.065, 0.6, -0.008, 0.75, 0],
  tip: [0, 0, 0.2, -0.55, 0.45, 0.3, 0.6, -0.12, 0.8, 0],
};
/** The riser's crouch, which the drop starts from. */
export const CROUCH = { y: 0.02, sx: 0.06, sy: -0.1 } as const;

/** Vocabulary weights for an energy when no style is fixed: groove up to 0.45,
 *  swagger to 0.82, then a build into hype. */
export function vocabulary(energy: number): [number, number, number] {
  const toSwagger = smoother((energy - 0.4) / 0.1);
  const toHype = smoother((energy - 0.9) / 0.1);
  return [(1 - toSwagger) * (1 - toHype), toSwagger * (1 - toHype), toHype];
}

/**
 * The dance for one reading of the music, as fractions of size. `style`
 * fixes the vocabulary (the race passes swagger); left out, energy picks it.
 * Energy changes only a few things: a 0.85 to 1 amplitude, the riser crouch,
 * the build into hype, and the drop. It never multiplies everything.
 */
export function danceInto(p: MotionPulse, out: Motion, style?: WickDanceStyle, intensity = 1): void {
  const beats = p.time / BEAT;
  const amp = (0.85 + 0.15 * p.energy) * clamp(intensity, 0.35, 1.65);
  let wG: number, wS: number, wH: number;
  if (style) {
    const h = style === "hype" ? 0 : smoother((p.energy - 0.9) / 0.1);
    wG = style === "groove" ? 1 - h : 0;
    wS = style === "swagger" ? 1 - h : 0;
    wH = style === "hype" ? 1 : h;
  } else {
    [wG, wS, wH] = vocabulary(p.energy);
  }
  // Riser: a visible crouch before the drop (energy 0.82 to 1, before the flash).
  const crouch = p.flash <= 0 && p.energy > 0.82 ? smoother((p.energy - 0.82) / 0.18) : 0;
  // The drop owns the body for DROP_DUR and hands back over 150 ms.
  const since = p.flash > 0 ? -Math.log(Math.max(p.flash, 1e-9)) / 3 : Infinity;
  const dropW = since < DROP_DUR ? 1 : since < DROP_DUR + 0.15 ? 1 - smoother((since - DROP_DUR) / 0.15) : 0;
  const phraseW = amp * (1 - 0.6 * crouch) * (1 - dropW);
  phraseInto("groove", beats, out, wG * phraseW);
  phraseInto("swagger", beats, out, wS * phraseW);
  phraseInto("hype", beats, out, wH * phraseW);
  if (crouch > 0) { out.y += CROUCH.y * crouch; out.sx += CROUCH.sx * crouch; out.sy += CROUCH.sy * crouch; }
  if (dropW > 0) addTracks(out, DROP, Math.min(since, DROP_DUR), dropW);
}

/** Reduced Motion dance: a beat-timed brightness and an eyebrow on the bar. */
export function danceReducedInto(p: MotionPulse, out: Motion, w = 1): void {
  out.glow *= 1 - 0.08 * (1 - p.beat) * w;
  out.bl -= 5 * p.down * w;
  out.br -= 5 * p.down * w;
}

// ── the director ────────────────────────────────────────────────────────────

export interface MotionInput {
  mood: MotionMood;
  rm: boolean;
  /** Seconds into the solved sequence (null when none is running or it was
   *  already over when this Wick appeared). */
  solveE: number | null;
  /** Seconds since the last face or colour change began, or null. */
  transitionE: number | null;
  /** The race music, or null when he is not dancing. */
  pulse: MotionPulse | null;
  style?: WickDanceStyle;
  intensity?: number;
}

const FADE_IN = 0.12;
const FADE_OUT = 0.15;
const CARRY = 0.15;

/** How much a window [start, start + dur] suppresses the channels below it. */
export function overrideEnv(e: number, dur: number): number {
  if (e < 0 || e > dur + FADE_OUT) return 0;
  return smoother(e / FADE_IN) * (e < dur ? 1 : 1 - smoother((e - dur) / FADE_OUT));
}

/**
 * One per mounted Wick. Feed it the game's events (mood comes in every
 * frame; `cue` for a scored guess or a reaction; `input` for typing) and ask
 * for a frame with `sample`. Times are the renderer's clock, in seconds.
 */
export class MotionDirector {
  readonly seed: number;
  private epoch: number | null = null;
  private mood: MotionMood | null = null;
  private baseFrom = motionZero();
  private baseTo = motionZero();
  private baseAt = -99;
  private baseD0 = BASE_WINDOW[0];
  private baseD1 = BASE_WINDOW[1];
  private clip: ClipName | null = null;
  private clipAmp = 1;
  private clipAt = -99;
  private pending = false;
  private pendingKind: string | null = null;
  private pendingAt = 0;
  private carry = motionZero();
  private carryAt = -99;
  /** How much the interrupted clip was suppressing the channels below it. */
  private carryEnv = 0;
  private guessAt = -99;
  private focused = false;
  private focusAt = -99;
  private typedAt = -99;
  private typedCount = 0;
  private gazeW = 0;
  private lastLt: number | null = null;
  private cur: AttnCursor = { n: -1, start: 0 };
  private ev: AttnEvent = { kind: "glance", n: 0, start: 0, dur: 0, side: 0 };
  private tmp = motionZero();

  constructor(seed: number) { this.seed = seed >>> 0; }

  private local(t: number): number {
    if (this.epoch === null) this.epoch = t;
    return t - this.epoch;
  }

  /** A guess was scored, or Wick reacted. `kind` is a wickpersonality.ts
   *  reaction kind, "question" for Ask Wick, or null for a plain guess. */
  cue(t: number, kind: string | null): void {
    const lt = this.local(t);
    this.pending = true;
    this.pendingKind = kind;
    this.pendingAt = lt;
    this.guessAt = lt;
  }

  /** The input field gained or lost focus, or a key was typed. */
  input(t: number, focused: boolean, typed = false): void {
    const lt = this.local(t);
    if (focused && !this.focused) this.focusAt = lt;
    this.focused = focused;
    if (typed) { this.typedAt = lt; this.typedCount++; }
  }

  /** The current base pose (mood rest pose, mid-ramp if it is changing). */
  baseInto(lt: number, out: Motion): void {
    const u = smoother((lt - this.baseAt - this.baseD0) / Math.max(1e-6, this.baseD1 - this.baseD0));
    const ut = smoother((lt - this.baseAt - this.baseD0 - TIP_LAG) / Math.max(1e-6, this.baseD1 - this.baseD0 + TIP_EXTRA));
    for (const c of CHANNELS) {
      const k = c === "tip" || c === "tu" ? ut : u;
      out[c] += this.baseFrom[c] + (this.baseTo[c] - this.baseFrom[c]) * k;
    }
  }

  private setMood(lt: number, mood: MotionMood): void {
    const to = motionZero();
    for (const c of CHANNELS) to[c] = BASE[mood][c] ?? 0;
    if (this.mood === null) {
      motionCopy(this.baseFrom, to); motionCopy(this.baseTo, to); this.baseAt = -99;
    } else {
      const from = motionZero();
      this.baseInto(lt, from);
      this.baseFrom = from;
      this.baseTo = to;
      this.baseAt = lt;
      this.baseD0 = BASE_WINDOW[0];
      this.baseD1 = BASE_WINDOW[1];
      if (this.clip && Math.abs(lt - this.clipAt) < 0.1) {
        this.baseAt = this.clipAt;
        [this.baseD0, this.baseD1] = CLIPS[this.clip].baseIn;
      }
    }
    this.mood = mood;
  }

  private startClip(mood: MotionMood): void {
    this.pending = false;
    const pick = clipForCue(mood, this.pendingKind);
    if (!pick) return;
    const at = this.pendingAt;
    // Start from the pose on screen: carry whatever the old clip was doing,
    // plus what is left of an older carry (a third guess in quick succession).
    const keep = at - this.carryAt < CARRY ? 1 - smoother((at - this.carryAt) / CARRY) : 0;
    this.carryEnv = Math.max(this.clipEnvAt(at), this.carryEnv * keep);
    const m = this.tmp;
    motionReset(m);
    motionAdd(m, this.carry, keep);
    if (this.clip && at - this.clipAt < CLIPS[this.clip].dur) clipInto(this.clip, at - this.clipAt, this.clipAmp, m);
    motionCopy(this.carry, m);
    this.carryAt = at;
    this.clip = pick.clip;
    this.clipAmp = pick.amp;
    this.clipAt = at;
    if (Math.abs(this.baseAt - at) < 0.1) {
      this.baseAt = at;
      [this.baseD0, this.baseD1] = CLIPS[pick.clip].baseIn;
    }
  }

  private clipEnvAt(lt: number): number {
    return this.clip ? overrideEnv(lt - this.clipAt, CLIPS[this.clip].dur) : 0;
  }

  /** Is a reaction clip suppressing the lower channels at `lt`? (0..1) An
   *  interrupted clip's suppression fades with its carry, so nothing below
   *  pops back in for a frame. */
  clipEnv(lt: number): number {
    const carried = lt - this.carryAt < CARRY ? this.carryEnv * (1 - smoother((lt - this.carryAt) / CARRY)) : 0;
    return Math.max(this.clipEnvAt(lt), carried);
  }

  /** The clip running at `t` (for the studio readout and tests). */
  activeClip(t: number): ClipName | null {
    const lt = this.local(t);
    return this.clip && lt - this.clipAt < CLIPS[this.clip].dur ? this.clip : null;
  }

  sample(t: number, inp: MotionInput, out: Motion): void {
    const lt = this.local(t);
    const dt = this.lastLt === null ? 0 : clamp(lt - this.lastLt, 0, 0.1);
    this.lastLt = lt;
    if (inp.mood !== this.mood) this.setMood(lt, inp.mood);
    if (this.pending) this.startClip(inp.mood);
    motionReset(out);

    // 5. Solve: everything below fades out at once and back over 150 ms after.
    const sw = inp.solveE === null ? 1 : inp.solveE < SOLVE_DONE ? 0 : smoother((inp.solveE - SOLVE_DONE) / FADE_OUT);

    // 1. Base pose.
    this.baseInto(lt, out);

    // 3. Reaction clip, and the carried remainder of the one it interrupted.
    const ce = this.clipEnv(lt);
    if (this.clip) {
      const e = lt - this.clipAt;
      if (e < CLIPS[this.clip].dur) clipInto(this.clip, e, this.clipAmp, out);
    }
    if (lt - this.carryAt < CARRY) motionAdd(out, this.carry, 1 - smoother((lt - this.carryAt) / CARRY));

    // 4. Transition silhouette: the reaction owns the body when both run.
    const te = inp.transitionE;
    const tEnv = te === null ? 0 : overrideEnv(te, TRANSITION_DUR);
    if (te !== null && te < TRANSITION_DUR && !inp.rm) addTracks(out, TRANSITION, te, 1 - ce);

    // 2. Dance, suppressed by a reaction.
    const dancing = !!inp.pulse;
    if (inp.pulse) {
      const m = this.tmp;
      motionReset(m);
      if (inp.rm) danceReducedInto(inp.pulse, out, 1 - ce);
      else { danceInto(inp.pulse, m, inp.style, inp.intensity ?? 1); motionAdd(out, m, 1 - ce); }
    }

    // 1. Idle life, under everything.
    const typing = this.focused && lt - this.typedAt < TYPING_QUIET;
    let idleW = (1 - Math.max(ce, tEnv)) * (dancing ? 0.25 : 1) * (typing ? 0.4 : 1);
    if (inp.rm) { out.glow *= idleGlow(lt); idleW = 0; }
    idleBody(lt, this.seed, inp.mood, out, idleW);
    // Attention events: never two at once, never just after a guess, never
    // while typing, dancing, reacting or changing face.
    if (!dancing && attentionAt(lt, this.seed, this.cur, this.ev)) {
      const s = this.ev.start;
      const trStart = te === null ? null : lt - te;
      const blocked = (s >= this.guessAt && s - this.guessAt < ATTN_QUIET_AFTER_GUESS)
        || s - this.typedAt < TYPING_QUIET
        || (this.clip !== null && s >= this.clipAt && s - this.clipAt < CLIPS[this.clip].dur + FADE_OUT)
        || (trStart !== null && s >= trStart && s - trStart < TRANSITION_DUR + FADE_OUT);
      if (!blocked) attentionInto(this.ev, lt, out, 1 - Math.max(ce, tEnv));
    }

    // Typing awareness: look at the field on focus (180 ms), small pupil
    // tracking while typing, back to the player after 1.6 s of quiet.
    const look = this.focused && lt - Math.max(this.focusAt, this.typedAt) < TYPING_QUIET;
    this.gazeW = look ? Math.min(1, this.gazeW + dt / 0.18) : Math.max(0, this.gazeW - dt / 0.25);
    if (this.gazeW > 0) {
      const g = smoother(this.gazeW) * (1 - ce);
      out.gy += 13 * g;
      if (typing) out.gx += ((this.typedCount % 7) - 3) * 1.2 * g;
    }

    if (sw < 1) {
      for (const c of CHANNELS) out[c] *= sw;
    }
    if (inp.rm) reduceMotionClamp(out);
  }
}
