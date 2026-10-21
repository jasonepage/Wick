# Wick 3.7 handoff (for a fresh session)

You are picking up Wick 3.7 work from an earlier session. Read this whole file
before doing anything. Also read `docs/wick/BUGS_3.7.md`.

## How to work in this project

- The repo is on Jason's Mac at `/Users/jasonpage/Documents/GitHub/wick`
  (public repo github.com/jasonepage/Wick, branch `main`). Work on it through
  the linked-computer tools: the shell sees it at `$HOME/mnt/wick`.
- You make the git commits. Jason does NOT commit; he only pushes, from GitHub
  Desktop. One commit per piece of work, everything included, always on `main`
  (no branches). End commit messages with the attribution lines your session
  gives you.
- Git needs to delete its own lock files. Ask for delete permission on the
  wick folder (the delete-permission tool) BEFORE your first commit. If a
  commit warns "unable to unlink ... .lock", remove the leftover `.git/*.lock`
  and `.git/objects/maintenance.lock` files, or GitHub Desktop will fail.
- The shell on the Mac cannot push (no GitHub sign-in). Ask Jason to push.
- Web deploys: the server and web client run on Render, with auto-deploy OFF
  on purpose. After Jason pushes, he (or you, in the built-in browser if he is
  signed in to dashboard.render.com) presses Manual Deploy on the `wick-api`
  service. A deploy restarts the server and drops live races.
- iOS: there is NO Swift compiler. Write Swift very carefully, keep long
  expressions split into typed `let`s, and ask Jason to build in Xcode and send
  errors. A tree-sitter Swift parser is handy for a syntax-only check.
- Web checks: in `wick-web`, `npx tsc --noEmit` and `npm test` run on the Mac.
  `vite build` cannot empty `dist` inside the repo; build to
  `--outDir $HOME/wickdist --emptyOutDir` instead.
- Never write secrets (Gemini key, debug token) into any file. If a command
  needs one, have Jason paste it into that one command.
- Writing style for Jason: plain words, short sentences, about a 7th grade
  level, no abbreviations without the full term first, no em dashes, never the
  word "slop". Give a real example, not a made-up comparison. For a real
  decision, offer 2 to 4 clickable options with your pick first.

## Done in the last session (October 21, 2026)

All committed on `main`. Check `git log` and ask whether Jason has pushed the
latest ones.

- `d329a65` Web: the six final Keeper faces in `wick-web/src/game/wickface.ts`,
  drawn by `wick.ts` (and `wickcanvas.ts`), picked from the game state, with a
  blink-and-morph between faces. Faces: Sly (cold), Flustered (warm, hot,
  boiling), Shocked (solved), Calm (the grey Wick: gave up, lost, "won't say"),
  Serious (live race), Focus (while an Ask Wick answer is pending).
- `2ad0aea` iOS: the same faces in `Hunch/Theme/KeeperFace.swift` and
  `KeeperView.swift`. Also made the game 100% free: removed the coin shop,
  in-app purchases, coins everywhere, and the cosmetic wardrobe. Hints are 3
  free a day, then none until tomorrow (new Loc string `noHintsToday`).
- `b7d4943` New Sly app icon (light, dark, tinted), web favicons and
  home-screen icons, README image (`docs/icon-sly.png`), and removed coin text
  from the marketing and docs pages.
- `1f3acdf` Solved Wick stays Shocked and keeps blinking (no settle to Calm).
- Jason built iOS once and it ran (the faces showed). Keep an eye out for any
  build errors he reports.

## Done in the second session (October 21, 2026, evening)

The Keeper job below is DONE (commits `0570235`, `9b309b4`, `d97830b`).
Jason chose "Server Gemini" for iPhone solo.

- Server: no automatic answers; thinking budget 512 (WICK_KEEPER_THINKING);
  typical-case prompt; round history from the web (`/keeper` body `history`)
  and from races (kept per player in the hub); saved answers in
  `answercache.ts` (`keeper-answers.json` on the Render disk, common ones
  only); daily warm-up in `keeperwarm.ts` (about 55 calls a day, English
  only; WICK_KEEPER_WARM_LANGS adds languages); debug routes
  `/debug/keeper?...&fresh=1` and `/debug/keeper-cache`.
  `offlinekeeper.ts` and the server's `worddata.json` were removed.
- "swings" fix in `warmthservice.ts` (`scoringForm`).
- iOS: `Hunch/Engine/KeeperClient.swift` (new). `QuestionService` asks the
  server first, then Apple's on-device model, else fails with Retry. Chips are
  all shown and sent in English. The tutorial still uses the tags. The offline
  banner is gone. NOT BUILT YET: Jason needs to build in Xcode.
- Privacy policy, PRIVACY.md and the support FAQ say questions go to the
  server and Gemini.
- Still to do: Jason updates the App Store privacy label (questions are sent
  to the server, not linked to identity); deploy; check park answers with
  `/debug/keeper` after deploy.
- Prompt changes: bump `KEEPER_PROMPT_VERSION` in `keeper.ts`, or old saved
  answers stay.

## (Done) The job: replace the automatic Keeper answers with Gemini plus saved answers

Jason's call: the automatic (deterministic) answers are wrong far too often
and fixing them word by word is endless. Example he hit: for "chair" it said
it was used for entertainment. Why: `offlinekeeper.ts` (server) and
`WordAttributes.deterministicVerdict` (iOS) answer from ONE category tag per
word plus a few hand lists, so they guess at the group, not the word.

Honest note to keep in mind: in the one logged round (daily #1421 "park",
see BUGS_3.7.md) the automatic answers were right and Gemini got three wrong.
So removing the automatic answers only works if Gemini gets better at the
same time. Do both.

### Server (wick-api), for the web game and live races

Where it happens: `wick-api/src/keeper.ts`, function `keeperAnswer`. It is
called from `server.ts` (the `/ask` route near line 481, the debug route near
line 400, and the in-race `answerKeeper` near line 631).

1. Remove the deterministic-first step in `keeperAnswer` (the
   `deterministicAnswer(...)` call). Keep both leak checks exactly as they are.
   Leave `offlinekeeper.ts` in place for now unless nothing else uses it.
2. Make Gemini better (from BUGS_3.7.md):
   - Turn thinking back on with a small budget (for example 512) and make sure
     only the final answer text is used, never the reasoning.
   - Change the prompt to "answer for the typical case" (a typical park has
     grass and trees; you can walk a dog there) and drop "Never default to
     Yes".
   - Send the round's earlier questions and verdicts when the client has them
     (the web client would need to send them; iOS already passes `history`).
3. Save answers (the cache):
   - Key: secret word (lowercased) + language + the question normalized
     (lowercase, trim, collapse spaces, drop trailing punctuation).
   - Value: verdict + reply. Look it up before calling Gemini; store after a
     good answer (never store "unavailable" or leak results).
   - Keep it in memory and in a JSON file in `WICK_DATA_DIR` (the Render disk,
     already used by `board.ts` and `pushsubs.ts`), so deploys keep it.
   - Bonus: the same question always gets the same answer, which is fairer in
     live races.
4. Answer the common questions early: once a day, for the daily word, ask a
   list of common questions (the starter questions plus the weekly "Most asked
   questions") so the first players get instant answers. Keep the daily cost
   small and log it.
5. Tests in `keeper.test.ts`: the exact "park" questions from BUGS_3.7.md with
   a fake generator, the cache (hit, miss, normalization, not storing
   failures), and that leak checks still win.
6. Also from BUGS_3.7.md: "swings" read Cold while "playground" was #5 for
   "park". Likely the plural is not folded to "swing" before scoring. Check
   `warmthservice.ts` and `rankvocab.ts`.

### Open decision: iPhone solo (ASK JASON FIRST)

iPhone solo does not use Gemini today. `Hunch/Engine/QuestionService.swift`
runs the automatic answers first, then Apple's on-device model (Apple
Intelligence), and falls back to the automatic answers on phones without it.
The starter chips (`askStarter` in `GameViewModel.swift`) use the automatic
answers too. Ask Jason which way, with these options:

- Server Gemini plus saved answers (recommended): the same answers as web and
  races; fall back to the on-device model when offline. The privacy policy
  (`wick-web/public/marketing/privacy.html`) and the App Store privacy label
  then need a line saying questions are sent to the server.
- Apple on-device model only: drop the automatic answers, stay on-device.
  Phones without Apple Intelligence lose questions.
- Server first, iPhone later: fix web and races now, iPhone in 3.8.

## Other 3.7 items still open

- Jason builds iOS in Xcode; fix any errors he sends.
- App Store Connect: Jason must remove the three coin products (small,
  medium, large) so the listing stops showing "In-App Purchases".
- New App Store screenshots with the new Wick; "100% free, no ads" is now a
  real selling point.
- The share replay video still draws the old Wick on both platforms
  (`wick-web/src/game/replay/scene.ts` and `Hunch/Replay/ReplayScene.swift`).
  Port the new faces there so shared clips match the app.
- Is 3.6 approved yet? Ask; 3.7 ships after it either way.
