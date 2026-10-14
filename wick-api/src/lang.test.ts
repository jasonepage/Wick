//
//  lang.test.ts: scoring a round in Spanish, French, Italian or German.
//
//  The server embeds every language in the same Gemini space; what changes per
//  language is the reference vocabulary a guess is ranked against and the
//  real-word gate. These tests inject vectors so no API key is needed.
//

import { afterEach, describe, expect, it } from "vitest";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { LANGS, isLang, langOf, rankVocabFor } from "./lang.js";
import { isRealWord, foldAccents } from "./dictionary.js";
import { warmthScore } from "./warmthservice.js";
import { _setRankVectors, _setMode, _clearCache, rankVocabEntries, rankVocabStatus, warmRankVocab } from "./embeddings.js";

describe("language registry", () => {
  it("knows five languages and defaults to English", () => {
    expect(LANGS).toEqual(["en", "es", "fr", "it", "de", "zh"]);
    expect(isLang("es")).toBe(true);
    expect(isLang("ja")).toBe(false);
    expect(langOf("fr")).toBe("fr");
    expect(langOf(undefined)).toBe("en");
    expect(langOf("klingon")).toBe("en");
  });

  it("carries a full 10k vocabulary per language, in iOS order", () => {
    for (const lang of ["es", "fr", "it", "de", "zh"] as const) {
      const v = rankVocabFor(lang);
      expect(v.length).toBe(10_000);
      expect(new Set(v).size).toBe(10_000);
    }
    expect(isRealWord("图书馆", "zh")).toBe(true);
    expect(isRealWord("library", "zh")).toBe(false);
    expect(rankVocabFor("es")[0]).toBe("que");
    expect(rankVocabFor("en")[0]).toBe("the");
  });
});

describe("real-word gate per language", () => {
  it("English still uses the big list", () => {
    expect(isRealWord("library")).toBe(true);
    expect(isRealWord("dokc")).toBe(false);
  });
  it("other languages accept their vocabulary, with or without accents", () => {
    expect(isRealWord("gobierno", "es")).toBe(true);
    expect(isRealWord("GOBIERNO", "es")).toBe(true);
    expect(isRealWord("también", "es")).toBe(true);
    expect(isRealWord("tambien", "es")).toBe(true);
    expect(isRealWord("library", "es")).toBe(false);
    expect(isRealWord("xyzzy", "de")).toBe(false);
    expect(foldAccents("straße")).toBe("strasse");
  });
});

describe("rank per language", () => {
  afterEach(() => { _setRankVectors([], "es"); _setRankVectors([]); _clearCache(); });

  const vec = (x: number, y: number) => [x, y, 0];
  const embedder = async (t: string) => ({ mar: vec(1, 0), océano: vec(0.98, 0.2), barco: vec(0.7, 0.7), montaña: vec(0, 1) }[t] ?? null);

  it("ranks a Spanish guess against the Spanish vocabulary only", async () => {
    process.env.GEMINI_API_KEY = "test-key"; // hasEmbeddings() reads env
    const f = (v: number[]) => Float32Array.from(v);
    _setRankVectors([{ word: "océano", vec: f(vec(0.98, 0.2)) }, { word: "barco", vec: f(vec(0.7, 0.7)) }, { word: "montaña", vec: f(vec(0, 1)) }], "es");
    const r = await warmthScore("mar", "barco", embedder, "es");
    expect(r.source).toBe("rank");
    expect(r.rank).toBe(3); // océano is closer, so barco is the 2nd closest guessable word: rank 3
    // English has no vocabulary injected, so the same pair falls back to cosine bands there.
    const en = await warmthScore("mar", "barco", embedder, "en");
    expect(en.source).toBe("embeddings");
    delete process.env.GEMINI_API_KEY;
  });
});

describe("rank vocab disk cache", () => {
  const dir = mkdtempSync(join(tmpdir(), "rankvec-"));
  afterEach(() => { _setRankVectors([], "it"); _setMode(null); delete process.env.WICK_VOCAB_CACHE; });

  it("writes int8 vectors after a warm and reads them back on the next warm", async () => {
    process.env.WICK_VOCAB_CACHE = dir;
    _setMode({ model: "test-model", taskType: true, dims: 3 });
    // A warm with a working embedder: patch batchEmbed by seeding the cache instead.
    // warmRankVocab goes through batchEmbed → network, so simulate the end state and save.
    const { _saveForTest, _loadForTest } = await import("./embeddings.js") as unknown as {
      _saveForTest: (lang: string, e: Array<{ word: string; vec: Float32Array }>) => void;
      _loadForTest: (lang: string, words: string[]) => Array<{ word: string; vec: Float32Array }> | null;
    };
    const entries = [
      { word: "mare", vec: Float32Array.from([0.5, -0.25, 1]) },
      { word: "cielo", vec: Float32Array.from([0, 1, 0]) },
    ];
    _saveForTest("it", entries);
    const back = _loadForTest("it", ["mare", "cielo"]);
    expect(back).not.toBeNull();
    expect(back!.map((e) => e.word)).toEqual(["mare", "cielo"]);
    // int8 quantisation keeps direction: relative error under 1%.
    expect(Math.abs(back![0]!.vec[0]! - 0.5)).toBeLessThan(0.01);
    expect(Math.abs(back![0]!.vec[1]! + 0.25)).toBeLessThan(0.01);
    // A different model must not read it.
    _setMode({ model: "other-model", taskType: true, dims: 3 });
    expect(_loadForTest("it", ["mare", "cielo"])).toBeNull();
    // Nor a vocabulary with different words.
    _setMode({ model: "test-model", taskType: true, dims: 3 });
    expect(_loadForTest("it", ["mare", "sole"])).toBeNull();
    rmSync(dir, { recursive: true, force: true });
  });

  it("reports per-language status", () => {
    _setRankVectors([{ word: "mare", vec: Float32Array.from([1, 0]) }], "it");
    expect(rankVocabStatus().it?.ready).toBe(1);
    expect(rankVocabEntries("it").length).toBe(1);
    void warmRankVocab; // exercised by embeddings.test.ts with a mocked fetch
  });
});
