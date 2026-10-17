// SPDX-License-Identifier: MPL-2.0
//
//  board.ts: today's race board on the web (3.6). Mirrors DailyBoard.swift.
//  A solved daily is sent once (the server keeps the first result per player),
//  the player's public row id and auto name are kept in localStorage, and a
//  result that could not be sent waits there until the board is next opened.
//

export interface BoardRow { rank: number; id: string; name: string; g: number; h: number; ms: number; lang: string; gu?: boolean }
export interface BoardSnapshot { n: number; total: number; top: BoardRow[]; me?: BoardRow }

const NAME_KEY = "wick.board.name";
const REROLL_KEY = "wick.board.r";
const PENDING_KEY = "wick.board.pending";
const idKey = (n: number) => `wick.board.id.${n}`;

function get(k: string): string | null { try { return localStorage.getItem(k); } catch { return null; } }
function put(k: string, v: string): void { try { localStorage.setItem(k, v); } catch { /* private mode */ } }
function drop(k: string): void { try { localStorage.removeItem(k); } catch { /* private mode */ } }

export function myBoardId(n: number): string | null { return get(idKey(n)); }
export function myBoardName(): string | null { return get(NAME_KEY); }
function reroll(): number { return Number(get(REROLL_KEY)) || 0; }

async function sendPending(httpBase: string, today: number): Promise<void> {
  const raw = get(PENDING_KEY);
  if (!raw) return;
  let body: { n: number } & Record<string, unknown>;
  try { body = JSON.parse(raw); } catch { drop(PENDING_KEY); return; }
  if (myBoardId(body.n) || body.n < today - 1) { drop(PENDING_KEY); return; }
  try {
    const res = await fetch(`${httpBase}/board`, {
      method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body),
    });
    const json = (await res.json()) as { ok?: boolean; id?: string; name?: string };
    if (json.ok && json.id) {
      put(idKey(body.n), json.id);
      if (json.name) put(NAME_KEY, json.name);
      drop(PENDING_KEY);
    } else if (res.status >= 400 && res.status < 500 && res.status !== 429) {
      drop(PENDING_KEY); // the server said no (too fast, not today)
    }
  } catch { /* offline: try again later */ }
}

/** Send a finished daily: a solve, or a give-up (`gu`). No hints on the web, so h is always 0. */
export async function submitBoard(
  httpBase: string,
  r: { n: number; g: number; ms: number; lang: string; kid: string; gu?: boolean },
): Promise<void> {
  if (myBoardId(r.n)) return;
  put(PENDING_KEY, JSON.stringify({ n: r.n, g: r.g, h: 0, ms: Math.round(r.ms), lang: r.lang, kid: r.kid, r: reroll(), gu: r.gu === true }));
  await sendPending(httpBase, r.n);
}

export async function fetchBoard(httpBase: string, n: number): Promise<BoardSnapshot | null> {
  await sendPending(httpBase, n);
  const me = myBoardId(n);
  try {
    const res = await fetch(`${httpBase}/board?n=${n}${me ? `&me=${me}` : ""}`, { cache: "no-store" });
    if (!res.ok) return null;
    return (await res.json()) as BoardSnapshot;
  } catch {
    return null;
  }
}

/** Roll a new auto name; renames today's entry too. Returns the new name. */
export async function rerollBoardName(httpBase: string, n: number, kid: string): Promise<string | null> {
  const next = reroll() + 1;
  try {
    const res = await fetch(`${httpBase}/board/name`, {
      method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ n, kid, r: next }),
    });
    const json = (await res.json()) as { ok?: boolean; name?: string };
    if (!json.ok || !json.name) return null;
    put(REROLL_KEY, String(next));
    put(NAME_KEY, json.name);
    return json.name;
  } catch {
    return null;
  }
}

/** "4:10", or "1:02:05" past an hour. */
export function fmtBoardTime(ms: number): string {
  const s = Math.floor(Math.max(0, ms) / 1000);
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
  const pad = (x: number) => String(x).padStart(2, "0");
  return h > 0 ? `${h}:${pad(m)}:${pad(sec)}` : `${m}:${pad(sec)}`;
}

export const BOARD_FLAG: Record<string, string> = { en: "🇺🇸", es: "🇪🇸", fr: "🇫🇷", it: "🇮🇹", de: "🇩🇪", zh: "🇨🇳" };
