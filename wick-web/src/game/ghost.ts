//
//  ghost.ts — encode a finished round into a shareable "race me" link.
//
//  See PLAN_RACE_GHOST. The rule that shapes everything here:
//
//      SHAPE CROSSES OVER. CONTENT NEVER DOES.
//
//  The payload is numbers only. No guess, no question, no reply, no secret ever
//  enters it — so a link cannot leak the answer even to someone who decodes it
//  by hand, which they can, because it isn't encrypted and doesn't need to be.
//  That is a property of the format, not a promise about behaviour.
//
//  What Player 2 gets per action: WHEN it happened, whether it was a guess or a
//  question, whether it improved Player 1's best, and the heat band they stood at
//  afterwards. Enough to feel the race, useless for solving the word.
//
//  Encoding: each action packs into one integer,
//
//      (dt << 5) | (kind << 4) | (improved << 3) | band
//
//  where dt is deciseconds since the PREVIOUS action — deltas keep the numbers
//  small, so base36 gives 2-3 characters per action. A typical round is under a
//  hundred characters of URL, with no base64 needed since base36 plus separators
//  is already URL-safe.
//

/** 0 = Freezing … 5 = Boiling, 6 = Solved. Mirrors the bands in wickface.ts. */
export function bandOf(score0to100: number): number {
  const s = score0to100;
  if (s >= 100) return 6;
  if (s >= 60) return 5;
  if (s >= 45) return 4;
  if (s >= 30) return 3;
  if (s >= 18) return 2;
  if (s >= 8) return 1;
  return 0;
}

export interface GhostAction {
  /** Ms into the round. */
  t: number;
  /** 0 = guess, 1 = question. */
  kind: 0 | 1;
  /** Did this action improve their best? */
  improved: 0 | 1;
  /** Their BEST band so far, after this action. */
  band: number;
}

export interface GhostRun {
  /** "daily" → ref is a puzzle number; "practice" → ref is a pool index. */
  mode: "daily" | "practice";
  /** Puzzle number, or pool index. Never the word itself. */
  ref: number;
  solved: boolean;
  actions: GhostAction[];
}

const VERSION = 2;
/** A round longer than this is almost certainly junk or an attack. */
const MAX_ACTIONS = 300;

interface SourceGuess { warmth: number | null; correct: boolean; at?: number; seq?: number }
interface SourceReply { at?: number; seq?: number }

/**
 * Turn a played round into a run. Guesses and replies live in separate arrays;
 * `seq` is what interleaves them back into the order they actually happened.
 * Anything without a `seq` predates the recorder and is dropped — a partial
 * ordering would produce a ghost that lies.
 */
export function buildRun(
  mode: "daily" | "practice",
  ref: number,
  solved: boolean,
  guesses: SourceGuess[],
  replies: SourceReply[],
): GhostRun | null {
  type Row = { seq: number; at: number; kind: 0 | 1; score: number | null };
  const rows: Row[] = [];
  for (const g of guesses) {
    if (typeof g.seq !== "number" || typeof g.at !== "number") continue;
    rows.push({ seq: g.seq, at: g.at, kind: 0, score: g.correct ? 100 : g.warmth === null ? null : g.warmth * 100 });
  }
  for (const r of replies) {
    if (typeof r.seq !== "number" || typeof r.at !== "number") continue;
    rows.push({ seq: r.seq, at: r.at, kind: 1, score: null });
  }
  if (rows.length === 0) return null;
  rows.sort((a, b) => a.seq - b.seq);

  let best = -1;
  const actions: GhostAction[] = rows.slice(0, MAX_ACTIONS).map((row) => {
    let improved: 0 | 1 = 0;
    if (row.score !== null && row.score > best) { best = row.score; improved = 1; }
    return { t: row.at, kind: row.kind, improved, band: bandOf(Math.max(0, best)) };
  });
  return { mode, ref, solved, actions };
}

const b36 = (n: number) => Math.max(0, Math.round(n)).toString(36);

/** Pack a run into a URL-safe string. */
export function encodeRun(run: GhostRun): string {
  let prev = 0;
  const parts = run.actions.slice(0, MAX_ACTIONS).map((a) => {
    const dt = Math.max(0, Math.round((a.t - prev) / 100)); // deciseconds since the last action
    prev = a.t;
    const packed = dt * 32 + (a.kind << 4) + (a.improved << 3) + (a.band & 7);
    return b36(packed);
  });
  return `${VERSION}-${run.mode === "practice" ? "p" : "d"}${b36(run.ref)}-${run.solved ? 1 : 0}-${parts.join(".")}`;
}

/** Parse a run. Returns null for anything malformed — a bad link must fail
 *  quietly into a normal round, never into a broken board. */
export function decodeRun(raw: string): GhostRun | null {
  try {
    const s = (raw ?? "").trim();
    if (!s) return null;
    const bits = s.split("-");
    if (bits.length !== 4) return null;
    const [v, ref0, sv, body] = bits as [string, string, string, string];
    const ver = parseInt(v, 10);
    if (ver !== VERSION && ver !== 1) return null;
    if (sv !== "0" && sv !== "1") return null;

    // v1 carried a bare puzzle number and had no practice mode. Still decoded so
    // links shared before v2 keep working.
    let mode: "daily" | "practice" = "daily";
    let refStr = ref0;
    if (ver === 2) {
      const tag = ref0.charAt(0);
      if (tag !== "d" && tag !== "p") return null;
      mode = tag === "p" ? "practice" : "daily";
      refStr = ref0.slice(1);
    }
    const ref = parseInt(refStr, 36);
    if (!Number.isFinite(ref) || ref < 0 || ref > 1e6) return null;

    const chunks = body.length ? body.split(".") : [];
    if (chunks.length === 0 || chunks.length > MAX_ACTIONS) return null;

    let t = 0;
    const actions: GhostAction[] = [];
    for (const c of chunks) {
      const packed = parseInt(c, 36);
      if (!Number.isFinite(packed) || packed < 0) return null;
      const dt = Math.floor(packed / 32);
      const rest = packed % 32;
      const band = rest & 7;
      if (band > 6) return null;
      t += dt * 100;
      actions.push({
        t,
        kind: ((rest >> 4) & 1) as 0 | 1,
        improved: ((rest >> 3) & 1) as 0 | 1,
        band,
      });
    }
    return { mode, ref, solved: sv === "1", actions };
  } catch {
    return null;
  }
}

/** Total round length in ms. */
export function runDuration(run: GhostRun): number {
  return run.actions.length ? run.actions[run.actions.length - 1]!.t : 0;
}

/** "4:12" */
export function fmtDuration(ms: number): string {
  const total = Math.max(0, Math.round(ms / 1000));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}
