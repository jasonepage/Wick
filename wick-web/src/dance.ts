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
import { type WickMood, poseAt } from "./game/wick.ts";
import { moodRGB } from "./game/wickface.ts";
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

/** A whole race: 5 minutes. The riser starts on the first bar line after 1:05
 *  is left (3:56) and kiai lands at 4:00, like music.ts schedules it. */
const RACE_BARS = 150;
const RACE_RISER_AT = 236;
const RACE_KIAI_AT = 240;

interface Plan {
  mood: WickMood;
  section: Section;
  bars: number;
  seconds: number;
  /** Seconds into the clip where the riser and kiai start (null on chill). */
  riserAt: number | null;
  kiaiAt: number | null;
  green: boolean;
  /** Put the race music in the video. Off for edits with their own track. */
  audio: boolean;
}

const $ = <T extends HTMLElement>(id: string): T => document.getElementById(id) as T;
const canvas = $<HTMLCanvasElement>("canvas");
const status = $<HTMLDivElement>("status");
const ctx = canvas.getContext("2d")!;

function readPlan(): Plan {
  const mood = $<HTMLSelectElement>("mood").value as WickMood;
  const section = $<HTMLSelectElement>("section").value as Section;
  let bars = Math.max(1, Math.min(64, Math.round(Number($<HTMLInputElement>("bars").value) || 8)));
  // The drop needs 2 bars of chill, the 2 bar riser, and at least 2 bars of kiai.
  if (section === "drop" && bars < 6) { bars = 6; $<HTMLInputElement>("bars").value = "6"; }
  if (section === "race") { bars = RACE_BARS; $<HTMLInputElement>("bars").value = String(RACE_BARS); }
  const green = $<HTMLSelectElement>("background").value === "green";
  const audio = $<HTMLSelectElement>("audio").value !== "none";
  const riserAt = section === "drop" ? 2 * BAR : section === "race" ? RACE_RISER_AT : section === "kiai" ? -10 : null;
  const kiaiAt = section === "drop" ? 4 * BAR : section === "race" ? RACE_KIAI_AT : section === "kiai" ? -10 : null;
  return { mood, section, bars, seconds: bars * BAR, riserAt, kiaiAt, green, audio };
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

/** Paint frame at time `t` of the clip. */
function drawFrame(plan: Plan, blinks: number[], t: number): void {
  ctx.clearRect(0, 0, W, H);
  if (plan.green) { ctx.fillStyle = GREEN; ctx.fillRect(0, 0, W, H); }
  const blink = plan.mood === "celebrating" || plan.mood === "unamused" ? 0 : blinkAt(blinks, t);
  const pose = poseAt({ t, mood: plan.mood, pokeAt: null, reduceMotion: false, pulse: pulseFor(plan, t) });
  drawWick(ctx, { x: W / 2, y: FEET_Y, scale: SCALE, mood: plan.mood, color: moodRGB(plan.mood), pose, blink, t });
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
  src.start(startAt);
  const blinks = blinkTimes(plan.seconds);
  $<HTMLButtonElement>("stop").disabled = false;
  say(`Playing ${plan.bars} bars.`);
  const frame = (): void => {
    if (previewCtx !== ac) return;
    const lag = (ac as AudioContext & { outputLatency?: number }).outputLatency ?? ac.baseLatency ?? 0;
    const t = ac.currentTime - lag - startAt;
    drawFrame(plan, blinks, Math.max(0, t));
    if (t < plan.seconds) previewRaf = requestAnimationFrame(frame);
    else stopPreview();
  };
  previewRaf = requestAnimationFrame(frame);
}

function stopPreview(): void {
  cancelAnimationFrame(previewRaf);
  if (previewCtx) { void previewCtx.close(); previewCtx = null; }
  $<HTMLButtonElement>("stop").disabled = true;
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
  return `wick-${plan.mood}-${plan.section}-${plan.bars}bars${plan.audio ? "" : "-silent"}`;
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
    `Mood: ${plan.mood}. Section: ${plan.section}. 1080 x 1920, transparent background.\n`) });
  const zip = zipStore(entries);
  download(new Blob([zip], { type: "application/zip" }), `${clipName(plan)}-png.zip`);
  say(`Done: ${frames} PNG frames (${(zip.length / 1e6).toFixed(1)} MB).`);
}

// ── wire up ─────────────────────────────────────────────────────────────────

$("preview").addEventListener("click", () => { startPreview().catch((e) => say(String(e))); });
$("stop").addEventListener("click", stopPreview);
$("export-video").addEventListener("click", () => { exportVideo().catch((e) => say(String(e))); });
$("export-png").addEventListener("click", () => { exportPngs().catch((e) => say(String(e))); });
for (const id of ["mood", "section", "bars", "background", "audio"]) {
  $(id).addEventListener("change", () => { const p = readPlan(); canvas.classList.toggle("clear", !p.green); drawFrame(p, [], 0); });
}
// Hooks for scripted runs (Playwright): draw a frame at a time, or build a plan.
(window as unknown as { wickDance: unknown }).wickDance = { readPlan, drawFrame, blinkTimes, exportVideo, exportPngs };
drawFrame(readPlan(), [], 0);
