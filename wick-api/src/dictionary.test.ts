import { describe, it, expect } from "vitest";
import { isRealWord, dictionarySize } from "./dictionary.js";

describe("isRealWord", () => {
  it("loads a real dictionary", () => {
    expect(dictionarySize()).toBeGreaterThan(100_000);
  });

  it("accepts real English words (incl. inflections)", () => {
    for (const w of ["dock", "light", "wood", "clock", "lock", "water", "running", "run", "orchard"]) {
      expect(isRealWord(w)).toBe(true);
    }
  });

  it("rejects typos and keyboard mash", () => {
    for (const w of ["dokc", "loght", "asdfgh", "zxqwv", "qwertyuiop"]) {
      expect(isRealWord(w)).toBe(false);
    }
  });

  it("is case-insensitive and trims", () => {
    expect(isRealWord("  Dock ")).toBe(true);
    expect(isRealWord("LIGHT")).toBe(true);
  });

  it("rejects empty input", () => {
    expect(isRealWord("")).toBe(false);
    expect(isRealWord("   ")).toBe(false);
  });
});
