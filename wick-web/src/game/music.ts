// SPDX-License-Identifier: MPL-2.0
//
//  music.ts: race music for live races (3.5).
//
//  Made in GarageBand, all 120 BPM:
//
//    race_chill  a 16 bar (32 s) loop that plays from the start of a race.
//    race_riser  a 2 bar (4 s) build that plays into the switch.
//    race_kiai   a 16 bar loop that takes over when the race heats up: either
//                player reaches Hot, or a minute is left on the clock. It never
//                switches back.
//
//  The switch: the riser starts on the next bar line while chill ducks under
//  it, and kiai comes in from its own bar 1 exactly as the riser ends. Every
//  start is scheduled on the audio clock, so it lands on the beat.
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
/** Same cutoff as the Hot band (score 45 and up). */
export const KIAI_WARMTH = 0.45;
export const KIAI_REMAINING_MS = 60_000;

/** Should the race be on the kiai track? Pure, so it can be tested. */
export function wantsKiai(state: { youBest: number; oppBest: number; remainingMs: number }): boolean {
  return Math.max(state.youBest, state.oppBest) >= KIAI_WARMTH || state.remainingMs <= KIAI_REMAINING_MS;
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
  playing = { ctx, out, chill, kiaiBuf, riserBuf, sources: [src], startedAt: at, kiaiOn: false };
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
export function updateRaceMusic(state: { youBest: number; oppBest: number; remainingMs: number }): void {
  const p = playing;
  if (!p || p.kiaiOn || !wantsKiai(state) || !p.kiaiBuf) return;
  p.kiaiOn = true;
  const { ctx } = p;
  // The next bar line at least 0.1 s away, so nothing is scheduled in the past.
  const bars = Math.ceil((ctx.currentTime + 0.1 - p.startedAt) / BAR);
  const riserAt = p.startedAt + bars * BAR;
  const kiaiAt = p.riserBuf ? riserAt + RISER : riserAt;

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
