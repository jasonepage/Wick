# Claude Code brief: Wick 3.8 Race Showdown

Read this brief completely before editing code. Implement it on iOS and web. This is the concrete player-experience centerpiece for version 3.8.

## Product promise

A live race should feel like a head-to-head game show, not a solo puzzle with a small opponent label.

At every moment the player must understand:

1. Am I leading?
2. Is my opponent getting close?
3. How much time remains?

Do not reveal either player's guessed words or questions. Do not reveal the secret before the existing authoritative result. The server remains authoritative for time, scoring, solve state, and the winner.

## Existing foundation to preserve

- `Hunch/Live/MatchProtocol.swift` already exposes opponent progress only.
- `LiveDuelViewModel` / `LiveDuelView` own the iOS experience.
- The web live-race flow is in `wick-web/src/main.ts` around the existing live state and match rendering.
- Both clients already receive opponent best warmth and guess count.
- Quick Match already has a shared server start.
- Race music, energy, Wick dances, rematch, disconnect handling, cross-language results, and localization already exist.
- The motion implementation should follow `CLAUDE_3.8_MOTION_DIRECTOR.md`.

Build on these systems. Do not replace the protocol or scoring model unnecessarily.

## Scope

Implement exactly four connected experiences:

1. Three-second face-off.
2. Dual-Wick race HUD with an explicit lead state.
3. Final-minute and final-15-second escalation.
4. Winner/loser recap with instant rematch.

Do not add another race mode, leagues, rankings, accounts, chat, currency, or rewards.

## 1. Match-found face-off

Use the existing shared-start countdown. Do not add three seconds to the authoritative clock or let either client submit early.

### Layout

- Local Wick occupies the left seat.
- Opponent Wick occupies the right seat.
- Center copy: `FIRST TO TURN WICK GREEN WINS`.
- Countdown below: `3`, `2`, `1`, `GUESS`.
- Each seat has a short anonymous label.

### Anonymous labels

No accounts or identity are needed. Generate a stable label locally from information both clients already have or from a safe per-match seed supplied by the existing protocol. Never use device identity, network data, guess text, or personal data.

Use a small authored adjective/noun-style pool such as:

- `EMBER 42`
- `NIGHT WICK`
- `VIOLET SPARK`
- `COLD FLAME`

If generating the same label on both clients would require a protocol expansion, use `YOU` and `OPPONENT` for 3.8 instead. Do not delay the feature for names.

### Choreography

- Both Wicks start purple with serious faces.
- Their pupils glance toward each other.
- Wick tips lean inward slightly.
- On each countdown number, use a restrained planted pulse.
- On `GUESS`, both face forward and the input receives focus.
- Start music quietly when allowed by user settings.

### Accessibility

- Announce `Race found. Starts in three.` once.
- Do not announce every visual pulse.
- Reduced Motion uses opacity and face changes only.

## 2. Dual-Wick race HUD

The race screen must stop reading like a solo board with opponent metadata attached.

### Top arena

Create one compact two-seat arena above the input and guess history:

```text
YOU                         OPPONENT
[local Wick]               [opponent Wick]
ORANGE                      TEAL
8 guesses                   11 guesses

             YOU LEAD
              2:14
```

On narrow phones, retain two equal columns. Do not stack the opponent below the player because that destroys the duel relationship.

### Local seat

- Local Wick uses current/latest submitted warmth for color and face.
- Show guess count.
- Show a compact status derived from best warmth.

### Opponent seat

- Opponent Wick uses `opponent.bestWarmth` for its public color and status.
- Animate only when the public snapshot changes.
- Show opponent guess count.
- Never show their latest word, question, exact similarity, language-specific clue, or timing of individual keystrokes.

### Best-warmth status labels

Use the existing warmth thresholds, not new scoring rules. Map them to short localized labels:

- Lowest band: `SEARCHING`
- Cool/teal: `FOUND A TRAIL`
- Warm/yellow: `HEATING UP`
- Hot/orange: `VERY CLOSE`
- Highest non-solved/red: `DANGEROUSLY CLOSE`
- Solved: `SOLVED`

If localized copy becomes too wide, shorten while preserving meaning. Never expose the numeric score.

### Lead indicator

Compute lead from each player's **best warmth**, not latest guess.

- Local best greater by more than the existing equality tolerance: `YOU LEAD`.
- Opponent best greater: `THEY LEAD`.
- Equal within tolerance: `TIED`.

The tolerance must follow existing score rounding/comparison behavior. Do not invent a scoring advantage.

Lead transitions:

- Fade/slide the old label out over 100ms.
- Bring the new label in over 160ms.
- Give the newly leading Wick one authored attention accent.
- Do not cover the input or interrupt typing.
- VoiceOver announces a lead change at most once every five seconds.

### Information hierarchy

During play, keep only these items visually dominant:

1. Timer.
2. Lead state.
3. Two Wicks and their public temperature.
4. Guess input and latest result.

Move invite, leave, help, music, and other controls into compact secondary positions. Music mute must remain immediately available.

## 3. Momentum events

Momentum events are deterministic consequences of public match state. They are not random dialogue.

### Events

- Local takes lead: `YOU'RE HOTTER`
- Opponent takes lead: `THEY'RE CLOSING IN`
- Lead becomes tied: `DEAD HEAT`
- Both reach the highest non-solved heat band: `SUDDEN HEAT`
- Final 15 seconds begins: `15 SECONDS`

### Presentation

- Display in the center between seats or immediately below the timer.
- Duration: 650-900ms.
- Never block input or move the guess field.
- At most one announcement every two seconds.
- Winner/solve state has absolute priority.
- Do not use toast infrastructure if it obscures unrelated errors.

### Privacy

Derive events only from fields already safe to show: best warmth, guess count, solve/result state, and authoritative remaining time.

## 4. Race escalation

Preserve the current authoritative race duration. Do not change it to 90 seconds as part of this UI project.

Use remaining time to move through four presentation phases:

### Opening

- From race start until the existing final-minute threshold.
- Calm violet arena.
- `groove` motion vocabulary.
- Timer is readable but not dominant.

### Final minute

- Begins at the existing music riser / final-minute transition.
- Arena contrast increases modestly.
- Lead label and opponent status become slightly brighter.
- Wick shifts to `swagger` vocabulary.
- Announce `FINAL MINUTE` once.

### Final 15 seconds

- Timer grows approximately 15-20% and becomes the strongest text.
- Use `hype` choreography without the removed full spin.
- Add one restrained pulse per whole second to the timer or arena, not the whole screen.
- Announce `15 SECONDS` once.
- From 5 to 1, show large numerals near the timer. Keep the input usable.
- No screen shake or rapid full-screen flashing.

### Expired

- Freeze new submission immediately according to existing authoritative behavior.
- Do not locally guess the winner.
- Hold both Wicks until the result frame arrives.

## 5. Win and loss

### Local win

- Local side floods solved green.
- Local Wick runs the existing solved sequence and stays green.
- Opponent freezes in their last public color.
- Primary copy: `YOU TURNED WICK GREEN`.
- Reveal authoritative word and result only when existing result data allows it.

### Local loss

- Opponent Wick turns green and performs a shortened public solve accent.
- Local Wick gives one annoyed side-eye, not a sad collapse.
- Primary copy: `<OPPONENT> GOT THERE FIRST`, or `THEY GOT THERE FIRST` when labels are unavailable.

### Draw / timeout / disconnect

Retain existing authoritative result categories and copy. Give each a clear distinct visual state, but do not invent a winner.

- Draw: both seats receive equal emphasis.
- Neither solved: both remain non-green.
- Opponent left: retain the current recovery/fallback behavior.
- Connection loss: clearly separate network failure from a competitive loss.

## 6. Post-race recap

The recap should tell the story of the match using public-safe data.

### Required summary

- Result headline.
- Secret word when existing rules allow it.
- Finish time or timeout.
- Both guess counts.
- Each player's highest public warmth band.
- Number of lead changes.
- Primary button: `REMATCH` when available, otherwise `RACE SOMEONE NEW`.
- Secondary action: share result.

### Heat trails

If each client already receives enough public snapshots, record a small local timeline during the match:

```text
YOU       BLUE → TEAL → YELLOW → RED → GREEN
OPPONENT  BLUE → BLUE → TEAL → ORANGE
```

Rules:

- Store band transitions, not exact scores.
- Collapse repeated adjacent bands.
- Cap each trail at eight nodes using the existing share-card compression strategy if possible.
- This history is ephemeral and per-match.
- Do not expand the server protocol solely to provide historical opponent data for 3.8. If the live client cannot observe enough transitions, omit the opponent trail and keep the summary values.

### Rematch

- Rematch is the visual primary action.
- One tap uses the existing rematch flow.
- Preserve protection against duplicate rematch requests.
- When both accept, return to the face-off rather than abruptly replacing the recap.

## 7. Responsive layouts

### iPhone portrait

- Two equal Wick columns remain visible.
- Wicks may scale down, but faces must remain legible.
- Guess history scrolls below the fixed/compact arena.
- Input remains reachable above the keyboard.

### iPad / desktop

- Arena can become wider with larger Wicks.
- Do not spread critical information across the full screen width.
- Constrain the competitive area so eye travel remains short.

### Small web viewport

- Never require horizontal scrolling.
- Keep the timer, lead state, both colors, and input visible without opening a panel.

## 8. Localization

Add every new user-facing string to all currently supported languages. Follow current localization architecture and placeholder conventions.

Required English keys/concepts include:

- `FIRST TO TURN WICK GREEN WINS`
- `YOU LEAD`
- `THEY LEAD`
- `TIED`
- `SEARCHING`
- `FOUND A TRAIL`
- `HEATING UP`
- `VERY CLOSE`
- `DANGEROUSLY CLOSE`
- `YOU'RE HOTTER`
- `THEY'RE CLOSING IN`
- `DEAD HEAT`
- `SUDDEN HEAT`
- `FINAL MINUTE`
- `15 SECONDS`
- `YOU TURNED WICK GREEN`
- `THEY GOT THERE FIRST`
- `RACE SOMEONE NEW`

Keep strings compact. Do not use emoji as interface icons.

## 9. Analytics

Use existing analytics conventions and collect only product events, never guesses, questions, secret words, labels derived from identity, or exact similarity.

- face-off shown
- race started
- lead changed, with new state only
- final minute reached
- final 15 seconds reached
- result category
- rematch requested / accepted

Do not add analytics if doing so creates new server scope for 3.8. UI correctness is more important.

## 10. Testing

Add pure tests where possible.

### Required behavior tests

- Lead uses best warmth rather than latest warmth.
- Equal scores produce `TIED` using current score tolerance.
- Lead announcements obey cooldown and do not beat solve/result priority.
- Opponent UI never receives or renders guessed words/questions.
- Final-minute and 15-second phases switch from authoritative remaining time.
- Timeout does not locally declare a winner.
- Solved local Wick stays green.
- Loss makes only opponent Wick green.
- Heat trails collapse adjacent repeated bands and cap at eight nodes.
- Rematch cannot be submitted twice.
- Reduced Motion has no root translation, rotation, shake, or jump.
- All localization tables contain the new keys.

### Manual acceptance scenarios

Test on both web and iPhone:

1. Human quick match.
2. Friend-code match.
3. Bot/fallback match if still supported.
4. Cross-language match.
5. Local win.
6. Local loss.
7. Draw/timeout.
8. Opponent disconnect.
9. Background and resume.
10. Music muted.
11. Reduced Motion.
12. VoiceOver / screen reader.
13. Large text.
14. Rapid repeated submissions / delayed network snapshots.

## Acceptance criteria

- The race visually reads as two competitors within one second.
- The player can identify leader, opponent danger, and remaining time without inspecting guess history.
- No opponent word, question, or exact score is exposed.
- Both clients honor the same authoritative start and end.
- Input remains usable during every announcement and countdown phase where submissions are allowed.
- The final 15 seconds feel more intense without screen shake or inaccessible flashing.
- Win, loss, timeout, and connection failure cannot be confused.
- Rematch is available in one tap when supported.
- Web and iOS use the same state mapping, strings, and timing within 100ms.
- Existing score, protocol, matchmaking, and result behavior remain unchanged unless a minimal protocol addition is strictly required.

## Recommended implementation order

1. Extract pure public race-presentation state: bands, lead, phase, announcements.
2. Add unit tests for that state.
3. Build the dual-seat arena on web and iOS.
4. Wire face-off to the existing shared start.
5. Add momentum events and phase escalation.
6. Build the recap from authoritative result plus ephemeral public history.
7. Add localization and accessibility.
8. Verify every manual scenario.

## Explicitly out of scope

- Changing race length
- Changing similarity scoring or warmth thresholds
- Revealing exact scores
- Revealing opponent guesses or questions
- Chat, reactions sent between users, or user names
- Accounts, profiles, rankings, seasons, or leagues
- Spectator mode
- New server persistence
- Currency, prizes, rewards, or unlocks
- New music assets
- Full-body Wick

