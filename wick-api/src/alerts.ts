// SPDX-License-Identifier: MPL-2.0
//
//  alerts.ts: race alerts. Who gets told when something is happening in Wick.
//
//  Three things are worth a push:
//    waiting  a real person is waiting for a live race (with few players
//             online they would otherwise race the practice bot)
//    busy     several people are waiting at once
//    surge    far more people are playing than usual for this hour of the week
//             (see traffic.ts)
//
//  Two audiences:
//    1. The maintainer, through ntfy (https://ntfy.sh): one HTTP POST to a
//       topic the ntfy phone app subscribes to. No account, no Apple
//       certificate. The topic name works like a password, so it lives only in
//       the server's environment as WICK_NTFY_TOPIC. Unset = off. (`QueueAlerter`)
//    2. Players who turned on Race alerts in the app's Settings, through Apple
//       push (apns.ts), each for the kinds they picked (pushsubs.ts). The player
//       who is waiting is never told about their own wait. (`AlertHub`)
//
//  An alert carries only the language and a count. Never a player id, an IP
//  address, or anything a player typed.
//
//  The decision logic is pure with an injected clock, so it is tested without
//  a network. `ntfySender` is the thin network layer for ntfy.
//

import type { Lang } from "./lang.js";
import type { AlertKind, PushRegistry } from "./pushsubs.js";
import type { PushMessage, PushResult } from "./apns.js";

/** What the hub reports when a real person starts waiting in Quick Match. */
export interface QueueInfo {
  lang: Lang;
  /** Everyone waiting, including them. */
  waiting: number;
  /** The waiting player's id, so they are not told about themselves. */
  playerId?: string;
}

/** One push notification. */
export interface Alert {
  title: string;
  body: string;
  /** ntfy priority: 3 is normal, 4 is high (louder on the phone). */
  priority: 3 | 4;
}

export interface QueueAlertConfig {
  /** Minimum gap between "someone is waiting" alerts. */
  cooldownMs: number;
  /** This many people waiting at once counts as busy. */
  busyAt: number;
  /** Minimum gap between "busy" alerts. */
  busyCooldownMs: number;
  /** Minimum gap between "unusual traffic" alerts. */
  surgeCooldownMs: number;
}

export const DEFAULT_QUEUE_ALERT_CONFIG: QueueAlertConfig = {
  cooldownMs: 10 * 60_000,
  busyAt: 3,
  busyCooldownMs: 30 * 60_000,
  surgeCooldownMs: 60 * 60_000,
};

const LANG_NAMES: Record<Lang, string> = {
  en: "English",
  es: "Spanish",
  fr: "French",
  it: "Italian",
  de: "German",
  zh: "Chinese",
};

/** Decides when a queue event is worth a push, so the phone is not spammed. */
export class QueueAlerter {
  private lastAlertAt = -Infinity;
  private lastBusyAt = -Infinity;
  private lastSurgeAt = -Infinity;
  private readonly cfg: QueueAlertConfig;

  constructor(
    private readonly send: (alert: Alert) => void,
    private readonly now: () => number,
    cfg: Partial<QueueAlertConfig> = {},
  ) {
    this.cfg = { ...DEFAULT_QUEUE_ALERT_CONFIG, ...cfg };
  }

  /** A real person entered the Quick Match queue and is now waiting.
   *  `waiting` counts everyone waiting, including them. */
  onQueued(info: QueueInfo): void {
    const t = this.now();
    if (info.waiting >= this.cfg.busyAt && t - this.lastBusyAt >= this.cfg.busyCooldownMs) {
      this.lastBusyAt = t;
      this.lastAlertAt = t;
      this.send({
        title: `${info.waiting} people are waiting for a live race`,
        body: "The Wick queue is busy right now. Join at guesswick.com",
        priority: 4,
      });
      return;
    }
    if (t - this.lastAlertAt >= this.cfg.cooldownMs) {
      this.lastAlertAt = t;
      this.send({
        title: "Someone is waiting for a live race",
        body: `Playing in ${LANG_NAMES[info.lang]}. Join at guesswick.com before the bot does.`,
        priority: 3,
      });
    }
  }

  /** Far more people are playing than usual for this hour of the week. */
  onSurge(info: { active: number; threshold: number }): void {
    const t = this.now();
    if (t - this.lastSurgeAt < this.cfg.surgeCooldownMs) return;
    this.lastSurgeAt = t;
    this.send({
      title: `${info.active} people are playing Wick right now`,
      body: `That is unusual for this time of week (the bar was ${info.threshold}). Join at guesswick.com`,
      priority: 4,
    });
  }
}

// ── player push ─────────────────────────────────────────────────────────────

export interface PushAlertConfig {
  /** Minimum gap between pushes of each kind, to every phone at once. */
  cooldownMs: Record<AlertKind, number>;
  /** This many people waiting at once counts as busy. */
  busyAt: number;
  /** Deep link the push opens: the live race screen. */
  link: string;
}

export const DEFAULT_PUSH_ALERT_CONFIG: PushAlertConfig = {
  cooldownMs: { waiting: 10 * 60_000, busy: 30 * 60_000, surge: 60 * 60_000 },
  busyAt: 3,
  link: "wick://race",
};

/** The words on the phone. English for every language today; add a table per
 *  language here when the copy is translated (the app's own strings live in
 *  Loc.swift and fall back the same way). */
export function pushCopy(kind: AlertKind, n: { waiting?: number; active?: number }, _lang: Lang): { title: string; body: string } {
  switch (kind) {
    case "waiting":
      return { title: "Someone is waiting for a live race", body: "Race them before the practice flame does." };
    case "busy":
      return { title: `${n.waiting ?? 0} people are waiting for a live race`, body: "The queue is busy. Jump in now." };
    case "surge":
      return { title: `${n.active ?? 0} people are playing Wick right now`, body: "Way more than usual. Good time for a live race." };
  }
}

/** Fans each event out to the maintainer (ntfy) and to the phones that asked. */
export class AlertHub {
  private readonly cfg: PushAlertConfig;
  private readonly lastAt: Record<AlertKind, number> = { waiting: -Infinity, busy: -Infinity, surge: -Infinity };
  /** Pushes sent and tokens dropped, for the health page. */
  readonly stats = { sent: 0, dropped: 0, failed: 0 };

  constructor(
    private readonly deps: {
      maintainer: QueueAlerter | null;
      registry: PushRegistry | null;
      push: ((token: string, m: PushMessage) => Promise<PushResult>) | null;
      now: () => number;
    },
    cfg: Partial<PushAlertConfig> = {},
  ) {
    this.cfg = { ...DEFAULT_PUSH_ALERT_CONFIG, ...cfg };
  }

  onQueued(info: QueueInfo): void {
    this.deps.maintainer?.onQueued(info);
    if (info.waiting >= this.cfg.busyAt) {
      this.fan("busy", { waiting: info.waiting }, info.playerId);
    } else {
      this.fan("waiting", { waiting: info.waiting }, info.playerId);
    }
  }

  /** Called about once a minute with the traffic monitor's reading. */
  onTraffic(info: { active: number; threshold: number; unusual: boolean }): void {
    if (!info.unusual) return;
    this.deps.maintainer?.onSurge(info);
    this.fan("surge", { active: info.active });
  }

  private fan(kind: AlertKind, n: { waiting?: number; active?: number }, exceptKid?: string): void {
    const { registry, push, now } = this.deps;
    if (!registry || !push) return;
    const t = now();
    if (t - this.lastAt[kind] < this.cfg.cooldownMs[kind]) return;
    const subs = registry.wanting(kind, exceptKid);
    if (subs.length === 0) return;
    this.lastAt[kind] = t;
    for (const s of subs) {
      const copy = pushCopy(kind, n, s.lang);
      void push(s.token, { ...copy, collapseId: `wick-${kind}`, ttlSeconds: 600, link: this.cfg.link }).then((r) => {
        if (r === "ok") this.stats.sent++;
        else if (r === "bad_token") { registry.remove(s.token); this.stats.dropped++; }
        else this.stats.failed++;
      });
    }
  }
}

/** Sends an alert to an ntfy topic. Fire and forget: a failed push is logged
 *  and never affects the match. */
export function ntfySender(
  baseUrl: string,
  topic: string,
  fetchImpl: typeof fetch = fetch,
): (alert: Alert) => void {
  const url = `${baseUrl.replace(/\/+$/, "")}/${encodeURIComponent(topic)}`;
  return (alert) => {
    void fetchImpl(url, {
      method: "POST",
      body: alert.body,
      headers: {
        Title: alert.title,
        Priority: String(alert.priority),
        Tags: "fire",
        Click: "https://guesswick.com",
      },
    })
      .then((res) => {
        if (!res.ok) console.warn(`[wick-api] queue alert failed: HTTP ${res.status}`);
      })
      .catch((err: unknown) => {
        console.warn(`[wick-api] queue alert failed: ${String(err)}`);
      });
  };
}

/** Builds the alerter from environment variables, or returns null when
 *  WICK_NTFY_TOPIC is unset (alerts off, the default). */
export function queueAlerterFromEnv(
  env: Record<string, string | undefined>,
  now: () => number,
  fetchImpl: typeof fetch = fetch,
): QueueAlerter | null {
  const topic = env.WICK_NTFY_TOPIC?.trim();
  if (!topic) return null;
  const num = (key: string, fallback: number) => {
    const v = Number(env[key]);
    return Number.isFinite(v) && v > 0 ? v : fallback;
  };
  const d = DEFAULT_QUEUE_ALERT_CONFIG;
  return new QueueAlerter(
    ntfySender(env.WICK_NTFY_URL?.trim() || "https://ntfy.sh", topic, fetchImpl),
    now,
    {
      cooldownMs: num("WICK_ALERT_COOLDOWN_MS", d.cooldownMs),
      busyAt: num("WICK_ALERT_BUSY_AT", d.busyAt),
      busyCooldownMs: num("WICK_ALERT_BUSY_COOLDOWN_MS", d.busyCooldownMs),
      surgeCooldownMs: num("WICK_ALERT_SURGE_COOLDOWN_MS", d.surgeCooldownMs),
    },
  );
}
