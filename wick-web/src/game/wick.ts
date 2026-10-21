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
//     `flamePath`, `boilingShake`, `danceAt` and `poseAt` (the faces live in
//     wickface.ts). Given a
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
//  4. The face. Wick wears one of the Keeper's six faces from wickface.ts
//     (Sly, Flustered, Shocked, Calm, Serious, Focus), picked from the game's
//     state. He changes faces with a blink: the eyes shut, the brows, mouth and
//     flame tip morph while they are shut, and he opens on the new face with a
//     small squash and stretch.
//
//  KEEP IN LOCKSTEP with KeeperView.swift and WickDance.swift: when a number
//  changes on one platform, change it on the other.
//

import {
  type Mood, type RGB, type FaceName, type FaceP, type TipP, moodFor, moodRGB, lighten, rgb, starPath, PALETTE,
  FACES, FACE_TRANSFORM, PLATE_ART, PLATE_PATH, chunkyFlamePath, faceDrawList, faceFor, lerpFace, swapBlink, swapMorph,
} from "./wickface.ts";
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
/** How far the tip leans across the full flicker, in viewBox units. Gentler than
 *  the old thin flame (0.22 x 102) so the chunky silhouette stays true to the art. */
const LEAN = 0.09 * 102;
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
 * The flame outline: the chunky flame from the approved icon art (see
 * chunkyFlamePath in wickface.ts). `flicker` is 0..1; the tip leans by
 * (flicker - 0.5) * LEAN. `tip` is the face's tip reaction.
 */
export function flamePath(flicker: number, tip?: TipP): string {
  return chunkyFlamePath((flicker - 0.5) * LEAN, tip);
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
  /** Race mode: the Serious face (unless the word is cracked). */
  race?: boolean;
  /** An Ask Wick question is being answered: the Focus face. */
  focus?: boolean;
  /** Show off every face: a new one every SHOWCASE_SECONDS, with the usual
   *  blink between them (3.7). Home and the round's welcome use it. */
  showcase?: boolean;
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
  /** Race mode and Ask Wick focus, which pick his face along with the mood. */
  setFlags(flags: { race?: boolean; focus?: boolean; showcase?: boolean }): void;
  /** The face he is wearing. */
  readonly face: FaceName;
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

/** The face group: 18 path slots, always in the same order (see faceDrawList). */
function buildFace(id: string): { g: SVGGElement; slots: SVGPathElement[] } {
  const g = svgEl("g", { class: "face", transform: FACE_TRANSFORM });
  const clip = svgEl("clipPath", { id: `plate-${id}` });
  clip.append(svgEl("path", { d: PLATE_ART }));
  g.append(clip);
  const slots: SVGPathElement[] = [];
  for (let k = 0; k < 18; k++) {
    const p = svgEl("path", { d: "" });
    g.append(p);
    slots.push(p);
  }
  return { g, slots };
}

/** Paint a face into its slots. Only touches attributes that changed. */
function paintFace(slots: SVGPathElement[], id: string, p: FaceP, closure: number[], color: RGB): void {
  const items = faceDrawList(p, closure, color);
  items.forEach((it, k) => {
    const el = slots[k];
    if (!el) return;
    const set = (name: string, v: string | null): void => {
      if (v === null) { if (el.hasAttribute(name)) el.removeAttribute(name); return; }
      if (el.getAttribute(name) !== v) el.setAttribute(name, v);
    };
    set("d", it.d);
    set("fill", it.stroke ? "none" : it.fill ?? null);
    set("stroke", it.stroke ?? null);
    set("stroke-width", it.stroke ? String(it.width ?? 24) : null);
    set("stroke-linecap", it.stroke ? "round" : null);
    set("stroke-linejoin", it.stroke ? "round" : null);
    set("opacity", it.opacity < 0.999 ? it.opacity.toFixed(3) : null);
    set("clip-path", it.plate ? `url(#plate-${id})` : null);
  });
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
  rig: SVGGElement;
  plate: SVGPathElement;
  id: string;
  faceSlots: SVGPathElement[];
  face: FaceName;             // the face he is wearing (or changing into)
  faceFrom: FaceP;            // where the morph started
  faceTo: FaceP;
  faceAt: number;             // when the last face change began
  race: boolean;
  focus: boolean;
  showcase: boolean;          // walking through every face (Home, the welcome)
  showStart: number | null;   // when the showcase began, set on its first frame
  faceKey: string;            // what was last painted, to skip repaints
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

/** Seconds on each face in the showcase, and the order he shows them in. */
export const SHOWCASE_SECONDS = 5;
export const SHOWCASE_ORDER: readonly FaceName[] = ["sly", "flustered", "shocked", "calm", "serious", "focus"];

/** The showcase face `elapsed` seconds after it started. */
export function showcaseFace(elapsed: number): FaceName {
  const step = Math.max(0, Math.floor(elapsed / SHOWCASE_SECONDS));
  return SHOWCASE_ORDER[step % SHOWCASE_ORDER.length]!;
}

/** The face the game state calls for right now (or the showcase's next one).
 *  No showcase with reduced motion: the swaps would be instant jumps. */
function wantFace(i: Inst, t: number, rm: boolean): FaceName {
  if (i.showcase && !rm) {
    if (i.showStart === null) i.showStart = t;
    return showcaseFace(t - i.showStart);
  }
  return faceFor({ mood: i.mood, race: i.race, focus: i.focus });
}

/** Start changing faces: blink, morph behind the lids, pop open. */
function changeFace(i: Inst, to: FaceName, t: number): void {
  const e = t - i.faceAt;
  i.faceFrom = lerpFace(i.faceFrom, i.faceTo, swapMorph(e));   // from wherever he is now
  i.faceTo = FACES[to];
  i.face = to;
  i.faceAt = t;
  i.blinkAt = null;
  i.nextBlinkAt = t + 1.2 + nextBlinkDelay();
}

function frame(i: Inst, t: number, rm: boolean): void {
  const want = wantFace(i, t, rm);
  if (want !== i.face) changeFace(i, want, t);
  const e = t - i.faceAt;
  const u = rm ? 1 : swapMorph(e);
  const face = u >= 1 ? i.faceTo : lerpFace(i.faceFrom, i.faceTo, u);
  const shut = face.eyes.every((ey) => ey.closed > 0.99);

  // Idle blinks: a random wait, then a quick shut and open (not while shut or changing faces).
  let blink = 0;
  if (!rm && !shut && e > 0.6) {
    if (i.blinkAt === null && t >= i.nextBlinkAt) i.blinkAt = t;
    if (i.blinkAt !== null) {
      const be = t - i.blinkAt;
      blink = blinkAmount(be);
      if (be >= BLINK_LENGTH) { i.blinkAt = null; i.nextBlinkAt = t + nextBlinkDelay(); }
    }
  }
  const swap = rm ? 0 : swapBlink(e);
  const closure = face.eyes.map((ey) => Math.max(ey.closed, blink, swap));

  const pulse = i.dance ? i.pulse() : null;
  const pose = poseAt({ t, mood: i.mood, pokeAt: i.pokeAt, reduceMotion: rm, pulse });
  // The pop as he opens on a new face: squash and stretch, a hop for Shocked.
  if (!rm) {
    const pop = pokeEnvelope(e - 0.3) * (i.face === "shocked" ? 1.6 : 1);
    pose.sy *= 1 + 0.10 * pop;
    pose.sx *= 1 - 0.06 * pop;
    if (i.face === "shocked") pose.y -= 5 * pop;
  }
  i.rig.setAttribute("transform", poseTransform(pose));
  i.el.style.opacity = pose.opacity < 1 ? pose.opacity.toFixed(3) : "";

  // The silhouette: only rewrite the path when the lean or the tip changed.
  const tipChanging = e < 0.5;
  if (Math.abs(pose.flicker - i.lastFlicker) > 0.002 || tipChanging) {
    i.lastFlicker = pose.flicker;
    i.lastPath = flamePath(pose.flicker, face.tip);
    i.body.setAttribute("d", i.lastPath);
    i.glow.setAttribute("d", i.lastPath);
  }

  // Colour ease.
  const cf = Math.min(1, (t - i.colorAt) / MOOD_EASE);
  const c = mixRGB(i.rgbFrom, i.rgbTo, cf);
  if (!i.colorDone) {
    const top = lighten(c, 0.12);
    const bot = rgb(c);
    i.stops[0]?.setAttribute("stop-color", top);
    i.stops[1]?.setAttribute("stop-color", bot);
    i.stops[2]?.setAttribute("stop-color", bot);
    i.glow.setAttribute("fill", bot);
    i.colorDone = cf >= 1;
  }

  // The face: repaint only when something in it moved.
  const key = `${i.face}|${u.toFixed(3)}|${closure.map((v) => v.toFixed(3)).join(",")}|${c.join(",")}`;
  if (key !== i.faceKey) {
    i.faceKey = key;
    paintFace(i.faceSlots, i.id, face, closure, c);
  }

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
  const t0 = now();
  const race = !!opts.race, focus = !!opts.focus;
  const startFace = faceFor({ mood, race, focus });
  const d0 = flamePath(0.5, FACES[startFace].tip);
  const glow = svgEl("path", {
    class: "flame-glow", d: d0, fill: rgb(color), opacity: 0.30, filter: `url(#soft-${id})`,
    transform: `translate(${BASE_X} ${BASE_Y}) scale(1.12) translate(${-BASE_X} ${-BASE_Y})`,
  });
  const body = svgEl("path", { class: "flame-body", d: d0, fill: `url(#body-${id})` });
  // The inner flame: one tone step lighter than the body (white at 22%).
  const plate = svgEl("path", { class: "flame-core", d: PLATE_PATH, fill: WHITE, opacity: 0.22 });
  const sparkG = svgEl("g", { class: "sparkles", fill: SPARKLE_COLOR });
  const face = buildFace(id);
  rig.append(glow, body, plate, sparkG, face.g);
  el.append(defs, rig);
  host.append(el);

  const inst: Inst = {
    el, host, mood, rgbFrom: color, rgbTo: color, colorAt: t0 - MOOD_EASE, colorDone: false, stops, glow, body, rig,
    plate, id, faceSlots: face.slots, face: startFace, faceFrom: FACES[startFace], faceTo: FACES[startFace],
    faceAt: t0 - 10, race, focus, showcase: !!opts.showcase, showStart: null, faceKey: "",
    sparkles: [], pokeAt: null,
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
      // The face follows on the next frame (wantFace), with a blink and a morph.
      el.classList.remove(`mood-${inst.mood}`);
      el.classList.add(`mood-${m}`);
      inst.mood = m;
      setSparkles(m);
      wake();
    },
    setScore(score, neutral) { handle.setMood(moodFor({ score, neutral })); },
    poke() { inst.pokeAt = now(); wake(); },
    setDance(on) { inst.dance = on; },
    setFlags(flags) {
      if (flags.race !== undefined) inst.race = flags.race;
      if (flags.focus !== undefined) inst.focus = flags.focus;
      if (flags.showcase !== undefined && flags.showcase !== inst.showcase) {
        inst.showcase = flags.showcase;
        inst.showStart = null;   // a fresh showcase always opens on Sly
      }
      wake();
    },
    get face() { return inst.face; },
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
    have.setFlags({ race: !!opts.race, focus: !!opts.focus, showcase: !!opts.showcase });
    if (opts.dance !== undefined) have.setDance(opts.dance);
    return have;
  }
  host.replaceChildren();
  const w = mountWick(host, opts);
  mounted.set(host, w);
  return w;
}
