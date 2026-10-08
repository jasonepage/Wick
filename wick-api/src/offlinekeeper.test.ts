import { describe, it, expect } from "vitest";
import { deterministicAnswer, categoryOf } from "./offlinekeeper.js";

// Ground truth cross-checked against debug/wick_tracer.py.
describe("deterministic verdicts match the iOS engine", () => {
  const cases: Array<[string, string, "Yes" | "No" | "Sort of"]> = [
    ["library", "is it alive?", "No"],
    ["library", "is it man-made?", "Yes"],
    ["library", "is it a place?", "Yes"],
    ["book", "can you eat it?", "No"],
    ["book", "is it man-made?", "Yes"],
    ["dog", "is it an animal?", "Yes"],
    ["dog", "is it alive?", "Yes"],
    ["water", "is it a liquid?", "Yes"],
    ["ocean", "is it bigger than a car?", "Yes"],
  ];
  for (const [word, q, expected] of cases) {
    it(`${word} / "${q}" → ${expected}`, () => {
      const r = deterministicAnswer(word, q);
      expect(r?.verdict).toBe(expected);
      expect(r?.reply.length).toBeGreaterThan(0);
    });
  }
});

describe("deferral", () => {
  it("defers (null) for an untagged word", () => {
    expect(deterministicAnswer("zxqwv", "is it alive?")).toBeNull();
  });
  it("defers for an unmapped question", () => {
    expect(deterministicAnswer("library", "does it spark joy on tuesdays?")).toBeNull();
  });
  it("case-insensitive on the secret", () => {
    expect(deterministicAnswer("LIBRARY", "is it alive?")?.verdict).toBe("No");
  });
});

describe("category lookup", () => {
  it("knows tagged words", () => {
    expect(categoryOf("library")).toBe("structure");
    expect(categoryOf("book")).toBe("object");
    expect(categoryOf("dog")).toBe("animal");
  });
  it("returns null for unknown words", () => {
    expect(categoryOf("zxqwv")).toBeNull();
  });
});
