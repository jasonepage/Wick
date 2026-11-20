//
//  giveup.test.ts: the Give up button in live races (3.9).
//

import { describe, it, expect } from "vitest";
import { MatchHub, type Client } from "./hub.js";
import type { ServerFrame, ClientFrame } from "./protocol.js";
import { parseClientFrame } from "./protocol.js";
import { GIVE_UP_AFTER_MS } from "./room.js";

class Fake implements Client {
  frames: ServerFrame[] = [];
  constructor(public id: string) {}
  send(f: ServerFrame): void { this.frames.push(f); }
  close(): void { /* no-op */ }
  last<T extends ServerFrame["t"]>(t: T): Extract<ServerFrame, { t: T }> | undefined {
    for (let i = this.frames.length - 1; i >= 0; i--) if (this.frames[i]!.t === t) return this.frames[i] as never;
    return undefined;
  }
}

const RADISH = { en: "radish", es: "rábano", fr: "radis", it: "ravanello", de: "rettich", zh: "萝卜" };

function race() {
  let t = 1_000_000;
  const hub = new MatchHub({
    now: () => t,
    attest: () => true,
    matchmaker: { wordProvider: () => RADISH },
  });
  const a = new Fake("A"), b = new Fake("B");
  hub.connect(a); hub.connect(b);
  hub.receive(a, { t: "queue", mode: "casual" } as ClientFrame);
  hub.receive(b, { t: "queue", mode: "casual", lang: "es" } as ClientFrame);
  return { hub, a, b, at: (ms: number) => { t = 1_000_000 + ms; } };
}

describe("give up", () => {
  it("is refused in the first 30 seconds", () => {
    const { hub, a, at } = race();
    at(GIVE_UP_AFTER_MS - 1);
    hub.receive(a, { t: "giveUp" });
    expect(a.last("error")?.code).toBe("too_early");
    expect(a.last("result")).toBeUndefined();
  });

  it("after that, the other player wins and both see the word", () => {
    const { hub, a, b, at } = race();
    at(GIVE_UP_AFTER_MS);
    hub.receive(a, { t: "giveUp" });
    const ra = a.last("result")!, rb = b.last("result")!;
    expect(ra.result.reason).toBe("forfeit");
    expect(ra.result.winner).toBe("B");
    expect(ra.result.gaveUp).toBe("A");
    expect(ra.word).toBe("radish");
    expect(rb.word).toBe("rábano");
  });

  it("parses from the wire", () => {
    expect(parseClientFrame('{"t":"giveUp"}')).toEqual({ t: "giveUp" });
  });
});
