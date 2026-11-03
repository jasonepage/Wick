// SPDX-License-Identifier: MPL-2.0
//
//  dance.ts: the developer page that turns Wick's dance into video clips.
//
//  Jason makes TikToks from CapCut templates, so this page renders Wick
//  dancing to the real race music and exports:
//    1. a vertical 1080 x 1920 video on flat chroma green (#00FF00) with the
//       music in it, so CapCut's Chroma Key can cut him out and the sound
//       lines up, and
//    2. a transparent PNG sequence in a zip, for templates that take overlays.
//
//  Every frame is computed from the beat math (`pulseAt` in music.ts) at an
//  exact time, not captured from a live screen, so nothing stutters and every
//  hop lands on a beat. The music for the clip is mixed the same way the race
//  mixes it (chill loop, riser with chill ducking under it, kiai loop) in an
//  OfflineAudioContext, so the clip's audio clock and the beat math agree.
//
//  Not part of the normal build: dance.html is only served by `npm run dev`.
//

import { pulseAt, type Pulse } from "./game/music.ts";
import { type Pose, type WickDanceStyle, type WickMood, BASE_X, BASE_Y, SIZE, mixRGB, motionMood, tipToFlicker } from "./game/wick.ts";
import {
  type FaceName, type FaceP, FACES, PALETTE, SOLVE_HIT, SOLVE_RELEASE, SOLVE_RM_SWAP, faceFor, lerpFace, moodRGB, rgb,
  solveMorph, solveRing, solveScale, solveSparks, swapBlink, swapMorph,
} from "./game/wickface.ts";
import { type Motion, MotionDirector, colorWipe, danceInto, danceReducedInto, idleBody, idleGlow, motionZero } from "./game/wickmotion.ts";
import { drawWick } from "./game/wickcanvas.ts";
import { zipStore, type ZipEntry } from "./game/zip.ts";

const FPS = 30;
const W = 1080;
const H = 1920;
const BAR = 2;
const LOOP_START = 1;
const LOOP_END = 33;
const GREEN = "#00ff00";
/** Wick is 120 units wide; at 6 px a unit he is 720 px wide with room to jump. */
const SCALE = 6;
const FEET_Y = H * 0.62;

type Section = "chill" | "drop" | "kiai" | "race";
/** 3.8 review scenes. "dance" is the original clip maker. */
type Scene = "dance" | "idle" | "reaction" | "transition" | "solved";
/** A fixed seed, so a review frame is the same every time. */
const SEED = 1234;
/** When the change happens in a review scene (seconds into the clip). */
const T0 = 0.6;
const SCENE_SECONDS: Record<Exclude<Scene, "dance">, number> = { idle: 14, reaction: 2.2, transition: 1.6, solved: 3 };
/** The mood a personality beat lands in, and the face the game shows with it. */
const KIND_MOOD: Record<string, WickMood> = { near: "boiling", stall: "unamused" };
const KIND_FACE: Record<string, FaceName> = { repeat: "focus", leap: "warm", near: "flustered", regress: "serious", stall: "calm", question: "focus" };

/** A whole race: 5 minutes. The riser starts on the first bar line after 1:05
 *  is left (3:56) and kiai lands at 4:00, like music.ts schedules it. */
const RACE_BARS = 150;
const RACE_RISER_AT = 236;
const RACE_KIAI_AT = 240;

interface Plan {
  mood: WickMood;
  style: WickDanceStyle;
  intensity: number;
  section: Section;
  bars: number;
  seconds: number;
  /** Seconds into the clip where the riser and kiai start (null on chill). */
  riserAt: number | null;
  kiaiAt: number | null;
  green: boolean;
  /** Put the race music in the video. Off for edits with their own track. */
  audio: boolean;
  scene: Scene;
  fromMood: WickMood;
  toMood: WickMood;
  clip: string;
  /** A fixed dance energy for review, or null to follow the music. */
  energy: number | null;
  rm: boolean;
  speed: number;
}

const $ = <T extends HTMLElement>(id: string): T => document.getElementById(id) as T;
const canvas = $<HTMLCanvasElement>("canvas");
const status = $<HTMLDivElement>("status");
const timeline = $<HTMLInputElement>("timeline");
const timeValue = $<HTMLOutputElement>("time-value");
const intensityValue = $<HTMLOutputElement>("intensity-value");
const poseReadout = $<HTMLPreElement>("pose-readout");
const ctx = canvas.getContext("2d")!;

function readPlan(): Plan {
  const mood = $<HTMLSelectElement>("mood").value as WickMood;
  const style = $<HTMLSelectElement>("style").value as WickDanceStyle;
  const intensity = Math.max(0.35, Math.min(1.65, Number($<HTMLInputElement>("intensity").value) || 1));
  const section = $<HTMLSelectElement>("section").value as Section;
  let bars = Math.max(1, Math.min(64, Math.round(Number($<HTMLInputElement>("bars").value) || 8)));
  // The drop needs 2 bars of chill, the 2 bar riser, and at least 2 bars of kiai.
  if (section === "drop" && bars < 6) { bars = 6; $<HTMLInputElement>("bars").value = "6"; }
  if (section === "race") { bars = RACE_BARS; $<HTMLInputElement>("bars").value = String(RACE_BARS); }
  const green = $<HTMLSelectElement>("background").value === "green";
  const audio = $<HTMLSelectElement>("audio").value !== "none";
  const riserAt = section === "drop" ? 2 * BAR : section === "race" ? RACE_RISER_AT : section === "kiai" ? -10 : null;
  const kiaiAt = section === "drop" ? 4 * BAR : section === "race" ? RACE_KIAI_AT : section === "kiai" ? -10 : null;
  const scene = $<HTMLSelectElement>("scene").value as Scene;
  const seconds = scene === "dance" ? bars * BAR : SCENE_SECONDS[scene];
  timeline.max = String(seconds);
  if (Number(timeline.value) > seconds) timeline.value = String(seconds);
  intensityValue.value = `${intensity.toFixed(2)}×`;
  const ev = $<HTMLSelectElement>("energy").value;
  return {
    mood, style, intensity, section, bars, seconds, riserAt, kiaiAt, green, audio, scene,
    fromMood: $<HTMLSelectElement>("from-mood").value as WickMood,
    toMood: $<HTMLSelectElement>("to-mood").value as WickMood,
    clip: $<HTMLSelectElement>("clip").value,
    energy: ev === "music" ? null : Number(ev),
    rm: $<HTMLInputElement>("rm").checked,
    speed: Number($<HTMLSelectElement>("speed").value) || 1,
  };
}

/** The music pulse `t` seconds into the clip. */
function pulseFor(plan: Plan, t: number): Pulse {
  return pulseAt(t, plan.riserAt, plan.kiaiAt);
}

// Blinks on a fixed pseudo-random schedule, so a re-export gives the same frames.
function blinkTimes(seconds: number): number[] {
  const out: number[] = [];
  let seed = 12345;
  const rand = (): number => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
  let t = 1.5;
  while (t < seconds) { out.push(t); t += 2.2 + rand() * 2.3; }
  return out;
}

function blinkAt(times: number[], t: number): number {
  for (const b of times) {
    const e = t - b;
    if (e < 0) break;
    if (e < 0.07) return e / 0.07;
    if (e < 0.18) return 1;
    if (e < 0.27) return 1 - (e - 0.18) / 0.09;
  }
  return 0;
}

/** A motion frame as a pose for the canvas (viewBox units). */
function poseFrom(m: Motion, rm: boolean): Pose {
  return {
    x: m.x * SIZE, y: m.y * SIZE, rot: m.rot, sx: 1 + m.sx, sy: 1 + m.sy,
    flicker: rm ? tipToFlicker(Math.max(-0.4, Math.min(0.4, m.tip))) : tipToFlicker(m.tip), opacity: m.glow,
  };
}

/** Paint frame at time `t` of the clip. `studio` updates the scrubber/readout;
 *  exports leave it false so thousands of frames do no extra DOM work. */
function drawFrame(plan: Plan, blinks: number[], t: number, studio = false): void {
  ctx.clearRect(0, 0, W, H);
  if (plan.green) { ctx.fillStyle = GREEN; ctx.fillRect(0, 0, W, H); }
  const lines = plan.scene === "dance" ? drawDance(plan, blinks, t) : drawReview(plan, blinks, t);
  if (studio) {
    timeline.value = String(Math.max(0, Math.min(plan.seconds, t)));
    timeValue.value = `${Math.max(0, t).toFixed(2)} s`;
    poseReadout.textContent = lines.join("\n");
  }
}

function readout(m: Motion): string[] {
  const f = (v: number, d = 3): string => v.toFixed(d);
  return [
    `body   x ${f(m.x)}  y ${f(m.y)}  rot ${f(m.rot, 1)}°  sx ${f(m.sx)}  sy ${f(m.sy)}`,
    `tip    lean ${f(m.tip, 2)}  up ${f(m.tu, 1)}   glow ${f(m.glow, 2)}`,
    `face   eyes ${f(m.gx, 1)},${f(m.gy, 1)}  brows ${f(m.bl, 1)},${f(m.br, 1)}  lids ${f(m.ll, 2)},${f(m.lr, 2)}`,
  ];
}

/** The dance phrase (the clip maker and the review): idle under it, accents on the face. */
function drawDance(plan: Plan, blinks: number[], t: number): string[] {
  const blink = plan.mood === "celebrating" || plan.mood === "unamused" ? 0 : blinkAt(blinks, t);
  const raw = pulseFor(plan, t);
  const pulse = plan.energy === null ? raw : { ...raw, energy: plan.energy, flash: 0 };
  const m = motionZero();
  if (plan.rm) { danceReducedInto(pulse, m); m.glow *= idleGlow(t); }
  else { idleBody(t, SEED, motionMood(plan.mood), m, 0.25); danceInto(pulse, m, plan.style, plan.intensity); }
  drawWick(ctx, { x: W / 2, y: FEET_Y, scale: SCALE, mood: plan.mood, color: moodRGB(plan.mood), pose: poseFrom(m, plan.rm), blink, t, accent: m });
  return [
    `dance ${plan.style} · ${plan.intensity.toFixed(2)}× · beat ${(Math.floor(t / 0.5) % 8) + 1} of 8${plan.rm ? " · Reduced Motion" : ""}`,
    `music  beat ${pulse.beat.toFixed(3)}  energy ${pulse.energy.toFixed(3)}  drop ${pulse.flash.toFixed(3)}`,
    ...readout(m),
  ];
}

/** Idle, a reaction clip, a face and colour change, or the solve: the real
 *  MotionDirector replayed from the start of the scene, so any frame can be
 *  scrubbed to and every frame is repeatable. */
function drawReview(plan: Plan, blinks: number[], t: number): string[] {
  const before = plan.fromMood;
  let after = before;
  let kind: string | null = null;
  let reactFace: FaceName | null = null;
  let second = false;                                // the interrupt test
  if (plan.scene === "transition") after = plan.toMood;
  if (plan.scene === "solved") after = "celebrating";
  if (plan.scene === "reaction") {
    if (plan.clip.startsWith("mood:")) after = plan.clip.slice(5) as WickMood;
    else if (plan.clip === "double") { after = "hot"; second = true; }
    else { kind = plan.clip.slice(5); after = KIND_MOOD[kind] ?? before; reactFace = KIND_FACE[kind] ?? null; }
  }
  const T1 = T0 + 0.25;
  const moodAt = (x: number): WickMood => (x < T0 ? before : second && x >= T1 ? "boiling" : after);
  const changedAt = (x: number): number | null => {
    if (x < T0) return null;
    if (second && x >= T1) return T1;
    return after !== before || reactFace !== null ? T0 : null;
  };
  const rm = plan.rm;
  const solving = plan.scene === "solved";
  const d = new MotionDirector(SEED);
  const m = motionZero();
  const inp = (x: number) => ({
    mood: motionMood(moodAt(x)), rm, pulse: null,
    transitionE: changedAt(x) === null ? null : x - changedAt(x)!,
    solveE: solving && x >= T0 ? x - T0 : null,
  });
  d.sample(0, inp(0), m);
  if (t >= T0) {
    if (plan.scene === "reaction") d.cue(T0, kind);
    d.sample(T0, inp(T0), m);
    if (second && t >= T1) { d.cue(T1, null); d.sample(T1, inp(T1), m); }
  }
  d.sample(t, inp(t), m);

  // The face: a blink-and-morph at each change, or the solve's own morphs.
  const fname = (w: WickMood): FaceName => faceFor({ mood: w });
  const se = solving && t >= T0 ? t - T0 : null;
  const te = changedAt(t) === null ? null : t - changedAt(t)!;
  let faceP: FaceP = FACES[fname(moodAt(t))];
  let swap = 0;
  if (se !== null) {
    const at = rm ? SOLVE_RM_SWAP : SOLVE_RELEASE;
    faceP = se < at
      ? lerpFace(FACES[fname(before)], FACES.shocked, rm ? 1 : solveMorph(se))
      : lerpFace(FACES.shocked, FACES.sly, rm ? 1 : solveMorph(se - at));
  } else if (te !== null) {
    const from = second && t >= T1 ? FACES[fname("hot")] : FACES[fname(before)];
    const to = FACES[reactFace ?? fname(moodAt(t))];
    faceP = lerpFace(from, to, rm ? 1 : swapMorph(te));
    swap = rm ? 0 : swapBlink(te);
  }
  // The colour travels up the flame from the old mood to the new one.
  const fromRGB = moodRGB(second && t >= T1 ? "hot" : before), toRGB = moodRGB(moodAt(t));
  const w: [number, number, number] = [1, 1, 1];
  if (te !== null || se !== null) colorWipe(se ?? te ?? 0, rm, w);
  const colors: [typeof fromRGB, typeof fromRGB, typeof fromRGB] = [mixRGB(fromRGB, toRGB, w[0]), mixRGB(fromRGB, toRGB, w[1]), mixRGB(fromRGB, toRGB, w[2])];

  const pose = poseFrom(m, rm);
  if (se !== null) {
    if (!rm && se < SOLVE_HIT) { pose.x = 0; pose.y = 0; pose.rot = 0; pose.sx = 1; pose.sy = 1; }
    if (!rm) { const sc = solveScale(se); pose.sx *= sc.sx; pose.sy *= sc.sy; }
  }
  const blink = plan.scene === "idle" && !rm ? blinkAt(blinks, t) : 0;
  const mood = moodAt(t);
  drawWick(ctx, {
    x: W / 2, y: FEET_Y, scale: SCALE, mood, color: colors[1], colors, pose, blink, t,
    faceP, accent: m, closure: [swap, swap], sparks: se === null ? true : solveSparks(se, rm),
  });
  const ring = se === null ? null : solveRing(se, rm);
  if (ring) {
    ctx.save();
    ctx.globalAlpha = ring.opacity;
    ctx.strokeStyle = rgb(mixRGB(PALETTE.keeper, PALETTE.solved, ring.mix));
    ctx.lineWidth = 3 * SCALE;
    ctx.beginPath();
    ctx.arc(W / 2 + (60 - BASE_X) * SCALE, FEET_Y + (64 - BASE_Y) * SCALE, ring.r * 60 * SCALE, 0, 2 * Math.PI);
    ctx.stroke();
    ctx.restore();
  }
  const clip = d.activeClip(t);
  return [
    `${plan.scene} · ${before}${after !== before ? ` → ${second && t >= T1 ? "boiling" : after}` : ""}${rm ? " · Reduced Motion" : ""}`,
    `clip ${clip ?? "none"}  ·  change at ${T0}s${se !== null ? `  ·  solve ${se.toFixed(2)}s` : ""}${te !== null ? `  ·  transition ${te.toFixed(2)}s` : ""}`,
    ...readout(m),
  ];
}

// ── music ───────────────────────────────────────────────────────────────────

const decoded = new Map<string, Promise<AudioBuffer>>();

function loadSound(name: string): Promise<AudioBuffer> {
  let job = decoded.get(name);
  if (!job) {
    job = (async () => {
      const res = await fetch(`./sounds/${name}.mp3`);
      if (!res.ok) throw new Error(`missing ${name}.mp3`);
      const bytes = await res.arrayBuffer();
      // A throwaway context just to decode; the mix happens offline below.
      const ac = new OfflineAudioContext(2, 1, 44100);
      return await ac.decodeAudioData(bytes);
    })();
    decoded.set(name, job);
  }
  return job;
}

/** Mix the race music for the clip, exactly as a race would play it. */
async function mixMusic(plan: Plan): Promise<AudioBuffer> {
  const [chill, riser, kiai] = await Promise.all([loadSound("race_chill"), loadSound("race_riser"), loadSound("race_kiai")]);
  const rate = chill.sampleRate;
  const ac = new OfflineAudioContext(2, Math.ceil(plan.seconds * rate), rate);
  const out = ac.createGain();
  out.gain.value = 0.9;
  out.connect(ac.destination);

  const loop = (buf: AudioBuffer, to: AudioNode, at: number): void => {
    const src = ac.createBufferSource();
    src.buffer = buf;
    src.loop = true;
    src.loopStart = LOOP_START;
    src.loopEnd = LOOP_END;
    src.connect(to);
    src.start(at, LOOP_START);
  };

  if (plan.section === "kiai") {
    loop(kiai, out, 0);
  } else {
    const chillGain = ac.createGain();
    chillGain.connect(out);
    loop(chill, chillGain, 0);
    if ((plan.section === "drop" || plan.section === "race") && plan.riserAt !== null && plan.kiaiAt !== null) {
      const r = ac.createBufferSource();
      r.buffer = riser;
      r.connect(out);
      r.start(plan.riserAt);
      chillGain.gain.setValueAtTime(1, plan.riserAt);
      chillGain.gain.linearRampToValueAtTime(0.35, plan.kiaiAt);
      chillGain.gain.linearRampToValueAtTime(0, plan.kiaiAt + 0.06);
      loop(kiai, out, plan.kiaiAt);
    }
  }
  return ac.startRendering();
}

// ── preview ─────────────────────────────────────────────────────────────────

let previewCtx: AudioContext | null = null;
let previewRaf = 0;
let replayFrom = 0;

async function startPreview(): Promise<void> {
  stopPreview();
  const plan = readPlan();
  canvas.classList.toggle("clear", !plan.green);
  say("Mixing music…");
  const music = await mixMusic(plan);
  const ac = new AudioContext();
  previewCtx = ac;
  const src = ac.createBufferSource();
  src.buffer = music;
  src.connect(ac.destination);
  const startAt = ac.currentTime + 0.1;
  const requested = Number(timeline.value) || 0;
  const from = requested >= plan.seconds - 1 / FPS
    ? Math.max(0, Math.min(plan.seconds - 1 / FPS, replayFrom))
    : Math.max(0, Math.min(plan.seconds - 1 / FPS, requested));
  src.start(startAt, from);
  const blinks = blinkTimes(plan.seconds);
  $<HTMLButtonElement>("stop").disabled = false;
  $<HTMLButtonElement>("preview").textContent = "↻ Restart";
  say(`Playing ${plan.bars} bars.`);
  const frame = (): void => {
    if (previewCtx !== ac) return;
    const lag = (ac as AudioContext & { outputLatency?: number }).outputLatency ?? ac.baseLatency ?? 0;
    // Audio is scheduled a fraction ahead so the first sample is reliable.
    // Hold the selected pose during that lead-in instead of letting output
    // latency make the studio scrubber visibly jump backwards.
    const t = Math.max(from, from + ac.currentTime - lag - startAt);
    drawFrame(plan, blinks, t, true);
    if (t < plan.seconds) previewRaf = requestAnimationFrame(frame);
    else { stopPreview(); say("Ready. Pick a move or press Play."); }
  };
  previewRaf = requestAnimationFrame(frame);
}

function stopPreview(): void {
  cancelAnimationFrame(previewRaf);
  if (previewCtx) { void previewCtx.close(); previewCtx = null; }
  $<HTMLButtonElement>("stop").disabled = true;
  $<HTMLButtonElement>("preview").textContent = "▶ Play";
}

// ── export ──────────────────────────────────────────────────────────────────

function say(text: string): void { status.textContent = text; }

function download(blob: Blob, name: string): void {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  document.body.append(a);
  a.click();
  a.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
}

function clipName(plan: Plan): string {
  return `wick-${plan.mood}-${plan.style}-${plan.section}-${plan.bars}bars${plan.audio ? "" : "-silent"}`;
}

async function exportVideo(): Promise<void> {
  stopPreview();
  const plan = readPlan();
  canvas.classList.toggle("clear", !plan.green);
  const mb = await import("mediabunny");
  const { Output, BufferTarget, Mp4OutputFormat, WebMOutputFormat, CanvasSource, AudioBufferSource,
    getFirstEncodableVideoCodec, getFirstEncodableAudioCodec, QUALITY_HIGH } = mb;

  // The mix is needed even for a silent clip: the beat math and the music
  // share one clock, so sample rate and timing come from the real audio.
  say("Mixing music…");
  const music = await mixMusic(plan);

  // MP4 with H.264 where the browser has it; otherwise WebM, which every
  // Chromium can encode. CapCut takes both.
  let format: InstanceType<typeof Mp4OutputFormat> | InstanceType<typeof WebMOutputFormat> = new Mp4OutputFormat({ fastStart: "in-memory" });
  let ext = "mp4";
  let videoCodec = await getFirstEncodableVideoCodec(format.getSupportedVideoCodecs(), { width: W, height: H });
  let audioCodec = await getFirstEncodableAudioCodec(format.getSupportedAudioCodecs(), { numberOfChannels: 2, sampleRate: music.sampleRate });
  if (!videoCodec) {
    format = new WebMOutputFormat();
    ext = "webm";
    videoCodec = await getFirstEncodableVideoCodec(format.getSupportedVideoCodecs(), { width: W, height: H });
    audioCodec = await getFirstEncodableAudioCodec(format.getSupportedAudioCodecs(), { numberOfChannels: 2, sampleRate: music.sampleRate });
  }
  if (!videoCodec) { say("This browser cannot encode video. Try Chrome or Safari."); return; }

  const target = new BufferTarget();
  const output = new Output({ format, target });
  const video = new CanvasSource(canvas, { codec: videoCodec, bitrate: 12_000_000, keyFrameInterval: 2 });
  output.addVideoTrack(video, { frameRate: FPS });
  let audio: InstanceType<typeof AudioBufferSource> | null = null;
  if (!plan.audio) audioCodec = null;
  if (audioCodec) {
    audio = new AudioBufferSource({ codec: audioCodec, quality: QUALITY_HIGH });
    output.addAudioTrack(audio);
  }
  await output.start();
  if (audio) await audio.add(music);

  const blinks = blinkTimes(plan.seconds);
  const frames = Math.round(plan.seconds * FPS);
  for (let i = 0; i < frames; i++) {
    const t = i / FPS;
    drawFrame(plan, blinks, t);
    await video.add(t, 1 / FPS);
    if (i % 15 === 0) {
      say(`Encoding ${ext.toUpperCase()}: ${Math.round((i / frames) * 100)}%`);
      await new Promise((r) => setTimeout(r, 0));
    }
  }
  await output.finalize();
  if (!target.buffer) { say("The encoder produced no file."); return; }
  const blob = new Blob([target.buffer], { type: ext === "mp4" ? "video/mp4" : "video/webm" });
  download(blob, `${clipName(plan)}.${ext}`);
  say(`Done: ${clipName(plan)}.${ext} (${(blob.size / 1e6).toFixed(1)} MB${audioCodec ? ", with audio" : ", silent"}).`);
}

async function exportPngs(): Promise<void> {
  stopPreview();
  const plan = { ...readPlan(), green: false };
  canvas.classList.add("clear");
  const blinks = blinkTimes(plan.seconds);
  const frames = Math.round(plan.seconds * FPS);
  const entries: ZipEntry[] = [];
  for (let i = 0; i < frames; i++) {
    drawFrame(plan, blinks, i / FPS);
    const blob = await new Promise<Blob | null>((r) => canvas.toBlob(r, "image/png"));
    if (!blob) { say("Could not make a PNG."); return; }
    entries.push({ name: `wick_${String(i + 1).padStart(4, "0")}.png`, data: new Uint8Array(await blob.arrayBuffer()) });
    if (i % 10 === 0) {
      say(`Rendering PNGs: ${Math.round((i / frames) * 100)}%`);
      await new Promise((r) => setTimeout(r, 0));
    }
  }
  entries.push({ name: "info.txt", data: new TextEncoder().encode(
    `Wick dance PNG sequence\n${frames} frames at ${FPS} frames per second, ${plan.seconds} seconds (${plan.bars} bars at 120 BPM).\n` +
    `Mood: ${plan.mood}. Choreography: ${plan.style} at ${plan.intensity.toFixed(2)}x. Section: ${plan.section}. 1080 x 1920, transparent background.\n`) });
  const zip = zipStore(entries);
  download(new Blob([zip], { type: "application/zip" }), `${clipName(plan)}-png.zip`);
  say(`Done: ${frames} PNG frames (${(zip.length / 1e6).toFixed(1)} MB).`);
}

// ── wire up ─────────────────────────────────────────────────────────────────

$("preview").addEventListener("click", () => { startPreview().catch((e) => say(String(e))); });
$("stop").addEventListener("click", stopPreview);
$("export-video").addEventListener("click", () => { exportVideo().catch((e) => say(String(e))); });
$("export-png").addEventListener("click", () => { exportPngs().catch((e) => say(String(e))); });
function redrawStudio(): void {
  const p = readPlan();
  canvas.classList.toggle("clear", !p.green);
  drawFrame(p, blinkTimes(p.seconds), Number(timeline.value) || 0, true);
}

const PRESETS: Record<string, { style: WickDanceStyle; intensity: number; section: Section; start: number }> = {
  groove: { style: "groove", intensity: 0.78, section: "chill", start: 0 },
  swagger: { style: "swagger", intensity: 1, section: "chill", start: 0 },
  drop: { style: "hype", intensity: 1.2, section: "drop", start: 7.1 },
};

// Presets are the normal interface: one click configures the hidden studio
// controls and starts playback. The detailed editor remains available below.
for (const button of document.querySelectorAll<HTMLButtonElement>("[data-preset]")) {
  button.addEventListener("click", () => {
    const name = button.dataset.preset ?? "swagger";
    const preset = PRESETS[name] ?? PRESETS.swagger!;
    stopPreview();
    $<HTMLSelectElement>("style").value = preset.style;
    $<HTMLInputElement>("intensity").value = String(preset.intensity);
    $<HTMLSelectElement>("section").value = preset.section;
    $<HTMLInputElement>("bars").value = "8";
    timeline.value = String(preset.start);
    replayFrom = preset.start;
    for (const other of document.querySelectorAll<HTMLButtonElement>("[data-preset]")) {
      const active = other === button;
      other.classList.toggle("active", active);
      other.setAttribute("aria-pressed", String(active));
    }
    redrawStudio();
    startPreview().catch((e) => say(String(e)));
  });
}

for (const id of ["mood", "style", "section", "bars", "background", "audio"]) {
  $(id).addEventListener("change", redrawStudio);
}
$<HTMLInputElement>("intensity").addEventListener("input", redrawStudio);
timeline.addEventListener("input", () => { stopPreview(); redrawStudio(); });
const step = (direction: number): void => {
  stopPreview();
  const p = readPlan();
  timeline.value = String(Math.max(0, Math.min(p.seconds, (Number(timeline.value) || 0) + direction / FPS)));
  redrawStudio();
};
$<HTMLButtonElement>("step-back").addEventListener("click", () => step(-1));
$<HTMLButtonElement>("step-forward").addEventListener("click", () => step(1));
// ── 3.8 review transport: a silent clock with pause, restart, speed and steps ──
let reviewRaf = 0;
let reviewLast = 0;
const reviewButton = $<HTMLButtonElement>("review-play");
function reviewTick(now: number): void {
  const p = readPlan();
  const dt = reviewLast ? Math.min(0.1, (now - reviewLast) / 1000) : 0;
  reviewLast = now;
  let t = (Number(timeline.value) || 0) + dt * p.speed;
  if (t > p.seconds) t = 0;                     // loop
  canvas.classList.toggle("clear", !p.green);
  drawFrame(p, blinkTimes(p.seconds), t, true);
  reviewRaf = requestAnimationFrame(reviewTick);
}
function pauseReview(): void {
  cancelAnimationFrame(reviewRaf);
  reviewRaf = 0;
  reviewLast = 0;
  reviewButton.textContent = "▶ Review";
}
function playReview(): void {
  stopPreview();
  pauseReview();
  reviewButton.textContent = "❚❚ Pause";
  reviewRaf = requestAnimationFrame(reviewTick);
}
reviewButton.addEventListener("click", () => { if (reviewRaf) pauseReview(); else playReview(); });
$("review-restart").addEventListener("click", () => { timeline.value = "0"; redrawStudio(); playReview(); });
const reviewStep = (dir: number): void => {
  pauseReview();
  stopPreview();
  const p = readPlan();
  timeline.value = String(Math.max(0, Math.min(p.seconds, (Number(timeline.value) || 0) + dir / 60)));
  redrawStudio();
};
$("review-back").addEventListener("click", () => reviewStep(-1));
$("review-forward").addEventListener("click", () => reviewStep(1));
for (const id of ["scene", "from-mood", "to-mood", "clip", "energy", "speed"]) $(id).addEventListener("change", () => { timeline.value = "0"; redrawStudio(); });
$("rm").addEventListener("change", redrawStudio);
$("preview").addEventListener("click", pauseReview);

// Hooks for scripted runs (Playwright): draw a frame at a time, or build a plan.
(window as unknown as { wickDance: unknown }).wickDance = { readPlan, drawFrame, blinkTimes, exportVideo, exportPngs };
redrawStudio();
say("Pick a move or press Play.");
