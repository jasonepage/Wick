// SPDX-License-Identifier: MPL-2.0
//
//  wickcanvas.ts: draws Wick on a 2D canvas.
//
//  The game shows Wick as an SVG (wick.ts). Video clips need him painted onto a
//  canvas instead, one frame at a time, so this file draws the same flame, the
//  same face and the same pose with canvas calls. It reads the pose math from
//  wick.ts, so a frame here matches a frame on the page.
//

import {
  type Pose, type WickMood, BASE_X, BASE_Y, SPARKLES, SPARKLE_COLOR, flamePath, sparklePhase,
} from "./wick.ts";
import {
  type FaceAccent, type FaceName, type FaceP, type RGB, FACES, FACE_K, FACE_TX, FACE_TY, PLATE_ART, PLATE_PATH,
  accentFace, faceDrawList, faceFor, lighten, rgb,
} from "./wickface.ts";

export interface DrawWickArgs {
  /** Where Wick's feet go, in canvas pixels. */
  x: number;
  y: number;
  /** Canvas pixels per viewBox unit. Wick is 120 units wide. */
  scale: number;
  mood: WickMood;
  color: RGB;
  pose: Pose;
  /** 0 open ... 1 shut. */
  blink: number;
  /** Which of the Keeper's faces; picked from the mood when left out. */
  face?: FaceName;
  /** Seconds, for the sparkles. */
  t: number;
  /** 3.8: a face already morphed (a transition caught mid-way). */
  faceP?: FaceP;
  /** 3.8: live accents from the motion director (pupils, brows, lids, tip). */
  accent?: FaceAccent;
  /** 3.8: per-eye closure on top of the face's own (a transition blink). */
  closure?: number[];
  /** 3.8: [top, middle, bottom] while the colour travels up the flame. */
  colors?: [RGB, RGB, RGB];
  /** Hide the sparkles (the solved sequence before its release beat). */
  sparks?: boolean;
}

/** Paint one frame of Wick. Leaves the canvas state as it found it. */
export function drawWick(ctx: CanvasRenderingContext2D, a: DrawWickArgs): void {
  const { pose } = a;
  ctx.save();
  ctx.globalAlpha *= pose.opacity;
  // Into viewBox units, pivoting on the feet like the SVG transform does.
  ctx.translate(a.x, a.y);
  ctx.scale(a.scale, a.scale);
  ctx.translate(pose.x, pose.y);
  ctx.rotate((pose.rot * Math.PI) / 180);
  ctx.scale(pose.sx, pose.sy);
  ctx.translate(-BASE_X, -BASE_Y);

  const faceName = a.face ?? faceFor({ mood: a.mood });
  const face0 = a.faceP ?? FACES[faceName];
  const face = a.accent ? accentFace(face0, a.accent) : face0;
  const flame = new Path2D(flamePath(pose.flicker, face.tip));
  const [cTop, cMid, cBot] = a.colors ?? [a.color, a.color, a.color];
  const body = rgb(cMid);

  // Glow: the flame again, a little bigger, blurred and faint.
  ctx.save();
  ctx.translate(BASE_X, BASE_Y);
  ctx.scale(1.12, 1.12);
  ctx.translate(-BASE_X, -BASE_Y);
  ctx.filter = `blur(${(6 * a.scale).toFixed(1)}px)`;
  ctx.globalAlpha *= 0.30;
  ctx.fillStyle = body;
  ctx.fill(flame);
  ctx.restore();

  // Body: lighter at the tip.
  const g = ctx.createLinearGradient(0, 4, 0, 124);
  g.addColorStop(0, lighten(cTop, 0.12));
  g.addColorStop(0.55, body);
  g.addColorStop(1, rgb(cBot));
  ctx.fillStyle = g;
  ctx.fill(flame);

  // The inner flame: one tone step lighter (white at 22%).
  ctx.save();
  ctx.globalAlpha *= 0.22;
  ctx.fillStyle = "#ffffff";
  ctx.fill(new Path2D(PLATE_PATH));
  ctx.restore();

  // Sparkles (celebrating only).
  if (a.mood === "celebrating" && a.sparks !== false) {
    ctx.fillStyle = SPARKLE_COLOR;
    SPARKLES.forEach((s, k) => {
      const ph = sparklePhase(a.t, k);
      ctx.save();
      ctx.globalAlpha *= 0.25 + 0.75 * ph;
      ctx.translate(s.x, s.y);
      const sc = 0.7 + 0.45 * ph;
      ctx.scale(sc, sc);
      ctx.rotate((ph * 36 * Math.PI) / 180);
      ctx.translate(-s.x, -s.y);
      ctx.fill(new Path2D(starPathFor(s.x, s.y, s.r)));
      ctx.restore();
    });
  }

  // Face: the same draw list the SVG uses, in the art's units.
  ctx.save();
  ctx.translate(FACE_TX, FACE_TY);
  ctx.scale(FACE_K, FACE_K);
  const lids = [a.accent ? Math.max(0, a.accent.ll) : 0, a.accent ? Math.max(0, a.accent.lr) : 0];
  const closure = face.eyes.map((e, k) => Math.max(e.closed, a.blink, a.closure?.[k] ?? 0, lids[k] ?? 0));
  const plate = new Path2D(PLATE_ART);
  for (const it of faceDrawList(face, closure, cMid)) {
    if (!it.d || it.opacity <= 0.001) continue;
    ctx.save();
    if (it.plate) ctx.clip(plate);
    ctx.globalAlpha *= it.opacity;
    const p = new Path2D(it.d);
    if (it.stroke) {
      ctx.strokeStyle = it.stroke;
      ctx.lineWidth = it.width ?? 24;
      ctx.lineCap = "round";
      ctx.lineJoin = "round";
      ctx.stroke(p);
    } else {
      ctx.fillStyle = it.fill ?? "#ffffff";
      ctx.fill(p);
    }
    ctx.restore();
  }
  ctx.restore();
  ctx.restore();
}

// The star shape, the same as wickface.starPath (kept local so this file only
// leans on wick.ts for geometry that moves).
function starPathFor(cx: number, cy: number, r: number): string {
  let d = "";
  for (let i = 0; i < 10; i++) {
    const rad = i % 2 ? r * 0.45 : r;
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    d += `${i ? "L" : "M"}${(cx + Math.cos(a) * rad).toFixed(1)} ${(cy + Math.sin(a) * rad).toFixed(1)} `;
  }
  return `${d}Z`;
}
