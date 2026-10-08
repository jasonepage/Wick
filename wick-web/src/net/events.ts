//
//  events.ts — fire-and-forget product events.
//
//  Everything interesting about the daily happens in this tab: the puzzle is
//  resolved locally and progress lives in localStorage, so the server sees only
//  a scattering of /warmth calls and cannot tell a solve from a give-up, or one
//  player from ten. It has to be told.
//
//  Deliberately cheap and deliberately fallible: sendBeacon when available (it
//  survives the tab closing, which is exactly when a solve happens), otherwise a
//  keepalive fetch. Nothing awaits it, nothing retries, and a failure is silent —
//  analytics must never delay or break a turn of the game.
//

export type WickEvent =
  | "daily_start" | "daily_solve" | "daily_giveup"
  | "share_grid" | "share_map" | "reveal_view"
  | "duel_open" | "practice_start"
  | "race_link_created" | "race_link_opened" | "race_finished";

interface EventBody {
  e: WickEvent;
  /** Anonymous per-browser id, hashed server-side before it is written. */
  id: string;
  /** Puzzle number. */
  n?: number;
  /** Guess count. */
  g?: number;
  p: "web";
}

let base = "";
let who = "";

/** Called once at boot with the API base and this tab's anonymous id. */
export function initEvents(httpBase: string, anonId: string): void {
  base = httpBase;
  who = anonId;
}

export function track(e: WickEvent, extra: { n?: number; g?: number } = {}): void {
  if (!base || !who) return;
  const body: EventBody = { e, id: who, p: "web", ...extra };
  const url = `${base}/event`;
  try {
    const blob = new Blob([JSON.stringify(body)], { type: "application/json" });
    // sendBeacon survives the page being closed — a solve is very often the last
    // thing someone does before closing the tab.
    if (typeof navigator.sendBeacon === "function" && navigator.sendBeacon(url, blob)) return;
    void fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
      keepalive: true,
    }).catch(() => { /* never surfaces */ });
  } catch {
    /* analytics is never worth an exception */
  }
}
