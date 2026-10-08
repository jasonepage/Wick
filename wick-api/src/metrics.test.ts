import { describe, it, expect } from "vitest";
import { Metrics } from "./metrics.js";

describe("Metrics", () => {
  it("counts and snapshots", () => {
    const m = new Metrics();
    m.inc("a");
    m.inc("a");
    m.inc("b", 3);
    expect(m.get("a")).toBe(2);
    expect(m.get("b")).toBe(3);
    expect(m.get("missing")).toBe(0);
    expect(m.snapshot()).toEqual({ a: 2, b: 3 });
  });

  it("invite() bumps both the total and the per-kind counter", () => {
    const m = new Metrics();
    m.invite("created", "race");
    m.invite("created", "dare");
    m.invite("joined", "race");
    expect(m.get("invite.created")).toBe(2);
    expect(m.get("invite.created.race")).toBe(1);
    expect(m.get("invite.created.dare")).toBe(1);
    expect(m.get("invite.joined")).toBe(1);
    expect(m.get("invite.joined.race")).toBe(1);
  });

  it("snapshot keys are sorted (stable JSON)", () => {
    const m = new Metrics();
    m.inc("z");
    m.inc("a");
    expect(Object.keys(m.snapshot())).toEqual(["a", "z"]);
  });
});

describe("growth counters (3.3)", () => {
  it("derives solve rate, guesses to solve, share taps and arrivals from events", () => {
    const m = new Metrics();
    m.event("daily_start");
    m.event("daily_start");
    m.event("daily_start");
    m.event("daily_solve", 7);
    m.event("daily_solve", 9);
    m.event("daily_giveup", 12);
    m.event("share_grid");
    m.event("share_map");
    m.event("race_link_created");
    m.event("race_link_opened");
    expect(m.growth()).toEqual({ solveRate: 66.7, avgGuessesToSolve: 8, shareTaps: 3, raceLinkArrivals: 1 });
  });

  it("reports null rather than a fake number with no data", () => {
    expect(new Metrics().growth()).toEqual({ solveRate: null, avgGuessesToSolve: null, shareTaps: 0, raceLinkArrivals: 0 });
  });
});
