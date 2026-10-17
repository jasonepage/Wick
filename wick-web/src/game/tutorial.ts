// SPDX-License-Identifier: MPL-2.0
//
//  tutorial.ts: the rules of the tutorial level, with no browser in sight, so
//  they are unit tested in tests/tutorial.test.ts. The screen that draws it is
//  screenTutorial() in main.ts.
//
//  Mirrors Hunch/Game/Tutorial.swift and the Tutorial section of
//  GameViewModel.swift, with one difference: the web game has no hints, so the
//  web tutorial teaches four steps, not five.
//
//    1. guess   Guess any word. The heat shows up and is explained.
//    2. warmer  Guess a warmer word. "Warmer!" is celebrated.
//    3. ask     Ask Wick a yes or no question. Wick answers.
//    4. solve   Find the animal. Big celebration, then Today's puzzle and
//               the race board.
//
//  Every step waits for the player to DO the thing. The secret is one of ten
//  simple animals. The tutorial never touches the daily, stats, the race board
//  or anything else that is saved; only the "done" flag is.
//

import type { DailyWord } from "./daily.ts";

export type TutStep = "guess" | "warmer" | "ask" | "solve" | "done";
/** The steps the badges count (not "done"). */
export const TUT_STEPS: readonly TutStep[] = ["guess", "warmer", "ask", "solve"];

/** What just happened, so Wick can react before restating the goal. */
export type TutNote =
  | "none"
  | "notAWord"   // the guess was not a word the server knows
  | "colder"     // a guess that did not beat the best so far
  | "warmer"     // a guess that did (the step 2 payoff)
  | "movedOn"    // step 2 stopped waiting for "warmer"
  | "askInstead" // a guess while Wick wanted a question
  | "answered"   // Wick answered; the verdict is in `verdict`
  | "lucky";     // found the animal before step 4: a bonus animal took over

export interface TutState {
  step: TutStep;
  note: TutNote;
  /** Tries at this step that did not complete it. In the solve step they
   *  drive the clues: "it's an animal" after 3, then letters from 6. */
  misses: number;
  /** Wick's last verdict ("Yes", "No"...), for the "answered" note. */
  verdict: string;
}

/** Ten animals every 10-year-old knows. All are tier-1 rows of the shared word
 *  pool, so every play language has them. */
export const TUTORIAL_ANIMALS: readonly string[] = [
  "cat", "dog", "cow", "horse", "pig", "duck", "fish", "frog", "bear", "lion",
];

/** The solve step's clues, per animal: where it lives, then its sound or
 *  giveaway trait. Keys into i18n.ts. */
export const ANIMAL_CLUES: Readonly<Record<string, { group: "farm" | "pet" | "wild" | "water"; sound: string }>> = {
  cat: { group: "pet", sound: "tutSound.cat" },     dog: { group: "pet", sound: "tutSound.dog" },
  cow: { group: "farm", sound: "tutSound.cow" },    horse: { group: "farm", sound: "tutSound.horse" },
  pig: { group: "farm", sound: "tutSound.pig" },    duck: { group: "water", sound: "tutSound.duck" },
  fish: { group: "water", sound: "tutSound.fish" }, frog: { group: "water", sound: "tutSound.frog" },
  bear: { group: "wild", sound: "tutSound.bear" },  lion: { group: "wild", sound: "tutSound.lion" },
};
const GROUP_KEY = { farm: "tutGroupFarm", pet: "tutGroupPet", wild: "tutGroupWild", water: "tutGroupWater" } as const;

/** localStorage key set when the tutorial is finished or skipped. */
export const TUTORIAL_DONE_KEY = "wick.tutorial.done";

/** The ten animal rows out of the word pool. */
export function tutorialPool(pool: readonly DailyWord[]): DailyWord[] {
  return pool.filter((w) => TUTORIAL_ANIMALS.includes(w.en));
}

/** A random animal, never one whose English form is in `used` (unless every
 *  one has been used). */
export function pickAnimal(
  animals: readonly DailyWord[],
  used: ReadonlySet<string>,
  rand: () => number = Math.random,
): DailyWord {
  const fresh = animals.filter((w) => !used.has(w.en));
  const from = fresh.length > 0 ? fresh : animals;
  return from[Math.floor(rand() * from.length) % from.length]!;
}

export function freshState(): TutState {
  return { step: "guess", note: "none", misses: 0, verdict: "" };
}

/** What a step change looks like to the screen. */
export interface TutChange {
  state: TutState;
  /** A step was completed: play the level-up beat. */
  advanced: boolean;
  /** Play the big "Warmer!" pop. */
  cheer: boolean;
}

/** A guess was scored. `newBest` = closer than every guess before it (the
 *  very first scored guess counts as a new best). */
export function afterGuess(s: TutState, newBest: boolean): TutChange {
  switch (s.step) {
    case "guess":
      return { state: { ...s, step: "warmer", note: "none", misses: 0 }, advanced: true, cheer: false };
    case "warmer": {
      if (newBest) {
        return { state: { ...s, step: "ask", note: "warmer", misses: 0 }, advanced: true, cheer: true };
      }
      const misses = s.misses + 1;
      // Never a dead end: three misses and the lesson moves on.
      if (misses >= 3) {
        return { state: { ...s, step: "ask", note: "movedOn", misses: 0 }, advanced: true, cheer: false };
      }
      return { state: { ...s, note: "colder", misses }, advanced: false, cheer: false };
    }
    case "ask":
      return { state: { ...s, note: "askInstead" }, advanced: false, cheer: false };
    case "solve":
      return { state: { ...s, note: newBest ? "warmer" : "colder", misses: s.misses + 1 }, advanced: false, cheer: false };
    case "done":
      return { state: s, advanced: false, cheer: false };
  }
}

/** The server did not know the guess. */
export function afterNotAWord(s: TutState): TutState {
  return s.step === "done" ? s : { ...s, note: "notAWord" };
}

/** Wick answered a question. Only step 3 waits for one; later ones are play. */
export function afterAnswer(s: TutState, verdict: string): TutChange {
  if (s.step === "ask") {
    return { state: { ...s, step: "solve", note: "answered", misses: 0, verdict }, advanced: true, cheer: false };
  }
  if (s.step === "solve") {
    return { state: { ...s, note: "answered", verdict }, advanced: false, cheer: false };
  }
  return { state: s, advanced: false, cheer: false };
}

/** Found the animal before the solve step. A bonus animal carries on from the
 *  same step, so the lessons still happen. "Warmer" needs a first guess to
 *  beat, so step 2 starts over at step 1. */
export function afterLucky(s: TutState): TutState {
  return { ...s, step: s.step === "warmer" ? "guess" : s.step, note: "lucky", misses: 0 };
}

/** "F R _ _": the first `shown` letters, the rest as blanks. */
export function letterPattern(word: string, shown: number): string {
  return [...word.toLocaleUpperCase()].map((ch, i) => (i < shown ? ch : "_")).join(" ");
}

/** "F-R-O-G". */
export function spelledOut(word: string): string {
  return [...word.toLocaleUpperCase()].join("-");
}

/** Everything Wick's line needs from the outside world. */
export interface LineContext {
  t: (key: string, ...args: Array<string | number>) => string;
  /** The latest guess's heat word, already localized ("Freezing"...). */
  heat: string;
  /** A verdict token ("Yes") in the menu language. */
  verdictLabel: (v: string) => string;
  /** The secret word, for the letter clues. */
  secret: string;
  /** The animal's English form, to look up its clues. */
  animal: string;
}

/** The solve step is a dead giveaway on purpose: every wrong guess unlocks a
 *  stronger clue, until the word is spelled out.
 *    0 misses: it's an animal
 *    1: where it lives (farm, pet, wild, water)
 *    2: its sound or giveaway trait ("it hops and says ribbit")
 *    3+: the letters, one more per miss ("F R _ _"), then "It's F-R-O-G!" */
export function tutorialClues(s: TutState, c: LineContext): string[] {
  if (s.step !== "solve") return [];
  const { t } = c;
  const out = [t("tutItsAnAnimal")];
  const info = ANIMAL_CLUES[c.animal];
  if (!info) return out;
  if (s.misses >= 1) out.push(t(GROUP_KEY[info.group]));
  if (s.misses >= 2) out.push(t(info.sound));
  if (s.misses >= 3) {
    const shown = s.misses - 2;
    out.push(shown >= [...c.secret].length
      ? t("tutSpelled", spelledOut(c.secret))
      : t("tutLooksLike", letterPattern(c.secret, shown)));
  }
  return out;
}

/** What Wick says right now: a reaction, then the goal. Short on purpose. */
export function tutorialLine(s: TutState, c: LineContext): string {
  const { t } = c;
  switch (s.step) {
    case "guess":
      if (s.note === "notAWord") return t("tutNotAWord");
      if (s.note === "lucky") return `${t("tutLucky")} ${t("tutGuessAny")}`;
      return t("tutGuessAny");
    case "warmer":
      if (s.note === "notAWord") return t("tutNotAWord");
      if (s.note === "colder") return t("tutColder");
      return t("tutHeat", c.heat);
    case "ask":
      if (s.note === "warmer") return `${t("tutWarmer")} ${t("tutAsk")}`;
      if (s.note === "askInstead") return t("tutAskInstead");
      if (s.note === "notAWord") return `${t("tutNotAWord")} ${t("tutAsk")}`;
      if (s.note === "lucky") return `${t("tutLucky")} ${t("tutAsk")}`;
      return t("tutAsk");
    case "solve": {
      // Always ends on the newest clue, with a short reaction in front.
      const clue = tutorialClues(s, c).at(-1) ?? t("tutFindIt");
      if (s.note === "answered") return `${t("tutAnswered", c.verdictLabel(s.verdict))} ${clue}`;
      if (s.note === "notAWord") return `${t("tutNotAWord")} ${clue}`;
      return clue;
    }
    case "done":
      return t("tutDoneTitle");
  }
}

/** The step number for badges and the skip event (1 to 4; done counts as 5). */
export function stepNumber(step: TutStep): number {
  const i = TUT_STEPS.indexOf(step);
  return i >= 0 ? i + 1 : TUT_STEPS.length + 1;
}

/** Only a brand-new player is sent straight into the tutorial: never finished
 *  or skipped it, and never played a daily on this browser. Players from
 *  before 3.6 are not forced through it. */
export function shouldAutoStart(storageKeys: readonly string[], done: boolean): boolean {
  return !done && !storageKeys.some((k) => k.startsWith("wick.daily."));
}
