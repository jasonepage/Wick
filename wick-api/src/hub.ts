//
//  hub.ts — the live-match runtime glue (SDS §1/§5).
//
//  Ties the pure, tested cores together: Matchmaker (pairing) → Room (authoritative
//  match) → Bot (fill play). It is transport-agnostic — it talks to an abstract
//  `Client` (send/close), so the `ws` layer in server.ts adapts real sockets and
//  this module stays unit-testable with fake clients and an injected clock.
//
//  Time is injected via `now()`; the server calls `tick()` on an interval to
//  advance the 5-min cap (FR-33), reconnect grace (FR-17), bot-fill (FR-13), and
//  bot play. Nothing here reads the wall clock directly.
//
//  App Attest (FR-16): casual live is App-Attested but NOT entitlement-gated
//  (it's free). Real Apple attestation needs fixtures unavailable in this sandbox,
//  so `attest` is a seam defaulting to allow-all. >> FLAG: this MUST be replaced
//  with real App Attest verification before production; it is the anti-abuse gate.
//

import { Room, type MatchMode, type PlayerSeed } from "./room.js";
import { langOf, type Lang } from "./lang.js";
import type { MatchWord } from "./words.js";
import { Matchmaker, type Pairing, type MatchmakerDeps } from "./matchmaker.js";
import { Bot, type BotConfig } from "./bot.js";
import { DareRoom, type DareRole, type DareEvent } from "./dare.js";
import { isBlockedSecret, isBlockedGuess } from "./moderation.js";
import { isRealWord } from "./dictionary.js";
import { Metrics } from "./metrics.js";
import type { ClientFrame, ServerFrame, ClueFrame } from "./protocol.js";
import { dueSlot, pickKind, pickWarmerWord, UNKNOWN_RANK, type ClueLine } from "./clues.js";

/** How long an unjoined Dare invite stays open before it's swept (3.1) — mirrors
 *  the Matchmaker's friend-room TTL so an abandoned dare code doesn't leak forever. */
const DARE_INVITE_TTL_MS = 30 * 60_000;

/** A connected player. `id` is the App Attest key id (per-install identity, C2). */
export interface Client {
  id: string;
  send(frame: ServerFrame): void;
  close(): void;
}

export interface HubDeps {
  matchmaker: MatchmakerDeps;
  /** Authoritative clock (epoch ms). Server injects Date.now; tests inject a fake. */
  now: () => number;
  /** App Attest gate (FR-16). Default allow-all — REPLACE before production. */
  attest?: (client: Client, frame: ClientFrame) => boolean;
  /** Server-authoritative warmth for a guess → {score 0..100, rank?}. Injected
   *  (server wires the Gemini-backed scorer; tests inject a fake). Default score 0. */
  scoreWarmth?: (secret: string, guess: string, lang?: Lang) => Promise<{ score: number; rank?: number }>;
  /** Is the setter's word a real word? SYNCHRONOUS on purpose — onDare mutates
   *  pending-dare state and awaiting inside it would let a guesser's frame arrive
   *  before the setter is registered. Injected like scoreWarmth so the hub stays
   *  decoupled from the dictionary (and testable without one). */
  isPlayableSecret?: (word: string) => boolean;
  /** In-match Keeper: answer a yes/no question about the room secret without
   *  leaking it (server wires the Gemini Keeper; tests inject a fake). The
   *  last argument is the asker's earlier questions and verdicts this match,
   *  oldest first, so Wick stays consistent. Default: a polite "unavailable". */
  answerKeeper?: (secret: string, question: string, lang?: Lang, secretEn?: string, history?: AskedTurn[]) => Promise<{ verdict: string; reply: string }>;
  /** Difficulty knobs for the bot fill-in (FR-13). The server tunes the practice
   *  flame to be beatable; omitted → the bot's own DEFAULT_BOT_CONFIG. */
  botConfig?: Partial<BotConfig>;
  /** Invite-funnel counters (3.1). Shared with the Matchmaker; defaults to a
   *  throwaway instance so tests need not pass one. */
  metrics?: Metrics;
  /** 3.5: a real person started waiting in the Quick Match queue (not a friend
   *  code room). The server wires the maintainer's queue alert here. */
  onQueued?: (info: { lang: Lang; waiting: number; playerId: string }) => void;
  /** 3.6: a race guess was scored or a race question was answered. The server
   *  feeds the weekly Stats lists from here (see tally.ts). `secrets` are the
   *  room word in the seat's language and in English, so the caller can leave
   *  out anything that names the answer. */
  onPlayed?: (p: PlayedInfo) => void;
  /** 3.9 race clues: the reference words closest to a secret, closest first
   *  (index i has rank i + 2). Omitted → no warmer-word clues. */
  nearestWords?: (secret: string, lang: Lang) => Promise<string[]>;
  /** 3.9 race clues: Wick's written clue ladder for a seat (the secret in
   *  the seat's language, its English form, the menu language for a help
   *  line). Omitted → no written clues. */
  writeClues?: (secret: string, lang: Lang, secretEn: string, help?: string) => Promise<ClueLine[]>;
}

/** One guess or question from a live race, for the weekly Stats lists. */
export interface PlayedInfo {
  kind: "guess" | "question";
  text: string;
  lang: Lang;
  playerId: string;
  secrets: string[];
  /** Guesses only: the server's warmth. */
  score?: number;
  rank?: number;
}

interface ActiveRoom {
  room: Room;
  /** Bot seats: playerId → Bot driver. */
  bots: Map<string, Bot>;
  /** The match secret (English form), held hub-side so warmth can be scored server-authoritatively. */
  secret: string;
  /** The same concept in every language, for seats that hunt it in their own. */
  words: MatchWord;
  /** Each seat's language ("en" for bots and clients that sent none). */
  langs: Map<string, Lang>;
  /** The match mode, kept so a resuming/reconnecting client can be re-`paired`. */
  mode: MatchMode;
  /** Each player's questions this match and Wick's verdicts, oldest first. */
  asked?: Map<string, AskedTurn[]>;
  /** 3.9 timed race clues. */
  clues?: ClueState;
}

/** Per-race clue bookkeeping (3.9). Async inputs land in the maps when they
 *  resolve; a drop only uses what is ready at that moment. */
interface ClueState {
  /** Last 0-based clue slot handled (-1 before the first). */
  lastSlot: number;
  wordsSent: number;
  hintsSent: number;
  /** Each human seat's best server rank so far. */
  bestRank: Map<string, number>;
  /** Nearest reference words per seat language. */
  nearest: Map<Lang, string[]>;
  /** The written clue ladder per human seat. */
  ladders: Map<string, ClueLine[]>;
  /** Warmer words already given, per seat language. */
  usedWords: Map<Lang, Set<string>>;
  /** Clues each seat has been sent, re-sent on a reconnect. */
  sent: Map<string, ClueFrame[]>;
}

/** One question a player asked Wick and the verdict it got. */
export interface AskedTurn {
  q: string;
  v: string;
}

export class MatchHub {
  private readonly mm: Matchmaker;
  private readonly now: () => number;
  private readonly attest: (client: Client, frame: ClientFrame) => boolean;
  private readonly scoreWarmth: (secret: string, guess: string, lang?: Lang) => Promise<{ score: number; rank?: number }>;
  private readonly isPlayableSecret: (word: string) => boolean;
  private readonly answerKeeper: (
    secret: string,
    question: string,
    lang?: Lang,
    secretEn?: string,
    history?: AskedTurn[],
  ) => Promise<{ verdict: string; reply: string }>;
  /** The language each connected client last queued with. */
  private readonly clientLang = new Map<string, Lang>();
  /** The menu language each client last queued with (3.9 clue help line). */
  private readonly clientHelp = new Map<string, string>();
  private readonly nearestWords?: (secret: string, lang: Lang) => Promise<string[]>;
  private readonly writeClues?: (secret: string, lang: Lang, secretEn: string, help?: string) => Promise<ClueLine[]>;
  private readonly botConfig?: Partial<BotConfig>;
  private readonly onQueued: (info: { lang: Lang; waiting: number; playerId: string }) => void;
  private readonly onPlayed: (p: PlayedInfo) => void;
  private readonly metrics: Metrics;

  private readonly clients = new Map<string, Client>();
  private readonly rooms = new Map<string, ActiveRoom>();
  /** playerId → roomId, for active matches (kept across a disconnect for reconnect). */
  private readonly playerRoom = new Map<string, string>();

  // ── Live Dare ────────────────────────────────────────────────────────────────
  private readonly dareRooms = new Map<string, DareRoom>();
  /** playerId → dare roomId. */
  private readonly playerDare = new Map<string, string>();
  /** Open dares awaiting the second player, keyed by shared code. `createdAt` lets
   *  an abandoned invite expire (3.1). */
  private readonly pendingDares = new Map<
    string,
    { setterId?: string; guesserId?: string; word?: string; createdAt: number }
  >();
  private dareSeq = 0;

  constructor(deps: HubDeps) {
    this.metrics = deps.metrics ?? new Metrics();
    this.mm = new Matchmaker({ ...deps.matchmaker, metrics: this.metrics });
    this.now = deps.now;
    this.attest = deps.attest ?? (() => true);
    this.scoreWarmth = deps.scoreWarmth ?? (async () => ({ score: 0 }));
    // Fails open by default, matching scoreWarmth: a hub built without a
    // dictionary (every unit test) must not start rejecting dare words.
    this.isPlayableSecret = deps.isPlayableSecret ?? (() => true);
    this.answerKeeper =
      deps.answerKeeper ?? (async () => ({ verdict: "Won't say", reply: "Wick is quiet right now." }));
    this.botConfig = deps.botConfig;
    this.onQueued = deps.onQueued ?? (() => {});
    this.onPlayed = deps.onPlayed ?? (() => {});
    this.nearestWords = deps.nearestWords;
    this.writeClues = deps.writeClues;
  }

  // ── connection lifecycle ────────────────────────────────────────────────────

  connect(client: Client): void {
    this.clients.set(client.id, client);
    // Reconnect into an in-flight match (FR-17)?
    const roomId = this.playerRoom.get(client.id);
    if (roomId) {
      const ar = this.rooms.get(roomId);
      if (ar && ar.room.isActive()) {
        this.dispatch(roomId, ar.room.applyReconnect({ playerId: client.id, now: this.now() }));
        // Re-issue paired + state so the reconnecting client can resume the match
        // (FR-17): it may be a fresh app launch with no in-memory match state.
        this.sendResume(ar, client.id);
      }
    }
  }

  disconnect(client: Client): void {
    this.clients.delete(client.id);
    this.clientLang.delete(client.id);
    this.clientHelp.delete(client.id);
    // In a live dare? End it (no reconnect grace for dares in v1) and notify.
    const dareId = this.playerDare.get(client.id);
    if (dareId) {
      const dare = this.dareRooms.get(dareId);
      if (dare && dare.isActive()) this.dispatchDare(dareId, dare.forceEnd(this.now()));
      else this.cleanupDare(dareId);
      return;
    }
    // Drop any open dare this client was hosting/waiting on.
    for (const [code, p] of this.pendingDares) {
      if (p.setterId === client.id || p.guesserId === client.id) this.pendingDares.delete(code);
    }
    const roomId = this.playerRoom.get(client.id);
    if (roomId) {
      const ar = this.rooms.get(roomId);
      if (ar && ar.room.isActive()) {
        this.dispatch(roomId, ar.room.applyDisconnect({ playerId: client.id, now: this.now() }));
      }
      return;
    }
    // Not in a room — drop any queue/friend-room membership.
    this.mm.cancel(client.id);
  }

  receive(client: Client, frame: ClientFrame): void {
    if (!this.attest(client, frame)) {
      client.send({ t: "error", code: "attest_failed", message: "App attestation required." });
      client.close();
      return;
    }
    switch (frame.t) {
      case "queue":
        this.clientLang.set(client.id, langOf(frame.lang));
        if (frame.help) this.clientHelp.set(client.id, frame.help);
        else this.clientHelp.delete(client.id);
        this.onQueue(client, frame.mode, frame.friendCode, frame.create);
        return;
      case "dare":
        this.onDare(client, frame.role, frame.code, frame.word);
        return;
      case "guess":
        if (this.playerDare.has(client.id)) this.onDareGuess(client, frame.guess);
        else this.onGuess(client, frame.guess);
        return;
      case "question":
        this.onProgress(client, frame.warmth);
        return;
      case "ask":
        if (this.playerDare.has(client.id)) this.onDareAsk(client, frame.question);
        else this.onAsk(client, frame.question);
        return;
      case "heartbeat":
        return; // liveness only
    }
  }

  // ── Live Dare handlers ────────────────────────────────────────────────────────

  private onDare(client: Client, role: DareRole, code: string, word?: string): void {
    if (this.playerDare.has(client.id) || this.playerRoom.has(client.id)) {
      client.send({ t: "error", code: "already_in_match", message: "Already in a match." });
      return;
    }
    const key = code.trim().toUpperCase();
    if (!key) {
      client.send({ t: "error", code: "bad_code", message: "A dare code is required." });
      return;
    }
    if (role === "setter" && (!word || !word.trim())) {
      client.send({ t: "error", code: "no_word", message: "Pick a word to dare." });
      return;
    }
    // The setter's word is shown to the guesser at the reveal (user-generated
    // content) — reject slurs and crude/sexual words before the match can start.
    if (role === "setter" && isBlockedSecret(word!.trim())) {
      client.send({ t: "error", code: "blocked_word", message: "Please choose a different word." });
      return;
    }
    // The guesser's guesses have always been dictionary-checked (see onDareGuess),
    // but the word the WHOLE ROUND is scored against was not. A typo or a name
    // could be dared and every guess would read Freezing — which the guesser reads
    // as a broken game, not a hard word. Check it before the code is registered
    // and a link gets shared.
    if (role === "setter" && !this.isPlayableSecret(word!.trim())) {
      client.send({ t: "error", code: "not_a_word", message: "Wick doesn't know that word. Try another." });
      return;
    }
    // 3.1 invite intent (mirrors Race): the SETTER creates the code (must be free —
    // else `code_taken` so the client regenerates); the GUESSER joins it via a link
    // (must be live — else `no_such_invite` so a stale/expired dare link fails fast
    // instead of hanging). The setter always creates first, then shares the link.
    const existing = this.pendingDares.get(key);
    if (role === "setter") {
      if (existing?.setterId && existing.setterId !== client.id) {
        this.metrics.invite("code_taken", "dare");
        client.send({ t: "error", code: "code_taken", message: "That code's already daring someone. Tap Dare for a fresh one." });
        return;
      }
      const wasNewSetter = !existing?.setterId;
      const pending = existing ?? { createdAt: this.now() };
      pending.setterId = client.id;
      pending.word = word!.trim();
      this.pendingDares.set(key, pending);
      if (wasNewSetter) this.metrics.invite("created", "dare");
    } else {
      if (!existing?.setterId || !existing.word) {
        this.metrics.invite("no_such_invite", "dare");
        client.send({ t: "error", code: "no_such_invite", message: "That dare isn't active anymore. Ask your friend for a new link." });
        return;
      }
      existing.guesserId = client.id;
    }
    this.maybeStartDare(key);
  }

  /** Start the dare once a code has both a setter (with word) and a guesser. */
  private maybeStartDare(key: string): void {
    const p = this.pendingDares.get(key);
    if (p && p.setterId && p.guesserId && p.word) {
      this.pendingDares.delete(key);
      this.startDare(p.setterId, p.guesserId, p.word);
    }
  }

  private startDare(setterId: string, guesserId: string, word: string): void {
    this.metrics.invite("joined", "dare");
    const roomId = `dare-${++this.dareSeq}`;
    const dare = new DareRoom({ roomId, word, setterId, guesserId, now: this.now() });
    this.dareRooms.set(roomId, dare);
    this.playerDare.set(setterId, roomId);
    this.playerDare.set(guesserId, roomId);
    for (const [id, role] of [
      [setterId, "setter"] as const,
      [guesserId, "guesser"] as const,
    ]) {
      this.clients.get(id)?.send({ t: "dareStart", roomId, role });
    }
    this.fanOutDareState(dare);
  }

  private onDareGuess(client: Client, guess: string): void {
    const dare = this.dareOf(client.id);
    if (!dare) return;
    if (!dare.canGuess(client.id)) return; // setter can't guess
    // The setter spectates the guesser's words live — drop slurs so a guess can't
    // be used to harass. Vulgar-but-legit guesses ("cock" for a rooster) still play.
    if (isBlockedGuess(guess)) {
      client.send({ t: "error", code: "blocked_word", message: "Let's keep it friendly. Try another word." });
      return;
    }
    // Reject non-words (Dare is snapshot-driven, so it simply isn't added; the
    // error tells the guesser why). The exact secret is always allowed.
    if (guess.trim().toLowerCase() !== dare.word().trim().toLowerCase() && !isRealWord(guess)) {
      client.send({ t: "error", code: "not_a_word", message: "That's not a word I know. Try another." });
      return;
    }
    const roomId = dare.roomId;
    this.dispatchDare(roomId, dare.applyGuess({ playerId: client.id, guess, now: this.now() }));
    if (dare.isActive()) {
      void this.scoreWarmth(dare.word(), guess).then(({ score, rank }) => {
        const cur = this.dareRooms.get(roomId);
        if (!cur || !cur.isActive()) return;
        this.dispatchDare(roomId, cur.applyWarmth({ guess, warmth: score / 100, rank }));
      });
    }
  }

  private onDareAsk(client: Client, question: string): void {
    const dare = this.dareOf(client.id);
    if (!dare || !dare.canGuess(client.id)) return; // only the guesser asks Wick
    const playerId = client.id;
    void this.answerKeeper(dare.word(), question).then(({ verdict, reply }) => {
      this.clients.get(playerId)?.send({ t: "answer", question, verdict, reply });
    });
  }

  // ── frame handlers ──────────────────────────────────────────────────────────

  private onQueue(client: Client, mode: MatchMode, friendCode?: string, create?: boolean): void {
    if (this.playerDare.has(client.id)) {
      client.send({ t: "error", code: "already_in_match", message: "Already in a dare." });
      return;
    }
    if (this.playerRoom.has(client.id)) {
      // Already in a match → treat a queue as a RESUME request rather than an
      // error: re-issue paired + state so a client that quit and came back (its
      // in-memory match gone) rejoins the live match instead of getting stuck.
      const ar = this.roomOf(client.id);
      if (ar && ar.room.isActive()) {
        this.sendResume(ar, client.id);
        return;
      }
      // Stale mapping (room already ended) — clear it and let them queue fresh.
      this.playerRoom.delete(client.id);
    }
    // 3.1 invite intent: with a link-based invite the client says whether it is
    // CREATING the code (must be free) or JOINING one (must be live), so a code
    // collision or a stale link fails fast instead of silently cross-joining or
    // hanging. Omitted `create` keeps the legacy first-hosts/second-joins behaviour.
    if (friendCode !== undefined && create !== undefined) {
      const host = this.mm.friendRoomHost(friendCode);
      if (create && host && host !== client.id) {
        this.metrics.invite("code_taken", "race");
        client.send({ t: "error", code: "code_taken", message: "That code's already in use. Tap Invite for a fresh one." });
        return;
      }
      if (!create && !host) {
        this.metrics.invite("no_such_invite", "race");
        client.send({ t: "error", code: "no_such_invite", message: "That invite isn't active anymore. Ask your friend for a new link." });
        return;
      }
    }

    const now = this.now();
    const pairing = this.mm.enqueue({ playerId: client.id, mode, friendCode, now });
    if (pairing) {
      this.startMatch(pairing);
      return;
    }
    // 3.3 shared start: tell a waiting Quick Match player when the race starts
    // so the client can count down to it (friend rooms have no schedule).
    if (!friendCode) {
      const startsAt = this.mm.startAtFor(client.id);
      if (startsAt !== null) {
        client.send({ t: "queued", startsAt, waitMs: Math.max(0, startsAt - now) });
      }
      this.onQueued({
        lang: this.clientLang.get(client.id) ?? "en",
        waiting: this.mm.waitingCount(mode),
        playerId: client.id,
      });
    }
  }

  private onGuess(client: Client, guess: string): void {
    const ar = this.roomOf(client.id);
    if (!ar) {
      client.send({ t: "error", code: "no_match", message: "Not in a match." });
      return;
    }
    const playerId = client.id;
    const roomId = ar.room.roomId;
    const lang = ar.langs.get(playerId) ?? "en";
    const secret = ar.room.secretFor(playerId);
    // 0) Reject non-words (typo/keyboard mash) before they count — the guess must
    //    be a real word in the seat's language, unless it exactly matches the
    //    secret. Matches iOS + web single-player. The client removes the guess on `notAWord`.
    if (guess.trim().toLowerCase() !== secret.trim().toLowerCase() && !isRealWord(guess, lang)) {
      client.send({ t: "scored", guess, score: 0, notAWord: true });
      return;
    }
    // 1) Solve check + guess count are INSTANT and authoritative — never wait on
    //    embedding latency for the winning guess (the race depends on it, C8).
    //    Client-reported warmth is ignored (server is authoritative).
    this.dispatch(roomId, ar.room.applyGuess({ playerId, guess, now: this.now() }));

    // 2) If the match is still going, score warmth server-side (async) and fan it
    //    out: update the room's progress (opponent sees it) and tell the guesser
    //    their own score via `scored`.
    if (ar.room.isActive()) {
      void this.scoreWarmth(secret, guess, lang).then(({ score, rank }) => {
        this.onPlayed({ kind: "guess", text: guess, lang, playerId, secrets: [secret, ar.secret], score, rank });
        const cur = this.rooms.get(roomId);
        if (!cur || !cur.room.isActive()) return;
        if (cur.clues && rank !== undefined && rank > 0) {
          const best = cur.clues.bestRank.get(playerId) ?? UNKNOWN_RANK;
          if (rank < best) cur.clues.bestRank.set(playerId, rank);
        }
        this.dispatch(
          roomId,
          cur.room.applyProgress({ playerId, warmth: score / 100, now: this.now() }),
        );
        this.clients.get(playerId)?.send({ t: "scored", guess, score, rank });
      });
    }
  }

  private onProgress(client: Client, warmth: number): void {
    const ar = this.roomOf(client.id);
    if (!ar) {
      client.send({ t: "error", code: "no_match", message: "Not in a match." });
      return;
    }
    this.dispatch(
      ar.room.roomId,
      ar.room.applyProgress({ playerId: client.id, warmth, now: this.now() }),
    );
  }

  /** Ask Wick a yes/no question mid-match. The Keeper runs server-side on the
   *  room secret (the asker never sees the word) and the answer goes back only
   *  to the asker — it reveals nothing to the opponent (progress-only, FR-8).
   *  Asking costs time, not warmth: the bar still moves only on guesses. */
  private onAsk(client: Client, question: string): void {
    const ar = this.roomOf(client.id);
    if (!ar) {
      client.send({ t: "error", code: "no_match", message: "Not in a match." });
      return;
    }
    const playerId = client.id;
    const lang = ar.langs.get(playerId) ?? "en";
    const secret = ar.room.secretFor(playerId);
    if (!ar.asked) ar.asked = new Map();
    const asked = ar.asked.get(playerId) ?? [];
    ar.asked.set(playerId, asked);
    const history = asked.slice(-12);
    void this.answerKeeper(secret, question, lang, ar.secret, history).then(({ verdict, reply }) => {
      if (verdict) asked.push({ q: question, v: verdict });
      this.onPlayed({ kind: "question", text: question, lang, playerId, secrets: [secret, ar.secret] });
      // The player may have finished/left while the Keeper was thinking.
      this.clients.get(playerId)?.send({ t: "answer", question, verdict, reply });
    });
  }

  // ── the periodic tick ───────────────────────────────────────────────────────

  /** Advance matchmaking + all rooms. Called on an interval by the server. */
  tick(): void {
    const now = this.now();

    // 1) Bot-fill / late human pairings.
    for (const pairing of this.mm.tick(now)) this.startMatch(pairing);

    // 2) Drive each active room: bots, cap/grace, then fan out state.
    for (const [roomId, ar] of [...this.rooms]) {
      if (!ar.room.isActive()) continue;
      const elapsed = now - ar.room.t0Wall;
      for (const [botId, bot] of ar.bots) {
        for (const step of bot.due(elapsed)) {
          if (!ar.room.isActive()) break;
          this.dispatch(
            roomId,
            ar.room.applyGuess({ playerId: botId, guess: step.guess, warmth: step.warmth, now }),
          );
        }
      }
      if (ar.room.isActive()) {
        this.dispatch(roomId, ar.room.tick(now));
        if (ar.room.isActive()) this.fanOutState(ar.room);
        if (ar.room.isActive()) this.driveClues(ar, now);
      }
    }

    // 3) Drive each active dare: cap check, then fan out the clock/state.
    for (const [roomId, dare] of [...this.dareRooms]) {
      if (!dare.isActive()) continue;
      this.dispatchDare(roomId, dare.tick(now));
      const cur = this.dareRooms.get(roomId);
      if (cur && cur.isActive()) this.fanOutDareState(cur);
    }

    // 4) Sweep abandoned dare invites (a setter who never got a guesser) past the TTL.
    for (const [code, p] of this.pendingDares) {
      if (now - p.createdAt >= DARE_INVITE_TTL_MS) {
        this.pendingDares.delete(code);
        this.metrics.invite("expired", "dare");
      }
    }
  }

  // ── match setup & event dispatch ────────────────────────────────────────────

  private startMatch(pairing: Pairing): void {
    const now = this.now();
    // Each human seat hunts the concept in the language it queued with; bots
    // and ghosts play the English form.
    const langs = new Map<string, Lang>();
    const seats = pairing.players.map((seat) => {
      const lang = seat.kind === "human" ? (this.clientLang.get(seat.id) ?? "en") : "en";
      langs.set(seat.id, lang);
      return { ...seat, secret: pairing.words[lang] };
    }) as [PlayerSeed, PlayerSeed];
    const room = new Room({
      roomId: pairing.roomId,
      mode: pairing.mode,
      secret: pairing.secret,
      players: seats,
      now,
    });
    const bots = new Map<string, Bot>();
    for (const seat of pairing.players) {
      if (seat.kind === "bot" || seat.kind === "ghost") {
        bots.set(
          seat.id,
          new Bot({ secret: pairing.secret, seed: pairing.botSeed ?? 0, config: this.botConfig }),
        );
      } else {
        this.playerRoom.set(seat.id, pairing.roomId);
      }
    }
    const ar: ActiveRoom = { room, bots, secret: pairing.secret, words: pairing.words, langs, mode: pairing.mode };
    this.rooms.set(pairing.roomId, ar);
    this.prepareClues(ar, pairing.players.filter((p) => p.kind === "human").map((p) => p.id));

    // Tell each human seat it's paired, then send the opening state.
    for (const seat of pairing.players) {
      if (seat.kind !== "human") continue;
      const client = this.clients.get(seat.id);
      const opponent = pairing.players.find((p) => p.id !== seat.id)!;
      if (!client) {
        // Player vanished between queue and pairing — resolve their absence.
        this.dispatch(pairing.roomId, room.applyDisconnect({ playerId: seat.id, now }));
        continue;
      }
      client.send({
        t: "paired",
        roomId: pairing.roomId,
        opponentKind: opponent.kind,
        mode: pairing.mode,
        wordId: pairing.roomId, // opaque handle (see protocol.ts note)
      });
    }
    if (room.isActive()) this.fanOutState(room);
  }

  /** Route a room's events to the right clients (fan out / notify / finalize). */
  private dispatch(roomId: string, events: ReturnType<Room["tick"]>): void {
    const ar = this.rooms.get(roomId);
    if (!ar) return;
    for (const ev of events) {
      switch (ev.type) {
        case "state":
          this.fanOutState(ar.room);
          break;
        case "opponentLeft": {
          // Notify the player who did NOT leave.
          const [a, b] = ar.room.playerIds();
          const other = ev.playerId === a ? b : a;
          this.clients.get(other)?.send({ t: "opponentLeft" });
          break;
        }
        case "ended": {
          // The match is over → reveal the word in the result (safe now). Each
          // seat gets the word as it hunted it, plus every language in play so
          // the end screen can show what the other player was chasing.
          const played = new Set(ar.langs.values());
          const words: Record<string, string> = {};
          for (const l of played) words[l] = ar.words[l];
          for (const id of ar.room.playerIds()) {
            this.clients.get(id)?.send({ t: "result", result: ev.result, word: ar.room.secretFor(id), words });
          }
          this.cleanupRoom(roomId);
          break;
        }
      }
    }
  }

  private fanOutState(room: Room): void {
    for (const id of room.playerIds()) this.sendStateTo(room, id);
  }

  private sendStateTo(room: Room, playerId: string): void {
    const client = this.clients.get(playerId);
    if (!client) return; // bot seat or disconnected human
    client.send({ t: "state", state: room.snapshotFor(playerId, this.now()) });
  }

  /** Re-issue the opening handshake (paired + state) to a single player so a
   *  reconnecting/resuming client can rebuild the match view. Progress-only —
   *  the secret and the opponent's guesses are never included. */
  private sendResume(ar: ActiveRoom, playerId: string): void {
    const client = this.clients.get(playerId);
    if (!client) return;
    const snap = ar.room.snapshotFor(playerId, this.now());
    client.send({
      t: "paired",
      roomId: ar.room.roomId,
      opponentKind: snap.opponent.kind,
      mode: ar.mode,
      wordId: ar.room.roomId,
    });
    client.send({ t: "state", state: snap });
    for (const clue of ar.clues?.sent.get(playerId) ?? []) client.send(clue);
  }

  // ── 3.9 timed race clues ────────────────────────────────────────────────────

  /** Start fetching what the race's clues need (nearest words per language,
   *  each human seat's written ladder) so it is ready by the first drop. */
  private prepareClues(ar: ActiveRoom, humans: string[]): void {
    if (!this.nearestWords && !this.writeClues) return;
    if (humans.length === 0) return;
    const st: ClueState = {
      lastSlot: -1,
      wordsSent: 0,
      hintsSent: 0,
      bestRank: new Map(),
      nearest: new Map(),
      ladders: new Map(),
      usedWords: new Map(),
      sent: new Map(),
    };
    ar.clues = st;
    const langs = new Set(humans.map((id) => ar.langs.get(id) ?? "en"));
    for (const lang of langs) {
      st.usedWords.set(lang, new Set());
      void this.nearestWords?.(ar.words[lang], lang).then(
        (list) => { st.nearest.set(lang, list); },
        () => {},
      );
    }
    for (const id of humans) {
      const lang = ar.langs.get(id) ?? "en";
      void this.writeClues?.(ar.words[lang], lang, ar.secret, this.clientHelp.get(id)).then(
        (lines) => { st.ladders.set(id, lines); },
        () => {},
      );
    }
  }

  /** Send the clue drop that is due, if any. Both human seats get the same
   *  kind of clue at the same time; a seat whose input is not ready yet just
   *  gets nothing this time. */
  private driveClues(ar: ActiveRoom, now: number): void {
    const st = ar.clues;
    if (!st) return;
    const snap = ar.room.snapshotFor(ar.room.playerIds()[0], now);
    const slot = dueSlot(snap.clock.elapsedMs, st.lastSlot, snap.clock.capMs);
    if (slot === null) return;
    st.lastSlot = slot;

    const humans = ar.room.playerIds().filter((id) => !ar.bots.has(id));
    let bestRank = UNKNOWN_RANK;
    for (const id of humans) bestRank = Math.min(bestRank, st.bestRank.get(id) ?? UNKNOWN_RANK);
    // Every human seat must have a rung left for a written clue to count.
    let hintsAvailable = Infinity;
    for (const id of humans) hintsAvailable = Math.min(hintsAvailable, st.ladders.get(id)?.length ?? 0);
    if (!Number.isFinite(hintsAvailable)) hintsAvailable = 0;
    // A warmer word only counts as available if every seat's language has a list.
    const wordsReady = humans.every((id) => (st.nearest.get(ar.langs.get(id) ?? "en")?.length ?? 0) > 0);

    const kind = pickKind({
      bestRank,
      wordsSent: wordsReady ? st.wordsSent : Number.MAX_SAFE_INTEGER,
      hintsSent: st.hintsSent,
      hintsAvailable,
    });
    if (kind === null) return;

    const n = st.wordsSent + st.hintsSent + 1;
    const frames = new Map<string, ClueFrame>();
    if (kind === "word") {
      // One pick per language, so two seats on the same language get the same word.
      const picks = new Map<Lang, { word: string; rank: number } | null>();
      for (const id of humans) {
        const lang = ar.langs.get(id) ?? "en";
        if (!picks.has(lang)) {
          const used = st.usedWords.get(lang) ?? new Set<string>();
          const forms = [ar.words[lang], ar.secret];
          picks.set(lang, pickWarmerWord(st.nearest.get(lang) ?? [], bestRank, used, forms));
        }
        const pick = picks.get(lang);
        if (pick) frames.set(id, { t: "clue", n, kind: "word", text: pick.word, rank: pick.rank });
      }
      if (frames.size === 0) return;
      for (const [lang, pick] of picks) if (pick) st.usedWords.get(lang)?.add(pick.word);
      st.wordsSent++;
    } else {
      for (const id of humans) {
        const line = st.ladders.get(id)?.[st.hintsSent];
        if (line) frames.set(id, { t: "clue", n, kind: "hint", text: line.text, ...(line.help ? { help: line.help } : {}) });
      }
      if (frames.size === 0) return;
      st.hintsSent++;
    }
    for (const [id, frame] of frames) {
      const list = st.sent.get(id) ?? [];
      list.push(frame);
      st.sent.set(id, list);
      this.clients.get(id)?.send(frame);
    }
  }

  private cleanupRoom(roomId: string): void {
    const ar = this.rooms.get(roomId);
    if (!ar) return;
    for (const id of ar.room.playerIds()) {
      if (this.playerRoom.get(id) === roomId) this.playerRoom.delete(id);
    }
    this.rooms.delete(roomId);
  }

  private roomOf(playerId: string): ActiveRoom | undefined {
    const roomId = this.playerRoom.get(playerId);
    return roomId ? this.rooms.get(roomId) : undefined;
  }

  // ── Live Dare dispatch ────────────────────────────────────────────────────────

  private dispatchDare(roomId: string, events: DareEvent[]): void {
    const dare = this.dareRooms.get(roomId);
    if (!dare) return;
    for (const ev of events) {
      if (ev.type === "state") {
        this.fanOutDareState(dare);
      } else {
        // ended → send the result (word revealed) to both, then clean up.
        for (const id of dare.playerIds()) this.clients.get(id)?.send({ t: "dareEnd", result: ev.result });
        this.cleanupDare(roomId);
      }
    }
  }

  private fanOutDareState(dare: DareRoom): void {
    const now = this.now();
    for (const id of dare.playerIds()) {
      this.clients.get(id)?.send({ t: "dareState", state: dare.snapshotFor(id, now) });
    }
  }

  private cleanupDare(roomId: string): void {
    const dare = this.dareRooms.get(roomId);
    if (!dare) return;
    for (const id of dare.playerIds()) {
      if (this.playerDare.get(id) === roomId) this.playerDare.delete(id);
    }
    this.dareRooms.delete(roomId);
  }

  private dareOf(playerId: string): DareRoom | undefined {
    const roomId = this.playerDare.get(playerId);
    return roomId ? this.dareRooms.get(roomId) : undefined;
  }

  /** "Race a flame now": a waiting Quick Match player gives up on the shared
   *  start and takes the bot at the next tick. No-op if they are not waiting. */
  expedite(client: Client): boolean {
    const ok = this.mm.expedite(client.id, this.now());
    if (ok) {
      const now = this.now();
      client.send({ t: "queued", startsAt: now, waitMs: 0 });
    }
    return ok;
  }

  // ── introspection (ops / tests) ─────────────────────────────────────────────

  /** Cheap counts for the Race screen's "N racing now" line. Humans only:
   *  bot seats are not people, and the line must stay honest. */
  liveCounts(): { racing: number; waiting: number } {
    let racing = 0;
    for (const ar of this.rooms.values()) {
      for (const id of ar.room.playerIds()) if (!ar.bots.has(id)) racing++;
    }
    return { racing, waiting: this.mm.waitingCount("casual") };
  }

  activeRoomCount(): number {
    return this.rooms.size;
  }
  activeDareCount(): number {
    return this.dareRooms.size;
  }
  connectedCount(): number {
    return this.clients.size;
  }
}
