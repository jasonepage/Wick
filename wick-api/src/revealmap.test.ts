import { describe, it, expect } from "vitest";
import { similarityMatrix } from "./revealmap.js";
import { pairSimilarity, nearSimilarities } from "./warmthservice.js";

describe("similarityMatrix", () => {
  const rescale = (c: number) => Math.round(c * 100) / 100;

  it("gives pairwise similarity in guess order, 1 on the diagonal", () => {
    const m = similarityMatrix([[1, 0], [0, 1], [1, 0]], rescale);
    expect(m).toEqual([[1, 0, 1], [0, 1, 0], [1, 0, 1]]);
  });

  it("gives null pairs for a word with no vector", () => {
    const m = similarityMatrix([[1, 0], null], rescale);
    expect(m).toEqual([[1, null], [null, null]]);
  });

  it("is null when nothing has a vector, so clients drop the stat", () => {
    expect(similarityMatrix([null, null], rescale)).toBeNull();
    expect(similarityMatrix([], rescale)).toBeNull();
  });
});

describe("pairSimilarity", () => {
  it("puts Gemini's hot cosine on the clients' 0 to 1 scale", () => {
    expect(pairSimilarity(0.8)).toBe(0);    // unrelated words
    expect(pairSimilarity(0.96)).toBe(1);
    expect(pairSimilarity(0.5)).toBe(0);    // never below zero
    expect(pairSimilarity(0.99)).toBe(1);   // never above one
    expect(pairSimilarity(0.88)).toBe(0.5);
  });
});

describe("nearSimilarities", () => {
  const vectors: Record<string, number[]> = { cat: [1, 0], dog: [1, 0], rock: [0, 1] };
  const embedder = async (w: string) => vectors[w] ?? null;

  it("keeps the caller's order and marks what it cannot compare", async () => {
    const got = await nearSimilarities("cat", ["dog", null, "zzz", "rock"], embedder);
    expect(got).toEqual([1, null, null, 0]);
  });

  it("gives nulls when the guess itself has no vector", async () => {
    expect(await nearSimilarities("zzz", ["cat"], embedder)).toEqual([null]);
  });
});
