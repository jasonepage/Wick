// SPDX-License-Identifier: MPL-2.0
//
//  wickface.ts: Wick's colours and face, shared by the web client.
//
//  The colour and label ramp is a faithful port of Hunch/Theme/HunchTheme.swift
//  (Palette, color(for:), label(for:)). Same RGB values, same score thresholds
//  (score = closeness 0..100). Wick's resting colour is the keeper violet
//  (purple): he starts purple before any warmth.
//
//  The mascot himself lives in wick.ts, which builds him once and moves him
//  from the clock, like KeeperView.swift on iOS. This file keeps the parts
//  both need: the palette, the mood for a score, and the star shape.
//

export type RGB = [number, number, number];

// Palette: exact RGB from HunchTheme.Palette (0..1 floats × 255).
export const PALETTE = {
  solved: [77, 158, 71] as RGB, // verdant green
  boiling: [232, 66, 54] as RGB, // ember red
  hot: [237, 107, 46] as RGB, // coral
  warm: [242, 166, 36] as RGB, // amber
  cool: [33, 161, 140] as RGB, // teal
  cold: [89, 189, 181] as RGB, // mint-teal
  freezing: [69, 133, 230] as RGB, // glacier blue
  keeper: [125, 92, 235] as RGB, // keeper violet, Wick's resting colour
  neutral: [120, 122, 134] as RGB, // deadpan grey ("Won't say" / unknown word)
};

function clamp01(w: number): number {
  return Math.max(0, Math.min(1, w));
}

export function rgb([r, g, b]: RGB): string {
  return `rgb(${r}, ${g}, ${b})`;
}
function rgba([r, g, b]: RGB, a: number): string {
  return `rgba(${r}, ${g}, ${b}, ${a})`;
}
/** Blend a colour toward white by fraction `f` (0..1), for the body's top highlight. */
export function lighten([r, g, b]: RGB, f: number): string {
  const m = (v: number) => Math.round(v + (255 - v) * f);
  return `rgb(${m(r)}, ${m(g)}, ${m(b)})`;
}

/** Temperature band for a closeness score (0..100); mirrors HunchTheme.color(for:). */
function band(score: number): RGB {
  if (score >= 100) return PALETTE.solved;
  if (score >= 60) return PALETTE.boiling;
  if (score >= 45) return PALETTE.hot;
  if (score >= 30) return PALETTE.warm;
  if (score >= 18) return PALETTE.cool;
  if (score >= 8) return PALETTE.cold;
  return PALETTE.freezing;
}

/** Heat word; mirrors HunchTheme.label(for:). */
export function scoreLabel(score: number): { label: string; hint: string } {
  if (score >= 100) return { label: "Solved!", hint: "you got it" };
  if (score >= 60) return { label: "Boiling", hint: "so hot!" };
  if (score >= 45) return { label: "Hot", hint: "so close" };
  if (score >= 30) return { label: "Warm", hint: "getting there" };
  if (score >= 18) return { label: "Cool", hint: "warming up" };
  if (score >= 8) return { label: "Cold", hint: "keep going" };
  return { label: "Freezing", hint: "keep going" };
}

/** CSS colour for a score (discrete band), or the resting violet if score is null. */
export function scoreColor(score: number | null): string {
  return score === null ? rgb(PALETTE.keeper) : rgb(band(score));
}
export function scoreColorA(score: number | null, a: number): string {
  return score === null ? rgba(PALETTE.keeper, a) : rgba(band(score), a);
}

export const RESTING_COLOR = rgb(PALETTE.keeper);

// ── moods ───────────────────────────────────────────────────────────────────

/** Wick's expression, mapped from the warmth band; mirrors KeeperMood.forScore. */
export type Mood =
  | "idle"
  | "freezing"
  | "cold"
  | "warm"
  | "hot"
  | "boiling"
  | "celebrating"
  | "unamused";

export function moodFor(opts: { score: number | null; neutral?: boolean }): Mood {
  if (opts.neutral) return "unamused";
  if (opts.score === null) return "idle";
  const s = opts.score;
  if (s >= 100) return "celebrating";
  if (s >= 60) return "boiling";
  if (s >= 45) return "hot";
  if (s >= 30) return "warm";
  if (s >= 18) return "cold";
  return "freezing";
}

/** Wick's body colour for a mood. Mirrors KeeperMood.bodyColor (unamused is the grey "Won't say" Wick on the web). */
export function moodRGB(mood: Mood): RGB {
  switch (mood) {
    case "freezing": return PALETTE.freezing;
    case "cold": return PALETTE.cold;
    case "warm": return PALETTE.warm;
    case "hot": return PALETTE.hot;
    case "boiling": return PALETTE.boiling;
    case "celebrating": return PALETTE.solved;
    case "unamused": return PALETTE.neutral;
    default: return PALETTE.keeper;
  }
}

/** A small n-pointed star path (celebrating eyes + solve sparkles). */
export function starPath(cx: number, cy: number, r: number): string {
  let d = "";
  for (let i = 0; i < 10; i++) {
    const rad = i % 2 ? r * 0.45 : r;
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    d += `${i ? "L" : "M"}${(cx + Math.cos(a) * rad).toFixed(1)} ${(cy + Math.sin(a) * rad).toFixed(1)} `;
  }
  return `${d}Z`;
}

/** Ring gauge: track + progress arc in `color`, filled to `fill` (0..1). */
export function ringSVG(fill: number, color: string): string {
  const t = clamp01(fill);
  const r = 52;
  const c = 2 * Math.PI * r;
  const offset = c * (1 - t);
  return `
  <svg class="ring" width="140" height="140" viewBox="0 0 120 120">
    <circle cx="60" cy="60" r="${r}" fill="none" stroke="rgba(255,255,255,0.08)" stroke-width="10"/>
    <circle cx="60" cy="60" r="${r}" fill="none" stroke="${color}" stroke-width="10"
      stroke-linecap="round" stroke-dasharray="${c.toFixed(1)}" stroke-dashoffset="${offset.toFixed(1)}"
      transform="rotate(-90 60 60)"/>
  </svg>`;
}
