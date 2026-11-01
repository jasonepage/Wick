# Wick 3.8 handoff: visual product design (for a fresh session)

You are picking up Wick 3.8 from an earlier session. This session's job is to
make Wick look better across the iPhone app, the web game, and the store and
share art. Read this whole file before doing anything. The older notes are in
`docs/wick/HANDOFF_3.7.md` and `docs/wick/BUGS_3.7.md`. Read those only if a
question comes up about the server or the Keeper.

Written October 31, 2026.

## How to work in this project

- The repo is on Jason's Mac at `/Users/jasonpage/Documents/GitHub/wick`
  (public repo github.com/jasonepage/Wick, branch `main`). Work on it through
  the linked-computer tools: the shell sees it at `$HOME/mnt/wick`. The repo
  is public, so never put private or personal notes in it.
- You make the git commits. Jason does NOT commit; he only pushes, from GitHub
  Desktop. One commit per piece of work, with everything in the Changes list
  included, always on `main` (no branches). End commit messages with the
  attribution lines your session gives you.
- Git needs to delete its own lock files. Ask for delete permission on the
  wick folder (the delete-permission tool) BEFORE your first commit. If a
  commit warns "unable to unlink ... .lock", remove the leftover `.git/*.lock`
  and `.git/objects/maintenance.lock` files, or GitHub Desktop will fail.
- The shell on the Mac cannot push. Ask Jason to push.
- The shell on the Mac is a Linux shell with GNU sed: use `sed -i`, not
  `sed -i ''`.
- Web deploys: the server and web client run on Render with auto-deploy OFF on
  purpose. After Jason pushes, he presses Manual Deploy on the `wick-api`
  service. A deploy restarts the server and drops live races.
- iOS: there is NO Swift compiler. Write Swift very carefully, split long
  expressions into typed `let`s, and ask Jason to build in Xcode and send the
  errors. The `tree-sitter-swift` Python package (in the cloud workspace)
  gives a syntax-only check.
- Swift settings: Swift 5 mode with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
  Any type used off the main thread (for example the face data used by the
  replay renderer) must be marked `nonisolated`. Xcode uses synchronized
  folders, so new Swift files are picked up without editing the project file.
- Web checks: in `wick-web`, `npx tsc --noEmit` and `npm test` run on the Mac.
  `vite build` cannot empty `dist` inside the repo; build to
  `--outDir $HOME/wickdist --emptyOutDir` instead.
- Looking at your own work: Playwright with headless Chromium is installed in
  the cloud workspace. Bundle a page on the Mac with esbuild (or stage the
  built files), render it in the workspace, and look at the screenshot before
  you show Jason anything. For iPhone screens, ask Jason for screenshots.
- When replacing an image on the site or README, use a new file name or a
  version in the address (like `?v=5`) so the new image shows right away.
  The favicons and link preview picture are on `?v=4` now.
- Never write secrets (Gemini key, debug token) into any file. If a command
  needs one, have Jason paste it into that one command.
- Writing style for Jason: plain words, short sentences, about a 7th grade
  level, no abbreviations without the full term first, no em dashes anywhere
  (code comments, copy, commit messages, replies), and never the word "slop".
  Give a real example, not a made-up comparison. For a real decision, offer 2
  to 4 clickable options with your pick first. For a yes or no question,
  answer in one word first.

## Where things stand

- Latest commit: `99b5f43` (replay Wick follows the latest tile). Ask Jason
  whether he has pushed it and deployed.
- 3.7 (build 1) was submitted to App Review on October 21, 2026. Ask whether it
  is live. Once it is live, Jason removes the three old coin in-app purchases
  in App Store Connect.
- 3.8 is set in Xcode: version 3.8, build 1. The 3.8 section of `CHANGELOG.md`
  lists what is in it so far (the replay video draws the new Wick on iPhone,
  and old race links open on a cold launch).
- 3.8 has NOT been built in Xcode yet. The risky parts are the new
  `KeeperFaceCG.swift` and the `nonisolated` marks in `KeeperFace.swift`. Ask
  Jason to build first and fix any errors before starting design work.

### Not committed yet: ChatGPT's "silver fox" brows (decide first)

Jason had ChatGPT make new Wick art. It left these uncommitted changes:

- Five concept pictures, 1024 by 1024: `docs/icon-daddy-wick-concept.png` and
  `-v2` to `-v5`. All five show the same idea: purple Wick with the Sly face,
  half-shut eyes, a smirk, and thick silver brows, on a dark sky with gold
  sparkles. v1 has the thinnest brows and most sparkles; v3 is the biggest
  with the strongest glow; v5 is softer and lighter.
- Code that makes the in-game brows match that look:
  - `wick-web/src/game/wickface.ts`: lighter silver brows
    (`BROW_GREY` 226, 223, 238), a new dark purple outline (`BROW_KEY`
    86, 72, 116), the loose stray hairs replaced by two soft bumps on top of
    each brow (`tuft()`), smoother shape, fewer points (`n` 64).
  - `Hunch/Theme/KeeperFace.swift`: the same change, plus the outline stroke
    in `draw(in:)`.
  - `Hunch/Theme/KeeperFaceCG.swift`: the outline stroke for the replay video.
  - `wick-web/tests/wick.test.ts`: the face draw list grows from 18 to 19
    items (the outline is a new item).
- Web tests pass (67 of 67) and the web type check is clean with these
  changes. The Swift side is not built.

Before you change anything else, ask Jason:

1. Keep the new brows and commit them? Pick option 3 first if unsure:
   - Commit as they are.
   - Throw them away (`git checkout` those four files).
   - Draw them first: render the web Wick with the new brows next to the
     concept pictures and show Jason before committing (recommended).
2. Should one of the five pictures become the new app icon? If yes, which
   one. The app icon lives in `Hunch/Assets.xcassets/AppIcon.appiconset`
   (light, dark and tinted), the web icons in `wick-web/public`, and the
   README picture is `docs/icon-sly.png`. Jason wants the icon used
   everywhere (App Store, favicon, README, store art).

## The job: make Wick look better (3.8)

The request is open: "improve the visual product design". Start by finding
out what Jason means, then show, do not tell.

1. Get the build working (above) and settle the brow question.
2. Take stock. Screenshot every web screen in the workspace (home, a round
   in progress, Ask Wick, reveal, race, daily race board, tutorial, settings
   or help), at phone width and desktop width. Ask Jason for iPhone
   screenshots of the same screens and the iPad home. Put them side by side.
3. Ask Jason what bugs him most, with clickable options. Real places to
   start:
   - Wick himself (brows, glow, how the six faces read at small sizes).
   - The round screen (the busiest screen: guesses list, warmth, Ask Wick
     answers).
   - The reveal and the share card (what people post).
   - Home (first impression; iPhone, iPad and web).
   - Store art: App Store screenshots and the README screenshots.
4. Make changes one area at a time. For each area: a quick mockup or render,
   Jason picks, then build it on BOTH iPhone and web so they match, then one
   commit.
5. Keep the web and iPhone looks in step. Most screens exist on both.

### What Jason has already decided (do not undo)

- Brand color is purple (the Wick violet, about RGB 125, 92, 235), not red
  or orange.
- Only the current flame Wick is used anywhere. The old round blob Wick is
  ugly and must not come back.
- Wick is a tired old man flame: the original chunky flame and flat style,
  bushy grey brows drawn differently on each side, heavy drooping lids,
  subtle bags under the eyes. No blush and nothing sexualized.
- Six faces and when they show: Sly (player is cold), Flustered (warm, hot,
  boiling), Shocked (solved), Calm (the grey Wick: gave up, lost, "won't
  say"), Serious (live race), Focus (while an Ask Wick answer is pending).
- On a solve, Wick stays Shocked and keeps blinking. He does not settle to
  Calm.
- Home and the round's welcome Wick cycle through all six faces every 5
  seconds with a blink between, and stay purple for every face.
- In the replay video, Wick takes the color and face of the tile he just
  jumped to, not the best one so far.
- Headline everywhere: "Race against others to reveal the Secret Word!" with
  "Ask Wick 20 questions or guess by the meaning." under it. Never name any
  other guessing game in the copy.
- The game is 100% free: no coins, no shop, no purchases, no ads. Hints are
  3 free a day.
- No starter question chips on the web board.
- The live race is the fun mode and leads the Race area. The ghost race is
  gone on both platforms.
- The web game should suit Twitch streamers: easy music mute, no sudden loud
  sounds, an obvious live race button, fast queueing.

## Map of the visual code

### Colors, spacing and type

- iPhone: `Hunch/Theme/HunchTheme.swift`
  - Palette: solved green, boiling red, hot coral, warm amber, cool teal,
    cold mint teal, freezing blue, gold, streak orange, keeper violet,
    neutral grey.
  - Spacing 4, 8, 12, 16, 20, 28. Corner radius: chip 10, field 14, card 20,
    hero 26.
  - Fonts: SF Rounded for numbers and the reveal word.
- Web: `wick-web/src/style.css` (about 970 lines). The `:root` block holds
  the same palette as raw RGB channels (`--p-hot` and so on) so rules can
  pick their own see-through level. Light pastel home, dark round screen,
  soft frosted cards with a 26 pixel radius.
- The face colors live in `wick-web/src/game/wickface.ts` and
  `Hunch/Theme/KeeperFace.swift`. Keep these and the palettes above the same.

### Wick (the Keeper)

The face data is defined twice, once per platform, and the two files must
stay in lockstep (same numbers, same order):

- `wick-web/src/game/wickface.ts` and `Hunch/Theme/KeeperFace.swift`: the six
  faces, eyes, brows, mouth, sweat drop, blink, and the game-state-to-face
  picker (`faceFor`).

Four drawers use that data:

- `wick-web/src/game/wick.ts`: SVG Wick in the web game, including the
  `showcase` face cycling (`SHOWCASE_SECONDS = 5`).
- `wick-web/src/game/wickcanvas.ts`: canvas Wick for the web replay video.
- `Hunch/Theme/KeeperView.swift` (with `KeeperFace.swift`): SwiftUI Wick in
  the app.
- `Hunch/Theme/KeeperFaceCG.swift`: Core Graphics Wick for the iPhone replay
  video.

Tests: `wick-web/tests/wick.test.ts` checks the face draw list (slot count,
open or shut eyes, brows, sweat). Update it when you add or remove a drawn
part.

### Screens

- iPhone: `Hunch/Views/` (HomeView, GameView, AskQuestionView, RevealView,
  RevealShareCard, DailyBoardView, DuelView for races, StatsView,
  ArchiveView, SettingsView, HowToPlayView, TutorialCoach,
  AchievementsView). Backgrounds and effects in `Hunch/Theme/`
  (AnimatedMeshBackground, ConfettiView, MusicPulseOverlay, WickDance).
- iPad: HomeView uses a wider 840 point column when the size class is
  regular.
- Web: `wick-web/src/main.ts` (all screens), `game/backdrop.ts` (animated
  background), `game/revealcard.ts` (share card), `game/tutorial.ts`,
  `dance.ts`.
- Replay video: `wick-web/src/game/replay/scene.ts` and
  `Hunch/Replay/ReplayScene.swift`.

### Art and store files

- App Store header and search art: `docs/appstore/wick-header-3840x1646.png`
  and `wick-search-3840x2560.png`.
- README screenshots: `docs/screenshots/01-home.png` to `04-reveal.png`
  (see the README.txt there).
- Web icons, link preview picture (`og-image.png`) and the install manifest:
  `wick-web/public`. Marketing pages: `wick-web/public/marketing`.

## Other open items (not design, but do not lose them)

- Jason builds 3.8 in Xcode and sends errors.
- Push and Manual Deploy for anything not yet live.
- After a deploy, check the "park" answers with
  `/debug/keeper?secret=park&q=does it have grass and trees?&fresh=1`
  (needs the debug token; Jason pastes it into the command).
- Jason asked to hide a "Product Hunt" badge. It was not found anywhere in
  the repo. Ask him where he sees it.
- Optional: MP4 and GIF animations of Wick cycling his faces, for Jason's
  visual files.
