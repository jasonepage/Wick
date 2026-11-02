# Claude Code brief: Wick 3.8 personality polish

Implement this brief on iOS and web. Keep both platforms visually and behaviorally aligned. Use existing renderers, animation primitives, sound routing, haptics, and share-card systems before adding anything new.

## Product goal

Make Wick feel like a character reacting to the player, not a temperature meter wearing a face. Version 3.8 should add three connected improvements:

1. A memorable solved moment.
2. A share card people want to post.
3. A small set of rare contextual reactions.

Do not add currency, unlocks, shops, dialogue trees, full-body art, or another game mode.

## Non-negotiable visual rules

- Wick is a flame head only. Do not add a wax body, human torso, shoulders, arms, or anatomy.
- The final solved Wick is **green**. Purple remains the brand color and default-host color.
- Wick's canonical identity is the current flame silhouette, masculine eyes, sleek asymmetrical brows, compact mouth, and dimensional cartoon rendering.
- Do not make Wick look like an emoji, child, balloon, alien, or human.
- No broad happy grin. Emotion comes from brows, lids, pupils, mouth shape, flame posture, and timing.
- Keep effects restrained. One strong reaction beats constant particles.

## 1. Solved sequence: "You got me"

Total duration: about 1.8 seconds. The answer must be readable within 250ms. The player may skip after the first 120ms.

| Time | Beat | Wick | Screen |
|---:|---|---|---|
| 0.00-0.12 | Hit | Freeze on the submitted guess. Eyes widen. Pupils lock forward. Brows jump upward. Flame tip snaps upright. | One tight green pulse from the winning tile. Success haptic. |
| 0.12-0.42 | Disbelief | Wick becomes solved green. One eye opens slightly wider than the other. Mouth becomes a compact open gasp. | Background dims slightly so the green reads clearly. No confetti yet. |
| 0.42-0.82 | Release | Flame compresses once, then rebounds to 1.08x. Do not spin. | One violet-to-green ring expands and fades. Three gold sparks maximum. Medium haptic on rebound. |
| 0.82-1.28 | Recovery | Brows lower. Eyes narrow into a reluctant impressed look. Mouth shifts into a tiny crooked smirk. Wick stays green. | Guess count and time appear as one group. |
| 1.28-1.80 | Button pose | One eyebrow lifts a few pixels. Hold the green final pose and continue normal blinking. | Share and next actions fade in together. |

Suggested line pool, choose one without delaying the result:

- `You actually got it.`
- `Fine. That was good.`
- `I knew you would. Eventually.`
- First guess only: `...on the first guess?`

Do not show a line every time if it makes the flow feel repetitive. Never change Wick back to purple during the solved screen.

### Reduced Motion

Crossfade Wick to green shocked, fade in one solved ring, then settle into the green impressed face. Total duration 700-900ms. No translation, rotation, shake, or falling particles.

## 2. Share card

The card should explain the game result at a glance, even to someone who has never played.

### Visual hierarchy

1. Small brand line: `WICK DAILY #<number>`
2. Main result: `<number> GUESSES`
3. Heat trail: 5-8 compact colored nodes showing the player's actual progress
4. Large solved-green Wick head with the final shocked/impressed expression
5. Footer: `Can you turn Wick green?` and `guesswick.com`

### Layout

- Square primary export.
- Dark midnight-violet background.
- Text and heat trail on the left; green Wick head on the right.
- Maintain an 8% safe margin.
- Use real game data. Do not invent a fake percentile or score.
- Keep the secret word hidden by default. If the existing product has an explicit spoiler/reveal choice, respect it.
- The heat trail ends in green. Do not end on purple.

### Accessibility

- Do not rely on color alone. Each heat node also changes size or carries a simple ring/shape state.
- All important text meets readable contrast against the background.
- The card remains understandable when reduced to a phone-message preview.

## 3. Rare contextual reactions

These are short visual punctuation, not dialogue scenes. Never interrupt typing, scoring, accessibility focus, or race timing.

| Trigger | Reaction | Optional line | Cooldown |
|---|---|---|---|
| Exact repeated guess | Half-lidded stare, one slow blink | `We did this one.` | Once per round |
| Very cold after a warm guess | Wick glances sideways; brows flatten | `Bold strategy.` | Once per round |
| Large positive similarity jump | Flame tip perks up; eyes sharpen | `Now we're moving.` | Once every 4 guesses |
| Near solve / highest heat band | Red flustered face; restrained sweat mark | `Careful.` | Once every 3 guesses |
| First-guess solve | Longer green shock hold | `...on the first guess?` | Always when earned |
| 15+ guesses without improvement | Grey deadpan for one beat, then current state | `Take a breath.` | Once per round |

### Selection rules

- At most one rare reaction per submitted guess.
- Prefer the most specific trigger: solve, first-guess solve, repeat, large jump, near solve, regression, long stall.
- A reaction must not occur more than once within three guesses unless it is the solve.
- Lines are optional and should appear less often than animations.
- Do not use random personality lines disconnected from game state.
- Do not mention embeddings, cosine similarity, or internal scoring.

## Analytics

Use the project's existing analytics conventions. Track only enough to evaluate the feature:

- solved sequence shown / skipped
- share card opened / shared
- rare reaction type shown

Do not add guess text or the secret word to analytics payloads.

## Acceptance criteria

- Web and iOS end every successful solve with green Wick.
- Answer is visible within 250ms.
- Share card renders with real round data and a green final node.
- Rare reactions never alter the similarity score or round result.
- Sound-off remains visually complete.
- Reduced Motion removes positional movement.
- VoiceOver / screen-reader announcements describe the result once, not every animation beat.
- Existing races, replay, daily streak, sharing, and result actions still fire once.
- Add or update tests for reaction priority, cooldowns, solved-green persistence, and share-card data mapping.

## Explicitly out of scope

- New Wick body art
- Generated dialogue or network calls for personality
- Voice acting
- Multiple unlockable victory animations
- Confetti storms or screen-filling particles
- Economy, coins, rewards, chests, or cosmetics

## Recommended implementation order

1. Lock solved-green persistence and the five-beat solved sequence.
2. Build the share card from existing result data.
3. Add a deterministic reaction selector with cooldown state.
4. Add the small line pool.
5. Verify Reduced Motion, sound-off, and accessibility.

