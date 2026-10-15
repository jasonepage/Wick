// SPDX-License-Identifier: MPL-2.0
//
//  apns.ts: sends push notifications to iPhones through Apple's push service
//  (APNs), with no library.
//
//  How Apple push works, in short: the app asks iOS for a device token and
//  sends it to us (POST /push/register). To notify that phone we open one
//  HTTP/2 connection to api.push.apple.com and POST a small JSON payload to
//  /3/device/<token>, signed with a token (a JWT) made from a private key you
//  download once from your Apple Developer account. Node has HTTP/2 and the
//  signing built in, so this file is the whole client.
//
//  Settings, all from the environment (see .env.example):
//    WICK_APNS_KEY       the .p8 key file's text (PEM). Newlines may be written
//                        as the two characters "\n", which is what a host's
//                        one-line env box needs.
//    WICK_APNS_KEY_ID    the 10 character key id shown next to the key
//    WICK_APNS_TEAM_ID   the 10 character Apple team id
//    WICK_APNS_BUNDLE_ID the app's bundle id (the "topic")
//    WICK_APNS_SANDBOX   set to 1 to push to debug builds from Xcode
//  Push is off unless the first four are set.
//
//  The signing token (`makeJwt`) is pure and tested. The network part is kept
//  small and reports one of three results so the caller can drop dead tokens.
//

import { createPrivateKey, sign, type KeyObject } from "node:crypto";
import http2, { type ClientHttp2Session } from "node:http2";

export interface ApnsConfig {
  keyPem: string;
  keyId: string;
  teamId: string;
  bundleId: string;
  sandbox: boolean;
}

/** What one push attempt came to. `bad_token` means the phone is gone: forget it. */
export type PushResult = "ok" | "bad_token" | "error";

export interface PushMessage {
  title: string;
  body: string;
  /** Pushes with the same id replace each other on the phone. */
  collapseId?: string;
  /** Seconds the push stays worth delivering if the phone is offline. */
  ttlSeconds?: number;
  /** Deep link the app opens, carried in the payload. */
  link?: string;
}

function b64url(data: Buffer | string): string {
  return Buffer.from(data).toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** The .p8 key text as given, or with "\n" written out, turned into a key. */
export function parseKey(pem: string): KeyObject {
  const text = pem.includes("\\n") ? pem.replace(/\\n/g, "\n") : pem;
  return createPrivateKey({ key: text.trim(), format: "pem" });
}

/** The bearer token APNs wants: ES256 over {kid} and {iss, iat}. Pure. */
export function makeJwt(key: KeyObject, keyId: string, teamId: string, nowSec: number): string {
  const header = b64url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const claims = b64url(JSON.stringify({ iss: teamId, iat: Math.floor(nowSec) }));
  const signature = sign("sha256", Buffer.from(`${header}.${claims}`), { key, dsaEncoding: "ieee-p1363" });
  return `${header}.${claims}.${b64url(signature)}`;
}

/** The JSON Apple expects for an alert push. Pure. */
export function payloadFor(m: PushMessage): string {
  const aps: Record<string, unknown> = { alert: { title: m.title, body: m.body }, sound: "default" };
  const body: Record<string, unknown> = { aps };
  if (m.link) body.link = m.link;
  return JSON.stringify(body);
}

export class ApnsClient {
  private readonly key: KeyObject;
  private session: ClientHttp2Session | null = null;
  private jwt = "";
  private jwtAt = -Infinity;
  private readonly host: string;

  constructor(private readonly cfg: ApnsConfig, private readonly now: () => number = Date.now) {
    this.key = parseKey(cfg.keyPem);
    this.host = cfg.sandbox ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
  }

  /** Apple accepts a token for an hour; we make a fresh one every 50 minutes. */
  private bearer(): string {
    const t = this.now();
    if (t - this.jwtAt > 50 * 60_000) {
      this.jwt = makeJwt(this.key, this.cfg.keyId, this.cfg.teamId, t / 1000);
      this.jwtAt = t;
    }
    return this.jwt;
  }

  private connection(): ClientHttp2Session {
    if (this.session && !this.session.closed && !this.session.destroyed) return this.session;
    const s = http2.connect(this.host);
    s.on("error", () => { if (this.session === s) this.session = null; });
    s.on("close", () => { if (this.session === s) this.session = null; });
    this.session = s;
    return s;
  }

  /** Push one message to one phone. Never throws. */
  send(deviceToken: string, m: PushMessage): Promise<PushResult> {
    return new Promise((resolve) => {
      let done = false;
      const finish = (r: PushResult): void => { if (!done) { done = true; resolve(r); } };
      try {
        const headers: Record<string, string> = {
          ":method": "POST",
          ":path": `/3/device/${deviceToken}`,
          "authorization": `bearer ${this.bearer()}`,
          "apns-topic": this.cfg.bundleId,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "apns-expiration": String(Math.floor(this.now() / 1000) + (m.ttlSeconds ?? 600)),
        };
        if (m.collapseId) headers["apns-collapse-id"] = m.collapseId;
        const req = this.connection().request(headers);
        let status = 0;
        let text = "";
        req.setEncoding("utf8");
        req.on("response", (h) => { status = Number(h[":status"] ?? 0); });
        req.on("data", (chunk: string) => { text += chunk; });
        req.on("end", () => {
          if (status === 200) { finish("ok"); return; }
          let reason = "";
          try { reason = String((JSON.parse(text) as { reason?: string }).reason ?? ""); } catch { /* not json */ }
          if (status === 410 || reason === "BadDeviceToken" || reason === "Unregistered" || reason === "DeviceTokenNotForTopic") {
            finish("bad_token");
          } else {
            console.warn(`[wick-api] apns ${status} ${reason || text.slice(0, 80)}`);
            finish("error");
          }
        });
        req.on("error", (e) => { console.warn(`[wick-api] apns request failed: ${String(e)}`); finish("error"); });
        req.setTimeout(10_000, () => { req.close(); finish("error"); });
        req.end(payloadFor(m));
      } catch (e) {
        console.warn(`[wick-api] apns send failed: ${String(e)}`);
        finish("error");
      }
    });
  }

  close(): void {
    this.session?.close();
    this.session = null;
  }
}

/** The client from the environment, or null when push is not configured. */
export function apnsFromEnv(env: Record<string, string | undefined>, now: () => number = Date.now): ApnsClient | null {
  const keyPem = env.WICK_APNS_KEY?.trim();
  const keyId = env.WICK_APNS_KEY_ID?.trim();
  const teamId = env.WICK_APNS_TEAM_ID?.trim();
  const bundleId = env.WICK_APNS_BUNDLE_ID?.trim();
  if (!keyPem || !keyId || !teamId || !bundleId) return null;
  try {
    return new ApnsClient({ keyPem, keyId, teamId, bundleId, sandbox: env.WICK_APNS_SANDBOX === "1" }, now);
  } catch (e) {
    console.warn(`[wick-api] WICK_APNS_KEY could not be read: ${String(e)}`);
    return null;
  }
}
