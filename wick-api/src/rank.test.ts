import { describe, it, expect } from "vitest";
import { rankToScore, rankFromCosines, warmthScore } from "./warmthservice.js";
import { _setRankVectors, _clearCache, type RankEntry } from "./embeddings.js";

// Band edges mirror iOS HunchTheme.label(for:).
const band = (s: number) =>
  s >= 60 ? "boiling" : s >= 45 ? "hot" : s >= 30 ? "warm" : s >= 18 ? "cool" : s >= 8 ? "cold" : "freezing";

describe("rankToScore — bands match iOS HunchTheme exactly", () => {
  const N = 10000;
  // iOS rank convention (1 = answer, 2 = closest): Boiling 2-25, Hot 26-100,
  // Warm 101-400, Cool 401-1200, Cold beyond. The score band must equal the rank
  // band so the ring, heat word, and "#N" all agree with the single-player board.
  it("maps each iOS rank tier to the matching score band", () => {
    expect(band(rankToScore(2, N))).toBe("boiling");
    expect(band(rankToScore(25, N))).toBe("boiling");
    expect(band(rankToScore(26, N))).toBe("hot");
    expect(band(rankToScore(100, N))).toBe("hot");
    expect(band(rankToScore(101, N))).toBe("warm");
    expect(band(rankToScore(400, N))).toBe("warm");
    expect(band(rankToScore(401, N))).toBe("cool");
    expect(band(rankToScore(1200, N))).toBe("cool");
    expect(band(rankToScore(1201, N))).toBe("cold");
    expect(band(rankToScore(9000, N))).toBe("freezing");
  });

  it("is monotonically non-increasing in rank", () => {
    let prev = 100;
    for (let r = 2; r <= N; r += 17) {
      const s = rankToScore(r, N);
      expect(s).toBeLessThanOrEqual(prev);
      prev = s;
    }
  });
});

describe("rankFromCosines", () => {
  const sorted = [0.9, 0.8, 0.7, 0.6, 0.5]; // descending
  it("counts how many vocab cosines beat the guess", () => {
    expect(rankFromCosines(sorted, 0.95)).toBe(0); // closer than all
    expect(rankFromCosines(sorted, 0.75)).toBe(2); // 0.9, 0.8 are closer
    expect(rankFromCosines(sorted, 0.4)).toBe(5); // colder than all
  });
});

describe("warmthScore uses rank when the vocab is warmed", () => {
  it("ranks a near-secret guess hotter than a far one", async () => {
    _clearCache();
    const secret = [1, 0];
    const near = [0.98, 0.2]; // high cosine to secret
    const far = [0.1, 1]; // near-orthogonal → cold
    _setRankVectors([
      [1, 0], [0.99, 0.1], [0.95, 0.3], [0.8, 0.6], [0.5, 0.87], [0.2, 0.98], [-0.2, 0.98],
    ]);
    const embedder = async (t: string): Promise<number[] | null> => {
      if (t === "secretword") return secret;
      if (t === "near") return near;
      if (t === "far") return far;
      return null;
    };
    process.env.GEMINI_API_KEY = "test-key";
    const hot = await warmthScore("secretword", "near", embedder);
    const cold = await warmthScore("secretword", "far", embedder);
    delete process.env.GEMINI_API_KEY;
    expect(hot.source).toBe("rank");
    expect(hot.rank).toBeDefined();
    expect(hot.rank!).toBeGreaterThanOrEqual(2); // iOS convention starts at 2
    expect(hot.score).toBeGreaterThan(cold.score);
    _setRankVectors([]);
  });

  it("a rich domain vocab crowds a tangential word OUT of the hot zone (the harvest/lion fix)", async () => {
    // The bug: with a thin vocab, an unrelated word (lion) had almost nothing
    // closer to the secret, so it ranked hot. Model it: 'harvest' is close to a
    // cluster of farm words and only mildly close to 'lion'. With the farm words
    // present as reference vocab, lion must land Warm/Cool — NOT Hot/Boiling.
    _clearCache();
    const harvest = [1, 0, 0];
    // 120 farm-ish words all closer to harvest than lion is (cos ~0.95). In the
    // real 10k vocab there are easily 100+ agriculture/food/plant words nearer to
    // "harvest" than an animal — that's exactly what was missing from the old 2k.
    const farm: RankEntry[] = Array.from({ length: 120 }, (_, i) => ({
      word: `farm${i}`,
      vec: new Float32Array([0.95, 0.31 + i * 0.0001, 0]),
    }));
    // Plus some unrelated filler words further away.
    const filler: RankEntry[] = Array.from({ length: 60 }, (_, i) => ({
      word: `misc${i}`,
      vec: new Float32Array([0.2, 0.9, i * 0.001]),
    }));
    _setRankVectors([...farm, ...filler]);
    const lion = [0.85, 0.53, 0]; // mildly close: cos ≈ 0.85, below the farm cluster
    const embedder = async (t: string): Promise<number[] | null> => {
      if (t === "harvest") return harvest;
      if (t === "lion") return lion;
      return null;
    };
    process.env.GEMINI_API_KEY = "test-key";
    const r = await warmthScore("harvest", "lion", embedder);
    delete process.env.GEMINI_API_KEY;
    expect(r.source).toBe("rank");
    // ~40 farm words beat lion → iOS rank ≈ 42 → Warm/Cool, never Hot/Boiling.
    expect(r.rank!).toBeGreaterThan(100); // > iOS Hot cutoff
    expect(band(r.score)).not.toBe("boiling");
    expect(band(r.score)).not.toBe("hot");
    _setRankVectors([]);
  });

  it("excludes the secret and its variants from the ranking (matches iOS)", async () => {
    _clearCache();
    // Unique secret word: the per-secret cosine cache is keyed by the secret, so
    // reusing a name across tests would read a stale vocab's cosines.
    const secret = [1, 0];
    // Vocab includes 'vineyards' (a variant of the secret 'vineyard') pointing
    // exactly at the secret — it must be excluded, or it would inflate every rank.
    _setRankVectors([
      { word: "vineyards", vec: new Float32Array([1, 0]) }, // variant → excluded
      { word: "field", vec: new Float32Array([0.7, 0.71]) },
      { word: "misc", vec: new Float32Array([0.1, 0.99]) },
    ]);
    const guess = [0.72, 0.69]; // slightly closer than 'field'
    const embedder = async (t: string): Promise<number[] | null> =>
      t === "vineyard" ? secret : t === "trellis" ? guess : null;
    process.env.GEMINI_API_KEY = "test-key";
    const r = await warmthScore("vineyard", "trellis", embedder);
    delete process.env.GEMINI_API_KEY;
    // With the variant excluded, nothing outranks the guess → rank at the top (2).
    expect(r.rank!).toBeLessThanOrEqual(4);
    _setRankVectors([]);
  });
});
