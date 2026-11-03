# Claude Code brief: Wick 3.8 motion director polish

Read this entire brief before changing code. This is an animation-polish pass, not a new feature system and not a visual redesign.

The repository already has a strong foundation:

- Cross-platform authored dance clips in `wick-web/src/game/wick.ts` and `Hunch/Theme/WickDance.swift`.
- A motion preview/export page in `wick-web/src/dance.ts`.
- Face transitions, score moods, solved choreography, personality reactions, music pulse, Reduced Motion, and unit tests.

Preserve those systems. Improve their animation language so Wick feels observant, weighted, expressive, and authored rather than continuously bounced by formulas.

## Product goal

Wick should appear to:

1. Watch the player.
2. Evaluate the submitted word.
3. React physically.
4. Recover into the new emotional state.

The emotional order is always **attention, anticipation, action, settle**. The player should be able to feel Wick thinking before the result text is consciously read.

## Character rules

- Wick is one flame head. Never add a torso, arms, legs, chest, hands, or anatomy.
- Motion must preserve the approved chunky flame silhouette and readable face.
- Wick has weight. The base is the anchor; the upper flame and tip carry secondary motion.
- Brows and pupils usually react before the main silhouette.
- The tip follows the main silhouette slightly late and settles last.
- Wick is masculine, dry, confident, and occasionally caught off guard.
- Avoid cute mascot hopping, rubber-hose motion, jelly wobble, emoji reactions, frantic spins, and constant particles.
- Purple is the default character color. The final solved character stays green.

## Motion architecture

Treat each frame as the composition of five channels. Keep the same conceptual channels on web and iOS even if their types differ.

1. **Base pose:** stable scale, rotation, and translation for the current mood.
2. **Idle life:** low-amplitude breath, gaze, blink, brow reset, and tip drift.
3. **Authored reaction:** a short stateful clip triggered by a guess or question.
4. **Music choreography:** beat-aligned dance, used only where music is active.
5. **Transition / solve override:** face swap or solved sequence with highest visual priority.

Priority from highest to lowest:

`solve > face transition > guess reaction > dance accent > idle life`

Lower channels may continue their clocks while visually suppressed, but their transforms must not suddenly reappear mid-cycle. When an override ends, blend to the current lower-priority pose over 120-180ms.

## Shared animation grammar

### Anticipation

- Large action: 90-140ms of preparation.
- Small action: 50-80ms.
- Compress in the opposite direction of travel.
- Eyes or brows lead by 30-60ms when readable.

### Action

- Fastest part of a reaction: 90-180ms.
- Use one clear directional idea, not simultaneous shake, bounce, spin, and particles.

### Settle

- First overshoot is small, approximately 8-16% of the main displacement.
- At most one visible corrective rebound.
- Tip may take another 60-100ms to finish settling.

### Interruptibility

- A new submitted guess may interrupt any idle, rare reaction, or dance accent immediately.
- Start the new reaction from the currently rendered pose, not from a hidden rest pose.
- Solve interrupts everything.
- No non-solve animation may block input.

## Idle life system

The idle should feel irregular but deterministic for a given session seed. Do not use unbounded random changes every frame.

### Continuous motion

- Breath period: 2.8-3.6s, with only 1.0-1.8% vertical scale change.
- Counter-scale width so the base does not look inflatable.
- Tip drift period: 3.4-5.2s, offset from breathing and limited to a subtle 2-4% lean.
- Root vertical travel: no more than 1.2% of Wick's size outside music screens.

### Attention events

Schedule one event every 3.5-7s when the player is not typing rapidly or submitting:

- **Input glance:** pupils move toward the input field for 450-700ms, then return.
- **Brow reset:** one brow lifts 2-4%, holds briefly, then eases down.
- **Slow judgment blink:** asymmetric close, 170-230ms total.
- **Tip listen:** tip leans slightly toward the interface while eyes stay on the player.

Do not play two attention events together. Do not trigger one during the first 800ms after a guess.

### Typing awareness

If the existing view can safely expose focus/typing state without invasive architecture:

- On input focus, Wick's gaze moves toward the field over 180ms.
- During typing, keep the body quiet and use only tiny pupil tracking.
- After 1.6s without input, Wick glances back toward the player.

If focus state is costly or platform-specific, omit this rather than coupling the renderer to text-field internals.

## Guess reaction clips

Every scored guess uses one primary clip. Color and face transitions remain driven by the existing score state.

### Grey / defeated: `deflate`

Duration: 620ms.

1. Eyes fall first by 40ms.
2. Root settles down 3%; silhouette widens 2% and shortens 4%.
3. Tip loses tension and leans away.
4. Hold the deadpan pose without bouncing back to cheerfulness.

No drool, sigh cloud, or exaggerated sadness.

### Blue / freezing: `cold-shoulder`

Duration: 520ms.

1. Quick inward compression of 3%.
2. One restrained left-right shiver, not continuous vibration.
3. Eyes remain half-lidded and unimpressed.
4. Tip gives one delayed twitch.

### Teal / cold: `inspect`

Duration: 680ms.

1. Wick leans forward 3% and sideways 2%.
2. Pupils move toward the guess/result area.
3. One brow lowers while the other remains skeptical.
4. Settle into a held suspicious pose for 250ms.

This must not look pleased, sleepy, or sexual.

### Yellow / warm: `interest`

Duration: 560ms.

1. Tip perks upright first.
2. Wick rises 2.5% with a narrow 2% stretch.
3. Pupils lock forward and brows become attentive.
4. One small settle downward.

### Orange / hot: `caught`

Duration: 650ms.

1. Eyes widen slightly before the body moves.
2. Wick recoils 3% and rotates 2 degrees away.
3. Mouth tightens; brows attempt to recover.
4. Wick returns only halfway toward neutral, retaining tension.

### Red / boiling: `hide-panic`

Duration: 760ms.

1. A 90ms freeze.
2. One sharp 3-frame shake with decreasing amplitude.
3. Tip snaps away, then over-corrects once.
4. Eyes slide sideways as the face returns to controlled fluster.

Replace any endless boiling jitter while the result first lands with this authored entrance. A much smaller ambient tremor may remain afterward.

### Green / solved

Keep the existing solved system and requirements in `CLAUDE_3.8_PERSONALITY_POLISH.md`. The motion polish must not change these decisions:

- Wick becomes green immediately.
- Shock reads first.
- One compression and rebound only.
- No spin.
- Final pose is green and impressed/sly.

## Face and color transition

All ordinary state changes use the same recognizable transition:

| Time | Action |
|---:|---|
| 0-70ms | Eyes begin closing; current pose anticipates by 1-2%. |
| 70-150ms | Eyes fully closed. Face geometry morphs and color begins traveling from the lower flame upward. |
| 150-240ms | New color and face finish behind closed lids. Silhouette reaches its smallest compression. |
| 240-360ms | Eyes reopen into the new emotion. Silhouette releases with a small overshoot. |
| 360-440ms | Tip catches up and settles. |

Do not use a uniform crossfade over the whole character. If an upward color wipe is too expensive in a renderer, approximate it with a bottom-to-top gradient mask or a fast two-stage body/face color blend. Keep Reduced Motion as a clean crossfade.

## Dance choreography

Keep the existing `groove`, `swagger`, and `hype` clip identifiers to avoid unnecessary API churn. Give each a different silhouette and emotional purpose instead of treating them as amplitude variants.

All phrases are eight beats at the music system's existing beat duration.

### `groove`: restrained confidence

Purpose: normal chill music and relaxed preview.

| Beat | Pose |
|---:|---|
| 1 | Settle left with a low shoulderless flame lean; eyes remain forward. |
| 2 | Return through center; tip trails right. |
| 3 | Settle right, slightly smaller than beat 1. |
| 4 | Center hold with one brow accent. |
| 5 | Deeper left lean and tiny upward float. |
| 6 | Center with a controlled squash. |
| 7 | Right lean with pupils glancing opposite the body. |
| 8 | Plant at center and prepare the loop. |

Rules: root never rises more than 5% of size; rotation stays within 5 degrees; no visible jump on every beat.

### `swagger`: Wick's signature dance

Purpose: the default live-race performance.

| Beat | Pose |
|---:|---|
| 1 | Strong left plant, 7-9 degree lean, eyes slide right. |
| 2 | Tall center pass; tip still points left. |
| 3 | Strong right plant; crooked smirk peaks. |
| 4 | Brief center hold, almost motionless. |
| 5 | Lower left compression, the phrase's largest anticipation. |
| 6 | Diagonal release through center. |
| 7 | Right hero pose with one raised brow. |
| 8 | Weighted landing and reset. |

Rules: the contrast between moving beats and holds creates swagger. Do not hop on all eight beats. Beats 4 and 8 must feel planted.

### `hype`: big drop, still controlled

Purpose: final race energy and the music drop.

Beats 1-4 build from the swagger phrase with increased travel, not faster jitter. Beats 5-7 form one connected move:

1. Beat 5 crouch/compress.
2. Beat 6 launch with up to 22% vertical travel.
3. Between 6 and 7, use one controlled 120-180 degree turn only if the face remains readable; otherwise use a strong arc without rotation.
4. Beat 7 landing with 10-12% squash and one recoil.
5. Beat 8 hero hold with the tip settling last.

Remove the existing full 360-degree drop spin. Wick is a character performing a move, not a loading symbol.

## Music-energy behavior

- Energy 0-0.45: `groove` vocabulary and small accents.
- Energy 0.45-0.82: `swagger` vocabulary and clearer plants.
- Energy 0.82-1.0: visible phrase-level anticipation leading into `hype`.
- Do not simply multiply every transform by energy. Crossfade between authored vocabularies or change a limited set of parameters.
- Background pulse supports Wick but must not make every beat flash.

## Rare personality micro-animations

Map the existing deterministic personality triggers to a physical clip:

- `repeat`: slow judgment blink, then one brow lift.
- `leap`: tip snap plus forward attention, no generic bounce.
- `near`: `hide-panic` at 70% amplitude.
- `regress`: eyes move first, then body turns away 2-3 degrees.
- `stall`: `deflate`, held briefly.
- `wild question`: face leads; use at most one tiny silhouette accent.

The existing cooldown and priority system remains authoritative. Do not add random rare reactions outside it.

## Sound and haptics

This pass should work without sound. If existing hooks make it cheap:

- Landings align with existing beat or result transients.
- Use haptics only for solved, music drop, or a major warmth leap.
- Never vibrate for idle or every dance beat.

Do not add new audio files for this pass.

## Reduced Motion

- No root translation, rotation, jumping, shaking, or continuous bob.
- Preserve blinks, gaze, brow changes, face morphs, color changes, and opacity/glow breathing.
- Dance becomes a subtle beat-timed luminance and eyebrow accent.
- Guess reactions use face, pupils, brows, tip shape, and a maximum 2% scale change.
- Solve follows the existing Reduced Motion specification.

## Performance

- Keep one animation clock per mounted Wick, as the current systems intend.
- Do not allocate paths, arrays, timers, or random generators every frame.
- Avoid layout reads/writes inside the web animation loop.
- Suspend animation when offscreen or backgrounded.
- Maintain 60fps on supported iPhones and ordinary laptop browsers.

## Motion Studio requirements

Upgrade the existing developer motion page only as needed to review the work. It should expose:

- Idle for every mood.
- Each guess-reaction clip.
- Face/color transition between any two states.
- All three dance phrases at low, medium, and high energy.
- Solved and Reduced Motion previews.
- Pause, restart, 0.25x/0.5x/1x playback, and frame stepping if these controls are not already present.

Do not turn the motion page into a general animation editor. It is a review surface.

## Cross-platform acceptance criteria

- Web and iOS use the same named clips, beat poses, durations, and priority rules within 50ms.
- Large actions visibly anticipate and settle.
- The tip trails the root and settles last.
- Groove, swagger, and hype remain identifiable with music muted.
- Swagger includes planted holds rather than bouncing every beat.
- Hype uses no full 360-degree spin.
- Each temperature has a distinct entrance reaction.
- A rapid second guess cleanly interrupts the first reaction without snapping to rest.
- Solved Wick stays green.
- Reduced Motion contains no translation, rotation, jumping, or shake.
- Animation never changes scoring, reaction selection, race timing, or input availability.
- Update pure motion tests on both platforms for key poses, priorities, interruption blending, tip delay, no-spin constraint, and Reduced Motion.

## Implementation order

1. Introduce/clarify shared motion channels and priority composition without changing visuals.
2. Replace continuous idle bounce with the quieter idle-life specification.
3. Add the six temperature entrance clips.
4. Refine face/color transitions.
5. Re-author groove and swagger with planted holds.
6. Replace the full-spin drop with the controlled hype phrase.
7. Map personality triggers to clips.
8. Finish Reduced Motion and Motion Studio review controls.
9. Run tests and compare web/iOS values side by side.

## Explicitly out of scope

- New character art
- Skeletal rigging or third-party animation runtimes
- Full-body Wick
- New music or sound assets
- User-created dances
- Unlockable cosmetics
- Network-generated behavior
- Changes to game rules, score thresholds, or reaction selection

