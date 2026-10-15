// SPDX-License-Identifier: MPL-2.0
import { describe, it, expect } from "vitest";
import { TrafficMonitor, hourOfWeek } from "./traffic.js";

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const WEEK = 7 * DAY;

describe("traffic", () => {
  it("files hours by weekday and hour, Sunday midnight first", () => {
    expect(hourOfWeek(Date.UTC(2026, 9, 11, 0, 0))).toBe(0);         // a Sunday
    expect(hourOfWeek(Date.UTC(2026, 9, 11, 13, 30))).toBe(13);
    expect(hourOfWeek(Date.UTC(2026, 9, 13, 2, 0))).toBe(2 * 24 + 2); // Tuesday 02:00
  });

  it("counts distinct players active in the last ten minutes", () => {
    const clock = { t: Date.UTC(2026, 9, 11, 12, 0) };
    const m = new TrafficMonitor(() => clock.t);
    m.seen("a"); m.seen("b"); m.seen("a");
    expect(m.activeNow()).toBe(2);
    clock.t += 11 * 60_000;
    m.seen("c");
    expect(m.activeNow()).toBe(1);
  });

  it("needs the floor with no history, then three times the usual peak for that hour", () => {
    const start = Date.UTC(2026, 9, 11, 0, 0);   // a Sunday, midnight UTC
    const clock = { t: start };
    const m = new TrafficMonitor(() => clock.t);
    expect(m.threshold()).toBe(4);
    // A normal week: two players every day at noon, one the rest of the time.
    for (let d = 0; d < 7; d++) {
      for (let h = 0; h < 24; h++) {
        clock.t = start + d * DAY + h * HOUR;
        const n = h === 12 ? 2 : 1;
        for (let i = 0; i < n; i++) m.seen(`p${d}-${h}-${i}`);
        m.tick();
      }
    }
    clock.t = start + WEEK + 12 * HOUR;   // next Sunday, noon
    m.tick();
    expect(m.expected()).toBe(2);
    expect(m.threshold()).toBe(6);
    for (let i = 0; i < 5; i++) m.seen(`x${i}`);
    expect(m.isUnusual()).toBe(false);
    m.seen("x5");
    expect(m.isUnusual()).toBe(true);
    clock.t = start + WEEK + 15 * HOUR;   // 15:00, where the usual peak is 1
    m.tick();
    expect(m.threshold()).toBe(4);
  });
});
