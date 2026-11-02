//
//  revealcard.ts — the semantic map, and the spoiler-free image you can post.
//
//  PLAN_3.2 calls the shareable map "the second viral surface" and "the single
//  biggest miss vs. the original spec". This is it. The map plays the role
//  Wordle's grid plays, except it is unique per player and per puzzle: where you
//  wandered in meaning-space on the way to the word.
//
//  ONE renderer, two dresses. The on-screen map and the share card come out of
//  the same mapMarkup() so they can never drift:
//
//    on screen  — responsive, dots animate in, the word is revealed at centre
//    share card — fixed size, opaque background, branded, and SPOILER-FREE:
//                 the word and every guess label are withheld
//
//  Spoiler-freedom is enforced in one place — the `spoiler` flag — rather than by
//  remembering to strip things at the call site. Two things are withheld:
//    1. the solved word at the centre (a "?" marker takes its place)
//    2. the text labels on the hottest guesses
//  The dot POSITIONS stay: they are the interesting part, and a dot at radius
//  0.4 tells a reader nothing about which word it was. The winning guess is
//  already excluded by construction — mapMarkup drops score >= 100.
//

import { t } from "../i18n.ts";
import type { RevealPointDTO } from "../net/api.ts";
import { PALETTE, wickStillMarkup } from "./wickface.ts";

const FONT = "ui-rounded, -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif";

export const CARD_W = 540;
export const CARD_H = 640;
/** 3.8: the postable card is square. */
export const CARD_SIZE = 600;

function esc(s: string): string {
  return s.replace(/[&<>"]/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[ch] ?? ch));
}

/** Temperature colour for a 0..100 closeness — mirrors HunchTheme.color(for:). */
export function revealBandColor(s: number): string {
  return s >= 100 ? "#4D9E47" : s >= 60 ? "#E84236" : s >= 45 ? "#ED6B2E"
       : s >= 30 ? "#F2A624" : s >= 18 ? "#21A18C" : s >= 8 ? "#59BDB5" : "#4585E6";
}

const BANDS = [
  { f: 0.30, c: "#E84236", l: "Boiling" }, { f: 0.48, c: "#ED6B2E", l: "Hot" },
  { f: 0.64, c: "#F2A624", l: "Warm" },    { f: 0.78, c: "#21A18C", l: "Cool" },
  { f: 0.90, c: "#59BDB5", l: "Cold" },    { f: 1.00, c: "#4585E6", l: "Freezing" },
];

interface MapOpts {
  /** Centre of the map in user units. */
  cx: number; cy: number;
  /** Radius of the outermost (Freezing) ring. */
  r: number;
  /** The solved word. Ignored entirely when `spoiler` is true. */
  word?: string;
  /** Withhold the word and every guess label. */
  spoiler?: boolean;
  /** Stagger the dots in. Only meaningful on screen — a rasterised SVG has no
   *  stylesheet, so the card is always static. */
  animate?: boolean;
  /** Ring stroke alpha. The on-screen map sits on a busy backdrop and wants
   *  these whisper-faint; the card is a flat field at 2x, where the same value
   *  disappears entirely. */
  ringOpacity?: number;
  /** Label every band, or only the outer/middle/inner three. Six centred labels
   *  stack into what reads as a vertical list once the map is card-sized. */
  sparseLabels?: boolean;
}

/** The map itself as inner markup, so callers can wrap it however they like. */
function mapMarkup(points: RevealPointDTO[], o: MapOpts): string {
  const { cx, cy, r, spoiler = false, animate = false, ringOpacity = 0.18, sparseLabels = false } = o;
  const sx = (p: RevealPointDTO) => (cx + p.x * r).toFixed(1);
  const sy = (p: RevealPointDTO) => (cy + p.y * r).toFixed(1);

  // Boiling / Warm / Freezing — the inner, middle and outer band, enough to read
  // the gradient without six labels queueing up the vertical centreline.
  const SPARSE = new Set(["Boiling", "Warm", "Freezing"]);
  const rings = BANDS.map((b) => {
    const ring = `<circle cx="${cx}" cy="${cy}" r="${(b.f * r).toFixed(1)}" fill="none" stroke="${b.c}" stroke-opacity="${ringOpacity}" stroke-width="1" stroke-dasharray="2 4"/>`;
    if (sparseLabels && !SPARSE.has(b.l)) return ring;
    return ring +
      `<text x="${cx}" y="${(cy - b.f * r + 11).toFixed(1)}" text-anchor="middle" fill="${b.c}" fill-opacity="0.7" font-size="9" font-weight="700">${b.l.toUpperCase()}</text>`;
  }).join("");

  // score >= 100 is the answer itself — never plotted, on screen or in the card.
  const dotPts = points.filter((p) => p.score < 100);

  const pathD = points.map((p, i) => (i ? "L" : "M") + sx(p) + " " + sy(p)).join(" ");
  const path = points.length > 1
    ? `<path d="${pathD}" fill="none" stroke="rgba(255,255,255,0.22)" stroke-width="2" stroke-linecap="round" stroke-dasharray="4 5"/>`
    : "";

  // Only the six hottest guesses are ever labelled, and never in spoiler mode.
  const labelled = spoiler
    ? new Set<string>()
    : new Set([...dotPts].sort((a, b) => b.score - a.score).slice(0, 6).map((p) => p.word));

  const dots = dotPts.map((p, i) => {
    const c = revealBandColor(p.score);
    const label = labelled.has(p.word)
      ? `<text x="${sx(p)}" y="${(cy + p.y * r - 11).toFixed(1)}" text-anchor="middle" fill="${c}" font-size="10" font-weight="700" paint-order="stroke" stroke="rgba(8,10,15,.85)" stroke-width="3" stroke-linejoin="round">${esc(p.word)}</text>`
      : "";
    const cls = animate ? ` class="rv-dot" style="animation-delay:${(i * 0.05).toFixed(2)}s"` : "";
    return `<circle${cls} cx="${sx(p)}" cy="${sy(p)}" r="7" fill="${c}" stroke="rgba(8,10,15,.85)" stroke-width="2"/>${label}`;
  }).join("");

  const glow = `<circle cx="${cx}" cy="${cy}" r="34" fill="url(#rvglow)"/>`;

  // The centre is where the spoiler would be. Withhold it, and the image becomes
  // a puzzle instead of an answer.
  const centre = spoiler
    ? `<circle cx="${cx}" cy="${cy}" r="13" fill="none" stroke="#4D9E47" stroke-width="2.5"/>` +
      `<text x="${cx}" y="${cy + 5.5}" text-anchor="middle" fill="#4D9E47" font-size="16" font-weight="800">?</text>`
    : `<text x="${cx}" y="${cy - 1}" text-anchor="middle" fill="#4D9E47" font-size="15" font-weight="800">${esc((o.word ?? "").toUpperCase())}</text>` +
      `<text x="${cx}" y="${cy + 11}" text-anchor="middle" fill="#9aa4b2" font-size="8" font-weight="700">${esc(t("revealTheWord"))}</text>`;

  return glow + rings + path + dots + centre;
}

const GLOW_DEF =
  `<defs><radialGradient id="rvglow">` +
  `<stop offset="0%" stop-color="rgba(77,158,71,.5)"/><stop offset="100%" stop-color="rgba(77,158,71,0)"/>` +
  `</radialGradient></defs>`;

/** The map as shown on the Reveal screen: responsive, animated, word revealed. */
export function revealSVG(points: RevealPointDTO[], word: string): string {
  return `<svg viewBox="0 0 400 400" width="100%" role="img" aria-label="Semantic map of your guesses">` +
    GLOW_DEF +
    mapMarkup(points, { cx: 200, cy: 200, r: 170, word, animate: true }) +
    `</svg>`;
}

export interface CardMeta {
  /** Only used to name the downloaded file. */
  puzzleNumber: number;
  /** "WICK DAILY #1436" or "WICK PRACTICE". Already localised. */
  brand: string;
  /** Number of guesses. */
  guesses: number;
  /** Solved, or given up. */
  solved: boolean;
  /** Every scored guess, oldest to newest, as 0...100 warmth (100 = the word). */
  heat: number[];
  /** Bare host, e.g. "guesswick.com". */
  host: string;
}

/** One node of the heat trail: color, size and a ring that mark the band, so
 *  the trail reads without color too. */
export interface TrailNode { score: number; color: string; r: number; ring: boolean }

/** Pick 5 to 8 nodes from the real guesses: the first, the last (always kept,
 *  so a solve ends green), and the ones in between spread evenly. Fewer than
 *  five guesses show as they are. */
export function heatTrail(heat: number[]): TrailNode[] {
  const picked: number[] = [];
  if (heat.length <= 8) picked.push(...heat);
  else {
    const n = 8;
    for (let i = 0; i < n; i++) picked.push(heat[Math.round((i * (heat.length - 1)) / (n - 1))]!);
    picked[n - 1] = heat[heat.length - 1]!;
  }
  return picked.map((score) => {
    const band = score >= 100 ? 6 : score >= 60 ? 5 : score >= 45 ? 4 : score >= 30 ? 3 : score >= 18 ? 2 : score >= 8 ? 1 : 0;
    return { score, color: revealBandColor(score), r: 5 + band * 1.3, ring: score >= 100 };
  });
}

/**
 * The postable card (3.8): brand line, the guess count, the heat trail, and
 * the solved green Wick on the right. Standalone: carries its own xmlns,
 * background and font stack, because once rasterised it has no page and no
 * stylesheet to inherit. The word is never on it.
 */
export function shareCardSVG(m: CardMeta): string {
  const S = CARD_SIZE, margin = S * 0.08;
  const left = margin, textW = S * 0.44;
  const nodes = heatTrail(m.heat);
  const wickColor = m.solved ? PALETTE.solved : PALETTE.neutral;
  const wickFace = m.solved ? "sly" : "calm";
  const wickSize = S * 0.50;
  const wickX = S - margin - wickSize + 10, wickY = S * 0.24;
  // Heat trail: nodes spaced across the text column, joined by a faint line.
  const trailY = S * 0.56;
  const gapX = nodes.length > 1 ? Math.min(28, (textW - 40) / (nodes.length - 1)) : 0;
  const trail = nodes.map((nd, i) => {
    const x = left + 8 + i * gapX;
    const ring = nd.ring ? `<circle cx="${x}" cy="${trailY}" r="${(nd.r + 5).toFixed(1)}" fill="none" stroke="${nd.color}" stroke-width="2" opacity="0.8"/>` : "";
    return `<circle cx="${x}" cy="${trailY}" r="${nd.r.toFixed(1)}" fill="${nd.color}"/>${ring}`;
  }).join("");
  const trailLine = nodes.length > 1
    ? `<line x1="${left + 8}" y1="${trailY}" x2="${(left + 8 + (nodes.length - 1) * gapX).toFixed(1)}" y2="${trailY}" stroke="rgba(255,255,255,0.14)" stroke-width="2"/>`
    : "";
  const result = m.solved ? `${m.guesses} ${esc(t("cardGuesses", m.guesses))}` : esc(t("revealShareUnsolved")).toUpperCase();
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 ${S} ${S}" font-family="${FONT}">
  <defs>
    <radialGradient id="card-bg" cx="72%" cy="42%" r="70%"><stop offset="0%" stop-color="#2a1d4e"/><stop offset="100%" stop-color="#120c22"/></radialGradient>
    <radialGradient id="card-glow"><stop offset="0%" stop-color="rgba(77,158,71,0.45)"/><stop offset="100%" stop-color="rgba(77,158,71,0)"/></radialGradient>
  </defs>
  <rect width="${S}" height="${S}" fill="url(#card-bg)"/>
  <circle cx="${wickX + wickSize / 2}" cy="${wickY + wickSize * 0.55}" r="${wickSize * 0.7}" fill="${m.solved ? "url(#card-glow)" : "none"}"/>
  <text x="${left}" y="${margin + 18}" fill="#b9a8ff" font-size="17" font-weight="800" letter-spacing="2.5">${esc(m.brand)}</text>
  <text x="${left}" y="${margin + 86}" fill="#fff6ea" font-size="${m.solved ? 56 : 40}" font-weight="900" letter-spacing="-1">${result}</text>
  ${trailLine}${trail}
  <text x="${left}" y="${S - margin - 30}" fill="#d9d0f0" font-size="19" font-weight="700">${esc(t("cardTease"))}</text>
  <text x="${left}" y="${S - margin}" fill="#b9a8ff" font-size="17" font-weight="800">${esc(m.host)}</text>
  <svg x="${wickX}" y="${wickY}" width="${wickSize}" height="${wickSize * 128 / 120}" viewBox="0 0 120 128" overflow="visible">${wickStillMarkup(wickFace, wickColor, m.solved ? "card-s" : "card-u", { sparks: m.solved })}</svg>
</svg>`;
}

/**
 * Rasterise a standalone SVG string to PNG.
 *
 * A data: URL is used rather than a blob: URL — Safari has historically been
 * unreliable about blob-backed SVG images — and encodeURIComponent rather than
 * btoa, because guesses can be non-ASCII in four of the five languages.
 */
export async function svgToPng(svg: string, w: number, h: number, scale = 2): Promise<Blob | null> {
  const img = new Image();
  const loaded = await new Promise<boolean>((resolve) => {
    img.onload = () => resolve(true);
    img.onerror = () => resolve(false);
    img.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svg);
  });
  if (!loaded) return null;

  const canvas = document.createElement("canvas");
  canvas.width = Math.round(w * scale);
  canvas.height = Math.round(h * scale);
  const ctx = canvas.getContext("2d");
  if (!ctx) return null;
  ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
  return new Promise<Blob | null>((resolve) => canvas.toBlob((b) => resolve(b), "image/png"));
}

export type ShareOutcome = "shared" | "downloaded" | "cancelled" | "failed";

/**
 * Post the card. Native share sheet with the file attached where that exists
 * (iOS Safari, Android Chrome); otherwise download the PNG and put the text on
 * the clipboard, which is the best a desktop browser can do.
 */
export async function shareRevealCard(
  meta: CardMeta,
  text: string,
): Promise<ShareOutcome> {
  const png = await svgToPng(shareCardSVG(meta), CARD_SIZE, CARD_SIZE, 2);
  if (!png) return "failed";

  const file = new File([png], `wick-${meta.puzzleNumber}.png`, { type: "image/png" });
  const nav = navigator as Navigator & { canShare?: (d?: ShareData) => boolean };
  if (typeof nav.share === "function" && nav.canShare?.({ files: [file] })) {
    try {
      await nav.share({ files: [file], text });
      return "shared";
    } catch (e) {
      if ((e as { name?: string }).name === "AbortError") return "cancelled";
      // fall through to the download path
    }
  }

  try {
    const url = URL.createObjectURL(png);
    const a = document.createElement("a");
    a.href = url;
    a.download = file.name;
    document.body.append(a);
    a.click();
    a.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 10_000);
    try { await navigator.clipboard.writeText(text); } catch { /* clipboard denied — the PNG still saved */ }
    return "downloaded";
  } catch {
    return "failed";
  }
}
