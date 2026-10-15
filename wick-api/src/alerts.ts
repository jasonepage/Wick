// SPDX-License-Identifier: MPL-2.0
//
//  alerts.ts: tell the maintainer when someone is waiting for a live race (3.5).
//
//  With few players online, a lone player in the Quick Match queue usually ends
//  up racing the practice bot. This sends a push to the maintainer's phone the
//  moment a real person starts waiting, so he can jump in and race them.
//
//  Delivery is ntfy (https://ntfy.sh): one HTTP POST to a topic, which the ntfy
//  phone app subscribes to. No account, no Apple push certificate. The topic
//  name works like a password (anyone who knows it can read the alerts), so it
//  lives only in the server's environment as WICK_NTFY_TOPIC. Unset = off.
//
//  An alert carries only the language and how many are waiting. Never a player
//  id, an IP address, or anything a player typed.
//
//  The decision logic (`QueueAlerter`) is pure with an injected clock, so it is
//  tested without a network. `ntfySender` is the thin network layer.
//

import type { Lang } from "./lang.js";

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
}

export const DEFAULT_QUEUE_ALERT_CONFIG: QueueAlertConfig = {
  cooldownMs: 10 * 60_000,
  busyAt: 3,
  busyCooldownMs: 30 * 60_000,
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
  onQueued(info: { lang: Lang; waiting: number }): void {
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
    },
  );
}
