// SPDX-License-Identifier: MPL-2.0
//
//  wick.ts: Wick, the mascot, as a living thing on the web.
//
//  Wick is a purple flame with a face. On iOS (Hunch/Theme/KeeperView.swift) he
//  is drawn fresh every frame from the clock. Since the 3.8 motion pass, how
//  he moves comes from the motion director in wickmotion.ts (base pose, idle
//  life, reaction clips, dance, face and colour transition); this file draws
//  it as an SVG, with the same numbers as iOS.
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
  solveMorph, accentFace,
  SOLVE_DONE, SOLVE_HIT, SOLVE_RM_DONE, solveFace, solveRing, solveScale, solveSparks,
} from "./wickface.ts";
import { musicPulse } from "./music.ts";
import {
  type Motion, type MotionMood, type WickDanceStyle, MotionDirector, clamp, colorWipe, danceInto, danceReducedInto,
  idleBody, idleGlow, motionZero,
} from "./wickmotion.ts";

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
//
//  3.8 motion pass: the motion itself lives in wickmotion.ts (the five
//  channels, the clips, the dance phrases). This section keeps the small
//  stateless helpers the canvas, the replay and the Motion Studio use.

/**
 * The flame outline: the chunky flame from the approved icon art (see
 * chunkyFlamePath in wickface.ts). `flicker` is 0..1; the tip leans by
 * (flicker - 0.5) * LEAN. `tip` is the face's tip reaction.
 */
export function flamePath(flicker: number, tip?: TipP): string {
  return chunkyFlamePath((flicker - 0.5) * LEAN, tip);
}

/** The motion channel `tip` (-1..1) as a flicker (0..1). */
export function tipToFlicker(tip: number): number {
  return clamp(0.5 + 0.5 * tip, 0, 1);
}

/** 3.8: three gold sparks, no more (the personality brief). */
export const SPARKLES: { x: number; y: number; r: number }[] = [
  { x: 22, y: 40, r: 4 }, { x: 100, y: 34, r: 3.4 }, { x: 104, y: 88, r: 3 },
];
export const SPARKLE_COLOR = rgb(PALETTE.warm);

/** How bright sparkle `i` is at time `t` (0..1). Mirrors KeeperView.sparkles. */
export function sparklePhase(t: number, i: number): number {
  return (Math.sin((t * 2 * Math.PI) / 0.6 - i * 0.75) + 1) / 2;
}

/**
 * The old boiling shake (two sine waves at unrelated speeds). 3.8 no longer
 * shakes him endlessly: the red entrance is the authored "hide-panic" clip,
 * and the ambient tremor afterwards is a small fraction of this (wickmotion.ts
 * idleBody). Kept for the replay renderer and its tests.
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

/** A tap: one squash and release, no wobble (3.8). Mirrors KeeperView. */
export function pokeSquash(e: number): { sx: number; sy: number } {
  const k = pokeEnvelope(e);
  return { sx: 1 + 0.06 * k, sy: 1 - 0.1 * k };
}

export type { WickDanceStyle };

export interface Move {
  x: number;
  y: number;
  rot: number;
  sx: number;
  sy: number;
  /** -1...1. Secondary motion for the flame crown. */
  tip: number;
}
export const STILL: Move = { x: 0, y: 0, rot: 0, sx: 1, sy: 1, tip: 0 };

/**
 * Wick's dance for one reading of the race music, in units of `size`. The
 * phrases, the riser crouch and the drop are in wickmotion.ts (danceInto).
 * `style` fixes the vocabulary; left out, the music's energy picks it.
 */
export function danceAt(p: WickPulse, size = SIZE, style?: WickDanceStyle, intensity = 1): Move {
  const m = motionZero();
  danceInto(p, m, style, intensity);
  return { x: m.x * size, y: m.y * size, rot: m.rot, sx: 1 + m.sx, sy: 1 + m.sy, tip: clamp(m.tip, -1, 1) };
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
  danceStyle?: WickDanceStyle;
  danceIntensity?: number;
  size?: number;
  /** Idle seed (the Motion Studio passes one so a clip is repeatable). */
  seed?: number;
}

/**
 * A stateless pose for exports and the studio: idle life plus the dance plus
 * a tap. The live game uses MotionDirector instead (reactions, transitions,
 * attention). Same channels, same numbers.
 */
export function poseAt(a: PoseInput): Pose {
  const size = a.size ?? SIZE;
  const { t } = a;
  const m = motionZero();
  const mood = motionMood(a.mood);
  if (a.reduceMotion) {
    if (a.pulse) danceReducedInto(a.pulse, m);
    return { x: 0, y: 0, rot: 0, sx: 1, sy: 1, flicker: 0.5, opacity: idleGlow(t) * m.glow };
  }
  idleBody(t, a.seed ?? 0, mood, m, a.pulse ? 0.25 : 1);
  if (a.pulse) danceInto(a.pulse, m, a.danceStyle, a.danceIntensity);
  let sx = 1 + m.sx, sy = 1 + m.sy;
  if (a.pokeAt !== null) {
    const k = pokeSquash(t - a.pokeAt);
    sx *= k.sx; sy *= k.sy;
  }
  return { x: m.x * size, y: m.y * size, rot: m.rot, sx, sy, flicker: tipToFlicker(m.tip), opacity: 1 };
}

/** Grey ("unamused" on the web) is the deadpan mood the motion calls grey. */
export function motionMood(m: WickMood): MotionMood {
  return m === "unamused" ? "grey" : m;
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
  /** Which authored motion clip to blend with the beat. */
  danceStyle?: WickDanceStyle;
  /** 0.35...1.65 in the motion studio; 1 in the game. */
  danceIntensity?: number;
  /** Race mode: the Serious face (unless the word is cracked). */
  race?: boolean;
  /** An Ask Wick question is being answered: the Focus face. */
  focus?: boolean;
  /** Short authored personality beat. Color still comes from score/mood. */
  face?: FaceName | null;
  /** 3.8: the solve was the first guess, so Shocked holds a little longer. */
  firstGuess?: boolean;
  /** 3.8: called once when the solved sequence ends (not on a reopened round). */
  onSolveDone?: (skipped: boolean) => void;
  /** Show off every face: a new one every SHOWCASE_SECONDS, with the usual
   *  blink between them (3.7). Home and the round's welcome use it. */
  showcase?: boolean;
  /** Where to read the music from; defaults to music.ts. The clip exporter passes its own. */
  pulse?: () => WickPulse | null;
  /** Called when the player pokes him. */
  onPoke?: () => void;
  /** 3.8: bump `seq` to cue a reaction clip (a scored guess, a personality
   *  beat, an Ask Wick answer). `kind` is a wickpersonality.ts reaction kind,
   *  "question", or null for a plain guess. The first value seen is not cued. */
  cue?: { seq: number; kind: string | null };
  /** 3.8 Race Showdown: a small pose added on top of his motion every frame
   *  (the face-off glance and lean). Return null for none. */
  stance?: (() => WickStance | null) | null;
}

/** Pupils, tip lean and a scale squash, in wickmotion.ts channel units. */
export interface WickStance { gx: number; tip: number; sx: number; sy: number }

export interface Wick {
  readonly el: SVGSVGElement;
  readonly mood: WickMood;
  /** Change the look from a score (and the grey flag), easing over half a second. */
  setScore(score: number | null, neutral?: boolean): void;
  setMood(mood: WickMood): void;
  /** Squash, stretch and wiggle, like a tap on iOS Wick. */
  poke(): void;
  setDance(on: boolean, style?: WickDanceStyle, intensity?: number): void;
  /** Race mode and Ask Wick focus, which pick his face along with the mood. */
  setFlags(flags: { race?: boolean; focus?: boolean; showcase?: boolean }): void;
  /** Temporarily override only the expression; null returns control to heat. */
  setFace(face: FaceName | null): void;
  /** 3.8: jump to the end of the solved sequence (the player tapped). Returns
   *  true when a sequence was running and got skipped. */
  settleSolve(): boolean;
  /** 3.8: what the next solved sequence should know (set before the solving score lands). */
  setSolveOptions(o: { firstGuess?: boolean; onSolveDone?: ((skipped: boolean) => void) | null }): void;
  /** Seconds into the solved sequence, or null when none is running. */
  readonly solveElapsed: number | null;
  /** 3.8: play the reaction for a scored guess or a reaction kind now. */
  cue(kind: string | null): void;
  /** 3.8: the input field's focus, and a keystroke (typing awareness). */
  input(focused: boolean, typed?: boolean): void;
  /** 3.8: the extra pose read every frame (see WickOptions.stance). */
  setStance(fn: (() => WickStance | null) | null): void;
  /** The face he is wearing. */
  readonly face: FaceName;
  /** Stop animating and remove the SVG. */
  destroy(): void;
}

/** One random number per page load, so each session idles a little differently. */
const SESSION_SEED = (Math.random() * 4294967296) >>> 0;
function seedFor(id: string): number {
  let h = 2166136261;
  for (let k = 0; k < id.length; k++) h = Math.imul(h ^ id.charCodeAt(k), 16777619);
  return (SESSION_SEED ^ h) >>> 0;
}
const SVG_NS = "http://www.w3.org/2000/svg";

function svgEl<K extends keyof SVGElementTagNameMap>(tag: K, attrs: Record<string, string | number> = {}): SVGElementTagNameMap[K] {
  const e = document.createElementNS(SVG_NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, String(v));
  return e;
}

/** The face group: 19 path slots, always in the same order (see faceDrawList). */
function buildFace(id: string): { g: SVGGElement; slots: SVGPathElement[] } {
  const g = svgEl("g", { class: "face", transform: FACE_TRANSFORM });
  const clip = svgEl("clipPath", { id: `plate-${id}` });
  clip.append(svgEl("path", { d: PLATE_ART }));
  g.append(clip);
  const slots: SVGPathElement[] = [];
  for (let k = 0; k < 19; k++) {
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
  colorAt: number;            // when the colour change began (seconds)
  colorDone: boolean;         // true once the wipe has landed and been painted
  wipe: [number, number, number];
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
  overrideFace: FaceName | null;
  showcase: boolean;          // walking through every face (Home, the welcome)
  showStart: number | null;   // when the showcase began, set on its first frame
  faceKey: string;            // what was last painted, to skip repaints
  sparkles: SVGPathElement[];
  pokeAt: number | null;
  /** 3.8: when the solved sequence began; -Infinity when he was already
   *  solved at mount (a reopened round), so the final pose shows at once. */
  solvedAt: number | null;
  solvedFirst: boolean;
  ring: SVGCircleElement;
  onSolveDone: ((skipped: boolean) => void) | null;     // armed for the running sequence
  solveDoneOpt: ((skipped: boolean) => void) | null;    // what the next sequence will call
  nextBlinkAt: number;
  blinkAt: number | null;
  visible: boolean;
  dance: boolean;
  danceStyle: WickDanceStyle;
  danceIntensity: number;
  pulse: () => WickPulse | null;
  io: IntersectionObserver | null;
  lastFlicker: number;
  lastTip: string;
  lastPath: string;
  /** 3.8 motion */
  director: MotionDirector;
  mo: Motion;
  pose: Pose;
  stance: (() => WickStance | null) | null;
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

/** The colour now, at stop `k` of the wipe (0 top, 1 middle, 2 bottom). */
function wipeColor(i: Inst, k: number): RGB {
  return mixRGB(i.rgbFrom, i.rgbTo, i.wipe[k]!);
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
  if (i.mood === "celebrating" && i.solvedAt !== null) return solveFace(t - i.solvedAt, rm, i.solvedFirst);
  if (i.overrideFace) return i.overrideFace;
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
  // 3.8: the solved sequence outranks everything (see wickmotion.ts).
  const se = i.mood === "celebrating" && i.solvedAt !== null && i.solvedAt !== -Infinity ? t - i.solvedAt : null;
  const solving = se !== null && se < (rm ? SOLVE_RM_DONE : SOLVE_DONE);
  const want = wantFace(i, t, rm);
  if (want !== i.face) changeFace(i, want, t);
  const e = t - i.faceAt;
  const u = rm ? 1 : solving ? solveMorph(e) : swapMorph(e);
  const face0 = u >= 1 ? i.faceTo : lerpFace(i.faceFrom, i.faceTo, u);
  const shut = face0.eyes.every((ey) => ey.closed > 0.99);

  // The transition is the latest face or colour change: one blink for both.
  const te = t - Math.max(i.faceAt, i.colorAt);
  const swap = rm || solving ? 0 : swapBlink(te);

  // Idle blinks: a random wait, then a quick shut and open (not while shut or changing faces).
  let blink = 0;
  if (!rm && !shut && te > 0.6) {
    if (i.blinkAt === null && t >= i.nextBlinkAt) i.blinkAt = t;
    if (i.blinkAt !== null) {
      const be = t - i.blinkAt;
      blink = blinkAmount(be);
      if (be >= BLINK_LENGTH) { i.blinkAt = null; i.nextBlinkAt = t + nextBlinkDelay(); }
    }
  }

  // The motion director: base pose, idle life, reaction, dance, transition.
  const pulse = i.dance ? i.pulse() : null;
  const mo = i.mo;
  i.director.sample(t, {
    mood: motionMood(i.mood), rm, solveE: se, transitionE: te >= 0 && te < 2 ? te : null, pulse,
    style: i.danceStyle, intensity: i.danceIntensity,
  }, mo);
  // 3.8 Race Showdown: the face-off pose (it already obeys Reduced Motion).
  const st = i.stance ? i.stance() : null;
  if (st) { mo.gx += st.gx; mo.tip += st.tip; mo.sx += st.sx; mo.sy += st.sy; }
  const pose = i.pose;
  pose.x = mo.x * SIZE; pose.y = mo.y * SIZE; pose.rot = mo.rot;
  pose.sx = 1 + mo.sx; pose.sy = 1 + mo.sy;
  pose.flicker = rm ? 0.5 + 0.5 * clamp(mo.tip, -0.4, 0.4) : tipToFlicker(mo.tip);
  pose.opacity = mo.glow;
  if (!rm && i.pokeAt !== null) {
    const k = pokeSquash(t - i.pokeAt);
    pose.sx *= k.sx; pose.sy *= k.sy;
  }
  // 3.8: the solved sequence. Freeze on the hit, squash and rebound on the
  // release, one ring, and the sparks only from the release on.
  let sparksOn = true;
  if (se !== null) {
    if (!rm && se < SOLVE_HIT) { pose.x = 0; pose.y = 0; pose.rot = 0; pose.sx = 1; pose.sy = 1; }
    if (!rm) { const sc = solveScale(se); pose.sx *= sc.sx; pose.sy *= sc.sy; }
    const ring = solveRing(se, rm);
    if (ring) {
      const c = mixRGB(PALETTE.keeper, PALETTE.solved, ring.mix);
      i.ring.setAttribute("r", (ring.r * 60).toFixed(1));
      i.ring.setAttribute("stroke", rgb(c));
      i.ring.setAttribute("opacity", ring.opacity.toFixed(3));
    } else if (i.ring.getAttribute("opacity") !== "0") {
      i.ring.setAttribute("opacity", "0");
    }
    sparksOn = solveSparks(se, rm);
    const done = rm ? SOLVE_RM_DONE : SOLVE_DONE;
    if (se >= done && i.onSolveDone) { const cb = i.onSolveDone; i.onSolveDone = null; cb(false); }
  }
  i.rig.setAttribute("transform", poseTransform(pose));
  i.el.style.opacity = pose.opacity < 0.999 ? pose.opacity.toFixed(3) : "";

  // The face with its live accents (pupils, brows, lids, tip).
  const face = accentFace(face0, mo);
  const closure = face.eyes.map((ey, k) => Math.max(ey.closed, blink, swap, Math.max(0, k === 0 ? mo.ll : mo.lr)));

  // The silhouette: only rewrite the path when the lean or the tip changed.
  const tipKey = `${face.tip.dx.toFixed(2)},${face.tip.dy.toFixed(2)},${face.tip.sharp.toFixed(3)}`;
  if (Math.abs(pose.flicker - i.lastFlicker) > 0.002 || tipKey !== i.lastTip) {
    i.lastFlicker = pose.flicker;
    i.lastTip = tipKey;
    i.lastPath = flamePath(pose.flicker, face.tip);
    i.body.setAttribute("d", i.lastPath);
    i.glow.setAttribute("d", i.lastPath);
  }

  // Colour: it travels up the flame, bottom first, behind the closed lids.
  colorWipe(t - i.colorAt, rm, i.wipe);
  const c = wipeColor(i, 1);
  if (!i.colorDone) {
    i.stops[0]?.setAttribute("stop-color", lighten(wipeColor(i, 0), 0.12));
    i.stops[1]?.setAttribute("stop-color", rgb(c));
    i.stops[2]?.setAttribute("stop-color", rgb(wipeColor(i, 2)));
    i.glow.setAttribute("fill", rgb(c));
    i.colorDone = i.wipe[0] >= 1 && i.wipe[1] >= 1 && i.wipe[2] >= 1;
  }

  // The face: repaint only when something in it moved.
  const q = (v: number): string => (Math.round(v * 2) / 2).toString();
  const key = `${i.face}|${u.toFixed(3)}|${closure.map((v) => v.toFixed(3)).join(",")}|${c.join(",")}|${q(mo.gx)},${q(mo.gy)},${q(mo.bl)},${q(mo.br)},${(Math.min(0, mo.ll) + Math.min(0, mo.lr)).toFixed(2)}`;
  if (key !== i.faceKey) {
    i.faceKey = key;
    paintFace(i.faceSlots, i.id, face, closure, c);
  }

  // Sparkles twinkle (celebrating only; the group is empty otherwise).
  for (let k = 0; k < i.sparkles.length; k++) {
    const ph = rm ? 0.4 * sparklePhase(t, k) : sparklePhase(t, k);
    const sp = i.sparkles[k]!;
    const { x, y } = SPARKLES[k]!;
    sp.setAttribute("opacity", sparksOn ? (0.25 + 0.75 * ph).toFixed(3) : "0");
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
  // 3.8: the one solved ring, drawn behind him and invisible until the solve.
  const ring = svgEl("circle", { class: "solve-ring", cx: BASE_X, cy: 64, r: 0, fill: "none", "stroke-width": 3, opacity: 0 });
  const face = buildFace(id);
  rig.append(ring, glow, body, plate, sparkG, face.g);
  el.append(defs, rig);
  host.append(el);

  const inst: Inst = {
    el, host, mood, rgbFrom: color, rgbTo: color, colorAt: t0 - 10, colorDone: false, wipe: [1, 1, 1], stops, glow, body, rig,
    plate, id, faceSlots: face.slots, face: startFace, faceFrom: FACES[startFace], faceTo: FACES[startFace],
    faceAt: t0 - 10, race, focus, overrideFace: opts.face ?? null, showcase: !!opts.showcase, showStart: null, faceKey: "",
    sparkles: [], pokeAt: null,
    solvedAt: mood === "celebrating" ? -Infinity : null, solvedFirst: !!opts.firstGuess, ring, onSolveDone: null,
    solveDoneOpt: opts.onSolveDone ?? null,
    nextBlinkAt: t0 + nextBlinkDelay(), blinkAt: null, visible: true, dance: !!opts.dance,
    danceStyle: opts.danceStyle ?? "swagger", danceIntensity: opts.danceIntensity ?? 1,
    pulse: opts.pulse ?? musicPulse, io: null, lastFlicker: 0.5, lastTip: "", lastPath: d0,
    director: new MotionDirector(seedFor(id)), mo: motionZero(), stance: opts.stance ?? null,
    pose: { x: 0, y: 0, rot: 0, sx: 1, sy: 1, flicker: 0.5, opacity: 1 },
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
  el.addEventListener("pointerdown", () => { if (handle.settleSolve()) return; handle.poke(); opts.onPoke?.(); });

  instances.add(inst);
  hookDocument();
  wake();

  const handle: Wick = {
    el,
    get mood() { return inst.mood; },
    setMood(m: WickMood) {
      if (m === inst.mood) return;
      const t = now();
      // Start the colour change from wherever the colour is right now.
      colorWipe(t - inst.colorAt, reduceMotion(), inst.wipe);
      inst.rgbFrom = wipeColor(inst, 1);
      inst.rgbTo = moodRGB(m);
      inst.colorAt = t;
      inst.colorDone = false;
      // The face follows on the next frame (wantFace), with a blink and a morph.
      el.classList.remove(`mood-${inst.mood}`);
      el.classList.add(`mood-${m}`);
      if (m === "celebrating") { inst.solvedAt = t; inst.onSolveDone = inst.solveDoneOpt; }
      else inst.solvedAt = null;
      inst.mood = m;
      setSparkles(m);
      wake();
    },
    setScore(score, neutral) { handle.setMood(moodFor({ score, neutral })); },
    poke() { inst.pokeAt = now(); wake(); },
    setDance(on, style, intensity) {
      inst.dance = on;
      if (style) inst.danceStyle = style;
      if (intensity !== undefined) inst.danceIntensity = intensity;
      wake();
    },
    setFlags(flags) {
      if (flags.race !== undefined) inst.race = flags.race;
      if (flags.focus !== undefined) inst.focus = flags.focus;
      if (flags.showcase !== undefined && flags.showcase !== inst.showcase) {
        inst.showcase = flags.showcase;
        inst.showStart = null;   // a fresh showcase always opens on Sly
      }
      wake();
    },
    setFace(face) { inst.overrideFace = face; wake(); },
    setSolveOptions(o) {
      if (o.firstGuess !== undefined) inst.solvedFirst = o.firstGuess;
      if (o.onSolveDone !== undefined) inst.solveDoneOpt = o.onSolveDone;
    },
    settleSolve() {
      const e = handle.solveElapsed;
      if (e === null || e >= SOLVE_DONE) return false;
      if (e < SOLVE_HIT) return false;            // the hit itself cannot be skipped
      inst.solvedAt = now() - SOLVE_DONE;
      if (inst.onSolveDone) { const cb = inst.onSolveDone; inst.onSolveDone = null; cb(true); }
      wake();
      return true;
    },
    get solveElapsed() {
      if (inst.mood !== "celebrating" || inst.solvedAt === null || inst.solvedAt === -Infinity) return null;
      return now() - inst.solvedAt;
    },
    cue(kind) { inst.director.cue(now(), kind); wake(); },
    input(focused, typed = false) { inst.director.input(now(), focused, typed); wake(); },
    setStance(fn) { inst.stance = fn; wake(); },
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
    have.setSolveOptions({ firstGuess: opts.firstGuess, onSolveDone: opts.onSolveDone });
    have.setScore(opts.score, opts.neutral);
    have.setFlags({ race: !!opts.race, focus: !!opts.focus, showcase: !!opts.showcase });
    have.setFace(opts.face ?? null);
    have.setStance(opts.stance ?? null);
    if (opts.dance !== undefined) have.setDance(opts.dance, opts.danceStyle, opts.danceIntensity);
    const seen = cueSeen.get(have) ?? 0;
    if (opts.cue && opts.cue.seq !== seen) {
      cueSeen.set(have, opts.cue.seq);
      if (opts.cue.seq > seen) have.cue(opts.cue.kind);
    }
    return have;
  }
  host.replaceChildren();
  const w = mountWick(host, opts);
  mounted.set(host, w);
  cueSeen.set(w, opts.cue?.seq ?? 0);    // a fresh Wick does not replay the last cue
  return w;
}
const cueSeen = new WeakMap<Wick, number>();
