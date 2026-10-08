import { describe, it, expect, afterEach } from "vitest";
import { LruCache, cosine, batchEmbed, warmRankVocab, rankVocabEntries, _clearCache } from "./embeddings.js";

describe("LruCache", () => {
  it("evicts the least-recently-used, not the oldest-inserted", () => {
    const c = new LruCache<number>(2);
    c.set("a", 1);
    c.set("b", 2);
    c.get("a"); // touch a → b is now the LRU
    c.set("c", 3); // evicts b, keeps a
    expect(c.has("a")).toBe(true);
    expect(c.has("b")).toBe(false);
    expect(c.has("c")).toBe(true);
    expect(c.size).toBe(2);
  });

  it("re-setting an existing key updates the value without growing", () => {
    const c = new LruCache<number>(2);
    c.set("a", 1);
    c.set("a", 9);
    expect(c.get("a")).toBe(9);
    expect(c.size).toBe(1);
  });

  it("clear empties it", () => {
    const c = new LruCache<number>(2);
    c.set("a", 1);
    c.clear();
    expect(c.size).toBe(0);
    expect(c.has("a")).toBe(false);
  });
});

describe("cosine", () => {
  it("is 1 for identical, ~0 for orthogonal", () => {
    expect(cosine([1, 0], [1, 0])).toBeCloseTo(1);
    expect(cosine([1, 0], [0, 1])).toBeCloseTo(0);
  });
  it("handles zero vectors without NaN", () => {
    expect(cosine([0, 0], [1, 2])).toBe(0);
  });
  it("accepts Float32Array (how the rank vocab is stored)", () => {
    expect(cosine(new Float32Array([1, 0]), [1, 0])).toBeCloseTo(1);
  });
});

describe("batchEmbed", () => {
  const realFetch = globalThis.fetch;
  afterEach(() => {
    globalThis.fetch = realFetch;
    delete process.env.GEMINI_API_KEY;
    _clearCache();
  });

  it("returns one vector per input, in order, from batchEmbedContents", async () => {
    process.env.GEMINI_API_KEY = "test-key";
    globalThis.fetch = (async (url: unknown, init?: { body?: string }) => {
      const u = String(url);
      if (u.includes(":batchEmbedContents")) {
        const body = JSON.parse(init!.body!) as { requests: unknown[] };
        // Encode each request's index so we can assert order is preserved.
        const embeddings = body.requests.map((_r, i) => ({ values: [i + 1, 0] }));
        return { ok: true, json: async () => ({ embeddings }) };
      }
      return { ok: true, json: async () => ({ embedding: { values: [1, 0] } }) };
    }) as unknown as typeof fetch;
    const out = await batchEmbed(["a", "b", "c"]);
    expect(out.length).toBe(3);
    expect(out[0]![0]).toBe(1);
    expect(out[2]![0]).toBe(3);
  });

  it("falls back to per-word embed when the batch call fails", async () => {
    process.env.GEMINI_API_KEY = "test-key";
    globalThis.fetch = (async (url: unknown) => {
      const u = String(url);
      if (u.includes(":batchEmbedContents")) return { ok: false, status: 500, text: async () => "err" };
      return { ok: true, json: async () => ({ embedding: { values: [7, 0] } }) };
    }) as unknown as typeof fetch;
    const out = await batchEmbed(["x", "y"]);
    expect(out[0]).toEqual([7, 0]); // came from the single-embed fallback
    expect(out[1]).toEqual([7, 0]);
  });
});

describe("warmRankVocab", () => {
  const realFetch = globalThis.fetch;
  afterEach(() => {
    globalThis.fetch = realFetch;
    delete process.env.GEMINI_API_KEY;
    _clearCache();
  });

  it("stores word-paired entries for every embedded vocab word", async () => {
    process.env.GEMINI_API_KEY = "test-key";
    globalThis.fetch = (async (url: unknown, init?: { body?: string }) => {
      const u = String(url);
      if (u.includes(":batchEmbedContents")) {
        const body = JSON.parse(init!.body!) as { requests: unknown[] };
        return { ok: true, json: async () => ({ embeddings: body.requests.map(() => ({ values: [1, 0] })) }) };
      }
      return { ok: true, json: async () => ({ embedding: { values: [1, 0] } }) };
    }) as unknown as typeof fetch;
    const n = await warmRankVocab(["Farm", "field", "crop", "farm"]); // dupes/case handled
    expect(n).toBe(3);
    const words = rankVocabEntries()
      .map((e) => e.word)
      .sort();
    expect(words).toEqual(["crop", "farm", "field"]);
  });
});
