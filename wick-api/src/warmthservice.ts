//
//  warmthservice.ts — server-authoritative hot/cold "warmth" for a guess.
//
//  Turns a (secret, guess) pair into a 0..100 closeness score, the same 0..100
//  scale the client's band mapping (Freezing…Boiling…Solved) expects. Uses Gemini
//  embeddings (embeddings.ts) + cosine; exact matches short-circuit to 100; if
//  embeddings are unavailable it falls back to a rough lexical score so the game
//  still responds (clearly marked `source: "fallback"`).
//
//  Gemini cosine has a high baseline (unrelated words are ~0.4–0.6, not ~0 like
//  Apple's NLEmbedding), so cosine is rescaled through [LO, HI] → [0, 100]. Those
//  bounds are the calibration knobs (env WICK_WARMTH_LO / WICK_WARMTH_HI) — tune
//  them once real Gemini outputs are observed on Render. FLAG: defaults are an
//  initial guess, not yet calibrated against live data.
//

import { embed, cosine, hasEmbeddings, rankVocabEntries, LruCache } from "./embeddings.js";
import { normalizeWord } from "./room.js";
import { isRealWord } from "./dictionary.js";

// Calibration for gemini-embedding-001 + SEMANTIC_SIMILARITY: this model runs hot
// — unrelated words sit ~0.80, closely related ~0.87–0.94. So the useful window is
// [0.80, 0.96]. Tune via env (WICK_WARMTH_LO / WICK_WARMTH_HI) without a redeploy.
const LO = numEnv("WICK_WARMTH_LO", 0.8);
const HI = numEnv("WICK_WARMTH_HI", 0.96);

function numEnv(name: string, dflt: number): number {
  const v = Number(process.env[name]);
  return Number.isFinite(v) ? v : dflt;
}

function clamp01(x: number): number {
  return Math.max(0, Math.min(1, x));
}

export type WarmthSource = "exact" | "rank" | "embeddings" | "fallback";

export interface WarmthResult {
  /** 0..100 closeness. 100 only for an exact match. */
  score: number;
  source: WarmthSource;
  /** Raw cosine similarity when embeddings were used (for calibration). */
  cos?: number;
  /** Contexto rank in the iOS convention (1 = the answer, 2 = the closest
   *  guessable word) when source === "rank". Reveal "#N" at rank ≤ 100. */
  rank?: number;
}

// ── Contexto-style rank scoring ────────────────────────────────────────────────
// Sorted-desc cosines of a secret to the whole rank vocab, cached per secret (a
// live match reuses one secret for many guesses).
const secretRef = new LruCache<number[]>(200);

// Rank band cutoffs, in the iOS 1-based rank convention (rank 1 = the answer,
// rank 2 = the single closest guessable word). These MIRROR the iOS app's
// HunchTheme bands EXACTLY so live warmth reads identically to the single-player
// board — Boiling ≤25, Hot ≤100, Warm ≤400, Cool ≤1200, Cold beyond. Env-tunable
// so the feel can still be dialled against real games without a redeploy.
function rankEnv(name: string, dflt: number): number {
  const v = Number(process.env[name]);
  return Number.isFinite(v) && v > 0 ? v : dflt;
}
const R_BOILING = rankEnv("WICK_RANK_BOILING", 25);
const R_HOT = rankEnv("WICK_RANK_HOT", 100);
const R_WARM = rankEnv("WICK_RANK_WARM", 400);
const R_COOL = rankEnv("WICK_RANK_COOL", 1200);

/** Map an iOS-convention rank (1 = answer, 2 = closest guess) to a 0..99 score
 *  whose band matches HunchTheme.label EXACTLY (60..<100 Boiling, 45..<60 Hot,
 *  30..<45 Warm, 18..<30 Cool, 8..<18 Cold, else Freezing). This keeps the warmth
 *  ring, the fallback heat word, and the "#N" reveal all in agreement — and in
 *  agreement with the single-player board. */
export function rankToScore(rank: number, vocabSize: number): number {
  if (rank <= 1) return 99; // effectively the answer (an exact match scores 100 elsewhere)
  // [loRank, hiRank, scoreAtLo, scoreAtHi] — endpoints sit inside each label band.
  const tiers: Array<[number, number, number, number]> = [
    [2, R_BOILING, 92, 60], // Boiling
    [R_BOILING + 1, R_HOT, 59, 45], // Hot
    [R_HOT + 1, R_WARM, 44, 30], // Warm
    [R_WARM + 1, R_COOL, 29, 18], // Cool
  ];
  for (const [loR, hiR, sHi, sLo] of tiers) {
    if (rank <= hiR) {
      const t = Math.min(1, Math.max(0, (rank - loR) / Math.max(1, hiR - loR)));
      return Math.round(sHi - t * (sHi - sLo));
    }
  }
  // Cold / Freezing tail (rank > R_COOL): 17 sliding down toward 1.
  const t = Math.min(1, (rank - R_COOL) / Math.max(1, vocabSize - R_COOL));
  return Math.max(1, Math.round(17 - t * 16));
}

/** # of cosines in a descending-sorted list strictly greater than `cos`. */
export function rankFromCosines(sortedDesc: number[], cos: number): number {
  let lo = 0;
  let hi = sortedDesc.length;
  while (lo < hi) {
    const mid = (lo + hi) >> 1;
    if (sortedDesc[mid]! > cos) lo = mid + 1;
    else hi = mid;
  }
  return lo;
}

/** Cosines of the secret to every rank-vocab word, sorted high→low, EXCLUDING the
 *  secret and its morphological variants (substring either way) — matching the iOS
 *  engine so the rank number lines up. Cached per secret (a live match reuses one
 *  secret across many guesses). */
function secretCosinesDesc(secretVec: number[], secretKey: string): number[] {
  const cached = secretRef.get(secretKey);
  if (cached) return cached;
  const s = secretKey;
  const cs: number[] = [];
  for (const { word, vec } of rankVocabEntries()) {
    if (word && (word === s || word.includes(s) || s.includes(word))) continue;
    cs.push(cosine(secretVec, vec));
  }
  cs.sort((a, b) => b - a);
  secretRef.set(secretKey, cs);
  return cs;
}

/** Map a cosine similarity to a 0..99 score (99 cap: only exact match is 100). */
export function scoreFromCosine(cos: number, lo: number = LO, hi: number = HI): number {
  const t = clamp01((cos - lo) / (hi - lo || 1));
  return Math.min(99, Math.max(0, Math.round(t * 100)));
}

/** Rough lexical closeness (0..45), used only when embeddings are unavailable.
 *  Capped low so a fallback guess never masquerades as "hot". */
export function lexicalFallback(a: string, b: string): number {
  if (a === b) return 100;
  if (!a || !b) return 0;
  const setA = new Set(a);
  const setB = new Set(b);
  let shared = 0;
  for (const c of setA) if (setB.has(c)) shared++;
  const union = new Set([...a, ...b]).size || 1;
  const jaccard = shared / union;
  let p = 0;
  while (p < a.length && p < b.length && a[p] === b[p]) p++;
  const prefix = p / Math.max(a.length, b.length);
  return Math.round(Math.min(45, (0.5 * jaccard + 0.5 * prefix) * 60));
}

/**
 * Score how warm `guess` is to `secret`. `embedder` is injectable for tests.
 */
export async function warmthScore(
  secret: string,
  guess: string,
  embedder: (t: string) => Promise<number[] | null> = embed,
): Promise<WarmthResult> {
  const s = normalizeWord(secret);
  const g = normalizeWord(guess);
  if (!g) return { score: 0, source: "fallback" };
  if (s === g) return { score: 100, source: "exact" };

  if (hasEmbeddings()) {
    const [es, eg] = await Promise.all([embedder(s), embedder(g)]);
    if (es && eg) {
      const cos = cosine(es, eg);
      const round = Math.round(cos * 1000) / 1000;
      const vocab = rankVocabEntries();
      if (vocab.length > 0) {
        // Contexto-style: rank the guess against the reference vocabulary, then
        // convert to the iOS 1-based rank (answer = 1, closest guess = 2) so the
        // "#N" and heat band match the single-player board exactly.
        const closer = rankFromCosines(secretCosinesDesc(es, s), cos);
        const rank = closer + 2;
        return { score: rankToScore(rank, vocab.length), source: "rank", cos: round, rank };
      }
      // Vocab not warmed yet → absolute-cosine bands (graceful during boot).
      return { score: scoreFromCosine(cos), source: "embeddings", cos: round };
    }
  }
  return { score: lexicalFallback(s, g), source: "fallback" };
}


// ── Is this word playable as a SECRET? ────────────────────────────────────────
//
//  A Dare lets one player choose the word their friend will hunt. Until now that
//  word was only checked for emptiness and profanity — so "zxcvbn", "Jonathan" or
//  a typo could be dared, and the guesser would play a whole round in which every
//  guess reads Freezing. They cannot tell a broken word from a hard one, which is
//  the worst possible failure: it looks like the game is lying to them.
//
//  Three gates, in increasing strictness:
//
//    1. is it an English word?        — the ~274k dictionary already used for guesses
//    2. can it be embedded at all?    — no vector, no warmth, no game
//    3. does it have a NEIGHBOURHOOD? — the interesting one
//
//  (3) is what today taught us. A word is only a good puzzle if some words are
//  meaningfully closer to it than the rest; that gradient IS the game. If its
//  cosines against the reference vocabulary are flat — nothing clearly nearer
//  than anything else — then every guess scores about the same and the round is
//  noise, even though the word is real and embeddable. Obscure and highly
//  technical words fail this way.
//
//  Computing it is free: secretCosinesDesc() is exactly what a live round needs
//  and it caches, so validating the word also warms the cache for the match.

export type SecretVerdict = "ok" | "not_a_word" | "no_embedding" | "too_flat";

export interface SecretCheck {
  ok: boolean;
  verdict: SecretVerdict;
  /** Gap between the 25th-closest vocab word and the median. Higher = a sharper
   *  neighbourhood = a better puzzle. Logged so the threshold below can be set
   *  from real dares instead of guessed. */
  spread?: number;
}

//  DELIBERATELY OFF BY DEFAULT (0 = observe, never reject). Any threshold I pick
//  today would be invented — we have no distribution of spreads for real dare
//  words yet. The value is logged on every dare; once a week of them exists, set
//  WICK_SECRET_MIN_SPREAD to something grounded and it starts enforcing.
const MIN_SPREAD = numEnv("WICK_SECRET_MIN_SPREAD", 0);

/** Median of a descending-sorted list. */
function medianDesc(sortedDesc: number[]): number {
  const n = sortedDesc.length;
  if (n === 0) return 0;
  const mid = n >> 1;
  return n % 2 ? sortedDesc[mid]! : (sortedDesc[mid - 1]! + sortedDesc[mid]!) / 2;
}

/**
 * Can this word carry a round? Fails OPEN at every step where we cannot tell
 * (no dictionary, no API key, vocabulary not warmed yet) — blocking a legitimate
 * dare is worse than allowing a mediocre one.
 */
export async function validateSecret(
  word: string,
  embedder: (t: string) => Promise<number[] | null> = embed,
): Promise<SecretCheck> {
  const w = normalizeWord(word);
  if (!w) return { ok: false, verdict: "not_a_word" };
  if (!isRealWord(w)) return { ok: false, verdict: "not_a_word" };

  if (!hasEmbeddings()) return { ok: true, verdict: "ok" }; // can't check — allow
  const vec = await embedder(w);
  if (!vec) return { ok: false, verdict: "no_embedding" };

  const vocab = rankVocabEntries();
  if (vocab.length === 0) return { ok: true, verdict: "ok" }; // not warmed — allow

  const cs = secretCosinesDesc(vec, w);
  const near = cs[24] ?? cs[cs.length - 1] ?? 0; // 25th closest, or the last we have
  const spread = Math.round((near - medianDesc(cs)) * 1000) / 1000;
  if (MIN_SPREAD > 0 && spread < MIN_SPREAD) return { ok: false, verdict: "too_flat", spread };
  return { ok: true, verdict: "ok", spread };
}
