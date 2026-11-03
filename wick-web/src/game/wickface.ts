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
  keeper: [116, 68, 240] as RGB, // canon Wick violet
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

export type FaceName = "sly" | "flustered" | "shocked" | "calm" | "serious" | "focus" | "warm" | "hot";

/** One eye. lidL/lidR/sag: the heavy upper lid (y at its left and right ends,
 *  and how far it sags in the middle). closed 1 = shut (the Calm face); bow and
 *  tilt shape the shut lash line. pdx/pdy/pr: the pupil. */
export interface EyeP { cx: number; cy: number; rx: number; ry: number; lidL: number; lidR: number; sag: number; pdx: number; pdy: number; pr: number; closed: number; bow: number; tilt: number }
/** One sculpted purple brow: a curve from the INNER end to the OUTER end, its
 *  weight and taper, and two broad integrated crown tufts [t, height, lean]. */
export interface BrowP { c: number[][]; th: number; taper: number; peak: number; hairs: number[][]; tail: number[][] }
/** The mouth: a white stroke through `pts`, or (oval 1) the small dark "o". */
export interface MouthP { pts: number[][]; w: number; oval: number; ocx: number; ocy: number; orx: number; ory: number }
export interface DropP { on: number; x: number; y: number; r: number; h: number; tilt: number }
/** The flame tip's reaction, in viewBox units: curl (Sly), droop (Flustered), spike (Shocked). */
export interface TipP { dx: number; dy: number; sharp: number }
export interface FaceP { eyes: EyeP[]; brows: BrowP[]; mouth: MouthP; drop: DropP; tip: TipP }

function mouthLine(x0: number, y0: number, x1: number, y1: number, bend: number, w: number): MouthP {
  const pts: number[][] = [];
  for (let i = 0; i <= 32; i++) {
    const t = i / 32;
    pts.push([x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + bend * 4 * t * (1 - t)]);
  }
  return { pts, w, oval: 0, ocx: 512, ocy: 712, orx: 18, ory: 23 };
}

export const FACES: Record<FaceName, FaceP> = {
  sly: {
    eyes: [
      { cx: 413, cy: 590, rx: 52, ry: 40, lidL: 584, lidR: 596, sag: 5, pdx: -18, pdy: 9, pr: 19, closed: 0, bow: 5, tilt: 0 },
      { cx: 611, cy: 590, rx: 52, ry: 40, lidL: 596, lidR: 584, sag: 5, pdx: -18, pdy: 9, pr: 19, closed: 0, bow: 5, tilt: 0 },
    ],
    brows: [
      { c: [[482, 554], [452, 538], [402, 510], [350, 494]], th: 39, taper: 0.68, peak: 0.18, hairs: [[0.18, 10, 40], [0.47, 8, 55]], tail: [[6, 20, 5], [0, 0, 0]] },
      { c: [[542, 554], [572, 536], [624, 506], [674, 490]], th: 39, taper: 0.68, peak: 0.18, hairs: [[0.22, 9, 35], [0.4, 12, 45]], tail: [[18, 28, 6], [-10, 18, 4]] },
    ],
    mouth: { pts: [[561.68, 702.36], [558.58, 703.35], [555.46, 704.29], [552.32, 705.16], [549.18, 705.98], [546.02, 706.73], [542.86, 707.42], [539.68, 708.04], [536.49, 708.6], [533.3, 709.09], [530.1, 709.51], [526.9, 709.85], [523.68, 710.11], [520.46, 710.29], [517.25, 710.38], [514.03, 710.37], [510.81, 710.26], [507.59, 710.03], [504.38, 709.68], [501.19, 709.21], [498.01, 708.58], [494.86, 707.8], [491.75, 706.86], [488.68, 705.72], [485.67, 704.39], [482.73, 702.83], [479.9, 701.04], [477.2, 699], [474.63, 696.71], [472.26, 694.16], [470.1, 691.37], [468.17, 688.35], [466.48, 685.14]], w: 21, oval: 0, ocx: 512, ocy: 712, orx: 18, ory: 23 },
    drop: { on: 0, x: 714, y: 560, r: 19, h: 50, tilt: -14 },
    tip: { dx: -4, dy: 0, sharp: 0.92 }, // curl
  },
  flustered: {
    eyes: [
      { cx: 413, cy: 590, rx: 53, ry: 41, lidL: 576, lidR: 594, sag: 4, pdx: -20, pdy: 10, pr: 20, closed: 0, bow: 5, tilt: 0 },
      { cx: 611, cy: 586, rx: 53, ry: 41, lidL: 590, lidR: 574, sag: 4, pdx: -20, pdy: 10, pr: 20, closed: 0, bow: 5, tilt: 0 },
    ],
    brows: [
      { c: [[484, 550], [452, 530], [402, 504], [352, 494]], th: 39, taper: 0.7, peak: 0.18, hairs: [[0.15, 9, 30], [0.42, 7, 50]], tail: [[10, 18, 4], [0, 0, 0]] },
      { c: [[540, 530], [574, 510], [624, 488], [674, 486]], th: 39, taper: 0.7, peak: 0.18, hairs: [[0.25, 8, 40], [0.55, 9, 55]], tail: [[-4, 16, 4], [0, 0, 0]] },
    ],
    mouth: mouthLine(478, 704, 548, 711, 5, 19),
    drop: { on: 0.55, x: 714, y: 560, r: 16, h: 42, tilt: -14 },
    tip: { dx: 2, dy: -2, sharp: 0.88 }, // hot, resisting reaction
  },
  shocked: {
    eyes: [
      { cx: 410, cy: 584, rx: 60, ry: 59, lidL: 526, lidR: 519, sag: 2, pdx: 12, pdy: -5, pr: 12, closed: 0, bow: 5, tilt: 0 },
      { cx: 616, cy: 576, rx: 57, ry: 55, lidL: 518, lidR: 528, sag: 2, pdx: -10, pdy: 5, pr: 12, closed: 0, bow: 5, tilt: 0 },
    ],
    brows: [
      { c: [[474, 480], [446, 438], [398, 420], [350, 442]], th: 37, taper: 0.68, peak: 0.18, hairs: [[0.2, 8, 35], [0.5, 10, 50]], tail: [[14, 20, 5], [0, 0, 0]] },
      { c: [[550, 466], [580, 424], [632, 412], [678, 444]], th: 37, taper: 0.68, peak: 0.18, hairs: [[0.3, 11, 40], [0.58, 8, 55]], tail: [[20, 24, 5], [-6, 14, 4]] },
    ],
    mouth: { pts: [[512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712], [512, 712]], w: 24, oval: 1, ocx: 516, ocy: 718, orx: 31, ory: 37 },
    drop: { on: 0, x: 714, y: 560, r: 19, h: 50, tilt: -14 },
    tip: { dx: -1, dy: -6, sharp: 0.76 }, // explosive spike
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
      { cx: 413, cy: 586, rx: 52, ry: 40, lidL: 588, lidR: 598, sag: 4, pdx: 19, pdy: 5, pr: 19, closed: 0, bow: 5, tilt: 0 },
      { cx: 611, cy: 578, rx: 54, ry: 44, lidL: 568, lidR: 576, sag: 4, pdx: 19, pdy: 5, pr: 19, closed: 0, bow: 5, tilt: 0 },
    ],
    brows: [
      { c: [[480, 548], [448, 542], [404, 540], [362, 544]], th: 36, taper: 0.68, peak: 0.18, hairs: [[0.25, 10, 35], [0.52, 8, 50]], tail: [[4, 18, 4], [0, 0, 0]] },
      { c: [[544, 522], [576, 496], [624, 486], [668, 500]], th: 36, taper: 0.68, peak: 0.18, hairs: [[0.2, 8, 40], [0.48, 10, 45]], tail: [[14, 20, 5], [0, 0, 0]] },
    ],
    mouth: mouthLine(490, 708, 542, 704, 0, 18),
    drop: { on: 0, x: 714, y: 560, r: 19, h: 50, tilt: -14 },
    tip: { dx: 0, dy: 0, sharp: 1 }, // neutral
  },
  calm: {
    eyes: [
      { cx: 413, cy: 590, rx: 52, ry: 39, lidL: 596, lidR: 600, sag: 5, pdx: -5, pdy: 12, pr: 18, closed: 0, bow: 8, tilt: 1 },
      { cx: 611, cy: 590, rx: 52, ry: 39, lidL: 600, lidR: 596, sag: 5, pdx: -5, pdy: 12, pr: 18, closed: 0, bow: 8, tilt: -1 },
    ],
    brows: [
      { c: [[478, 548], [448, 546], [404, 546], [362, 550]], th: 34, taper: 0.7, peak: 0.18, hairs: [[0.2, 9, 35], [0.5, 8, 50]], tail: [[12, 20, 5], [0, 0, 0]] },
      { c: [[546, 548], [576, 546], [620, 546], [662, 550]], th: 34, taper: 0.7, peak: 0.18, hairs: [[0.25, 10, 40], [0.55, 8, 55]], tail: [[16, 24, 5], [-8, 14, 4]] },
    ],
    mouth: mouthLine(480, 710, 544, 712, 0, 18),
    drop: { on: 0, x: 714, y: 560, r: 19, h: 50, tilt: -14 },
    tip: { dx: 0, dy: 0, sharp: 1 }, // neutral
  },
  // Yellow: alert, inviting confidence.
  warm: {
    eyes: [
      { cx: 413, cy: 580, rx: 53, ry: 45, lidL: 570, lidR: 576, sag: 5, pdx: 10, pdy: 8, pr: 21, closed: 0, bow: 5, tilt: 0 },
      { cx: 611, cy: 580, rx: 53, ry: 45, lidL: 576, lidR: 570, sag: 5, pdx: 10, pdy: 8, pr: 21, closed: 0, bow: 5, tilt: 0 },
    ],
    brows: [
      { c: [[480, 520], [446, 506], [400, 500], [358, 510]], th: 36, taper: 0.62, peak: 0.2, hairs: [], tail: [] },
      { c: [[544, 516], [578, 500], [624, 494], [666, 504]], th: 36, taper: 0.62, peak: 0.2, hairs: [], tail: [] },
    ],
    mouth: mouthLine(468, 704, 558, 697, 8, 21),
    drop: { on: 0, x: 714, y: 560, r: 19, h: 50, tilt: -14 },
    tip: { dx: -1.5, dy: -1, sharp: 0.96 },
  },
  // Orange: locked-in determination.
  hot: {
    eyes: [
      { cx: 413, cy: 586, rx: 52, ry: 40, lidL: 578, lidR: 594, sag: 4, pdx: 6, pdy: 10, pr: 20, closed: 0, bow: 5, tilt: 0 },
      { cx: 611, cy: 586, rx: 52, ry: 40, lidL: 594, lidR: 578, sag: 4, pdx: -6, pdy: 10, pr: 20, closed: 0, bow: 5, tilt: 0 },
    ],
    brows: [
      { c: [[484, 552], [450, 536], [402, 512], [354, 492]], th: 39, taper: 0.7, peak: 0.18, hairs: [], tail: [] },
      { c: [[540, 552], [574, 536], [622, 510], [670, 488]], th: 39, taper: 0.7, peak: 0.18, hairs: [], tail: [] },
    ],
    mouth: mouthLine(474, 708, 550, 704, -2, 20),
    drop: { on: 0, x: 714, y: 560, r: 19, h: 50, tilt: -14 },
    tip: { dx: 1.5, dy: -2, sharp: 0.88 },
  },
};

/** Art units to viewBox units. */
export const FACE_K = 120 / 718;
export const FACE_TX = 60 - 512 * FACE_K;
export const FACE_TY = 4 - 152 * FACE_K;
export const FACE_TRANSFORM = `translate(${FACE_TX.toFixed(3)} ${FACE_TY.toFixed(3)}) scale(${FACE_K.toFixed(5)})`;

export const EYE_WHITE: RGB = [245, 243, 254];
export const PUPIL: RGB = [31, 23, 59];
/** Hue-matched brows: dark blue on blue Wick, forest on green, burgundy on red. */
export function browFill(c: RGB): RGB {
  return [Math.round(c[0] * 0.63), Math.round(c[1] * 0.63), Math.round(c[2] * 0.63)];
}
export function browKey(c: RGB): RGB {
  const fill = browFill(c);
  return [Math.round(fill[0] * 0.52), Math.round(fill[1] * 0.52), Math.round(fill[2] * 0.52)];
}

/** The inner flame (lighter core) in art units, for clipping the face shading. */
export const PLATE_ART = "M511.5 448.0 C585.0 490.4 655.9 540.0 655.9 657.5 C655.9 776.5 598.8 841.0 511.5 841.0 C425.2 841.0 368.1 776.5 368.1 657.5 C368.1 540.0 439.0 490.4 511.5 448.0 Z";

/** The chunky flame outline in viewBox units, fitted to the icon art. `lean` is
 *  the tip's sideways lean (the flicker), `tip` the face's tip reaction. */
export function chunkyFlamePath(lean = 0, tip: TipP = { dx: 0, dy: 0, sharp: 1 }): string {
  const f = (v: number): string => (Math.round(v * 10) / 10).toString();
  const tx = 60 + lean + tip.dx, ty = 4 + tip.dy;
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
  if (o.mood === "freezing") return "serious";
  if (o.mood === "cold") return "focus";
  if (o.mood === "warm") return "warm";
  if (o.mood === "hot") return "hot";
  if (o.mood === "boiling") return "flustered";
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

/** The transition blink when the face or colour changes (3.8 motion pass):
 *  closing 0 to 70 ms, shut 70 to 240 ms while the face and colour change
 *  behind the lids, open by 360 ms. */
export function swapBlink(e: number): number {
  if (e < 0) return 0;
  if (e < 0.07) return e / 0.07;
  if (e < 0.24) return 1;
  if (e < 0.36) return 1 - (e - 0.24) / 0.12;
  return 0;
}
/** How far through the morph the brows, mouth and tip are `e` seconds in:
 *  entirely behind the closed lids, 70 to 240 ms. */
export function swapMorph(e: number): number {
  const x = Math.max(0, Math.min(1, (e - 0.07) / 0.17));
  return x * x * (3 - 2 * x);
}
/** During the solved sequence the face changes without a blink (the shock
 *  must read first): a plain 160 ms morph. */
export function solveMorph(e: number): number {
  const x = Math.max(0, Math.min(1, e / 0.16));
  return x * x * (3 - 2 * x);
}

/** Small live offsets on top of a face (wickmotion.ts): pupils (gx, gy), each
 *  brow (bl, br; negative is up), each lid (ll, lr; below 0 lifts the lid,
 *  above 0 is drawn as closure by the caller), and the tip (tu). */
export interface FaceAccent { gx: number; gy: number; bl: number; br: number; ll: number; lr: number; tu: number }

/** The face with accents applied. Returns `p` itself when there are none. */
export function accentFace(p: FaceP, a: FaceAccent): FaceP {
  if (!a.gx && !a.gy && !a.bl && !a.br && a.ll >= 0 && a.lr >= 0 && !a.tu) return p;
  const lid = [a.ll, a.lr];
  return {
    ...p,
    eyes: p.eyes.map((e, i) => {
      const lift = Math.min(0, lid[i] ?? 0) * 24;
      return { ...e, pdx: e.pdx + a.gx, pdy: e.pdy + a.gy, lidL: e.lidL + lift, lidR: e.lidR + lift };
    }),
    brows: p.brows.map((b, i) => {
      const dy = i === 0 ? a.bl : a.br;
      return dy ? { ...b, c: b.c.map((q) => [q[0]!, q[1]! + dy]) } : b;
    }),
    tip: { ...p.tip, dy: p.tip.dy + a.tu },
  };
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
/** A sleek brow built as one strong silhouette without loose hair texture. */
export function browPath(b: BrowP): string {
  const n = 64, th = b.th, C = b.c;
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
    const smoothRise = rise * rise * (3 - 2 * rise);
    // Heavy at the glabella, then commit to a sharp outside taper. The old
    // near-constant width made every expression look like two pasted bars.
    return th * (0.96 + 0.12 * smoothRise) * (1 - b.taper * 0.98 * fall ** 1.15);
  };
  const top: Pt[] = [], bot: Pt[] = [];
  for (let i = 0; i <= n; i++) {
    const [, , nx, ny] = fr(i); const t = i / n; const w = width(t) / 2;
    const [x, y] = cen[i]!;
    top.push([x + nx * w, y + ny * w]); bot.push([x - nx * w, y - ny * w]);
  }
  const [tx0, ty0, nx0, ny0] = fr(0); const [x0, y0] = cen[0]!; const w0 = width(0) / 2;
  const [txn, tyn] = fr(n); const [xn, yn] = cen[n]!; const wn = width(1) / 2;
  const outerTip: Pt = [xn + txn * wn * 0.9, yn + tyn * wn * 0.9];
  const cap: Pt[] = [];
  for (let k = 1; k < 20; k++) {
    const a = (Math.PI * k) / 20;
    cap.push([x0 + nx0 * w0 * Math.cos(a) - tx0 * w0 * Math.sin(a), y0 + ny0 * w0 * Math.cos(a) - ty0 * w0 * Math.sin(a)]);
  }
  return polyPath([...top, outerTip, ...bot.reverse(), ...cap.reverse()]);
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

/** Everything in the face, back to front, always the same 19 slots (some may be empty). */
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
  const brows = p.brows.map(browPath).join("");
  items.push({ d: brows, stroke: rgb(browKey(color)), width: 9, opacity: 0.72 });
  items.push({ d: brows, fill: rgb(browFill(color)), opacity: 1 });
  items.push({ d: mouthStrokePath(p.mouth), stroke: rgb(EYE_WHITE), width: p.mouth.w, opacity: 1 - p.mouth.oval });
  items.push({ d: p.mouth.oval > 0.01 ? mouthOvalPath(p.mouth) : "", fill: rgb(PUPIL), opacity: p.mouth.oval });
  items.push({ d: p.drop.on > 0.01 ? dropPath(p.drop) : "", fill: rgb(EYE_WHITE), opacity: p.drop.on });
  return items;
}


// ── 3.8: the solved sequence "You got me" ─────────────────────────────────────
// Five beats, 1.8 seconds, shared with KeeperFace.swift (same numbers).
//   hit        0.00 to 0.12  freeze, Shocked
//   disbelief  0.12 to 0.42  green, Shocked
//   release    0.42 to 0.82  compress then rebound to 1.08, one ring, sparks
//   recovery   0.82 to 1.28  Sly: the reluctant impressed look
//   button     1.28 to 1.80  hold green Sly, normal blinks
// A first-guess solve holds Shocked longer (SOLVE_FIRST_HOLD).

export const SOLVE_HIT = 0.12;
export const SOLVE_DISBELIEF = 0.42;
export const SOLVE_RELEASE = 0.82;
export const SOLVE_RECOVERY = 1.28;
export const SOLVE_DONE = 1.8;
export const SOLVE_FIRST_HOLD = 0.5;
/** Reduced Motion: a crossfade to green Shocked, one ring fades, then Sly. */
export const SOLVE_RM_SWAP = 0.4;
export const SOLVE_RM_DONE = 0.8;
export const SOLVE_REBOUND = 1.08;

/** The face Wick wears `e` seconds into the solved sequence. */
export function solveFace(e: number, reduceMotion: boolean, firstGuess = false): FaceName {
  if (reduceMotion) return e < SOLVE_RM_SWAP ? "shocked" : "sly";
  const swap = SOLVE_RELEASE + (firstGuess ? SOLVE_FIRST_HOLD : 0);
  return e < swap ? "shocked" : "sly";
}

/** Squash and rebound during the release beat: x and y scale factors. */
export function solveScale(e: number): { sx: number; sy: number } {
  if (e < SOLVE_DISBELIEF || e >= SOLVE_RELEASE) return { sx: 1, sy: 1 };
  const u = (e - SOLVE_DISBELIEF) / (SOLVE_RELEASE - SOLVE_DISBELIEF);   // 0..1
  if (u < 0.3) {
    const k = u / 0.3;                                       // compress
    return { sx: 1 + 0.06 * k, sy: 1 - 0.10 * k };
  }
  if (u < 0.65) {
    const k = (u - 0.3) / 0.35;                              // rebound past 1
    return { sx: 1.06 - 0.10 * k, sy: 0.90 + (SOLVE_REBOUND - 0.90) * k };
  }
  const k = (u - 0.65) / 0.35;                               // settle
  return { sx: 0.96 + 0.04 * k, sy: SOLVE_REBOUND - (SOLVE_REBOUND - 1) * k };
}

/** The one ring: radius as a factor of Wick's size, opacity, and the mix from
 *  violet (0) to solved green (1). Null outside the release beat. */
export function solveRing(e: number, reduceMotion: boolean): { r: number; opacity: number; mix: number } | null {
  if (reduceMotion) {
    if (e < SOLVE_RM_SWAP * 0.5 || e >= SOLVE_RM_DONE) return null;
    const u = (e - SOLVE_RM_SWAP * 0.5) / (SOLVE_RM_DONE - SOLVE_RM_SWAP * 0.5);
    return { r: 0.75, opacity: 0.5 * Math.sin(u * Math.PI), mix: u };
  }
  if (e < SOLVE_DISBELIEF || e >= SOLVE_RELEASE) return null;
  const u = (e - SOLVE_DISBELIEF) / (SOLVE_RELEASE - SOLVE_DISBELIEF);
  return { r: 0.55 + 0.6 * u, opacity: 0.7 * (1 - u), mix: u };
}

/** The gold sparks show from the release beat on. */
export function solveSparks(e: number, reduceMotion: boolean): boolean {
  return reduceMotion ? e >= SOLVE_RM_SWAP : e >= SOLVE_DISBELIEF;
}


// ── 3.8: a still Wick as SVG markup (the share card) ─────────────────────────

function escAttr(v: string): string { return v.replace(/"/g, "&quot;"); }

/**
 * Wick drawn once, no animation, as inner SVG markup in his own 120 by 128
 * box. `id` keeps gradient and clip ids unique on a page. The card and any
 * other static picture of him come from here so he always matches the game.
 */
export function wickStillMarkup(face: FaceName, color: RGB, id: string, opts: { sparks?: boolean } = {}): string {
  const f = FACES[face];
  const d = chunkyFlamePath(0, f.tip);
  const top = lighten(color, 0.12), bot = rgb(color);
  const items = faceDrawList(f, f.eyes.map((e) => e.closed), color);
  const paths = items.map((it) => {
    if (!it.d) return "";
    const a: string[] = [`d="${escAttr(it.d)}"`];
    if (it.stroke) a.push(`fill="none" stroke="${it.stroke}" stroke-width="${it.width ?? 24}" stroke-linecap="round" stroke-linejoin="round"`);
    else if (it.fill) a.push(`fill="${it.fill}"`);
    if (it.opacity < 0.999) a.push(`opacity="${it.opacity.toFixed(3)}"`);
    if (it.plate) a.push(`clip-path="url(#plate-${id})"`);
    return `<path ${a.join(" ")}/>`;
  }).join("");
  const sparks = opts.sparks
    ? `<g fill="${rgb(PALETTE.warm)}">` + [{ x: 22, y: 40, r: 4 }, { x: 100, y: 34, r: 3.4 }, { x: 104, y: 88, r: 3 }]
        .map((sp) => `<path d="${starPath(sp.x, sp.y, sp.r)}"/>`).join("") + `</g>`
    : "";
  return `<defs>` +
    `<linearGradient id="body-${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="${top}"/><stop offset="55%" stop-color="${bot}"/><stop offset="100%" stop-color="${bot}"/></linearGradient>` +
    `<filter id="soft-${id}" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="6"/></filter>` +
    `<clipPath id="plate-${id}"><path d="${PLATE_ART}"/></clipPath>` +
    `</defs>` +
    `<path d="${d}" fill="${bot}" opacity="0.30" filter="url(#soft-${id})" transform="translate(60 124) scale(1.12) translate(-60 -124)"/>` +
    `<path d="${d}" fill="url(#body-${id})"/>` +
    `<path d="${PLATE_PATH}" fill="#ffffff" opacity="0.22"/>` +
    sparks +
    `<g transform="${FACE_TRANSFORM}">${paths}</g>`;
}
