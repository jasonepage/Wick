// SPDX-License-Identifier: MPL-2.0
//
//  music.ts: race music for live races (3.5).
//
//  Made in GarageBand, all 120 BPM:
//
//    race_chill  a 16 bar (32 s) loop that plays from the start of a race.
//    race_riser  a 2 bar (4 s) build that plays into the switch.
//    race_kiai   a 16 bar loop for the last minute of the race. It never
//                switches back.
//
//  The riser starts on the first bar line after 1:05 is left, so kiai drops
//  right around the 1:00 mark. A race that ends sooner stays on chill.
//
//  The switch: the riser starts on the next bar line while chill ducks under
//  it, and kiai comes in from its own bar 1 exactly as the riser ends. Every
//  start is scheduled on the audio clock, so it lands on the beat.
//
//  The screen moves with the music: `musicPulse()` reads the same audio clock
//  and tells the background (backdrop.ts) where the beat is and how intense the
//  track is, so the stars and embers pulse in time and heat up for kiai.
//
//  Gapless looping. MP3 decoders add a few milliseconds of silence at the start
//  of a file, which would click at every loop. So each file holds one extra
//  second on both sides (the loop's last second, the 32 s loop, its first
//  second), and we loop the window from 1 s to 33 s. Any 32 s window of that
//  file is a perfect loop, so a decoder's offset can't break it. The files are
//  built by debug/music/make_race_loops.py.
//
//  Music has its own switch in Settings, on by default, separate from Sound
//  effects (off by default on the web). Nothing is downloaded until a race
//  actually starts.
//

import { audioOut } from "./sound.ts";

const BASE = "/sounds";
const KEY = "wick.music";

export function musicEnabled(): boolean {
  try { return localStorage.getItem(KEY) !== "0"; } catch { return true; }
}

export function setMusicEnabled(on: boolean): void {
  try { localStorage.setItem(KEY, on ? "1" : "0"); } catch { /* storage off */ }
  if (!on) stopRaceMusic();
}
const LOOP_START = 1;
const LOOP_END = 33;
const BAR = 2;            // seconds per bar at 120 BPM
const VOLUME = 0.6;       // under the guess tones, which are the feedback
const RISER = 4;          // seconds: 2 bars
const DUCK = 0.35;        // chill level by the end of the riser
const FADE_IN = 1.5;
const FADE_OUT = 1.2;
/** Kiai is the last minute. The riser needs 2 bars (4 s) plus up to a bar of
 *  waiting for a bar line, so it starts at 1:05 to land kiai near 1:00. */
export const KIAI_AT_MS = 65_000;

/** Should the race start its riser into kiai? Pure, so it can be tested. */
export function wantsKiai(remainingMs: number): boolean {
  return remainingMs <= KIAI_AT_MS;
}

interface Playing {
  ctx: AudioContext;
  out: GainNode;
  chill: GainNode;
  kiaiBuf: AudioBuffer | null;
  riserBuf: AudioBuffer | null;
  sources: AudioBufferSourceNode[];
  startedAt: number;
  kiaiOn: boolean;
  riserAt: number | null;
  kiaiAt: number | null;
}

const buffers = new Map<string, Promise<AudioBuffer | null>>();
let playing: Playing | null = null;
/** Bumped on every start and stop, so a slow download can't start music for a
 *  race that already ended. */
let generation = 0;

function load(ctx: AudioContext, name: string): Promise<AudioBuffer | null> {
  let job = buffers.get(name);
  if (!job) {
    job = (async () => {
      try {
        const res = await fetch(`${BASE}/${name}.mp3`);
        if (!res.ok) return null;
        return await ctx.decodeAudioData(await res.arrayBuffer());
      } catch {
        return null; // missing music must never break a race
      }
    })();
    buffers.set(name, job);
    void job.then((b) => { if (!b) buffers.delete(name); });
  }
  return job;
}

let starting: Promise<void> | null = null;

/** Start the race music. Safe to call often: while it is loading or playing,
 *  further calls just wait for or keep the same music. */
export function startRaceMusic(): Promise<void> {
  if (playing) return Promise.resolve();
  if (!starting) {
    const job = begin();
    starting = job;
    void job.finally(() => { if (starting === job) starting = null; });
  }
  return starting;
}

async function begin(): Promise<void> {
  const gen = ++generation;
  if (!musicEnabled()) return;
  const audio = await audioOut();
  if (!audio) return;
  const { ctx, master } = audio;
  const [chillBuf, kiaiBuf, riserBuf] = await Promise.all([
    load(ctx, "race_chill"), load(ctx, "race_kiai"), load(ctx, "race_riser"),
  ]);
  if (gen !== generation || playing || !chillBuf) return;

  const out = ctx.createGain();
  out.gain.value = 0;
  out.connect(master);
  const chill = ctx.createGain();
  chill.gain.value = 1;
  chill.connect(out);

  const at = ctx.currentTime + 0.05;
  const src = loopSource(ctx, chillBuf, chill);
  src.start(at, LOOP_START);
  out.gain.setValueAtTime(0, at);
  out.gain.linearRampToValueAtTime(VOLUME, at + FADE_IN);
  playing = { ctx, out, chill, kiaiBuf, riserBuf, sources: [src], startedAt: at, kiaiOn: false, riserAt: null, kiaiAt: null };
}

function loopSource(ctx: AudioContext, buf: AudioBuffer, to: AudioNode): AudioBufferSourceNode {
  const src = ctx.createBufferSource();
  src.buffer = buf;
  src.loop = true;
  src.loopStart = LOOP_START;
  src.loopEnd = LOOP_END;
  src.connect(to);
  return src;
}

/** Feed every race state in. Switches to kiai once: the riser starts on the
 *  next bar line and kiai lands on the downbeat after it. */
export function updateRaceMusic(remainingMs: number): void {
  const p = playing;
  if (!p || p.kiaiOn || !wantsKiai(remainingMs) || !p.kiaiBuf) return;
  p.kiaiOn = true;
  const { ctx } = p;
  // The next bar line at least 0.1 s away, so nothing is scheduled in the past.
  const bars = Math.ceil((ctx.currentTime + 0.1 - p.startedAt) / BAR);
  const riserAt = p.startedAt + bars * BAR;
  const kiaiAt = p.riserBuf ? riserAt + RISER : riserAt;
  p.riserAt = riserAt;
  p.kiaiAt = kiaiAt;

  if (p.riserBuf) {
    const riser = ctx.createBufferSource();
    riser.buffer = p.riserBuf;
    riser.connect(p.out);
    riser.start(riserAt);
    p.sources.push(riser);
    p.chill.gain.setValueAtTime(1, riserAt);
    p.chill.gain.linearRampToValueAtTime(DUCK, kiaiAt);
  }
  p.chill.gain.setValueAtTime(p.riserBuf ? DUCK : 1, kiaiAt);
  p.chill.gain.linearRampToValueAtTime(0, kiaiAt + 0.06);

  const kiai = loopSource(ctx, p.kiaiBuf, p.out);
  kiai.start(kiaiAt, LOOP_START);
  p.sources.push(kiai);
}

/** Where the music is right now, for visuals that move with it. Null when no
 *  race music is playing.
 *    beat    1 on each beat, falling to 0 before the next (a quick decay)
 *    down    the same, but only on the first beat of each bar
 *    energy  0 on chill, rising through the riser, 1 on kiai
 *    flash   1 at the moment kiai drops, fading over about a second */
export function musicPulse(): { beat: number; down: number; energy: number; flash: number } | null {
  const p = playing;
  if (!p) return null;
  // What the listener hears now, not what the audio thread is rendering.
  const lag = (p.ctx as AudioContext & { outputLatency?: number }).outputLatency ?? p.ctx.baseLatency ?? 0;
  const t = p.ctx.currentTime - lag - p.startedAt;
  if (t < 0) return { beat: 0, down: 0, energy: 0, flash: 0 };
  return pulseAt(t, p.riserAt === null ? null : p.riserAt - p.startedAt,
    p.kiaiAt === null ? null : p.kiaiAt - p.startedAt);
}

/** The pulse at `t` seconds into the music. Pure, so it can be tested. */
export function pulseAt(t: number, riserAt: number | null, kiaiAt: number | null):
  { beat: number; down: number; energy: number; flash: number } {
  const BEAT = BAR / 4;
  const inBeat = (t % BEAT) / BEAT;
  const beat = Math.exp(-inBeat * 5);
  const down = Math.floor(t / BEAT) % 4 === 0 ? beat : 0;
  let energy = 0;
  let flash = 0;
  if (riserAt !== null && kiaiAt !== null && t >= riserAt) {
    energy = t >= kiaiAt ? 1 : ((t - riserAt) / Math.max(0.001, kiaiAt - riserAt)) ** 2;
    if (t >= kiaiAt) flash = Math.exp(-(t - kiaiAt) * 3);
  }
  return { beat, down, energy, flash };
}

/** Fade the music out and stop it. Safe to call when nothing is playing. */
export function stopRaceMusic(): void {
  generation++;
  starting = null;
  const p = playing;
  playing = null;
  if (!p) return;
  const now = p.ctx.currentTime;
  p.out.gain.cancelScheduledValues(now);
  p.out.gain.setValueAtTime(p.out.gain.value, now);
  p.out.gain.linearRampToValueAtTime(0, now + FADE_OUT);
  for (const src of p.sources) {
    try { src.stop(now + FADE_OUT + 0.05); } catch { /* already stopped */ }
  }
  window.setTimeout(() => { try { p.out.disconnect(); } catch { /* gone */ } }, (FADE_OUT + 0.2) * 1000);
}
