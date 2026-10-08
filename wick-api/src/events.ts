//
//  events.ts — durable, dependency-free product analytics.
//
//  /metrics has always been in-memory, so every deploy wiped it. That is why the
//  honest answer to "does anyone play Duel?" has been "no idea" — and why a
//  broken warmth oracle could sit in production unnoticed.
//
//  This writes one JSON line per event to stdout. Render retains logs, so the
//  data survives restarts and is greppable from the dashboard. No database, no
//  credentials, no new dependency, nothing to provision. If the volume ever
//  justifies a real warehouse, the same call sites can fan out to one — but not
//  measuring at all while waiting for that is the expensive option.
//
//  Privacy: the client's anonymous id is HASHED before it is written, and no
//  secret word, guess, or free text is ever logged. We only need to distinguish
//  players, not identify them.
//

import { createHash } from "node:crypto";

/** Grep target: `[wick-event]` in the Render log viewer. */
const PREFIX = "[wick-event]";

/** An allowlist, because /event is public. Without it, anyone could write
 *  arbitrary lines into our log stream — noise at best, log-injection at worst. */
const ALLOWED = new Set([
  "daily_start",
  "daily_solve",
  "daily_giveup",
  "share_grid",
  "share_map",
  "reveal_view",
  "duel_open",
  "dare_set",
  "practice_start",
  "race_link_created",
  "race_link_opened",
  "race_finished",
]);

export function isTrackedEvent(name: unknown): name is string {
  return typeof name === "string" && ALLOWED.has(name);
}

/** Short, stable, non-reversible id. Enough to count distinct players and
 *  returning players; not enough to identify one. */
export function anonId(raw: unknown): string {
  const s = typeof raw === "string" ? raw.trim().slice(0, 128) : "";
  if (!s) return "anon";
  return createHash("sha256").update(s).digest("hex").slice(0, 12);
}

export interface EventProps {
  /** Hashed client id. */
  id?: string;
  /** Daily puzzle number, when relevant. */
  n?: number;
  /** Guess count, when relevant. */
  g?: number;
  /** Platform hint: "web" | "ios". */
  p?: string;
}

/**
 * Emit one event. Never throws — analytics must not be able to break a request.
 * Set WICK_EVENTS=0 to silence.
 */
export function track(name: string, props: EventProps = {}): void {
  if (process.env.WICK_EVENTS === "0") return;
  try {
    const line = { e: name, ts: new Date().toISOString(), ...props };
    console.log(`${PREFIX} ${JSON.stringify(line)}`);
  } catch {
    /* analytics is never worth an exception */
  }
}
