import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dailyForDay, dayIndex, dayStartMs } from "./daily.js";

describe("daily word (server copy of the web/iOS picker)", () => {
  it("matches the known puzzles", () => {
    expect(dailyForDay(9322).en).toBe("library"); // #1322, 2026-07-11
    expect(dailyForDay(9421).en).toBe("park");    // #1421 (BUGS_3.7.md; Oct 17 in US time)
  });

  it("counts whole UTC days since 2001", () => {
    // The daily turns over at midnight UTC: #1421 ran from Oct 18 00:00 UTC,
    // which is the afternoon of Oct 17 in the US.
    expect(dayIndex(Date.UTC(2026, 9, 18, 0, 0, 0))).toBe(9421);
    expect(dayIndex(Date.UTC(2026, 9, 18, 23, 59, 59))).toBe(9421);
    expect(dayIndex(Date.UTC(2026, 9, 17, 23, 59, 59))).toBe(9420);
    expect(dayStartMs(9421)).toBe(Date.UTC(2026, 9, 18));
  });

  it("reads the same pool as the web game", () => {
    const here = readFileSync(fileURLToPath(new URL("./dailypool.json", import.meta.url)), "utf8");
    const web = readFileSync(fileURLToPath(new URL("../../wick-web/src/game/dailyPool.json", import.meta.url)), "utf8");
    expect(JSON.parse(here)).toEqual(JSON.parse(web));
  });
});
