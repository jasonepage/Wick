import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { STARTER_QUESTIONS } from "./starterquestions.js";
import { isLeakAttempt } from "./keeper.js";

function fullTexts(path: string): string[] {
  const src = readFileSync(fileURLToPath(new URL(path, import.meta.url)), "utf8");
  return [...src.matchAll(/full: "([^"]*)"/g)].map((m) => m[1]!);
}

describe("starter questions", () => {
  it("match the web bank, in order", () => {
    expect([...STARTER_QUESTIONS]).toEqual(fullTexts("../../wick-web/src/game/starters.ts"));
  });
  it("match the iOS bank", () => {
    expect([...STARTER_QUESTIONS].sort()).toEqual(fullTexts("../../Hunch/Engine/StarterQuestions.swift").sort());
  });
  it("never trip the leak check", () => {
    for (const q of STARTER_QUESTIONS) expect(isLeakAttempt(q, "park")).toBe(false);
  });
});
