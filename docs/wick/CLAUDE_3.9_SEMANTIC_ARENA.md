# Wick 3.9 — Semantic Arena

## Product thesis

Wick is the competitive game of navigating meaning.

The player is not merely guessing a hidden word. They are searching semantic space, learning how words relate, and trying to reach the target with a cleaner route than an opponent. Version 3.9 must make that invisible strategy legible without turning Wick into a classroom or an AI chat wrapper.

Primary promise:

> Find the secret word. Master the map of meaning.

## Existing foundation to preserve

- The existing 3.2 semantic reveal map and its deterministic geometry.
- The 3.8 head-only Wick design, color language, reactions, Race Showdown, privacy posture, offline play, localization, sharing, and reduced-motion behavior.
- Purple is neutral/default. Green is solved and remains green after a successful solve.
- The secret word must never leak before the round ends, including via accessibility labels, analytics, logs, share cards, or network payloads not already authorized by the game.

## 3.9 scope

Build five connected additions on web and iOS:

1. **Strategic guess signals during play**
2. **A redesigned post-round Path Report**
3. **Deterministic route statistics**
4. **A spoiler-free Path Card**
5. **A two-player Path Comparison after races**

Do not add rankings, seasons, currencies, accounts, language courses, chat, or a new live-race protocol in this pass.

---

## 1. Strategic guess signals

Each accepted guess may show one small secondary signal beneath its existing warmth/rank result. This is guidance, not a definition and never a direct clue.

Allowed signal vocabulary:

- **Breakthrough** — the guess improved substantially over the player's previous best.
- **Warmer** — a modest new personal best.
- **Sideways** — semantically different from the previous guess but not closer to the target.
- **Same neighborhood** — close to the previous guess and similarly warm; the player is circling.
- **Backtrack** — meaningfully colder than the previous guess.
- **New direction** — far from the player's recent guesses; exploration without judging it as good or bad.

Never show the secret's category during play. Never claim a linguistic relationship the available deterministic data cannot support. Signals should be calculated from existing scores plus pairwise similarity between the player's own guesses. If that similarity is unavailable, gracefully limit signals to Breakthrough, Warmer, and Backtrack.

### Visual design

- One compact line, maximum two words where possible.
- No extra card around it.
- Use a small directional glyph plus text; do not rely on color alone.
- Muted by default. Breakthrough receives one restrained gold pulse.
- Show at most one signal per accepted guess.
- Wick may deliver a rare matching one-liner, but the interface signal must remain understandable with sound off.
- Respect Reduce Motion: replace pulse/motion with a static emphasis state.

### Behavioral thresholds

Centralize thresholds in one pure, testable classifier shared in behavior across platforms. Use conservative defaults and tune against fixtures; do not scatter magic numbers through views.

Suggested initial interpretation:

- Breakthrough: new best and increase >= 15 points.
- Warmer: new best and increase >= 4 points.
- Backtrack: decrease >= 12 points.
- Same neighborhood: pairwise similarity to prior guess >= 0.72 and absolute warmth change < 8.
- New direction: similarity to each of the last three guesses < 0.35.
- Sideways: default when direction changed but warmth is roughly flat.

Priority when multiple apply: Breakthrough > Warmer > Backtrack > Same neighborhood > New direction > Sideways.

---

## 2. Path Report

Rename/reframe the existing post-round semantic map as **Your Path**. Keep the existing radial meaning map as the hero, but turn the screen into a useful 15-second debrief.

### Reveal sequence

1. Wick locks into the solved-green state.
2. The secret word appears at the center.
3. The player's route draws from first guess to final guess in chronological order.
4. The pivotal move receives a gold halo.
5. Three stat tiles rise in below the map.
6. One short coaching sentence appears.

The whole sequence should take about 1.2 seconds and remain skippable. With Reduce Motion, show the completed composition immediately.

### Information hierarchy

1. Result: `Solved in 8`
2. Semantic map and chronological path
3. Three stats: **Efficiency**, **Best Jump**, **Exploration**
4. One coach line from Wick
5. Primary action: **Share Path**
6. Secondary actions: rematch/play again/back

### Stat definitions

All statistics must be deterministic, locally explainable, and stable for identical input.

#### Efficiency

A 0–100 route-quality score derived only from the player's warmth progression. It should reward reaching the target with fewer regressions and fewer redundant moves, not merely fewer guesses. Do not present it as an objective measure of intelligence.

Recommended model:

- Start from the total positive progress actually needed to move from the first scored guess to 100.
- Compare it with total traveled warmth distance, including regressions.
- Apply a small redundancy penalty for consecutive near-duplicate guesses.
- Clamp 0–100.
- Very short paths should not automatically receive 100 if they contain a large regression.

Expose a small info sheet explaining: `How directly your guesses moved toward the answer.`

#### Best Jump

The guess with the largest positive increase over the previous guess. Display the entered word and `+N° warmer` after the round only. If the first guess is the only scored guess, show `First try`.

#### Exploration

Count distinct semantic clusters visited using pairwise similarities among the player's own guesses, with a deterministic threshold. Display as `3 directions`, not a fake percentage. This is descriptive, not always better when higher.

### Coach lines

Choose one deterministic line from a small authored set. Examples:

- `Clean route. You committed when it got warm.`
- `That breakthrough changed the whole round.`
- `You explored widely, then closed fast.`
- `You circled one neighborhood for a while.`
- `Next time, pivot sooner after a backtrack.`

Do not generate these with a network model. Avoid insults, grading language, or claims about intelligence.

---

## 3. Path Card

Add a new spoiler-free share treatment based on the existing square card.

Required content:

- `WICK DAILY #NNNN` or practice/race label
- `SOLVED IN N`
- A simplified unlabeled route line with temperature-colored nodes
- Efficiency score
- Best-jump magnitude, but never the guessed word for a current daily puzzle
- Solved-green Wick head
- `guesswick.com`

Never include the answer or guess labels for the active daily puzzle. Provide text equivalents for accessibility and a non-image fallback. Preserve current share behavior if rendering fails.

---

## 4. Race Path Comparison

After a race result, add a compact comparison below the winner treatment. Do not interrupt or replace the existing 3.8 victory moment.

Display two horizontal miniature routes:

- Player name
- Guess count
- Efficiency
- Temperature trail ending in green only for a solve
- Gold marker on each player's best jump

Then show exactly one neutral comparison sentence:

- `You found the breakthrough first.`
- `Alex took the shorter route.`
- `Both paths converged at the end.`

Never shame the loser. Never expose an opponent's actual guess words—only their abstract trail and derived stats. If opponent route data is not available in the existing protocol, hide comparison cleanly rather than changing the live protocol recklessly. A local/current-player Path Report must still work.

---

## 5. Category reveal after completion

After the answer is visible, show one broad, curated category chip if `WordAttributes` already has a reliable category for that word: e.g. `ANIMAL`, `PLACE`, `OBJECT`, `ACTION`, `FEELING`, `NATURE`, `FOOD`, `ART & MUSIC`, `TIME`, or `EVENT`.

- Category is post-round only.
- Localize the label.
- Omit it when unknown rather than guessing.
- Do not expand or rewrite the word database merely to force 100% coverage.

---

## Platform parity

Implement equivalent behavior on iOS and web. Exact layout may adapt, but terminology, classification, stat formulas, spoiler rules, and race privacy must match.

Prefer pure engine modules with fixtures over calculations inside UI views. Add focused tests for:

- Signal priority and thresholds
- Efficiency edge cases
- Best jump
- Exploration clustering
- Same-input determinism
- Empty/one-guess/give-up rounds
- Daily share-card spoiler safety
- Unknown category omission
- Opponent word privacy
- Reduce Motion/static state

## Acceptance criteria

- A completed solo round visibly produces a coherent Path Report on iOS and web.
- Every stat can be explained in one sentence and reproduced from round data.
- The active daily answer and guesses never appear on the shared Path Card.
- During play, no category or direct semantic relationship to the answer is revealed.
- Race comparison never displays opponent guess words.
- Existing 3.8 Race Showdown and solved-green behavior remain intact.
- Existing tests continue to pass; new engine behavior has test coverage.
- Production web build passes.
- iOS project compiles in Xcode with no new warnings introduced by this feature.

## Implementation order

1. Pure route-analysis engine and tests on both platforms.
2. Solo Path Report on iOS.
3. Solo Path Report on web.
4. During-play strategic signals.
5. Path Card.
6. Race comparison only where protocol data already safely supports it.
7. Localization, accessibility, reduced motion, regression pass.

## Explicit non-goals

- No generative-AI dependency.
- No hidden personality profiling.
- No claims that embeddings are linguistically authoritative.
- No mid-game answer category.
- No opponent guess-word disclosure.
- No leaderboard or ranked scoring based on Efficiency yet.
- No redesign of Wick, navigation, home screen, or 3.8 race arena.
