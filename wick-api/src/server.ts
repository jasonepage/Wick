//
//  server.ts — the runnable Wick match service (SDS §1).
//
//  HTTP (free tier ok):   GET /healthz         liveness (FR-1)
//                         GET /d/:code         OG share preview (FR-5)
//  WebSocket (warm):      WS  /match           live match + matchmaking (FR-8..18)
//
//  This file is the thin runtime adapter: it wires real sockets + an interval
//  clock to the tested cores (MatchHub → Matchmaker/Room/Bot). All match logic is
//  in those modules; this file just plumbs transport.
//

import { serve } from "@hono/node-server";
import { serveStatic } from "@hono/node-server/serve-static";
import { Hono, type Context } from "hono";
import { compress } from "hono/compress";
import { WebSocketServer, type WebSocket } from "ws";
import { renderPreviewHtml, renderInviteHtml } from "./preview.js";
import { MatchHub, type Client } from "./hub.js";
import { parseClientFrame, type ServerFrame } from "./protocol.js";
import { makeWordProvider } from "./words.js";
import { warmthScore, validateSecret } from "./warmthservice.js";
import { isRealWord, dictionarySize } from "./dictionary.js";
import { keeperAnswer } from "./keeper.js";
import { hasEmbeddings, lastEmbedError, activeEmbedModel, activeEmbedMode, selfCheck, rankVocabExpected, rankVocabProgress, prewarm, cacheStats, warmRankVocab, rankVocabVectors, batchEmbed } from "./embeddings.js";
import { layout as revealLayout } from "./revealmap.js";
import { COMMON_WORDS } from "./commonwords.js";
import { RANK_VOCAB } from "./rankvocab.js";
import { RateLimiter } from "./ratelimit.js";
import { isAllowedOrigin, parseOrigins } from "./abuse.js";
import { Metrics } from "./metrics.js";
import { track, isTrackedEvent, anonId } from "./events.js";

// Render injects PORT at runtime — never set it by hand. `|| 8080` is a safety
// net: an empty PORT ("") would otherwise parse to 0 (a random port Render can't
// reach) and a non-numeric one to NaN (a hard crash on listen). Any falsy/NaN
// value falls back to a valid default instead of breaking the boot.
const PORT = Number(process.env.PORT) || 8080;
// Canonical link/host for 3.1: guesswick.com (the custom domain, pointed at this
// Render service so one origin serves the API, the web client, the OG cards, and the
// AASA). Override with WICK_APP_LINK_BASE. Legacy WK-/WR- links shared before the
// migration still resolve via the /d/:code route below.
const APP_LINK_BASE = process.env.WICK_APP_LINK_BASE ?? "https://guesswick.com";
const TICK_MS = Number(process.env.WICK_TICK_MS ?? 1000);
// Apple App Site Association appID = "<TEAMID>.<bundleID>". Defaults to the real Wick
// app id (Team 8C4BM6A82T + bundle party.heirloom.Hunch) so Universal Links verify
// even if the env var is unset; override with WICK_APPLE_APP_ID (e.g. for a rename).
const APPLE_APP_ID = process.env.WICK_APPLE_APP_ID ?? "8C4BM6A82T.party.heirloom.Hunch";

// ── Anti-abuse (FR-23) — protect the Gemini-backed endpoints from cost abuse ────
// Public + cross-platform, so App Attest can't gate web; a per-IP token bucket
// bounds how fast any caller burns Gemini. Generous enough for real humans.
const numEnv = (k: string, d: number) => Number(process.env[k] ?? d);
// HTTP /warmth + /keeper: ~1 req/sec sustained, burst 40.
const httpLimiter = new RateLimiter(numEnv("WICK_HTTP_BURST", 40), numEnv("WICK_HTTP_RPS", 1), Date.now);
// WS guess/ask (live): burst 30, ~5/sec — brisk typing is fine, floods aren't.
const wsLimiter = new RateLimiter(numEnv("WICK_WS_BURST", 30), numEnv("WICK_WS_RPS", 5), Date.now);
// Match/dare CREATION (queue/dare frames): heavier than a guess — each spins up a
// room / bot / invite, so a tighter bucket bounds match- and invite-spam. A real
// human starting/rematching/dares stays well under burst 12, ~0.5/sec.
const createLimiter = new RateLimiter(numEnv("WICK_CREATE_BURST", 12), numEnv("WICK_CREATE_RPS", 0.5), Date.now);
// NEW WS connections per IP: bounds socket floods before any match state is
// allocated. Burst 15, ~1/sec.
const connLimiter = new RateLimiter(numEnv("WICK_CONN_BURST", 15), numEnv("WICK_CONN_RPS", 1), Date.now);
// Browser origins allowed to open a live socket. Native apps send no Origin and are
// allowed (App Attest gates them later, FR-16). Override with WICK_ALLOWED_ORIGINS.
const ALLOWED_ORIGINS = parseOrigins(process.env.WICK_ALLOWED_ORIGINS, [
  "https://guesswick.com",
  "https://www.guesswick.com",
  "https://wick-api.onrender.com",
]);
// Debug endpoints are OFF unless this token is set AND matches ?token= (they burn
// Gemini and take an arbitrary secret — never leave them open in production).
const DEBUG_TOKEN = process.env.WICK_DEBUG_TOKEN ?? "";

/** Best-effort client IP (Render sits behind a proxy → trust x-forwarded-for). */
function ipFromXff(xff: string | string[] | undefined): string {
  const raw = Array.isArray(xff) ? xff[0] : xff;
  return raw?.split(",")[0]?.trim() || "unknown";
}

// ── HTTP app ────────────────────────────────────────────────────────────────

const app = new Hono();

// Gzip everything compressible, over 1 KB. The JS bundle is the single biggest
// thing this instance hands out and it goes over the wire uncompressed today —
// Render's proxy does not compress for you. Hono's default content-type filter
// already skips images and audio, so the mp3s and PNGs are not re-compressed
// for nothing. Applies to JSON responses too, which matters most for /reveal
// (a full round's point array).
app.use(compress());

// `gemini` shows whether the API key is loaded — so warmth/Keeper quality issues
// are easy to diagnose (false → key not set/deployed → lexical fallback).
// How long a cold instance may report unhealthy while the rank vocab warms.
// Render holds the OLD instance until the new one passes its health check, so
// reporting unhealthy here means a deploy simply takes longer to cut over and
// nobody is served noise in the meantime.
//
// The deadline is the escape hatch: if Gemini is down, the sweep never finishes,
// and without a cap the deploy could never go live at all — so past the grace
// window we report healthy-but-degraded rather than blocking a fix from shipping.
const READY_GRACE_MS = numEnv("WICK_READY_GRACE_MS", 10 * 60_000);
const BOOTED_AT = Date.now();

/** Rank vocab warmed (or not expected at all, e.g. no Gemini key → lexical
 *  fallback, which is degraded but stable and shouldn't fail a deploy). */
function rankVocabReady(): boolean {
  return !hasEmbeddings() || rankVocabVectors().length > 0;
}

app.get("/healthz", (c) => {
  const ready = rankVocabReady();
  const withinGrace = Date.now() - BOOTED_AT < READY_GRACE_MS;
  // Unhealthy ONLY while a cold instance is still warming inside the window.
  const status = ready || !withinGrace ? 200 : 503;
  return c.json({
    ok: status === 200,
    ready,
    // True when we are serving despite a cold vocab because the grace window
    // expired — warmth is running on the lexical fallback and will read poorly.
    degraded: !ready && !withinGrace,
    service: "wick-api",
    ts: Date.now(),
    gemini: hasEmbeddings(),
    cache: cacheStats(),
    rankVocab: rankVocabVectors().length, // 0 until warmed; >0 = Contexto ranking live
    // The frozen (model, taskType, dims) triple. If this ever reads back as
    // anything other than one consistent value, vectors are being mixed across
    // projections and every warmth score is noise — see embeddings.ts.
    embedMode: activeEmbedMode(),
    rankVocabExpected: rankVocabExpected(), // if this exceeds rankVocab, ranks read warm
    rankVocabProgress: rankVocabProgress(), // live count while the warm runs
    dictionary: dictionarySize(), // ~274k when the word list loaded; 0 = unavailable (fails open)
    invites: metrics.snapshot(), // 3.1 invite funnel — created/joined/expired/...
  }, status);
});

app.get("/d/:code", (c) => {
  const code = c.req.param("code");
  const html = renderPreviewHtml({ code, appLink: `${APP_LINK_BASE}/d/${encodeURIComponent(code)}` });
  return c.html(html);
});

// 3.1 live-invite deep link: /p/:code?m=race|dare. Universal Links match /p/* (via
// the AASA below), so an installed iOS app opens straight into the live screen; a
// browser with no app gets a mode-aware OG page that redirects into the web client to
// play. The Dare word is NEVER in the link — only the rendezvous code.
app.get("/p/:code", (c) => {
  const code = c.req.param("code");
  const m = c.req.query("m");
  const mode = m === "race" || m === "dare" ? m : undefined;
  const enc = encodeURIComponent(code);
  const modeQ = mode ? `&m=${mode}` : "";
  const html = renderInviteHtml({
    code,
    mode,
    // The web client (served at "/") reads ?p= / ?m= at boot and auto-joins.
    playLink: `/?p=${enc}${modeQ}`,
    appLink: `${APP_LINK_BASE}/p/${enc}${mode ? `?m=${mode}` : ""}`,
  });
  return c.html(html);
});

// Ghost Race link: /r/<run>  (3.3)
//
// A PATH, not a query, because Universal Links only ever match on path — a
// "/?r=" link could never open the app. But the SPA cannot simply be served
// here: vite is built with base "./", so index.html at a nested path resolves
// "./assets/…" to "/r/assets/…", 404s, and the app never boots. Hence the same
// shape as /p/:code above — a small server-rendered page that bounces into the
// web client at the ROOT, where the relative asset paths resolve.
//
// So: installed app → Universal Link opens it. No app → this page → /?r=<run>.
app.get("/r/:run", (c) => {
  const run = c.req.param("run");
  const enc = encodeURIComponent(run);
  const html = renderInviteHtml({
    code: run,
    playLink: `/?r=${enc}`,
    appLink: `${APP_LINK_BASE}/r/${enc}`,
    imageUrl: `${APP_LINK_BASE}/og-image.jpg`,
  });
  return c.html(html);
});

// Apple App Site Association for Universal Links (3.1). Served at the exact path over
// HTTPS with no redirect, as application/json. `/p/*` is the invite surface; `/d/*`
// keeps legacy links opening the app too. Set WICK_APPLE_APP_ID to the real
// "<TEAMID>.<bundleID>" before this verifies.
// Universal Links match on PATH only, never on the query string — which is why
// ghost-race links are generated as /r/<run> rather than /?r=<run>: a query-form
// link could never open the app.
//
// Only claim a path the app can actually handle. "/r/*" is claimed because
// Ghost.from(url:) parses it and GhostChallengeView presents it; anything the
// app can't play must stay off this list, or the link opens an app that silently
// does nothing and the sender never finds out why.
const AASA = {
  applinks: {
    apps: [],
    details: [{ appID: APPLE_APP_ID, paths: ["/p/*", "/d/*", "/r/*"] }],
  },
} as const;
app.get("/.well-known/apple-app-site-association", (c) => c.json(AASA));
app.get("/apple-app-site-association", (c) => c.json(AASA)); // legacy root location

// Invite-funnel counters (3.1): created → joined, and where it leaks (expired /
// code_taken / no_such_invite), split race vs dare. Directional, in-memory.
const metrics = new Metrics();
app.get("/metrics", (c) => c.json({ ...metrics.snapshot(), growth: metrics.growth() }));

// Hot/cold warmth for a guess (server-authoritative; Gemini key only in env, C4).
// Single-player callers (who know the secret) send { secret, guess }.
app.post("/warmth", async (c) => {
  if (!httpLimiter.take(`${ipFromXff(c.req.header("x-forwarded-for"))}:warmth`)) {
    return c.json({ error: "rate_limited" }, 429);
  }
  let body: unknown;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: "bad_json" }, 400);
  }
  const secret = (body as { secret?: unknown }).secret;
  const guess = (body as { guess?: unknown }).guess;
  if (typeof secret !== "string" || typeof guess !== "string") {
    return c.json({ error: "secret and guess required" }, 400);
  }
  if (secret.length > 64 || guess.length > 64) {
    return c.json({ error: "too_long" }, 400);
  }
  // Reject non-words (typos, keyboard mash) before spending a Gemini call — the
  // guess must be a real English word, unless it exactly matches the secret. This
  // mirrors iOS, where a non-word simply has no on-device embedding.
  if (guess.trim().toLowerCase() !== secret.trim().toLowerCase() && !isRealWord(guess)) {
    return c.json({ score: null, notAWord: true });
  }
  const result = await warmthScore(secret, guess);
  return c.json(result); // { score, source }
});

// One-click warmth diagnostic (open in a browser). Shows the score, whether it
// used real embeddings or the lexical fallback, the raw cosine, and any embed
// error — so a "book reads Freezing" issue is instantly explainable.
//   /debug/warmth?secret=library&guess=book
app.get("/debug/warmth", async (c) => {
  if (!DEBUG_TOKEN || c.req.query("token") !== DEBUG_TOKEN) return c.json({ error: "forbidden" }, 403);
  const secret = c.req.query("secret") ?? "library";
  const probes = (c.req.query("guess") ?? "librarian,book,school,university,car,ocean,happy")
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
    .slice(0, 20);
  const results = [];
  for (const g of probes) results.push({ guess: g, ...(await warmthScore(secret, g)) });
  results.sort((a, b) => (b.cos ?? -1) - (a.cos ?? -1));
  return c.json({
    secret,
    gemini: hasEmbeddings(),
    model: activeEmbedModel(),
    embedError: lastEmbedError(),
    results,
  });
});

// One-click Keeper diagnostic (open in a browser). Shows the verdict/reply and,
// on failure, the exact Gemini error (e.g. which chat model 404'd).
//   /debug/keeper?secret=library&q=is it alive
app.get("/debug/keeper", async (c) => {
  if (!DEBUG_TOKEN || c.req.query("token") !== DEBUG_TOKEN) return c.json({ error: "forbidden" }, 403);
  const secret = c.req.query("secret") ?? "library";
  const q = c.req.query("q") ?? "is it alive?";
  const result = await keeperAnswer(secret, q);
  return c.json({ secret, question: q, ...result });
});

// The Keeper: answer a yes/no question about the secret without revealing it
// (leak-proof, Gemini + Wick persona; FR-19). Single-player callers send the secret.
// Is this word playable as a Dare secret? The client calls this while the setter
// is still typing, so a bad word is caught before they share a link — rather than
// their friend discovering it mid-round when every guess reads Freezing.
// The WS path enforces the dictionary check independently; this is the nicer UX,
// not the security boundary.
// Product events from the clients. Everything that matters about the daily
// happens in the browser (localStorage), so the server cannot infer it — the
// client has to say so. Allowlisted names only; ids are hashed on arrival.
app.post("/event", async (c) => {
  if (!httpLimiter.take(`${ipFromXff(c.req.header("x-forwarded-for"))}:event`)) {
    return c.json({ ok: false }, 429);
  }
  const body = (await c.req.json().catch(() => null)) as
    { e?: unknown; id?: unknown; n?: unknown; g?: unknown; p?: unknown } | null;
  if (!isTrackedEvent(body?.e)) return c.json({ ok: false });
  metrics.event(body.e, typeof body.g === "number" ? body.g : undefined);
  track(body.e, {
    id: anonId(body.id),
    n: typeof body.n === "number" && Number.isFinite(body.n) ? body.n : undefined,
    g: typeof body.g === "number" && Number.isFinite(body.g) ? body.g : undefined,
    p: body.p === "ios" || body.p === "web" ? body.p : undefined,
  });
  return c.json({ ok: true });
});

app.post("/validate-word", async (c) => {
  if (!httpLimiter.take(`${ipFromXff(c.req.header("x-forwarded-for"))}:validate`)) {
    return c.json({ error: "rate_limited" }, 429);
  }
  const body = (await c.req.json().catch(() => null)) as { word?: unknown } | null;
  const word = typeof body?.word === "string" ? body.word : "";
  if (!word.trim()) return c.json({ ok: false, verdict: "not_a_word" });
  return c.json(await validateSecret(word));
});

app.post("/keeper", async (c) => {
  if (!httpLimiter.take(`${ipFromXff(c.req.header("x-forwarded-for"))}:keeper`)) {
    return c.json({ error: "rate_limited" }, 429);
  }
  let body: unknown;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: "bad_json" }, 400);
  }
  const secret = (body as { secret?: unknown }).secret;
  const question = (body as { question?: unknown }).question;
  if (typeof secret !== "string" || typeof question !== "string") {
    return c.json({ error: "secret and question required" }, 400);
  }
  if (secret.length > 64 || question.length > 280) {
    return c.json({ error: "too_long" }, 400);
  }
  const result = await keeperAnswer(secret, question);
  return c.json(result); // { verdict, reply, source }
});

// The Reveal (3.2): a post-round semantic map. The caller sends its own guesses
// (word + 0..100 score); the server embeds the guess words and returns a 2D layout
// (radius from score, angle from pairwise similarity). No secret is needed — the
// center word is one the caller already knows — and no word the caller didn't send
// is ever returned. Rate-limited like /warmth.
app.post("/reveal", async (c) => {
  if (!httpLimiter.take(`${ipFromXff(c.req.header("x-forwarded-for"))}:reveal`)) {
    return c.json({ error: "rate_limited" }, 429);
  }
  let body: unknown;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: "bad_json" }, 400);
  }
  const guessesRaw = (body as { guesses?: unknown }).guesses;
  if (!Array.isArray(guessesRaw)) {
    return c.json({ error: "guesses required" }, 400);
  }
  // Sanitize: at most 60 guesses, each { word: string (≤64), score: number 0..100 }.
  const items = guessesRaw
    .slice(0, 60)
    .map((g) => {
      const w = (g as { word?: unknown }).word;
      const s = (g as { score?: unknown }).score;
      return typeof w === "string" && typeof s === "number"
        ? { word: w.slice(0, 64), score: Math.max(0, Math.min(100, s)) }
        : null;
    })
    .filter((x): x is { word: string; score: number } => x !== null);
  if (items.length === 0) return c.json({ points: [] });

  const words = items.map((x) => x.word);
  // Embed the guess words (mostly cache hits — they were scored during play). Without
  // a Gemini key, vectors are all null → the layout falls back to even spacing.
  const vectors = hasEmbeddings() ? await batchEmbed(words) : words.map(() => null);
  const points = revealLayout(words, items.map((x) => x.score), vectors);
  return c.json({ points });
});

// Serve the built web client (wick-web) from ./public. Specific API routes above
// take precedence; everything else falls back to the static site + its index.
//
// CACHING. This process serves the SPA, its bundle and 22 sound clips off the
// same instance that runs the game, on half a CPU. Without cache headers every
// visitor re-downloads all of it every visit, and a crowd arriving at once (a
// stream, a launch) starves the game loop to serve bytes the browser already
// had. Three tiers, split by whether the URL changes when the content does:
//
//   /assets/*      Vite emits content-hashed filenames, so the URL IS the
//                  version. Immutable for a year: changed file, changed name.
//   other statics  Icons, sounds, og-image: stable names, rare changes. A day,
//                  then revalidate.
//   index.html     Never cached. It is what points at the current /assets
//                  hashes, so a stale copy pins a returning player to a dead
//                  bundle — the classic white screen after a deploy.
//
// This is also what makes a CDN in front (Cloudflare) work at all: with no
// cache headers an edge has nothing to go on and passes everything through.
const YEAR = 60 * 60 * 24 * 365;
const DAY = 60 * 60 * 24;

const staticCache = (path: string, c: Context): void => {
  c.header(
    "Cache-Control",
    path.includes("/assets/")
      ? `public, max-age=${YEAR}, immutable`
      : `public, max-age=${DAY}, must-revalidate`,
  );
};

/** index.html must never be cached — see above. */
const noStore = (_path: string, c: Context): void => {
  c.header("Cache-Control", "no-cache, must-revalidate");
};

app.get("/", serveStatic({ path: "./public/index.html", onFound: noStore }));
app.use("/*", serveStatic({ root: "./public", onFound: staticCache }));
app.get("/*", serveStatic({ path: "./public/index.html", onFound: noStore })); // SPA fallback

// ── Hub (real clock) ───────────────────────────────────────────────────────────
// Anti-abuse today (FR-16/FR-23) is transport-layer, above: per-IP rate limits on
// connections, match/dare creation, and the Gemini actions, plus a browser-origin
// check. The hub's `attest` seam stays open for the NEXT layer — cryptographic
// per-identity attestation (Apple App Attest / web signed session token), which
// needs device fixtures to verify and lands separately (see hub.ts FLAG, NOTE_3.1).

const hub = new MatchHub({
  now: () => Date.now(),
  metrics, // 3.1 invite-funnel counters, shared with the matchmaker
  // attest: (client, frame) => verifyAppAttest(...)  // future identity layer (FR-16)
  // Server-authoritative warmth for live matches (Gemini embeddings, C8).
  scoreWarmth: async (secret, guess) => {
    const r = await warmthScore(secret, guess);
    return { score: r.score, rank: r.rank };
  },
  // Gate on the SETTER's word before a Dare can start. Synchronous dictionary
  // check only — the deeper embeddability check lives on POST /validate-word,
  // which the client calls while the setter is still typing.
  isPlayableSecret: (word) => isRealWord(word),
  // In-match Keeper: leak-proof yes/no answers on the room secret (FR-19).
  answerKeeper: async (secret, question) => {
    const r = await keeperAnswer(secret, question);
    return { verdict: r.verdict, reply: r.reply };
  },
  // Practice flame: never solves — it warms up and applies light pressure, but
  // the human always wins by solving. (It can still edge a warmth tie-break if
  // NEITHER solves at the cap.) Tunable via env if we want it tougher later.
  botConfig: {
    solveProbability: 0,
    guessGapMsRange: [3500, 12_000],
  },
  matchmaker: {
    // Random word per match; NOT a single-player daily word (C1).
    wordProvider: makeWordProvider(() => Math.floor(Math.random() * 1_000_000)),
    roomIdProvider: () => `room-${randomId()}`,
    botSeedProvider: () => Math.floor(Math.random() * 0x7fffffff),
    // 3.3 shared start times: Quick Match starts on the next 2-minute boundary
    // (at least 15 s away), so players who arrive a minute apart race together.
    config: { startSlotMs: 120_000, minWaitMs: 15_000 },
  },
});

function randomId(): string {
  return Math.random().toString(36).slice(2, 10);
}

// ── boot ──────────────────────────────────────────────────────────────────────

const server = serve({ fetch: app.fetch, port: PORT }, (info) => {
  console.log(`[wick-api] HTTP+WS listening on :${info.port}`);
  // Pre-warm common first-guesses so early warmth is instant, then embed the rank
  // vocabulary so warmth becomes Contexto-style (rank, not absolute cosine).
  // Fire-and-forget — never blocks boot; warmth falls back to bands until ready.
  // Set WICK_PREWARM=0 to skip both.
  if (process.env.WICK_PREWARM !== "0" && hasEmbeddings()) {
    // Negotiate the embedding mode BEFORE the warm storm starts. Everything
    // below then shares one frozen (model, taskType) pair. Doing this lazily,
    // under four concurrent prewarm workers, is what let transient 429s push
    // some words into a different projection than the rest.
    void selfCheck()
      .then((chk) => {
        if (!chk) { console.warn("[wick-api] embed self-check could not run (no usable model)"); return; }
        console.log(`[wick-api] embed mode ${chk.mode}, self-check cos=${chk.cos}`);
        if (!chk.ok) {
          console.error(
            `[wick-api] EMBEDDING SELF-CHECK FAILED — cos(${"tomato"}, vegetable)=${chk.cos} is implausibly low. ` +
            "Vectors are probably not comparable; warmth ranks will be noise.",
          );
        }
      })
      .then(() => prewarm(COMMON_WORDS))
      .then((n) => console.log(`[wick-api] pre-warmed ${n} common embeddings`))
      .then(() => warmRankVocab(RANK_VOCAB))
      .then((n) => console.log(`[wick-api] rank vocab ready: ${n} words`));
  }
});

const wss = new WebSocketServer({ server: server as never, path: "/match" });

wss.on("connection", (socket: WebSocket, req) => {
  const ip = ipFromXff(req.headers["x-forwarded-for"]);
  const origin = req.headers["origin"];

  // Anti-abuse gate, BEFORE any match state is allocated (FR-16/FR-23):
  //  1) Origin: block other websites opening cross-origin sockets to us (native
  //     apps send no Origin and pass; App Attest is the future identity layer).
  //  2) Connection flood: bound new sockets per IP.
  if (!isAllowedOrigin(typeof origin === "string" ? origin : undefined, ALLOWED_ORIGINS)) {
    socket.close(1008, "origin_not_allowed"); // 1008 = policy violation
    return;
  }
  if (!connLimiter.take(ip)) {
    socket.close(1013, "rate_limited"); // 1013 = try again later
    return;
  }

  // Phase-1 identity: the App Attest key id. Passed as ?kid= for now; real
  // attestation verification replaces this (FR-16, hub.ts FLAG).
  const url = new URL(req.url ?? "/", `http://localhost:${PORT}`);
  const id = url.searchParams.get("kid") ?? `anon-${randomId()}`;

  const client: Client = {
    id,
    send: (frame: ServerFrame) => {
      if (socket.readyState === socket.OPEN) socket.send(JSON.stringify(frame));
    },
    close: () => socket.close(),
  };

  hub.connect(client);

  socket.on("message", (data) => {
    const frame = parseClientFrame(data.toString());
    if (!frame) {
      client.send({ t: "error", code: "bad_frame", message: "Unparseable frame." });
      return;
    }
    // Rate-limit the Gemini-triggering actions (guess/ask) per IP — bounds cost
    // from a single flooding connection without affecting real play.
    if (frame.t === "guess" || frame.t === "ask") {
      if (!wsLimiter.take(ip)) {
        client.send({ t: "error", code: "rate_limited", message: "Slow down a moment." });
        return;
      }
    }
    // Rate-limit match/dare CREATION per IP — bounds match- and invite-spam (each
    // queue/dare allocates a room / bot / pending invite). Resume re-queues are rare
    // enough to sit under the bucket.
    if (frame.t === "queue" || frame.t === "dare") {
      if (!createLimiter.take(ip)) {
        client.send({ t: "error", code: "rate_limited", message: "Too many matches too fast — take a breath." });
        return;
      }
    }
    hub.receive(client, frame);
  });

  socket.on("close", () => hub.disconnect(client));
  socket.on("error", () => hub.disconnect(client));
});

// The authoritative tick: advances cap, grace, bot-fill, and bot play.
const ticker = setInterval(() => hub.tick(), TICK_MS);

// Bound rate-limiter memory: drop idle buckets every 10 min.
const sweeper = setInterval(() => {
  httpLimiter.sweep();
  wsLimiter.sweep();
  createLimiter.sweep();
  connLimiter.sweep();
}, 600_000);

function shutdown() {
  clearInterval(ticker);
  clearInterval(sweeper);
  wss.close();
  server.close();
  console.log("[wick-api] shut down");
}
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
