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
