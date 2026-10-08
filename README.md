# Wick

Wick is a daily word game where you guess by meaning, not spelling. There is one
secret word a day. Type any word and Wick tells you how close you are in meaning:
freezing, cold, cool, warm, hot, boiling. "Tomato" is hot when the answer is
"red"; "tomb" is freezing, even though the letters look close. You can also ask
Wick, the little flame who guards the word, yes or no questions. It plays on the
web at [guesswick.com](https://guesswick.com) and as an iOS app
([Wick: Daily Word Game](https://apps.apple.com/app/id6777743483)), and both
play the same daily puzzle in English, Spanish, French, Italian and German.

This repository is the whole thing: the iOS app (`Hunch/`, the project's
original name), the server (`wick-api/`) and the web client (`wick-web/`).

## How the scoring works

Every word is turned into a list of numbers called an embedding. Words that are
used in similar ways end up with similar numbers, so the distance between two
embeddings is a decent stand-in for how related the two words are. Wick takes
the embedding of your guess and the embedding of the secret word and measures
the angle between them (cosine similarity). A small angle means close in
meaning.

Raw similarity is hard to read, so Wick converts it to a rank. The server
embeds a vocabulary of about ten thousand common words once, sorts them by
similarity to today's secret, and reports where your guess lands in that list.
Rank 1 is the answer, rank 2 is the single closest word, and so on. The bands
are fixed cutoffs on that rank: boiling is rank 25 or better, hot is 100 or
better, warm 400, cool 1200, and cold beyond that. Your guess has to be a
real dictionary word to be scored at all.

Where the embeddings come from depends on the platform:

- Web: the server computes the score. The browser sends the guess and the
  secret to `wick-api`, which calls the Google Gemini embedding API and sends
  the score back. If no Gemini key is set, the server falls back to a rough
  spelling-based score and labels it as a fallback.
- iOS, single player: everything stays on the device. English uses Apple's
  built-in word embedding (`NLEmbedding`). The other four languages use small
  embedding models bundled in this repository under `ODRResources/`, built from
  fastText vectors and downloaded on demand the first time you pick a language.
  Yes or no questions to Wick are answered by Apple's on-device Foundation
  Models on iOS 26, with a rule-based answer for a few dozen known facts per
  word so the model cannot contradict them.
- iOS, live multiplayer (Race): the server scores both players so they see the
  same numbers, same path as the web.

The daily word is chosen by a seeded shuffle of a fixed pool (`DailyWords.swift`
on iOS, `dailyPool.json` on the web) keyed to the day number, so every device
agrees on the puzzle without asking a server.

## Running the web version

You need Node 22.9 or newer and a Gemini API key. The web client has no key of
its own; it talks to `wick-api`, and the key lives only there.

```bash
# 1. Server
cd wick-api
npm ci
cp .env.example .env        # put your key in GEMINI_API_KEY
npm run dev                 # http://localhost:8080, reloads on change

# 2. Web client, in a second terminal
cd wick-web
npm ci
npm run dev                 # http://localhost:5173, talks to localhost:8080
```

To serve the game from one process the way guesswick.com does, build the client
into the server's `public/` folder and start the server:

```bash
cd wick-api
npm run build:all
npm start
```

`render.yaml` at the repository root is an optional Render Blueprint for the
same layout. Every server variable is documented in `wick-api/.env.example`.
Two worth knowing: `WICK_ALLOWED_ORIGINS` must include your own domain for the
browser's live-match socket to connect, and `WICK_DEBUG_TOKEN` should stay
unset in production, since the debug routes reveal the secret word.

## Building the iOS app

You need Xcode 26 or newer and an Apple developer account for device builds.
The app targets iOS 17; the on-device question answering needs iOS 26 and an
Apple Intelligence capable device, and degrades to rule-based answers below
that.

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
open Hunch.xcodeproj
```

Edit `Config/Local.xcconfig` (it is gitignored) and set:

- `DEVELOPMENT_TEAM` to your Apple Team ID.
- `PRODUCT_BUNDLE_IDENTIFIER` to a bundle id you own.
- `WICK_SERVER_BASE` to your own `wick-api` if you want live multiplayer
  against your server. Leave it out to use the public Wick server. Write URLs
  as `wss:/$()/host` because `//` starts a comment in an xcconfig file.

Then build and run from Xcode. Single player works with no server and no key.
iCloud sync and Game Center need the matching capabilities enabled on your App
ID; without them those calls fail quietly and the game still plays.

## Bring your own Gemini key

The only secret in the whole system is one Google Gemini API key, and it is
read from the `GEMINI_API_KEY` environment variable on the server. Nothing in
this repository contains a key, and neither client ever holds one.

1. Create a key at https://aistudio.google.com/apikey.
2. Locally: copy `wick-api/.env.example` to `wick-api/.env` and fill in
   `GEMINI_API_KEY`. The `.env` file is gitignored.
3. On a host: set `GEMINI_API_KEY` in the host's environment settings instead
   of a file.

The key is sent to Google as a query parameter on each embedding call, which
is Google's documented pattern for this API. Restrict the key to the
Generative Language API in the Google Cloud console.

## Repository map

| Path | What it is |
|---|---|
| `Hunch/` | iOS app source (SwiftUI). `Engine/` holds scoring, word lists and the Keeper. `Live/` is the multiplayer client. |
| `Hunch.xcodeproj`, `Config/` | Xcode project, shared build settings (`Wick.xcconfig`) and the merged `Info.plist`. |
| `ODRResources/` | Core ML embedding models for Spanish, French, Italian and German, loaded on demand. |
| `wick-api/` | Node server: scoring, matchmaking, bots, share previews, static hosting of the web client. |
| `wick-web/` | Vite and TypeScript web client. |
| `debug/` | Developer tools: the embedding build pipeline, a load tester, and a Python port of the Keeper's rule table. |
| `docs/` | The GitHub Pages site and a design note on the cross-platform plan. |

## License

Wick's source code is under the [Mozilla Public License 2.0](LICENSE). You may
read, run, fork and build on it; changes to Wick's own files must be published
under the same license. The four bundled embedding models are derived from
fastText vectors and carry their own license; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The Wick name, the flame
character and the App Store listing are not covered by the code license.
