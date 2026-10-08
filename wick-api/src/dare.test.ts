import { describe, it, expect } from "vitest";
import { DareRoom, DEFAULT_DARE_CONFIG } from "./dare.js";

const T0 = 1_000_000;
const CAP = DEFAULT_DARE_CONFIG.capMs;

function room() {
  return new DareRoom({ roomId: "d1", word: "Library", setterId: "S", guesserId: "G", now: T0 });
}

describe("roles", () => {
  it("only the guesser may guess; the setter is a spectator", () => {
    const r = room();
    expect(r.canGuess("G")).toBe(true);
    expect(r.canGuess("S")).toBe(false);
    // A setter 'guess' is ignored — no state, no solve.
    expect(r.applyGuess({ playerId: "S", guess: "library", now: T0 + 1000 })).toEqual([]);
    expect(r.isActive()).toBe(true);
  });

  it("the setter sees the word; the guesser never does", () => {
    const r = room();
    r.applyGuess({ playerId: "G", guess: "book", now: T0 + 1000 });
    const setter = r.snapshotFor("S", T0 + 1000);
    const guesser = r.snapshotFor("G", T0 + 1000);
    expect(setter.word).toBe("library");
    expect(guesser.word).toBeUndefined();
    // Both can see the guessed words (the guesser typed them).
    expect(setter.guesses.map((g) => g.word)).toEqual(["book"]);
    expect(guesser.guesses.map((g) => g.word)).toEqual(["book"]);
  });
});

describe("guessing + warmth", () => {
  it("scores warmth asynchronously onto the matching guess", () => {
    const r = room();
    r.applyGuess({ playerId: "G", guess: "book", now: T0 + 1000 });
    expect(r.snapshotFor("G", T0 + 1000).guesses[0]!.warmth).toBeNull(); // pending
    r.applyWarmth({ guess: "book", warmth: 0.62 });
    const snap = r.snapshotFor("G", T0 + 1200);
    expect(snap.guesses[0]!.warmth).toBeCloseTo(0.62);
    expect(snap.bestWarmth).toBeCloseTo(0.62);
  });

  it("a correct guess ends the dare as solved, instantly", () => {
    const r = room();
    const ev = r.applyGuess({ playerId: "G", guess: "library", now: T0 + 4200 });
    expect(ev[0]!.type).toBe("ended");
    expect(r.isActive()).toBe(false);
    const res = r.snapshotFor("S", T0 + 4200).result!;
    expect(res.solved).toBe(true);
    expect(res.solvedAtMs).toBe(4200);
    expect(res.word).toBe("library");
  });

  it("is case-insensitive on the solve", () => {
    const r = room();
    const ev = r.applyGuess({ playerId: "G", guess: "  LIBRARY ", now: T0 + 500 });
    expect(ev[0]!.type).toBe("ended");
  });
});

describe("timeout", () => {
  it("fails the dare when the cap is reached without a solve", () => {
    const r = room();
    r.applyGuess({ playerId: "G", guess: "book", now: T0 + 1000 });
    expect(r.tick(T0 + CAP - 1)).toEqual([]); // still going
    const ev = r.tick(T0 + CAP);
    expect(ev[0]!.type).toBe("ended");
    const res = (ev[0] as { type: "ended"; result: import("./dare.js").DareResult }).result;
    expect(res.solved).toBe(false);
    expect(res.solvedAtMs).toBeNull();
    expect(res.word).toBe("library"); // revealed at the end
  });
});

describe("no leak until the end", () => {
  it("the guesser's live snapshots never contain the word", () => {
    const r = room();
    r.applyGuess({ playerId: "G", guess: "book", now: T0 + 1000 });
    r.applyWarmth({ guess: "book", warmth: 0.4 });
    const blob = JSON.stringify(r.snapshotFor("G", T0 + 1000)).toLowerCase();
    expect(blob).not.toContain("library");
    // …but the final result reveals it.
    r.tick(T0 + CAP);
    expect(r.snapshotFor("G", T0 + CAP).result!.word).toBe("library");
  });
});
