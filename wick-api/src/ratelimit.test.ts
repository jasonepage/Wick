import { describe, it, expect } from "vitest";
import { RateLimiter } from "./ratelimit.js";

describe("RateLimiter (token bucket)", () => {
  it("allows up to the burst capacity, then blocks", () => {
    let t = 1000;
    const rl = new RateLimiter(3, 1, () => t);
    expect(rl.take("a")).toBe(true);
    expect(rl.take("a")).toBe(true);
    expect(rl.take("a")).toBe(true);
    expect(rl.take("a")).toBe(false); // burst exhausted
  });

  it("refills over time at the sustained rate", () => {
    let t = 1000;
    const rl = new RateLimiter(2, 1, () => t); // 1 token/sec
    expect(rl.take("a")).toBe(true);
    expect(rl.take("a")).toBe(true);
    expect(rl.take("a")).toBe(false);
    t += 1000; // +1s → +1 token
    expect(rl.take("a")).toBe(true);
    expect(rl.take("a")).toBe(false);
  });

  it("never exceeds capacity when idle a long time", () => {
    let t = 1000;
    const rl = new RateLimiter(5, 10, () => t);
    t += 60_000; // long idle
    for (let i = 0; i < 5; i++) expect(rl.take("a")).toBe(true);
    expect(rl.take("a")).toBe(false); // capped at capacity, not 600
  });

  it("keys are independent", () => {
    let t = 1000;
    const rl = new RateLimiter(1, 1, () => t);
    expect(rl.take("a")).toBe(true);
    expect(rl.take("b")).toBe(true);
    expect(rl.take("a")).toBe(false);
    expect(rl.take("b")).toBe(false);
  });

  it("sweeps idle buckets", () => {
    let t = 1000;
    const rl = new RateLimiter(1, 1, () => t);
    rl.take("a");
    expect(rl.size()).toBe(1);
    t += 700_000;
    rl.sweep(600_000);
    expect(rl.size()).toBe(0);
  });
});
