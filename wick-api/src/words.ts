//
//  words.ts — the multiplayer match word pool.
//
//  IMPORTANT (C1 moat): these are words the SERVER may hold for live-match
//  adjudication. They are NOT the single-player daily words — single-player never
//  touches a server, and no daily word/streak/guess is here. This is a small,
//  self-contained pool the matchmaker draws a secret from per match. It is
//  intentionally a placeholder: before launch, align this pool with the app's
//  curated multiplayer word set (and, if the app resolves the board from a word
//  *index*, agree an index↔word contract). Flagged — the exact pool source is a
//  handoff item, not fixed by the SRS.
//

/** Placeholder multiplayer word pool. Replace/extend before launch. */
export const MATCH_WORDS: readonly string[] = [
  "ember", "flame", "spark", "cinder", "kindle", "hearth", "beacon", "lantern",
  "candle", "torch", "glow", "smoke", "ash", "coal", "blaze", "flicker",
  "warmth", "signal", "compass", "anchor", "harbor", "meadow", "river", "summit",
  "orchard", "cabin", "bridge", "garden", "market", "harvest", "willow", "cedar",
];

/**
 * Deterministic-friendly word provider. Pass an `index()` that returns a
 * non-negative integer to pick from the pool (the server injects a random one;
 * tests inject a counter). Defaults to a simple rotating counter.
 */
export function makeWordProvider(index?: () => number): () => string {
  let i = 0;
  const pick = index ?? (() => i++);
  return () => {
    const n = Math.abs(Math.trunc(pick())) % MATCH_WORDS.length;
    return MATCH_WORDS[n]!;
  };
}
