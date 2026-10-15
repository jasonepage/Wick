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
