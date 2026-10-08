//
//  wickface.ts — the Wick mascot + warmth visuals for the web client.
//
//  The colour/label ramp is a FAITHFUL PORT of Hunch/Theme/HunchTheme.swift
//  (Palette + color(for:)/label(for:)). Same RGB values, same score thresholds
//  (score = closeness 0..100). Wick's resting colour is the keeper violet
//  (purple) — he "starts purple" before any warmth.
//
//  The mascot itself is ALSO a port of the iOS Wick (Hunch/Theme/KeeperView.swift):
//  the same teardrop flame silhouette, white mood-driven eyes/mouth (idle · freezing
//  · cold · warm · hot · boiling · celebrating · unamused), layered depth, and a
//  subtle idle life — drift · lean · waver · blink · sparkle, all Reduce-Motion aware
//  via the `.wick-mascot.alive` rules in style.css. KEEP IN LOCKSTEP with
//  KeeperView.swift — when Wick's look changes on one platform, mirror it on the other.
//
//  STRUCTURE THE STYLESHEET DEPENDS ON. Do not flatten these groups:
//    .wick-float  → vertical drift
//      .wick-sway → the lean; pivots on the flame's base at (60,122)
//        .flame-core
//          .flame-glow  → blurred halo, runs the waver one beat behind the body
//          .flame-body  → the silhouette that morphs; see @keyframes wick-waver
//          .flame-sheen → inner highlight, slides against the morph
//        .eyes → blinks (omitted for the celebrating mood, whose eyes are stars)
//  The four waver silhouettes in style.css are derived from FLAME below and share
//  its exact command structure (M · C · C · C · C · Z) — that is what lets the
//  browser interpolate `d`. Change FLAME and those four must be re-derived.
//

type RGB = [number, number, number];

// Palette — exact RGB from HunchTheme.Palette (0..1 floats × 255).
const PALETTE = {
  solved: [77, 158, 71] as RGB, // verdant green
  boiling: [232, 66, 54] as RGB, // ember red
  hot: [237, 107, 46] as RGB, // coral
  warm: [242, 166, 36] as RGB, // amber
  cool: [33, 161, 140] as RGB, // teal
  cold: [89, 189, 181] as RGB, // mint-teal
  freezing: [69, 133, 230] as RGB, // glacier blue
  keeper: [125, 92, 235] as RGB, // keeper violet — Wick's resting colour
  neutral: [120, 122, 134] as RGB, // deadpan grey ("Won't say" / unknown word)
};

function clamp01(w: number): number {
  return Math.max(0, Math.min(1, w));
}

function rgb([r, g, b]: RGB): string {
  return `rgb(${r}, ${g}, ${b})`;
}
function rgba([r, g, b]: RGB, a: number): string {
  return `rgba(${r}, ${g}, ${b}, ${a})`;
}
/** Blend a colour toward white by fraction `f` (0..1) — for the body's top highlight. */
function lighten([r, g, b]: RGB, f: number): string {
  const m = (v: number) => Math.round(v + (255 - v) * f);
  return `rgb(${m(r)}, ${m(g)}, ${m(b)})`;
}

/** Temperature band for a closeness score (0..100) — mirrors HunchTheme.color(for:). */
function band(score: number): RGB {
  if (score >= 100) return PALETTE.solved;
  if (score >= 60) return PALETTE.boiling;
  if (score >= 45) return PALETTE.hot;
  if (score >= 30) return PALETTE.warm;
  if (score >= 18) return PALETTE.cool;
  if (score >= 8) return PALETTE.cold;
  return PALETTE.freezing;
}

/** Heat word — mirrors HunchTheme.label(for:). */
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

// ── the mascot ──────────────────────────────────────────────────────────────

/** Wick's expression, mapped from the warmth band — mirrors KeeperMood.forScore. */
type Mood =
  | "idle"
  | "freezing"
  | "cold"
  | "warm"
  | "hot"
  | "boiling"
  | "celebrating"
  | "unamused";

function moodFor(opts: { score: number | null; neutral?: boolean }): Mood {
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

function bodyRGB(opts: { score: number | null; neutral?: boolean }): RGB {
  if (opts.neutral) return PALETTE.neutral;
  if (opts.score === null) return PALETTE.keeper;
  return band(opts.score);
}

// iOS KeeperFlameShape ported to a 120×128 viewBox: a teardrop flame that fans wide
// at the belly (x 5→115) and tapers to a soft tip at y≈8. Keep in lockstep with
// KeeperFlameShape.path(in:) in KeeperView.swift.
const FLAME =
  "M60 122 C20 120 5 99 5 71 C5 36 32 19 60 8 C88 19 115 36 115 71 C115 99 100 120 60 122 Z";

/** A small n-pointed star path (celebrating eyes + solve sparkles). */
function starPath(cx: number, cy: number, r: number): string {
  let d = "";
  for (let i = 0; i < 10; i++) {
    const rad = i % 2 ? r * 0.45 : r;
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    d += `${i ? "L" : "M"}${(cx + Math.cos(a) * rad).toFixed(1)} ${(cy + Math.sin(a) * rad).toFixed(1)} `;
  }
  return `${d}Z`;
}

/**
 * The Wick mascot as an SVG string. `score` (0..100) sets colour + expression; pass
 * null for the resting purple Wick, or `neutral: true` for the deadpan grey Wick
 * (rejected/invalid input — "Won't say" / unknown word). `size` in px. Mascots at or
 * above 72px come alive (bob · flicker · blink); smaller inline ones stay calm.
 */
export function mascotSVG(opts: {
  score: number | null;
  size?: number;
  id?: string;
  neutral?: boolean;
}): string {
  const size = opts.size ?? 132;
  const id = opts.id ?? "wick";
  const mood = moodFor(opts);
  const c = bodyRGB(opts);
  const top = lighten(c, 0.34);
  const bot = rgb(c);
  const W = "#ffffff";
  const eyeY = 74;
  const lx = 47;
  const rx = 73;
  const my = 93;

  // Eyes — white, mood-driven (mirrors KeeperView.moodEye).
  let eyes: string;
  if (mood === "celebrating") {
    eyes = `<path d="${starPath(lx, eyeY, 8)}" fill="${W}"/><path d="${starPath(rx, eyeY, 8)}" fill="${W}"/>`;
  } else if (mood === "unamused") {
    // Flat "-_-" dashes.
    eyes = `<rect x="${lx - 8}" y="${eyeY - 2}" width="16" height="4" rx="2" fill="${W}" opacity="0.92"/>
    <rect x="${rx - 8}" y="${eyeY - 2}" width="16" height="4" rx="2" fill="${W}" opacity="0.92"/>`;
  } else if (mood === "freezing") {
    // Squint.
    eyes = `<rect x="${lx - 6.5}" y="${eyeY - 2.5}" width="13" height="5" rx="2.5" fill="${W}"/>
    <rect x="${rx - 6.5}" y="${eyeY - 2.5}" width="13" height="5" rx="2.5" fill="${W}"/>`;
  } else {
    const r = mood === "boiling" ? 7.6 : 6.6; // wide-eyed when boiling
    eyes = `<circle cx="${lx}" cy="${eyeY}" r="${r}" fill="${W}"/><circle cx="${rx}" cy="${eyeY}" r="${r}" fill="${W}"/>
    <circle cx="${lx - 1.6}" cy="${eyeY - 1.8}" r="1.8" fill="${bot}" opacity="0.5"/>
    <circle cx="${rx - 1.6}" cy="${eyeY - 1.8}" r="1.8" fill="${bot}" opacity="0.5"/>`;
  }

  // Mouth — white, mood-driven (mirrors KeeperView.mouth).
  let mouth: string;
  if (mood === "celebrating" || mood === "boiling") {
    mouth = `<path d="M50 ${my} A10 10 0 0 0 70 ${my} Z" fill="${W}" opacity="0.92"/>`; // open, delighted
  } else if (mood === "hot" || mood === "warm" || mood === "idle") {
    mouth = `<path d="M50 ${my} Q60 ${my + 8} 70 ${my}" stroke="${W}" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.92"/>`; // smile
  } else if (mood === "unamused") {
    mouth = `<path d="M52 ${my + 1} L68 ${my + 1}" stroke="${W}" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.8"/>`; // flat
  } else {
    mouth = `<path d="M50 ${my + 5} Q60 ${my - 4} 70 ${my + 5}" stroke="${W}" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.9"/>`; // frown (cold)
  }

  // Star eyes shouldn't blink (they twinkle instead); everything else can.
  const eyesCls = mood === "celebrating" ? "" : ' class="eyes"';
  const sparkles =
    mood === "celebrating"
      ? `<g fill="${rgb(PALETTE.warm)}">
      <path class="spark" style="animation-delay:0s" d="${starPath(18, 42, 4)}"/>
      <path class="spark" style="animation-delay:.4s" d="${starPath(104, 38, 3.4)}"/>
      <path class="spark" style="animation-delay:.8s" d="${starPath(100, 88, 3)}"/>
      <path class="spark" style="animation-delay:.2s" d="${starPath(16, 86, 3)}"/>
    </g>`
      : "";
  // Big mascots breathe; tiny inline ones (opponent strip, Keeper badge) stay still.
  const alive = size >= 72 ? " alive" : "";

  return `
  <svg class="wick-mascot${alive}" width="${size}" height="${size}" viewBox="0 0 120 128" role="img" aria-label="Wick">
    <defs>
      <linearGradient id="body-${id}" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="${top}"/>
        <stop offset="55%" stop-color="${bot}"/>
        <stop offset="100%" stop-color="${bot}"/>
      </linearGradient>
      <filter id="soft-${id}" x="-40%" y="-40%" width="180%" height="180%">
        <feGaussianBlur stdDeviation="4"/>
      </filter>
    </defs>
    <g class="wick-float"><g class="wick-sway">
      <g class="flame-core">
        <path class="flame-glow" d="${FLAME}" fill="${bot}" opacity="0.28" filter="url(#soft-${id})"
          transform="translate(60 122) scale(1.06) translate(-60 -122)"/>
        <path class="flame-body" d="${FLAME}" fill="url(#body-${id})"/>
        <ellipse class="flame-sheen" cx="53" cy="54" rx="15" ry="23" fill="#ffffff" opacity="0.15" filter="url(#soft-${id})"/>
      </g>
      ${sparkles}
      <g${eyesCls}>${eyes}</g>
      ${mouth}
    </g></g>
  </svg>`;
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
