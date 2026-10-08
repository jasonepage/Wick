//
//  client.ts — WickMatchClient: the browser's live-match connection.
//
//  Thin, typed wrapper over the browser WebSocket. Mirrors the iOS MatchClient:
//  open WSS /match, send queue/guess/question/heartbeat, surface the server's
//  paired/state/result/opponentLeft/error frames via callbacks. The UI never
//  touches raw frames.
//
//  Offline-safe spirit (C3): every failure path calls onClose/onError rather than
//  throwing into the UI, so the app can always fall back to a friendly state.
//

import type {
  ClientFrame,
  ServerFrame,
  MatchMode,
  QueueFrame,
  PairedFrame,
  QueuedFrame,
  StateFrame,
  ResultFrame,
  ScoredFrame,
  AnswerFrame,
  ErrorFrame,
} from "./protocol.ts";

export interface WickClientHandlers {
  onOpen?: () => void;
  onPaired?: (frame: PairedFrame) => void;
  /** 3.3: waiting for the shared start; `startsAt` is wall ms, `waitMs` a duration. */
  onQueued?: (frame: QueuedFrame) => void;
  onState?: (frame: StateFrame) => void;
  onResult?: (frame: ResultFrame) => void;
  onScored?: (frame: ScoredFrame) => void;
  onAnswer?: (frame: AnswerFrame) => void;
  onOpponentLeft?: () => void;
  onError?: (frame: ErrorFrame | { code: string; message: string }) => void;
  onClose?: (info: { clean: boolean }) => void;
}

export interface WickClientOptions {
  /** WS base, e.g. "wss://wick-api.onrender.com". */
  serverBase: string;
  /** Per-tab identity = the App Attest key id slot (phase 1 uses ?kid=). */
  kid: string;
  handlers: WickClientHandlers;
}

export class WickMatchClient {
  private ws: WebSocket | null = null;
  private readonly base: string;
  private readonly kid: string;
  private readonly h: WickClientHandlers;
  private heartbeatTimer: number | null = null;
  // Auto-reconnect on a flaky drop (mobile web especially). iOS gets server-side
  // reconnect grace (FR-17); this gives the web the same resilience by re-opening
  // and letting onOpen re-queue, which the server resumes into the live match.
  private closedByUs = false;
  private reconnectAttempts = 0;
  private readonly maxReconnects = 3;
  private reconnectTimer: number | null = null;

  constructor(opts: WickClientOptions) {
    this.base = opts.serverBase.replace(/\/+$/, "");
    this.kid = opts.kid;
    this.h = opts.handlers;
  }

  connect(): void {
    this.closedByUs = false;
    const url = `${this.base}/match?kid=${encodeURIComponent(this.kid)}`;
    let ws: WebSocket;
    try {
      ws = new WebSocket(url);
    } catch {
      this.h.onError?.({ code: "connect_failed", message: "Couldn't open a connection." });
      return;
    }
    this.ws = ws;

    ws.addEventListener("open", () => {
      this.reconnectAttempts = 0; // a good connection resets the retry budget
      this.startHeartbeat();
      this.h.onOpen?.();
    });

    ws.addEventListener("message", (ev) => {
      const frame = parseServerFrame(typeof ev.data === "string" ? ev.data : "");
      if (!frame) return;
      switch (frame.t) {
        case "paired":
          this.h.onPaired?.(frame);
          break;
        case "queued":
          this.h.onQueued?.(frame);
          break;
        case "state":
          this.h.onState?.(frame);
          break;
        case "result":
          this.h.onResult?.(frame);
          break;
        case "scored":
          this.h.onScored?.(frame);
          break;
        case "answer":
          this.h.onAnswer?.(frame);
          break;
        case "opponentLeft":
          this.h.onOpponentLeft?.();
          break;
        case "error":
          this.h.onError?.(frame);
          break;
      }
    });

    ws.addEventListener("error", () => {
      // Stay quiet while we still have retries left — only surface once we give up.
      if (!this.closedByUs && this.reconnectAttempts < this.maxReconnects) return;
      this.h.onError?.({ code: "socket_error", message: "Connection problem." });
    });

    ws.addEventListener("close", (ev) => {
      this.stopHeartbeat();
      // Unexpected drop → reconnect with backoff. Re-opening fires onOpen, which
      // re-queues; the server resumes an in-flight Race (FR-17). Only surface
      // onClose once the retry budget is spent, so the UI doesn't flash an error.
      if (!this.closedByUs && this.reconnectAttempts < this.maxReconnects) {
        this.reconnectAttempts++;
        this.reconnectTimer = window.setTimeout(() => this.connect(), 400 * this.reconnectAttempts);
        return;
      }
      this.h.onClose?.({ clean: ev.wasClean });
    });
  }

  /** Queue for a match. With `friendCode`, `create` declares intent (3.1 links):
   *  `true` = host a fresh invite (server rejects a colliding code with `code_taken`);
   *  `false` = join an existing one (server replies `no_such_invite` if it's dead);
   *  omitted = legacy first-hosts/second-joins. */
  queue(mode: MatchMode, friendCode?: string, create?: boolean): void {
    const frame: QueueFrame = { t: "queue", mode };
    if (friendCode) frame.friendCode = friendCode;
    if (create !== undefined) frame.create = create;
    this.send(frame);
  }

  guess(word: string, warmth?: number): void {
    const frame: ClientFrame =
      warmth === undefined ? { t: "guess", guess: word } : { t: "guess", guess: word, warmth };
    this.send(frame);
  }

  question(warmth: number): void {
    this.send({ t: "question", warmth });
  }

  /** Ask Wick a yes/no question mid-match; the server answers on the room secret
   *  and replies via `answer` (onAnswer). */
  ask(question: string): void {
    this.send({ t: "ask", question });
  }

  close(): void {
    this.closedByUs = true; // an intentional close must NOT trigger auto-reconnect
    if (this.reconnectTimer !== null) {
      window.clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    this.stopHeartbeat();
    this.ws?.close();
    this.ws = null;
  }

  private send(frame: ClientFrame): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(frame));
    }
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();
    // window.setInterval returns a number in the browser.
    this.heartbeatTimer = window.setInterval(() => this.send({ t: "heartbeat" }), 15_000);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer !== null) {
      window.clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }
}

/** Parse an inbound server frame; returns null if not a recognized frame. */
function parseServerFrame(raw: string): ServerFrame | null {
  if (!raw) return null;
  let obj: unknown;
  try {
    obj = JSON.parse(raw);
  } catch {
    return null;
  }
  if (typeof obj !== "object" || obj === null) return null;
  const t = (obj as { t?: unknown }).t;
  if (
    t === "paired" ||
    t === "state" ||
    t === "result" ||
    t === "scored" ||
    t === "answer" ||
    t === "opponentLeft" ||
    t === "error"
  ) {
    return obj as ServerFrame;
  }
  return null;
}
