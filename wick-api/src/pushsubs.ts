// SPDX-License-Identifier: MPL-2.0
//
//  pushsubs.ts: the phones that asked for race alerts, and which alerts.
//
//  A player turns alerts on in the app's Settings. The app sends us its push
//  token, its player id (so we never tell a player about their own queue), the
//  language it plays in, and the kinds of alert it wants:
//
//    waiting  one real person is waiting for a live race
//    busy     several people are waiting at once
//    surge    far more people are playing than usual for this time of week
//
//  Everything lives in memory. The app re-registers every time it comes to the
//  foreground, so a server restart only means a quiet spell until players open
//  the app again. Nothing here is written to disk and no entry carries a name,
//  an IP address or anything a player typed.
//

import { type Lang, langOf } from "./lang.js";

export const ALERT_KINDS = ["waiting", "busy", "surge"] as const;
export type AlertKind = (typeof ALERT_KINDS)[number];

export function isAlertKind(x: unknown): x is AlertKind {
  return typeof x === "string" && (ALERT_KINDS as readonly string[]).includes(x);
}

export interface Subscription {
  token: string;
  /** The player's per-install id (the same `kid` the live socket uses). */
  kid: string;
  lang: Lang;
  kinds: Set<AlertKind>;
  updatedAt: number;
}

/** An APNs device token: 64 hex characters today; allow a little room. */
export function isDeviceToken(x: unknown): x is string {
  return typeof x === "string" && /^[0-9a-fA-F]{32,200}$/.test(x);
}

export class PushRegistry {
  private readonly byToken = new Map<string, Subscription>();

  constructor(private readonly now: () => number, private readonly maxEntries = 50_000) {}

  /** Add or update a phone. Returns the stored kinds, or null when the request is bad. */
  upsert(input: { token: unknown; kid: unknown; lang?: unknown; kinds: unknown }): Set<AlertKind> | null {
    if (!isDeviceToken(input.token)) return null;
    if (typeof input.kid !== "string" || input.kid.length === 0 || input.kid.length > 80) return null;
    if (!Array.isArray(input.kinds)) return null;
    const kinds = new Set<AlertKind>();
    for (const k of input.kinds) if (isAlertKind(k)) kinds.add(k);
    const token = input.token.toLowerCase();
    if (kinds.size === 0) { this.byToken.delete(token); return kinds; }
    if (!this.byToken.has(token) && this.byToken.size >= this.maxEntries) return null;
    this.byToken.set(token, { token, kid: input.kid, lang: langOf(input.lang), kinds, updatedAt: this.now() });
    return kinds;
  }

  remove(token: string): void {
    this.byToken.delete(token.toLowerCase());
  }

  /** Everyone who wants `kind`, leaving out the player with id `exceptKid`. */
  wanting(kind: AlertKind, exceptKid?: string): Subscription[] {
    const out: Subscription[] = [];
    for (const s of this.byToken.values()) {
      if (s.kinds.has(kind) && s.kid !== exceptKid) out.push(s);
    }
    return out;
  }

  get size(): number {
    return this.byToken.size;
  }

  /** Forget phones that have not re-registered in `maxAgeMs` (the app
   *  re-registers on every foreground, so a month means the app is gone). */
  sweep(maxAgeMs: number): number {
    const cutoff = this.now() - maxAgeMs;
    let dropped = 0;
    for (const [token, s] of this.byToken) {
      if (s.updatedAt < cutoff) { this.byToken.delete(token); dropped++; }
    }
    return dropped;
  }
}
