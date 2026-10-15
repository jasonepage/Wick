# wick-web

The Wick web game, played at [guesswick.com](https://guesswick.com). It plays
the same daily puzzle as the iOS app, plus practice rounds and live races,
in any modern browser. It is the answer for Android and desktop players.

Plain TypeScript and Vite, no UI framework. Runtime dependencies: `qrcode`
(QR codes for joining a live race) and `mediabunny` (packaging Solve Replay videos as MP4).

The web client holds **no API key**. A browser has no word model, so every
guess is scored by [`wick-api`](../wick-api), which is where the Gemini key
lives.

## Run it

Node 22.9 or newer (22.18 or newer for `npm test`, which runs TypeScript
tests directly). Start a local `wick-api` first, then:

```bash
npm ci
npm run dev        # http://localhost:5173
```

Open the page in two tabs to play both sides of a live race.

### Which server it talks to

In this order:

1. `?server=ws://host:port` on the page URL
2. `VITE_WICK_SERVER` in `wick-web/.env` (copy [`.env.example`](.env.example); the file is gitignored)
3. The same origin the page was served from. In production, `wick-api`
   serves the built web game, so this is the normal case
4. On localhost with nothing set: `ws://localhost:8080`, a local `wick-api`

## Scripts

| Command | What it does |
|---|---|
| `npm run dev` | Development server with live reload |
| `npm test` | Unit tests (Node's built-in test runner) |
| `npm run typecheck` | Type check with `tsc` |
| `npm run build` | Type check, then build static files into `dist/` |
| `npm run preview` | Serve the built `dist/` locally |

GitHub Actions runs `typecheck`, `test` and `build` on every push and pull
request.

## Where things are

| Path | What it does |
|---|---|
| `src/main.ts` | The app: home menu, daily and practice rounds, live race screens |
| `src/game/daily.ts`, `src/game/dailyPool.json` | The daily puzzle, ported from iOS so both pick the same word on the same day |
| `src/game/playlang.ts` | Which language a round is played in |
| `src/game/replay/` | Solve Replay: timing (`timeline.ts`), drawing one frame (`scene.ts`), and recording to a video file (`record.ts`) |
| `src/game/revealcard.ts` | The reveal map and the spoiler-free share image |
| `src/game/gloss.ts` | Short word meanings for players learning English |
| `src/game/stats.ts` | Daily stats and streaks, saved only in the browser |
| `src/game/ghost.ts` | "Race me" share links |
| `src/game/starters.ts` | Suggested questions for asking Wick |
| `src/game/wickface.ts`, `src/game/backdrop.ts`, `src/game/sound.ts` | The Wick character, the moving background, and sound effects |
| `src/i18n.ts` | Every menu string, in six languages |
| `src/net/` | The server connection: `api.ts` for scoring and the Keeper, `client.ts` for live races, `events.ts` for anonymous play counts |
| `src/net/protocol.ts` | Re-exports the live race message types straight from `wick-api/src/protocol.ts` through the `@server/*` path alias, so the client and server cannot drift |
| `public/` | Icons, sounds, the website pages under `marketing/`, and the meaning files under `gloss/` |
| `scripts/` | Builders for the `gloss/` meaning files |
| `tests/` | Unit tests |

The meaning files in `public/gloss/` are built from outside dictionaries and
keep their own licenses. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
