import { describe, it, expect } from "vitest";
import { Bot, DEFAULT_BOT_CONFIG, type BotStep } from "./bot.js";
import { Room, normalizeWord } from "./room.js";

const CAP = DEFAULT_BOT_CONFIG.capMs;

/** Find a seed that yields willSolve === want, so tests aren't flaky. */
function seedFor(want: boolean, secret = "ember"): number {
  for (let s = 1; s < 5000; s++) {
    if (new Bot({ secret, seed: s }).solves() === want) return s;
  }
  throw new Error("no seed found");
}

describe("determinism", () => {
  it("same seed ⇒ identical plan", () => {
    const a = new Bot({ secret: "ember", seed: 42 }).plan_();
    const b = new Bot({ secret: "ember", seed: 42 }).plan_();
    expect(a).toEqual(b);
  });

  it("different seeds ⇒ (generally) different plans", () => {
    const a = JSON.stringify(new Bot({ secret: "ember", seed: 1 }).plan_());
    const b = JSON.stringify(new Bot({ secret: "ember", seed: 2 }).plan_());
    expect(a).not.toEqual(b);
  });
});

describe("solving bots", () => {
  const seed = seedFor(true);

  it("submit the real secret exactly once, as the final step", () => {
    const bot = new Bot({ secret: "Ember", seed });
    const plan = bot.plan_();
    const solveSteps = plan.filter((s) => s.solves);
    expect(solveSteps).toHaveLength(1);
    expect(solveSteps[0]).toBe(plan[plan.length - 1]);
    expect(normalizeWord(solveSteps[0]!.guess)).toBe("ember");
    expect(solveSteps[0]!.warmth).toBe(1);
  });

  it("only wrong (non-secret) guesses before the solve", () => {
    const bot = new Bot({ secret: "ember", seed });
    for (const step of bot.plan_().slice(0, -1)) {
      expect(normalizeWord(step.guess)).not.toBe("ember");
    }
  });

  it("solve lands inside the match cap", () => {
    const bot = new Bot({ secret: "ember", seed });
    const solve = bot.plan_().find((s) => s.solves)!;
    expect(solve.atMs).toBeGreaterThan(0);
    expect(solve.atMs).toBeLessThan(CAP);
  });
});

describe("non-solving bots (fairness — humans can win)", () => {
  const seed = seedFor(false);

  it("never submit the secret and never exceed a sub-1 warmth ceiling", () => {
    const bot = new Bot({ secret: "ember", seed });
    for (const step of bot.plan_()) {
      expect(step.solves).toBe(false);
      expect(normalizeWord(step.guess)).not.toBe("ember");
      expect(step.warmth).toBeLessThan(1);
    }
  });
});

describe("pacing", () => {
  it("first guess is not instant and steps are strictly time-ordered", () => {
    const bot = new Bot({ secret: "ember", seed: seedFor(true) });
    const plan = bot.plan_();
    expect(plan[0]!.atMs).toBeGreaterThanOrEqual(DEFAULT_BOT_CONFIG.minFirstGuessMs);
    for (let i = 1; i < plan.length; i++) {
      expect(plan[i]!.atMs).toBeGreaterThan(plan[i - 1]!.atMs);
    }
  });

  it("warmth trends upward overall (later half warmer than first half)", () => {
    const bot = new Bot({ secret: "ember", seed: seedFor(true) });
    const plan = bot.plan_();
    const mid = Math.floor(plan.length / 2);
    const avg = (xs: BotStep[]) => xs.reduce((a, s) => a + s.warmth, 0) / Math.max(1, xs.length);
    expect(avg(plan.slice(mid))).toBeGreaterThan(avg(plan.slice(0, mid)));
  });
});

describe("due() polling", () => {
  it("returns each step exactly once, in order, as time advances", () => {
    const bot = new Bot({ secret: "ember", seed: seedFor(true) });
    const total = bot.plan_().length;
    const collected: BotStep[] = [];
    for (let t = 0; t <= CAP; t += 1000) collected.push(...bot.due(t));
    expect(collected).toHaveLength(total);
    expect(collected).toEqual([...bot.plan_()]);
  });

  it("nothing is due before the first step's time", () => {
    const bot = new Bot({ secret: "ember", seed: seedFor(true) });
    expect(bot.due(0)).toEqual([]);
  });
});

describe("integration with Room (a solving bot beats an idle human)", () => {
  it("drives Room.applyGuess to a bot win", () => {
    const T0 = 500_000;
    const seed = seedFor(true);
    const bot = new Bot({ secret: "ember", seed });
    const room = new Room({
      roomId: "r",
      mode: "casual",
      secret: "ember",
      players: [
        { id: "HUMAN", kind: "human" },
        { id: "BOT", kind: "bot" },
      ],
      now: T0,
    });
    // Human does nothing; drive the bot to completion.
    for (let t = 0; t <= CAP && room.isActive(); t += 250) {
      for (const step of bot.due(t)) {
        room.applyGuess({ playerId: "BOT", guess: step.guess, warmth: step.warmth, now: T0 + t });
      }
    }
    const res = room.getResult()!;
    expect(res.reason).toBe("solved");
    expect(res.winner).toBe("BOT");
  });

  it("a human who solves before the bot's solve time still wins", () => {
    const T0 = 0;
    const seed = seedFor(true);
    const bot = new Bot({ secret: "ember", seed });
    const solveAt = bot.plan_().find((s) => s.solves)!.atMs;
    const room = new Room({
      roomId: "r",
      mode: "casual",
      secret: "ember",
      players: [
        { id: "HUMAN", kind: "human" },
        { id: "BOT", kind: "bot" },
      ],
      now: T0,
    });
    // Human solves one ms before the bot would.
    const res = room.applyGuess({ playerId: "HUMAN", guess: "ember", now: T0 + solveAt - 1 });
    const ended = res.find((e) => e.type === "ended");
    expect(ended).toBeDefined();
    expect(room.getResult()!.winner).toBe("HUMAN");
  });
});
