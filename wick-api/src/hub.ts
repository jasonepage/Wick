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

import { Room, type MatchMode } from "./room.js";
import { Matchmaker, type Pairing, type MatchmakerDeps } from "./matchmaker.js";
import { Bot, type BotConfig } from "./bot.js";
import { DareRoom, type DareRole, type DareEvent } from "./dare.js";
import { isBlockedSecret, isBlockedGuess } from "./moderation.js";
import { isRealWord } from "./dictionary.js";
import { Metrics } from "./metrics.js";
import type { ClientFrame, ServerFrame } from "./protocol.js";

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
  scoreWarmth?: (secret: string, guess: string) => Promise<{ score: number; rank?: number }>;
  /** Is the setter's word a real word? SYNCHRONOUS on purpose — onDare mutates
   *  pending-dare state and awaiting inside it would let a guesser's frame arrive
   *  before the setter is registered. Injected like scoreWarmth so the hub stays
   *  decoupled from the dictionary (and testable without one). */
  isPlayableSecret?: (word: string) => boolean;
  /** In-match Keeper: answer a yes/no question about the room secret without
   *  leaking it (server wires the Gemini/deterministic Keeper; tests inject a
   *  fake). Default: a polite "unavailable". */
  answerKeeper?: (secret: string, question: string) => Promise<{ verdict: string; reply: string }>;
  /** Difficulty knobs for the bot fill-in (FR-13). The server tunes the practice
   *  flame to be beatable; omitted → the bot's own DEFAULT_BOT_CONFIG. */
  botConfig?: Partial<BotConfig>;
  /** Invite-funnel counters (3.1). Shared with the Matchmaker; defaults to a
   *  throwaway instance so tests need not pass one. */
  metrics?: Metrics;
}

interface ActiveRoom {
  room: Room;
  /** Bot seats: playerId → Bot driver. */
  bots: Map<string, Bot>;
  /** The match secret — held hub-side so warmth can be scored server-authoritatively. */
  secret: string;
  /** The match mode, kept so a resuming/reconnecting client can be re-`paired`. */
  mode: MatchMode;
}

export class MatchHub {
  private readonly mm: Matchmaker;
  private readonly now: () => number;
  private readonly attest: (client: Client, frame: ClientFrame) => boolean;
  private readonly scoreWarmth: (secret: string, guess: string) => Promise<{ score: number; rank?: number }>;
  private readonly isPlayableSecret: (word: string) => boolean;
  private readonly answerKeeper: (
    secret: string,
    question: string,
  ) => Promise<{ verdict: string; reply: string }>;
  private readonly botConfig?: Partial<BotConfig>;
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
      client.send({ t: "error", code: "not_a_word", message: "Wick doesn't know that word — try another." });
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
        client.send({ t: "error", code: "code_taken", message: "That code's already daring someone — tap Dare for a fresh one." });
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
        client.send({ t: "error", code: "no_such_invite", message: "That dare isn't active anymore — ask your friend for a new link." });
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
      client.send({ t: "error", code: "blocked_word", message: "Let's keep it friendly — try another word." });
      return;
    }
    // Reject non-words (Dare is snapshot-driven, so it simply isn't added; the
    // error tells the guesser why). The exact secret is always allowed.
    if (guess.trim().toLowerCase() !== dare.word().trim().toLowerCase() && !isRealWord(guess)) {
      client.send({ t: "error", code: "not_a_word", message: "That's not a word I know — try another." });
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
        client.send({ t: "error", code: "code_taken", message: "That code's already in use — tap Invite for a fresh one." });
        return;
      }
      if (!create && !host) {
        this.metrics.invite("no_such_invite", "race");
        client.send({ t: "error", code: "no_such_invite", message: "That invite isn't active anymore — ask your friend for a new link." });
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
    // 0) Reject non-words (typo/keyboard mash) before they count — the guess must
    //    be a real word, unless it exactly matches the secret. Matches iOS + web
    //    single-player. The client removes the guess on `notAWord`.
    if (guess.trim().toLowerCase() !== ar.secret.trim().toLowerCase() && !isRealWord(guess)) {
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
      void this.scoreWarmth(ar.secret, guess).then(({ score, rank }) => {
        const cur = this.rooms.get(roomId);
        if (!cur || !cur.room.isActive()) return;
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
    void this.answerKeeper(ar.secret, question).then(({ verdict, reply }) => {
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
    const room = new Room({
      roomId: pairing.roomId,
      mode: pairing.mode,
      secret: pairing.secret,
      players: pairing.players,
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
    this.rooms.set(pairing.roomId, { room, bots, secret: pairing.secret, mode: pairing.mode });

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
          // The match is over → reveal the word in the result (safe now).
          for (const id of ar.room.playerIds()) {
            this.clients.get(id)?.send({ t: "result", result: ev.result, word: ar.secret });
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
