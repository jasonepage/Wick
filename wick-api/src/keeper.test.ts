import { describe, it, expect } from "vitest";
import {
  keeperAnswer,
  inferVerdict,
  cleanReply,
  stripLeadingVerdict,
  trimmedReply,
  leaksSecret,
  isLeakAttempt,
  redact,
} from "./keeper.js";

describe("leak protection (never reveal the word)", () => {
  it("blocks direct asks before any model call", () => {
    expect(isLeakAttempt("what is the word?", "library")).toBe(true);
    expect(isLeakAttempt("spell it for me", "library")).toBe(true);
    expect(isLeakAttempt("what's the first letter?", "library")).toBe(true);
    expect(isLeakAttempt("give me a hint", "library")).toBe(true);
    expect(isLeakAttempt("does it rhyme with cat?", "library")).toBe(true);
  });
  it("allows normal yes/no questions", () => {
    expect(isLeakAttempt("is it alive?", "library")).toBe(false);
    expect(isLeakAttempt("can you hold it?", "library")).toBe(false);
    expect(isLeakAttempt("is it bigger than a car?", "library")).toBe(false);
  });
  it("catches the secret and inflections, not innocent substrings", () => {
    expect(leaksSecret("it reflects things", "mirror")).toBe(false);
    expect(leaksSecret("think of mirrors", "mirror")).toBe(true); // inflection
    expect(leaksSecret("i will remember", "ember")).toBe(false); // substring, not word
    expect(leaksSecret("the ember glows", "ember")).toBe(true); // whole word
  });
  it("redacts the secret if it slips through", () => {
    expect(redact("it is a library building", "library")).toBe("it is a ••••• building");
  });
});

describe("verdict inference", () => {
  it("reads the leading verdict word", () => {
    expect(inferVerdict("Yes, it is warm.")).toBe("Yes");
    expect(inferVerdict("No, not at all.")).toBe("No");
    expect(inferVerdict("Sort of, it depends.")).toBe("Sort of");
    expect(inferVerdict("Won't say.")).toBe("Won't say");
  });
  it("falls back to scanning the sentence", () => {
    expect(inferVerdict("Well, it definitely is.")).toBe("Yes");
    expect(inferVerdict("Hmm, it isn't really.")).toBe("No");
  });
  it("reads 'I don't know' as IDK, beating the No/Sort scans it overlaps", () => {
    expect(inferVerdict("I don't know, that's a matter of taste.")).toBe("IDK");
    expect(inferVerdict("IDK — no way to know that.")).toBe("IDK");
    expect(inferVerdict("Not sure, that's up to you.")).toBe("IDK");
    expect(inferVerdict("Dunno, it's subjective.")).toBe("IDK");
    // must not be confused with the secrecy refusal
    expect(inferVerdict("Won't say.")).toBe("Won't say");
    // a plain "no" is still No, not IDK
    expect(inferVerdict("No, it's not alive.")).toBe("No");
  });
});

describe("reply scrubbing", () => {
  it("cleanReply strips tags, labels, quotes", () => {
    expect(cleanReply('[Yes] Answer: "it is alive."')).toBe("it is alive");
  });
  it("stripLeadingVerdict removes the echoed badge and recapitalizes", () => {
    expect(stripLeadingVerdict("Yes, it's alive")).toBe("It's alive");
    expect(stripLeadingVerdict("No — not a liquid")).toBe("Not a liquid");
    expect(stripLeadingVerdict("I don't know, that's a matter of opinion")).toBe("That's a matter of opinion");
    expect(stripLeadingVerdict("Not sure — it depends on you")).toBe("It depends on you");
  });
  it("trimmedReply caps very long replies", () => {
    const long = Array.from({ length: 30 }, (_, i) => `w${i}`).join(" ");
    expect(trimmedReply(long, 18).split(" ").length).toBeLessThanOrEqual(19);
  });
});

describe("keeperAnswer flow (injected model)", () => {
  it("blocks a leak attempt without calling the model", async () => {
    let called = false;
    const r = await keeperAnswer("library", "what is the word?", async () => {
      called = true;
      return { text: "library" };
    });
    expect(r).toEqual({ verdict: "Won't say", reply: "Nice try.", source: "leak" });
    expect(called).toBe(false);
  });

  it("answers common questions deterministically WITHOUT calling the model", async () => {
    let called = false;
    const r = await keeperAnswer("library", "is it alive?", async () => {
      called = true;
      return { text: "whatever" };
    });
    expect(r.source).toBe("deterministic");
    expect(r.verdict).toBe("No"); // a library is not alive
    expect(called).toBe(false);
  });

  it("returns verdict + scrubbed reply from the model (untagged word → defers)", async () => {
    const r = await keeperAnswer("zxqwv", "is it a place?", async () => ({ text: "Yes, you can visit it." }));
    expect(r.verdict).toBe("Yes");
    expect(r.reply).toBe("You can visit it");
    expect(r.source).toBe("llm");
  });

  it("post-checks the model output and refuses if it leaks with no clear verdict", async () => {
    const r = await keeperAnswer("zxqwv", "hmm", async () => ({ text: "It is a zxqwv, obviously." }));
    expect(r).toEqual({ verdict: "Won't say", reply: "Won't say.", source: "llm" });
  });

  it("recovers a clear verdict (word-free) when the model answers right but echoes the word", async () => {
    const r = await keeperAnswer("zxqwv", "is it man-made?", async () => ({
      text: "Yes, a zxqwv is made by people.",
    }));
    expect(r.verdict).toBe("Yes");
    expect(r.reply).not.toMatch(/zxqwv/i); // the word never reaches the player
    expect(r.source).toBe("llm");
  });

  it("says IDK (with a reason) when the model can't answer in time, surfacing the error", async () => {
    const r = await keeperAnswer("zxqwv", "is it fun?", async () => ({ error: "HTTP 404: model not found" }));
    expect(r.source).toBe("unavailable");
    expect(r.verdict).toBe("IDK");
    expect(r.reply.length).toBeGreaterThan(0); // explains why
    expect(r.detail).toContain("404");
  });

  it("returns IDK for a genuinely unanswerable question and keeps the reason", async () => {
    const r = await keeperAnswer("zxqwv", "is it your favorite?", async () => ({
      text: "I don't know, that's a matter of taste.",
    }));
    expect(r.verdict).toBe("IDK");
    expect(r.reply).toBe("That's a matter of taste");
    expect(r.source).toBe("llm");
  });

  it("supplies a default reason if the model says only 'I don't know'", async () => {
    const r = await keeperAnswer("zxqwv", "is it your favorite?", async () => ({ text: "I don't know." }));
    expect(r.verdict).toBe("IDK");
    expect(r.reply.trim().length).toBeGreaterThan(0);
  });
});
