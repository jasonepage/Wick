import { describe, it, expect } from "vitest";
import { QueueAlerter, ntfySender, queueAlerterFromEnv, type Alert } from "./alerts.js";

function setup(cfg = {}) {
  const sent: Alert[] = [];
  const clock = { t: 1_000_000 };
  const alerter = new QueueAlerter((a) => sent.push(a), () => clock.t, cfg);
  return { sent, clock, alerter };
}

describe("QueueAlerter", () => {
  it("alerts when someone starts waiting, with their language", () => {
    const { sent, alerter } = setup();
    alerter.onQueued({ lang: "es", waiting: 1 });
    expect(sent).toHaveLength(1);
    expect(sent[0]!.title).toBe("Someone is waiting for a live race");
    expect(sent[0]!.body).toContain("Spanish");
    expect(sent[0]!.priority).toBe(3);
  });

  it("stays quiet inside the cooldown, then alerts again", () => {
    const { sent, clock, alerter } = setup({ cooldownMs: 600_000 });
    alerter.onQueued({ lang: "en", waiting: 1 });
    clock.t += 599_999;
    alerter.onQueued({ lang: "en", waiting: 1 });
    expect(sent).toHaveLength(1);
    clock.t += 1;
    alerter.onQueued({ lang: "en", waiting: 1 });
    expect(sent).toHaveLength(2);
  });

  it("sends a louder busy alert even inside the normal cooldown", () => {
    const { sent, clock, alerter } = setup({ busyAt: 3 });
    alerter.onQueued({ lang: "en", waiting: 1 });
    clock.t += 1000;
    alerter.onQueued({ lang: "fr", waiting: 3 });
    expect(sent).toHaveLength(2);
    expect(sent[1]!.title).toBe("3 people are waiting for a live race");
    expect(sent[1]!.priority).toBe(4);
  });

  it("limits busy alerts to their own cooldown", () => {
    const { sent, clock, alerter } = setup({ busyAt: 2, busyCooldownMs: 1_800_000, cooldownMs: 600_000 });
    alerter.onQueued({ lang: "en", waiting: 2 });
    clock.t += 700_000;
    alerter.onQueued({ lang: "en", waiting: 4 });
    // Busy is still cooling down, so this falls back to a normal alert.
    expect(sent.map((a) => a.priority)).toEqual([4, 3]);
  });

  it("never puts an id or anything typed in the alert", () => {
    const { sent, alerter } = setup();
    alerter.onQueued({ lang: "zh", waiting: 1 });
    expect(JSON.stringify(sent)).not.toMatch(/kid|player|ip/i);
  });
});

describe("ntfySender", () => {
  it("posts the alert to the topic", async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const fakeFetch = (async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      return new Response("ok");
    }) as unknown as typeof fetch;
    ntfySender("https://ntfy.sh/", "my-topic", fakeFetch)({ title: "T", body: "B", priority: 4 });
    await new Promise((r) => setTimeout(r, 0));
    expect(calls[0]!.url).toBe("https://ntfy.sh/my-topic");
    expect(calls[0]!.init.body).toBe("B");
    expect((calls[0]!.init.headers as Record<string, string>).Title).toBe("T");
    expect((calls[0]!.init.headers as Record<string, string>).Priority).toBe("4");
  });

  it("swallows network errors", async () => {
    const failing = (async () => {
      throw new Error("offline");
    }) as unknown as typeof fetch;
    expect(() => ntfySender("https://ntfy.sh", "t", failing)({ title: "T", body: "B", priority: 3 })).not.toThrow();
    await new Promise((r) => setTimeout(r, 0));
  });
});

describe("queueAlerterFromEnv", () => {
  it("is off when no topic is set", () => {
    expect(queueAlerterFromEnv({}, () => 0)).toBeNull();
    expect(queueAlerterFromEnv({ WICK_NTFY_TOPIC: "  " }, () => 0)).toBeNull();
  });

  it("is on when a topic is set", () => {
    expect(queueAlerterFromEnv({ WICK_NTFY_TOPIC: "abc" }, () => 0)).toBeInstanceOf(QueueAlerter);
  });
});

import { AlertHub } from "./alerts.js";
import { PushRegistry } from "./pushsubs.js";

describe("AlertHub", () => {
  function setupHub() {
    const clock = { t: 1_000_000 };
    const registry = new PushRegistry(() => clock.t);
    const pushed: { token: string; title: string; collapseId?: string }[] = [];
    const results = new Map<string, "ok" | "bad_token" | "error">();
    const maintainerSent: Alert[] = [];
    const hub = new AlertHub({
      maintainer: new QueueAlerter((a) => maintainerSent.push(a), () => clock.t),
      registry,
      push: async (token, m) => { pushed.push({ token, title: m.title, collapseId: m.collapseId }); return results.get(token) ?? "ok"; },
      now: () => clock.t,
    });
    registry.upsert({ token: "a".repeat(64), kid: "A", lang: "en", kinds: ["waiting", "busy", "surge"] });
    registry.upsert({ token: "b".repeat(64), kid: "B", lang: "es", kinds: ["busy"] });
    return { clock, registry, pushed, results, maintainerSent, hub };
  }
  const flush = () => new Promise((r) => setTimeout(r, 0));

  it("tells the maintainer and the phones that asked, never the waiting player", async () => {
    const { pushed, maintainerSent, hub } = setupHub();
    hub.onQueued({ lang: "en", waiting: 1, playerId: "B" });
    await flush();
    expect(maintainerSent).toHaveLength(1);
    expect(pushed.map((p) => p.token[0])).toEqual(["a"]);
    expect(pushed[0]?.collapseId).toBe("wick-waiting");
    hub.onQueued({ lang: "en", waiting: 1, playerId: "A" });
    await flush();
    expect(pushed).toHaveLength(1);   // A is the one waiting now, and nobody else wants "waiting"
  });

  it("sends busy instead of waiting when enough people queue, with its own cooldown", async () => {
    const { clock, pushed, hub } = setupHub();
    hub.onQueued({ lang: "en", waiting: 3, playerId: "C" });
    await flush();
    expect(pushed.map((p) => p.token[0]).sort()).toEqual(["a", "b"]);
    expect(pushed[0]?.title).toContain("3 people");
    clock.t += 29 * 60_000;
    hub.onQueued({ lang: "en", waiting: 4, playerId: "C" });
    await flush();
    expect(pushed).toHaveLength(2);
    clock.t += 2 * 60_000;
    hub.onQueued({ lang: "en", waiting: 4, playerId: "C" });
    await flush();
    expect(pushed).toHaveLength(4);
  });

  it("pushes a surge once an hour and only when traffic is unusual", async () => {
    const { clock, pushed, maintainerSent, hub } = setupHub();
    hub.onTraffic({ active: 3, threshold: 4, unusual: false });
    hub.onTraffic({ active: 9, threshold: 4, unusual: true });
    await flush();
    expect(pushed).toHaveLength(1);
    expect(pushed[0]?.title).toBe("9 people are playing Wick right now");
    expect(maintainerSent).toHaveLength(1);
    clock.t += 30 * 60_000;
    hub.onTraffic({ active: 12, threshold: 4, unusual: true });
    await flush();
    expect(pushed).toHaveLength(1);
  });

  it("forgets a phone Apple says is gone", async () => {
    const { registry, results, hub } = setupHub();
    results.set("a".repeat(64), "bad_token");
    hub.onQueued({ lang: "en", waiting: 1, playerId: "Z" });
    await flush();
    expect(registry.size).toBe(1);
    expect(hub.stats.dropped).toBe(1);
  });
});
