import { describe, it, expect } from "vitest";
import { isAllowedOrigin, parseOrigins } from "./abuse.js";

const ALLOWED = ["https://guesswick.com", "https://wick-api.onrender.com"];

describe("isAllowedOrigin (WS handshake gate)", () => {
  it("allows a native client (no Origin header)", () => {
    expect(isAllowedOrigin(undefined, ALLOWED)).toBe(true);
    expect(isAllowedOrigin("", ALLOWED)).toBe(true);
  });

  it("allows an exact allow-listed browser origin", () => {
    expect(isAllowedOrigin("https://guesswick.com", ALLOWED)).toBe(true);
    expect(isAllowedOrigin("https://wick-api.onrender.com", ALLOWED)).toBe(true);
  });

  it("allows localhost dev origins on any port/scheme", () => {
    expect(isAllowedOrigin("http://localhost:5173", ALLOWED)).toBe(true);
    expect(isAllowedOrigin("http://127.0.0.1:4173", ALLOWED)).toBe(true);
  });

  it("blocks a cross-origin website", () => {
    expect(isAllowedOrigin("https://evil.example", ALLOWED)).toBe(false);
    // A look-alike subdomain is NOT an exact match → blocked.
    expect(isAllowedOrigin("https://guesswick.com.evil.example", ALLOWED)).toBe(false);
  });

  it("denies a malformed Origin", () => {
    expect(isAllowedOrigin("not a url", ALLOWED)).toBe(false);
  });
});

describe("parseOrigins", () => {
  it("splits and trims a csv, ignoring blanks", () => {
    expect(parseOrigins(" a , b ,, c ", ["x"])).toEqual(["a", "b", "c"]);
  });
  it("falls back when unset or empty", () => {
    expect(parseOrigins(undefined, ["x", "y"])).toEqual(["x", "y"]);
    expect(parseOrigins("   ", ["x"])).toEqual(["x"]);
  });
});
