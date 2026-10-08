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

/** Wick's dark card, so the PNG looks the same wherever it is posted. */
const INK = "#0d0a14";
const FONT = "ui-rounded, -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif";

export const CARD_W = 540;
export const CARD_H = 640;

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
  /** Orange chip under the wordmark: "#1355", or the word for Practice. */
  badge: string;
  /** Shown beside the badge, e.g. "solved in 7". Already localised. */
  resultLine: string;
  /** Bare host, e.g. "guesswick.com". */
  host: string;
}

/**
 * The postable card. Standalone: carries its own xmlns, background and font
 * stack, because once rasterised it has no page and no stylesheet to inherit.
 */
export function shareCardSVG(points: RevealPointDTO[], m: CardMeta): string {
  const cx = CARD_W / 2;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${CARD_W}" height="${CARD_H}" viewBox="0 0 ${CARD_W} ${CARD_H}" font-family="${FONT}">
  <rect width="${CARD_W}" height="${CARD_H}" fill="${INK}"/>
  <rect x="10" y="10" width="${CARD_W - 20}" height="${CARD_H - 20}" rx="28" fill="none" stroke="rgba(255,255,255,0.07)" stroke-width="1"/>
  ${GLOW_DEF}
  <text x="${cx}" y="62" text-anchor="middle" fill="#f5ede2" font-size="38" font-weight="800" letter-spacing="-0.5">Wick</text>
  <text x="${cx}" y="92" text-anchor="middle" font-size="16" font-weight="700">
    <tspan fill="#ED6B2E">${esc(m.badge)}</tspan><tspan fill="#6f7a89"> · </tspan><tspan fill="#9aa4b2">${esc(m.resultLine)}</tspan>
  </text>
  ${mapMarkup(points, { cx, cy: 340, r: 186, spoiler: true, ringOpacity: 0.38, sparseLabels: true })}
  <text x="${cx}" y="578" text-anchor="middle" fill="#6f7a89" font-size="13" font-weight="600">${esc(t("revealShareTease"))}</text>
  <text x="${cx}" y="606" text-anchor="middle" fill="#ED6B2E" font-size="15" font-weight="800">${esc(m.host)}</text>
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
  points: RevealPointDTO[],
  meta: CardMeta,
  text: string,
): Promise<ShareOutcome> {
  const png = await svgToPng(shareCardSVG(points, meta), CARD_W, CARD_H, 2);
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
