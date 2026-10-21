// SPDX-License-Identifier: MPL-2.0
//
//  wickface.ts: Wick's colours and face, shared by the web client.
//
//  The colour and label ramp is a faithful port of Hunch/Theme/HunchTheme.swift
//  (Palette, color(for:), label(for:)). Same RGB values, same score thresholds
//  (score = closeness 0..100). Wick's resting colour is the keeper violet
//  (purple): he starts purple before any warmth.
//
//  The mascot himself lives in wick.ts, which builds him once and moves him
//  from the clock, like KeeperView.swift on iOS. This file keeps the parts
//  both need: the palette, the mood for a score, the star shape, and the
//  Keeper's six faces with the chunky flame they sit on.
//

export type RGB = [number, number, number];

// Palette: exact RGB from HunchTheme.Palette (0..1 floats × 255).
export const PALETTE = {
  solved: [77, 158, 71] as RGB, // verdant green
  boiling: [232, 66, 54] as RGB, // ember red
  hot: [237, 107, 46] as RGB, // coral
  warm: [242, 166, 36] as RGB, // amber
  cool: [33, 161, 140] as RGB, // teal
  cold: [89, 189, 181] as RGB, // mint-teal
  freezing: [69, 133, 230] as RGB, // glacier blue
  keeper: [125, 92, 235] as RGB, // keeper violet, Wick's resting colour
  neutral: [120, 122, 134] as RGB, // deadpan grey ("Won't say" / unknown word)
};

function clamp01(w: number): number {
  return Math.max(0, Math.min(1, w));
}

export function rgb([r, g, b]: RGB): string {
  return `rgb(${r}, ${g}, ${b})`;
}
function rgba([r, g, b]: RGB, a: number): string {
  return `rgba(${r}, ${g}, ${b}, ${a})`;
}
/** Blend a colour toward white by fraction `f` (0..1), for the body's top highlight. */
export function lighten([r, g, b]: RGB, f: number): string {
  const m = (v: number) => Math.round(v + (255 - v) * f);
  return `rgb(${m(r)}, ${m(g)}, ${m(b)})`;
}

/** Temperature band for a closeness score (0..100); mirrors HunchTheme.color(for:). */
function band(score: number): RGB {
  if (score >= 100) return PALETTE.solved;
  if (score >= 60) return PALETTE.boiling;
  if (score >= 45) return PALETTE.hot;
  if (score >= 30) return PALETTE.warm;
  if (score >= 18) return PALETTE.cool;
  if (score >= 8) return PALETTE.cold;
  return PALETTE.freezing;
}

/** Heat word; mirrors HunchTheme.label(for:). */
export function scoreLabel(score: number): { label: string; hint: string } {
  if (score >= 100) return { label: "Solved!", hint: "you got it" };
  if (score >= 60) return { label: "Boiling", hint: "so hot!" };
  if (score >= 45) return { label: "Hot", hint: "so close" };
  if (score >= 30) return { label: "Warm", hint: "getting there" };
  if (score >= 18) return { label: "Cool", hint: "warming up" };
  if (score >= 8) return { label: "Cold", hint: "keep going" };
  return { label: "Freezing", hint: "keep going" };
}

/** CSS colour for a score (discrete band), or the resting violet if score is null. */
export function scoreColor(score: number | null): string {
  return score === null ? rgb(PALETTE.keeper) : rgb(band(score));
}
export function scoreColorA(score: number | null, a: number): string {
  return score === null ? rgba(PALETTE.keeper, a) : rgba(band(score), a);
}

export const RESTING_COLOR = rgb(PALETTE.keeper);

// ── moods ───────────────────────────────────────────────────────────────────

/** Wick's expression, mapped from the warmth band; mirrors KeeperMood.forScore. */
export type Mood =
  | "idle"
  | "freezing"
  | "cold"
  | "warm"
  | "hot"
  | "boiling"
  | "celebrating"
  | "unamused";

export function moodFor(opts: { score: number | null; neutral?: boolean }): Mood {
  if (opts.neutral) return "unamused";
  if (opts.score === null) return "idle";
  const s = opts.score;
  if (s >= 100) return "celebrating";
  if (s >= 60) return "boiling";
  if (s >= 45) return "hot";
  if (s >= 30) return "warm";
  if (s >= 18) return "cold";
  return "freezing";
}

/** Wick's body colour for a mood. Mirrors KeeperMood.bodyColor (unamused is the grey "Won't say" Wick on the web). */
export function moodRGB(mood: Mood): RGB {
  switch (mood) {
    case "freezing": return PALETTE.freezing;
    case "cold": return PALETTE.cold;
    case "warm": return PALETTE.warm;
    case "hot": return PALETTE.hot;
    case "boiling": return PALETTE.boiling;
    case "celebrating": return PALETTE.solved;
    case "unamused": return PALETTE.neutral;
    default: return PALETTE.keeper;
  }
}

/** A small n-pointed star path (celebrating eyes + solve sparkles). */
export function starPath(cx: number, cy: number, r: number): string {
  let d = "";
  for (let i = 0; i < 10; i++) {
    const rad = i % 2 ? r * 0.45 : r;
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    d += `${i ? "L" : "M"}${(cx + Math.cos(a) * rad).toFixed(1)} ${(cy + Math.sin(a) * rad).toFixed(1)} `;
  }
  return `${d}Z`;
}

/** Ring gauge: track + progress arc in `color`, filled to `fill` (0..1). */
export function ringSVG(fill: number, color: string): string {
  const t = clamp01(fill);
  const r = 52;
  const c = 2 * Math.PI * r;
  const offset = c * (1 - t);
  return `
  <svg class="ring" width="140" height="140" viewBox="0 0 120 120">
    <circle cx="60" cy="60" r="${r}" fill="none" stroke="rgba(255,255,255,0.08)" stroke-width="10"/>
    <circle cx="60" cy="60" r="${r}" fill="none" stroke="${color}" stroke-width="10"
      stroke-linecap="round" stroke-dasharray="${c.toFixed(1)}" stroke-dashoffset="${offset.toFixed(1)}"
      transform="rotate(-90 60 60)"/>
  </svg>`;
}

// ── the Keeper's faces ──────────────────────────────────────────────────────
//
//  The six approved faces from the final Keeper sheet (October 2026). Every
//  number below comes straight from the code that drew that sheet, in the art's
//  own units: the 1024 px icon, where the flame's tip is at (512, 152) and its
//  base at (512, 870). One transform (FACE_K, FACE_TX, FACE_TY) maps those units
//  into Wick's 120 x 128 viewBox, so the proportions match the sheet exactly.
//
//  The drawing is renderer neutral: `faceDrawList` returns a fixed list of SVG
//  path strings and colours, which wick.ts puts in an SVG, wickcanvas.ts paints
//  with Path2D, and KeeperView.swift mirrors on iOS.
//
//  KEEP IN LOCKSTEP with Hunch/Theme/KeeperFace.swift.

export type FaceName = "sly" | "flustered" | "shocked" | "calm" | "serious" | "focus";

/** One eye. lidL/lidR/sag: the heavy upper lid (y at its left and right ends,
 *  and how far it sags in the middle). closed 1 = shut (the Calm face); bow and
 *  tilt shape the shut lash line. pdx/pdy/pr: the pupil. */
export interface EyeP { cx: number; cy: number; rx: number; ry: number; lidL: number; lidR: number; sag: number; pdx: number; pdy: number; pr: number; closed: number; bow: number; tilt: number }
/** One bushy grey brow: a curve from the INNER end to the OUTER end, its weight
 *  and taper, two loose hairs [t, length, lean] and two tip wisps [lift, length, width]. */
export interface BrowP { c: number[][]; th: number; taper: number; peak: number; hairs: number[][]; tail: number[][] }
/** The mouth: a white stroke through `pts`, or (oval 1) the small dark "o". */
export interface MouthP { pts: number[][]; w: number; oval: number; ocx: number; ocy: number; orx: number; ory: number }
export interface DropP { on: number; x: number; y: number; r: number; h: number; tilt: number }
/** The flame tip's reaction, in viewBox units: curl (Sly), droop (Flustered), spike (Shocked). */
export interface TipP { dx: number; dy: number; sharp: number }
export interface FaceP { eyes: EyeP[]; brows: BrowP[]; mouth: MouthP; drop: DropP; tip: TipP }

export const FACES: Record<FaceName, FaceP> = {
  sly: {
    eyes: [
      { cx: 413, cy: 578, rx: 54, ry: 42, lidL: 590, lidR: 582, sag: 7, pdx: -24, pdy: 8, pr: 23, closed: 0, bow: 5, tilt: 0 },
      { cx: 611, cy: 578, rx: 54, ry: 42, lidL: 588, lidR: 583, sag: 7, pdx: -24, pdy: 8, pr: 23, closed: 0, bow: 5, tilt: 0 },
    ],
    brows: [
      { c: [[474, 537], [444, 533], [398, 534], [356, 544]], th: 35.84, taper: 0.5, peak: 0.25, hairs: [[0.18, 10, 40], [0.47, 8, 55]], tail: [[6, 20, 5], [0, 0, 0]] },
      { c: [[554, 522], [584, 494], [634, 480], [674, 494]], th: 35.84, taper: 0.5, peak: 0.35, hairs: [[0.22, 9, 35], [0.4, 12, 45]], tail: [[18, 28, 6], [-10, 18, 4]] },
    ],
    mouth: { pts: [[582.97, 702], [578.54, 703.21], [574.08, 704.35], [569.6, 705.42], [565.11, 706.41], [560.6, 707.33], [556.08, 708.17], [551.54, 708.93], [546.99, 709.61], [542.43, 710.21], [537.86, 710.72], [533.28, 711.13], [528.69, 711.45], [524.09, 711.67], [519.5, 711.78], [514.9, 711.77], [510.3, 711.63], [505.7, 711.35], [501.12, 710.93], [496.56, 710.35], [492.02, 709.59], [487.52, 708.64], [483.07, 707.49], [478.68, 706.1], [474.38, 704.47], [470.19, 702.57], [466.14, 700.39], [462.28, 697.9], [458.62, 695.11], [455.23, 692], [452.14, 688.6], [449.38, 684.92], [446.97, 681]], w: 24, oval: 0, ocx: 512, ocy: 712, orx: 18, ory: 23 },
    drop: { on: 0, x: 714, y: 560, r: 19, h: 50, tilt: -14 },
    tip: { dx: -4, dy: 0, sharp: 0.92 }, // curl
  },
  flustered: {
    eyes: [
      { cx: 413, cy: 578, rx: 54, ry: 50, lidL: 558, lidR: 540, sag: 6, pdx: 22, pdy: 14, pr: 23, closed: 0, bow: 5, tilt: 0 },
      { cx: 611, cy: 578, rx: 54, ry: 50, lidL: 540, lidR: 558, sag: 6, pdx: 22, pdy: 14, pr: 23, closed: 0, bow: 5, tilt: 0 },
    ],
    brows: [
      { c: [[462, 460], [430, 474], [392, 494], [358, 514]], th: 35.84, taper: 0.5, peak: 0.2, hairs: [[0.15, 9, 30], [0.42, 7, 50]], tail: [[10, 18, 4], [0, 0, 0]] },
      { c: [[564, 468], [592, 474], [628, 492], [662, 512]], th: 35.84, taper: 0.5, peak: 0.3, hairs: [[0.25, 8, 40], [0.55, 9, 55]], tail: [[-4, 16, 4], [0, 0, 0]] },
    ],
    mouth: { pts: [[464, 712], [466.6, 714.53], [469.29, 716.96], [472.16, 719.18], [475.31, 720.96], [478.79, 721.93], [482.4, 721.72], [485.78, 720.43], [488.82, 718.47], [491.62, 716.17], [494.27, 713.69], [496.86, 711.15], [499.48, 708.65], [502.22, 706.27], [505.17, 704.17], [508.44, 702.61], [512, 702], [515.56, 702.61], [518.83, 704.17], [521.78, 706.27], [524.52, 708.65], [527.14, 711.15], [529.73, 713.69], [532.38, 716.17], [535.18, 718.47], [538.22, 720.43], [541.6, 721.72], [545.21, 721.93], [548.69, 720.96], [551.84, 719.18], [554.71, 716.96], [557.4, 714.53], [560, 712]], w: 22, oval: 0, ocx: 512, ocy: 712, orx: 18, ory: 23 },
    drop: { on: 1, x: 714, y: 560, r: 19, h: 50, tilt: -14 },
    tip: { dx: 3.3, dy: 2.3, sharp: 1.08 }, // droop
  },
  shocked: {
    eyes: [
      { cx: 413, cy: 578, rx: 54, ry: 52, lidL: 531, lidR: 531, sag: 4, pdx: 0, pdy: 2, pr: 17, closed: 0, bow: 5, tilt: 0 },
      { cx: 611, cy: 578, rx: 54, ry: 52, lidL: 531, lidR: 531, sag: 4, pdx: 0, pdy: 2, pr: 17, closed: 0, bow: 5, tilt: 0 },
    ],
    brows: [
      { c: [[470, 488], [446, 466], [400, 458], [360, 472]], th: 35.84, taper: 0.5, peak: 0.3, hairs: [[0.2, 8, 35], [0.5, 10, 50]], tail: [[14, 20, 5], [0, 0, 0]] },
      { c: [[556, 474], [578, 446], [628, 436], [666, 452]], th: 35.84, taper: 0.5, peak: 0.4, hairs: [[0.3, 11, 40], [0.58, 8, 55]], tail: [[20, 24, 5], [-6, 14, 4]] },
    ],
    mouth: { pts: [[512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712]], w: 24, oval: 1, ocx: 512, ocy: 712, orx: 18, ory: 23 },
    drop: { on: 0, x: 714, y: 560, r: 19, h: 50, tilt: -14 },
    tip: { dx: 0, dy: -3, sharp: 0.82 }, // spike
  },
  serious: {
    eyes: [
      { cx: 413, cy: 578, rx: 54, ry: 42, lidL: 566, lidR: 586, sag: 5, pdx: 4, pdy: 8, pr: 23, closed: 0, bow: 5, tilt: 0 },
      { cx: 611, cy: 578, rx: 54, ry: 42, lidL: 586, lidR: 566, sag: 5, pdx: -4, pdy: 8, pr: 23, closed: 0, bow: 5, tilt: 0 },
    ],
    brows: [
      { c: [[484, 556], [448, 544], [402, 526], [356, 514]], th: 35.84, taper: 0.5, peak: 0.25, hairs: [[0.2, 9, 30], [0.45, 11, 45]], tail: [[8, 22, 5], [0, 0, 0]] },
      { c: [[540, 548], [578, 536], [624, 514], [668, 496]], th: 35.84, taper: 0.5, peak: 0.3, hairs: [[0.3, 8, 40], [0.6, 10, 50]], tail: [[12, 18, 4], [-8, 14, 3]] },
    ],
    mouth: { pts: [[474, 710], [476.38, 710], [478.75, 710], [481.12, 710], [483.5, 710], [485.88, 710], [488.25, 710], [490.62, 710], [493, 710], [495.38, 710], [497.75, 710], [500.12, 710], [502.5, 710], [504.88, 710], [507.25, 710], [509.62, 710], [512, 710], [514.38, 710], [516.75, 710], [519.12, 710], [521.5, 710], [523.88, 710], [526.25, 710], [528.62, 710], [531, 710], [533.38, 710], [535.75, 710], [538.12, 710], [540.5, 710], [542.88, 710], [545.25, 710], [547.62, 710], [550, 710]], w: 24, oval: 0, ocx: 512, ocy: 712, orx: 18, ory: 23 },
    drop: { on: 0, x: 714, y: 560, r: 19, h: 50, tilt: -14 },
    tip: { dx: 0, dy: 0, sharp: 1 }, // neutral
  },
  focus: {
    eyes: [
      { cx: 413, cy: 578, rx: 54, ry: 42, lidL: 592, lidR: 596, sag: 5, pdx: -2, pdy: 26, pr: 21, closed: 0, bow: 5, tilt: 0 },
      { cx: 611, cy: 578, rx: 54, ry: 42, lidL: 586, lidR: 582, sag: 5, pdx: -2, pdy: 26, pr: 21, closed: 0, bow: 5, tilt: 0 },
    ],
    brows: [
      { c: [[484, 550], [450, 548], [406, 548], [364, 552]], th: 35.84, taper: 0.5, peak: 0.25, hairs: [[0.25, 10, 35], [0.52, 8, 50]], tail: [[4, 18, 4], [0, 0, 0]] },
      { c: [[540, 548], [574, 544], [620, 542], [660, 546]], th: 35.84, taper: 0.5, peak: 0.3, hairs: [[0.2, 8, 40], [0.48, 10, 45]], tail: [[14, 20, 5], [0, 0, 0]] },
    ],
    mouth: { pts: [[486.01, 710], [487.63, 709.92], [489.24, 709.86], [490.86, 709.8], [492.48, 709.75], [494.1, 709.72], [495.71, 709.7], [497.33, 709.69], [498.95, 709.7], [500.57, 709.72], [502.19, 709.76], [503.81, 709.82], [505.42, 709.9], [507.04, 710], [508.65, 710.13], [510.26, 710.28], [511.87, 710.46], [513.48, 710.67], [515.08, 710.91], [516.67, 711.19], [518.26, 711.5], [519.84, 711.85], [521.41, 712.24], [522.97, 712.68], [524.52, 713.16], [526.04, 713.69], [527.55, 714.28], [529.04, 714.92], [530.5, 715.61], [531.93, 716.37], [533.33, 717.18], [534.69, 718.06], [536.01, 719]], w: 24, oval: 0, ocx: 512, ocy: 712, orx: 18, ory: 23 },
    drop: { on: 0, x: 714, y: 560, r: 19, h: 50, tilt: -14 },
    tip: { dx: 0, dy: 0, sharp: 1 }, // neutral
  },
  calm: {
    eyes: [
      { cx: 413, cy: 578, rx: 54, ry: 40, lidL: 587, lidR: 581, sag: 24, pdx: 0, pdy: 0, pr: 20, closed: 1, bow: 24, tilt: 3 },
      { cx: 611, cy: 578, rx: 54, ry: 40, lidL: 582, lidR: 586, sag: 24, pdx: 0, pdy: 0, pr: 20, closed: 1, bow: 24, tilt: -2 },
    ],
    brows: [
      { c: [[470, 506], [442, 492], [400, 488], [360, 498]], th: 35.84, taper: 0.5, peak: 0.3, hairs: [[0.2, 9, 35], [0.5, 8, 50]], tail: [[12, 20, 5], [0, 0, 0]] },
      { c: [[556, 498], [586, 482], [630, 476], [666, 488]], th: 35.84, taper: 0.5, peak: 0.35, hairs: [[0.25, 10, 40], [0.55, 8, 55]], tail: [[16, 24, 5], [-8, 14, 4]] },
    ],
    mouth: { pts: [[454, 700], [457, 702.79], [460.2, 705.37], [463.56, 707.72], [467.06, 709.85], [470.69, 711.77], [474.42, 713.47], [478.25, 714.96], [482.14, 716.24], [486.1, 717.31], [490.11, 718.19], [494.16, 718.86], [498.23, 719.33], [502.32, 719.61], [506.43, 719.7], [510.53, 719.59], [514.62, 719.28], [518.69, 718.78], [522.73, 718.08], [526.73, 717.18], [530.69, 716.09], [534.58, 714.8], [538.4, 713.31], [542.14, 711.62], [545.78, 709.73], [549.32, 707.65], [552.73, 705.37], [556.01, 702.9], [559.14, 700.25], [562.11, 697.43], [564.92, 694.44], [567.55, 691.29], [570, 688]], w: 24, oval: 0, ocx: 512, ocy: 712, orx: 18, ory: 23 },
    drop: { on: 0, x: 714, y: 560, r: 19, h: 50, tilt: -14 },
    tip: { dx: 0, dy: 0, sharp: 1 }, // neutral
  },
};

/** Art units to viewBox units. */
export const FACE_K = 120 / 718;
export const FACE_TX = 60 - 512 * FACE_K;
export const FACE_TY = 4 - 152 * FACE_K;
export const FACE_TRANSFORM = `translate(${FACE_TX.toFixed(3)} ${FACE_TY.toFixed(3)}) scale(${FACE_K.toFixed(5)})`;

export const EYE_WHITE: RGB = [245, 243, 254];
export const PUPIL: RGB = [31, 23, 59];
export const BROW_GREY: RGB = [214, 210, 228];

/** The inner flame (lighter core) in art units, for clipping the face shading. */
export const PLATE_ART = "M511.5 448.0 C585.0 490.4 655.9 540.0 655.9 657.5 C655.9 776.5 598.8 841.0 511.5 841.0 C425.2 841.0 368.1 776.5 368.1 657.5 C368.1 540.0 439.0 490.4 511.5 448.0 Z";

/** The chunky flame outline in viewBox units, fitted to the icon art. `lean` is
 *  the tip's sideways lean (the flicker), `tip` the face's tip reaction. */
export function chunkyFlamePath(lean = 0, tip: TipP = { dx: 0, dy: 0, sharp: 1 }): string {
  const f = (v: number): string => (Math.round(v * 10) / 10).toString();
  const tx = 60 + lean + tip.dx, ty = 4 + tip.dy;
  // Fitted to the icon: a sharp tip, shoulders pulled by one control each side
  // (moved by `sharp` and by the lean), widest at y 67.2, a round base.
  const sh = 43.986 * tip.sharp, sy = 20.605 + tip.dy * 0.5, sl = lean * 0.6;
  return `M60 124 C${f(37.084)} 124 16 109.2 16 67.2 ` +
    `C${f(60 - sh + sl)} ${f(sy)} ${f(tx)} ${f(ty)} ${f(tx)} ${f(ty)} ` +
    `C${f(tx)} ${f(ty)} ${f(60 + sh + sl)} ${f(sy)} 104 67.2 ` +
    `C104 109.2 ${f(82.916)} 124 60 124 Z`;
}
/** The inner flame (lighter core) in viewBox units. */
export const PLATE_PATH = "M60 53.5 C72.2 60.6 84 68.8 84 88.5 C84 108.4 74.5 119.2 60 119.2 C45.5 119.2 36 108.4 36 88.5 C36 68.8 47.8 60.6 60 53.5 Z";

/** Which face for the game's state. Solved stays Shocked (he keeps blinking). */
export function faceFor(o: { mood: Mood; race?: boolean; focus?: boolean }): FaceName {
  if (o.mood === "celebrating") return "shocked";
  if (o.focus) return "focus";
  if (o.mood === "unamused") return "calm";
  if (o.race) return "serious";
  if (o.mood === "warm" || o.mood === "hot" || o.mood === "boiling") return "flustered";
  return "sly";
}

/** Blend two faces (u 0 gives a, 1 gives b), number by number. */
export function lerpFace(a: FaceP, b: FaceP, u: number): FaceP {
  const L = (x: unknown, y: unknown): unknown => {
    if (typeof x === "number" && typeof y === "number") return x + (y - x) * u;
    if (Array.isArray(x) && Array.isArray(y)) return x.map((v, i) => L(v, y[i]));
    if (x && typeof x === "object" && y && typeof y === "object") {
      const o: Record<string, unknown> = {};
      for (const k of Object.keys(x)) o[k] = L((x as Record<string, unknown>)[k], (y as Record<string, unknown>)[k]);
      return o;
    }
    return u < 0.5 ? x : y;
  };
  return L(a, b) as FaceP;
}

/** The transition blink when the face changes: shut in 90 ms, hold while the
 *  face morphs behind the lids, open by 420 ms. */
export function swapBlink(e: number): number {
  if (e < 0) return 0;
  if (e < 0.09) return e / 0.09;
  if (e < 0.30) return 1;
  if (e < 0.42) return 1 - (e - 0.30) / 0.12;
  return 0;
}
/** How far through the morph the brows, mouth and tip are `e` seconds in. */
export function swapMorph(e: number): number {
  const x = Math.max(0, Math.min(1, (e - 0.06) / 0.32));
  return x * x * (3 - 2 * x);
}

// ── geometry (art units) ──

type Pt = [number, number];
const n2 = (v: number): string => (Math.round(v * 10) / 10).toString();
function polyPath(pts: Pt[]): string {
  if (pts.length < 3) return "";
  let d = `M${n2(pts[0]![0])} ${n2(pts[0]![1])}`;
  for (let i = 1; i < pts.length; i++) d += `L${n2(pts[i]![0])} ${n2(pts[i]![1])}`;
  return d + "Z";
}
/** A region swept column by column: for each x, the [top, bottom] span (or null). */
function columns(x0: number, x1: number, n: number, span: (x: number) => [number, number] | null): string {
  let best: Pt[][] = [[], []], cur: Pt[][] = [[], []];
  for (let i = 0; i < n; i++) {
    const x = x0 + (x1 - x0) * (0.5 - 0.5 * Math.cos((Math.PI * i) / (n - 1)));
    const s = span(x);
    if (s && s[1] - s[0] > 0.05) { cur[0]!.push([x, s[0]]); cur[1]!.push([x, s[1]]); }
    else { if (cur[0]!.length > best[0]!.length) best = cur; cur = [[], []]; }
  }
  if (cur[0]!.length > best[0]!.length) best = cur;
  return polyPath([...best[0]!, ...best[1]!.reverse()]);
}
const half = (x: number, cx: number, r: number): number => {
  const q = 1 - ((x - cx) / r) ** 2;
  return q > 0 ? Math.sqrt(q) : -1;
};
function quad(x: number, x0: number, x1: number, yL: number, yR: number, sag: number): number {
  const u = Math.max(0, Math.min(1, (x - x0) / (x1 - x0)));
  return (1 - u) ** 2 * yL + 2 * u * (1 - u) * ((yL + yR) / 2 + sag) + u * u * yR;
}
/** The open lid line and the shut lash line. */
const lidY = (e: EyeP, x: number): number => quad(x, e.cx - e.rx - 10, e.cx + e.rx + 10, e.lidL, e.lidR, e.sag);
const shutY = (e: EyeP, x: number): number => quad(x, e.cx - e.rx, e.cx + e.rx, e.cy + 6 + e.tilt, e.cy + 6 - e.tilt, e.bow);

export interface EyeShapes { lid: string; bag: string; white: string; pupil: string; lash: string; lashOpacity: number }
/** One eye at closure `c` (0 open, 1 shut): heavy lid, under-eye bag, white, pupil, lash line. */
export function eyeShapes(e: EyeP, c: number): EyeShapes {
  const upper = (x: number): number => lidY(e, x) + (shutY(e, x) - lidY(e, x)) * c;
  const lower = (x: number): number => e.cy + e.ry + (shutY(e, x) - (e.cy + e.ry)) * c;
  const inEye = (x: number): [number, number] | null => {
    const h = half(x, e.cx, e.rx);
    if (h < 0) return null;
    return [Math.max(e.cy - e.ry * h, upper(x)), Math.min(e.cy + e.ry * h, lower(x))];
  };
  const white = columns(e.cx - e.rx, e.cx + e.rx, 40, inEye);
  const px = e.cx + e.pdx, py = e.cy + e.pdy;
  const pupil = columns(px - e.pr, px + e.pr, 28, (x) => {
    const w = inEye(x), h = half(x, px, e.pr);
    if (!w || h < 0) return null;
    return [Math.max(w[0], py - e.pr * h), Math.min(w[1], py + e.pr * h)];
  });
  const lid = columns(e.cx - e.rx - 6, e.cx + e.rx + 6, 40, (x) => {
    const h = half(x, e.cx, e.rx + 6);
    if (h < 0) return null;
    return [e.cy - (e.ry + 6) * h, Math.min(e.cy + (e.ry + 6) * h, upper(x))];
  });
  const bag = columns(e.cx - e.rx * 0.8, e.cx + e.rx * 0.8, 28, (x) => {
    const h1 = half(x, e.cx, e.rx * 0.8), h2 = half(x, e.cx, e.rx + 5);
    if (h1 < 0) return null;
    const bottom = e.cy + 5 + (e.ry + 10) * h1;
    const top = Math.max(h2 < 0 ? -Infinity : e.cy + (e.ry + 4) * h2, e.cy + e.ry * 0.35);
    return [top, bottom];
  });
  let lash = "";
  for (let i = 0; i <= 24; i++) {
    const x = e.cx - e.rx + (2 * e.rx * i) / 24;
    lash += `${i ? "L" : "M"}${n2(x)} ${n2(upper(x))}`;
  }
  const lo = Math.max(0, Math.min(1, (c - 0.55) / 0.35));
  return { lid, bag, white, pupil, lash, lashOpacity: lo * lo * (3 - 2 * lo) };
}

function bez(c: number[][], t: number): Pt {
  const [p0, p1, p2, p3] = c as [number[], number[], number[], number[]];
  const a = (1 - t) ** 3, b = 3 * (1 - t) ** 2 * t, d = 3 * (1 - t) * t * t, e = t ** 3;
  return [a * p0[0]! + b * p1[0]! + d * p2[0]! + e * p3[0]!, a * p0[1]! + b * p1[1]! + d * p2[1]! + e * p3[1]!];
}
/** A bushy grey brow: tapered body with a soft uneven top, loose hairs and tip wisps. */
export function browPath(b: BrowP): string {
  const n = 120, th = b.th, C = b.c;
  const cen: Pt[] = [];
  for (let i = 0; i <= n; i++) cen.push(bez(C, i / n));
  const fr = (i: number): [number, number, number, number] => {
    const a = cen[Math.max(i - 1, 0)]!, q = cen[Math.min(i + 1, n)]!;
    let tx = q[0] - a[0], ty = q[1] - a[1];
    const L = Math.hypot(tx, ty) || 1; tx /= L; ty /= L;
    let nx = ty, ny = -tx;
    if (ny > 0) { nx = -nx; ny = -ny; }
    return [tx, ty, nx, ny];
  };
  const width = (t: number): number => {
    const rise = b.peak > 0 ? Math.min(1, t / b.peak) : 1;
    const fall = Math.max(0, (t - b.peak) / (1 - b.peak));
    return th * (0.72 + 0.28 * Math.sin((rise * Math.PI) / 2)) * (1 - b.taper * fall ** 1.4);
  };
  const ph = ((C[0]![0]! * 0.37 + C[0]![1]! * 0.11) % 6.28);
  const top: Pt[] = [], bot: Pt[] = [];
  for (let i = 0; i <= n; i++) {
    const [, , nx, ny] = fr(i); const t = i / n; const w = width(t) / 2;
    const rough = th * 0.055 * (Math.sin(2 * Math.PI * 2.4 * t + ph) + 0.5 * Math.sin(2 * Math.PI * 5.3 * t + ph * 1.7)) * (0.3 + 0.7 * t);
    const [x, y] = cen[i]!;
    top.push([x + nx * (w + rough), y + ny * (w + rough)]); bot.push([x - nx * w, y - ny * w]);
  }
  const [tx0, ty0, nx0, ny0] = fr(0); const [x0, y0] = cen[0]!; const w0 = width(0) / 2;
  const cap: Pt[] = [];
  for (let k = 1; k < 20; k++) {
    const a = (Math.PI * k) / 20;
    cap.push([x0 + nx0 * w0 * Math.cos(a) - tx0 * w0 * Math.sin(a), y0 + ny0 * w0 * Math.cos(a) - ty0 * w0 * Math.sin(a)]);
  }
  let d = polyPath([...top, ...bot.reverse(), ...cap.reverse()]);
  const strand = (pts: Pt[], ws: number[], px: number, py: number): string =>
    polyPath([...pts.map((p, k): Pt => [p[0] + px * ws[k]!, p[1] + py * ws[k]!]), ...pts.map((p, k): Pt => [p[0] - px * ws[k]!, p[1] - py * ws[k]!]).reverse()]);
  for (const [t, ln, lean] of b.hairs as [number, number, number][]) {
    if (ln < 0.5) continue;
    const i = Math.floor(t * n); const [tx, ty, nx, ny] = fr(i); const w = width(t) / 2;
    const bx = cen[i]![0] + nx * (w - 3), by = cen[i]![1] + ny * (w - 3);
    const a = (lean * Math.PI) / 180; const dx = nx * Math.cos(a) + tx * Math.sin(a), dy = ny * Math.cos(a) + ty * Math.sin(a);
    const L = ln * 1.4; const pts: Pt[] = [], ws: number[] = [];
    for (let k = 0; k <= 20; k++) { const u = k / 20; pts.push([bx + dx * L * u + tx * L * 0.35 * u * u, by + dy * L * u + ty * L * 0.35 * u * u]); ws.push(3.2 * (1 - u) + 0.4); }
    d += strand(pts, ws, -dy, dx);
  }
  const [tx, ty, nx, ny] = fr(n - 6); const [ex, ey] = cen[n - 6]!;
  for (const [lift, ln, wd] of b.tail as [number, number, number][]) {
    if (ln < 0.5) continue;
    const a = (lift * Math.PI) / 180; const dx = tx * Math.cos(a) + nx * Math.sin(a), dy = ty * Math.cos(a) + ny * Math.sin(a);
    const pts: Pt[] = [], ws: number[] = [];
    for (let k = 0; k <= 24; k++) { const u = k / 24; pts.push([ex + dx * ln * u + nx * ln * 0.18 * u * u, ey + dy * ln * u + ny * ln * 0.18 * u * u]); ws.push(wd * (1 - u)); }
    d += strand(pts, ws, -dy, dx);
  }
  return d;
}
/** The sweat drop: a circle and the triangle up to its tip, turned by `tilt`. */
export function dropPath(dp: DropP): string {
  const s = 0.4 + 0.6 * dp.on, r = dp.r * s, h = dp.h * s;
  const a = (dp.tilt * Math.PI) / 180, k = r / h, tx = r * Math.sqrt(1 - k * k), ty = -r * k;
  const rot = (x: number, y: number): Pt => [dp.x + x * Math.cos(a) - y * Math.sin(a), dp.y + x * Math.sin(a) + y * Math.cos(a)];
  const circle: Pt[] = [];
  for (let i = 0; i < 28; i++) { const t = (2 * Math.PI * i) / 28; circle.push([dp.x + r * Math.cos(t), dp.y + r * Math.sin(t)]); }
  return polyPath([rot(0, -h), rot(tx, ty), rot(-tx, ty)]) + polyPath(circle);
}
export function mouthStrokePath(m: MouthP): string {
  return m.pts.map((p, i) => `${i ? "L" : "M"}${n2(p[0]!)} ${n2(p[1]!)}`).join("");
}
export function mouthOvalPath(m: MouthP): string {
  const s = 0.3 + 0.7 * m.oval; const pts: Pt[] = [];
  for (let i = 0; i < 28; i++) { const t = (2 * Math.PI * i) / 28; pts.push([m.ocx + m.orx * s * Math.cos(t), m.ocy + m.ory * s * Math.sin(t)]); }
  return polyPath(pts);
}

// ── shading: one rule for the whole face ──
//  The inner flame is one tone step UP from the body (white at 22%). The
//  under-eye bags are that same step DOWN, and the heavy lids 1.3 steps down.
export function plateRGB(c: RGB): RGB {
  return [c[0] + (255 - c[0]) * 0.22, c[1] + (255 - c[1]) * 0.22, c[2] + (255 - c[2]) * 0.22];
}
/** `base` stepped down `steps` tone steps for body colour `c`. */
export function shadeRGB(base: RGB, c: RGB, steps: number): RGB {
  const p = plateRGB(c);
  return [0, 1, 2].map((k) => Math.round(Math.max(0, Math.min(255, base[k]! * Math.pow(c[k]! / Math.max(1, p[k]!), steps))))) as RGB;
}

/** One shape to draw, in art units. `plate` = clip to the inner flame. */
export interface DrawItem { d: string; fill?: string; stroke?: string; width?: number; opacity: number; plate?: boolean }

/** Everything in the face, back to front, always the same 18 slots (some may be empty). */
export function faceDrawList(p: FaceP, closure: number[], color: RGB): DrawItem[] {
  const plate = plateRGB(color);
  const items: DrawItem[] = [];
  const shapes = p.eyes.map((e, i) => eyeShapes(e, closure[i] ?? 0));
  for (const s of shapes) {
    items.push({ d: s.bag, fill: rgb(shadeRGB(color, color, 1)), opacity: 1 });
    items.push({ d: s.bag, fill: rgb(shadeRGB(plate, color, 1)), opacity: 1, plate: true });
    items.push({ d: s.lid, fill: rgb(shadeRGB(color, color, 1.3)), opacity: 1 });
    items.push({ d: s.lid, fill: rgb(shadeRGB(plate, color, 1.3)), opacity: 1, plate: true });
  }
  for (const s of shapes) {
    items.push({ d: s.white, fill: rgb(EYE_WHITE), opacity: 1 });
    items.push({ d: s.pupil, fill: rgb(PUPIL), opacity: 1 });
    items.push({ d: s.lash, stroke: rgb(EYE_WHITE), width: 16, opacity: s.lashOpacity });
  }
  items.push({ d: p.brows.map(browPath).join(""), fill: rgb(BROW_GREY), opacity: 1 });
  items.push({ d: mouthStrokePath(p.mouth), stroke: rgb(EYE_WHITE), width: p.mouth.w, opacity: 1 - p.mouth.oval });
  items.push({ d: p.mouth.oval > 0.01 ? mouthOvalPath(p.mouth) : "", fill: rgb(PUPIL), opacity: p.mouth.oval });
  items.push({ d: p.drop.on > 0.01 ? dropPath(p.drop) : "", fill: rgb(EYE_WHITE), opacity: p.drop.on });
  return items;
}
