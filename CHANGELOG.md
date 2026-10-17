# Changelog

Notable changes to Wick, newest first. The iOS version number is the App Store
version. The web game and server ship from `main` and follow the same feature
numbers.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased] (3.6)

### Added

- **Tutorial level.** A brand-new player opens straight into a hands-on
  level instead of a How to play sheet. The secret word is one of ten simple
  animals, and every step waits for the player to do the thing: guess any
  word (the heat bar shows where it landed), guess a warmer one, ask Wick a
  yes or no question ("Is it alive?" types itself into the real field, the
  player presses send), use a free hint, then solve it. Wick coaches each
  step in one short line; the rest of the board is dimmed and the control to
  touch next pulses. Haptics, sounds and a big "Warmer!" pop on every step.
  Finding the animal early gets a "Lucky!" and a bonus animal so the lessons
  still happen. The solve step is a dead giveaway: it starts with "it's an
  animal", and every wrong guess unlocks a stronger clue (where it lives, its
  sound, then the letters one by one) until the word is spelled out.
  Skippable any time; replay it from How to play or Settings. Players from
  before 3.6 are not forced through it. The web game gets the same level in
  all six languages, in four steps (the web game has no hints, so there is
  no hint step). The tutorial never touches the
  daily, stats, streak, coins, achievements, round history, the weekly word
  stats or the race board.
- How to play is now a glance: a big "Play the tutorial" button, the heat
  bar, a real question with Wick's answer, and two one-line rules.
- Server: `tutorial_start`, `tutorial_done` and `tutorial_skip` (with the
  step it was skipped on) on the `/event` allowlist, to see where new players
  drop off.
- **Today's race board.** Everyone plays the same daily word, so every solver
  is now ranked against everyone else: fewest guesses wins, each hint counts
  as one more, ties go to the faster time. Shown on the solved card ("You're
  #3 of 41 today") and in Stats, on iOS and on the web, with flags for the
  language each player solved in. Nothing is posted on its own: the solved
  and give-up screens offer one big Submit button, and only the first
  finished round of the day can be submitted. Give-ups go at the bottom.
- Auto names like "Violet Otter" from a safe word list, with a New name
  button. Nothing is typed, so there is nothing to moderate.
- Server: `POST /board`, `POST /board/name`, `GET /board?n=&me=`. One entry
  per player per day (the first solve counts), impossible times rejected,
  yesterday's puzzle still accepted all of the next UTC day so offline solves count, the last
  week kept in `board.json` on the Render disk.
- **Everyone's week on the Stats page.** iOS Stats now shows "Top guesses this
  week" and "Most asked questions" across all players, below your own stats.
  Weekly window, resets Monday 00:00 UTC. The app caches the lists for 30
  minutes so opening Stats does not hit the server each time.
- Server: `POST /tally` (iOS solo reports a word or a typed question, with no
  id) and `GET /stats/weekly?lang=` (counts only). Web solo and live races are
  counted where the text already reaches the server. Counts are kept on the
  Render disk in `tally.json`.
- Spoiler and privacy rules: only guesses that read Cool or colder are
  counted, never the answer or a question that names it; a row shows once
  three different senders have sent it; questions with numbers, links,
  emails or crude words are dropped. Senders are told apart only by a salted
  hash held in memory for the week.
- iOS Settings: "Add my words to weekly stats", on by default. The privacy
  policy and privacy manifest describe it.
- Race alert reliability: the app registers for pushes again on every
  foreground, registrations are kept on a Render disk, and the TestFlight
  launch crash is fixed.
- Dance page: a whole-race section (5 minutes with the riser and kiai where
  the race puts them) and an option to export the video silent.


### Changed

- **Cleaner end of round (iOS).** The solved and gave-up cards now have one
  big button (the race board), a row of three share tiles (Result as the
  emoji grid, Map as the picture, Video as the replay), and two quiet buttons
  (See the map, Play a random word). The open "Race a friend" button is gone
  from the end cards on iOS and web; "Race them back" still shows after a
  round that came from a friend's race link.
- **Prettier map (iOS).** The Reveal map draws one glowing trail through
  each new closest guess into the word instead of a dashed line through
  every guess, the heat bands are soft tinted rings with their names off to
  the side, word labels never overlap, and the word sits on a solid disc.

## [3.5]

### Added

- **Reminder offer.** After the first daily solve, iOS asks once whether the
  player wants a reminder when the next word is ready. It uses the time set in
  Settings (9 AM unless changed).
- **Queue alert.** The server can push the maintainer's phone through ntfy when
  a real person starts waiting for a live race, with a louder alert when the
  queue is busy, so a first race can be against a human instead of the bot. Off
  unless `WICK_NTFY_TOPIC` is set.
- **Challenge line.** A solved daily replay's end card now reads "Can you beat
  14? Play free at guesswick.com", on iOS and on the web.
- **Race music.** Live races have their own soundtrack, made in GarageBand: a
  chill loop, then a two bar riser into an intense "kiai" loop that drops
  right around the last minute, on the beat. The screen moves with it: the
  background and Wick pulse on every beat, and heat up when kiai drops. It has its own Race music switch in
  Settings, on by default, on iOS and on the web.
- **Install on Android.** The web game can be installed as an app from Chrome.
  An Install button replaces the App Store link when Chrome offers it, and a
  small offline page shows when there is no connection.
- **Wick dances.** In live races Wick dances to the race music, locked to the
  beat: a hop on each beat, a step to alternating sides, a bigger move on beat
  1 of each bar, and a jump and spin when kiai drops. On iOS and on the web.
- **Web Wick comes alive.** The web mascot is now built once and moved from
  the clock like the iOS one: he bobs, leans, breathes, blinks at random,
  eases between moods, and squashes when poked. He no longer snaps back every
  time a live race updates. Boiling is a hard shake on both platforms.
- **Race alerts.** Players can turn on pushes in Settings for when someone is
  waiting for a live race, when the queue is busy, or when unusually many
  people are playing for that time of week. Delivered through Apple push; off
  on the server unless the `WICK_APNS_*` settings are set.
- A developer page (`wick-web/dance.html`) renders Wick dancing to the real
  race music and exports green screen video or a transparent PNG sequence for
  TikTok templates.

### Changed

- iOS daily reminders are now queued one day at a time for the next two weeks,
  so a day whose puzzle is already solved is skipped, and each one names the
  puzzle number.

## [3.4] - 2026-10-14

### Added

- **Solve Replay.** Turn a finished round into a short vertical video and save
  it to Photos or download it. Available on iOS and on the web, where it is
  saved as MP4 when the browser can encode it.
- Replays show each guessed word and each question asked. On the daily puzzle
  the answer and the closest guesses (ranks 2 to 11) stay hidden; practice
  replays show everything, including the answer.
- **Play in your language.** A round can be played and scored in Spanish,
  French, Italian or German, on iOS and on the web.
- **Cross-language races.** Two players in different languages can race the
  same concept, each scored in their own language.
- A Race word pool of 504 words in six languages, including playable
  Simplified Chinese.
- Web: Simplified Chinese menus and short Chinese meanings for players who are
  learning English.
- Web: short meanings next to each guess in Spanish, French, Italian and
  German.
- Web: a language hint in settings and dictionary overrides.

### Changed

- New app icon: Wick, the purple flame, with gold sparks, used everywhere.
- The web Wick now moves by mood, like the iOS app.
- Marketing pages use the app icon and the Wick violet accent.

## [3.3] - October 2026

The source code was published on GitHub under the Mozilla Public License 2.0
on 2026-10-08, ahead of this release.

### Added

- Quick Match uses shared start times: players count down to the same
  start slot.
- Three free hints a day.
- Anonymous play counts (puzzle started, solved or given up), described in
  [PRIVACY.md](PRIVACY.md).
- The website links to the source code.

### Changed

- The Race screen leads with live racing.
- The rating prompt appears earlier.

### Removed

- The Dare mode, so Race and the daily puzzle get the attention.
- Ready-made starter questions on the web board.

[Unreleased]: https://github.com/jasonepage/Wick/compare/v3.4...main
[3.4]: https://github.com/jasonepage/Wick/releases/tag/v3.4
[3.3]: https://apps.apple.com/app/id6777743483
