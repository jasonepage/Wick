// SPDX-License-Identifier: MPL-2.0
import { describe, it, expect } from "vitest";
import { PushRegistry } from "./pushsubs.js";

const TOKEN = "a".repeat(64);

describe("PushRegistry", () => {
  it("keeps a phone with the kinds it asked for, in its language", () => {
    const r = new PushRegistry(() => 1000);
    const kinds = r.upsert({ token: TOKEN.toUpperCase(), kid: "p1", lang: "fr", kinds: ["waiting", "nonsense", "surge"] });
    expect([...kinds!]).toEqual(["waiting", "surge"]);
    expect(r.size).toBe(1);
    expect(r.wanting("waiting")[0]?.lang).toBe("fr");
    expect(r.wanting("busy")).toHaveLength(0);
  });

  it("leaves the waiting player out of their own alert", () => {
    const r = new PushRegistry(() => 1000);
    r.upsert({ token: TOKEN, kid: "p1", kinds: ["waiting"] });
    r.upsert({ token: "b".repeat(64), kid: "p2", kinds: ["waiting"] });
    expect(r.wanting("waiting", "p1").map((s) => s.kid)).toEqual(["p2"]);
  });

  it("rejects bad tokens and ids, and an empty kinds list unregisters", () => {
    const r = new PushRegistry(() => 1000);
    expect(r.upsert({ token: "zz", kid: "p1", kinds: ["waiting"] })).toBeNull();
    expect(r.upsert({ token: TOKEN, kid: "", kinds: ["waiting"] })).toBeNull();
    expect(r.upsert({ token: TOKEN, kid: "p1", kinds: "waiting" })).toBeNull();
    r.upsert({ token: TOKEN, kid: "p1", kinds: ["waiting"] });
    expect(r.upsert({ token: TOKEN, kid: "p1", kinds: [] })?.size).toBe(0);
    expect(r.size).toBe(0);
  });

  it("forgets phones that stopped re-registering, and caps its size", () => {
    const clock = { t: 0 };
    const r = new PushRegistry(() => clock.t, 2);
    r.upsert({ token: TOKEN, kid: "p1", kinds: ["busy"] });
    clock.t = 10;
    r.upsert({ token: "b".repeat(64), kid: "p2", kinds: ["busy"] });
    expect(r.upsert({ token: "c".repeat(64), kid: "p3", kinds: ["busy"] })).toBeNull();
    clock.t = 15;
    expect(r.sweep(6)).toBe(1);
    expect(r.wanting("busy").map((s) => s.kid)).toEqual(["p2"]);
  });
});

import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

describe("PushRegistry on disk", () => {
  it("writes the list to a file and reads it back on the next boot", () => {
    const dir = mkdtempSync(join(tmpdir(), "wick-push-"));
    const file = join(dir, "push.json");
    try {
      const a = new PushRegistry(() => 1000);
      expect(a.persistTo(file)).toBe(0);
      a.upsert({ token: TOKEN, kid: "p1", lang: "de", kinds: ["waiting", "surge"] });
      a.saveNow();
      const rows = JSON.parse(readFileSync(file, "utf8"));
      expect(rows).toHaveLength(1);
      expect(rows[0].kid).toBe("p1");

      const b = new PushRegistry(() => 2000);
      expect(b.persistTo(file)).toBe(1);
      expect(b.wanting("surge")[0]?.lang).toBe("de");
      expect(b.wanting("busy")).toHaveLength(0);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
