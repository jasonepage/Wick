//
//  record.ts: Solve Replay (3.4) for the web: canvas to video file.
//
//  Two ways to make the file, best first:
//
//  1. WebCodecs (the browser's built-in video encoder) plus Mediabunny to pack
//     the frames into an MP4. Frames are drawn as fast as the device can, so a
//     45 second replay takes a few seconds, and the file is always MP4 (H.264).
//     Mediabunny is MPL-2.0 like Wick, and it is loaded only when a replay is
//     made, so it adds nothing to the normal page load.
//  2. If that encoder is missing, the old way: play the replay on the canvas in
//     real time while MediaRecorder captures it. MP4 where the browser can,
//     otherwise WebM.
//
//  The player shares or downloads the file and posts it themselves; nothing is
//  uploaded.
//

import type { ReplayScene } from "./scene.ts";

export interface Recording {
  blob: Blob;
  /** "video/mp4" or "video/webm". */
  type: string;
  ext: "mp4" | "webm";
}

const CANDIDATES = [
  "video/mp4;codecs=avc1.640028",
  "video/mp4;codecs=avc1",
  "video/mp4",
  "video/webm;codecs=vp9",
  "video/webm;codecs=vp8",
  "video/webm",
];

/** The best video format this browser can record, or null if it can't. */
export function pickMime(): string | null {
  if (typeof MediaRecorder === "undefined") return null;
  if (typeof HTMLCanvasElement === "undefined" || typeof HTMLCanvasElement.prototype.captureStream !== "function") return null;
  return CANDIDATES.find((m) => MediaRecorder.isTypeSupported(m)) ?? null;
}

export function canRecord(): boolean {
  return typeof VideoEncoder !== "undefined" || pickMime() !== null;
}

const FPS = 30;
const BITRATE = 8_000_000;
/** A short hold on the last frame so the end card isn't cut off. */
const TAIL = 0.3;

const aborted = (): DOMException => new DOMException("Recording cancelled", "AbortError");

/**
 * Way 1: encode every frame straight to MP4. Returns null when this browser
 * can't encode H.264 at this size, so the caller can fall back.
 */
async function encodeMp4(
  scene: ReplayScene,
  canvas: HTMLCanvasElement,
  onProgress: (p: number) => void,
  signal: AbortSignal,
): Promise<Recording | null> {
  if (typeof VideoEncoder === "undefined") return null;
  // Destructured so the bundler keeps only the parts used here.
  const { canEncodeVideo, BufferTarget, Output, Mp4OutputFormat, CanvasSource } = await import("mediabunny");
  const ok = await canEncodeVideo("avc", { width: canvas.width, height: canvas.height, bitrate: BITRATE, frameRate: FPS });
  if (!ok) return null;
  const ctx = canvas.getContext("2d");
  if (!ctx) return null;

  const target = new BufferTarget();
  const output = new Output({ format: new Mp4OutputFormat({ fastStart: "in-memory" }), target });
  const source = new CanvasSource(canvas, { codec: "avc", bitrate: BITRATE, keyFrameInterval: 2 });
  output.addVideoTrack(source, { frameRate: FPS });
  await output.start();

  const frames = Math.ceil((scene.duration + TAIL) * FPS);
  try {
    for (let i = 0; i < frames; i++) {
      if (signal.aborted) throw aborted();
      scene.draw(ctx, Math.min(i / FPS, scene.duration));
      await source.add(i / FPS, 1 / FPS);
      if (i % 10 === 0) {
        onProgress(i / frames);
        // Let the page repaint so the progress bar moves.
        await new Promise((r) => setTimeout(r, 0));
      }
    }
    await output.finalize();
  } catch (e) {
    await output.cancel().catch(() => undefined);
    throw e;
  }
  if (!target.buffer) throw new Error("encoder produced no file");
  onProgress(1);
  return { blob: new Blob([target.buffer], { type: "video/mp4" }), type: "video/mp4", ext: "mp4" };
}

/**
 * Makes the video, MP4 whenever the browser allows. Resolves with the finished
 * file. Rejects with an AbortError if `signal` fires.
 */
export async function recordReplay(
  scene: ReplayScene,
  canvas: HTMLCanvasElement,
  onProgress: (p: number) => void,
  signal: AbortSignal,
): Promise<Recording> {
  try {
    const mp4 = await encodeMp4(scene, canvas, onProgress, signal);
    if (mp4) return mp4;
  } catch (e) {
    if ((e as { name?: string }).name === "AbortError") throw e;
    // Encoder failed partway (rare); fall back to real-time recording.
  }
  return recordRealtime(scene, canvas, onProgress, signal);
}

/** Way 2: plays the replay on `canvas` in real time and records it. */
async function recordRealtime(
  scene: ReplayScene,
  canvas: HTMLCanvasElement,
  onProgress: (p: number) => void,
  signal: AbortSignal,
): Promise<Recording> {
  const mime = pickMime();
  const ctx = canvas.getContext("2d");
  if (!mime || !ctx) throw new Error("recording not supported");

  scene.draw(ctx, 0);
  const stream = canvas.captureStream(FPS);
  const recorder = new MediaRecorder(stream, { mimeType: mime, videoBitsPerSecond: BITRATE });
  const chunks: Blob[] = [];
  recorder.ondataavailable = (e) => { if (e.data.size > 0) chunks.push(e.data); };
  const stopped = new Promise<void>((resolve) => { recorder.onstop = () => resolve(); });

  recorder.start(1000);
  const start = performance.now();
  try {
    await new Promise<void>((resolve, reject) => {
      const tick = (): void => {
        if (signal.aborted) { reject(aborted()); return; }
        const t = (performance.now() - start) / 1000;
        scene.draw(ctx, Math.min(t, scene.duration));
        onProgress(Math.min(1, t / scene.duration));
        if (t >= scene.duration + TAIL) resolve();
        else requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    });
  } finally {
    if (recorder.state !== "inactive") recorder.stop();
    await stopped;
    stream.getTracks().forEach((track) => track.stop());
  }

  const type = mime.split(";")[0]!;
  return { blob: new Blob(chunks, { type }), type, ext: type === "video/mp4" ? "mp4" : "webm" };
}

export type SaveOutcome = "shared" | "downloaded" | "cancelled" | "failed";

/** Can this browser hand a video file to the system share sheet? */
export function canShareFile(rec: Recording, name: string): boolean {
  const nav = navigator as Navigator & { canShare?: (d?: ShareData) => boolean };
  if (typeof nav.share !== "function" || !nav.canShare) return false;
  try {
    return nav.canShare({ files: [new File([rec.blob], `${name}.${rec.ext}`, { type: rec.type })] });
  } catch {
    return false;
  }
}

/** Opens the share sheet with the video (on phones this offers "Save Video"
 *  and the TikTok app). */
export async function shareVideo(rec: Recording, name: string): Promise<SaveOutcome> {
  const file = new File([rec.blob], `${name}.${rec.ext}`, { type: rec.type });
  try {
    await navigator.share({ files: [file] });
    return "shared";
  } catch (e) {
    return (e as { name?: string }).name === "AbortError" ? "cancelled" : "failed";
  }
}

/** Saves the video to the Downloads folder. */
export function downloadVideo(rec: Recording, name: string): SaveOutcome {
  try {
    const url = URL.createObjectURL(rec.blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `${name}.${rec.ext}`;
    document.body.append(a);
    a.click();
    a.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
    return "downloaded";
  } catch {
    return "failed";
  }
}
