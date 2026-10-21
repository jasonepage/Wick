//
//  embeddings.ts — word embeddings via Google Gemini (SDS §, FR-19/24 spirit).
//
//  Powers the server-side hot/cold "warmth" (the cross-platform replacement for
//  the iOS on-device NLEmbedding). The API key lives ONLY in Render env
//  (GEMINI_API_KEY) — never in any client (C4). Swappable provider (FR-24): only
//  this file talks to Gemini.
//
//  Model: the current GA embedding model is `gemini-embedding-001`
//  (text-embedding-004 was retired). We try a small fallback chain and PIN the
//  first model this key can actually use, so it self-selects. Override with
//  WICK_EMBED_MODEL (single name or comma list).
//
//  Caches vectors in memory (words repeat constantly). Degrades gracefully: if
//  the key is missing or every model fails, `embed` returns null (→ lexical
//  fallback, C3) and records `lastEmbedError()`.
//

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const GEMINI_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models";
const MODELS = (process.env.WICK_EMBED_MODEL ?? "gemini-embedding-001,gemini-embedding-2,text-embedding-004")
  .split(",")
  .map((s) => s.trim())
  .filter((s) => s.length > 0);
const CACHE_MAX = 4000;

// Output dimensionality (Matryoshka truncation on gemini-embedding-001). 768 keeps
// almost all of the semantic signal while cutting memory 4× vs the 3072 default —
// with a 10k-word rank vocabulary that's the difference between ~30MB and ~120MB of
// vectors on a 512MB Render Starter. Cosine is scale-invariant, so no re-normalize
// is needed. Set WICK_EMBED_DIM=0 (or empty) to fall back to the model default.
const EMBED_DIM = (() => {
  const raw = process.env.WICK_EMBED_DIM;
  if (raw === undefined) return 768;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0; // 0 → omit the param
})();

// Max texts per batchEmbedContents request. Gemini accepts up to ~100 comfortably.
const BATCH_MAX = 100;

/** A tiny LRU: `get` moves the key to the most-recent end, so hot words survive
 *  eviction (the old FIFO could drop a frequently-guessed word). */
export class LruCache<V> {
  private readonly map = new Map<string, V>();
  constructor(private readonly max: number) {}
  get(k: string): V | undefined {
    const v = this.map.get(k);
    if (v !== undefined) {
      this.map.delete(k);
      this.map.set(k, v);
    }
    return v;
  }
  set(k: string, v: V): void {
    if (this.map.has(k)) this.map.delete(k);
    else if (this.map.size >= this.max) {
      const oldest = this.map.keys().next().value;
      if (oldest !== undefined) this.map.delete(oldest);
    }
    this.map.set(k, v);
  }
  has(k: string): boolean {
    return this.map.has(k);
  }
  get size(): number {
    return this.map.size;
  }
  clear(): void {
    this.map.clear();
  }
}

const cache = new LruCache<number[]>(CACHE_MAX);
// De-dupe concurrent embeds of the SAME word into one Gemini call (e.g. two
// players guess "dog" at once, or a double-tap): callers share the in-flight promise.
const inFlight = new Map<string, Promise<number[] | null>>();
let cacheHits = 0;
let cacheMisses = 0;
let lastError: string | null = null;
// The ONE (model, taskType) combination this process uses. Both halves matter:
// a vector embedded with taskType=SEMANTIC_SIMILARITY and one embedded without
// live in different projections of the space, and their cosine is meaningless —
// near zero, as if the words were unrelated. Mixing either half silently
// poisons every comparison, so both are negotiated once and then frozen.
interface EmbedMode { model: string; taskType: boolean }
let mode: EmbedMode | null = null;
let modeProbe: Promise<EmbedMode | null> | null = null;
/** Vector width of the first good embedding. Anything else means the model
 *  changed underneath us — reject rather than compare across spaces. */
let dims = 0;
/** A pair with an unmistakable relationship, used to probe and to self-check. */
const PROBE = ["tomato", "vegetable"] as const;

/** All-zero vectors are truthy, so they used to sail through `if (vec)` and get
 *  cached — after which cosine() returns exactly 0 for that word for the life of
 *  the process. Treat them as failures. */
function degenerate(vec: number[]): boolean {
  if (vec.length === 0) return true;
  for (const v of vec) if (v !== 0) return false;
  return true;
}

function apiKey(): string {
  return process.env.GEMINI_API_KEY ?? "";
}

/** True if a Gemini key is configured (so real embeddings are available). */
export function hasEmbeddings(): boolean {
  return apiKey().length > 0;
}

/** The last embedding failure reason (diagnostics), or null if the last call succeeded. */
export function lastEmbedError(): string | null {
  return lastError;
}

/** The embedding model currently in use (once one has succeeded). */
export function activeEmbedModel(): string | null {
  return mode?.model ?? null;
}

/** The frozen (model, taskType, dims) triple — surfaced on /healthz so a repeat
 *  of the mixed-space bug is visible without a redeploy. */
export function activeEmbedMode(): { model: string; taskType: boolean; dims: number } | null {
  return mode ? { model: mode.model, taskType: mode.taskType, dims } : null;
}

/**
 * Negotiate the model + taskType ONCE, behind a single shared promise.
 *
 * This is the fix for the poisoned-vocabulary bug. Previously each call picked
 * its own combination: on any error it silently retried the same model WITHOUT
 * taskType and accepted the result, and it reassigned the pinned model on every
 * success. Under the request storm of a boot-time warm (prewarm at concurrency 4
 * plus a 10k-word rank vocab) transient 429s are close to certain — so a subset
 * of words got embedded in a different projection than the rest. Their cosines
 * to everything else came out near zero, which is why "red" scored 0.012 against
 * "tomato" and ranked 8195th.
 */
async function ensureMode(): Promise<EmbedMode | null> {
  if (mode) return mode;
  if (!hasEmbeddings()) { lastError = "no GEMINI_API_KEY"; return null; }
  modeProbe ??= (async (): Promise<EmbedMode | null> => {
    let lastE = "no models configured";
    for (const model of MODELS) {
      for (const taskType of [true, false]) {
        const r = await callEmbed(model, PROBE[0], taskType);
        if (r.error || !r.vec || degenerate(r.vec)) {
          lastE = `${model}${taskType ? "" : " (no taskType)"}: ${r.error ?? "degenerate vector"}`;
          continue;
        }
        dims = r.vec.length;
        lastError = null;
        return { model, taskType };
      }
    }
    lastError = lastE;
    return null;
  })().then((m) => { mode = m; return m; }).finally(() => { modeProbe = null; });
  return modeProbe;
}

/**
 * Boot sanity check: embed a pair of obviously-related words and report their
 * cosine. A healthy gemini space puts these near 0.7–0.8; anything under ~0.3
 * means the vectors are not comparable and every warmth score downstream is
 * noise. Cheap (two embeds, both cached afterwards) and it turns a silent
 * data-quality failure into a line in the logs.
 */
export async function selfCheck(): Promise<{ ok: boolean; cos: number; mode: string } | null> {
  const m = await ensureMode();
  if (!m) return null;
  const [a, b] = await Promise.all([embed(PROBE[0]), embed(PROBE[1])]);
  if (!a || !b) return null;
  const c = cosine(a, b);
  return { ok: c > 0.3, cos: Math.round(c * 1000) / 1000, mode: `${m.model}${m.taskType ? "+similarity" : ""}` };
}

interface Attempt {
  vec?: number[];
  error?: string;
  /** True for 429/5xx — worth retrying; a 400 never is. */
  retryable?: boolean;
  /** Seconds from a Retry-After header, when the API supplied one. */
  retryAfterSec?: number;
}

const RETRY_TRIES = Math.max(1, Number(process.env.WICK_EMBED_RETRIES ?? 4));
const RETRY_BASE_MS = Math.max(50, Number(process.env.WICK_EMBED_RETRY_MS ?? 400));

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

/** Exponential backoff with jitter. Jitter matters here: the vocab warm runs
 *  several workers at once, and without it they all retry on the same beat and
 *  re-trigger the same 429. */
function backoffMs(attempt: number, retryAfter?: number): number {
  if (retryAfter && Number.isFinite(retryAfter)) return Math.min(30_000, retryAfter * 1000);
  const base = RETRY_BASE_MS * Math.pow(2, attempt);
  return Math.min(30_000, base + Math.random() * base * 0.4);
}

/** Retry a rate-limited or transient call. Anything non-retryable returns at once.
 *
 *  This is what recovers the words the first vocab warm dropped. Embedding 10k
 *  words in one burst reliably trips Gemini's per-minute limit; previously those
 *  words returned null and were silently omitted from the vocabulary, leaving it
 *  at ~63% and skewing every rank warm (fewer competitors = better rank). */
async function withRetry(fn: () => Promise<Attempt>): Promise<Attempt> {
  let last: Attempt = { error: "no attempt" };
  for (let i = 0; i < RETRY_TRIES; i++) {
    last = await fn();
    if (!last.error || !last.retryable) return last;
    if (i < RETRY_TRIES - 1) await sleep(backoffMs(i, last.retryAfterSec));
  }
  return last;
}

async function callEmbed(model: string, norm: string, withTaskType: boolean): Promise<Attempt> {
  const body: Record<string, unknown> = { model: `models/${model}`, content: { parts: [{ text: norm }] } };
  // taskType SEMANTIC_SIMILARITY tunes vectors for cosine similarity (supported
  // on gemini-embedding-001 / text-embedding-004). If a model rejects it, we
  // retry without it.
  if (withTaskType) body.taskType = "SEMANTIC_SIMILARITY";
  if (EMBED_DIM > 0) body.outputDimensionality = EMBED_DIM;
  try {
    const res = await fetch(`${GEMINI_ENDPOINT}/${model}:embedContent?key=${apiKey()}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      const t = await res.text().catch(() => "");
      const ra = Number(res.headers.get("retry-after"));
      return {
        error: `HTTP ${res.status}: ${t.slice(0, 140)}`,
        retryable: res.status === 429 || res.status >= 500,
        retryAfterSec: Number.isFinite(ra) ? ra : undefined,
      };
    }
    const json = (await res.json()) as { embedding?: { values?: unknown } };
    const values = json.embedding?.values;
    if (!Array.isArray(values) || values.length === 0) return { error: "no embedding values" };
    const vec = values.map(Number);
    if (vec.some((n) => !Number.isFinite(n))) return { error: "non-finite values" };
    return { vec };
  } catch (e) {
    // Network/DNS blips are transient by nature.
    return { error: String(e).slice(0, 140), retryable: true };
  }
}

/**
 * Embed a single word/phrase. Returns the vector, or null if embeddings are
 * unavailable (no key) or every model fails. Cached by normalized text. Tries
 * the pinned model first, then the rest of the chain (with, then without,
 * taskType), pinning the first that works.
 */
export async function embed(text: string): Promise<number[] | null> {
  const norm = text.trim().toLowerCase();
  if (!norm) return null;
  const cached = cache.get(norm);
  if (cached) {
    cacheHits += 1;
    return cached;
  }
  if (!hasEmbeddings()) {
    lastError = "no GEMINI_API_KEY";
    return null;
  }
  // Already fetching this word? Share that call rather than firing another.
  const pending = inFlight.get(norm);
  if (pending) return pending;

  cacheMisses += 1;
  const p = computeEmbed(norm).then((vec) => {
    if (vec) cache.set(norm, vec);
    return vec;
  });
  inFlight.set(norm, p);
  void p.finally(() => inFlight.delete(norm));
  return p;
}

/** Fetch one vector using the frozen mode (no caching here).
 *
 *  A failure returns null and is NOT papered over by trying another model or
 *  dropping taskType — that is what produced two incompatible vector spaces in
 *  the same cache. Returning null is safe and self-healing: the word simply
 *  isn't cached, so the next guess re-embeds it once the API is happy again. */
async function computeEmbed(norm: string): Promise<number[] | null> {
  const m = await ensureMode();
  if (!m) return null;
  const r = await withRetry(() => callEmbed(m.model, norm, m.taskType));
  if (r.error || !r.vec || degenerate(r.vec)) {
    lastError = r.error ?? "degenerate vector";
    return null;
  }
  if (dims && r.vec.length !== dims) {
    // Width changed => the model changed underneath us. Never compare across.
    lastError = `dim mismatch: got ${r.vec.length}, expected ${dims}`;
    return null;
  }
  lastError = null;
  return r.vec;
}

/** Embed many texts in ONE request via `:batchEmbedContents`. Returns a vector
 *  (or null) per input, in order. Tries the given model with, then without,
 *  taskType. Any transport/shape failure returns all-null so the caller can fall
 *  back to per-word embeds — batch is a boot-speed optimization, never a
 *  correctness dependency. */
/** Marker so the batch retry wrapper can tell "rate limited, try again" from
 *  "malformed request, give up". */
class RetryableBatch extends Error {
  constructor(public status: number) { super(`batch HTTP ${status}`); }
}

async function callBatch(model: string, words: string[], withTaskType: boolean): Promise<(number[] | null)[]> {
  const requests = words.map((w) => {
    const req: Record<string, unknown> = { model: `models/${model}`, content: { parts: [{ text: w }] } };
    if (withTaskType) req.taskType = "SEMANTIC_SIMILARITY";
    if (EMBED_DIM > 0) req.outputDimensionality = EMBED_DIM;
    return req;
  });
  try {
    const res = await fetch(`${GEMINI_ENDPOINT}/${model}:batchEmbedContents?key=${apiKey()}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ requests }),
    });
    if (!res.ok) {
      if (res.status === 429 || res.status >= 500) throw new RetryableBatch(res.status);
      return words.map(() => null);
    }
    const json = (await res.json()) as { embeddings?: Array<{ values?: unknown }> };
    const embs = json.embeddings;
    if (!Array.isArray(embs) || embs.length !== words.length) return words.map(() => null);
    return embs.map((e) => {
      const values = e?.values;
      if (!Array.isArray(values) || values.length === 0) return null;
      const vec = values.map(Number);
      return vec.some((n) => !Number.isFinite(n)) ? null : vec;
    });
  } catch (e) {
    if (e instanceof RetryableBatch) throw e;
    return words.map(() => null);
  }
}

/** callBatch with backoff on 429/5xx. */
async function callBatchRetrying(model: string, words: string[], withTaskType: boolean): Promise<(number[] | null)[]> {
  for (let i = 0; i < RETRY_TRIES; i++) {
    try {
      return await callBatch(model, words, withTaskType);
    } catch (e) {
      if (!(e instanceof RetryableBatch) || i === RETRY_TRIES - 1) return words.map(() => null);
      await sleep(backoffMs(i));
    }
  }
  return words.map(() => null);
}

/**
 * Embed a list of texts efficiently (batched), returning a vector or null per
 * input in order. Falls back to per-word `embed()` for any that the batch call
 * couldn't resolve, so the result is as complete as single-embedding would be —
 * just far fewer round-trips. Does NOT touch the guess LRU (vocab words would
 * evict real guesses); callers that want caching should use `embed()`.
 */
export async function batchEmbed(words: string[]): Promise<(number[] | null)[]> {
  if (!hasEmbeddings()) return words.map(() => null);
  // Pin a working model first (single embed self-selects the model this key can use).
  const m = await ensureMode();
  if (!m) return words.map(() => null);
  const model = m.model;
  const out: (number[] | null)[] = new Array(words.length).fill(null);
  for (let i = 0; i < words.length; i += BATCH_MAX) {
    const chunk = words.slice(i, i + BATCH_MAX);
    // No taskType fallback here either: a chunk that fails falls through to
    // per-word embed() below, which uses the same frozen mode. Retrying the
    // chunk without taskType would silently mix spaces a thousand words at a time.
    const vecs = await callBatchRetrying(model, chunk, m.taskType);
    for (let j = 0; j < chunk.length; j++) {
      out[i + j] = vecs[j] ?? (await embed(chunk[j]!).catch(() => null)); // per-word fallback
    }
  }
  return out;
}

/** Pre-embed a list of words in the background so their first real guess is
 *  instant (no Gemini round-trip). Bounded concurrency; errors are swallowed.
 *  Returns how many succeeded. */
export async function prewarm(words: string[], concurrency = 4): Promise<number> {
  if (!hasEmbeddings()) return 0;
  const queue = [...new Set(words.map((w) => w.trim().toLowerCase()).filter((w) => w.length > 0))];
  let ok = 0;
  const worker = async () => {
    for (;;) {
      const w = queue.shift();
      if (!w) return;
      const v = await embed(w).catch(() => null);
      if (v) ok += 1;
    }
  };
  await Promise.all(Array.from({ length: Math.max(1, concurrency) }, worker));
  return ok;
}

/** Cache diagnostics (ops / observability). */
export function cacheStats(): { size: number; hits: number; misses: number; inFlight: number } {
  return { size: cache.size, hits: cacheHits, misses: cacheMisses, inFlight: inFlight.size };
}

// ── rank vocabulary (Contexto-style warmth) ────────────────────────────────────
// The embedded reference words, PAIRED with the word so ranking can exclude the
// secret and its morphological variants (matching the iOS engine). Stored as
// Float32Array (half the memory of JS number[]) and never evicted — with 10k
// words a vocabulary is the app's biggest allocation (~30MB at 768 dims).
//
// One set per LANGUAGE. English is warmed at boot; the others are warmed the
// first time a round asks for them (ensureRankVocab), so a server nobody plays
// in German on never pays for German. A finished warm is written to disk
// (WICK_VOCAB_CACHE, default data/rankvec) as int8 vectors, ~8MB per language,
// and read back on the next boot instead of re-embedding 10k words through
// Gemini. The file records the (model, taskType, dims) it was made with and is
// ignored if the live mode differs, so a model change can never mix spaces.
export interface RankEntry {
  word: string;
  vec: Float32Array;
}
const rankByLang = new Map<string, RankEntry[]>();
const rankExpectedByLang = new Map<string, number>();
const rankProgressByLang = new Map<string, number>();
const rankWarmInFlight = new Map<string, Promise<number>>();

function vocabCacheDir(): string {
  return process.env.WICK_VOCAB_CACHE ?? "data/rankvec";
}

/** Where a language's cached vectors live. */
function vocabCachePath(lang: string): string {
  return join(vocabCacheDir(), `${lang}.rankvec`);
}

interface VocabFileHeader {
  model: string;
  taskType: boolean;
  dims: number;
  words: string[];
}

/** Write a warmed vocabulary to disk: one JSON header line, then per word a
 *  Float32 scale and `dims` int8 values (value = int8 * scale). Best effort;
 *  a failure only means the next boot re-embeds. */
function saveRankVocabToDisk(lang: string, entries: RankEntry[]): void {
  if (!mode || entries.length === 0 || process.env.WICK_VOCAB_CACHE === "0") return;
  try {
    const header: VocabFileHeader = { model: mode.model, taskType: mode.taskType, dims, words: entries.map((e) => e.word) };
    const head = Buffer.from(JSON.stringify(header) + "\n", "utf8");
    const body = Buffer.alloc(entries.length * (4 + dims));
    let off = 0;
    for (const e of entries) {
      let max = 0;
      for (let i = 0; i < dims; i++) max = Math.max(max, Math.abs(e.vec[i] ?? 0));
      const scale = max > 0 ? max / 127 : 1;
      body.writeFloatLE(scale, off);
      off += 4;
      for (let i = 0; i < dims; i++) body.writeInt8(Math.round((e.vec[i] ?? 0) / scale), off++);
    }
    mkdirSync(vocabCacheDir(), { recursive: true });
    writeFileSync(vocabCachePath(lang), Buffer.concat([head, body]));
    console.log(`[wick-api] rank vocab ${lang}: cached ${entries.length} vectors to ${vocabCachePath(lang)}`);
  } catch (e) {
    console.warn(`[wick-api] rank vocab ${lang}: could not write cache: ${String(e).slice(0, 120)}`);
  }
}

/** Read a cached vocabulary back, or null if there is none, it was made with a
 *  different (model, taskType, dims), or it does not hold the words asked for. */
function loadRankVocabFromDisk(lang: string, words: string[]): RankEntry[] | null {
  if (!mode || process.env.WICK_VOCAB_CACHE === "0") return null;
  let buf: Buffer;
  try {
    buf = readFileSync(vocabCachePath(lang));
  } catch {
    return null;
  }
  try {
    const nl = buf.indexOf(0x0a);
    if (nl < 0) return null;
    const header = JSON.parse(buf.subarray(0, nl).toString("utf8")) as VocabFileHeader;
    if (header.model !== mode.model || header.taskType !== mode.taskType || header.dims !== dims) return null;
    const want = new Set(words);
    if (header.words.length === 0 || !header.words.every((w) => want.has(w))) return null;
    const have = new Set(header.words);
    const missing = words.filter((w) => !have.has(w)).length;
    if (missing > words.length * 0.02) return null; // too incomplete to be worth it; re-embed
    const rows = new Map<string, Float32Array>();
    let off = nl + 1;
    for (const w of header.words) {
      if (off + 4 + dims > buf.length) return null;
      const scale = buf.readFloatLE(off);
      off += 4;
      const vec = new Float32Array(dims);
      for (let i = 0; i < dims; i++) vec[i] = buf.readInt8(off++) * scale;
      rows.set(w, vec);
    }
    return words.filter((w) => rows.has(w)).map((w) => ({ word: w, vec: rows.get(w)! }));
  } catch {
    return null;
  }
}

/** Embed the rank vocabulary (batched) and hold the vectors for ranking.
 *  Returns how many embedded. Safe to call again (replaces the set).
 *  `concurrency` bounds how many batch requests are in flight at once.
 *  Reads the on-disk cache first when one matches the live embedding mode. */
export async function warmRankVocab(words: string[], concurrency = 4, lang = "en"): Promise<number> {
  if (!hasEmbeddings()) return 0;
  const uniq = [...new Set(words.map((w) => w.trim().toLowerCase()).filter((w) => w.length > 0))];
  // Published immediately, not at the end: otherwise /healthz reads a useless
  // 0/0 for the several minutes the warm takes and there is no way to tell a
  // slow boot from a stalled one.
  rankExpectedByLang.set(lang, uniq.length);
  rankProgressByLang.set(lang, 0);

  // The cache file is only trusted once the (model, taskType) pair is known.
  await ensureMode();
  const cached = loadRankVocabFromDisk(lang, uniq);
  if (cached) {
    rankByLang.set(lang, cached);
    rankProgressByLang.set(lang, cached.length);
    console.log(`[wick-api] rank vocab ${lang}: loaded ${cached.length}/${uniq.length} from disk cache`);
    return cached.length;
  }

  // Words are keyed by name so repeat sweeps can target exactly what is missing.
  const got = new Map<string, Float32Array>();

  /** One pass over whatever is still missing. Returns how many it added. */
  const sweep = async (todo: string[], workers: number): Promise<number> => {
    const chunks: string[][] = [];
    for (let i = 0; i < todo.length; i += BATCH_MAX) chunks.push(todo.slice(i, i + BATCH_MAX));
    let next = 0;
    let added = 0;
    const worker = async (): Promise<void> => {
      for (;;) {
        const idx = next++;
        if (idx >= chunks.length) return;
        const chunk = chunks[idx]!;
        const vecs = await batchEmbed(chunk).catch(() => chunk.map(() => null));
        for (let j = 0; j < chunk.length; j++) {
          const v = vecs[j];
          if (v) { got.set(chunk[j]!, Float32Array.from(v)); added++; rankProgressByLang.set(lang, got.size); }
        }
      }
    };
    await Promise.all(Array.from({ length: Math.max(1, workers) }, worker));
    return added;
  };

  // First pass at full speed, then re-sweep the stragglers with progressively
  // fewer workers. Embedding 10k words in one burst reliably trips Gemini's
  // per-minute limit; the words that lose that race used to be dropped on the
  // floor, which is how the vocabulary ended up at ~63% and every rank came out
  // warmer than iOS would show for the same guess.
  await sweep(uniq, concurrency);
  for (const workers of [2, 1]) {
    const missing = uniq.filter((w) => !got.has(w));
    if (missing.length === 0) break;
    console.log(`[wick-api] rank vocab ${lang}: re-sweeping ${missing.length} missing words at concurrency ${workers}`);
    const added = await sweep(missing, workers);
    if (added === 0) break; // making no progress — stop rather than spin
  }

  const shortfall = uniq.length - got.size;
  if (shortfall > 0) {
    console.warn(
      `[wick-api] rank vocab ${lang} INCOMPLETE: ${got.size}/${uniq.length} (${shortfall} missing). ` +
      "Ranks will read warmer than iOS for the same guess; see WICK_EMBED_RETRIES.",
    );
  }

  // Preserve the caller's word order so the vocabulary is deterministic across
  // deploys (the sweeps finish out of order).
  const entries = uniq.filter((w) => got.has(w)).map((w) => ({ word: w, vec: got.get(w)! }));
  rankByLang.set(lang, entries);
  rankExpectedByLang.set(lang, uniq.length);
  if (shortfall === 0) saveRankVocabToDisk(lang, entries);
  return entries.length;
}

/** Warm a language's vocabulary if it is not ready, sharing one in-flight warm
 *  per language. Resolves with the entry count (0 when embeddings are off).
 *  Callers that cannot wait (a live guess) should not await this; they get the
 *  absolute-cosine bands until it lands, exactly like English during boot. */
export function ensureRankVocab(lang: string, words: string[], concurrency = 2): Promise<number> {
  const have = rankByLang.get(lang);
  if (have && have.length > 0) return Promise.resolve(have.length);
  const pending = rankWarmInFlight.get(lang);
  if (pending) return pending;
  const p = warmRankVocab(words, concurrency, lang).finally(() => rankWarmInFlight.delete(lang));
  rankWarmInFlight.set(lang, p);
  return p;
}

/** How many words the vocabulary SHOULD hold, for /healthz to compare against. */
export function rankVocabExpected(lang = "en"): number {
  return rankExpectedByLang.get(lang) ?? 0;
}

/** Words embedded so far in the current warm. rankVocab stays 0 until the whole
 *  warm commits, so this is the only way to watch it progress. */
export function rankVocabProgress(lang = "en"): number {
  return rankProgressByLang.get(lang) ?? 0;
}

/** Per-language readiness, for /healthz. Only languages that have been asked
 *  for appear. */
export function rankVocabStatus(): Record<string, { ready: number; expected: number; progress: number }> {
  const out: Record<string, { ready: number; expected: number; progress: number }> = {};
  for (const lang of new Set([...rankByLang.keys(), ...rankExpectedByLang.keys()])) {
    out[lang] = { ready: rankByLang.get(lang)?.length ?? 0, expected: rankVocabExpected(lang), progress: rankVocabProgress(lang) };
  }
  return out;
}

/** The embedded rank-vocab entries for a language (empty until warmed). */
export function rankVocabEntries(lang = "en"): RankEntry[] {
  return rankByLang.get(lang) ?? [];
}

/** The embedded rank-vocab vectors (empty until warmed). Back-compat accessor. */
export function rankVocabVectors(lang = "en"): Float32Array[] {
  return rankVocabEntries(lang).map((e) => e.vec);
}

/** For tests: inject/clear the rank vocab directly. Accepts word-paired entries
 *  or bare vectors (words default to "" — fine for tests that don't exercise
 *  the secret/variant exclusion). */
export function _setRankVectors(v: RankEntry[] | ArrayLike<number>[], lang = "en"): void {
  rankByLang.set(lang, v.map((e) =>
    "vec" in (e as RankEntry)
      ? { word: (e as RankEntry).word, vec: Float32Array.from((e as RankEntry).vec) }
      : { word: "", vec: Float32Array.from(e as ArrayLike<number>) },
  ));
}

/** For tests: the disk cache round trip without a network warm. */
export const _saveForTest = saveRankVocabToDisk;
export const _loadForTest = loadRankVocabFromDisk;

/** For tests: pretend the embedding mode was negotiated. */
export function _setMode(m: { model: string; taskType: boolean; dims: number } | null): void {
  mode = m ? { model: m.model, taskType: m.taskType } : null;
  dims = m ? m.dims : 0;
}

/** Cosine similarity of two equal-length vectors, in [-1, 1]. */
export function cosine(a: ArrayLike<number>, b: ArrayLike<number>): number {
  const n = Math.min(a.length, b.length);
  let dot = 0;
  let na = 0;
  let nb = 0;
  for (let i = 0; i < n; i++) {
    const x = a[i]!;
    const y = b[i]!;
    dot += x * y;
    na += x * x;
    nb += y * y;
  }
  if (na === 0 || nb === 0) return 0;
  return dot / (Math.sqrt(na) * Math.sqrt(nb));
}

/** For tests: clear the in-memory cache + counters. */
export function _clearCache(): void {
  cache.clear();
  inFlight.clear();
  cacheHits = 0;
  cacheMisses = 0;
}
