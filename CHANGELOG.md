# Changelog

Notable changes to Wick, newest first. The iOS version number is the App Store
version. The web game and server ship from `main` and follow the same feature
numbers.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased] (3.5)

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
