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
  /** 3.9: how alike this guess is to each word sent as `near`, same order.
   *  Missing when the server has no embeddings. */
  near?: (number | null)[];
}

export async function fetchWarmth(
  httpBase: string,
  secret: string,
  guess: string,
  /** The round's play language; the server ranks against that language's list. */
  lang: string = "en",
  /** 3.9: the player's own last guesses, newest first, for the strategic signal. */
  near: readonly string[] = [],
): Promise<WarmthResult | "not_a_word" | null> {
  try {
    const res = await fetch(`${httpBase}/warmth`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(near.length > 0 ? { secret, guess, lang, near } : { secret, guess, lang }),
    });
    if (!res.ok) return null;
    const json = (await res.json()) as { score?: unknown; rank?: unknown; notAWord?: unknown; near?: unknown };
    if (json.notAWord === true) return "not_a_word";
    if (typeof json.score !== "number") return null;
    const out: WarmthResult = { score: json.score, rank: typeof json.rank === "number" ? json.rank : null };
    if (Array.isArray(json.near)) out.near = json.near.map((x) => (typeof x === "number" ? x : null));
    return out;
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

export interface RevealResult {
  points: RevealPointDTO[];
  /** 3.9: pairwise similarity between the guesses, or null when unavailable. */
  similarity: (number | null)[][] | null;
}

/** Server-computed semantic-map layout for a finished round. Sends the player's own
 *  guesses (word + 0..100 score); the server embeds them and returns positions.
 *  Returns null on failure (the caller hides the map). */
export async function fetchReveal(
  httpBase: string,
  guesses: { word: string; score: number }[],
): Promise<RevealResult | null> {
  try {
    const res = await fetch(`${httpBase}/reveal`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ guesses }),
    });
    if (!res.ok) return null;
    const json = (await res.json()) as { points?: unknown; similarity?: unknown };
    if (!Array.isArray(json.points)) return null;
    return {
      points: json.points as RevealPointDTO[],
      similarity: Array.isArray(json.similarity) ? (json.similarity as (number | null)[][]) : null,
    };
  } catch {
    return null;
  }
}

export interface KeeperReply {
  verdict: string;
  reply: string;
}

/** One earlier question this round and the verdict Wick gave it. */
export interface AskedTurn {
  q: string;
  v: string;
}

/** Ask the Keeper a question about the secret. Returns null on failure. */
export async function askKeeper(
  httpBase: string,
  secret: string,
  question: string,
  /** The round's play language, plus the English form of the secret (the
   *  server leak-checks both forms). */
  lang: string = "en",
  secretEn?: string,
  /** 3.7: the round's earlier questions and verdicts, oldest first, so Wick
   *  stays consistent ("a place" then "touchable" is Yes). */
  history: AskedTurn[] = [],
): Promise<KeeperReply | null> {
  try {
    const res = await fetch(`${httpBase}/keeper`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ secret, question, lang, secretEn, history }),
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


/** Humans racing / waiting right now (GET /live), or null if the server is
 *  unreachable. The Race chooser shows it; it never blocks anything. */
export async function fetchLiveCounts(httpBase: string): Promise<{ racing: number; waiting: number } | null> {
  try {
    const res = await fetch(`${httpBase}/live`);
    if (!res.ok) return null;
    const j = (await res.json()) as { racing?: unknown; waiting?: unknown };
    const racing = typeof j.racing === "number" ? j.racing : 0;
    const waiting = typeof j.waiting === "number" ? j.waiting : 0;
    return { racing, waiting };
  } catch {
    return null;
  }
}
