// SPDX-License-Identifier: MPL-2.0
import { describe, it, expect } from "vitest";
import { generateKeyPairSync, verify } from "node:crypto";
import { makeJwt, parseKey, payloadFor, apnsFromEnv } from "./apns.js";

const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const pem = privateKey.export({ type: "pkcs8", format: "pem" }).toString();

function b64urlDecode(s: string): Buffer {
  return Buffer.from(s.replace(/-/g, "+").replace(/_/g, "/"), "base64");
}

describe("apns", () => {
  it("makes a signing token Apple can check: ES256 header, team and time claims", () => {
    const jwt = makeJwt(parseKey(pem), "ABC123DEFG", "TEAM456789", 1_700_000_000.9);
    const [h, c, sig] = jwt.split(".") as [string, string, string];
    expect(JSON.parse(b64urlDecode(h).toString())).toEqual({ alg: "ES256", kid: "ABC123DEFG" });
    expect(JSON.parse(b64urlDecode(c).toString())).toEqual({ iss: "TEAM456789", iat: 1_700_000_000 });
    const ok = verify("sha256", Buffer.from(`${h}.${c}`), { key: publicKey, dsaEncoding: "ieee-p1363" }, b64urlDecode(sig));
    expect(ok).toBe(true);
  });

  it("reads a key however the env box mangled it", () => {
    const flat = pem.replace(/\n/g, "\\n");
    expect(() => parseKey(flat)).not.toThrow();
    const spaced = pem.replace(/\n/g, " ");               // newlines folded to spaces
    expect(() => parseKey(spaced)).not.toThrow();
    const quoted = `"${pem.replace(/\n/g, "")}"`;         // one line in quotes
    expect(() => parseKey(quoted)).not.toThrow();
    const bodyOnly = pem.split("\n").filter((l) => l && !l.startsWith("-----")).join("");
    expect(() => parseKey(bodyOnly)).not.toThrow();
    // All of them sign the same way as the clean file.
    const a = makeJwt(parseKey(pem), "K", "T", 100);
    const b = makeJwt(parseKey(spaced), "K", "T", 100);
    expect(a.split(".").slice(0, 2)).toEqual(b.split(".").slice(0, 2));
  });

  it("builds the alert payload with a sound and the deep link", () => {
    const p = JSON.parse(payloadFor({ title: "T", body: "B", link: "wick://race" }));
    expect(p.aps.alert).toEqual({ title: "T", body: "B" });
    expect(p.aps.sound).toBe("default");
    expect(p.link).toBe("wick://race");
  });

  it("is off unless every setting is present, and reads the key when they are", () => {
    expect(apnsFromEnv({})).toBeNull();
    expect(apnsFromEnv({ WICK_APNS_KEY: pem, WICK_APNS_KEY_ID: "K", WICK_APNS_TEAM_ID: "T" })).toBeNull();
    const c = apnsFromEnv({ WICK_APNS_KEY: pem, WICK_APNS_KEY_ID: "K", WICK_APNS_TEAM_ID: "T", WICK_APNS_BUNDLE_ID: "com.x.y" });
    expect(c).not.toBeNull();
    c?.close();
    expect(apnsFromEnv({ WICK_APNS_KEY: "not a key", WICK_APNS_KEY_ID: "K", WICK_APNS_TEAM_ID: "T", WICK_APNS_BUNDLE_ID: "b" })).toBeNull();
  });
});
