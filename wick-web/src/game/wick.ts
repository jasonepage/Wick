// SPDX-License-Identifier: MPL-2.0
//
//  wick.ts: Wick, the mascot, as a living thing on the web.
//
//  Wick is a purple flame with a face. On iOS (Hunch/Theme/KeeperView.swift) he
//  is drawn fresh every frame from the clock: he bobs, his tip leans, he
//  breathes, he shivers when freezing and shakes when boiling, he blinks at
//  random, and a poke squashes and stretches him. This file brings the same
//  life to the web with the same formulas and the same numbers.
//
//  How it is put together:
//
//  1. Pure math (no browser needed, so it is unit tested in tests/wick.test.ts):
//     `flamePath`, `faceSpec`, `boilingShake`, `danceAt` and `poseAt`. Given a
//     time and a mood they say where Wick is and what shape he is.
//  2. The DOM component: `mountWick` builds the SVG once and then only moves
//     it. One requestAnimationFrame loop drives every mounted Wick, and it
//     pauses when the tab is hidden or no Wick is on screen. Screens must not
//     rebuild Wick when they re-render: find the mounted one and call
//     `setScore` or `setMood` instead (see `ensureWick`).
//  3. The dance. When a Wick is mounted with `dance: true` it reads the race
//     music's pulse every frame and layers beat-locked moves on top of the mood
//     motion. The same moves live in Hunch/Theme/WickDance.swift for iOS.
//
//  Units: everything is in viewBox units. The viewBox is 120 wide and 128 tall
//  and the flame's base sits at (60, 124), so a 120 px Wick is one unit per
//  pixel. `SIZE` (120) plays the part of `size` in KeeperView's formulas.
//
//  KEEP IN LOCKSTEP with KeeperView.swift and WickDance.swift: when a number
//  changes on one platform, change it on the other.
//

import { type Mood, type RGB, moodFor, moodRGB, lighten, rgb, starPath, PALETTE } from "./wickface.ts";
import { musicPulse } from "./music.ts";

export type WickMood = Mood;

/** One reading of the race music's clock. `time` is seconds into the music;
 *  the rest is what `musicPulse()` in music.ts returns. */
export interface WickPulse {
  beat: number;
  down: number;
  energy: number;
  flash: number;
  time: number;
}

/** Wick's width in viewBox units. Stands in for `size` in the iOS formulas. */
export const SIZE = 120;
/** Where the flame's feet are. Every transform pivots here. */
export const BASE_X = 60;
export const BASE_Y = 124;
/** The flame's box inside the viewBox: 102 wide and 120 tall, like the iOS
 *  frame of size x 1.18 size. */
const FLAME_RECT = { x: 9, y: 4, w: 102, h: 120 };

const EYE_Y = 72;
const EYE_LX = 43.6;
const EYE_RX = 76.4;
const MOUTH_Y = 92;
const EYE_R = 6.9;
const STROKE = 3.4;
const WHITE = "#ffffff";

// ── pure math ───────────────────────────────────────────────────────────────

/** Seconds per bob, by mood. Mirrors KeeperMood.bobPeriod. */
export function bobPeriod(mood: WickMood): number {
  switch (mood) {
    case "boiling": return 0.55;
    case "hot": case "celebrating": return 0.8;
    case "warm": return 1.2;
    case "cold": return 2.4;
    case "freezing": return 2.8;
    case "unamused": return 2.2;
    default: return 1.8;
  }
}

/** How far the bob goes, as a fraction of size. Mirrors KeeperView.bobAmplitude. */
export function bobAmplitude(mood: WickMood, size = SIZE): number {
  return mood === "celebrating" ? size * 0.07 : size * 0.035;
}

/**
 * The flame outline, point for point the same as KeeperFlameShape.path(in:).
 * `flicker` is 0..1; the tip leans by (flicker - 0.5) * 0.22 * width.
 */
export function flamePath(flicker: number, r = FLAME_RECT): string {
  const { x, y, w, h } = r;
  const lean = (flicker - 0.5) * 0.22 * w;
  const f = (v: number): string => (Math.round(v * 10) / 10).toString();
  const pt = (px: number, py: number): string => `${f(x + px)} ${f(y + py)}`;
  return `M${pt(w * 0.5, h)} ` +
    `C${pt(w * 0.16, h * 0.98)} ${pt(w * 0.07, h * 0.78)} ${pt(w * 0.07, h * 0.52)} ` +
    `C${pt(w * 0.07, h * 0.22)} ${pt(w * 0.32 + lean * 0.6, h * 0.10)} ${pt(w * 0.5 + lean, 0)} ` +
    `C${pt(w * 0.68 + lean * 0.6, h * 0.10)} ${pt(w * 0.93, h * 0.22)} ${pt(w * 0.93, h * 0.52)} ` +
    `C${pt(w * 0.93, h * 0.78)} ${pt(w * 0.84, h * 0.98)} ${pt(w * 0.5, h)} Z`;
}

/** A shape in Wick's face. `eye` marks the parts that blink. */
export type Shape =
  | { kind: "circle"; cx: number; cy: number; r: number; fill: string; opacity: number; eye?: boolean }
  | { kind: "rect"; x: number; y: number; w: number; h: number; rx: number; fill: string; opacity: number; eye?: boolean }
  | { kind: "path"; d: string; fill?: string; stroke?: string; width?: number; opacity: number; eye?: boolean };

/** Eyes and mouth for a mood. Mirrors KeeperView.moodEye and KeeperView.mouth. */
export function faceSpec(mood: WickMood): Shape[] {
  const out: Shape[] = [];
  const W = WHITE;
  // Eyes.
  if (mood === "celebrating") {
    out.push({ kind: "path", d: starPath(EYE_LX, EYE_Y, 10), fill: W, opacity: 1, eye: true });
    out.push({ kind: "path", d: starPath(EYE_RX, EYE_Y, 10), fill: W, opacity: 1, eye: true });
  } else if (mood === "unamused") {
    for (const cx of [EYE_LX, EYE_RX]) out.push({ kind: "rect", x: cx - 7, y: EYE_Y - 1.5, w: 14, h: 3, rx: 1.5, fill: W, opacity: 0.85, eye: true });
  } else if (mood === "freezing") {
    for (const cx of [EYE_LX, EYE_RX]) out.push({ kind: "rect", x: cx - 6.9, y: EYE_Y - 3.1, w: 13.8, h: 6.2, rx: 3.1, fill: W, opacity: 0.9, eye: true });
  } else {
    const r = mood === "boiling" || mood === "hot" ? EYE_R * 1.18 : EYE_R;
    for (const cx of [EYE_LX, EYE_RX]) out.push({ kind: "circle", cx, cy: EYE_Y, r, fill: W, opacity: 0.9, eye: true });
  }
  // Mouth.
  const my = MOUTH_Y;
  if (mood === "celebrating" || mood === "boiling") {
    out.push({ kind: "path", d: `M51 ${my} A9 9 0 0 0 69 ${my} Z`, fill: W, opacity: 0.9 });
  } else if (mood === "hot" || mood === "warm" || mood === "idle") {
    out.push({ kind: "path", d: `M51 ${my} Q60 ${my + 7} 69 ${my}`, stroke: W, width: STROKE, opacity: 0.9 });
  } else if (mood === "unamused") {
    out.push({ kind: "path", d: `M53 ${my + 1} L67 ${my + 1}`, stroke: W, width: STROKE, opacity: 0.8 });
  } else {
    out.push({ kind: "path", d: `M51 ${my + 4} Q60 ${my - 3} 69 ${my + 4}`, stroke: W, width: STROKE, opacity: 0.9 });
  }
  return out;
}

/** The four sparkles around a celebrating Wick: where they sit and how big. */
export const SPARKLES: { x: number; y: number; r: number }[] = [
  { x: 22, y: 40, r: 4 }, { x: 100, y: 34, r: 3.4 }, { x: 104, y: 88, r: 3 }, { x: 16, y: 84, r: 3 },
];
export const SPARKLE_COLOR = rgb(PALETTE.warm);

/** How bright sparkle `i` is at time `t` (0..1). Mirrors KeeperView.sparkles. */
export function sparklePhase(t: number, i: number): number {
  return (Math.sin((t * 2 * Math.PI) / 0.6 - i * 0.75) + 1) / 2;
}

/**
 * Boiling is a hard shake: a fast jitter in two directions plus a little
 * rotation. Two sine waves at unrelated speeds, so it never looks like a loop.
 * Clearly stronger than hot (which only bobs fast), still readable.
 */
export function boilingShake(t: number, size = SIZE): { x: number; y: number; rot: number } {
  return {
    x: (Math.sin(t * 71) * 0.6 + Math.sin(t * 113) * 0.4) * size * 0.045,
    y: (Math.sin(t * 89 + 1.3) * 0.6 + Math.sin(t * 131) * 0.4) * size * 0.02,
    rot: Math.sin(t * 97) * 2.5,
  };
}

/** The 0..1 envelope of a poke `e` seconds after the tap. Mirrors KeeperView.pokeProgress. */
export function pokeEnvelope(e: number): number {
  if (e < 0 || e >= 0.45) return 0;
  return Math.cos((e / 0.45) * Math.PI / 2) * Math.exp(-e * 5);
}

export interface Move { x: number; y: number; rot: number; sx: number; sy: number }
export const STILL: Move = { x: 0, y: 0, rot: 0, sx: 1, sy: 1 };

/**
 * Wick's dance for one reading of the race music. Locked to the beat:
 *   a hop on each beat (squash on landing, stretch on the way up),
 *   a step and lean to alternating sides each beat,
 *   a bigger hop and lean on beat 1 of each bar,
 *   and when kiai drops (flash), a big jump with a full spin.
 * `energy` sets how hard he goes: a groove on chill, building through the
 * riser, full out on kiai.
 */
export function danceAt(p: WickPulse, size = SIZE): Move {
  const BEAT = 0.5;
  const idx = Math.floor(p.time / BEAT);
  const ph = (p.time - idx * BEAT) / BEAT;            // 0..1 through the beat
  const side = idx % 2 === 0 ? -1 : 1;                // step side alternates
  const downbeat = idx % 4 === 0;
  const amp = 0.55 + 0.75 * p.energy;                 // chill 0.55, kiai 1.3

  // The hop: in the air between beats, feet down on the beat.
  const arc = Math.sin(Math.PI * ph);
  let y = -arc * size * (downbeat ? 0.10 : 0.06) * amp;
  // Squash on landing (the beat pulse is 1 on the beat and decays), stretch in the air.
  const squash = 0.14 * p.beat * amp;
  const stretch = 0.07 * arc * amp;
  let sx = 1 + squash - stretch;
  let sy = 1 - squash + stretch;

  // The step: slide from one side to the other over the beat, leaning that way.
  const ease = (1 - Math.cos(Math.PI * Math.min(1, ph * 1.4))) / 2;
  const travel = side * (2 * ease - 1);
  const x = travel * size * 0.06 * amp;
  let rot = travel * 7 * amp * (downbeat ? 1.5 : 1);

  // The drop: one big jump with a full spin in the first second of kiai.
  if (p.flash > 0) {
    const u = Math.min(1, -Math.log(Math.max(p.flash, 1e-9)) / 3);   // seconds since the drop
    if (u < 1) {
      const jump = Math.sin(Math.PI * u);
      y -= jump * size * 0.35;
      rot += 360 * (u * u * (3 - 2 * u));
      sx *= 1 - 0.1 * jump;
      sy *= 1 + 0.1 * jump;
    }
  }
  return { x, y, rot, sx, sy };
}

/** Everything about where Wick is on one frame. */
export interface Pose {
  x: number;
  y: number;
  /** Degrees, around the base. */
  rot: number;
  sx: number;
  sy: number;
  /** 0..1, the tip lean. 0.5 is centered. */
  flicker: number;
  /** Whole-body opacity. Only moves under Reduce Motion. */
  opacity: number;
}

export interface PoseInput {
  /** Seconds, any continuous clock. */
  t: number;
  mood: WickMood;
  /** When the last poke happened on the same clock, or null. */
  pokeAt: number | null;
  reduceMotion: boolean;
  /** The music pulse, or null for no dance. */
  pulse: WickPulse | null;
  size?: number;
}

/** Wick's pose at time `t`. Same formulas and numbers as KeeperView's TimelineView body. */
export function poseAt(a: PoseInput): Pose {
  const size = a.size ?? SIZE;
  const { t, mood } = a;
  if (a.reduceMotion) {
    // No positional or scaling motion: only a soft opacity breath.
    const glow = 0.86 + 0.14 * (Math.sin((t * 2 * Math.PI) / 2.4) + 1) / 2;
    return { x: 0, y: 0, rot: 0, sx: 1, sy: 1, flicker: 0.5, opacity: glow };
  }
  const period = bobPeriod(mood);
  const bob = Math.sin((t * 2 * Math.PI) / period) * bobAmplitude(mood, size);
  const shiver = mood === "freezing" ? Math.sin(t * 30) * 1.2 : 0;
  const shake = mood === "boiling" ? boilingShake(t, size) : { x: 0, y: 0, rot: 0 };
  const flicker = 0.5 + Math.sin((t * 2 * Math.PI) / (period * 0.8)) / 2;
  const breathe = 1 + Math.sin((t * 2 * Math.PI) / (period * 1.7)) * 0.03;

  let pokeScale = 1;
  let pokeWiggle = 0;
  if (a.pokeAt !== null) {
    const e = t - a.pokeAt;
    const env = pokeEnvelope(e);
    pokeScale = 1 + env * 0.20;
    pokeWiggle = env * 6 * Math.sin(e * 34);
  }

  const dance = a.pulse ? danceAt(a.pulse, size) : STILL;
  return {
    x: shiver + shake.x + dance.x,
    y: bob + shake.y + dance.y,
    rot: pokeWiggle + shake.rot + dance.rot,
    sx: breathe * pokeScale * dance.sx,
    sy: breathe * pokeScale * dance.sy,
    flicker,
    opacity: 1,
  };
}

/** The SVG transform for a pose, pivoting on the base. */
export function poseTransform(p: Pose): string {
  const f = (v: number): string => v.toFixed(2);
  return `translate(${f(BASE_X + p.x)} ${f(BASE_Y + p.y)}) rotate(${f(p.rot)}) scale(${f(p.sx)} ${f(p.sy)}) translate(${-BASE_X} ${-BASE_Y})`;
}

/** The scaleY of the eyes for a blink amount (0 open, 1 shut). iOS squeezes to 0.18. */
export function blinkScale(blink: number): number {
  return 1 - blink * (1 - 0.18);
}

/** How shut the eyes are `e` seconds into a blink: 70 ms shut, hold 110 ms, 90 ms open. */
export function blinkAmount(e: number): number {
  if (e < 0) return 0;
  if (e < 0.07) return e / 0.07;
  if (e < 0.18) return 1;
  if (e < 0.27) return 1 - (e - 0.18) / 0.09;
  return 0;
}
export const BLINK_LENGTH = 0.27;

/** Mix two colours. `f` 0 gives `a`, 1 gives `b`. */
export function mixRGB(a: RGB, b: RGB, f: number): RGB {
  const m = (x: number, y: number): number => Math.round(x + (y - x) * f);
  return [m(a[0], b[0]), m(a[1], b[1]), m(a[2], b[2])];
}

// ── the DOM component ───────────────────────────────────────────────────────

export interface WickOptions {
  /** Closeness 0..100, or null for the resting purple Wick. */
  score: number | null;
  /** The deadpan grey Wick (unknown word, gave up, lost). */
  neutral?: boolean;
  /** Pixels. */
  size?: number;
  /** Unique id for the gradient and filter, when several Wicks share a page. */
  id?: string;
  /** Dance to the race music when it plays. Only the live race screen sets this. */
  dance?: boolean;
  /** Where to read the music from; defaults to music.ts. The clip exporter passes its own. */
  pulse?: () => WickPulse | null;
  /** Called when the player pokes him. */
  onPoke?: () => void;
}

export interface Wick {
  readonly el: SVGSVGElement;
  readonly mood: WickMood;
  /** Change the look from a score (and the grey flag), easing over half a second. */
  setScore(score: number | null, neutral?: boolean): void;
  setMood(mood: WickMood): void;
  /** Squash, stretch and wiggle, like a tap on iOS Wick. */
  poke(): void;
  setDance(on: boolean): void;
  /** Stop animating and remove the SVG. */
  destroy(): void;
}

const MOOD_EASE = 0.5;       // seconds, like iOS .easeInOut(duration: 0.5)
const SVG_NS = "http://www.w3.org/2000/svg";

function svgEl<K extends keyof SVGElementTagNameMap>(tag: K, attrs: Record<string, string | number> = {}): SVGElementTagNameMap[K] {
  const e = document.createElementNS(SVG_NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, String(v));
  return e;
}

/** Build one face shape as an SVG element. */
function shapeEl(s: Shape): SVGElement {
  switch (s.kind) {
    case "circle":
      return svgEl("circle", { cx: s.cx, cy: s.cy, r: s.r, fill: s.fill, opacity: s.opacity });
    case "rect":
      return svgEl("rect", { x: s.x, y: s.y, width: s.w, height: s.h, rx: s.rx, fill: s.fill, opacity: s.opacity });
    case "path": {
      const attrs: Record<string, string | number> = { d: s.d, opacity: s.opacity };
      if (s.fill) attrs.fill = s.fill;
      if (s.stroke) {
        attrs.stroke = s.stroke;
        attrs["stroke-width"] = s.width ?? STROKE;
        attrs.fill = "none";
        attrs["stroke-linecap"] = "round";
      }
      return svgEl("path", attrs);
    }
  }
}

/** A face group: eyes (which blink) and the mouth. */
function buildFace(mood: WickMood): { g: SVGGElement; eyes: SVGGElement; blinks: boolean } {
  const g = svgEl("g", { class: "face" });
  const eyes = svgEl("g", { class: "eyes" });
  g.append(eyes);
  for (const s of faceSpec(mood)) (s.eye ? eyes : g).append(shapeEl(s));
  // Star eyes twinkle instead of blinking; dashes have nothing to shut.
  const blinks = mood !== "celebrating" && mood !== "unamused";
  return { g, eyes, blinks };
}

interface Inst {
  el: SVGSVGElement;
  host: HTMLElement;
  mood: WickMood;
  rgbFrom: RGB;
  rgbTo: RGB;
  colorAt: number;            // when the colour ease began (seconds)
  colorDone: boolean;         // true once the ease has landed and been painted
  stops: SVGStopElement[];
  glow: SVGPathElement;
  body: SVGPathElement;
  sheen: SVGPathElement;
  rig: SVGGElement;
  faceIn: ReturnType<typeof buildFace>;
  faceOut: ReturnType<typeof buildFace> | null;
  faceAt: number;             // when the face crossfade began
  sparkles: SVGPathElement[];
  pokeAt: number | null;
  nextBlinkAt: number;
  blinkAt: number | null;
  visible: boolean;
  dance: boolean;
  pulse: () => WickPulse | null;
  io: IntersectionObserver | null;
  lastFlicker: number;
  lastPath: string;
}

const instances = new Set<Inst>();
let rafId: number | null = null;
let reduceMotionQuery: MediaQueryList | null = null;
let hooked = false;

function reduceMotion(): boolean {
  if (typeof window === "undefined" || !window.matchMedia) return false;
  if (!reduceMotionQuery) reduceMotionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  return reduceMotionQuery.matches;
}

function now(): number {
  return performance.now() / 1000;
}

function nextBlinkDelay(): number {
  return 2.2 + Math.random() * 2.3;   // iOS blinkLoop: 2.2...4.5 s
}

/** Start the shared frame loop if anything is visible and it isn't running. */
function wake(): void {
  if (rafId !== null) return;
  if (typeof document !== "undefined" && document.hidden) return;
  for (const i of instances) {
    if (i.visible) { rafId = requestAnimationFrame(tick); return; }
  }
}

function hookDocument(): void {
  if (hooked || typeof document === "undefined") return;
  hooked = true;
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      if (rafId !== null) { cancelAnimationFrame(rafId); rafId = null; }
    } else {
      wake();
    }
  });
}

function tick(): void {
  rafId = null;
  const t = now();
  const rm = reduceMotion();
  let anyVisible = false;
  for (const i of instances) {
    if (!i.el.isConnected) { teardown(i); continue; }
    if (!i.visible) continue;
    anyVisible = true;
    frame(i, t, rm);
  }
  if (anyVisible) rafId = requestAnimationFrame(tick);
}

function frame(i: Inst, t: number, rm: boolean): void {
  // Blink timing: a random wait, then a quick shut and open.
  let blink = 0;
  if (i.faceIn.blinks && !rm) {
    if (i.blinkAt === null && t >= i.nextBlinkAt) i.blinkAt = t;
    if (i.blinkAt !== null) {
      const e = t - i.blinkAt;
      blink = blinkAmount(e);
      if (e >= BLINK_LENGTH) { i.blinkAt = null; i.nextBlinkAt = t + nextBlinkDelay(); }
    }
  }
  const pulse = i.dance ? i.pulse() : null;
  const pose = poseAt({ t, mood: i.mood, pokeAt: i.pokeAt, reduceMotion: rm, pulse });
  i.rig.setAttribute("transform", poseTransform(pose));
  i.el.style.opacity = pose.opacity < 1 ? pose.opacity.toFixed(3) : "";

  // The silhouette: only rewrite the path when the lean actually changed.
  if (Math.abs(pose.flicker - i.lastFlicker) > 0.002) {
    i.lastFlicker = pose.flicker;
    i.lastPath = flamePath(pose.flicker);
    i.body.setAttribute("d", i.lastPath);
    i.glow.setAttribute("d", i.lastPath);
    i.sheen.setAttribute("d", i.lastPath);
  }

  // Colour ease.
  const cf = Math.min(1, (t - i.colorAt) / MOOD_EASE);
  if (!i.colorDone) {
    const c = mixRGB(i.rgbFrom, i.rgbTo, cf);
    const top = lighten(c, 0.12);
    const bot = rgb(c);
    i.stops[0]?.setAttribute("stop-color", top);
    i.stops[1]?.setAttribute("stop-color", bot);
    i.stops[2]?.setAttribute("stop-color", bot);
    i.glow.setAttribute("fill", bot);
    i.colorDone = cf >= 1;
  }

  // Face crossfade.
  if (i.faceOut) {
    const ff = Math.min(1, (t - i.faceAt) / MOOD_EASE);
    i.faceIn.g.setAttribute("opacity", ff.toFixed(3));
    i.faceOut.g.setAttribute("opacity", (1 - ff).toFixed(3));
    if (ff >= 1) { i.faceOut.g.remove(); i.faceOut = null; i.faceIn.g.removeAttribute("opacity"); }
  }
  const bs = blinkScale(blink);
  i.faceIn.eyes.setAttribute("transform", bs < 1 ? `translate(0 ${EYE_Y}) scale(1 ${bs.toFixed(3)}) translate(0 ${-EYE_Y})` : "");

  // Sparkles twinkle (celebrating only; the group is empty otherwise).
  for (let k = 0; k < i.sparkles.length; k++) {
    const ph = rm ? 0.4 * sparklePhase(t, k) : sparklePhase(t, k);
    const sp = i.sparkles[k]!;
    const { x, y } = SPARKLES[k]!;
    sp.setAttribute("opacity", (0.25 + 0.75 * ph).toFixed(3));
    const sc = rm ? 1 : 0.7 + 0.45 * ph;
    sp.setAttribute("transform", `translate(${x} ${y}) scale(${sc.toFixed(3)}) rotate(${(ph * 36).toFixed(1)}) translate(${-x} ${-y})`);
  }
}

function teardown(i: Inst): void {
  instances.delete(i);
  i.io?.disconnect();
  if (instances.size === 0 && rafId !== null) { cancelAnimationFrame(rafId); rafId = null; }
}

/**
 * Build Wick inside `host` and start animating him. Returns a handle for
 * changing his mood, poking him and taking him down.
 */
export function mountWick(host: HTMLElement, opts: WickOptions): Wick {
  const size = opts.size ?? 132;
  const id = opts.id ?? "wick";
  const mood = moodFor({ score: opts.score, neutral: opts.neutral });
  const color = moodRGB(mood);

  const el = svgEl("svg", {
    class: `wick-mascot mood-${mood}`, width: size, height: size, viewBox: "0 0 120 128",
    role: "img", "aria-label": "Wick", overflow: "visible",
  });
  const defs = svgEl("defs");
  const grad = svgEl("linearGradient", { id: `body-${id}`, x1: 0, y1: 0, x2: 0, y2: 1 });
  const stops = [
    svgEl("stop", { offset: "0%", "stop-color": lighten(color, 0.12) }),
    svgEl("stop", { offset: "55%", "stop-color": rgb(color) }),
    svgEl("stop", { offset: "100%", "stop-color": rgb(color) }),
  ];
  grad.append(...stops);
  const filter = svgEl("filter", { id: `soft-${id}`, x: "-40%", y: "-40%", width: "180%", height: "180%" });
  filter.append(svgEl("feGaussianBlur", { stdDeviation: 6 }));
  defs.append(grad, filter);

  const rig = svgEl("g", { class: "wick-rig" });
  const d0 = flamePath(0.5);
  const glow = svgEl("path", {
    class: "flame-glow", d: d0, fill: rgb(color), opacity: 0.30, filter: `url(#soft-${id})`,
    transform: `translate(${BASE_X} ${BASE_Y}) scale(1.12) translate(${-BASE_X} ${-BASE_Y})`,
  });
  const body = svgEl("path", { class: "flame-body", d: d0, fill: `url(#body-${id})` });
  const sheenG = svgEl("g", { class: "flame-sheen", opacity: 0.22 });
  const sheen = svgEl("path", { d: d0, fill: WHITE, transform: `translate(60 119) scale(0.55) translate(-60 -124)` });
  sheenG.append(sheen);
  const sparkG = svgEl("g", { class: "sparkles", fill: SPARKLE_COLOR });
  const face = buildFace(mood);
  rig.append(glow, body, sheenG, sparkG, face.g);
  el.append(defs, rig);
  host.append(el);

  const t0 = now();
  const inst: Inst = {
    el, host, mood, rgbFrom: color, rgbTo: color, colorAt: t0 - MOOD_EASE, colorDone: false, stops, glow, body, sheen, rig,
    faceIn: face, faceOut: null, faceAt: t0, sparkles: [], pokeAt: null,
    nextBlinkAt: t0 + nextBlinkDelay(), blinkAt: null, visible: true, dance: !!opts.dance,
    pulse: opts.pulse ?? musicPulse, io: null, lastFlicker: 0.5, lastPath: d0,
  };
  const setSparkles = (m: WickMood): void => {
    sparkG.replaceChildren();
    inst.sparkles = [];
    if (m !== "celebrating") return;
    for (const s of SPARKLES) {
      const p = svgEl("path", { class: "spark", d: starPath(s.x, s.y, s.r) });
      sparkG.append(p);
      inst.sparkles.push(p);
    }
  };
  setSparkles(mood);

  if (typeof IntersectionObserver !== "undefined") {
    inst.io = new IntersectionObserver((entries) => {
      for (const e of entries) inst.visible = e.isIntersecting;
      if (inst.visible) wake();
    });
    inst.io.observe(el);
  }
  el.style.cursor = "pointer";
  el.addEventListener("pointerdown", () => { handle.poke(); opts.onPoke?.(); });

  instances.add(inst);
  hookDocument();
  wake();

  const handle: Wick = {
    el,
    get mood() { return inst.mood; },
    setMood(m: WickMood) {
      if (m === inst.mood) return;
      const t = now();
      // Start the colour ease from wherever the colour is right now.
      inst.rgbFrom = mixRGB(inst.rgbFrom, inst.rgbTo, Math.min(1, (t - inst.colorAt) / MOOD_EASE));
      inst.rgbTo = moodRGB(m);
      inst.colorAt = t;
      inst.colorDone = false;
      // Crossfade the face. If one is still fading out, drop it and fade from the current one.
      inst.faceOut?.g.remove();
      inst.faceOut = inst.faceIn;
      inst.faceIn = buildFace(m);
      inst.faceIn.g.setAttribute("opacity", "0");
      inst.faceOut.eyes.removeAttribute("transform");
      rig.append(inst.faceIn.g);
      inst.faceAt = t;
      inst.blinkAt = null;
      inst.nextBlinkAt = t + nextBlinkDelay();
      el.classList.remove(`mood-${inst.mood}`);
      el.classList.add(`mood-${m}`);
      inst.mood = m;
      setSparkles(m);
      wake();
    },
    setScore(score, neutral) { handle.setMood(moodFor({ score, neutral })); },
    poke() { inst.pokeAt = now(); wake(); },
    setDance(on) { inst.dance = on; },
    destroy() { teardown(inst); el.remove(); },
  };
  return handle;
}

const mounted = new WeakMap<Element, Wick>();

/**
 * The Wick already living in `host`, or a new one. Screens that re-render
 * call this instead of rebuilding him, so his motion never snaps back to the
 * start. When a Wick is found, his look is updated to `opts` in place.
 */
export function ensureWick(host: HTMLElement, opts: WickOptions): Wick {
  const have = mounted.get(host);
  if (have && have.el.isConnected && have.el.parentElement === host) {
    have.setScore(opts.score, opts.neutral);
    if (opts.dance !== undefined) have.setDance(opts.dance);
    return have;
  }
  host.replaceChildren();
  const w = mountWick(host, opts);
  mounted.set(host, w);
  return w;
}
