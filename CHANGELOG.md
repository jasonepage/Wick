# Changelog

Notable changes to Wick, newest first. The iOS version number is the App Store
version. The web game and server ship from `main` and follow the same feature
numbers.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased] (iOS 3.4)

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

## 2026-10-08: Public source release (iOS 3.3)

The code was published under the Mozilla Public License 2.0.

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

[Unreleased]: https://github.com/jasonepage/Wick/commits/main
