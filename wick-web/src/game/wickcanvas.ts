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
  type Pose, type WickMood, BASE_X, BASE_Y, SPARKLES, SPARKLE_COLOR, blinkScale,
  faceSpec, flamePath, sparklePhase,
} from "./wick.ts";
import { type RGB, lighten, rgb } from "./wickface.ts";

const EYE_Y = 72;

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
  /** Seconds, for the sparkles. */
  t: number;
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

  const flame = new Path2D(flamePath(pose.flicker));
  const body = rgb(a.color);

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
  g.addColorStop(0, lighten(a.color, 0.12));
  g.addColorStop(0.55, body);
  g.addColorStop(1, body);
  ctx.fillStyle = g;
  ctx.fill(flame);

  // Sheen: a small white flame inside.
  ctx.save();
  ctx.translate(60, 119);
  ctx.scale(0.55, 0.55);
  ctx.translate(-60, -124);
  ctx.globalAlpha *= 0.22;
  ctx.fillStyle = "#ffffff";
  ctx.fill(flame);
  ctx.restore();

  // Sparkles (celebrating only).
  if (a.mood === "celebrating") {
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

  // Face. The eyes squeeze toward their centre line when blinking.
  const bs = blinkScale(a.blink);
  for (const s of faceSpec(a.mood)) {
    ctx.save();
    if (s.eye && bs < 1) {
      ctx.translate(0, EYE_Y);
      ctx.scale(1, bs);
      ctx.translate(0, -EYE_Y);
    }
    ctx.globalAlpha *= s.opacity;
    switch (s.kind) {
      case "circle":
        ctx.fillStyle = s.fill;
        ctx.beginPath();
        ctx.arc(s.cx, s.cy, s.r, 0, Math.PI * 2);
        ctx.fill();
        break;
      case "rect":
        ctx.fillStyle = s.fill;
        ctx.beginPath();
        ctx.roundRect(s.x, s.y, s.w, s.h, s.rx);
        ctx.fill();
        break;
      case "path": {
        const p = new Path2D(s.d);
        if (s.stroke) {
          ctx.strokeStyle = s.stroke;
          ctx.lineWidth = s.width ?? 3.4;
          ctx.lineCap = "round";
          ctx.stroke(p);
        } else {
          ctx.fillStyle = s.fill ?? "#ffffff";
          ctx.fill(p);
        }
        break;
      }
    }
    ctx.restore();
  }
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
