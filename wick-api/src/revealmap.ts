//
//  revealmap.ts — server-side layout engine for "The Reveal" (3.2 web).
//
//  Mirrors Hunch/Engine/RevealMap.swift EXACTLY (validated against the same test
//  suite): radius from the 0..100 warmth score (concentric rings == the HunchTheme
//  heat bands), angle from a classical-MDS projection (Jacobi eigen) of the guesses'
//  pairwise similarity, with a deterministic rotation + mirror so the same round
//  always draws the same map. The browser has no embedding engine, so the server
//  computes this from the Gemini vectors it already holds and returns the points.
//
//  Keep in lockstep with RevealMap.swift.
//

export interface RevealPoint {
  word: string;
  score: number;  // 0..100 (the warmth the player saw)
  radius: number; // 0 (center / hot) .. 1 (rim / cold) — from score only
  angle: number;  // radians — from the 2D projection
  x: number;      // radius * cos(angle)
  y: number;      // radius * sin(angle)
}

const PI = Math.PI;

function cosine(a: number[], b: number[]): number {
  const n = Math.min(a.length, b.length);
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < n; i++) {
    const x = a[i]!, y = b[i]!;
    dot += x * y; na += x * x; nb += y * y;
  }
  if (na === 0 || nb === 0) return 0;
  return dot / (Math.sqrt(na) * Math.sqrt(nb));
}

/** Map a 0..100 warmth score to a 0..1 radius (higher score → nearer the center).
 *  Breakpoints sit on the HunchTheme band thresholds so the rings ARE the heat bands. */
export function radiusForScore(score: number): number {
  const s = Math.max(0, Math.min(100, score));
  const pts: Array<[number, number]> = [[100, 0], [60, 0.30], [45, 0.48],
                                         [30, 0.64], [18, 0.78], [8, 0.90], [0, 1]];
  for (let k = 0; k < pts.length - 1; k++) {
    const hi = pts[k]!, lo = pts[k + 1]!;
    if (s <= hi[0] && s >= lo[0]) {
      const t = hi[0] === lo[0] ? 0 : (hi[0] - s) / (hi[0] - lo[0]);
      return hi[1] + t * (lo[1] - hi[1]);
    }
  }
  return 1;
}

/** Jacobi eigenvalue algorithm for a symmetric matrix. */
function jacobiEigen(input: number[][]): { vals: number[]; vecs: number[][] } {
  const n = input.length;
  const a = input.map((r) => r.slice());
  const v: number[][] = Array.from({ length: n }, (_, i) =>
    Array.from({ length: n }, (_, j) => (i === j ? 1 : 0)));
  if (n === 1) return { vals: [a[0]![0]!], vecs: v };

  for (let it = 0; it < 100; it++) {
    let p = 0, q = 1, mx = 0;
    for (let i = 0; i < n; i++) {
      const ai = a[i]!;
      for (let j = i + 1; j < n; j++) {
        if (Math.abs(ai[j]!) > mx) { mx = Math.abs(ai[j]!); p = i; q = j; }
      }
    }
    if (mx < 1e-12) break;

    const ap = a[p]!, aq = a[q]!;
    const app = ap[p]!, aqq = aq[q]!, apq = ap[q]!;
    const phi = 0.5 * Math.atan2(2 * apq, aqq - app);
    const c = Math.cos(phi), s = Math.sin(phi);

    for (let i = 0; i < n; i++) {
      const ai = a[i]!;
      const aip = ai[p]!, aiq = ai[q]!;
      ai[p] = c * aip - s * aiq;
      ai[q] = s * aip + c * aiq;
    }
    for (let i = 0; i < n; i++) {
      const api = ap[i]!, aqi = aq[i]!;
      ap[i] = c * api - s * aqi;
      aq[i] = s * api + c * aqi;
    }
    for (let i = 0; i < n; i++) {
      const vi = v[i]!;
      const vip = vi[p]!, viq = vi[q]!;
      vi[p] = c * vip - s * viq;
      vi[q] = s * vip + c * viq;
    }
  }
  const vals = Array.from({ length: n }, (_, i) => a[i]![i]!);
  return { vals, vecs: v };
}

/** Classical MDS to 2D via double-centering + Jacobi eigen-decomposition. */
function mds2D(dist: number[][]): number[][] {
  const n = dist.length;
  const d2 = dist.map((r) => r.map((x) => x * x));
  const rowMean = new Array<number>(n).fill(0);
  let grand = 0;
  for (let i = 0; i < n; i++) {
    const row = d2[i]!;
    for (let j = 0; j < n; j++) rowMean[i] = rowMean[i]! + row[j]!;
    rowMean[i] = rowMean[i]! / n; grand += rowMean[i]!;
  }
  grand /= n;
  const b: number[][] = Array.from({ length: n }, () => new Array<number>(n).fill(0));
  for (let i = 0; i < n; i++) {
    const bi = b[i]!, d2i = d2[i]!;
    for (let j = 0; j < n; j++) bi[j] = -0.5 * (d2i[j]! - rowMean[i]! - rowMean[j]! + grand);
  }

  const { vals, vecs } = jacobiEigen(b);
  const order = Array.from({ length: n }, (_, i) => i).sort((x, y) => vals[y]! - vals[x]!);
  const k0 = order[0]!, k1 = n > 1 ? order[1]! : order[0]!;
  const s0 = Math.sqrt(Math.max(0, vals[k0]!)), s1 = Math.sqrt(Math.max(0, vals[k1]!));
  const coords: number[][] = Array.from({ length: n }, () => [0, 0]);
  for (let i = 0; i < n; i++) {
    const vi = vecs[i]!;
    coords[i] = [vi[k0]! * s0, vi[k1]! * s1];
  }
  return coords;
}

/** Angles from the 2D coords with a deterministic rotation + mirror (hottest to top,
 *  second-hottest on the right); collapsed projections fall back to even spacing. */
function canonicalAngles(coords: number[][], scores: number[]): number[] {
  const n = coords.length;
  const ang = coords.map((c) => Math.atan2(c[1]!, c[0]!));

  let spread = 0;
  for (const c of coords) spread = Math.max(spread, Math.sqrt(c[0]! * c[0]! + c[1]! * c[1]!));
  if (spread < 1e-9) {
    for (let i = 0; i < n; i++) ang[i] = -PI / 2 + (2 * PI * i) / n;
    return ang;
  }

  let hot = 0;
  for (let i = 1; i < n; i++) if (scores[i]! > scores[hot]!) hot = i;

  let second = -1;
  for (let i = 0; i < n; i++) {
    if (i === hot) continue;
    if (second < 0 || scores[i]! > scores[second]!) second = i;
  }
  if (second >= 0) {
    let rel = ang[second]! - ang[hot]!;
    while (rel <= -PI) rel += 2 * PI;
    while (rel > PI) rel -= 2 * PI;
    if (rel < 0) for (let i = 0; i < n; i++) ang[i] = 2 * ang[hot]! - ang[i]!;
  }

  const rot = -PI / 2 - ang[hot]!;
  for (let i = 0; i < n; i++) {
    let a = ang[i]! + rot;
    while (a <= -PI) a += 2 * PI;
    while (a > PI) a -= 2 * PI;
    ang[i] = a;
  }
  return ang;
}

function core(words: string[], scores: number[], dist: number[][]): RevealPoint[] {
  const n = words.length;
  if (n === 0) return [];
  const angles = n === 1 ? [-PI / 2] : canonicalAngles(mds2D(dist), scores);
  const out: RevealPoint[] = [];
  for (let i = 0; i < n; i++) {
    const r = radiusForScore(scores[i]!);
    const a = angles[i]!;
    out.push({ word: words[i]!, score: scores[i]!, radius: r, angle: a, x: r * Math.cos(a), y: r * Math.sin(a) });
  }
  return out;
}

/** Build the layout from per-guess vectors. A null vector (unknown word) is treated
 *  as maximally far from every other guess. */
export function layout(words: string[], scores: number[], vectors: (number[] | null)[]): RevealPoint[] {
  const n = words.length;
  const d: number[][] = Array.from({ length: n }, () => new Array<number>(n).fill(0));
  for (let i = 0; i < n; i++) {
    const vi = vectors[i] ?? null;
    const row = d[i]!;
    for (let j = i + 1; j < n; j++) {
      const vj = vectors[j] ?? null;
      const dist = vi && vj ? Math.max(0, 1 - cosine(vi, vj)) : 1;
      row[j] = dist; d[j]![i] = dist;
    }
  }
  return core(words, scores, d);
}
