import { _setRankVectors } from "./embeddings.js";
import { describe, it, expect } from "vitest";
import { scoreFromCosine, lexicalFallback, warmthScore, validateSecret } from "./warmthservice.js";
import { cosine } from "./embeddings.js";

describe("scoreFromCosine", () => {
  it("maps below LO to 0 and near HI to high, monotonically", () => {
    expect(scoreFromCosine(0.2, 0.45, 0.88)).toBe(0);
    expect(scoreFromCosine(0.45, 0.45, 0.88)).toBe(0);
    const mid = scoreFromCosine(0.66, 0.45, 0.88);
    expect(mid).toBeGreaterThan(0);
    expect(mid).toBeLessThan(99);
    expect(scoreFromCosine(0.88, 0.45, 0.88)).toBe(99); // capped, never 100
    expect(scoreFromCosine(0.95, 0.45, 0.88)).toBe(99);
  });
  it("is monotonic increasing in cosine", () => {
    let prev = -1;
    for (let c = 0.4; c <= 0.9; c += 0.05) {
      const s = scoreFromCosine(c, 0.45, 0.88);
      expect(s).toBeGreaterThanOrEqual(prev);
      prev = s;
    }
  });
});

describe("cosine", () => {
  it("is 1 for identical, ~0 for orthogonal", () => {
    expect(cosine([1, 2, 3], [1, 2, 3])).toBeCloseTo(1);
    expect(cosine([1, 0], [0, 1])).toBeCloseTo(0);
  });
  it("handles zero vectors without NaN", () => {
    expect(cosine([0, 0], [1, 1])).toBe(0);
  });
});

describe("lexicalFallback", () => {
  it("is 100 for identical and low for unrelated", () => {
    expect(lexicalFallback("river", "river")).toBe(100);
    expect(lexicalFallback("river", "xkqzw")).toBeLessThan(20);
  });
  it("never exceeds 45 for non-identical words", () => {
    for (const [a, b] of [["river", "rivers"], ["cat", "car"], ["book", "look"]]) {
      expect(lexicalFallback(a!, b!)).toBeLessThanOrEqual(45);
    }
  });
});

describe("warmthScore", () => {
  it("exact match → 100 (source exact), case/space-insensitive", async () => {
    const r = await warmthScore("Library", "  library ", async () => [1, 0, 0]);
    expect(r).toEqual({ score: 100, source: "exact" });
  });

  it("empty guess → 0", async () => {
    const r = await warmthScore("library", "   ", async () => [1, 0, 0]);
    expect(r.score).toBe(0);
  });

  it("uses embeddings when available (injected embedder)", async () => {
    // secret and guess map to near-identical vectors → high cosine → high score.
    const embedder = async (t: string): Promise<number[]> =>
      t === "library" ? [1, 0, 0] : [0.95, 0.31, 0]; // cos ≈ 0.95
    // hasEmbeddings() reads env; force a key for this test.
    process.env.GEMINI_API_KEY = "test-key";
    const r = await warmthScore("library", "book", embedder);
    delete process.env.GEMINI_API_KEY;
    expect(r.source).toBe("embeddings");
    expect(r.score).toBeGreaterThan(50);
    expect(r.score).toBeLessThanOrEqual(99);
  });

  it("falls back to lexical when no key is set", async () => {
    delete process.env.GEMINI_API_KEY;
    const r = await warmthScore("river", "river-ish", async () => [1, 0, 0]);
    expect(r.source).toBe("fallback");
  });
});

// ── validateSecret: the Dare word gate ───────────────────────────────────────
describe("validateSecret", () => {
  const vec = (n: number) => Array.from({ length: 8 }, (_, i) => Math.sin(n + i));

  it("rejects a non-word before spending an embed call", async () => {
    let called = false;
    const r = await validateSecret("zxcvbn", async () => { called = true; return vec(1); });
    expect(r.ok).toBe(false);
    expect(r.verdict).toBe("not_a_word");
    expect(called).toBe(false);
  });

  it("rejects an empty or whitespace word", async () => {
    expect((await validateSecret("   ")).verdict).toBe("not_a_word");
  });

  it("accepts an ordinary English word", async () => {
    const r = await validateSecret("tomato", async () => vec(2));
    expect(r.ok).toBe(true);
  });

  it("fails open when the word embeds but no vocabulary is warmed", async () => {
    _setRankVectors([]);
    const r = await validateSecret("tomato", async () => vec(3));
    expect(r.ok).toBe(true);
    expect(r.verdict).toBe("ok");
  });
});
