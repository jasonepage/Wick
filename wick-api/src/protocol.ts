//
//  protocol.ts — the WS /match wire frames (SDS §4).
//
//  Small JSON frames. Metadata only — the client never sends the secret (it
//  doesn't have it), and the server never sends the secret, opponent guesses, or
//  anything that reveals the answer.
//

import type { OpponentKind, MatchMode, MatchResult, StateSnapshot } from "./room.js";
import type { DareRole, DareSnapshot, DareResult } from "./dare.js";

// ── client → server ───────────────────────────────────────────────────────────

export interface QueueFrame {
  t: "queue";
  mode: MatchMode;
  /** Optional private friend code (FR-9). */
  friendCode?: string;
  /** Invite intent for a friend code (3.1 links). `true` = CREATE/host a fresh
   *  invite — the server rejects a colliding code with `code_taken` so the client
   *  can regenerate. `false` = JOIN an existing invite — the server replies
   *  `no_such_invite` if none is live (so a stale/expired link fails fast instead of
   *  hanging). Omitted = legacy symmetric behaviour (first to present the code hosts,
   *  the second joins) — keeps pre-3.1 clients working unchanged. */
  create?: boolean;
}

/** A guess. `guess` is the player's own guessed word (used server-side to verify
 *  the solve against the secret — C8); `warmth` is the on-device hot/cold value. */
export interface GuessFrame {
  t: "guess";
  guess: string;
  warmth?: number;
}

/** A question outcome that only moved the warmth bar (no word revealed). */
export interface QuestionFrame {
  t: "question";
  warmth: number;
}

/** Ask Wick a yes/no question DURING a live match. The client can't score this
 *  itself (it never sees the match word), so the server runs the leak-proof
 *  Keeper on the room secret and replies with an `answer` frame (FR-19). */
export interface AskFrame {
  t: "ask";
  question: string;
}

/** Start or join a LIVE DARE by a shared code. The setter sends role "setter"
 *  plus the chosen `word`; the guesser sends role "guesser" (no word). They pair
 *  on the code, then the guesser plays with `guess`/`ask` while the setter
 *  spectates. */
export interface DareFrame {
  t: "dare";
  role: DareRole;
  code: string;
  /** Required for the setter (the word to guess); ignored for the guesser. */
  word?: string;
}

export interface HeartbeatFrame {
  t: "heartbeat";
}

export type ClientFrame =
  | QueueFrame
  | GuessFrame
  | QuestionFrame
  | AskFrame
  | DareFrame
  | HeartbeatFrame;

// ── server → client ───────────────────────────────────────────────────────────

export interface PairedFrame {
  t: "paired";
  roomId: string;
  /** Honesty label — "human" | "bot" | "ghost" (C9, FR-13). */
  opponentKind: OpponentKind;
  mode: MatchMode;
  /** Opaque per-match handle. NOT the answer. How the client turns this into a
   *  playable hidden board is an app-side contract (flagged for Jason). */
  wordId: string;
}

/** 3.3: sent to a casual Quick Match player who is now waiting. `startsAt` is
 *  the shared wall-clock start (ms since epoch); `waitMs` is the same thing as
 *  a duration, for clients whose clock may be off. If a human shows up sooner
 *  the race starts early. */
export interface QueuedFrame {
  t: "queued";
  startsAt: number;
  waitMs: number;
}

export interface StateFrame {
  t: "state";
  state: StateSnapshot;
}

export interface ResultFrame {
  t: "result";
  result: MatchResult;
  /** The secret, revealed ONLY here — the match is over, so it's safe to show
   *  (leak-proofing applies during play; the end screen reveals the word). */
  word: string;
}

export interface OpponentLeftFrame {
  t: "opponentLeft";
}

/** The server's authoritative warmth for a guess the player just made. */
export interface ScoredFrame {
  t: "scored";
  guess: string;
  /** 0..100 closeness (server-computed; the client renders it). */
  score: number;
  /** Contexto rank (# reference words closer than the guess), when available.
   *  The client reveals "#N" for a close guess, like the single-player board. */
  rank?: number;
  /** True when the guess isn't a real word (typo/keyboard mash) — the client
   *  removes it instead of scoring it, matching single-player. */
  notAWord?: boolean;
}

/** The Keeper's reply to an in-match `ask`. Metadata only — verdict + a short
 *  persona line, never the secret (the Keeper is leak-proof; C7). */
export interface AnswerFrame {
  t: "answer";
  /** Echo of the asked question, so the client can pair reply → bubble. */
  question: string;
  /** "Yes" | "No" | "Sort of" | "Won't say". */
  verdict: string;
  reply: string;
}

/** A live dare has begun — tells each player their role. */
export interface DareStartFrame {
  t: "dareStart";
  roomId: string;
  role: DareRole;
}

/** Streamed dare state (role-specific: the setter's includes the word). */
export interface DareStateFrame {
  t: "dareState";
  state: DareSnapshot;
}

/** The dare finished (solved or timed out); the word is revealed. */
export interface DareEndFrame {
  t: "dareEnd";
  result: DareResult;
}

export interface ErrorFrame {
  t: "error";
  code: string;
  message: string;
}

export type ServerFrame =
  | PairedFrame
  | QueuedFrame
  | StateFrame
  | ResultFrame
  | OpponentLeftFrame
  | ScoredFrame
  | AnswerFrame
  | DareStartFrame
  | DareStateFrame
  | DareEndFrame
  | ErrorFrame;

/** Parse an inbound text frame; returns null if it isn't a valid ClientFrame. */
export function parseClientFrame(raw: string): ClientFrame | null {
  let obj: unknown;
  try {
    obj = JSON.parse(raw);
  } catch {
    return null;
  }
  if (typeof obj !== "object" || obj === null) return null;
  const t = (obj as { t?: unknown }).t;
  switch (t) {
    case "queue": {
      const mode = (obj as { mode?: unknown }).mode;
      if (mode !== "casual" && mode !== "ranked") return null;
      const fc = (obj as { friendCode?: unknown }).friendCode;
      const frame: QueueFrame = { t: "queue", mode };
      if (typeof fc === "string") frame.friendCode = fc;
      const cr = (obj as { create?: unknown }).create;
      if (typeof cr === "boolean") frame.create = cr;
      return frame;
    }
    case "guess": {
      const guess = (obj as { guess?: unknown }).guess;
      if (typeof guess !== "string") return null;
      const w = (obj as { warmth?: unknown }).warmth;
      const frame: GuessFrame = { t: "guess", guess };
      if (typeof w === "number") frame.warmth = w;
      return frame;
    }
    case "question": {
      const w = (obj as { warmth?: unknown }).warmth;
      if (typeof w !== "number") return null;
      return { t: "question", warmth: w };
    }
    case "ask": {
      const q = (obj as { question?: unknown }).question;
      if (typeof q !== "string") return null;
      return { t: "ask", question: q };
    }
    case "dare": {
      const role = (obj as { role?: unknown }).role;
      const code = (obj as { code?: unknown }).code;
      if ((role !== "setter" && role !== "guesser") || typeof code !== "string") return null;
      const word = (obj as { word?: unknown }).word;
      const frame: DareFrame = { t: "dare", role, code };
      if (typeof word === "string") frame.word = word;
      return frame;
    }
    case "heartbeat":
      return { t: "heartbeat" };
    default:
      return null;
  }
}
