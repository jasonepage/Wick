//
//  Loc.swift
//  Hunch
//
//  In-app UI strings, keyed by the round's GameLanguage. We localize manually
//  (rather than via the system bundle) because the language is an in-app choice
//  that must override the device language. Access via `game.loc` from any view.
//
//  1.8: table-based. Every string lives in a per-language dictionary; the
//  accessors below are a typed façade over the tables. Adding a language means
//  adding ONE dictionary — any key it's missing falls back to English, so a
//  partially-translated language degrades gracefully instead of breaking.
//  Format placeholders: %@ for strings, %d for integers.
//

import Foundation

struct Loc {
    let lang: GameLanguage

    // MARK: - Lookup

    /// The raw string for `key` in this language, falling back to English.
    private func s(_ key: String) -> String {
        Loc.tables[lang.rawValue]?[key] ?? Loc.en[key] ?? key
    }

    /// The formatted string for `key` with `args` interpolated.
    private func f(_ key: String, _ args: CVarArg...) -> String {
        String(format: s(key), arguments: args)
    }

    // MARK: - Header
    func dailyTitle(_ n: Int) -> String { f("dailyTitle", n) }
    var practice: String { s("practice") }

    // MARK: - Archive
    var archive: String { s("archive") }
    var archiveEmpty: String { s("archiveEmpty") }
    var archiveSolvedToast: String { s("archiveSolvedToast") }
    var todaysPuzzle: String { s("todaysPuzzle") }
    func tier(_ n: Int) -> String { f("tier", n) }

    // MARK: - Home / menu
    var home: String { s("home") }
    var pastPuzzles: String { s("pastPuzzles") }
    var chooseDifficulty: String { s("chooseDifficulty") }
    var homeGuessWord: String { s("homeGuessWord") }
    var homeReplayAnyDay: String { s("homeReplayAnyDay") }
    var homePlayAnytime: String { s("homePlayAnytime") }
    var homeDressUpWick: String { s("homeDressUpWick") }

    // MARK: - Duels
    var duel: String { s("duel") }
    var soundHapticsTitle: String { s("soundHapticsTitle") }
    var hapticsToggle: String { s("hapticsToggle") }
    var soundToggle: String { s("soundToggle") }
    var duelSolvedToast: String { s("duelSolvedToast") }
    var duelCreate: String { s("duelCreate") }
    var duelRace: String { s("duelRace") }
    var duelRaceBlurb: String { s("duelRaceBlurb") }
    var duelPlayNow: String { s("duelPlayNow") }
    var duelYourCode: String { s("duelYourCode") }
    var duelShareCode: String { s("duelShareCode") }
    var duelPaste: String { s("duelPaste") }
    var duelJoin: String { s("duelJoin") }
    var duelJoinPlaceholder: String { s("duelJoinPlaceholder") }
    var duelGo: String { s("duelGo") }
    var duelInvalid: String { s("duelInvalid") }
    var duelChooseWord: String { s("duelChooseWord") }
    var duelHeadToHead: String { s("duelHeadToHead") }
    var duelWin: String { s("duelWin") }
    var duelLose: String { s("duelLose") }
    var duelTie: String { s("duelTie") }
    var duelYou: String { s("duelYou") }
    var duelThem: String { s("duelThem") }
    var duelGaveUp: String { s("duelGaveUp") }
    var duelNeedYours: String { s("duelNeedYours") }
    var duelCopied: String { s("duelCopied") }
    var duelCopy: String { s("duelCopy") }
    var duelResultShare: String { s("duelResultShare") }
    func duelResultMsg(_ code: String) -> String { f("duelResultMsg", code) }
    func duelYouChose(_ w: String) -> String { f("duelYouChose", w) }
    var duelShareMsg: String { s("duelShareMsg") }
    func duelSolvedIn(_ n: Int) -> String { f("duelSolvedIn", n) }

    // MARK: - Live multiplayer (3.0/3.1) — Race and invite links (Dare retired 3.3)
    // NOTE: ES/FR/IT/DE for this section were drafted for 3.1; worth a fluent skim
    // before an App Store build. English is the source of truth; any missing key
    // falls back to English automatically.
    var liveJoin: String { s("liveJoin") }
    var liveCancel: String { s("liveCancel") }
    var liveDone: String { s("liveDone") }
    var liveClose: String { s("liveClose") }
    var liveLeave: String { s("liveLeave") }
    var liveConnectionLost: String { s("liveConnectionLost") }
    var liveTheWordWas: String { s("liveTheWordWas") }
    var liveYourRound: String { s("liveYourRound") }
    var liveInviteFriend: String { s("liveInviteFriend") }
    var liveKeepGoing: String { s("liveKeepGoing") }
    var liveScoring: String { s("liveScoring") }
    var liveYouGotItLower: String { s("liveYouGotItLower") }
    var liveSolvedExcl: String { s("liveSolvedExcl") }
    var liveRace: String { s("liveRace") }
    var liveRaceBlurb: String { s("liveRaceBlurb") }
    var liveQuickMatch: String { s("liveQuickMatch") }
    var liveHaveACode: String { s("liveHaveACode") }
    var liveEnterIt: String { s("liveEnterIt") }
    var liveInviteHintRace: String { s("liveInviteHintRace") }
    var liveFindingOpponent: String { s("liveFindingOpponent") }
    var liveWaitingForFriend: String { s("liveWaitingForFriend") }
    var livePracticeFlameSteps: String { s("livePracticeFlameSteps") }
    var liveNextRaceIn: String { s("liveNextRaceIn") }
    var liveShareInviteLink: String { s("liveShareInviteLink") }
    var liveShareTapToJoin: String { s("liveShareTapToJoin") }
    var liveTheyJoinByLink: String { s("liveTheyJoinByLink") }
    var liveLiveRace: String { s("liveLiveRace") }
    var livePlayAgain: String { s("livePlayAgain") }
    var liveTryAgain: String { s("liveTryAgain") }
    var liveGuessOrAsk: String { s("liveGuessOrAsk") }
    var liveGuessOrAskHint: String { s("liveGuessOrAskHint") }
    func liveWelcome(_ keeper: String) -> String { f("liveWelcome", keeper) }
    var liveLiveOpponent: String { s("liveLiveOpponent") }
    var livePracticeFlame: String { s("livePracticeFlame") }
    var liveGhost: String { s("liveGhost") }
    var liveOpponent: String { s("liveOpponent") }
    var liveReconnecting: String { s("liveReconnecting") }
    func liveGuessesCount(_ n: Int) -> String { f("liveGuessesCount", n) }
    var liveGoodStart: String { s("liveGoodStart") }
    var liveClosestYet: String { s("liveClosestYet") }
    var liveFurther: String { s("liveFurther") }
    var liveResult: String { s("liveResult") }
    var liveYouWin: String { s("liveYouWin") }
    var liveYouLost: String { s("liveYouLost") }
    var liveDraw: String { s("liveDraw") }
    var liveFirstToWord: String { s("liveFirstToWord") }
    var liveOppFirst: String { s("liveOppFirst") }
    var liveTimeUpWarmest: String { s("liveTimeUpWarmest") }
    var liveOppLeft: String { s("liveOppLeft") }
    var liveYouLeft: String { s("liveYouLeft") }
    var liveBothDropped: String { s("liveBothDropped") }
    var liveOppLeftHangTight: String { s("liveOppLeftHangTight") }
    var liveNotAWord: String { s("liveNotAWord") }
    var liveInviteExpired: String { s("liveInviteExpired") }
    var liveShareMsgRace: String { s("liveShareMsgRace") }
    var liveScanCaption: String { s("liveScanCaption") }
    var liveRematch: String { s("liveRematch") }

    // MARK: - Wardrobe
    var wardrobe: String { s("wardrobe") }
    var wardrobeBlurb: String { s("wardrobeBlurb") }
    var equip: String { s("equip") }
    var equipped: String { s("equipped") }
    var take_off: String { s("take_off") }
    var buy: String { s("buy") }
    var owned: String { s("owned") }
    var notEnoughCoins: String { s("notEnoughCoins") }
    func slotName(_ slot: AccessorySlot) -> String { s("slot_" + slot.rawValue) }
    func accessoryName(_ key: String) -> String { s(key) }

    // MARK: - Welcome / hero
    func welcome(_ keeper: String) -> String { f("welcome", keeper) }
    var notInVocabulary: String { s("notInVocabulary") }
    var keepGoing: String { s("keepGoing") }

    // MARK: - Trajectory
    // Temperature words (Cool/Warm/Hot) describe how close a guess is; these
    // movement labels use plain "closer / further" language so the two never
    // seem to contradict each other (e.g. a "Cool" guess can still be "Closest yet").
    var firstGuess: String { s("firstGuess") }
    /// Localized heat-band word for a canonical HunchTheme token ("Boiling",
    /// "Hot", …). Unknown tokens (e.g. "#14") pass through unchanged.
    func heat(_ token: String) -> String {
        let key = "heat." + token
        return Loc.tables[lang.rawValue]?[key] ?? Loc.en[key] ?? token
    }
    // Wick's round-aware nudges
    var nudgeSoClose: String { s("nudgeSoClose") }
    var nudgeCircling: String { s("nudgeCircling") }
    var nudgeStuck: String { s("nudgeStuck") }
    /// First-run coaching — shown for a player's first two rounds only, aimed at
    /// the "why is my sensible word Freezing?" misconception.
    var coachNotAWord: String { s("coachNotAWord") }
    var coachFirstCold: String { s("coachFirstCold") }
    var coachFirstWarm: String { s("coachFirstWarm") }
    var coachTriangulate: String { s("coachTriangulate") }
    func warmestUp(_ spots: Int) -> String { f("warmestUp", spots) }
    var warmest: String { s("warmest") }
    var colder: String { s("colder") }

    // MARK: - Input
    var guessPlaceholder: String { s("guessPlaceholder") }
    var askKeeper: String { s("askKeeper") }
    var hint: String { s("hint") }
    /// Combined guess/ask field: a bare word guesses, a phrase or "?" asks Wick.
    var guessOrAskPlaceholder: String { s("guessOrAskPlaceholder") }
    var guessOrAskHint: String { s("guessOrAskHint") }
    var roundLog: String { s("roundLog") }
    var needIdeas: String { s("needIdeas") }
    /// VoiceOver-only strings. Everything else the screen reader speaks is
    /// composed from copy that already exists (the word, the heat band, the
    /// rank), so only the controls that show no text at all need their own key.
    var a11ySend: String { s("a11ySend") }
    var a11yShop: String { s("a11yShop") }
    var a11yAskThis: String { s("a11yAskThis") }
    /// Opening-board legend teaching the round's two verbs.
    var waysTitle: String { s("waysTitle") }
    var wayGuessTitle: String { s("wayGuessTitle") }
    var wayGuessBody: String { s("wayGuessBody") }
    var wayAskTitle: String { s("wayAskTitle") }
    var wayAskBody: String { s("wayAskBody") }
    /// Wick's adaptive offer to answer a question, keyed by why it fired.
    var offerStuck: String { s("offerStuck") }
    var offerCold: String { s("offerCold") }
    var offerRoutine: String { s("offerRoutine") }
    var offerAskElse: String { s("offerAskElse") }
    var offerNotNow: String { s("offerNotNow") }
    /// Feed-sort toggle labels: chronological vs. hottest-first.
    var sortRecent: String { s("sortRecent") }
    var sortClosest: String { s("sortClosest") }

    // MARK: - Learn mode
    var learnTitle: String { s("learnTitle") }
    /// "Learn Spanish" — `name` is the learn language's name in the UI language.
    func learnToggle(_ name: String) -> String { f("learnToggle", name) }
    /// "Shows each guess translated to Spanish (apple → manzana)…" — pass the
    /// learn language's name plus a live example pair (play word → learn word).
    func learnBlurb(_ name: String, _ from: String, _ to: String) -> String {
        f("learnBlurb", name, from, to)
    }

    // MARK: - Solved / revealed
    var solvedTitle: String { s("solvedTitle") }
    func solvedIn(_ word: String, _ n: Int) -> String {
        f(n == 1 ? "solvedIn.one" : "solvedIn.other", word, n)
    }
    func streakDays(_ n: Int) -> String { f("streakDays", n) }
    var shareResult: String { s("shareResult") }
    // Share-card copy
    func shareSolvedIn(_ n: Int) -> String { f("shareSolvedIn", n) }
    func shareQuestions(_ n: Int) -> String {
        f(n == 1 ? "shareQuestions.one" : "shareQuestions.other", n)
    }
    func shareHints(_ n: Int) -> String {
        f(n == 1 ? "shareHints.one" : "shareHints.other", n)
    }
    var shareTagline: String { s("shareTagline") }
    var playRandom: String { s("playRandom") }
    var easy: String { s("easy") }
    var medium: String { s("medium") }
    var hard: String { s("hard") }
    var theWordWas: String { s("theWordWas") }

    // MARK: - Give up
    var giveUpTitle: String { s("giveUpTitle") }
    var giveUp: String { s("giveUp") }
    var keepTrying: String { s("keepTrying") }
    var giveUpMessage: String { s("giveUpMessage") }

    // MARK: - Guess list
    func guessesCount(_ n: Int) -> String { f("guessesCount", n) }

    // MARK: - Ask the Keeper
    var askTitle: String { s("askTitle") }
    var done: String { s("done") }
    var askTab: String { s("askTab") }
    var guessTab: String { s("guessTab") }
    var suggestedQuestions: String { s("suggestedQuestions") }
    func dreamingClue(_ keeper: String) -> String { f("dreamingClue", keeper) }
    var askIntro: String { s("askIntro") }
    var keeperNoRespond: String { s("keeperNoRespond") }
    var retry: String { s("retry") }
    var askPlaceholder: String { s("askPlaceholder") }
    var notAKnownWord: String { s("notAKnownWord") }
    var offlineBanner: String { s("offlineBanner") }
    var offlineFootnote: String { s("offlineFootnote") }
    var questionsFree: String { s("questionsFree") }
    func freeQuestionsLeft(_ n: Int) -> String {
        f(n == 1 ? "freeQuestionsLeft.one" : "freeQuestionsLeft.other", n)
    }
    func questionCost(_ cost: Int, coins: Int) -> String { f("questionCost", cost, coins) }
    var outOfCoins: String { s("outOfCoins") }

    // MARK: - Menu / Settings
    var howToPlay: String { s("howToPlay") }
    var settings: String { s("settings") }
    var language: String { s("language") }
    var languageFooter: String { s("languageFooter") }

    // MARK: - Stats
    var yourStats: String { s("yourStats") }
    var currentStreak: String { s("currentStreak") }
    var bestStreak: String { s("bestStreak") }
    var wordsSolved: String { s("wordsSolved") }
    var avgGuesses: String { s("avgGuesses") }
    var fewestGuesses: String { s("fewestGuesses") }
    var coins: String { s("coins") }
    var achievements: String { s("achievements") }
    var leaderboards: String { s("leaderboards") }
    var dailyReminder: String { s("dailyReminder") }
    var time: String { s("time") }
    var reminderBlurb: String { s("reminderBlurb") }
    /// Notification copy. Written in the player's IN-APP language (see
    /// `HunchNotifications`), never the device language.
    var notifDailyTitle: String { s("notifDailyTitle") }
    var notifDailyBody: String { s("notifDailyBody") }
    var notifStreakTitle: String { s("notifStreakTitle") }
    /// "6 days and counting…" — %d is the streak about to be lost.
    func notifStreakBody(_ days: Int) -> String { f("notifStreakBody", days) }

    // MARK: - Toasts
    func dailyBonus(_ n: Int) -> String { f("dailyBonus", n) }
    func countsAsAlready(_ typed: String, _ word: String) -> String { f("countsAsAlready", typed, word) }
    func alreadyGuessed(_ word: String) -> String { f("alreadyGuessed", word) }
    func normalizedTo(_ typed: String, _ word: String) -> String { f("normalizedTo", typed, word) }
    func didYouMean(_ typed: String, _ suggestion: String) -> String { f("didYouMean", typed, suggestion) }
    func notInVocabToast(_ typed: String) -> String { f("notInVocabToast", typed) }
    func solvedBadge(_ reward: Int, _ badge: String) -> String { f("solvedBadge", reward, badge) }
    func solvedCoins(_ reward: Int) -> String { f("solvedCoins", reward) }
    func theWordWasToast(_ word: String) -> String { f("theWordWasToast", word) }
    var hintWarmingUp: String { s("hintWarmingUp") }
    func hintsCost(_ cost: Int) -> String { f("hintsCost", cost) }
    func hintFreeLeft(_ n: Int) -> String { f("hintFreeLeft", n) }
    func hintCoinPrice(_ cost: Int) -> String { f("hintCoinPrice", cost) }
    func topTakeIt(_ n: Int) -> String { f("topTakeIt", n) }
    var noCloserHint: String { s("noCloserHint") }
    func hintLands(_ word: String, _ rank: Int) -> String { f("hintLands", word, rank) }
    func spellHint(_ letters: String) -> String { f("spellHint", letters) }
    var wickEgg: String { s("wickEgg") }
    var eggHunch: String { s("eggHunch") }
    var eggCheat: String { s("eggCheat") }
    func plusCoins(_ amount: Int) -> String { f("plusCoins", amount) }
    func outOfFreeQuestions(_ cost: Int) -> String { f("outOfFreeQuestions", cost) }
    var keeperDidntRespond: String { s("keeperDidntRespond") }
    var scoringUnavailable: String { s("scoringUnavailable") }
    var vocabularyReady: String { s("vocabularyReady") }
    var scoringKeyboardHint: String { s("scoringKeyboardHint") }

    // MARK: - Embedding download (1.9 On-Demand Resources)
    var downloadDictionaryTitle: String { s("downloadDictionaryTitle") }
    var downloadDictionaryBlurb: String { s("downloadDictionaryBlurb") }
    var downloadDictionaryFailed: String { s("downloadDictionaryFailed") }
    var cancelDownload: String { s("cancelDownload") }
    var dictionaries: String { s("dictionaries") }
    var dictionariesBlurb: String { s("dictionariesBlurb") }
    var downloadAll: String { s("downloadAll") }
    var dictionaryReady: String { s("dictionaryReady") }
    var dictionaryDownload: String { s("dictionaryDownload") }

    // MARK: - Settings extras
    var notifications: String { s("notifications") }
    var about: String { s("about") }
    var privacyPolicy: String { s("privacyPolicy") }
    var languagePickHint: String { s("languagePickHint") }

    // MARK: - How to play
    var meetKeeper: String { s("meetKeeper") }
    var meetKeeperSub: String { s("meetKeeperSub") }
    var letsPlay: String { s("letsPlay") }
    var howStep1Title: String { s("howStep1Title") }
    var howStep1Detail: String { s("howStep1Detail") }
    var howStep2Title: String { s("howStep2Title") }
    var howStep2Detail: String { s("howStep2Detail") }
    var howStep3Title: String { s("howStep3Title") }
    var howStep3Detail: String { s("howStep3Detail") }
    var howStep4Title: String { s("howStep4Title") }
    var howStep4Detail: String { s("howStep4Detail") }

    // MARK: - Shop
    var getCoins: String { s("getCoins") }
    var yourBalance: String { s("yourBalance") }
    func coinsAmount(_ n: Int) -> String { f("coinsAmount", n) }
    var loadingShop: String { s("loadingShop") }
    var shopUnavailable: String { s("shopUnavailable") }
    var shopUnavailableDetail: String { s("shopUnavailableDetail") }
    var coinsBuyBlurb: String { s("coinsBuyBlurb") }

    // MARK: - Ghost Race (3.2)
    /// Keys mirror wick-web/src/i18n.ts exactly, so a challenge reads the same
    /// on both clients. Integer slots use %d here: web's t() fills %@ and %d
    /// alike, but String(format:) does not — %@ with an Int is undefined.
    var ghostRival: String { s("ghostRival") }
    var ghostWaiting: String { s("ghostWaiting") }
    func ghostFinished(_ time: String) -> String { f("ghostFinished", time) }
    var raceChallengeTitle: String { s("raceChallengeTitle") }
    func raceChallengeBlurb(_ puzzle: Int, _ moves: Int) -> String { f("raceChallengeBlurb", puzzle, moves) }
    func raceChallengeBlurbPractice(_ moves: Int) -> String { f("raceChallengeBlurbPractice", moves) }
    var raceStart: String { s("raceStart") }
    var raceDecline: String { s("raceDecline") }
    var raceGo: String { s("raceGo") }
    var raceAFriend: String { s("raceAFriend") }
    var raceThemBack: String { s("raceThemBack") }
    func raceShareSolved(_ time: String) -> String { f("raceShareSolved", time) }
    var raceShareUnsolved: String { s("raceShareUnsolved") }
    // Race hub (3.3) — Dare retired; ghost race leads, live race second.
    var homeRaceSub: String { s("homeRaceSub") }
    var raceFriendBlurb: String { s("raceFriendBlurb") }
    var racePlayTodayFirst: String { s("racePlayTodayFirst") }
    var raceSendYourRun: String { s("raceSendYourRun") }
    var raceStrangerTitle: String { s("raceStrangerTitle") }
    var raceLiveDisclosure: String { s("raceLiveDisclosure") }

    // MARK: - The Reveal (3.2)
    /// `revealFound` / `revealCaption` / `revealTheWord` / `revealSeeMap` mirror
    /// wick-web/src/i18n.ts (minus web's leading emoji on `revealSeeMap`, which
    /// iOS draws as an SF Symbol). The rest are iOS-only VoiceOver strings.
    func revealFound(_ word: String, _ guesses: Int) -> String { f("revealFound", word, guesses) }
    var revealCaption: String { s("revealCaption") }
    var revealTheWord: String { s("revealTheWord") }
    var revealSeeMap: String { s("revealSeeMap") }
    var revealReplay: String { s("revealReplay") }
    var revealMapA11y: String { s("revealMapA11y") }
    func revealGuessA11y(_ n: Int, _ word: String, _ band: String) -> String {
        f("revealGuessA11y", n, word, band)
    }

    // MARK: - Tables

    /// All string tables, keyed by language code. Adding a language = adding
    /// one entry here (missing keys fall back to English automatically).
    static let tables: [String: [String: String]] = [
        GameLanguage.english.rawValue: en,
        GameLanguage.spanish.rawValue: es,
        GameLanguage.french.rawValue: fr,
        GameLanguage.italian.rawValue: it,
        GameLanguage.german.rawValue: de,
    ]

    /// English — the source language and universal fallback. Every key MUST
    /// exist here.
    static let en: [String: String] = [
        // The Reveal (3.2)
        "revealFound": "You found %@ in %d",
        "revealCaption": "Distance from the center is how close you were in meaning; similar guesses sit near each other.",
        "revealTheWord": "THE WORD",
        "revealSeeMap": "See the map",
        "revealReplay": "Replay the hunt",
        "revealMapA11y": "Semantic map of your guesses.",
        "revealGuessA11y": "Guess %d, %@, %@",
        // Ghost Race (3.2) — mirrors wick-web/src/i18n.ts key for key.
        "ghostRival": "Ghost",
        "ghostWaiting": "warming up",
        "ghostFinished": "finished in %@",
        "raceChallengeTitle": "A friend challenged you",
        "raceChallengeBlurb": "Puzzle #%d \u{2014} they made %d moves. Beat their time.",
        "raceChallengeBlurbPractice": "A random word \u{2014} they made %d moves. Beat their time.",
        "raceStart": "Race them",
        "raceDecline": "Just play it alone",
        "raceGo": "GO!",
        "raceAFriend": "Race a friend",
        "raceThemBack": "Race them back",
        "raceShareSolved": "I solved it in %@ \u{2014} beat that.",
        "raceShareUnsolved": "Can you solve this one?",
        "homeRaceSub": "Beat a friend's time",
        "raceFriendBlurb": "Finish today's word, then send the link. Your friend races your ghost, move by move. No app needed.",
        "racePlayTodayFirst": "Play today's word",
        "raceSendYourRun": "Send your race",
        "raceStrangerTitle": "Race someone live",
        "raceLiveDisclosure": "Live races send the words you type to Wick's server (via Google Gemini) to score them. A ghost race link carries only your timing and warmth, never your words.",
        "liveRematch": "Rematch",
        "liveScanCaption": "Or scan the code.",
        // Live multiplayer (3.0/3.1)
        "liveJoin": "Join", "liveCancel": "Cancel", "liveDone": "Done", "liveClose": "Close", "liveLeave": "Leave",
        "liveConnectionLost": "Connection lost", "liveTheWordWas": "The word was", "liveYourRound": "Your round",
        "liveInviteFriend": "Invite a friend", "liveKeepGoing": "keep going", "liveScoring": "scoring…",
        "liveYouGotItLower": "you got it", "liveSolvedExcl": "Solved!",
        "liveRace": "Race", "liveRaceBlurb": "Both of you guess the same hidden word — first to solve wins.",
        "liveQuickMatch": "Quick Match", "liveHaveACode": "HAVE A CODE?", "liveEnterIt": "enter it",
        "liveInviteHintRace": "Invite makes a link to send. Quick Match finds anyone (or a practice flame).",
        "liveFindingOpponent": "Finding an opponent…", "liveWaitingForFriend": "Waiting for your friend…",
        "livePracticeFlameSteps": "A Wick flame steps in if nobody's around.",
        "liveNextRaceIn": "Next race starts in",
        "liveShareInviteLink": "Share invite link",
        "liveShareTapToJoin": "Send the link — your friend taps it to join. Or they can type the code.",
        "liveTheyJoinByLink": "They join by tapping your link, or entering the code.",
        "liveLiveRace": "Live Race", "livePlayAgain": "Play again", "liveTryAgain": "Try again",
        "liveGuessOrAsk": "Guess a word, or ask Wick…",
        "liveGuessOrAskHint": "A single word is a guess. Add a “?” or type a phrase to ask Wick.",
        "liveWelcome": "Hi, I'm %@. I'm guarding a secret word — guess anything and I'll tell you how close you are by meaning.",
        "liveLiveOpponent": "Live opponent", "livePracticeFlame": "Practice flame",
        "liveGhost": "Ghost of a past run", "liveOpponent": "Opponent", "liveReconnecting": "reconnecting…",
        "liveGuessesCount": "%d guesses",
        "liveGoodStart": "Good start!", "liveClosestYet": "Closest yet", "liveFurther": "Further than your best",
        "liveResult": "Result", "liveYouWin": "You win!", "liveYouLost": "You lost", "liveDraw": "Draw",
        "liveFirstToWord": "First to the word.", "liveOppFirst": "Your opponent got there first.",
        "liveTimeUpWarmest": "Time's up — decided by the warmest guess.",
        "liveOppLeft": "Your opponent left.", "liveYouLeft": "You left the match.",
        "liveBothDropped": "No result — both players dropped.",
        "liveOppLeftHangTight": "Your opponent left — hang tight.",
        "liveNotAWord": "That's not a word I know — try another.",
        "liveInviteExpired": "That invite's expired — ask your friend for a new link.",
        "liveShareMsgRace": "Race me in Wick!",
        // Header
        "dailyTitle": "#%d",
        "practice": "Practice",
        "archive": "Past puzzles",
        "archiveEmpty": "No past puzzles yet. Come back tomorrow!",
        "archiveSolvedToast": "Nice — you solved a past puzzle!",
        "todaysPuzzle": "Today's puzzle",
        "tier": "Tier %d",
        // Welcome / hero
        "welcome": "Hi, I'm %@. I'm guarding a secret word — guess anything and I'll tell you how close you are by meaning.",
        "notInVocabulary": "not in vocabulary",
        "keepGoing": "keep going",
        // Trajectory
        "firstGuess": "Good start!",
        "heat.Solved!": "Solved!",
        "heat.Boiling": "Boiling",
        "heat.Hot": "Hot",
        "heat.Warm": "Warm",
        "heat.Cool": "Cool",
        "heat.Cold": "Cold",
        "heat.Freezing": "Freezing",
        "nudgeSoClose": "So close I can feel it!",
        "nudgeCircling": "Ooh, you're circling it…",
        "nudgeStuck": "Cold for a few now. Stuck? Ask me something — like what it's used for, or where you'd find it.",
        "coachNotAWord": "I don't know that one — I only know everyday single words. Try another.",
        "coachFirstCold": "Cold doesn't mean it's a bad word — it means wrong topic. I score by meaning, not spelling. Try something from a totally different subject.",
        "coachFirstWarm": "Good — that's the right neighbourhood. Now go more specific in that direction.",
        "coachTriangulate": "Still nothing warm. Spread out instead of digging: an animal, a feeling, a place, a tool. Once one comes back warm, follow it.",
        "warmestUp": "Closest yet · %d closer",
        "warmest": "Closest yet",
        "colder": "Further than your best",
        // Input
        "guessPlaceholder": "Guess a word…",
        "askKeeper": "Ask the Keeper",
        "hint": "Hint",
        "guessOrAskPlaceholder": "Guess a word, or ask Wick…",
        "guessOrAskHint": "A single word is a guess. Add a “?” or type a phrase to ask Wick.",
        "roundLog": "Your round",
        "needIdeas": "Need ideas to ask Wick?",
        "a11ySend": "Send",
        "a11yShop": "Open the coin shop",
        "a11yAskThis": "Asks Wick this question",
        "waysTitle": "Two ways to play",
        "wayGuessTitle": "Type one word",
        "wayGuessBody": "I'll tell you how close it is in meaning.",
        "wayAskTitle": "Or ask me anything",
        "wayAskBody": "Yes / no answers, always free.",
        "offerStuck": "Cold for a few now. Want me to narrow it down?",
        "offerCold": "Nothing warm yet. Try asking me this —",
        "offerRoutine": "You can interrogate me, you know. Start here:",
        "offerAskElse": "Something else",
        "offerNotNow": "Not now",
        "sortRecent": "Recent",
        "sortClosest": "Hottest",
        // Learn mode
        "learnTitle": "Learn mode",
        "learnToggle": "Learn %@",
        "learnBlurb": "Shows each guess translated to %@ (%@ → %@) as you play, so you pick up words.",
        // Solved / revealed
        "solvedTitle": "Solved it!",
        "solvedIn.one": "“%@” in %d guess",
        "solvedIn.other": "“%@” in %d guesses",
        "streakDays": "%d-day streak!",
        "shareResult": "Share result",
        "shareSolvedIn": "solved in %d",
        "shareQuestions.one": "%d question",
        "shareQuestions.other": "%d questions",
        "shareHints.one": "%d hint",
        "shareHints.other": "%d hints",
        "shareTagline": "Wick · guess by meaning",
        "playRandom": "Play a random word",
        "easy": "Easy",
        "medium": "Medium",
        "hard": "Hard",
        "theWordWas": "The word was",
        // Give up
        "giveUpTitle": "Reveal the answer?",
        "giveUp": "Give up",
        "keepTrying": "Keep trying",
        "giveUpMessage": "You'll see the word and this round ends.",
        // Guess list
        "guessesCount": "Guesses · %d",
        // Ask the Keeper
        "askTitle": "Ask the Keeper",
        "done": "Done",
        "duel": "Duel",
        "soundHapticsTitle": "Sound & Haptics",
        "hapticsToggle": "Haptics",
        "soundToggle": "Sound",
        "duelSolvedToast": "Duel solved! Share your result to compare.",
        "home": "Home",
        "pastPuzzles": "Past puzzles",
        "chooseDifficulty": "Choose difficulty",
        "homeGuessWord": "Guess the secret word",
        "homeReplayAnyDay": "Replay any day",
        "homePlayAnytime": "Play anytime",
        "homeDressUpWick": "Dress up Wick",
        "duelCreate": "Create a duel",
        "duelRace": "Race",
        "duelRaceBlurb": "Wick picks a secret word — you both play it blind, then compare.",
        "duelPlayNow": "Play now",
        "duelYourCode": "Your duel code",
        "duelShareCode": "Share",
        "duelPaste": "Paste code",
        "duelJoin": "Join a duel",
        "duelJoinPlaceholder": "Paste a code…",
        "duelGo": "Go",
        "duelInvalid": "That code isn't valid.",
        "duelChooseWord": "Choose a word",
        "duelHeadToHead": "Head-to-head",
        "duelWin": "You win!",
        "duelLose": "They win!",
        "duelTie": "It's a tie!",
        "duelYou": "You",
        "duelThem": "Them",
        "duelGaveUp": "Gave up",
        "duelNeedYours": "Play this duel to compare head-to-head.",
        "duelCopied": "Copied!",
        "duelCopy": "Copy",
        "duelResultShare": "Share your result",
        "duelResultMsg": "My Wick duel result: %@ — paste it in the duel to compare.",
        "duelYouChose": "You chose \"%@\". Send the code to a friend.",
        "duelShareMsg": "Can you beat me at Wick?",
        "duelSolvedIn": "Solved in %d",
        "wardrobe": "Wick's Wardrobe",
        "wardrobeBlurb": "Spend coins to dress up Wick. Just for fun — it won't change the game.",
        "equip": "Wear",
        "equipped": "Wearing",
        "take_off": "Take off",
        "buy": "Buy",
        "owned": "Owned",
        "notEnoughCoins": "Not enough coins",
        "slot_hat": "Hats",
        "slot_eyes": "Eyes",
        "slot_face": "Face",
        "slot_mouth": "Mouth",
        "slot_neck": "Neck",
        "acc_tophat": "Top Hat",
        "acc_tongue": "Tongue Out",
        "acc_googly": "Googly Eyes",
        "acc_hearts": "Heart Eyes",
        "acc_stars": "Star Eyes",
        "acc_party": "Party Hat",
        "acc_wizard": "Wizard Hat",
        "acc_crown": "Crown",
        "acc_monocle": "Monocle",
        "acc_glasses": "Glasses",
        "acc_bowtie": "Bow Tie",
        "acc_tie": "Necktie",
        "askTab": "Ask",
        "guessTab": "Guess",
        "suggestedQuestions": "Suggested questions",
        "dreamingClue": "%@ is dreaming up a clue…",
        "askIntro": "Ask things like “Is it alive?”, “Bigger than a car?”, “Found indoors?” The Keeper answers truthfully but won't reveal the word.",
        "keeperNoRespond": "The Keeper didn’t respond",
        "retry": "Retry",
        "askPlaceholder": "Ask Wick anything…",
        "questionsFree": "Questions are free — ask Wick anything.",
        "notAKnownWord": "not a known word",
        "offlineBanner": "Wick works offline on this iPhone. Tap a suggested question for an exact answer, or type a simple yes/no like “Is it alive?” or “Bigger than a car?” You don’t need Apple Intelligence.",
        "offlineFootnote": "Offline mode: Wick answers the basics on-device. Tap a suggestion for an exact answer.",
        "freeQuestionsLeft.one": "%d free question left",
        "freeQuestionsLeft.other": "%d free questions left",
        "questionCost": "Each question costs %d coins (you have %d)",
        "outOfCoins": "Out of coins — keep guessing free, or solve rounds to earn more.",
        // Menu / Settings
        "howToPlay": "How to play",
        "settings": "Settings",
        "language": "Language",
        "languageFooter": "Sets the language of the daily word, your guesses, and Wick. Changing it starts a fresh round.",
        // Stats
        "yourStats": "Your stats",
        "currentStreak": "Current streak",
        "bestStreak": "Best streak",
        "wordsSolved": "Words solved",
        "avgGuesses": "Avg guesses",
        "fewestGuesses": "Fewest guesses",
        "coins": "Coins",
        "achievements": "Achievements",
        "leaderboards": "Leaderboards",
        "dailyReminder": "Daily reminder",
        "time": "Time",
        "reminderBlurb": "A gentle nudge when each day's word is ready.",
        "notifDailyTitle": "Today's word is ready",
        "notifDailyBody": "Wick is guarding a new one. Think you can get it?",
        "notifStreakTitle": "Your flame is about to go out",
        "notifStreakBody": "%d days and counting — today's word is still unsolved.",
        // Toasts
        "dailyBonus": "Daily bonus · +%d coins",
        "countsAsAlready": "“%@” counts as “%@” — already guessed.",
        "alreadyGuessed": "Already guessed “%@”.",
        "normalizedTo": "“%@” → “%@”",
        "didYouMean": "“%@” isn’t in my vocabulary — did you mean “%@”?",
        "notInVocabToast": "“%@” isn’t in my vocabulary — try another.",
        "solvedBadge": "Solved! +%d · 🏅 %@",
        "solvedCoins": "Solved! +%d coins",
        "theWordWasToast": "The word was “%@”",
        "hintWarmingUp": "Hint is warming up — try again in a second.",
        "hintsCost": "Free hints are done for today. Hints cost %d coins now.",
        "hintFreeLeft": "Hint (%d free today)", "hintCoinPrice": "Hint (%d coins)",
        "topTakeIt": "You're in the top %d — take it from here! 🔥",
        "noCloserHint": "You're closing in — no closer hint to give!",
        "hintLands": "Hint: “%@” lands at #%d — warmer!",
        "spellHint": "The word starts with %@",
        "wickEgg": "Hey — that's what I'm made of!",
        "eggHunch": "Hunch? That's my old name — good memory.",
        "eggCheat": "Cheat? Where's the fun in that?",
        "plusCoins": "+%d coins",
        "outOfFreeQuestions": "Out of free questions — costs %d coins.",
        "keeperDidntRespond": "The Keeper didn’t respond — tap Retry.",
        "scoringUnavailable": "This language's dictionary isn't downloaded yet — I'll keep trying. Connect to the internet for a moment and it'll sort itself out.",
        "vocabularyReady": "Dictionary ready — game on!",
        "scoringKeyboardHint": "Still downloading? iOS fetches a dictionary once your device uses the language — add this language's keyboard in Settings → General → Keyboard, then come back. I'll pick it up automatically.",
        "downloadDictionaryTitle": "Downloading dictionary…",
        "downloadDictionaryBlurb": "A quick one-time download so you can play this language offline. It'll only take a moment.",
        "downloadDictionaryFailed": "Couldn't download just now — I'll keep trying, and you can still play with the built-in dictionary.",
        "cancelDownload": "Cancel",
        "dictionaries": "Offline dictionaries",
        "dictionariesBlurb": "Download a language's dictionary so it's ready to play offline. Languages also download automatically the first time you pick them.",
        "downloadAll": "Download all languages",
        "dictionaryReady": "Ready",
        "dictionaryDownload": "Download",
        // Settings extras
        "notifications": "Notifications",
        "about": "About",
        "privacyPolicy": "Privacy Policy",
        "languagePickHint": "Choose the game's language",
        // How to play
        "meetKeeper": "Meet the Keeper",
        "meetKeeperSub": "It guards the secret word — and warms up as you get close.",
        "letsPlay": "Let's play",
        "howStep1Title": "Guess by meaning",
        "howStep1Detail": "There's one secret word. Type any word and you'll see how close it is — by meaning, not spelling.",
        "howStep2Title": "Hot or cold",
        "howStep2Detail": "Closer guesses score higher and turn red-hot. Far-off ones stay icy blue. The screen warms up as you close in.",
        "howStep3Title": "Ask Wick",
        "howStep3Detail": "Stuck? Ask Wick yes/no questions like “Is it alive?” — it works on every iPhone, answers truthfully, and never reveals the word.",
        "howStep4Title": "A new word daily",
        "howStep4Detail": "Everyone gets the same word each day. Solve it, build a streak, and share your result.",
        // Shop
        "getCoins": "Get coins",
        "yourBalance": "Your balance",
        "coinsAmount": "%d coins",
        "loadingShop": "Loading shop…",
        "shopUnavailable": "Shop unavailable",
        "shopUnavailableDetail": "Coin packs couldn't load right now. Check your connection and try again.",
        "coinsBuyBlurb": "Coins buy extra hints and questions. You can always play the daily and earn coins for free.",
    ]

    /// Spanish.
    static let es: [String: String] = [
        // The Reveal (3.2)
        "revealFound": "Encontraste %@ en %d",
        "revealCaption": "La distancia al centro indica lo cerca que estuviste en significado; las palabras parecidas quedan juntas.",
        "revealTheWord": "LA PALABRA",
        "revealSeeMap": "Ver el mapa",
        "revealReplay": "Repetir la b\u{00FA}squeda",
        "revealMapA11y": "Mapa sem\u{00E1}ntico de tus intentos.",
        "revealGuessA11y": "Intento %d, %@, %@",
        // Ghost Race (3.2)
        "ghostRival": "Fantasma",
        "ghostWaiting": "calentando",
        "ghostFinished": "termin\u{00F3} en %@",
        "raceChallengeTitle": "Un amigo te ha retado",
        "raceChallengeBlurb": "Puzle n.\u{00BA} %d: hicieron %d movimientos. Supera su tiempo.",
        "raceChallengeBlurbPractice": "Una palabra al azar: hicieron %d movimientos. Supera su tiempo.",
        "raceStart": "Compite",
        "raceDecline": "Jugar yo solo",
        "raceGo": "\u{00A1}YA!",
        "raceAFriend": "Retar a un amigo",
        "raceThemBack": "Devolver el reto",
        "raceShareSolved": "Lo resolv\u{00ED} en %@: sup\u{00E9}ralo.",
        "raceShareUnsolved": "\u{00BF}Puedes resolver este?",
        "homeRaceSub": "Supera el tiempo de un amigo",
        "raceFriendBlurb": "Termina la palabra de hoy y envía el enlace. Tu amigo corre contra tu fantasma, jugada a jugada. No necesita la app.",
        "racePlayTodayFirst": "Juega la palabra de hoy",
        "raceSendYourRun": "Envía tu carrera",
        "raceStrangerTitle": "Carrera en vivo",
        "raceLiveDisclosure": "Las carreras en vivo envían las palabras que escribes al servidor de Wick (vía Google Gemini) para puntuarlas. Un enlace de carrera fantasma solo lleva tus tiempos y tu calor, nunca tus palabras.",
        "liveRematch": "Revancha",
        "liveScanCaption": "O escanea el código.",
        // Live multiplayer (3.0/3.1) — draft, needs fluent skim
        "liveJoin": "Unirse", "liveCancel": "Cancelar", "liveDone": "Listo", "liveClose": "Cerrar", "liveLeave": "Salir",
        "liveConnectionLost": "Conexión perdida", "liveTheWordWas": "La palabra era", "liveYourRound": "Tu ronda",
        "liveInviteFriend": "Invita a un amigo", "liveKeepGoing": "sigue así", "liveScoring": "puntuando…",
        "liveYouGotItLower": "¡lo tienes!", "liveSolvedExcl": "¡Resuelto!",
        "liveRace": "Carrera", "liveRaceBlurb": "Ambos adivináis la misma palabra oculta: gana quien la resuelva primero.",
        "liveQuickMatch": "Partida rápida", "liveHaveACode": "¿TIENES UN CÓDIGO?", "liveEnterIt": "escríbelo",
        "liveInviteHintRace": "Invitar crea un enlace para enviar. Partida rápida encuentra a cualquiera (o una llama de práctica).",
        "liveFindingOpponent": "Buscando rival…", "liveWaitingForFriend": "Esperando a tu amigo…",
        "livePracticeFlameSteps": "Una llama de Wick entra si no hay nadie.",
        "liveNextRaceIn": "La próxima carrera empieza en",
        "liveShareInviteLink": "Compartir enlace",
        "liveShareTapToJoin": "Envía el enlace: tu amigo toca para unirse. O puede escribir el código.",
        "liveTheyJoinByLink": "Se unen tocando tu enlace o escribiendo el código.",
        "liveLiveRace": "Carrera en vivo", "livePlayAgain": "Jugar otra vez", "liveTryAgain": "Reintentar",
        "liveGuessOrAsk": "Adivina una palabra o pregúntale a Wick…",
        "liveGuessOrAskHint": "Una sola palabra es un intento. Añade “?” o escribe una frase para preguntarle a Wick.",
        "liveWelcome": "Hola, soy %@. Guardo una palabra secreta: adivina lo que sea y te diré qué tan cerca estás por significado.",
        "liveLiveOpponent": "Rival en vivo", "livePracticeFlame": "Llama de práctica",
        "liveGhost": "Fantasma de una partida pasada", "liveOpponent": "Rival", "liveReconnecting": "reconectando…",
        "liveGuessesCount": "%d intentos",
        "liveGoodStart": "¡Buen comienzo!", "liveClosestYet": "Lo más cerca", "liveFurther": "Más lejos que tu mejor",
        "liveResult": "Resultado", "liveYouWin": "¡Ganaste!", "liveYouLost": "Perdiste", "liveDraw": "Empate",
        "liveFirstToWord": "El primero en llegar a la palabra.", "liveOppFirst": "Tu rival llegó primero.",
        "liveTimeUpWarmest": "Se acabó el tiempo: decide el intento más cálido.",
        "liveOppLeft": "Tu rival se fue.", "liveYouLeft": "Saliste de la partida.",
        "liveBothDropped": "Sin resultado: ambos jugadores se cayeron.",
        "liveOppLeftHangTight": "Tu rival se fue: espera un momento.",
        "liveNotAWord": "Esa no es una palabra que conozca: prueba otra.",
        "liveInviteExpired": "Esa invitación caducó: pídele a tu amigo un nuevo enlace.",
        "liveShareMsgRace": "¡Compite conmigo en Wick!",
        // Header
        "dailyTitle": "N.º %d",
        "practice": "Práctica",
        "archive": "Puzzles anteriores",
        "archiveEmpty": "Aún no hay puzzles anteriores. ¡Vuelve mañana!",
        "archiveSolvedToast": "¡Bien! Resolviste un puzzle anterior.",
        "todaysPuzzle": "Puzzle de hoy",
        "tier": "Nivel %d",
        // Welcome / hero
        "welcome": "Hola, soy %@. Guardo una palabra secreta: adivina lo que sea y te diré qué tan cerca estás por significado.",
        "notInVocabulary": "no está en el vocabulario",
        "keepGoing": "sigue",
        // Trajectory
        "firstGuess": "¡Buen comienzo!",
        "heat.Solved!": "¡Resuelto!",
        "heat.Boiling": "Hirviendo",
        "heat.Hot": "Caliente",
        "heat.Warm": "Cálido",
        "heat.Cool": "Fresco",
        "heat.Cold": "Frío",
        "heat.Freezing": "Helado",
        "nudgeSoClose": "¡Tan cerca que puedo sentirlo!",
        "nudgeCircling": "Uy, lo estás rodeando…",
        "nudgeStuck": "Varios intentos fríos seguidos. ¿Atascado? Pregúntame algo — para qué sirve, o dónde se encuentra.",
        "coachNotAWord": "Esa no la conozco — solo sé palabras sueltas y corrientes. Prueba con otra.",
        "coachFirstCold": "Frío no significa que sea mala palabra — significa tema equivocado. Puntuúo por significado, no por letras. Prueba con algo de un tema totalmente distinto.",
        "coachFirstWarm": "Bien — ese es el barrio correcto. Ahora sé más específico en esa dirección.",
        "coachTriangulate": "Sigue sin haber nada caliente. En vez de insistir, Ã¡brete: un animal, una emoción, un lugar, una herramienta. Cuando algo salga caliente, síguelo.",
        "warmestUp": "Lo más cerca · %d más cerca",
        "warmest": "Lo más cerca hasta ahora",
        "colder": "Más lejos que tu mejor intento",
        // Input
        "guessPlaceholder": "Adivina una palabra…",
        "askKeeper": "Pregunta al Guardián",
        "hint": "Pista",
        "guessOrAskPlaceholder": "Adivina una palabra o pregunta a Wick…",
        "guessOrAskHint": "Una palabra suelta es un intento. Añade «?» o escribe una frase para preguntar a Wick.",
        "roundLog": "Tu ronda",
        "needIdeas": "¿Ideas para preguntar a Wick?",
        "a11ySend": "Enviar",
        "a11yShop": "Abrir la tienda de monedas",
        "a11yAskThis": "Hace esta pregunta a Wick",
        "waysTitle": "Dos formas de jugar",
        "wayGuessTitle": "Escribe una palabra",
        "wayGuessBody": "Te diré lo cerca que está en significado.",
        "wayAskTitle": "O pregúntame lo que sea",
        "wayAskBody": "Respuestas de sí / no, siempre gratis.",
        "offerStuck": "Llevas varios fríos. ¿Quieres que lo acote?",
        "offerCold": "Nada caliente todavía. Prueba a preguntarme esto —",
        "offerRoutine": "Puedes interrogarme, ¿sabes? Empieza por aquí:",
        "offerAskElse": "Otra cosa",
        "offerNotNow": "Ahora no",
        "sortRecent": "Recientes",
        "sortClosest": "Más cálidos",
        // Learn mode
        "learnTitle": "Modo aprendizaje",
        "learnToggle": "Aprender %@",
        "learnBlurb": "Muestra cada intento traducido al %@ (%@ → %@) mientras juegas, para aprender palabras.",
        // Solved / revealed
        "solvedTitle": "¡Resuelto!",
        "solvedIn.one": "«%@» en %d intento",
        "solvedIn.other": "«%@» en %d intentos",
        "streakDays": "¡Racha de %d días!",
        "shareResult": "Compartir resultado",
        "shareSolvedIn": "resuelto en %d",
        "shareQuestions.one": "%d pregunta",
        "shareQuestions.other": "%d preguntas",
        "shareHints.one": "%d pista",
        "shareHints.other": "%d pistas",
        "shareTagline": "Wick · adivina por significado",
        "playRandom": "Jugar una palabra al azar",
        "easy": "Fácil",
        "medium": "Media",
        "hard": "Difícil",
        "theWordWas": "La palabra era",
        // Give up
        "giveUpTitle": "¿Revelar la respuesta?",
        "giveUp": "Rendirse",
        "keepTrying": "Seguir intentando",
        "giveUpMessage": "Verás la palabra y la ronda terminará.",
        // Guess list
        "guessesCount": "Intentos · %d",
        // Ask the Keeper
        "askTitle": "Pregunta al Guardián",
        "done": "Listo",
        "duel": "Duelo",
        "soundHapticsTitle": "Sonido y vibración",
        "hapticsToggle": "Vibración",
        "soundToggle": "Sonido",
        "duelSolvedToast": "¡Duelo resuelto! Comparte tu resultado.",
        "home": "Inicio",
        "pastPuzzles": "Anteriores",
        "chooseDifficulty": "Elige dificultad",
        "homeGuessWord": "Adivina la palabra secreta",
        "homeReplayAnyDay": "Repite cualquier día",
        "homePlayAnytime": "Juega cuando quieras",
        "homeDressUpWick": "Viste a Wick",
        "duelCreate": "Crear un duelo",
        "duelRace": "Carrera",
        "duelRaceBlurb": "Wick elige una palabra secreta — ambos jugáis a ciegas y comparáis.",
        "duelPlayNow": "Jugar ahora",
        "duelYourCode": "Tu código de duelo",
        "duelShareCode": "Compartir",
        "duelPaste": "Pegar código",
        "duelJoin": "Unirse a un duelo",
        "duelJoinPlaceholder": "Pega un código…",
        "duelGo": "Ir",
        "duelInvalid": "Ese código no es válido.",
        "duelChooseWord": "Elige una palabra",
        "duelHeadToHead": "Cara a cara",
        "duelWin": "¡Ganas!",
        "duelLose": "¡Ganan ellos!",
        "duelTie": "¡Empate!",
        "duelYou": "Tú",
        "duelThem": "Ellos",
        "duelGaveUp": "Se rindió",
        "duelNeedYours": "Juega este duelo para comparar cara a cara.",
        "duelCopied": "¡Copiado!",
        "duelCopy": "Copiar",
        "duelResultShare": "Comparte tu resultado",
        "duelResultMsg": "Mi resultado del duelo Wick: %@ — pégalo en el duelo para comparar.",
        "duelYouChose": "Elegiste «%@». Envía el código a un amigo.",
        "duelShareMsg": "¿Puedes ganarme en Wick?",
        "duelSolvedIn": "Resuelto en %d",
        "wardrobe": "Armario de Wick",
        "wardrobeBlurb": "Gasta monedas para vestir a Wick. Solo por diversión — no cambia el juego.",
        "equip": "Poner",
        "equipped": "Puesto",
        "take_off": "Quitar",
        "buy": "Comprar",
        "owned": "Adquirido",
        "notEnoughCoins": "Monedas insuficientes",
        "slot_hat": "Sombreros",
        "slot_eyes": "Ojos",
        "slot_face": "Cara",
        "slot_mouth": "Boca",
        "slot_neck": "Cuello",
        "acc_tophat": "Chistera",
        "acc_tongue": "Lengua fuera",
        "acc_googly": "Ojos saltones",
        "acc_hearts": "Ojos de corazón",
        "acc_stars": "Ojos de estrella",
        "acc_party": "Gorro de fiesta",
        "acc_wizard": "Sombrero de mago",
        "acc_crown": "Corona",
        "acc_monocle": "Monóculo",
        "acc_glasses": "Gafas",
        "acc_bowtie": "Pajarita",
        "acc_tie": "Corbata",
        "askTab": "Preguntar",
        "guessTab": "Adivinar",
        "suggestedQuestions": "Preguntas sugeridas",
        "dreamingClue": "%@ está ideando una pista…",
        "askIntro": "Pregunta cosas como «¿Está vivo?», «¿Más grande que un coche?», «¿Se encuentra en interiores?». El Guardián responde con la verdad, pero no revelará la palabra.",
        "keeperNoRespond": "El Guardián no respondió",
        "retry": "Reintentar",
        "askPlaceholder": "Pregúntale lo que sea a Wick…",
        "questionsFree": "Las preguntas son gratis — pregúntale lo que sea a Wick.",
        "notAKnownWord": "no es una palabra conocida",
        "offlineBanner": "Wick funciona sin conexión en este iPhone. Toca una pregunta sugerida para una respuesta exacta, o escribe un sí/no simple como «¿Está vivo?». No necesitas Apple Intelligence.",
        "offlineFootnote": "Modo sin conexión: Wick responde lo básico en el dispositivo. Toca una sugerencia para una respuesta exacta.",
        "freeQuestionsLeft.one": "%d pregunta gratis",
        "freeQuestionsLeft.other": "%d preguntas gratis",
        "questionCost": "Cada pregunta cuesta %d monedas (tienes %d)",
        "outOfCoins": "Sin monedas: sigue adivinando gratis o resuelve rondas para ganar más.",
        // Menu / Settings
        "howToPlay": "Cómo jugar",
        "settings": "Ajustes",
        "language": "Idioma",
        "languageFooter": "Define el idioma de la palabra del día, tus intentos y Wick. Cambiarlo inicia una ronda nueva.",
        // Stats
        "yourStats": "Tus estadísticas",
        "currentStreak": "Racha actual",
        "bestStreak": "Mejor racha",
        "wordsSolved": "Palabras resueltas",
        "avgGuesses": "Intentos prom.",
        "fewestGuesses": "Menos intentos",
        "coins": "Monedas",
        "achievements": "Logros",
        "leaderboards": "Clasificaciones",
        "dailyReminder": "Recordatorio diario",
        "time": "Hora",
        "reminderBlurb": "Un aviso suave cuando la palabra de cada día está lista.",
        "notifDailyTitle": "La palabra de hoy está lista",
        "notifDailyBody": "Wick guarda una nueva. ¿Crees que la adivinas?",
        "notifStreakTitle": "Tu llama está a punto de apagarse",
        "notifStreakBody": "%d días seguidos — la palabra de hoy sigue sin resolver.",
        // Toasts
        "dailyBonus": "Bono diario · +%d monedas",
        "countsAsAlready": "«%@» cuenta como «%@» — ya la intentaste.",
        "alreadyGuessed": "Ya intentaste «%@».",
        "normalizedTo": "«%@» → «%@»",
        "didYouMean": "«%@» no está en mi vocabulario — ¿quisiste decir «%@»?",
        "notInVocabToast": "«%@» no está en mi vocabulario — prueba otra.",
        "solvedBadge": "¡Resuelto! +%d · 🏅 %@",
        "solvedCoins": "¡Resuelto! +%d monedas",
        "theWordWasToast": "La palabra era «%@»",
        "hintWarmingUp": "La pista se está calentando — inténtalo en un segundo.",
        "hintsCost": "Las pistas gratis de hoy se acabaron. Ahora cuestan %d monedas.",
        "hintFreeLeft": "Pista (%d gratis hoy)", "hintCoinPrice": "Pista (%d monedas)",
        "topTakeIt": "Estás entre los %d primeros — ¡tú puedes! 🔥",
        "noCloserHint": "Te estás acercando — ¡no hay pista más cercana!",
        "hintLands": "Pista: «%@» queda en el n.º %d — ¡más cálido!",
        "spellHint": "La palabra empieza por %@",
        "wickEgg": "¡Oye, de eso estoy hecho!",
        "eggHunch": "¿Hunch? Así me llamaba antes — buena memoria.",
        "eggCheat": "¿Hacer trampa? ¿Dónde está la gracia?",
        "plusCoins": "+%d monedas",
        "outOfFreeQuestions": "Sin preguntas gratis — cuesta %d monedas.",
        "keeperDidntRespond": "El Guardián no respondió — toca Reintentar.",
        "scoringUnavailable": "El diccionario de este idioma aún no se ha descargado — seguiré intentándolo. Conéctate a internet un momento y se arreglará solo.",
        "vocabularyReady": "Diccionario listo — ¡a jugar!",
        "scoringKeyboardHint": "¿Sigue sin descargarse? iOS obtiene el diccionario cuando tu dispositivo usa el idioma — añade el teclado de este idioma en Ajustes → General → Teclado y vuelve. Lo detectaré automáticamente.",
        "downloadDictionaryTitle": "Descargando diccionario…",
        "downloadDictionaryBlurb": "Una descarga rápida, solo una vez, para jugar en este idioma sin conexión. Tardará un momento.",
        "downloadDictionaryFailed": "No se pudo descargar ahora mismo — seguiré intentándolo, y puedes jugar con el diccionario integrado.",
        "cancelDownload": "Cancelar",
        "dictionaries": "Diccionarios sin conexión",
        "dictionariesBlurb": "Descarga el diccionario de un idioma para jugar sin conexión. Los idiomas también se descargan automáticamente la primera vez que los eliges.",
        "downloadAll": "Descargar todos los idiomas",
        "dictionaryReady": "Listo",
        "dictionaryDownload": "Descargar",
        // Settings extras
        "notifications": "Notificaciones",
        "about": "Acerca de",
        "privacyPolicy": "Política de privacidad",
        "languagePickHint": "Elige el idioma del juego",
        // How to play
        "meetKeeper": "Conoce al Guardián",
        "meetKeeperSub": "Custodia la palabra secreta y se calienta a medida que te acercas.",
        "letsPlay": "¡A jugar!",
        "howStep1Title": "Adivina por significado",
        "howStep1Detail": "Hay una palabra secreta. Escribe cualquier palabra y verás qué tan cerca está —por significado, no por ortografía.",
        "howStep2Title": "Caliente o frío",
        "howStep2Detail": "Los intentos más cercanos puntúan más alto y se vuelven al rojo vivo. Los lejanos quedan azul helado. La pantalla se calienta a medida que te acercas.",
        "howStep3Title": "Pregunta a Wick",
        "howStep3Detail": "¿Atascado? Hazle a Wick preguntas de sí/no como «¿Está vivo?» —funciona en todos los iPhone, responde con la verdad y nunca revela la palabra.",
        "howStep4Title": "Una palabra nueva cada día",
        "howStep4Detail": "Todos reciben la misma palabra cada día. Resuélvela, crea una racha y comparte tu resultado.",
        // Shop
        "getCoins": "Conseguir monedas",
        "yourBalance": "Tu saldo",
        "coinsAmount": "%d monedas",
        "loadingShop": "Cargando la tienda…",
        "shopUnavailable": "Tienda no disponible",
        "shopUnavailableDetail": "No se pudieron cargar los paquetes de monedas ahora. Revisa tu conexión e inténtalo de nuevo.",
        "coinsBuyBlurb": "Las monedas compran pistas y preguntas extra. Siempre puedes jugar el diario y ganar monedas gratis.",
    ]

    /// French. Language names arrive with their article ("l'anglais"), so
    /// sentences here are phrased to fit ("Apprendre l'anglais", "traduit vers
    /// l'anglais").
    static let fr: [String: String] = [
        // The Reveal (3.2)
        "revealFound": "%@ trouv\u{00E9} en %d",
        "revealCaption": "La distance au centre indique votre proximit\u{00E9} de sens ; les mots proches sont regroup\u{00E9}s.",
        "revealTheWord": "LE MOT",
        "revealSeeMap": "Voir la carte",
        "revealReplay": "Revoir la chasse",
        "revealMapA11y": "Carte s\u{00E9}mantique de vos essais.",
        "revealGuessA11y": "Essai %d, %@, %@",
        // Ghost Race (3.2)
        "ghostRival": "Fant\u{00F4}me",
        "ghostWaiting": "s\u{2019}\u{00E9}chauffe",
        "ghostFinished": "termin\u{00E9} en %@",
        "raceChallengeTitle": "Un ami vous a d\u{00E9}fi\u{00E9}",
        "raceChallengeBlurb": "Puzzle n\u{00B0} %d \u{2014} %d coups jou\u{00E9}s. Battez leur temps.",
        "raceChallengeBlurbPractice": "Un mot au hasard \u{2014} %d coups jou\u{00E9}s. Battez leur temps.",
        "raceStart": "Les d\u{00E9}fier",
        "raceDecline": "Jouer seul",
        "raceGo": "PARTEZ !",
        "raceAFriend": "D\u{00E9}fier un ami",
        "raceThemBack": "Les d\u{00E9}fier \u{00E0} leur tour",
        "raceShareSolved": "R\u{00E9}solu en %@ \u{2014} faites mieux.",
        "raceShareUnsolved": "Saurez-vous r\u{00E9}soudre celui-ci ?",
        "homeRaceSub": "Bats le temps d'un ami",
        "raceFriendBlurb": "Termine le mot du jour, puis envoie le lien. Ton ami affronte ton fantôme, coup par coup. Pas besoin de l'app.",
        "racePlayTodayFirst": "Joue le mot du jour",
        "raceSendYourRun": "Envoie ta course",
        "raceStrangerTitle": "Course en direct",
        "raceLiveDisclosure": "Les courses en direct envoient les mots que tu tapes au serveur de Wick (via Google Gemini) pour les noter. Un lien de course fantôme ne contient que ton rythme et ta chaleur, jamais tes mots.",
        "liveRematch": "Revanche",
        "liveScanCaption": "Ou scanne le code.",
        // Live multiplayer (3.0/3.1) — draft, needs fluent skim
        "liveJoin": "Rejoindre", "liveCancel": "Annuler", "liveDone": "Terminé", "liveClose": "Fermer", "liveLeave": "Quitter",
        "liveConnectionLost": "Connexion perdue", "liveTheWordWas": "Le mot était", "liveYourRound": "Ta manche",
        "liveInviteFriend": "Inviter un ami", "liveKeepGoing": "continue", "liveScoring": "calcul…",
        "liveYouGotItLower": "trouvé !", "liveSolvedExcl": "Résolu !",
        "liveRace": "Course", "liveRaceBlurb": "Vous devinez le même mot caché — le premier à trouver gagne.",
        "liveQuickMatch": "Partie rapide", "liveHaveACode": "TU AS UN CODE ?", "liveEnterIt": "saisis-le",
        "liveInviteHintRace": "Inviter crée un lien à envoyer. Partie rapide trouve n'importe qui (ou une flamme d'entraînement).",
        "liveFindingOpponent": "Recherche d'un adversaire…", "liveWaitingForFriend": "En attente de ton ami…",
        "livePracticeFlameSteps": "Une flamme de Wick intervient si personne n'est là.",
        "liveNextRaceIn": "La prochaine course commence dans",
        "liveShareInviteLink": "Partager le lien",
        "liveShareTapToJoin": "Envoie le lien — ton ami tape dessus pour rejoindre. Ou il peut saisir le code.",
        "liveTheyJoinByLink": "Ils rejoignent en touchant ton lien ou en saisissant le code.",
        "liveLiveRace": "Course en direct", "livePlayAgain": "Rejouer", "liveTryAgain": "Réessayer",
        "liveGuessOrAsk": "Devine un mot, ou demande à Wick…",
        "liveGuessOrAskHint": "Un seul mot est une proposition. Ajoute « ? » ou écris une phrase pour demander à Wick.",
        "liveWelcome": "Salut, je suis %@. Je garde un mot secret — propose ce que tu veux et je te dirai à quel point tu es proche par le sens.",
        "liveLiveOpponent": "Adversaire en direct", "livePracticeFlame": "Flamme d'entraînement",
        "liveGhost": "Fantôme d'une partie passée", "liveOpponent": "Adversaire", "liveReconnecting": "reconnexion…",
        "liveGuessesCount": "%d essais",
        "liveGoodStart": "Bon début !", "liveClosestYet": "Au plus près", "liveFurther": "Plus loin que ton meilleur",
        "liveResult": "Résultat", "liveYouWin": "Tu gagnes !", "liveYouLost": "Tu as perdu", "liveDraw": "Égalité",
        "liveFirstToWord": "Premier sur le mot.", "liveOppFirst": "Ton adversaire est arrivé en premier.",
        "liveTimeUpWarmest": "Temps écoulé — décidé par la proposition la plus chaude.",
        "liveOppLeft": "Ton adversaire est parti.", "liveYouLeft": "Tu as quitté la partie.",
        "liveBothDropped": "Aucun résultat — les deux joueurs ont abandonné.",
        "liveOppLeftHangTight": "Ton adversaire est parti — patiente.",
        "liveNotAWord": "Ce n'est pas un mot que je connais — essaie-en un autre.",
        "liveInviteExpired": "Cette invitation a expiré — demande un nouveau lien à ton ami.",
        "liveShareMsgRace": "Fais la course avec moi sur Wick !",
        // Header
        "dailyTitle": "N° %d",
        "practice": "Entraînement",
        "archive": "Énigmes passées",
        "archiveEmpty": "Pas encore d'énigmes passées. Reviens demain !",
        "archiveSolvedToast": "Bravo — énigme passée résolue !",
        "todaysPuzzle": "Énigme du jour",
        "tier": "Niveau %d",
        // Welcome / hero
        "welcome": "Salut, je suis %@. Je garde un mot secret : propose n'importe quel mot et je te dirai à quel point tu es proche par le sens.",
        "notInVocabulary": "absent du vocabulaire",
        "keepGoing": "continue",
        // Trajectory
        "firstGuess": "Bon début !",
        "heat.Solved!": "Trouvé !",
        "heat.Boiling": "Brûlant",
        "heat.Hot": "Chaud",
        "heat.Warm": "Tiède",
        "heat.Cool": "Frais",
        "heat.Cold": "Froid",
        "heat.Freezing": "Glacial",
        "nudgeSoClose": "Si près que je le sens !",
        "nudgeCircling": "Oh, tu tournes autour…",
        "nudgeStuck": "Quelques essais froids de suite. Bloqué ? Pose-moi une question — à quoi ça sert, ou où on le trouve.",
        "coachNotAWord": "Je ne connais pas celui-là — seulement des mots simples et courants. Essaie autre chose.",
        "coachFirstCold": "Froid ne veut pas dire mauvais mot — ça veut dire mauvais sujet. Je note le sens, pas l'orthographe. Essaie quelque chose d'un domaine totalement différent.",
        "coachFirstWarm": "Bien — c'est le bon quartier. Maintenant sois plus précis dans cette direction.",
        "coachTriangulate": "Toujours rien de chaud. Élargis au lieu de creuser : un animal, une émotion, un lieu, un outil. Dès que ça chauffe, suis la piste.",
        "warmestUp": "Au plus près · %d de mieux",
        "warmest": "Au plus près jusqu'ici",
        "colder": "Plus loin que ton meilleur essai",
        // Input
        "guessPlaceholder": "Propose un mot…",
        "askKeeper": "Interroge le Gardien",
        "hint": "Indice",
        "guessOrAskPlaceholder": "Propose un mot, ou demande à Wick…",
        "guessOrAskHint": "Un mot seul est un essai. Ajoute « ? » ou écris une phrase pour interroger Wick.",
        "roundLog": "Ta manche",
        "needIdeas": "Des idées de questions pour Wick ?",
        "a11ySend": "Envoyer",
        "a11yShop": "Ouvrir la boutique de pièces",
        "a11yAskThis": "Pose cette question à Wick",
        "waysTitle": "Deux façons de jouer",
        "wayGuessTitle": "Écris un mot",
        "wayGuessBody": "Je te dirai à quel point il est proche par le sens.",
        "wayAskTitle": "Ou pose-moi une question",
        "wayAskBody": "Réponses oui / non, toujours gratuites.",
        "offerStuck": "Plusieurs essais froids d'affilée. Je réduis le champ ?",
        "offerCold": "Rien de chaud pour l'instant. Essaie de me demander ça —",
        "offerRoutine": "Tu peux m'interroger, tu sais. Commence par là :",
        "offerAskElse": "Autre chose",
        "offerNotNow": "Pas maintenant",
        "sortRecent": "Récents",
        "sortClosest": "Plus chauds",
        // Learn mode
        "learnTitle": "Mode apprentissage",
        "learnToggle": "Apprendre %@",
        "learnBlurb": "Affiche chaque essai traduit vers %@ (%@ → %@) pendant que tu joues, pour retenir du vocabulaire.",
        // Solved / revealed
        "solvedTitle": "Trouvé !",
        "solvedIn.one": "« %@ » en %d essai",
        "solvedIn.other": "« %@ » en %d essais",
        "streakDays": "Série de %d jours !",
        "shareResult": "Partager le résultat",
        "shareSolvedIn": "résolu en %d",
        "shareQuestions.one": "%d question",
        "shareQuestions.other": "%d questions",
        "shareHints.one": "%d indice",
        "shareHints.other": "%d indices",
        "shareTagline": "Wick · devine par le sens",
        "playRandom": "Jouer un mot au hasard",
        "easy": "Facile",
        "medium": "Moyen",
        "hard": "Difficile",
        "theWordWas": "Le mot était",
        // Give up
        "giveUpTitle": "Révéler la réponse ?",
        "giveUp": "Abandonner",
        "keepTrying": "Continuer",
        "giveUpMessage": "Tu verras le mot et la manche se terminera.",
        // Guess list
        "guessesCount": "Essais · %d",
        // Ask the Keeper
        "askTitle": "Interroge le Gardien",
        "done": "OK",
        "duel": "Duel",
        "soundHapticsTitle": "Son et vibrations",
        "hapticsToggle": "Vibrations",
        "soundToggle": "Son",
        "duelSolvedToast": "Duel résolu ! Partage ton résultat.",
        "home": "Accueil",
        "pastPuzzles": "Anciennes",
        "chooseDifficulty": "Choisis la difficulté",
        "homeGuessWord": "Devine le mot secret",
        "homeReplayAnyDay": "Rejoue n'importe quel jour",
        "homePlayAnytime": "Joue quand tu veux",
        "homeDressUpWick": "Habille Wick",
        "duelCreate": "Créer un duel",
        "duelRace": "Course",
        "duelRaceBlurb": "Wick choisit un mot secret — vous jouez tous deux à l'aveugle, puis comparez.",
        "duelPlayNow": "Jouer",
        "duelYourCode": "Ton code de duel",
        "duelShareCode": "Partager",
        "duelPaste": "Coller le code",
        "duelJoin": "Rejoindre un duel",
        "duelJoinPlaceholder": "Colle un code…",
        "duelGo": "OK",
        "duelInvalid": "Ce code n'est pas valide.",
        "duelChooseWord": "Choisis un mot",
        "duelHeadToHead": "Face à face",
        "duelWin": "Tu gagnes !",
        "duelLose": "Ils gagnent !",
        "duelTie": "Égalité !",
        "duelYou": "Toi",
        "duelThem": "Eux",
        "duelGaveUp": "Abandon",
        "duelNeedYours": "Joue ce duel pour comparer en face à face.",
        "duelCopied": "Copié !",
        "duelCopy": "Copier",
        "duelResultShare": "Partager ton résultat",
        "duelResultMsg": "Mon résultat de duel Wick : %@ — colle-le dans le duel pour comparer.",
        "duelYouChose": "Tu as choisi « %@ ». Envoie le code à un ami.",
        "duelShareMsg": "Peux-tu me battre à Wick ?",
        "duelSolvedIn": "Résolu en %d",
        "wardrobe": "Garde-robe de Wick",
        "wardrobeBlurb": "Dépense des pièces pour habiller Wick. Juste pour le plaisir — ça ne change pas le jeu.",
        "equip": "Porter",
        "equipped": "Porté",
        "take_off": "Retirer",
        "buy": "Acheter",
        "owned": "Acquis",
        "notEnoughCoins": "Pas assez de pièces",
        "slot_hat": "Chapeaux",
        "slot_eyes": "Yeux",
        "slot_face": "Visage",
        "slot_mouth": "Bouche",
        "slot_neck": "Cou",
        "acc_tophat": "Haut-de-forme",
        "acc_tongue": "Langue tirée",
        "acc_googly": "Yeux mobiles",
        "acc_hearts": "Yeux en cœur",
        "acc_stars": "Yeux étoilés",
        "acc_party": "Chapeau de fête",
        "acc_wizard": "Chapeau de magicien",
        "acc_crown": "Couronne",
        "acc_monocle": "Monocle",
        "acc_glasses": "Lunettes",
        "acc_bowtie": "Nœud papillon",
        "acc_tie": "Cravate",
        "askTab": "Demander",
        "guessTab": "Deviner",
        "suggestedQuestions": "Questions suggérées",
        "dreamingClue": "%@ imagine un indice…",
        "askIntro": "Pose des questions comme « Est-ce vivant ? », « Plus grand qu'une voiture ? », « Trouvé à l'intérieur ? ». Le Gardien répond honnêtement mais ne révélera pas le mot.",
        "keeperNoRespond": "Le Gardien n'a pas répondu",
        "retry": "Réessayer",
        "askPlaceholder": "Demande ce que tu veux à Wick…",
        "questionsFree": "Les questions sont gratuites — demande ce que tu veux à Wick.",
        "notAKnownWord": "mot inconnu",
        "offlineBanner": "Wick fonctionne hors ligne sur cet iPhone. Touche une question suggérée pour une réponse exacte, ou écris un simple oui/non comme « Est-ce vivant ? ». Pas besoin d'Apple Intelligence.",
        "offlineFootnote": "Mode hors ligne : Wick répond à l'essentiel sur l'appareil. Touche une suggestion pour une réponse exacte.",
        "freeQuestionsLeft.one": "%d question gratuite",
        "freeQuestionsLeft.other": "%d questions gratuites",
        "questionCost": "Chaque question coûte %d pièces (tu en as %d)",
        "outOfCoins": "Plus de pièces — continue à deviner gratuitement, ou résous des manches pour en gagner.",
        // Menu / Settings
        "howToPlay": "Comment jouer",
        "settings": "Réglages",
        "language": "Langue",
        "languageFooter": "Définit la langue du mot du jour, de tes essais et de Wick. En changer relance une manche.",
        // Stats
        "yourStats": "Tes statistiques",
        "currentStreak": "Série en cours",
        "bestStreak": "Meilleure série",
        "wordsSolved": "Mots trouvés",
        "avgGuesses": "Essais moy.",
        "fewestGuesses": "Moins d'essais",
        "coins": "Pièces",
        "achievements": "Succès",
        "leaderboards": "Classements",
        "dailyReminder": "Rappel quotidien",
        "time": "Heure",
        "reminderBlurb": "Un petit signe quand le mot du jour est prêt.",
        "notifDailyTitle": "Le mot du jour est prêt",
        "notifDailyBody": "Wick en garde un nouveau. Tu penses le trouver ?",
        "notifStreakTitle": "Ta flamme va s'éteindre",
        "notifStreakBody": "%d jours d'affilée — le mot du jour n'est toujours pas trouvé.",
        // Toasts
        "dailyBonus": "Bonus quotidien · +%d pièces",
        "countsAsAlready": "« %@ » compte comme « %@ » — déjà essayé.",
        "alreadyGuessed": "Déjà essayé « %@ ».",
        "normalizedTo": "« %@ » → « %@ »",
        "didYouMean": "« %@ » n'est pas dans mon vocabulaire — tu voulais dire « %@ » ?",
        "notInVocabToast": "« %@ » n'est pas dans mon vocabulaire — essaie un autre mot.",
        "solvedBadge": "Trouvé ! +%d · 🏅 %@",
        "solvedCoins": "Trouvé ! +%d pièces",
        "theWordWasToast": "Le mot était « %@ »",
        "hintWarmingUp": "L'indice se prépare — réessaie dans une seconde.",
        "hintsCost": "Plus d'indices gratuits aujourd'hui. Ils coûtent %d pièces maintenant.",
        "hintFreeLeft": "Indice (%d gratuits aujourd'hui)", "hintCoinPrice": "Indice (%d pièces)",
        "topTakeIt": "Tu es dans le top %d — à toi de jouer ! 🔥",
        "noCloserHint": "Tu te rapproches — pas d'indice plus proche à donner !",
        "hintLands": "Indice : « %@ » arrive au n° %d — plus chaud !",
        "spellHint": "Le mot commence par %@",
        "wickEgg": "Hé — c'est de ça que je suis fait !",
        "eggHunch": "Hunch ? C'était mon ancien nom — bonne mémoire.",
        "eggCheat": "Tricher ? Où est le plaisir ?",
        "plusCoins": "+%d pièces",
        "outOfFreeQuestions": "Plus de questions gratuites — coûte %d pièces.",
        "keeperDidntRespond": "Le Gardien n'a pas répondu — touche Réessayer.",
        "scoringUnavailable": "Le dictionnaire de cette langue n'est pas encore téléchargé — je continue d'essayer. Connecte-toi à internet un instant et ça se réglera tout seul.",
        "vocabularyReady": "Dictionnaire prêt — à toi de jouer !",
        "scoringKeyboardHint": "Toujours rien ? iOS télécharge le dictionnaire quand ton appareil utilise la langue — ajoute le clavier de cette langue dans Réglages → Général → Clavier, puis reviens. Je le détecterai automatiquement.",
        "downloadDictionaryTitle": "Téléchargement du dictionnaire…",
        "downloadDictionaryBlurb": "Un petit téléchargement, une seule fois, pour jouer dans cette langue hors ligne. Ça ne prend qu'un instant.",
        "downloadDictionaryFailed": "Téléchargement impossible pour le moment — je continue d'essayer, et tu peux jouer avec le dictionnaire intégré.",
        "cancelDownload": "Annuler",
        "dictionaries": "Dictionnaires hors ligne",
        "dictionariesBlurb": "Télécharge le dictionnaire d'une langue pour jouer hors ligne. Les langues se téléchargent aussi automatiquement la première fois que tu les choisis.",
        "downloadAll": "Télécharger toutes les langues",
        "dictionaryReady": "Prêt",
        "dictionaryDownload": "Télécharger",
        // Settings extras
        "notifications": "Notifications",
        "about": "À propos",
        "privacyPolicy": "Politique de confidentialité",
        "languagePickHint": "Choisis la langue du jeu",
        // How to play
        "meetKeeper": "Voici le Gardien",
        "meetKeeperSub": "Il garde le mot secret — et se réchauffe quand tu approches.",
        "letsPlay": "C'est parti !",
        "howStep1Title": "Devine par le sens",
        "howStep1Detail": "Il y a un mot secret. Écris n'importe quel mot et tu verras à quel point il est proche — par le sens, pas l'orthographe.",
        "howStep2Title": "Chaud ou froid",
        "howStep2Detail": "Les essais proches marquent plus et virent au rouge brûlant. Les lointains restent bleu glacé. L'écran se réchauffe quand tu approches.",
        "howStep3Title": "Demande à Wick",
        "howStep3Detail": "Bloqué ? Pose à Wick des questions oui/non comme « Est-ce vivant ? » — ça marche sur tous les iPhone, il répond honnêtement et ne révèle jamais le mot.",
        "howStep4Title": "Un mot nouveau chaque jour",
        "howStep4Detail": "Tout le monde reçoit le même mot chaque jour. Trouve-le, bâtis une série et partage ton résultat.",
        // Shop
        "getCoins": "Obtenir des pièces",
        "yourBalance": "Ton solde",
        "coinsAmount": "%d pièces",
        "loadingShop": "Chargement de la boutique…",
        "shopUnavailable": "Boutique indisponible",
        "shopUnavailableDetail": "Impossible de charger les packs de pièces. Vérifie ta connexion et réessaie.",
        "coinsBuyBlurb": "Les pièces offrent des indices et des questions en plus. Le mot du jour reste gratuit, et tu gagnes des pièces en jouant.",
    ]

    /// Italian. Language names arrive with their article ("l'inglese"), so
    /// sentences here are phrased to fit ("Impara l'inglese", "tradotto verso
    /// l'inglese").
    static let it: [String: String] = [
        // The Reveal (3.2)
        "revealFound": "Hai trovato %@ in %d",
        "revealCaption": "La distanza dal centro indica quanto eri vicino nel significato; le parole simili stanno vicine.",
        "revealTheWord": "LA PAROLA",
        "revealSeeMap": "Vedi la mappa",
        "revealReplay": "Rivedi la caccia",
        "revealMapA11y": "Mappa semantica dei tuoi tentativi.",
        "revealGuessA11y": "Tentativo %d, %@, %@",
        // Ghost Race (3.2)
        "ghostRival": "Fantasma",
        "ghostWaiting": "si scalda",
        "ghostFinished": "finito in %@",
        "raceChallengeTitle": "Un amico ti ha sfidato",
        "raceChallengeBlurb": "Puzzle n. %d \u{2014} %d mosse. Batti il loro tempo.",
        "raceChallengeBlurbPractice": "Una parola a caso \u{2014} %d mosse. Batti il loro tempo.",
        "raceStart": "Sfidali",
        "raceDecline": "Gioco da solo",
        "raceGo": "VIA!",
        "raceAFriend": "Sfida un amico",
        "raceThemBack": "Sfidali di nuovo",
        "raceShareSolved": "L\u{2019}ho risolto in %@ \u{2014} battimi.",
        "raceShareUnsolved": "Riesci a risolvere questo?",
        "homeRaceSub": "Batti il tempo di un amico",
        "raceFriendBlurb": "Finisci la parola di oggi, poi invia il link. Il tuo amico sfida il tuo fantasma, mossa dopo mossa. Non serve l'app.",
        "racePlayTodayFirst": "Gioca la parola di oggi",
        "raceSendYourRun": "Invia la tua gara",
        "raceStrangerTitle": "Gara dal vivo",
        "raceLiveDisclosure": "Le gare dal vivo inviano le parole che scrivi al server di Wick (tramite Google Gemini) per valutarle. Un link di gara fantasma contiene solo i tuoi tempi e il tuo calore, mai le tue parole.",
        "liveRematch": "Rivincita",
        "liveScanCaption": "Oppure scansiona il codice.",
        // Live multiplayer (3.0/3.1) — draft, needs fluent skim
        "liveJoin": "Unisciti", "liveCancel": "Annulla", "liveDone": "Fatto", "liveClose": "Chiudi", "liveLeave": "Esci",
        "liveConnectionLost": "Connessione persa", "liveTheWordWas": "La parola era", "liveYourRound": "Il tuo turno",
        "liveInviteFriend": "Invita un amico", "liveKeepGoing": "continua", "liveScoring": "calcolo…",
        "liveYouGotItLower": "trovato!", "liveSolvedExcl": "Risolto!",
        "liveRace": "Gara", "liveRaceBlurb": "Indovinate entrambi la stessa parola nascosta: vince chi la risolve per primo.",
        "liveQuickMatch": "Partita rapida", "liveHaveACode": "HAI UN CODICE?", "liveEnterIt": "inseriscilo",
        "liveInviteHintRace": "Invita crea un link da inviare. Partita rapida trova chiunque (o una fiamma di pratica).",
        "liveFindingOpponent": "Cerco un avversario…", "liveWaitingForFriend": "In attesa del tuo amico…",
        "livePracticeFlameSteps": "Una fiamma di Wick interviene se non c'è nessuno.",
        "liveNextRaceIn": "La prossima gara inizia tra",
        "liveShareInviteLink": "Condividi il link",
        "liveShareTapToJoin": "Invia il link: il tuo amico lo tocca per unirsi. Oppure può digitare il codice.",
        "liveTheyJoinByLink": "Si uniscono toccando il tuo link o inserendo il codice.",
        "liveLiveRace": "Gara dal vivo", "livePlayAgain": "Gioca ancora", "liveTryAgain": "Riprova",
        "liveGuessOrAsk": "Indovina una parola o chiedi a Wick…",
        "liveGuessOrAskHint": "Una sola parola è un tentativo. Aggiungi “?” o scrivi una frase per chiedere a Wick.",
        "liveWelcome": "Ciao, sono %@. Custodisco una parola segreta: prova qualsiasi cosa e ti dirò quanto sei vicino per significato.",
        "liveLiveOpponent": "Avversario dal vivo", "livePracticeFlame": "Fiamma di pratica",
        "liveGhost": "Fantasma di una partita passata", "liveOpponent": "Avversario", "liveReconnecting": "riconnessione…",
        "liveGuessesCount": "%d tentativi",
        "liveGoodStart": "Buon inizio!", "liveClosestYet": "Il più vicino finora", "liveFurther": "Più lontano del tuo migliore",
        "liveResult": "Risultato", "liveYouWin": "Hai vinto!", "liveYouLost": "Hai perso", "liveDraw": "Pareggio",
        "liveFirstToWord": "Primo alla parola.", "liveOppFirst": "Il tuo avversario è arrivato prima.",
        "liveTimeUpWarmest": "Tempo scaduto: decide il tentativo più caldo.",
        "liveOppLeft": "Il tuo avversario se n'è andato.", "liveYouLeft": "Hai lasciato la partita.",
        "liveBothDropped": "Nessun risultato: entrambi i giocatori si sono disconnessi.",
        "liveOppLeftHangTight": "Il tuo avversario se n'è andato: aspetta.",
        "liveNotAWord": "Non è una parola che conosco: provane un'altra.",
        "liveInviteExpired": "Quell'invito è scaduto: chiedi al tuo amico un nuovo link.",
        "liveShareMsgRace": "Sfidami in una gara su Wick!",
        // Header
        "dailyTitle": "N. %d",
        "practice": "Allenamento",
        "archive": "Puzzle passati",
        "archiveEmpty": "Ancora nessun puzzle passato. Torna domani!",
        "archiveSolvedToast": "Bravo! Hai risolto un puzzle passato.",
        "todaysPuzzle": "Puzzle di oggi",
        "tier": "Livello %d",
        // Welcome / hero
        "welcome": "Ciao, sono %@. Custodisco una parola segreta: prova una parola qualsiasi e ti dirò quanto sei vicino per significato.",
        "notInVocabulary": "non nel vocabolario",
        "keepGoing": "continua",
        // Trajectory
        "firstGuess": "Buon inizio!",
        "heat.Solved!": "Risolto!",
        "heat.Boiling": "Bollente",
        "heat.Hot": "Caldo",
        "heat.Warm": "Tiepido",
        "heat.Cool": "Fresco",
        "heat.Cold": "Freddo",
        "heat.Freezing": "Gelido",
        "nudgeSoClose": "Così vicino che lo sento!",
        "nudgeCircling": "Ooh, ci stai girando intorno…",
        "nudgeStuck": "Qualche tentativo freddo di fila. Bloccato? Chiedimi qualcosa — a cosa serve, o dove si trova.",
        "coachNotAWord": "Questa non la conosco — conosco solo parole singole di uso comune. Provane un'altra.",
        "coachFirstCold": "Freddo non vuol dire parola sbagliata — vuol dire argomento sbagliato. Do il punteggio al significato, non alle lettere. Prova qualcosa di un tema completamente diverso.",
        "coachFirstWarm": "Bene — questo è il quartiere giusto. Ora vai più nello specifico in quella direzione.",
        "coachTriangulate": "Ancora niente di caldo. Allargati invece di insistere: un animale, un'emozione, un luogo, un attrezzo. Appena qualcosa scalda, seguila.",
        "warmestUp": "Il più vicino · %d in meglio",
        "warmest": "Il più vicino finora",
        "colder": "Più lontano del tuo migliore",
        // Input
        "guessPlaceholder": "Prova una parola…",
        "askKeeper": "Chiedi al Custode",
        "hint": "Indizio",
        "guessOrAskPlaceholder": "Prova una parola, o chiedi a Wick…",
        "guessOrAskHint": "Una parola da sola è un tentativo. Aggiungi «?» o scrivi una frase per chiedere a Wick.",
        "roundLog": "Il tuo round",
        "needIdeas": "Idee per domande a Wick?",
        "a11ySend": "Invia",
        "a11yShop": "Apri il negozio di monete",
        "a11yAskThis": "Fa questa domanda a Wick",
        "waysTitle": "Due modi di giocare",
        "wayGuessTitle": "Scrivi una parola",
        "wayGuessBody": "Ti dirò quanto è vicina per significato.",
        "wayAskTitle": "Oppure chiedimi qualsiasi cosa",
        "wayAskBody": "Risposte sì / no, sempre gratis.",
        "offerStuck": "Diversi tentativi freddi di fila. Vuoi che restringa il campo?",
        "offerCold": "Ancora niente di caldo. Prova a chiedermi questo —",
        "offerRoutine": "Puoi interrogarmi, sai. Inizia da qui:",
        "offerAskElse": "Qualcos'altro",
        "offerNotNow": "Non ora",
        "sortRecent": "Recenti",
        "sortClosest": "Più caldi",
        // Learn mode
        "learnTitle": "Modalità apprendimento",
        "learnToggle": "Impara %@",
        "learnBlurb": "Mostra ogni tentativo tradotto verso %@ (%@ → %@) mentre giochi, così impari parole nuove.",
        // Solved / revealed
        "solvedTitle": "Risolto!",
        "solvedIn.one": "«%@» in %d tentativo",
        "solvedIn.other": "«%@» in %d tentativi",
        "streakDays": "Serie di %d giorni!",
        "shareResult": "Condividi il risultato",
        "shareSolvedIn": "risolto in %d",
        "shareQuestions.one": "%d domanda",
        "shareQuestions.other": "%d domande",
        "shareHints.one": "%d indizio",
        "shareHints.other": "%d indizi",
        "shareTagline": "Wick · indovina per significato",
        "playRandom": "Gioca una parola a caso",
        "easy": "Facile",
        "medium": "Media",
        "hard": "Difficile",
        "theWordWas": "La parola era",
        // Give up
        "giveUpTitle": "Rivelare la risposta?",
        "giveUp": "Arrenditi",
        "keepTrying": "Continua a provare",
        "giveUpMessage": "Vedrai la parola e il round finirà.",
        // Guess list
        "guessesCount": "Tentativi · %d",
        // Ask the Keeper
        "askTitle": "Chiedi al Custode",
        "done": "Fine",
        "duel": "Duello",
        "soundHapticsTitle": "Suono e vibrazione",
        "hapticsToggle": "Vibrazione",
        "soundToggle": "Suono",
        "duelSolvedToast": "Duello risolto! Condividi il tuo risultato.",
        "home": "Home",
        "pastPuzzles": "Precedenti",
        "chooseDifficulty": "Scegli la difficoltà",
        "homeGuessWord": "Indovina la parola segreta",
        "homeReplayAnyDay": "Rigioca un giorno qualsiasi",
        "homePlayAnytime": "Gioca quando vuoi",
        "homeDressUpWick": "Vesti Wick",
        "duelCreate": "Crea un duello",
        "duelRace": "Gara",
        "duelRaceBlurb": "Wick sceglie una parola segreta — giocate entrambi alla cieca e confrontate.",
        "duelPlayNow": "Gioca ora",
        "duelYourCode": "Il tuo codice duello",
        "duelShareCode": "Condividi",
        "duelPaste": "Incolla codice",
        "duelJoin": "Unisciti a un duello",
        "duelJoinPlaceholder": "Incolla un codice…",
        "duelGo": "Vai",
        "duelInvalid": "Codice non valido.",
        "duelChooseWord": "Scegli una parola",
        "duelHeadToHead": "Testa a testa",
        "duelWin": "Vinci tu!",
        "duelLose": "Vincono loro!",
        "duelTie": "Pareggio!",
        "duelYou": "Tu",
        "duelThem": "Loro",
        "duelGaveUp": "Si è arreso",
        "duelNeedYours": "Gioca questo duello per il testa a testa.",
        "duelCopied": "Copiato!",
        "duelCopy": "Copia",
        "duelResultShare": "Condividi il risultato",
        "duelResultMsg": "Il mio risultato del duello Wick: %@ — incollalo nel duello per confrontare.",
        "duelYouChose": "Hai scelto «%@». Invia il codice a un amico.",
        "duelShareMsg": "Riesci a battermi a Wick?",
        "duelSolvedIn": "Risolto in %d",
        "wardrobe": "Guardaroba di Wick",
        "wardrobeBlurb": "Spendi monete per vestire Wick. Solo per gioco — non cambia la partita.",
        "equip": "Indossa",
        "equipped": "Indossato",
        "take_off": "Togli",
        "buy": "Compra",
        "owned": "Posseduto",
        "notEnoughCoins": "Monete insufficienti",
        "slot_hat": "Cappelli",
        "slot_eyes": "Occhi",
        "slot_face": "Viso",
        "slot_mouth": "Bocca",
        "slot_neck": "Collo",
        "acc_tophat": "Cilindro",
        "acc_tongue": "Linguaccia",
        "acc_googly": "Occhi finti",
        "acc_hearts": "Occhi a cuore",
        "acc_stars": "Occhi a stella",
        "acc_party": "Cappellino da festa",
        "acc_wizard": "Cappello da mago",
        "acc_crown": "Corona",
        "acc_monocle": "Monocolo",
        "acc_glasses": "Occhiali",
        "acc_bowtie": "Papillon",
        "acc_tie": "Cravatta",
        "askTab": "Chiedi",
        "guessTab": "Indovina",
        "suggestedQuestions": "Domande suggerite",
        "dreamingClue": "%@ sta pensando a un indizio…",
        "askIntro": "Chiedi cose come «È vivo?», «Più grande di una macchina?», «Si trova in casa?». Il Custode risponde sinceramente ma non rivelerà la parola.",
        "keeperNoRespond": "Il Custode non ha risposto",
        "retry": "Riprova",
        "askPlaceholder": "Chiedi qualsiasi cosa a Wick…",
        "questionsFree": "Le domande sono gratis — chiedi qualsiasi cosa a Wick.",
        "notAKnownWord": "parola sconosciuta",
        "offlineBanner": "Wick funziona offline su questo iPhone. Tocca una domanda suggerita per una risposta esatta, o scrivi un semplice sì/no come «È vivo?». Non serve Apple Intelligence.",
        "offlineFootnote": "Modalità offline: Wick risponde all'essenziale sul dispositivo. Tocca un suggerimento per una risposta esatta.",
        "freeQuestionsLeft.one": "%d domanda gratis",
        "freeQuestionsLeft.other": "%d domande gratis",
        "questionCost": "Ogni domanda costa %d monete (ne hai %d)",
        "outOfCoins": "Monete finite — continua a indovinare gratis, o risolvi round per guadagnarne.",
        // Menu / Settings
        "howToPlay": "Come si gioca",
        "settings": "Impostazioni",
        "language": "Lingua",
        "languageFooter": "Imposta la lingua della parola del giorno, dei tuoi tentativi e di Wick. Cambiarla avvia un nuovo round.",
        // Stats
        "yourStats": "Le tue statistiche",
        "currentStreak": "Serie attuale",
        "bestStreak": "Serie migliore",
        "wordsSolved": "Parole risolte",
        "avgGuesses": "Tentativi medi",
        "fewestGuesses": "Meno tentativi",
        "coins": "Monete",
        "achievements": "Obiettivi",
        "leaderboards": "Classifiche",
        "dailyReminder": "Promemoria giornaliero",
        "time": "Ora",
        "reminderBlurb": "Un gentile avviso quando la parola del giorno è pronta.",
        "notifDailyTitle": "La parola di oggi è pronta",
        "notifDailyBody": "Wick ne custodisce una nuova. Pensi di indovinarla?",
        "notifStreakTitle": "La tua fiamma sta per spegnersi",
        "notifStreakBody": "%d giorni di fila — la parola di oggi è ancora irrisolta.",
        // Toasts
        "dailyBonus": "Bonus giornaliero · +%d monete",
        "countsAsAlready": "«%@» conta come «%@» — già provata.",
        "alreadyGuessed": "Hai già provato «%@».",
        "normalizedTo": "«%@» → «%@»",
        "didYouMean": "«%@» non è nel mio vocabolario — intendevi «%@»?",
        "notInVocabToast": "«%@» non è nel mio vocabolario — prova un'altra parola.",
        "solvedBadge": "Risolto! +%d · 🏅 %@",
        "solvedCoins": "Risolto! +%d monete",
        "theWordWasToast": "La parola era «%@»",
        "hintWarmingUp": "L'indizio si sta preparando — riprova tra un secondo.",
        "hintsCost": "Gli indizi gratis di oggi sono finiti. Ora costano %d monete.",
        "hintFreeLeft": "Indizio (%d gratis oggi)", "hintCoinPrice": "Indizio (%d monete)",
        "topTakeIt": "Sei tra i primi %d — ce la puoi fare! 🔥",
        "noCloserHint": "Ti stai avvicinando — nessun indizio più vicino da dare!",
        "hintLands": "Indizio: «%@» arriva al n. %d — più caldo!",
        "spellHint": "La parola inizia con %@",
        "wickEgg": "Ehi — è di questo che sono fatto!",
        "eggHunch": "Hunch? Era il mio vecchio nome — che memoria.",
        "eggCheat": "Barare? Che gusto c'è?",
        "plusCoins": "+%d monete",
        "outOfFreeQuestions": "Domande gratis finite — costa %d monete.",
        "keeperDidntRespond": "Il Custode non ha risposto — tocca Riprova.",
        "scoringUnavailable": "Il dizionario di questa lingua non è ancora scaricato — continuo a provare. Connettiti a internet un momento e si sistemerà da solo.",
        "vocabularyReady": "Dizionario pronto — si gioca!",
        "scoringKeyboardHint": "Ancora niente? iOS scarica il dizionario quando il tuo dispositivo usa la lingua — aggiungi la tastiera di questa lingua in Impostazioni → Generali → Tastiera e torna qui. La rileverò automaticamente.",
        "downloadDictionaryTitle": "Download del dizionario…",
        "downloadDictionaryBlurb": "Un rapido download, una volta sola, per giocare in questa lingua offline. Ci vuole solo un momento.",
        "downloadDictionaryFailed": "Non è stato possibile scaricare ora — continuo a provare, e puoi giocare con il dizionario integrato.",
        "cancelDownload": "Annulla",
        "dictionaries": "Dizionari offline",
        "dictionariesBlurb": "Scarica il dizionario di una lingua per giocare offline. Le lingue si scaricano anche automaticamente la prima volta che le scegli.",
        "downloadAll": "Scarica tutte le lingue",
        "dictionaryReady": "Pronto",
        "dictionaryDownload": "Scarica",
        // Settings extras
        "notifications": "Notifiche",
        "about": "Informazioni",
        "privacyPolicy": "Informativa sulla privacy",
        "languagePickHint": "Scegli la lingua del gioco",
        // How to play
        "meetKeeper": "Ecco il Custode",
        "meetKeeperSub": "Custodisce la parola segreta — e si scalda quando ti avvicini.",
        "letsPlay": "Giochiamo!",
        "howStep1Title": "Indovina per significato",
        "howStep1Detail": "C'è una parola segreta. Scrivi una parola qualsiasi e vedrai quanto è vicina — per significato, non per ortografia.",
        "howStep2Title": "Caldo o freddo",
        "howStep2Detail": "I tentativi più vicini valgono di più e diventano rosso fuoco. Quelli lontani restano blu ghiaccio. Lo schermo si scalda mentre ti avvicini.",
        "howStep3Title": "Chiedi a Wick",
        "howStep3Detail": "Bloccato? Fai a Wick domande sì/no come «È vivo?» — funziona su ogni iPhone, risponde sinceramente e non rivela mai la parola.",
        "howStep4Title": "Una parola nuova ogni giorno",
        "howStep4Detail": "Tutti ricevono la stessa parola ogni giorno. Risolvila, costruisci una serie e condividi il risultato.",
        // Shop
        "getCoins": "Ottieni monete",
        "yourBalance": "Il tuo saldo",
        "coinsAmount": "%d monete",
        "loadingShop": "Caricamento del negozio…",
        "shopUnavailable": "Negozio non disponibile",
        "shopUnavailableDetail": "Impossibile caricare i pacchetti di monete. Controlla la connessione e riprova.",
        "coinsBuyBlurb": "Le monete danno indizi e domande extra. La parola del giorno resta gratis, e guadagni monete giocando.",
    ]

    /// German. Language names arrive bare ("Englisch"); the learn strings put
    /// the verb last ("Englisch lernen"), as German wants.
    static let de: [String: String] = [
        // The Reveal (3.2)
        "revealFound": "%@ in %d gefunden",
        "revealCaption": "Der Abstand zur Mitte zeigt, wie nah du der Bedeutung warst; \u{00E4}hnliche W\u{00F6}rter liegen beieinander.",
        "revealTheWord": "DAS WORT",
        "revealSeeMap": "Karte ansehen",
        "revealReplay": "Jagd erneut abspielen",
        "revealMapA11y": "Semantische Karte deiner Versuche.",
        "revealGuessA11y": "Versuch %d, %@, %@",
        // Ghost Race (3.2)
        "ghostRival": "Geist",
        "ghostWaiting": "w\u{00E4}rmt sich auf",
        "ghostFinished": "in %@ beendet",
        "raceChallengeTitle": "Ein Freund fordert dich heraus",
        "raceChallengeBlurb": "R\u{00E4}tsel Nr. %d \u{2014} %d Z\u{00FC}ge. Schlag ihre Zeit.",
        "raceChallengeBlurbPractice": "Ein zuf\u{00E4}lliges Wort \u{2014} %d Z\u{00FC}ge. Schlag ihre Zeit.",
        "raceStart": "Wettrennen",
        "raceDecline": "Allein spielen",
        "raceGo": "LOS!",
        "raceAFriend": "Freund herausfordern",
        "raceThemBack": "Revanche",
        "raceShareSolved": "Ich habe es in %@ gel\u{00F6}st \u{2014} schlag das.",
        "raceShareUnsolved": "Schaffst du das hier?",
        "homeRaceSub": "Schlag die Zeit eines Freundes",
        "raceFriendBlurb": "Löse das heutige Wort und schick den Link. Dein Freund tritt gegen deinen Geist an, Zug um Zug. Keine App nötig.",
        "racePlayTodayFirst": "Spiel das heutige Wort",
        "raceSendYourRun": "Sende dein Rennen",
        "raceStrangerTitle": "Live-Rennen",
        "raceLiveDisclosure": "Live-Rennen senden deine eingegebenen Wörter zur Bewertung an Wicks Server (über Google Gemini). Ein Geisterrennen-Link enthält nur dein Tempo und deine Wärme, nie deine Wörter.",
        "liveRematch": "Revanche",
        "liveScanCaption": "Oder scanne den Code.",
        // Live multiplayer (3.0/3.1) — draft, needs fluent skim
        "liveJoin": "Beitreten", "liveCancel": "Abbrechen", "liveDone": "Fertig", "liveClose": "Schließen", "liveLeave": "Verlassen",
        "liveConnectionLost": "Verbindung verloren", "liveTheWordWas": "Das Wort war", "liveYourRound": "Deine Runde",
        "liveInviteFriend": "Freund einladen", "liveKeepGoing": "weiter so", "liveScoring": "wird bewertet…",
        "liveYouGotItLower": "geschafft!", "liveSolvedExcl": "Gelöst!",
        "liveRace": "Rennen", "liveRaceBlurb": "Ihr ratet beide dasselbe versteckte Wort — wer zuerst löst, gewinnt.",
        "liveQuickMatch": "Schnelles Match", "liveHaveACode": "HAST DU EINEN CODE?", "liveEnterIt": "eingeben",
        "liveInviteHintRace": "Einladen erstellt einen Link zum Senden. Schnelles Match findet jeden (oder eine Übungsflamme).",
        "liveFindingOpponent": "Suche Gegner…", "liveWaitingForFriend": "Warte auf deinen Freund…",
        "livePracticeFlameSteps": "Eine Wick-Flamme springt ein, wenn niemand da ist.",
        "liveNextRaceIn": "Nächstes Rennen startet in",
        "liveShareInviteLink": "Link teilen",
        "liveShareTapToJoin": "Sende den Link — dein Freund tippt darauf, um beizutreten. Oder er gibt den Code ein.",
        "liveTheyJoinByLink": "Sie treten bei, indem sie deinen Link antippen oder den Code eingeben.",
        "liveLiveRace": "Live-Rennen", "livePlayAgain": "Nochmal spielen", "liveTryAgain": "Erneut versuchen",
        "liveGuessOrAsk": "Rate ein Wort oder frag Wick…",
        "liveGuessOrAskHint": "Ein einzelnes Wort ist ein Rateversuch. Füge „?“ hinzu oder schreibe einen Satz, um Wick zu fragen.",
        "liveWelcome": "Hi, ich bin %@. Ich hüte ein geheimes Wort — rate irgendwas und ich sage dir, wie nah du dem Sinn nach bist.",
        "liveLiveOpponent": "Live-Gegner", "livePracticeFlame": "Übungsflamme",
        "liveGhost": "Geist eines früheren Laufs", "liveOpponent": "Gegner", "liveReconnecting": "verbinde neu…",
        "liveGuessesCount": "%d Versuche",
        "liveGoodStart": "Guter Start!", "liveClosestYet": "Bisher am nächsten", "liveFurther": "Weiter als dein Bestes",
        "liveResult": "Ergebnis", "liveYouWin": "Du gewinnst!", "liveYouLost": "Du hast verloren", "liveDraw": "Unentschieden",
        "liveFirstToWord": "Erster beim Wort.", "liveOppFirst": "Dein Gegner war zuerst da.",
        "liveTimeUpWarmest": "Zeit um — entschieden durch den heißesten Versuch.",
        "liveOppLeft": "Dein Gegner hat verlassen.", "liveYouLeft": "Du hast das Match verlassen.",
        "liveBothDropped": "Kein Ergebnis — beide Spieler weg.",
        "liveOppLeftHangTight": "Dein Gegner ist weg — einen Moment.",
        "liveNotAWord": "Das ist kein Wort, das ich kenne — versuch ein anderes.",
        "liveInviteExpired": "Diese Einladung ist abgelaufen — bitte deinen Freund um einen neuen Link.",
        "liveShareMsgRace": "Mach ein Rennen mit mir bei Wick!",
        // Header
        "dailyTitle": "Nr. %d",
        "practice": "Training",
        "archive": "Frühere Rätsel",
        "archiveEmpty": "Noch keine früheren Rätsel. Komm morgen wieder!",
        "archiveSolvedToast": "Stark — vergangenes Rätsel gelöst!",
        "todaysPuzzle": "Heutiges Rätsel",
        "tier": "Stufe %d",
        // Welcome / hero
        "welcome": "Hallo, ich bin %@. Ich hüte ein geheimes Wort – rate irgendein Wort und ich sage dir, wie nah du der Bedeutung nach bist.",
        "notInVocabulary": "nicht im Wortschatz",
        "keepGoing": "weiter so",
        // Trajectory
        "firstGuess": "Guter Anfang!",
        "heat.Solved!": "Gelöst!",
        "heat.Boiling": "Kochend",
        "heat.Hot": "Heiß",
        "heat.Warm": "Warm",
        "heat.Cool": "Kühl",
        "heat.Cold": "Kalt",
        "heat.Freezing": "Eiskalt",
        "nudgeSoClose": "So nah, ich kann es spüren!",
        "nudgeCircling": "Ooh, du kreist es ein…",
        "nudgeStuck": "Ein paar kalte Versuche in Folge. Festgefahren? Frag mich etwas – wofür man es benutzt oder wo man es findet.",
        "coachNotAWord": "Das kenne ich nicht — ich kenne nur einzelne, alltägliche Wörter. Versuch ein anderes.",
        "coachFirstCold": "Kalt heißt nicht schlechtes Wort — es heißt falsches Thema. Ich bewerte die Bedeutung, nicht die Schreibweise. Probier etwas aus einem völlig anderen Bereich.",
        "coachFirstWarm": "Gut — das ist die richtige Gegend. Jetzt werde in dieser Richtung genauer.",
        "coachTriangulate": "Immer noch nichts Warmes. Streu breiter, statt nachzubohren: ein Tier, ein Gefühl, ein Ort, ein Werkzeug. Sobald etwas warm wird, folge dem.",
        "warmestUp": "Am nächsten dran · %d näher",
        "warmest": "Am nächsten dran",
        "colder": "Weiter weg als dein bester Versuch",
        // Input
        "guessPlaceholder": "Rate ein Wort…",
        "askKeeper": "Frag den Hüter",
        "hint": "Hinweis",
        "guessOrAskPlaceholder": "Rate ein Wort oder frag Wick…",
        "guessOrAskHint": "Ein einzelnes Wort ist ein Versuch. Füge ein „?“ hinzu oder schreibe einen Satz, um Wick zu fragen.",
        "roundLog": "Deine Runde",
        "needIdeas": "Ideen für Fragen an Wick?",
        "a11ySend": "Senden",
        "a11yShop": "Münz-Shop öffnen",
        "a11yAskThis": "Stellt Wick diese Frage",
        "waysTitle": "Zwei Arten zu spielen",
        "wayGuessTitle": "Tippe ein Wort",
        "wayGuessBody": "Ich sage dir, wie nah es der Bedeutung nach ist.",
        "wayAskTitle": "Oder frag mich etwas",
        "wayAskBody": "Ja / Nein-Antworten, immer kostenlos.",
        "offerStuck": "Ein paar kalte Versuche in Folge. Soll ich es eingrenzen?",
        "offerCold": "Noch nichts Warmes. Frag mich doch das —",
        "offerRoutine": "Du darfst mich ausfragen, weißt du. Fang hier an:",
        "offerAskElse": "Etwas anderes",
        "offerNotNow": "Später",
        "sortRecent": "Neueste",
        "sortClosest": "Heißeste",
        // Learn mode
        "learnTitle": "Lernmodus",
        "learnToggle": "%@ lernen",
        "learnBlurb": "Zeigt jeden Versuch auf %@ (%@ → %@), während du spielst – so lernst du nebenbei Wörter.",
        // Solved / revealed
        "solvedTitle": "Gelöst!",
        "solvedIn.one": "„%@“ in %d Versuch",
        "solvedIn.other": "„%@“ in %d Versuchen",
        "streakDays": "%d-Tage-Serie!",
        "shareResult": "Ergebnis teilen",
        "shareSolvedIn": "gelöst in %d",
        "shareQuestions.one": "%d Frage",
        "shareQuestions.other": "%d Fragen",
        "shareHints.one": "%d Hinweis",
        "shareHints.other": "%d Hinweise",
        "shareTagline": "Wick · rate nach Bedeutung",
        "playRandom": "Zufälliges Wort spielen",
        "easy": "Leicht",
        "medium": "Mittel",
        "hard": "Schwer",
        "theWordWas": "Das Wort war",
        // Give up
        "giveUpTitle": "Antwort aufdecken?",
        "giveUp": "Aufgeben",
        "keepTrying": "Weiter versuchen",
        "giveUpMessage": "Du siehst das Wort und die Runde endet.",
        // Guess list
        "guessesCount": "Versuche · %d",
        // Ask the Keeper
        "askTitle": "Frag den Hüter",
        "done": "Fertig",
        "duel": "Duell",
        "soundHapticsTitle": "Ton & Vibration",
        "hapticsToggle": "Vibration",
        "soundToggle": "Ton",
        "duelSolvedToast": "Duell gelöst! Teile dein Ergebnis.",
        "home": "Start",
        "pastPuzzles": "Frühere",
        "chooseDifficulty": "Schwierigkeit wählen",
        "homeGuessWord": "Errate das geheime Wort",
        "homeReplayAnyDay": "Spiele jeden Tag erneut",
        "homePlayAnytime": "Jederzeit spielen",
        "homeDressUpWick": "Wick anziehen",
        "duelCreate": "Duell erstellen",
        "duelRace": "Rennen",
        "duelRaceBlurb": "Wick wählt ein geheimes Wort — ihr spielt beide blind und vergleicht.",
        "duelPlayNow": "Jetzt spielen",
        "duelYourCode": "Dein Duell-Code",
        "duelShareCode": "Teilen",
        "duelPaste": "Code einfügen",
        "duelJoin": "Duell beitreten",
        "duelJoinPlaceholder": "Code einfügen…",
        "duelGo": "Los",
        "duelInvalid": "Dieser Code ist ungültig.",
        "duelChooseWord": "Wähle ein Wort",
        "duelHeadToHead": "Direktvergleich",
        "duelWin": "Du gewinnst!",
        "duelLose": "Sie gewinnen!",
        "duelTie": "Unentschieden!",
        "duelYou": "Du",
        "duelThem": "Sie",
        "duelGaveUp": "Aufgegeben",
        "duelNeedYours": "Spiele dieses Duell für den Direktvergleich.",
        "duelCopied": "Kopiert!",
        "duelCopy": "Kopieren",
        "duelResultShare": "Ergebnis teilen",
        "duelResultMsg": "Mein Wick-Duell-Ergebnis: %@ — füg es im Duell ein, um zu vergleichen.",
        "duelYouChose": "Du hast „%@“ gewählt. Sende den Code an einen Freund.",
        "duelShareMsg": "Schlägst du mich bei Wick?",
        "duelSolvedIn": "In %d gelöst",
        "wardrobe": "Wicks Kleiderschrank",
        "wardrobeBlurb": "Gib Münzen aus, um Wick zu verkleiden. Nur zum Spaß — es ändert das Spiel nicht.",
        "equip": "Anziehen",
        "equipped": "Getragen",
        "take_off": "Ablegen",
        "buy": "Kaufen",
        "owned": "Besitzt",
        "notEnoughCoins": "Nicht genug Münzen",
        "slot_hat": "Hüte",
        "slot_eyes": "Augen",
        "slot_face": "Gesicht",
        "slot_mouth": "Mund",
        "slot_neck": "Hals",
        "acc_tophat": "Zylinder",
        "acc_tongue": "Zunge raus",
        "acc_googly": "Kulleraugen",
        "acc_hearts": "Herzaugen",
        "acc_stars": "Sternaugen",
        "acc_party": "Partyhut",
        "acc_wizard": "Zaubererhut",
        "acc_crown": "Krone",
        "acc_monocle": "Monokel",
        "acc_glasses": "Brille",
        "acc_bowtie": "Fliege",
        "acc_tie": "Krawatte",
        "askTab": "Fragen",
        "guessTab": "Raten",
        "suggestedQuestions": "Vorgeschlagene Fragen",
        "dreamingClue": "%@ denkt sich einen Hinweis aus…",
        "askIntro": "Frag Dinge wie „Lebt es?“, „Größer als ein Auto?“, „Findet man es drinnen?“. Der Hüter antwortet ehrlich, verrät das Wort aber nicht.",
        "keeperNoRespond": "Der Hüter hat nicht geantwortet",
        "retry": "Erneut versuchen",
        "askPlaceholder": "Frag Wick irgendwas…",
        "questionsFree": "Fragen sind kostenlos — frag Wick irgendwas.",
        "notAKnownWord": "kein bekanntes Wort",
        "offlineBanner": "Wick funktioniert auf diesem iPhone offline. Tippe auf eine vorgeschlagene Frage für eine exakte Antwort, oder schreibe ein einfaches Ja/Nein wie „Lebt es?“. Apple Intelligence ist nicht nötig.",
        "offlineFootnote": "Offline-Modus: Wick beantwortet das Wichtigste auf dem Gerät. Tippe auf einen Vorschlag für eine exakte Antwort.",
        "freeQuestionsLeft.one": "%d Gratisfrage übrig",
        "freeQuestionsLeft.other": "%d Gratisfragen übrig",
        "questionCost": "Jede Frage kostet %d Münzen (du hast %d)",
        "outOfCoins": "Keine Münzen mehr – rate gratis weiter oder löse Runden, um mehr zu verdienen.",
        // Menu / Settings
        "howToPlay": "Spielanleitung",
        "settings": "Einstellungen",
        "language": "Sprache",
        "languageFooter": "Legt die Sprache des Tageswortes, deiner Versuche und von Wick fest. Ein Wechsel startet eine neue Runde.",
        // Stats
        "yourStats": "Deine Statistiken",
        "currentStreak": "Aktuelle Serie",
        "bestStreak": "Beste Serie",
        "wordsSolved": "Gelöste Wörter",
        "avgGuesses": "Ø Versuche",
        "fewestGuesses": "Wenigste Versuche",
        "coins": "Münzen",
        "achievements": "Erfolge",
        "leaderboards": "Bestenlisten",
        "dailyReminder": "Tägliche Erinnerung",
        "time": "Uhrzeit",
        "reminderBlurb": "Ein sanfter Stups, wenn das Wort des Tages bereit ist.",
        "notifDailyTitle": "Das Wort des Tages ist bereit",
        "notifDailyBody": "Wick hütet ein neues. Traust du dir das zu?",
        "notifStreakTitle": "Deine Flamme geht gleich aus",
        "notifStreakBody": "%d Tage in Folge — das heutige Wort ist noch ungelöst.",
        // Toasts
        "dailyBonus": "Tagesbonus · +%d Münzen",
        "countsAsAlready": "„%@“ zählt als „%@“ – schon versucht.",
        "alreadyGuessed": "„%@“ schon versucht.",
        "normalizedTo": "„%@“ → „%@“",
        "didYouMean": "„%@“ ist nicht in meinem Wortschatz – meintest du „%@“?",
        "notInVocabToast": "„%@“ ist nicht in meinem Wortschatz – versuch ein anderes.",
        "solvedBadge": "Gelöst! +%d · 🏅 %@",
        "solvedCoins": "Gelöst! +%d Münzen",
        "theWordWasToast": "Das Wort war „%@“",
        "hintWarmingUp": "Der Hinweis wärmt sich auf – versuch es gleich noch mal.",
        "hintsCost": "Die Gratis-Hinweise für heute sind aufgebraucht. Jetzt kosten sie %d Münzen.",
        "hintFreeLeft": "Hinweis (%d gratis heute)", "hintCoinPrice": "Hinweis (%d Münzen)",
        "topTakeIt": "Du bist unter den ersten %d – schaff es allein! 🔥",
        "noCloserHint": "Du kommst näher – es gibt keinen näheren Hinweis mehr!",
        "hintLands": "Hinweis: „%@“ landet auf Nr. %d – wärmer!",
        "spellHint": "Das Wort beginnt mit %@",
        "wickEgg": "Hey — daraus bestehe ich doch!",
        "eggHunch": "Hunch? So hieß ich früher — gutes Gedächtnis.",
        "eggCheat": "Schummeln? Wo bliebe da der Spaß?",
        "plusCoins": "+%d Münzen",
        "outOfFreeQuestions": "Keine Gratisfragen mehr – kostet %d Münzen.",
        "keeperDidntRespond": "Der Hüter hat nicht geantwortet – tippe auf „Erneut versuchen“.",
        "scoringUnavailable": "Das Wörterbuch dieser Sprache ist noch nicht heruntergeladen – ich versuche es weiter. Geh kurz online, dann löst es sich von selbst.",
        "vocabularyReady": "Wörterbuch bereit – los geht's!",
        "scoringKeyboardHint": "Immer noch nichts? iOS lädt das Wörterbuch, sobald dein Gerät die Sprache nutzt – füge die Tastatur dieser Sprache unter Einstellungen → Allgemein → Tastatur hinzu und komm zurück. Ich erkenne es automatisch.",
        "downloadDictionaryTitle": "Wörterbuch wird geladen…",
        "downloadDictionaryBlurb": "Ein kurzer, einmaliger Download, damit du diese Sprache offline spielen kannst. Es dauert nur einen Moment.",
        "downloadDictionaryFailed": "Download gerade nicht möglich – ich versuche es weiter, und du kannst mit dem integrierten Wörterbuch spielen.",
        "cancelDownload": "Abbrechen",
        "dictionaries": "Offline-Wörterbücher",
        "dictionariesBlurb": "Lade das Wörterbuch einer Sprache herunter, um offline zu spielen. Sprachen werden auch automatisch geladen, wenn du sie zum ersten Mal auswählst.",
        "downloadAll": "Alle Sprachen herunterladen",
        "dictionaryReady": "Bereit",
        "dictionaryDownload": "Laden",
        // Settings extras
        "notifications": "Mitteilungen",
        "about": "Über",
        "privacyPolicy": "Datenschutzerklärung",
        "languagePickHint": "Wähle die Spielsprache",
        // How to play
        "meetKeeper": "Das ist der Hüter",
        "meetKeeperSub": "Er hütet das geheime Wort – und wird wärmer, je näher du kommst.",
        "letsPlay": "Los geht's!",
        "howStep1Title": "Rate nach Bedeutung",
        "howStep1Detail": "Es gibt ein geheimes Wort. Tippe irgendein Wort ein und du siehst, wie nah es ist – der Bedeutung nach, nicht der Schreibweise.",
        "howStep2Title": "Heiß oder kalt",
        "howStep2Detail": "Nähere Versuche zählen mehr und glühen rot. Weit entfernte bleiben eisblau. Der Bildschirm wird wärmer, je näher du kommst.",
        "howStep3Title": "Frag Wick",
        "howStep3Detail": "Festgefahren? Stell Wick Ja/Nein-Fragen wie „Lebt es?“ – funktioniert auf jedem iPhone, antwortet ehrlich und verrät das Wort nie.",
        "howStep4Title": "Jeden Tag ein neues Wort",
        "howStep4Detail": "Alle bekommen jeden Tag dasselbe Wort. Löse es, baue eine Serie auf und teile dein Ergebnis.",
        // Shop
        "getCoins": "Münzen holen",
        "yourBalance": "Dein Guthaben",
        "coinsAmount": "%d Münzen",
        "loadingShop": "Shop wird geladen…",
        "shopUnavailable": "Shop nicht verfügbar",
        "shopUnavailableDetail": "Die Münzpakete konnten gerade nicht geladen werden. Prüfe deine Verbindung und versuch es erneut.",
        "coinsBuyBlurb": "Münzen kaufen extra Hinweise und Fragen. Das Tageswort bleibt gratis, und du verdienst Münzen beim Spielen.",
    ]
}
