//
//  warmth.ts — PLACEHOLDER hot/cold warmth for the web client (milestone 1 only).
//
//  ⚠️  This is NOT real warmth. The web client does not know the secret word (by
//  design — the server holds it), and it has no semantic engine, so it CANNOT
//  compute genuine hot/cold closeness. This module fabricates a plausible-looking
//  climbing value purely so the UI has something to show and the opponent strip
//  moves while we build the shell.
//
//  Milestone 2 replaces this entirely: the SERVER computes warmth (design note
//  docs/wick/CROSS_PLATFORM.md, WD-1/WD-2) and sends it back in `state`, at which
//  point the client stops fabricating and just renders the server's value. The
//  UI labels this as a placeholder so nothing dishonest is shown (C9).
//
//  Deterministic per (word, secret-less) so the same guess looks stable within a
//  match; trends upward with guess count so it feels like warming up.
//

/** Stable 0..1 hash of a string. */
function hash01(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return ((h >>> 0) % 100000) / 100000;
}

/**
 * Placeholder warmth for a guess. `guessNumber` is 1-based. Produces a value that
 * jitters per word but drifts upward as the player makes more guesses, so the bar
 * climbs believably. NEVER returns 1 (only a real solve is maximal warmth, and
 * the server decides solves).
 */
export function placeholderWarmth(word: string, guessNumber: number): number {
  const base = hash01(word.toLowerCase()); // 0..1 per-word jitter
  const drift = 1 - Math.exp(-guessNumber / 8); // 0 → ~0.9 as guesses accrue
  const w = 0.15 * base + 0.8 * drift;
  return Math.max(0, Math.min(0.95, w));
}

export const WARMTH_IS_PLACEHOLDER = true;
