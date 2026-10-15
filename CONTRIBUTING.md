# Contributing to Wick

Thanks for taking a look. Wick is a small, one developer project, and every
good bug report, test, translation fix or pull request makes a real
difference. This guide covers how to set up the code, the rules that keep the
game fair, and what a pull request needs before it can be merged.

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Contents

- [Ways to help](#ways-to-help)
- [How the repository is laid out](#how-the-repository-is-laid-out)
- [Setting up](#setting-up)
- [Running the checks](#running-the-checks)
- [Rules that keep the game fair](#rules-that-keep-the-game-fair)
- [Code style](#code-style)
- [Commits and pull requests](#commits-and-pull-requests)
- [Licensing of contributions](#licensing-of-contributions)
- [Reporting security problems](#reporting-security-problems)

## Ways to help

| You want to | Where to start |
|---|---|
| Report a bug | [Open a bug report](https://github.com/jasonepage/Wick/issues/new/choose). Please include the puzzle number, not the answer. |
| Fix a word or translation | The Race word pool in `wick-api/scripts/racepool.txt` is a first draft that still needs native speaker review for Spanish, French, Italian, German and Chinese. Use the "Word or translation fix" issue form, or send a pull request. |
| Add tests | Most server modules are pure and take an injected clock, so they are easy to test. See `wick-api/src/*.test.ts` for the pattern. |
| Improve the docs | Anything in a `README.md`, this file, or the comments at the top of a source file. |
| Take on something bigger | The planned "packs" interface described in the [README](README.md#where-this-is-going). Please open an issue first so we can agree on the shape. |

Issues labeled
[`good first issue`](https://github.com/jasonepage/Wick/labels/good%20first%20issue)
are small, safe, and a good way to learn the codebase.

If you plan to spend more than an hour on a change, open an issue or comment
on an existing one first. That way nobody builds something that cannot be
merged.

## How the repository is laid out

Wick is three programs in one repository. They share the same daily puzzle and
the same scoring rules.

| Folder | What it is | Language |
|---|---|---|
| `Hunch/`, `Hunch.xcodeproj`, `HunchTests/` | The iOS app | Swift, SwiftUI |
| `wick-api/` | The server that scores the web game and runs live races | TypeScript on Node, Hono, ws |
| `wick-web/` | The browser game at [guesswick.com](https://guesswick.com) | TypeScript, Vite, no framework |
| `debug/` | Developer tools: the embedding build pipeline, a load tester, a Python copy of the Keeper's rule table | Python, Swift, Node |
| `docs/` | GitHub Pages site, diagrams, screenshots | HTML, SVG |

**Why is the iOS app called "Hunch"?** Hunch was the game's working name. The
Xcode target, scheme and bundle identifier kept that name so the shipped App
Store app stays the same app across updates. Everything the player sees says
Wick.

## Setting up

### What you need

| Tool | Version | Needed for |
|---|---|---|
| Node.js | 22.9 or newer (22.18 or newer to run the web tests) | `wick-api`, `wick-web` |
| npm | comes with Node | `wick-api`, `wick-web` |
| Xcode | 26 or newer | the iOS app |
| A Google Gemini API key | free tier works | real hot and cold scores on the server (optional) |
| Python 3 | any recent version | only the scripts in `debug/` and `*/scripts/` |

### Server and web game

```bash
cd wick-api
npm ci
cp .env.example .env        # optional: add your GEMINI_API_KEY
npm run dev                 # http://localhost:8080

# in a second terminal
cd wick-web
npm ci
npm run dev                 # http://localhost:5173
```

Without a Gemini key the server still runs. Scores fall back to a rough
spelling based guess (marked `source: "fallback"`) and the Keeper is turned
off. That is enough for most bug fixes and all of the tests. Open the web game
in two browser tabs to play both sides of a live race.

### iOS app

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
open Hunch.xcodeproj
```

In `Config/Local.xcconfig` (it is gitignored), set `DEVELOPMENT_TEAM` to your
own Apple team and `PRODUCT_BUNDLE_IDENTIFIER` to an identifier you own.
Single player works with no server and no key. iCloud sync and Game Center
need those capabilities on your App ID; without them those calls fail quietly
and the game still plays. The README's [iOS section](README.md#ios) has the
details.

## Running the checks

Run these before you open a pull request. GitHub Actions runs the server and
web checks again on every push and pull request.

**Server**

```bash
cd wick-api
npm run typecheck
npm test
npm run build
```

**Web game**

```bash
cd wick-web
npm run typecheck
npm test
npm run build
```

**iOS app.** In Xcode, choose the Hunch scheme and press Command U, or from
the command line:

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch \
  -destination 'platform=iOS Simulator,name=<any installed iPhone simulator>'
```

The iOS tests are not run in CI yet, so please say in your pull request that
you ran them.

## Rules that keep the game fair

These matter more than style. A pull request that breaks one of them will not
be merged, even if everything else about it is good.

1. **The secret word never reaches a player early.** No route, socket frame,
   share link, preview card, replay video, log line or error message may
   contain the answer before the round is solved. Keeper replies are scrubbed
   of the secret before they leave the server; keep it that way.
2. **The server is the only judge.** In a live race, the server decides the
   score, the clock and the winner. Do not move a decision that affects who
   wins into a client.
3. **iOS and web must agree.** The same guess should earn the same band on
   every platform. If you change any of these, change both sides in the same
   pull request:
   - the band cutoffs (`Hunch/Theme/HunchTheme.swift` and the
     `WICK_RANK_*` defaults on the server)
   - the daily word pool (`Hunch/Engine/DailyWords.swift` and
     `wick-web/src/game/dailyPool.json`)
   - the reference vocabularies (`Hunch/Engine/RankVocabulary*.swift` and
     `wick-api/src/rankvocab*`)
   - the live race messages (`wick-api/src/protocol.ts` and
     `Hunch/Live/MatchProtocol.swift`). The web client imports the server's
     types directly, so it cannot drift; the Swift copy can.
4. **Privacy is a promise.** If a change sends anything new off the device,
   update [PRIVACY.md](PRIVACY.md), the website's privacy page
   (`wick-web/public/marketing/privacy.html`) and the iOS privacy manifest
   (`Hunch/PrivacyInfo.xcprivacy`) in the same pull request.
5. **No secrets in the repository.** API keys live in `wick-api/.env` or in
   your host's settings, and Apple team details live in
   `Config/Local.xcconfig`. Both are gitignored. The web client never holds a
   key.
6. **Few dependencies, on purpose.** The server has four runtime
   dependencies, the web game has two, and the iOS app uses only Apple
   frameworks. A new dependency needs a clear reason in the pull request and a
   license that works with MPL 2.0 and the App Store.

## Code style

- **Match the file you are in.** TypeScript uses two space indents and
  `strict` mode. Swift uses four space indents and follows the existing
  SwiftUI patterns.
- **Every source file opens with a short comment** that says what the file is
  for, plus the MPL license notice. Copy the header from a neighboring file.
- **Write comments for a newcomer.** Explain why, in plain words. Many files
  already do this; please keep it up.
- **Keep logic pure where you can.** Match rules, scoring and timing live in
  modules that take inputs (including the current time) and return results.
  That is what makes them testable. Sockets, timers and network calls stay in
  the thin layer around them (`server.ts`, `hub.ts`, `MatchClient.swift`).
- **New logic needs a test.** A bug fix should come with a test that fails
  without the fix.
- **Player facing text** goes through the string tables
  (`Hunch/Engine/Loc.swift` on iOS, `wick-web/src/i18n.ts` on the web) so it
  can be translated.

## Commits and pull requests

1. Fork the repository and create a branch from `main`.
2. Keep each pull request about one thing. Two small pull requests are easier
   to review than one large one.
3. Write commit messages as a short summary of what changed, starting with the
   area when it helps. Real examples from this repository:
   - `Server: score a round in Spanish, French, Italian or German`
   - `Web: per-guess meanings for Spanish, French, Italian and German`
   - `iOS: language settings like the web, and cross-language races`
4. Fill in the pull request template. Screenshots or a short screen recording
   help a lot for anything visual.
5. Make sure the checks are green. A maintainer will review, may ask for
   changes, and will merge when it is ready.

## Licensing of contributions

Wick's code is under the [Mozilla Public License 2.0](LICENSE). When you send
a pull request, you agree that your contribution is shared under that same
license. There is no separate contributor agreement to sign.

Some data files are not Wick's own work and keep their original licenses (for
example the fastText based embedding models and the wordfreq based word
lists). They are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
If you add data or code that came from somewhere else, add it to that file in
the same pull request and say where it came from.

The Wick name, the flame character and the App Store listing are not covered
by the code license.

## Reporting security problems

Please do not open a public issue for a security problem, including any way to
learn the secret word without guessing it. Follow [SECURITY.md](SECURITY.md)
instead.
