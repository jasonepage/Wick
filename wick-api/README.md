# wick-api

The Wick server. It does four jobs:

1. **Scores guesses for the web game.** A browser has no word model, so the
   web client sends each guess here and gets back a rank and a heat band.
2. **Answers questions to the Keeper** for the web game.
3. **Runs live races** for both the iOS app and the web game, over a
   WebSocket. The server holds the secret word, keeps the clock and decides
   the winner.
4. **Serves the web game and the website** at guesswick.com, plus the share
   link preview pages and Apple's Universal Links file.

It is one Node process with everything in memory and no database. The only
secret it needs is a Google Gemini API key, read from its environment.

Runtime dependencies: `hono`, `@hono/node-server`, `ws`, `word-list`. That is
all of them, on purpose.

For how scoring works and the full route table, see the
[main README](../README.md#the-server-route-by-route).

## Run it

Node 22.9 or newer.

```bash
npm ci
cp .env.example .env   # optional: put your Gemini key in GEMINI_API_KEY
npm run dev            # http://localhost:8080, restarts on save
```

Without a key the server still runs: warmth falls back to a rough spelling
based score (marked `source: "fallback"`) and the Keeper is turned off. Every
setting is documented in [`.env.example`](.env.example). On a host like
Render, set them in the dashboard instead of a file.

## Scripts

| Command | What it does |
|---|---|
| `npm run dev` | Run from source and restart on every save |
| `npm test` | Run the test suite once (Vitest) |
| `npm run test:watch` | Re-run tests on every save |
| `npm run typecheck` | Type check everything, including tests |
| `npm run build` | Compile to `dist/` |
| `npm start` | Run the compiled server from `dist/` |
| `npm run build:all` | Build the server and the web client, and copy the web build into `public/` so one process serves both, the way guesswick.com runs |

GitHub Actions runs `typecheck`, `test` and `build` on every push and pull
request.

## Where things are

| File | What it does |
|---|---|
| `src/server.ts` | The HTTP routes and the WebSocket. A thin layer that plugs real sockets and a real clock into the modules below |
| `src/warmthservice.ts` | Scores a guess: embeds it, ranks it against the reference vocabulary, picks the band |
| `src/embeddings.ts` | Calls the Gemini embedding API, with retries, batching and a cache |
| `src/rankvocab.ts`, `src/rankvocab/` | The 10,000 word reference vocabularies a guess is ranked against, one per language |
| `src/lang.ts` | The languages a round can be scored in |
| `src/dictionary.ts` | The real-word check, so a typo is bounced instead of scored |
| `src/commonwords.ts` | Common first guesses, embedded at startup so they score instantly |
| `src/keeper.ts` | The Keeper: answers every yes or no question with Gemini (with a small thinking budget and the round's earlier answers) and scrubs the secret from the reply |
| `src/answercache.ts` | Saved Keeper answers per word, so a repeat question is instant and the same for everyone. Common ones are kept on the Render disk |
| `src/keeperwarm.ts`, `src/daily.ts`, `src/starterquestions.ts` | Once a day, asks the common questions about the daily word before players arrive |
| `src/moderation.ts` | A small content filter for words players choose |
| `src/hub.ts` | Connects players, the matchmaker, match rooms and bots |
| `src/matchmaker.ts` | Pairs waiting players, handles friend codes, and adds a bot when the queue is empty |
| `src/room.ts` | One live race: clock, guesses, solve, timeout and disconnects |
| `src/dare.ts` | The Dare mode, retired from both clients in 3.3. The server code is still here |
| `src/bot.ts` | The practice opponent, clearly shown to players as a bot |
| `src/words.ts` | The live race word pool |
| `src/protocol.ts` | Every WebSocket message, with its parser. The web client imports these types directly |
| `src/preview.ts` | Share link preview pages. A preview never contains a word |
| `src/revealmap.ts` | Lays out the reveal map shown after a round |
| `src/ratelimit.ts`, `src/abuse.ts` | Per-IP rate limits and the browser origin check |
| `src/alerts.ts` | Race alerts: the maintainer's phone through ntfy (off unless `WICK_NTFY_TOPIC` is set) and opted-in players through Apple push |
| `src/apns.ts` | Apple push client on Node's HTTP/2 and crypto, no library. Off unless the `WICK_APNS_*` keys are set |
| `src/pushsubs.ts` | The phones that asked for race alerts and which kinds, in memory; the app re-registers on every foreground |
| `src/traffic.ts` | Active player count against the same hour of the week over the past seven days, for the "unusual number playing" alert |
| `src/events.ts`, `src/metrics.ts` | Anonymous play counts and in-memory counters |
| `src/board.ts` | Today's race board: daily solves ranked by guesses (hints count one extra) then time, auto names, sanity checks, kept on the data disk |
| `src/tally.ts` | This week's most guessed words and most asked questions for the Stats page: counts only, cool-or-colder guesses, nothing that names the answer, kept on the data disk |
| `scripts/` | Builders for the race pool and the Chinese vocabulary, and `growth.mjs`, which reads play counts from a log export |

Most modules are pure: they take their inputs, including the current time,
and return a result. That is why they can be tested without a network or a
real clock. Tests sit next to the code as `*.test.ts`.

## Security notes

- **The Gemini key lives only here.** Neither client ever holds it.
- **Keep `WICK_DEBUG_TOKEN` unset in production.** The `/debug/*` routes it
  turns on reveal the secret word.
- **Treat `WICK_NTFY_TOPIC` like a password.** Anyone who knows the topic can
  read the queue alerts. Set it in your host's dashboard, never in a file.
- **Set `WICK_ALLOWED_ORIGINS`** to your own domain, or browsers will not be
  allowed to open a live race socket.
- **Live race identity is not yet cryptographically verified.** Players are
  identified by a random per-install id, and the server relies on per-IP rate
  limits and the origin check. Apple App Attest is planned; the hook for it is
  the `attest` option in `src/hub.ts`. See [SECURITY.md](../SECURITY.md).

## Deploying

[`render.yaml`](../render.yaml) at the repository root is a Render Blueprint
for one always-on instance. Live races need a server that does not sleep, so
a free tier that spins down will drop matches. Auto deploy is off on purpose:
a restart drops every live race and clears the warmed vocabulary, so deploy
when you are watching.

The original cross-platform design note is in
[`docs/wick/CROSS_PLATFORM.md`](../docs/wick/CROSS_PLATFORM.md).
