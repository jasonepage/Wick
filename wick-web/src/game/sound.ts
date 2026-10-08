//
//  sound.ts — optional SFX for the web client.
//
//  The assets are the iOS set (Hunch/Sounds) transcoded to mono 96 kbps mp3 and
//  served from /sounds. The one worth understanding is the guess ladder:
//  guess_00 … guess_12 are thirteen tones rising from C4 (262 Hz) to E6 (1319 Hz)
//  in even ~2.33-semitone steps, so the PITCH of the reply tracks how warm the
//  guess was. Cold guesses answer low, boiling guesses answer high. The web had
//  no audio at all before this; the ladder was sitting unused in the iOS bundle.
//
//  Web-specific rules this module has to respect, none of which apply on iOS:
//
//    · Browsers refuse to start audio before a real user gesture, so nothing is
//      fetched, decoded, or even constructed until primeAudio() is called from a
//      genuine pointer/key event.
//    · A web page that makes noise uninvited is a page people close. So this is
//      OFF by default and there is a switch in Settings. To ship it on instead,
//      flip DEFAULT_ON below — that is the only change needed.
//    · Decoding happens once per clip into an AudioBuffer; playback is a fresh
//      BufferSource each time, so overlapping guesses don't cut each other off.
//

/** Ship-with-sound-on? Off is deliberate: see the note above. */
const DEFAULT_ON = false;

const KEY = "wick.sound";
const BASE = "/sounds";

/** Every clip we actually reference. */
export type SoundKey =
  | "tap" | "solved" | "gaveup" | "sparkle" | "coin" | "closest"
  | `guess_${string}`;

let ctx: AudioContext | null = null;
let master: GainNode | null = null;
const buffers = new Map<string, AudioBuffer>();
const pending = new Map<string, Promise<AudioBuffer | null>>();

export function soundEnabled(): boolean {
  try {
    const v = localStorage.getItem(KEY);
    if (v === "1") return true;
    if (v === "0") return false;
  } catch { /* storage off */ }
  return DEFAULT_ON;
}

export function setSoundEnabled(on: boolean): void {
  try { localStorage.setItem(KEY, on ? "1" : "0"); } catch { /* storage off */ }
  if (on) { primeAudio(); void play("tap"); }   // confirm the switch audibly
}

/** Called from the first real user gesture. Safe to call repeatedly. */
export function primeAudio(): void {
  if (!soundEnabled() || ctx) return;
  try {
    const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Ctor) return;
    ctx = new Ctor();
    master = ctx.createGain();
    master.gain.value = 0.5;   // the iOS clips are mixed hot for a phone speaker
    master.connect(ctx.destination);
  } catch { ctx = null; master = null; }
}

async function buffer(name: string): Promise<AudioBuffer | null> {
  if (!ctx) return null;
  const hit = buffers.get(name);
  if (hit) return hit;
  const inflight = pending.get(name);
  if (inflight) return inflight;

  const job = (async () => {
    try {
      const res = await fetch(`${BASE}/${name}.mp3`);
      if (!res.ok) return null;
      const buf = await ctx!.decodeAudioData(await res.arrayBuffer());
      buffers.set(name, buf);
      return buf;
    } catch {
      return null;   // a missing or undecodable clip must never break the game
    } finally {
      pending.delete(name);
    }
  })();
  pending.set(name, job);
  return job;
}

/** Fire and forget. Never throws, never blocks the caller. */
export async function play(name: SoundKey, gain = 1): Promise<void> {
  if (!soundEnabled()) return;
  primeAudio();
  if (!ctx || !master) return;
  // Safari suspends the context when the tab loses focus.
  if (ctx.state === "suspended") { try { await ctx.resume(); } catch { return; } }
  const buf = await buffer(name);
  if (!buf || !ctx || !master) return;
  try {
    const src = ctx.createBufferSource();
    src.buffer = buf;
    if (gain === 1) {
      src.connect(master);
    } else {
      const g = ctx.createGain();
      g.gain.value = gain;
      src.connect(g); g.connect(master);
    }
    src.start();
  } catch { /* autoplay still blocked, or the context died — stay silent */ }
}

/**
 * Answer a scored guess with its rung of the ladder.
 * @param warmth 0..1 closeness, the same number the guess row renders.
 */
export function playGuessTone(warmth: number): void {
  const w = Math.max(0, Math.min(1, warmth));
  const step = Math.round(w * 12);            // 0..12 → guess_00 … guess_12
  void play(`guess_${String(step).padStart(2, "0")}` as SoundKey);
}

/** Wire the one-time unlock to the first genuine gesture on the page. */
export function armAudioUnlock(): void {
  const once = () => { primeAudio(); };
  window.addEventListener("pointerdown", once, { once: true, passive: true });
  window.addEventListener("keydown", once, { once: true });
}
