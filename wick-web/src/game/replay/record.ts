//
//  record.ts: Solve Replay (3.4) for the web: canvas to video file.
//
//  The browser has no offscreen video writer that works everywhere, so the
//  replay plays on a visible canvas in real time while MediaRecorder captures
//  it. A 45 second replay takes 45 seconds to record, and the player watches
//  it happen. No libraries.
//
//  Format: MP4 (H.264) where the browser can record it (Safari, recent
//  Chrome), otherwise WebM (Firefox). The player shares or downloads the file
//  and posts it themselves; nothing is uploaded.
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
  return pickMime() !== null;
}

/**
 * Plays the replay on `canvas` from the start and records it. Resolves with
 * the finished file. Rejects with an AbortError if `signal` fires.
 */
export async function recordReplay(
  scene: ReplayScene,
  canvas: HTMLCanvasElement,
  onProgress: (p: number) => void,
  signal: AbortSignal,
): Promise<Recording> {
  const mime = pickMime();
  const ctx = canvas.getContext("2d");
  if (!mime || !ctx) throw new Error("recording not supported");

  scene.draw(ctx, 0);
  const stream = canvas.captureStream(30);
  const recorder = new MediaRecorder(stream, { mimeType: mime, videoBitsPerSecond: 8_000_000 });
  const chunks: Blob[] = [];
  recorder.ondataavailable = (e) => { if (e.data.size > 0) chunks.push(e.data); };
  const stopped = new Promise<void>((resolve) => { recorder.onstop = () => resolve(); });

  recorder.start(1000);
  const start = performance.now();
  try {
    await new Promise<void>((resolve, reject) => {
      const tick = (): void => {
        if (signal.aborted) { reject(new DOMException("Recording cancelled", "AbortError")); return; }
        const t = (performance.now() - start) / 1000;
        scene.draw(ctx, Math.min(t, scene.duration));
        onProgress(Math.min(1, t / scene.duration));
        // A short hold on the last frame so the end card isn't cut off.
        if (t >= scene.duration + 0.3) resolve();
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
