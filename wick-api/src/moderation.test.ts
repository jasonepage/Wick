import { describe, it, expect } from "vitest";
import { normalizeForModeration, isSlur, isBlockedSecret, isBlockedGuess } from "./moderation.js";

describe("normalizeForModeration", () => {
  it("folds leet, strips separators, and collapses long repeats", () => {
    expect(normalizeForModeration("F4GGOT")).toBe("faggot");
    expect(normalizeForModeration("n i g g e r")).toBe("nigger");
    expect(normalizeForModeration("fuuuuck")).toBe("fuck"); // 3+ repeats collapse
    expect(normalizeForModeration("sh!t")).toBe("shit");
    expect(normalizeForModeration("Apple")).toBe("apple");
  });
});

describe("slurs are blocked everywhere", () => {
  it("blocks slurs as both a secret and a guess", () => {
    for (const w of ["faggot", "n1gger", "Tr4nny", "retard", "d y k e"]) {
      expect(isSlur(w)).toBe(true);
      expect(isBlockedSecret(w)).toBe(true);
      expect(isBlockedGuess(w)).toBe(true);
    }
  });
});

describe("vulgar words: blocked as a set secret, allowed as an organic guess", () => {
  it("blocks a deliberately-set crude secret", () => {
    expect(isBlockedSecret("cock")).toBe(true);
    expect(isBlockedSecret("bitch")).toBe(true);
    expect(isBlockedSecret("fuck")).toBe(true);
  });
  it("still lets a real guess through (cock=rooster, bitch=female dog)", () => {
    expect(isBlockedGuess("cock")).toBe(false);
    expect(isBlockedGuess("bitch")).toBe(false);
    expect(isSlur("cock")).toBe(false);
  });
});

describe("no false positives on innocent words (exact-token match)", () => {
  it("lets normal words play as secret and guess", () => {
    for (const w of ["class", "cockpit", "assassin", "grass", "bass", "shiitake", "scunthorpe", "orchard", "elephant"]) {
      expect(isBlockedSecret(w)).toBe(false);
      expect(isBlockedGuess(w)).toBe(false);
    }
  });
});
