# Bugs to fix in 3.7

## Daily #1421 ("park"), web, Oct 17 2026

Reported from a recorded round (video: wick-park-daily-storycut.mp4).

### The Keeper answered No to clear Yes questions

| Question | Wick said | Truth | Who answered |
|---|---|---|---|
| does it have grass and trees? | No | Yes | Gemini |
| can you walk a dog there? | No | Yes | Gemini |
| is it touchable? | No | Yes (and it already said "a place" = Yes) | Gemini |
| is it a place? | Yes | Yes | deterministic |
| is it man made? | Yes | Yes | deterministic |
| can it move on its own? | No | No | deterministic |

Checked against `wick-api/src/offlinekeeper.ts` (park is tagged `structure`):
the three wrong answers all fell through the deterministic engine to Gemini.
The right ones were answered by the deterministic engine.

Likely causes, in `wick-api/src/keeper.ts`:

1. **Thinking is switched off.** `thinkingBudget: 0` on the 2.5 models, added to
   stop reasoning leaking into replies. Without it, flash answers fast and
   literally. Fix idea: a small thinking budget (for example 512) and keep only
   the final text.
2. **Gemini only gets the word.** iOS passes the word's facts (category lines
   from WordAttributes); the server passes nothing. Fix idea: add the
   `categoryOf()` fact line ("It is a man-made place...") to the prompt.
3. **No memory of the round.** Gemini never sees Wick's earlier answers, so it
   can say "a place" then "not touchable". Fix idea: send the round's previous
   questions and verdicts (iOS already passes `history`).
4. **The prompt leans to No.** "Never default to Yes" plus the abstract-word
   rule. Fix idea: say "answer for the typical case" (a typical park has grass
   and trees, you can walk a dog there).
5. **"touchable" isn't a trigger** for the deterministic `physical` property
   (only "tangible", "can you touch"...). Add "touchable", "touch".

Add regression tests in `keeper.test.ts` with these exact questions for "park".

### Warmth ranking looks off

- "swings" read Cold while "playground" was #5 Boiling.
- "bench" only read Cool (picnic #26, garden #65).

To check: `/debug/warmth?secret=park&guess=swings,swing,playground,bench,picnic,garden`
(needs the debug token). Suspect the plural "swings" missing from the rank
vocabulary or not folded to "swing" before embedding.
