//
//  api.ts — small HTTP client for the wick-api service (non-WS calls).
//

/** Convert the ws/wss base to an http/https base for REST calls. */
export function httpBaseFrom(wsBase: string): string {
  return wsBase.replace(/^ws/, "http").replace(/\/+$/, "");
}

/**
 * Server-scored warmth for a guess (0..100), or null on failure (caller keeps
 * its placeholder). Single-player callers know the secret and send it.
 */
export interface WarmthResult {
  score: number;
  /** Contexto rank (1 = the answer, 2 = closest word), when the server provides it. */
  rank: number | null;
}

export async function fetchWarmth(
  httpBase: string,
  secret: string,
  guess: string,
): Promise<WarmthResult | "not_a_word" | null> {
  try {
    const res = await fetch(`${httpBase}/warmth`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ secret, guess }),
    });
    if (!res.ok) return null;
    const json = (await res.json()) as { score?: unknown; rank?: unknown; notAWord?: unknown };
    if (json.notAWord === true) return "not_a_word";
    if (typeof json.score !== "number") return null;
    return { score: json.score, rank: typeof json.rank === "number" ? json.rank : null };
  } catch {
    return null;
  }
}

/** One plotted guess on "The Reveal" map (server-computed layout). */
export interface RevealPointDTO {
  word: string;
  score: number;
  radius: number;
  angle: number;
  x: number;
  y: number;
}

/** Server-computed semantic-map layout for a finished round. Sends the player's own
 *  guesses (word + 0..100 score); the server embeds them and returns positions.
 *  Returns null on failure (the caller hides the map). */
export async function fetchReveal(
  httpBase: string,
  guesses: { word: string; score: number }[],
): Promise<RevealPointDTO[] | null> {
  try {
    const res = await fetch(`${httpBase}/reveal`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ guesses }),
    });
    if (!res.ok) return null;
    const json = (await res.json()) as { points?: unknown };
    return Array.isArray(json.points) ? (json.points as RevealPointDTO[]) : null;
  } catch {
    return null;
  }
}

export interface KeeperReply {
  verdict: string;
  reply: string;
}

/** Ask the Keeper a question about the secret. Returns null on failure. */
export async function askKeeper(
  httpBase: string,
  secret: string,
  question: string,
): Promise<KeeperReply | null> {
  try {
    const res = await fetch(`${httpBase}/keeper`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ secret, question }),
    });
    if (!res.ok) return null;
    const json = (await res.json()) as { verdict?: unknown; reply?: unknown };
    return {
      verdict: typeof json.verdict === "string" ? json.verdict : "",
      reply: typeof json.reply === "string" ? json.reply : "",
    };
  } catch {
    return null;
  }
}

