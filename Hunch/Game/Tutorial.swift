//
//  Tutorial.swift
//  Hunch
//
//  3.6: the hands-on tutorial level. A brand-new player learns Wick by doing
//  it, one gated step at a time, on the REAL game board (not a slideshow):
//
//    1. Guess any word          -> the heat reading appears and is explained
//    2. Guess a warmer word     -> "Warmer!" is celebrated
//    3. Ask Wick a yes/no question (the move nobody finds on their own)
//    4. Use a free hint
//    5. Solve it                -> big celebration, then Today's puzzle and
//                                  the race board
//
//  The secret is one of ten simple animals. The tutorial is a sandbox: it
//  never touches the daily, stats, streak, achievements, round history,
//  the weekly word tally, or the race board (see GameViewModel, `.tutorial`).
//
//  Types only. The step logic lives in GameViewModel (it needs the round's
//  private state); the coaching UI lives in Views/TutorialCoach.swift.
//

import Foundation

/// Where the player is in the tutorial. Each step is gated on actually doing
/// the thing, never on reading.
enum TutorialStep: Int, Comparable, CaseIterable {
    case firstGuess = 1
    case warmer
    case ask
    case hint
    case solve
    case done

    /// The five steps the progress dots count (not `.done`).
    static let playable: [TutorialStep] = [.firstGuess, .warmer, .ask, .hint, .solve]

    static func < (a: TutorialStep, b: TutorialStep) -> Bool { a.rawValue < b.rawValue }
}

/// What just happened, so Wick can react to it before restating the goal.
enum TutorialNote: Equatable {
    case none
    /// The guess wasn't a word the engine knows.
    case notAWord
    /// A guess that didn't beat the best so far.
    case colder
    /// A guess that beat the best so far (the step 2 payoff).
    case warmer
    /// Step 2 gave up waiting for "warmer" and moved on.
    case movedOn
    /// The player guessed while Wick wanted a question.
    case askInstead
    /// Wick answered the question with this canonical verdict ("Yes", "No"...).
    case answered(String)
    /// The player guessed while Wick wanted the hint tapped.
    case hintInstead
    /// A hint word just landed.
    case hintLanded
    /// No hint was needed (already in the top 20, or nothing closer left).
    case alreadyHot
    /// The animal was found before step 5, so a bonus animal took its place.
    case lucky
}

/// The tutorial's secret words: ten animals every 10-year-old knows, in every
/// language (they are all tier-1 rows of DailyWords, so each one is in every
/// language's dictionary and is tagged as an animal, which means "Is it
/// alive?" gets a sure Yes on every iPhone, with or without the on-device AI).
enum TutorialAnimals {
    static let english = ["cat", "dog", "cow", "horse", "pig", "duck", "fish", "frog", "bear", "lion"]

    /// The ten rows, looked up once. Falls back to cat and dog if the table
    /// ever loses a row, so the tutorial can always start.
    static let all: [DailyWord] = {
        let rows = english.compactMap { en in DailyWords.all.first { $0.en == en } }
        return rows.isEmpty
            ? [DailyWord(en: "cat", es: "gato", fr: "chat", it: "gatto", de: "katze", tier: 1),
               DailyWord(en: "dog", es: "perro", fr: "chien", it: "cane", de: "hund", tier: 1)]
            : rows
    }()

    /// Where an animal lives, for the second clue of the solve step.
    enum Group { case farm, pet, wild, water }

    /// The solve step's clues, per animal: where it lives, then the sound it
    /// makes (or its giveaway trait). Keys into Loc ("tutSound.cow").
    static let clues: [String: (group: Group, soundKey: String)] = [
        "cat": (.pet, "tutSound.cat"),     "dog": (.pet, "tutSound.dog"),
        "cow": (.farm, "tutSound.cow"),    "horse": (.farm, "tutSound.horse"),
        "pig": (.farm, "tutSound.pig"),    "duck": (.water, "tutSound.duck"),
        "fish": (.water, "tutSound.fish"), "frog": (.water, "tutSound.frog"),
        "bear": (.wild, "tutSound.bear"),  "lion": (.wild, "tutSound.lion"),
    ]

    /// A random animal, never one whose English form is in `excluding`.
    static func random(excluding: Set<String> = []) -> DailyWord {
        let pool = all.filter { !excluding.contains($0.en) }
        return pool.randomElement() ?? all.randomElement()!
    }
}

/// Persisted flags for the tutorial. Handset-local on purpose, like the old
/// "seen How to play" flag (see CloudSync).
enum TutorialFlags {
    static let doneKey = "hunch.tutorialDone"
    /// The pre-3.6 flag set the first time a round was entered.
    static let legacySeenHowToKey = "hunch.seenHowTo"

    static var done: Bool {
        get { UserDefaults.standard.bool(forKey: doneKey) }
        set { UserDefaults.standard.set(newValue, forKey: doneKey) }
    }

    /// True only for a brand-new player: never finished or skipped the
    /// tutorial, never entered a round before 3.6, and no round on record.
    /// Players from before 3.6 are not forced through it; they can replay it
    /// from How to play or Settings.
    static func shouldAutoStart(solves: Int) -> Bool {
        let d = UserDefaults.standard
        return !done
            && !d.bool(forKey: legacySeenHowToKey)
            && RoundHistory.records.isEmpty
            && solves == 0
    }
}

/// A big on-screen cheer the coach plays once per bump of `tutorialCheerID`.
enum TutorialCheer: Equatable {
    case warmer
    case lucky
    case solved
}
