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
    /// 3.5: the race music switch, separate from sound effects.
    var musicToggle: String { s("musicToggle") }
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
    var shareSectionTitle: String { s("shareSectionTitle") }
    var shareTileResult: String { s("shareTileResult") }
    var shareTileMap: String { s("shareTileMap") }
    var shareTileVideo: String { s("shareTileVideo") }
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
    // 3.6: everyone's week on the Stats page, and its Settings switch.
    var weeklyHeader: String { s("weeklyHeader") }
    var weeklyTopGuesses: String { s("weeklyTopGuesses") }
    var weeklyTopQuestions: String { s("weeklyTopQuestions") }
    var weeklyResets: String { s("weeklyResets") }
    var weeklyEmpty: String { s("weeklyEmpty") }
    var weeklyOffline: String { s("weeklyOffline") }
    var weeklySettingsHeader: String { s("weeklySettingsHeader") }
    var shareWordsToggle: String { s("shareWordsToggle") }
    var shareWordsBlurb: String { s("shareWordsBlurb") }
    // 3.6: today's race board.
    var boardTitle: String { s("boardTitle") }
    var boardOpen: String { s("boardOpen") }
    /// "You're #3 of 41 today"
    func boardRankLine(_ rank: Int, _ total: Int) -> String { f("boardRankLine", rank, total) }
    /// "41 racing today"
    func boardPlayers(_ total: Int) -> String { f("boardPlayers", total) }
    var boardEmpty: String { s("boardEmpty") }
    var boardSolveFirst: String { s("boardSolveFirst") }
    var boardNewName: String { s("boardNewName") }
    var boardYou: String { s("boardYou") }
    var boardOffline: String { s("boardOffline") }
    /// "Racing as Violet Otter"
    func boardRacingAs(_ name: String) -> String { f("boardRacingAs", name) }
    var boardColGuesses: String { s("boardColGuesses") }
    var boardColTime: String { s("boardColTime") }
    var boardRules: String { s("boardRules") }
    var boardGaveUp: String { s("boardGaveUp") }
    var boardYourResult: String { s("boardYourResult") }
    var boardSubmit: String { s("boardSubmit") }
    var boardSubmitNote: String { s("boardSubmitNote") }
    var boardWaiting: String { s("boardWaiting") }
    var dailyReminder: String { s("dailyReminder") }
    var time: String { s("time") }
    var reminderBlurb: String { s("reminderBlurb") }
    // Race alerts (push from the server). English only for now; other
    // languages fall back to it.
    var raceAlerts: String { s("raceAlerts") }
    var alertWaiting: String { s("alertWaiting") }
    var alertBusy: String { s("alertBusy") }
    var alertSurge: String { s("alertSurge") }
    var raceAlertsBlurb: String { s("raceAlertsBlurb") }
    /// Notification copy. Written in the player's IN-APP language (see
    /// `HunchNotifications`), never the device language.
    var notifDailyTitle: String { s("notifDailyTitle") }
    var notifDailyBody: String { s("notifDailyBody") }
    var notifStreakTitle: String { s("notifStreakTitle") }
    /// "6 days and counting…" — %d is the streak about to be lost.
    func notifStreakBody(_ days: Int) -> String { f("notifStreakBody", days) }
    /// 3.5: the one-time offer after the first daily solve.
    var reminderOfferTitle: String { s("reminderOfferTitle") }
    var reminderOfferBody: String { s("reminderOfferBody") }
    var reminderOfferYes: String { s("reminderOfferYes") }
    var notNow: String { s("notNow") }

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
    func setPlayIn(_ name: String) -> String { f("setPlayIn", name) }
    var setPlayInHintOn: String { s("setPlayInHintOn") }
    var setPlayInHintOff: String { s("setPlayInHintOff") }
    func raceTheirWord(_ word: String, _ language: String) -> String { f("raceTheirWord", word, language) }

    // MARK: - How to play (3.6: a glance, plus the tutorial button)
    var letsPlay: String { s("letsPlay") }
    var howGuessLine: String { s("howGuessLine") }
    var howAskLine: String { s("howAskLine") }
    var howHintLine: String { s("howHintLine") }
    var howDailyLine: String { s("howDailyLine") }

    // MARK: - Tutorial level (3.6)
    var tutTitle: String { s("tutTitle") }
    var tutSkip: String { s("tutSkip") }
    var tutGuessAny: String { s("tutGuessAny") }
    var tutNotAWord: String { s("tutNotAWord") }
    func tutHeat(_ heat: String) -> String { f("tutHeat", heat) }
    var tutColder: String { s("tutColder") }
    var tutWarmer: String { s("tutWarmer") }
    var tutAsk: String { s("tutAsk") }
    var tutAskInstead: String { s("tutAskInstead") }
    func tutAnswered(_ verdict: String) -> String { f("tutAnswered", verdict) }
    var tutHint: String { s("tutHint") }
    var tutHintInstead: String { s("tutHintInstead") }
    var tutHintLanded: String { s("tutHintLanded") }
    var tutFindIt: String { s("tutFindIt") }
    var tutItsAnAnimal: String { s("tutItsAnAnimal") }
    var tutGroupFarm: String { s("tutGroupFarm") }
    var tutGroupPet: String { s("tutGroupPet") }
    var tutGroupWild: String { s("tutGroupWild") }
    var tutGroupWater: String { s("tutGroupWater") }
    /// A per-animal clue by key ("tutSound.frog").
    func tutClue(_ key: String) -> String { s(key) }
    func tutStartsWith(_ first: String) -> String { f("tutStartsWith", first) }
    func tutStartsEnds(_ first: String, _ last: String) -> String { f("tutStartsEnds", first, last) }
    func tutLetterCount(_ count: Int, _ first: String, _ last: String) -> String {
        f("tutLetterCount", count, first, last)
    }
    var tutAlreadyHot: String { s("tutAlreadyHot") }
    var tutLucky: String { s("tutLucky") }
    var tutDoneTitle: String { s("tutDoneTitle") }
    func tutDoneWord(_ word: String) -> String { f("tutDoneWord", word) }
    var tutDoneHeadline: String { s("tutDoneHeadline") }
    var tutPlayDaily: String { s("tutPlayDaily") }
    var tutFreeHint: String { s("tutFreeHint") }
    var tutCheerWarmer: String { s("tutCheerWarmer") }
    var tutCheerLucky: String { s("tutCheerLucky") }
    var tutCheerSolved: String { s("tutCheerSolved") }
    var tutBadgeGuess: String { s("tutBadgeGuess") }
    var tutBadgeWarmer: String { s("tutBadgeWarmer") }
    var tutBadgeAsk: String { s("tutBadgeAsk") }
    var tutBadgeHint: String { s("tutBadgeHint") }
    var tutBadgeSolve: String { s("tutBadgeSolve") }
    func tutStepOf(_ step: Int, _ total: Int) -> String { f("tutStepOf", step, total) }
    var tutPlayTutorial: String { s("tutPlayTutorial") }
    var tutPlayTutorialSub: String { s("tutPlayTutorialSub") }

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
    var raceLiveNow: String { s("raceLiveNow") }
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

    // MARK: - Solve Replay (3.4)
    var replayShare: String { s("replayShare") }
    var replayTitle: String { s("replayTitle") }
    var replayMaking: String { s("replayMaking") }
    var replaySave: String { s("replaySave") }
    var replaySaving: String { s("replaySaving") }
    var replaySaved: String { s("replaySaved") }
    var replaySavedHint: String { s("replaySavedHint") }
    var replaySaveFailed: String { s("replaySaveFailed") }
    var replayDenied: String { s("replayDenied") }
    var replayOpenSettings: String { s("replayOpenSettings") }
    var replayFailed: String { s("replayFailed") }
    var replayTryAgain: String { s("replayTryAgain") }
    var replayBest: String { s("replayBest") }
    var replayTagline: String { s("replayTagline") }
    var replayPlayFree: String { s("replayPlayFree") }
    /// 3.5: "Can you beat %d? Play free at", the end card line on a solved
    /// daily, so the video dares the viewer to beat the poster's guess count.
    var replayChallengeFormat: String { s("replayChallenge") }
    var replayRevealed: String { s("replayRevealed") }
    func replayRevealedAfter(_ n: Int) -> String { f("replayRevealedAfter", n) }
    /// Raw format strings ("Guess %d of %d", "+%d guesses"): the video is drawn
    /// off the main thread, so it formats these itself.
    var replayGuessOfFormat: String { s("replayGuessOf") }
    var replayFastForwardFormat: String { s("replayFastForward") }
    /// "The word was %@": the practice replay's end card formats it itself.
    var replayAnswerWasFormat: String { s("replayAnswerWas") }

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
        "homeRaceSub": "First to solve wins",
        "raceFriendBlurb": "Finish today's word, then send the link. Your friend races your ghost, move by move. No app needed.",
        "racePlayTodayFirst": "Play today's word",
        "raceSendYourRun": "Send your race",
        "raceStrangerTitle": "Race someone live",
        "raceLiveNow": "Race now",
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
        "shareSectionTitle": "Share",
        "shareTileResult": "Result",
        "shareTileMap": "Map",
        "shareTileVideo": "Video",
        "shareSolvedIn": "solved in %d",
        "shareQuestions.one": "%d question",
        "shareQuestions.other": "%d questions",
        "shareHints.one": "%d hint",
        "shareHints.other": "%d hints",
        "shareTagline": "Wick · ask 20 questions, race to reveal the secret word",
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
        "musicToggle": "Race music",
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
        "boardYourResult": "Your result today",
        "boardSubmit": "Submit to the board",
        "boardSubmitNote": "Nothing is posted until you tap Submit. You'll show up under an auto name, never your real one.",
        "boardWaiting": "Your score will post as soon as you're back online.",
        "boardGaveUp": "Gave up",
        "boardTitle": "Today's race",
        "boardOpen": "Today's race board",
        "boardRankLine": "You're #%d of %d today",
        "boardPlayers": "%d racing today",
        "boardEmpty": "Nobody has solved today's word yet. Be the first!",
        "boardSolveFirst": "Solve today's word to get on the board.",
        "boardNewName": "New name",
        "boardYou": "You",
        "boardOffline": "Can't load the board right now.",
        "boardRacingAs": "Racing as %@",
        "boardColGuesses": "Guesses",
        "boardColTime": "Time",
        "boardRules": "Fewest guesses wins. Each hint counts as one more guess. Ties go to the faster time. Giving up puts you at the bottom. Your first result of the day is the one that counts.",
        "weeklyHeader": "This week, everyone",
        "weeklyTopGuesses": "Top guesses this week",
        "weeklyTopQuestions": "Most asked questions",
        "weeklyResets": "All players. Resets Monday.",
        "weeklyEmpty": "Not enough plays yet this week.",
        "weeklyOffline": "Can't load this week's lists right now.",
        "weeklySettingsHeader": "Weekly stats",
        "shareWordsToggle": "Add my words to weekly stats",
        "shareWordsBlurb": "Adds your cool or colder guesses and the questions you type to the Keeper to everyone's weekly lists. Sent with no id. Close guesses and anything that names the answer stay on your phone.",
        "dailyReminder": "Daily reminder",
        "time": "Time",
        "reminderBlurb": "A gentle nudge when each day's word is ready.",
        "raceAlerts": "Race alerts",
        "alertWaiting": "Someone is waiting for a race",
        "alertBusy": "The race queue is busy",
        "alertSurge": "Unusually many people playing",
        "raceAlertsBlurb": "A push from Wick when there is someone to race. At most one of each an hour or so, and never about your own wait.",
        "notifDailyTitle": "Today's word is ready",
        "notifDailyBody": "Wick is guarding a new one. Think you can get it?",
        "notifStreakTitle": "Your flame is about to go out",
        "notifStreakBody": "%d days and counting — today's word is still unsolved.",
        "reminderOfferTitle": "Want a nudge tomorrow?",
        "reminderOfferBody": "Wick can tell you when the next word is ready. You can change the time in Settings.",
        "reminderOfferYes": "Remind me",
        "notNow": "Not now",
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
        "languagePickHint": "Choose the language of the menus.",
        "setPlayIn": "Play in %@",
        "raceTheirWord": "They were hunting \u{201C}%@\u{201D} (%@).",
        "setPlayInHintOn": "The word, your guesses and Wick are all in this language. Turn it off to play in English with meanings shown.",
        "setPlayInHintOff": "Menus and word meanings only. The word, your guesses and Wick stay in English, so you can learn English as you play. Turn it on to play the round in this language.",
        // How to play
        "letsPlay": "Let's play",
        "tutTitle": "Tutorial",
        "tutSkip": "Skip",
        "tutGuessAny": "I'm hiding a secret word. Type any word and send it!",
        "tutNotAWord": "I don't know that word. Try a real one!",
        "tutHeat": "%@! That's how close you are. Blue is far, red is super close. Now try a warmer word!",
        "tutColder": "Colder! Try a word with a totally different meaning.",
        "tutWarmer": "Warmer! You're getting closer.",
        "tutAsk": "Now my secret move: ask me a yes or no question!",
        "tutAskInstead": "Good try! But now ask me a question. Tap the bubble!",
        "tutAnswered": "I said %@!",
        "tutHint": "Ask me stuff like that as much as you want. Now tap Free hint!",
        "tutHintInstead": "Nice! Now tap the Free hint button to get a clue word.",
        "tutHintLanded": "That clue is closer to the secret word! Now find it. Guess or ask!",
        "tutFindIt": "Now find the secret word! Guess words or ask me questions.",
        "tutItsAnAnimal": "Clue: it's an animal! Guess one.",
        "tutGroupFarm": "Clue: it lives on a farm.",
        "tutGroupPet": "Clue: lots of people have one as a pet.",
        "tutGroupWild": "Clue: it's a big wild animal.",
        "tutGroupWater": "Clue: it lives in or near water.",
        "tutSound.cat": "Clue: it says meow!",
        "tutSound.dog": "Clue: it says woof!",
        "tutSound.cow": "Clue: it says moo and gives milk!",
        "tutSound.horse": "Clue: it says neigh and you can ride it!",
        "tutSound.pig": "Clue: it says oink and rolls in mud!",
        "tutSound.duck": "Clue: it says quack!",
        "tutSound.fish": "Clue: it swims and has fins!",
        "tutSound.frog": "Clue: it hops and says ribbit!",
        "tutSound.bear": "Clue: it loves honey!",
        "tutSound.lion": "Clue: it roars and has a big mane!",
        "tutStartsWith": "Clue: it starts with %@!",
        "tutStartsEnds": "Clue: it starts with %@ and ends with %@!",
        "tutLetterCount": "Clue: it has %d letters, starts with %@ and ends with %@!",
        "tutAlreadyHot": "You're already super close, no hint needed! Now find the secret word.",
        "tutLucky": "Whoa, you found it already! Here's a new secret word.",
        "tutDoneTitle": "You did it!",
        "tutDoneWord": "The secret word was %@.",
        "tutDoneHeadline": "Race against others to reveal the Secret Word!",
        "tutPlayDaily": "Play today's puzzle",
        "tutFreeHint": "Free hint",
        "tutCheerWarmer": "Warmer!",
        "tutCheerLucky": "Lucky!",
        "tutCheerSolved": "You got it!",
        "tutBadgeGuess": "Guess",
        "tutBadgeWarmer": "Warmer",
        "tutBadgeAsk": "Ask",
        "tutBadgeHint": "Hint",
        "tutBadgeSolve": "Solve",
        "tutStepOf": "Step %d of %d",
        "tutPlayTutorial": "Play the tutorial",
        "tutPlayTutorialSub": "Learn by playing. About a minute.",
        "howGuessLine": "Guess any word. Get warmer.",
        "howAskLine": "Ask me yes or no questions.",
        "howHintLine": "Stuck? A hint gives you a closer word.",
        "howDailyLine": "A new word every day. Race everyone to solve it!",
        // Shop
        "getCoins": "Get coins",
        "yourBalance": "Your balance",
        "coinsAmount": "%d coins",
        "loadingShop": "Loading shop…",
        "shopUnavailable": "Shop unavailable",
        "shopUnavailableDetail": "Coin packs couldn't load right now. Check your connection and try again.",
        "coinsBuyBlurb": "Coins buy extra hints and questions. You can always play the daily and earn coins for free.",
        // Solve Replay (3.4)
        "replayShare": "Share replay",
        "replayTitle": "Solve replay",
        "replayMaking": "Making your replay…",
        "replaySave": "Save to Photos",
        "replaySaving": "Saving…",
        "replaySaved": "Saved to Photos",
        "replaySavedHint": "Post it from your Photos to TikTok, Reels or anywhere you like.",
        "replaySaveFailed": "Couldn't save to Photos. Please try again.",
        "replayDenied": "Wick needs permission to add the video to your Photos. You can turn it on in Settings.",
        "replayOpenSettings": "Open Settings",
        "replayFailed": "Couldn't make the video. Please try again.",
        "replayTryAgain": "Try again",
        "replayGuessOf": "Guess %d of %d",
        "replayBest": "Best",
        "replayTagline": "Ask 20 questions, race to reveal the secret word",
        "replayPlayFree": "Play free at",
        "replayChallenge": "Can you beat %d? Play free at",
        "replayRevealed": "Revealed",
        "replayAnswerWas": "The word was %@",
        "replayRevealedAfter": "revealed after %d guesses",
        "replayFastForward": "+%d guesses",
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
        "homeRaceSub": "Gana quien resuelve primero",
        "raceFriendBlurb": "Termina la palabra de hoy y envía el enlace. Tu amigo corre contra tu fantasma, jugada a jugada. No necesita la app.",
        "racePlayTodayFirst": "Juega la palabra de hoy",
        "raceSendYourRun": "Envía tu carrera",
        "raceStrangerTitle": "Carrera en vivo",
        "raceLiveNow": "Correr ahora",
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
        "shareSectionTitle": "Compartir",
        "shareTileResult": "Resultado",
        "shareTileMap": "Mapa",
        "shareTileVideo": "Vídeo",
        "shareSolvedIn": "resuelto en %d",
        "shareQuestions.one": "%d pregunta",
        "shareQuestions.other": "%d preguntas",
        "shareHints.one": "%d pista",
        "shareHints.other": "%d pistas",
        "shareTagline": "Wick · haz 20 preguntas, corre a revelar la palabra secreta",
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
        "musicToggle": "Música de carrera",
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
        "boardYourResult": "Tu resultado de hoy",
        "boardSubmit": "Enviar a la clasificación",
        "boardSubmitNote": "No se publica nada hasta que toques Enviar. Aparecerás con un nombre automático, nunca el tuyo.",
        "boardWaiting": "Tu puntuación se publicará en cuanto vuelvas a tener conexión.",
        "boardGaveUp": "Te rendiste",
        "boardTitle": "La carrera de hoy",
        "boardOpen": "Clasificación de hoy",
        "boardRankLine": "Vas #%d de %d hoy",
        "boardPlayers": "%d compitiendo hoy",
        "boardEmpty": "Nadie ha resuelto la palabra de hoy. ¡Sé el primero!",
        "boardSolveFirst": "Resuelve la palabra de hoy para entrar en la clasificación.",
        "boardNewName": "Nuevo nombre",
        "boardYou": "Tú",
        "boardOffline": "No se puede cargar la clasificación ahora.",
        "boardRacingAs": "Compites como %@",
        "boardColGuesses": "Intentos",
        "boardColTime": "Tiempo",
        "boardRules": "Gana quien use menos intentos. Cada pista cuenta como un intento más. En caso de empate gana el tiempo más rápido. Rendirte te deja al final. Solo cuenta tu primer resultado del día.",
        "weeklyHeader": "Esta semana, todos",
        "weeklyTopGuesses": "Palabras más probadas esta semana",
        "weeklyTopQuestions": "Preguntas más hechas",
        "weeklyResets": "Todos los jugadores. Se reinicia el lunes.",
        "weeklyEmpty": "Aún no hay suficientes partidas esta semana.",
        "weeklyOffline": "No se pueden cargar las listas ahora.",
        "weeklySettingsHeader": "Estadísticas semanales",
        "shareWordsToggle": "Sumar mis palabras a las estadísticas",
        "shareWordsBlurb": "Añade tus intentos fríos y las preguntas que escribes al Guardián a las listas semanales de todos. Se envían sin ningún identificador. Los intentos cercanos y todo lo que nombre la respuesta se quedan en tu teléfono.",
        "dailyReminder": "Recordatorio diario",
        "time": "Hora",
        "reminderBlurb": "Un aviso suave cuando la palabra de cada día está lista.",
        "notifDailyTitle": "La palabra de hoy está lista",
        "notifDailyBody": "Wick guarda una nueva. ¿Crees que la adivinas?",
        "notifStreakTitle": "Tu llama está a punto de apagarse",
        "notifStreakBody": "%d días seguidos — la palabra de hoy sigue sin resolver.",
        "reminderOfferTitle": "¿Te aviso mañana?",
        "reminderOfferBody": "Wick puede avisarte cuando la próxima palabra esté lista. Puedes cambiar la hora en Ajustes.",
        "reminderOfferYes": "Avísame",
        "notNow": "Ahora no",
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
        "languagePickHint": "Elige el idioma de los menús.",
        "setPlayIn": "Jugar en %@",
        "raceTheirWord": "Buscaba \u{201C}%@\u{201D} (%@).",
        "setPlayInHintOn": "La palabra, tus intentos y Wick están en este idioma. Desactívalo para jugar en inglés con los significados a la vista.",
        "setPlayInHintOff": "Solo menús y significados. La palabra, tus intentos y Wick siguen en inglés, para que aprendas inglés mientras juegas. Actívalo para jugar la ronda en este idioma.",
        // How to play
        "letsPlay": "¡A jugar!",
        "tutTitle": "Tutorial",
        "tutSkip": "Saltar",
        "tutGuessAny": "Escondo una palabra secreta. ¡Escribe cualquier palabra y envíala!",
        "tutNotAWord": "No conozco esa palabra. ¡Prueba con una de verdad!",
        "tutHeat": "¡%@! Así de cerca estás. Azul es lejos, rojo es muy cerca. ¡Ahora prueba una palabra más caliente!",
        "tutColder": "¡Más frío! Prueba una palabra con un significado muy distinto.",
        "tutWarmer": "¡Más caliente! Te estás acercando.",
        "tutAsk": "Ahora mi truco secreto: ¡hazme una pregunta de sí o no!",
        "tutAskInstead": "¡Buen intento! Pero ahora hazme una pregunta. ¡Toca la burbuja!",
        "tutAnswered": "¡Dije %@!",
        "tutHint": "Pregúntame cosas así todas las veces que quieras. ¡Ahora toca Pista gratis!",
        "tutHintInstead": "¡Bien! Ahora toca el botón Pista gratis para recibir una palabra pista.",
        "tutHintLanded": "¡Esa pista está más cerca de la palabra secreta! Ahora encuéntrala. ¡Adivina o pregunta!",
        "tutFindIt": "¡Ahora encuentra la palabra secreta! Adivina palabras o hazme preguntas.",
        "tutItsAnAnimal": "Pista: ¡es un animal! Adivina cuál.",
        "tutGroupFarm": "Pista: vive en una granja.",
        "tutGroupPet": "Pista: mucha gente tiene uno como mascota.",
        "tutGroupWild": "Pista: es un animal salvaje y grande.",
        "tutGroupWater": "Pista: vive en el agua o cerca de ella.",
        "tutSound.cat": "Pista: ¡hace miau!",
        "tutSound.dog": "Pista: ¡hace guau!",
        "tutSound.cow": "Pista: ¡hace mu y da leche!",
        "tutSound.horse": "Pista: ¡relincha y puedes montarlo!",
        "tutSound.pig": "Pista: ¡hace oinc y se revuelca en el barro!",
        "tutSound.duck": "Pista: ¡hace cuac!",
        "tutSound.fish": "Pista: ¡nada y tiene aletas!",
        "tutSound.frog": "Pista: ¡salta y hace croac!",
        "tutSound.bear": "Pista: ¡le encanta la miel!",
        "tutSound.lion": "Pista: ¡ruge y tiene una gran melena!",
        "tutStartsWith": "Pista: ¡empieza por %@!",
        "tutStartsEnds": "Pista: ¡empieza por %@ y termina en %@!",
        "tutLetterCount": "Pista: ¡tiene %d letras, empieza por %@ y termina en %@!",
        "tutAlreadyHot": "¡Ya estás muy cerca, no hace falta pista! Ahora encuentra la palabra secreta.",
        "tutLucky": "¡Guau, ya la encontraste! Aquí tienes una nueva palabra secreta.",
        "tutDoneTitle": "¡Lo lograste!",
        "tutDoneWord": "La palabra secreta era %@.",
        "tutDoneHeadline": "¡Compite contra otros para revelar la Palabra Secreta!",
        "tutPlayDaily": "Jugar el puzzle de hoy",
        "tutFreeHint": "Pista gratis",
        "tutCheerWarmer": "¡Más caliente!",
        "tutCheerLucky": "¡Qué suerte!",
        "tutCheerSolved": "¡La tienes!",
        "tutBadgeGuess": "Adivina",
        "tutBadgeWarmer": "Caliente",
        "tutBadgeAsk": "Pregunta",
        "tutBadgeHint": "Pista",
        "tutBadgeSolve": "Resuelve",
        "tutStepOf": "Paso %d de %d",
        "tutPlayTutorial": "Jugar el tutorial",
        "tutPlayTutorialSub": "Aprende jugando. Más o menos un minuto.",
        "howGuessLine": "Adivina palabras. Busca el calor.",
        "howAskLine": "Hazme preguntas de sí o no.",
        "howHintLine": "¿Atascado? Una pista te da una palabra más cercana.",
        "howDailyLine": "Una palabra nueva cada día. ¡Compite con todos para resolverla!",
        // Shop
        "getCoins": "Conseguir monedas",
        "yourBalance": "Tu saldo",
        "coinsAmount": "%d monedas",
        "loadingShop": "Cargando la tienda…",
        "shopUnavailable": "Tienda no disponible",
        "shopUnavailableDetail": "No se pudieron cargar los paquetes de monedas ahora. Revisa tu conexión e inténtalo de nuevo.",
        "coinsBuyBlurb": "Las monedas compran pistas y preguntas extra. Siempre puedes jugar el diario y ganar monedas gratis.",
        // Solve Replay (3.4)
        "replayShare": "Compartir repetición",
        "replayTitle": "Repetición",
        "replayMaking": "Creando tu repetición…",
        "replaySave": "Guardar en Fotos",
        "replaySaving": "Guardando…",
        "replaySaved": "Guardado en Fotos",
        "replaySavedHint": "Publícalo desde Fotos en TikTok, Reels o donde quieras.",
        "replaySaveFailed": "No se pudo guardar en Fotos. Inténtalo de nuevo.",
        "replayDenied": "Wick necesita permiso para añadir el video a Fotos. Puedes activarlo en Ajustes.",
        "replayOpenSettings": "Abrir Ajustes",
        "replayFailed": "No se pudo crear el video. Inténtalo de nuevo.",
        "replayTryAgain": "Reintentar",
        "replayGuessOf": "Intento %d de %d",
        "replayBest": "Mejor",
        "replayTagline": "Haz 20 preguntas, corre a revelar la palabra secreta",
        "replayPlayFree": "Juega gratis en",
        "replayChallenge": "¿Puedes superar %d? Juega gratis en",
        "replayRevealed": "Revelada",
        "replayAnswerWas": "La palabra era %@",
        "replayRevealedAfter": "revelada tras %d intentos",
        "replayFastForward": "+%d intentos",
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
        "homeRaceSub": "Le premier à trouver gagne",
        "raceFriendBlurb": "Termine le mot du jour, puis envoie le lien. Ton ami affronte ton fantôme, coup par coup. Pas besoin de l'app.",
        "racePlayTodayFirst": "Joue le mot du jour",
        "raceSendYourRun": "Envoie ta course",
        "raceStrangerTitle": "Course en direct",
        "raceLiveNow": "Courir maintenant",
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
        "shareSectionTitle": "Partager",
        "shareTileResult": "Résultat",
        "shareTileMap": "Carte",
        "shareTileVideo": "Vidéo",
        "shareSolvedIn": "résolu en %d",
        "shareQuestions.one": "%d question",
        "shareQuestions.other": "%d questions",
        "shareHints.one": "%d indice",
        "shareHints.other": "%d indices",
        "shareTagline": "Wick · pose 20 questions, révèle le mot secret avant les autres",
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
        "musicToggle": "Musique de course",
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
        "boardYourResult": "Ton résultat du jour",
        "boardSubmit": "Envoyer au classement",
        "boardSubmitNote": "Rien n'est publié tant que tu n'appuies pas sur Envoyer. Tu apparais sous un nom automatique, jamais le tien.",
        "boardWaiting": "Ton score sera publié dès que tu seras de nouveau en ligne.",
        "boardGaveUp": "Abandon",
        "boardTitle": "La course du jour",
        "boardOpen": "Classement du jour",
        "boardRankLine": "Tu es #%d sur %d aujourd'hui",
        "boardPlayers": "%d en course aujourd'hui",
        "boardEmpty": "Personne n'a encore trouvé le mot du jour. Sois le premier !",
        "boardSolveFirst": "Trouve le mot du jour pour entrer au classement.",
        "boardNewName": "Nouveau nom",
        "boardYou": "Toi",
        "boardOffline": "Impossible de charger le classement pour le moment.",
        "boardRacingAs": "Tu cours en tant que %@",
        "boardColGuesses": "Essais",
        "boardColTime": "Temps",
        "boardRules": "Le moins d'essais l'emporte. Chaque indice compte comme un essai de plus. En cas d'égalité, le temps le plus rapide gagne. Abandonner te place en bas. Seul ton premier résultat du jour compte.",
        "weeklyHeader": "Cette semaine, tout le monde",
        "weeklyTopGuesses": "Mots les plus tentés cette semaine",
        "weeklyTopQuestions": "Questions les plus posées",
        "weeklyResets": "Tous les joueurs. Remise à zéro le lundi.",
        "weeklyEmpty": "Pas encore assez de parties cette semaine.",
        "weeklyOffline": "Impossible de charger les listes pour le moment.",
        "weeklySettingsHeader": "Statistiques de la semaine",
        "shareWordsToggle": "Ajouter mes mots aux statistiques",
        "shareWordsBlurb": "Ajoute tes essais froids et les questions que tu écris au Gardien aux listes de la semaine de tout le monde. Envoyé sans aucun identifiant. Les essais proches et tout ce qui nomme la réponse restent sur ton téléphone.",
        "dailyReminder": "Rappel quotidien",
        "time": "Heure",
        "reminderBlurb": "Un petit signe quand le mot du jour est prêt.",
        "notifDailyTitle": "Le mot du jour est prêt",
        "notifDailyBody": "Wick en garde un nouveau. Tu penses le trouver ?",
        "notifStreakTitle": "Ta flamme va s'éteindre",
        "notifStreakBody": "%d jours d'affilée — le mot du jour n'est toujours pas trouvé.",
        "reminderOfferTitle": "Un rappel demain ?",
        "reminderOfferBody": "Wick peut te prévenir quand le prochain mot est prêt. Tu peux changer l'heure dans les Réglages.",
        "reminderOfferYes": "Me le rappeler",
        "notNow": "Pas maintenant",
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
        "languagePickHint": "Choisis la langue des menus.",
        "setPlayIn": "Jouer en %@",
        "raceTheirWord": "Il cherchait \u{201C}%@\u{201D} (%@).",
        "setPlayInHintOn": "Le mot, tes essais et Wick sont dans cette langue. Désactive pour jouer en anglais avec les sens affichés.",
        "setPlayInHintOff": "Menus et sens des mots seulement. Le mot, tes essais et Wick restent en anglais, pour apprendre l'anglais en jouant. Active pour jouer la manche dans cette langue.",
        // How to play
        "letsPlay": "C'est parti !",
        "tutTitle": "Tutoriel",
        "tutSkip": "Passer",
        "tutGuessAny": "Je cache un mot secret. Tape n'importe quel mot et envoie-le !",
        "tutNotAWord": "Je ne connais pas ce mot. Essaie un vrai mot !",
        "tutHeat": "%@ ! Voilà à quel point tu es proche. Bleu, c'est loin. Rouge, c'est tout près. Maintenant, essaie un mot plus chaud !",
        "tutColder": "Plus froid ! Essaie un mot au sens très différent.",
        "tutWarmer": "Plus chaud ! Tu te rapproches.",
        "tutAsk": "Maintenant, mon coup secret : pose-moi une question par oui ou non !",
        "tutAskInstead": "Bien tenté ! Mais maintenant, pose-moi une question. Touche la bulle !",
        "tutAnswered": "J'ai dit %@ !",
        "tutHint": "Pose-moi ce genre de question autant que tu veux. Maintenant, touche Indice gratuit !",
        "tutHintInstead": "Bien ! Maintenant, touche le bouton Indice gratuit pour avoir un mot indice.",
        "tutHintLanded": "Cet indice est plus proche du mot secret ! Maintenant, trouve-le. Devine ou demande !",
        "tutFindIt": "Maintenant, trouve le mot secret ! Devine des mots ou pose-moi des questions.",
        "tutItsAnAnimal": "Indice : c'est un animal ! Devine lequel.",
        "tutGroupFarm": "Indice : ça vit dans une ferme.",
        "tutGroupPet": "Indice : beaucoup de gens en ont comme animal de compagnie.",
        "tutGroupWild": "Indice : c'est un grand animal sauvage.",
        "tutGroupWater": "Indice : ça vit dans l'eau ou près de l'eau.",
        "tutSound.cat": "Indice : ça fait miaou !",
        "tutSound.dog": "Indice : ça fait ouaf !",
        "tutSound.cow": "Indice : ça fait meuh et ça donne du lait !",
        "tutSound.horse": "Indice : ça hennit et on peut monter dessus !",
        "tutSound.pig": "Indice : ça fait groin groin et ça se roule dans la boue !",
        "tutSound.duck": "Indice : ça fait coin coin !",
        "tutSound.fish": "Indice : ça nage et ça a des nageoires !",
        "tutSound.frog": "Indice : ça saute et ça fait croâ !",
        "tutSound.bear": "Indice : ça adore le miel !",
        "tutSound.lion": "Indice : ça rugit et ça a une grande crinière !",
        "tutStartsWith": "Indice : ça commence par %@ !",
        "tutStartsEnds": "Indice : ça commence par %@ et finit par %@ !",
        "tutLetterCount": "Indice : %d lettres, ça commence par %@ et finit par %@ !",
        "tutAlreadyHot": "Tu es déjà tout près, pas besoin d'indice ! Maintenant, trouve le mot secret.",
        "tutLucky": "Waouh, tu l'as déjà trouvé ! Voici un nouveau mot secret.",
        "tutDoneTitle": "Tu as réussi !",
        "tutDoneWord": "Le mot secret était %@.",
        "tutDoneHeadline": "Fais la course contre les autres pour révéler le Mot Secret !",
        "tutPlayDaily": "Jouer l'énigme du jour",
        "tutFreeHint": "Indice gratuit",
        "tutCheerWarmer": "Plus chaud !",
        "tutCheerLucky": "Quelle chance !",
        "tutCheerSolved": "Trouvé !",
        "tutBadgeGuess": "Deviner",
        "tutBadgeWarmer": "Chaud",
        "tutBadgeAsk": "Demander",
        "tutBadgeHint": "Indice",
        "tutBadgeSolve": "Trouver",
        "tutStepOf": "Étape %d sur %d",
        "tutPlayTutorial": "Jouer le tutoriel",
        "tutPlayTutorialSub": "Apprends en jouant. Environ une minute.",
        "howGuessLine": "Devine des mots. Cherche la chaleur.",
        "howAskLine": "Pose-moi des questions par oui ou non.",
        "howHintLine": "Bloqué ? Un indice te donne un mot plus proche.",
        "howDailyLine": "Un nouveau mot chaque jour. Fais la course pour le trouver !",
        // Shop
        "getCoins": "Obtenir des pièces",
        "yourBalance": "Ton solde",
        "coinsAmount": "%d pièces",
        "loadingShop": "Chargement de la boutique…",
        "shopUnavailable": "Boutique indisponible",
        "shopUnavailableDetail": "Impossible de charger les packs de pièces. Vérifie ta connexion et réessaie.",
        "coinsBuyBlurb": "Les pièces offrent des indices et des questions en plus. Le mot du jour reste gratuit, et tu gagnes des pièces en jouant.",
        // Solve Replay (3.4)
        "replayShare": "Partager le replay",
        "replayTitle": "Replay",
        "replayMaking": "Création de ton replay…",
        "replaySave": "Enregistrer dans Photos",
        "replaySaving": "Enregistrement…",
        "replaySaved": "Enregistré dans Photos",
        "replaySavedHint": "Publie-le depuis Photos sur TikTok, Reels ou ailleurs.",
        "replaySaveFailed": "Impossible d'enregistrer dans Photos. Réessaie.",
        "replayDenied": "Wick a besoin de ton autorisation pour ajouter la vidéo à Photos. Tu peux l'activer dans Réglages.",
        "replayOpenSettings": "Ouvrir Réglages",
        "replayFailed": "Impossible de créer la vidéo. Réessaie.",
        "replayTryAgain": "Réessayer",
        "replayGuessOf": "Essai %d sur %d",
        "replayBest": "Meilleur",
        "replayTagline": "Pose 20 questions, révèle le mot secret avant les autres",
        "replayPlayFree": "Joue gratuitement sur",
        "replayChallenge": "Tu peux battre %d ? Joue gratuitement sur",
        "replayRevealed": "Révélé",
        "replayAnswerWas": "Le mot était %@",
        "replayRevealedAfter": "révélé après %d essais",
        "replayFastForward": "+%d essais",
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
        "homeRaceSub": "Vince chi risolve per primo",
        "raceFriendBlurb": "Finisci la parola di oggi, poi invia il link. Il tuo amico sfida il tuo fantasma, mossa dopo mossa. Non serve l'app.",
        "racePlayTodayFirst": "Gioca la parola di oggi",
        "raceSendYourRun": "Invia la tua gara",
        "raceStrangerTitle": "Gara dal vivo",
        "raceLiveNow": "Gareggia ora",
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
        "shareSectionTitle": "Condividi",
        "shareTileResult": "Risultato",
        "shareTileMap": "Mappa",
        "shareTileVideo": "Video",
        "shareSolvedIn": "risolto in %d",
        "shareQuestions.one": "%d domanda",
        "shareQuestions.other": "%d domande",
        "shareHints.one": "%d indizio",
        "shareHints.other": "%d indizi",
        "shareTagline": "Wick · fai 20 domande, svela per primo la parola segreta",
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
        "musicToggle": "Musica di gara",
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
        "boardYourResult": "Il tuo risultato di oggi",
        "boardSubmit": "Invia alla classifica",
        "boardSubmitNote": "Non viene pubblicato nulla finché non tocchi Invia. Comparirai con un nome automatico, mai il tuo.",
        "boardWaiting": "Il tuo punteggio verrà pubblicato appena torni online.",
        "boardGaveUp": "Ti sei arreso",
        "boardTitle": "La gara di oggi",
        "boardOpen": "Classifica di oggi",
        "boardRankLine": "Sei #%d su %d oggi",
        "boardPlayers": "%d in gara oggi",
        "boardEmpty": "Nessuno ha ancora risolto la parola di oggi. Sii il primo!",
        "boardSolveFirst": "Risolvi la parola di oggi per entrare in classifica.",
        "boardNewName": "Nuovo nome",
        "boardYou": "Tu",
        "boardOffline": "Impossibile caricare la classifica ora.",
        "boardRacingAs": "Gareggi come %@",
        "boardColGuesses": "Tentativi",
        "boardColTime": "Tempo",
        "boardRules": "Vince chi usa meno tentativi. Ogni indizio conta come un tentativo in più. A parità vince il tempo più veloce. Arrendersi ti mette in fondo. Conta solo il tuo primo risultato del giorno.",
        "weeklyHeader": "Questa settimana, tutti",
        "weeklyTopGuesses": "Parole più provate questa settimana",
        "weeklyTopQuestions": "Domande più fatte",
        "weeklyResets": "Tutti i giocatori. Si azzera il lunedì.",
        "weeklyEmpty": "Non ci sono ancora abbastanza partite questa settimana.",
        "weeklyOffline": "Impossibile caricare le liste ora.",
        "weeklySettingsHeader": "Statistiche settimanali",
        "shareWordsToggle": "Aggiungi le mie parole alle statistiche",
        "shareWordsBlurb": "Aggiunge i tuoi tentativi freddi e le domande che scrivi al Custode alle liste settimanali di tutti. Inviati senza alcun identificativo. I tentativi vicini e tutto ciò che nomina la risposta restano sul tuo telefono.",
        "dailyReminder": "Promemoria giornaliero",
        "time": "Ora",
        "reminderBlurb": "Un gentile avviso quando la parola del giorno è pronta.",
        "notifDailyTitle": "La parola di oggi è pronta",
        "notifDailyBody": "Wick ne custodisce una nuova. Pensi di indovinarla?",
        "notifStreakTitle": "La tua fiamma sta per spegnersi",
        "notifStreakBody": "%d giorni di fila — la parola di oggi è ancora irrisolta.",
        "reminderOfferTitle": "Un promemoria domani?",
        "reminderOfferBody": "Wick può avvisarti quando la prossima parola è pronta. Puoi cambiare l'orario nelle Impostazioni.",
        "reminderOfferYes": "Avvisami",
        "notNow": "Non ora",
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
        "languagePickHint": "Scegli la lingua dei menu.",
        "setPlayIn": "Gioca in %@",
        "raceTheirWord": "Cercava \u{201C}%@\u{201D} (%@).",
        "setPlayInHintOn": "La parola, i tuoi tentativi e Wick sono in questa lingua. Disattiva per giocare in inglese con i significati visibili.",
        "setPlayInHintOff": "Solo menu e significati. La parola, i tuoi tentativi e Wick restano in inglese, così impari l'inglese giocando. Attiva per giocare il round in questa lingua.",
        // How to play
        "letsPlay": "Giochiamo!",
        "tutTitle": "Tutorial",
        "tutSkip": "Salta",
        "tutGuessAny": "Nascondo una parola segreta. Scrivi una parola qualsiasi e inviala!",
        "tutNotAWord": "Non conosco questa parola. Provane una vera!",
        "tutHeat": "%@! Ecco quanto sei vicino. Blu è lontano, rosso è vicinissimo. Ora prova una parola più calda!",
        "tutColder": "Più freddo! Prova una parola dal significato molto diverso.",
        "tutWarmer": "Più caldo! Ti stai avvicinando.",
        "tutAsk": "Ora la mia mossa segreta: fammi una domanda da sì o no!",
        "tutAskInstead": "Bel tentativo! Ma ora fammi una domanda. Tocca la nuvoletta!",
        "tutAnswered": "Ho detto %@!",
        "tutHint": "Chiedimi cose così tutte le volte che vuoi. Ora tocca Indizio gratis!",
        "tutHintInstead": "Bene! Ora tocca il pulsante Indizio gratis per avere una parola indizio.",
        "tutHintLanded": "Quell'indizio è più vicino alla parola segreta! Ora trovala. Indovina o chiedi!",
        "tutFindIt": "Ora trova la parola segreta! Indovina parole o fammi domande.",
        "tutItsAnAnimal": "Indizio: è un animale! Indovina quale.",
        "tutGroupFarm": "Indizio: vive in una fattoria.",
        "tutGroupPet": "Indizio: tante persone ne hanno uno come animale domestico.",
        "tutGroupWild": "Indizio: è un grande animale selvatico.",
        "tutGroupWater": "Indizio: vive nell'acqua o vicino all'acqua.",
        "tutSound.cat": "Indizio: fa miao!",
        "tutSound.dog": "Indizio: fa bau!",
        "tutSound.cow": "Indizio: fa muu e dà il latte!",
        "tutSound.horse": "Indizio: nitrisce e lo puoi cavalcare!",
        "tutSound.pig": "Indizio: grugnisce e si rotola nel fango!",
        "tutSound.duck": "Indizio: fa qua qua!",
        "tutSound.fish": "Indizio: nuota e ha le pinne!",
        "tutSound.frog": "Indizio: salta e fa cra cra!",
        "tutSound.bear": "Indizio: adora il miele!",
        "tutSound.lion": "Indizio: ruggisce e ha una grande criniera!",
        "tutStartsWith": "Indizio: inizia con %@!",
        "tutStartsEnds": "Indizio: inizia con %@ e finisce con %@!",
        "tutLetterCount": "Indizio: ha %d lettere, inizia con %@ e finisce con %@!",
        "tutAlreadyHot": "Sei già vicinissimo, niente indizio! Ora trova la parola segreta.",
        "tutLucky": "Wow, l'hai già trovata! Ecco una nuova parola segreta.",
        "tutDoneTitle": "Ce l'hai fatta!",
        "tutDoneWord": "La parola segreta era %@.",
        "tutDoneHeadline": "Sfida gli altri a svelare la Parola Segreta!",
        "tutPlayDaily": "Gioca il puzzle di oggi",
        "tutFreeHint": "Indizio gratis",
        "tutCheerWarmer": "Più caldo!",
        "tutCheerLucky": "Che fortuna!",
        "tutCheerSolved": "Trovata!",
        "tutBadgeGuess": "Indovina",
        "tutBadgeWarmer": "Caldo",
        "tutBadgeAsk": "Chiedi",
        "tutBadgeHint": "Indizio",
        "tutBadgeSolve": "Risolvi",
        "tutStepOf": "Passo %d di %d",
        "tutPlayTutorial": "Gioca il tutorial",
        "tutPlayTutorialSub": "Impara giocando. Circa un minuto.",
        "howGuessLine": "Indovina parole. Cerca il caldo.",
        "howAskLine": "Fammi domande da sì o no.",
        "howHintLine": "Bloccato? Un indizio ti dà una parola più vicina.",
        "howDailyLine": "Una parola nuova ogni giorno. Sfida tutti a risolverla!",
        // Shop
        "getCoins": "Ottieni monete",
        "yourBalance": "Il tuo saldo",
        "coinsAmount": "%d monete",
        "loadingShop": "Caricamento del negozio…",
        "shopUnavailable": "Negozio non disponibile",
        "shopUnavailableDetail": "Impossibile caricare i pacchetti di monete. Controlla la connessione e riprova.",
        "coinsBuyBlurb": "Le monete danno indizi e domande extra. La parola del giorno resta gratis, e guadagni monete giocando.",
        // Solve Replay (3.4)
        "replayShare": "Condividi replay",
        "replayTitle": "Replay",
        "replayMaking": "Sto creando il tuo replay…",
        "replaySave": "Salva in Foto",
        "replaySaving": "Salvataggio…",
        "replaySaved": "Salvato in Foto",
        "replaySavedHint": "Pubblicalo da Foto su TikTok, Reels o dove vuoi.",
        "replaySaveFailed": "Impossibile salvare in Foto. Riprova.",
        "replayDenied": "Wick ha bisogno del permesso per aggiungere il video a Foto. Puoi attivarlo in Impostazioni.",
        "replayOpenSettings": "Apri Impostazioni",
        "replayFailed": "Impossibile creare il video. Riprova.",
        "replayTryAgain": "Riprova",
        "replayGuessOf": "Tentativo %d di %d",
        "replayBest": "Migliore",
        "replayTagline": "Fai 20 domande, svela per primo la parola segreta",
        "replayPlayFree": "Gioca gratis su",
        "replayChallenge": "Riesci a battere %d? Gioca gratis su",
        "replayRevealed": "Rivelata",
        "replayAnswerWas": "La parola era %@",
        "replayRevealedAfter": "rivelata dopo %d tentativi",
        "replayFastForward": "+%d tentativi",
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
        "homeRaceSub": "Wer zuerst löst, gewinnt",
        "raceFriendBlurb": "Löse das heutige Wort und schick den Link. Dein Freund tritt gegen deinen Geist an, Zug um Zug. Keine App nötig.",
        "racePlayTodayFirst": "Spiel das heutige Wort",
        "raceSendYourRun": "Sende dein Rennen",
        "raceStrangerTitle": "Live-Rennen",
        "raceLiveNow": "Jetzt starten",
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
        "shareSectionTitle": "Teilen",
        "shareTileResult": "Ergebnis",
        "shareTileMap": "Karte",
        "shareTileVideo": "Video",
        "shareSolvedIn": "gelöst in %d",
        "shareQuestions.one": "%d Frage",
        "shareQuestions.other": "%d Fragen",
        "shareHints.one": "%d Hinweis",
        "shareHints.other": "%d Hinweise",
        "shareTagline": "Wick · stell 20 Fragen, deck als Erster das geheime Wort auf",
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
        "musicToggle": "Rennmusik",
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
        "boardYourResult": "Dein heutiges Ergebnis",
        "boardSubmit": "An die Rangliste senden",
        "boardSubmitNote": "Nichts wird veröffentlicht, bis du auf Senden tippst. Du erscheinst unter einem automatischen Namen, nie unter deinem echten.",
        "boardWaiting": "Dein Ergebnis wird veröffentlicht, sobald du wieder online bist.",
        "boardGaveUp": "Aufgegeben",
        "boardTitle": "Das heutige Rennen",
        "boardOpen": "Heutige Rangliste",
        "boardRankLine": "Du bist heute #%d von %d",
        "boardPlayers": "%d heute im Rennen",
        "boardEmpty": "Noch niemand hat das heutige Wort gelöst. Sei der Erste!",
        "boardSolveFirst": "Löse das heutige Wort, um in die Rangliste zu kommen.",
        "boardNewName": "Neuer Name",
        "boardYou": "Du",
        "boardOffline": "Die Rangliste lässt sich gerade nicht laden.",
        "boardRacingAs": "Du spielst als %@",
        "boardColGuesses": "Versuche",
        "boardColTime": "Zeit",
        "boardRules": "Die wenigsten Versuche gewinnen. Jeder Hinweis zählt als ein Versuch mehr. Bei Gleichstand gewinnt die schnellere Zeit. Wer aufgibt, landet ganz unten. Nur dein erstes Ergebnis des Tages zählt.",
        "weeklyHeader": "Diese Woche, alle",
        "weeklyTopGuesses": "Häufigste Versuche dieser Woche",
        "weeklyTopQuestions": "Häufigste Fragen",
        "weeklyResets": "Alle Spieler. Neustart am Montag.",
        "weeklyEmpty": "Diese Woche gibt es noch nicht genug Runden.",
        "weeklyOffline": "Die Listen lassen sich gerade nicht laden.",
        "weeklySettingsHeader": "Wochenstatistik",
        "shareWordsToggle": "Meine Wörter zur Wochenstatistik beitragen",
        "shareWordsBlurb": "Fügt deine kalten Versuche und die Fragen, die du dem Hüter tippst, den Wochenlisten aller hinzu. Ohne jede Kennung gesendet. Nahe Versuche und alles, was die Antwort nennt, bleiben auf deinem Telefon.",
        "dailyReminder": "Tägliche Erinnerung",
        "time": "Uhrzeit",
        "reminderBlurb": "Ein sanfter Stups, wenn das Wort des Tages bereit ist.",
        "notifDailyTitle": "Das Wort des Tages ist bereit",
        "notifDailyBody": "Wick hütet ein neues. Traust du dir das zu?",
        "notifStreakTitle": "Deine Flamme geht gleich aus",
        "notifStreakBody": "%d Tage in Folge — das heutige Wort ist noch ungelöst.",
        "reminderOfferTitle": "Morgen erinnern?",
        "reminderOfferBody": "Wick kann dir sagen, wenn das nächste Wort bereit ist. Die Uhrzeit kannst du in den Einstellungen ändern.",
        "reminderOfferYes": "Erinnere mich",
        "notNow": "Jetzt nicht",
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
        "languagePickHint": "Wähle die Sprache der Menüs.",
        "setPlayIn": "Auf %@ spielen",
        "raceTheirWord": "Gesucht wurde \u{201E}%@\u{201C} (%@).",
        "setPlayInHintOn": "Das Wort, deine Versuche und Wick sind in dieser Sprache. Ausschalten, um auf Englisch mit Bedeutungen zu spielen.",
        "setPlayInHintOff": "Nur Menüs und Wortbedeutungen. Das Wort, deine Versuche und Wick bleiben auf Englisch, damit du beim Spielen Englisch lernst. Einschalten, um die Runde in dieser Sprache zu spielen.",
        // How to play
        "letsPlay": "Los geht's!",
        "tutTitle": "Tutorial",
        "tutSkip": "Überspringen",
        "tutGuessAny": "Ich verstecke ein geheimes Wort. Tippe irgendein Wort und schick es ab!",
        "tutNotAWord": "Das Wort kenne ich nicht. Versuch ein echtes!",
        "tutHeat": "%@! So nah bist du dran. Blau ist weit weg, Rot ist ganz nah. Jetzt versuch ein wärmeres Wort!",
        "tutColder": "Kälter! Versuch ein Wort mit ganz anderer Bedeutung.",
        "tutWarmer": "Wärmer! Du kommst näher.",
        "tutAsk": "Jetzt mein Geheimtrick: Stell mir eine Ja-oder-Nein-Frage!",
        "tutAskInstead": "Guter Versuch! Aber jetzt stell mir eine Frage. Tippe auf die Sprechblase!",
        "tutAnswered": "Ich habe %@ gesagt!",
        "tutHint": "Frag mich so etwas, so oft du willst. Jetzt tippe auf Gratis-Tipp!",
        "tutHintInstead": "Gut! Jetzt tippe auf Gratis-Tipp, dann bekommst du ein Hinweiswort.",
        "tutHintLanded": "Dieser Tipp ist näher am geheimen Wort! Jetzt finde es. Rate oder frag!",
        "tutFindIt": "Jetzt finde das geheime Wort! Rate Wörter oder stell mir Fragen.",
        "tutItsAnAnimal": "Tipp: Es ist ein Tier! Rate welches.",
        "tutGroupFarm": "Tipp: Es lebt auf einem Bauernhof.",
        "tutGroupPet": "Tipp: Viele Leute haben es als Haustier.",
        "tutGroupWild": "Tipp: Es ist ein großes wildes Tier.",
        "tutGroupWater": "Tipp: Es lebt im oder am Wasser.",
        "tutSound.cat": "Tipp: Es macht miau!",
        "tutSound.dog": "Tipp: Es macht wuff!",
        "tutSound.cow": "Tipp: Es macht muh und gibt Milch!",
        "tutSound.horse": "Tipp: Es wiehert und man kann darauf reiten!",
        "tutSound.pig": "Tipp: Es grunzt und wälzt sich im Schlamm!",
        "tutSound.duck": "Tipp: Es hat einen Schnabel und schnattert!",
        "tutSound.fish": "Tipp: Es schwimmt und hat Flossen!",
        "tutSound.frog": "Tipp: Es hüpft und quakt!",
        "tutSound.bear": "Tipp: Es liebt Honig!",
        "tutSound.lion": "Tipp: Es brüllt und hat eine große Mähne!",
        "tutStartsWith": "Tipp: Es fängt mit %@ an!",
        "tutStartsEnds": "Tipp: Es fängt mit %@ an und hört mit %@ auf!",
        "tutLetterCount": "Tipp: Es hat %d Buchstaben, fängt mit %@ an und hört mit %@ auf!",
        "tutAlreadyHot": "Du bist schon ganz nah, kein Tipp nötig! Jetzt finde das geheime Wort.",
        "tutLucky": "Wow, du hast es schon gefunden! Hier ist ein neues geheimes Wort.",
        "tutDoneTitle": "Geschafft!",
        "tutDoneWord": "Das geheime Wort war %@.",
        "tutDoneHeadline": "Tritt gegen andere an und enthülle das Geheime Wort!",
        "tutPlayDaily": "Heutiges Rätsel spielen",
        "tutFreeHint": "Gratis-Tipp",
        "tutCheerWarmer": "Wärmer!",
        "tutCheerLucky": "Glück gehabt!",
        "tutCheerSolved": "Gefunden!",
        "tutBadgeGuess": "Raten",
        "tutBadgeWarmer": "Wärmer",
        "tutBadgeAsk": "Fragen",
        "tutBadgeHint": "Tipp",
        "tutBadgeSolve": "Lösen",
        "tutStepOf": "Schritt %d von %d",
        "tutPlayTutorial": "Tutorial spielen",
        "tutPlayTutorialSub": "Lerne beim Spielen. Etwa eine Minute.",
        "howGuessLine": "Rate Wörter. Werde wärmer.",
        "howAskLine": "Stell mir Ja-oder-Nein-Fragen.",
        "howHintLine": "Kommst du nicht weiter? Ein Tipp gibt dir ein näheres Wort.",
        "howDailyLine": "Jeden Tag ein neues Wort. Tritt gegen alle an!",
        // Shop
        "getCoins": "Münzen holen",
        "yourBalance": "Dein Guthaben",
        "coinsAmount": "%d Münzen",
        "loadingShop": "Shop wird geladen…",
        "shopUnavailable": "Shop nicht verfügbar",
        "shopUnavailableDetail": "Die Münzpakete konnten gerade nicht geladen werden. Prüfe deine Verbindung und versuch es erneut.",
        "coinsBuyBlurb": "Münzen kaufen extra Hinweise und Fragen. Das Tageswort bleibt gratis, und du verdienst Münzen beim Spielen.",
        // Solve Replay (3.4)
        "replayShare": "Replay teilen",
        "replayTitle": "Replay",
        "replayMaking": "Dein Replay wird erstellt…",
        "replaySave": "In Fotos sichern",
        "replaySaving": "Wird gesichert…",
        "replaySaved": "In Fotos gesichert",
        "replaySavedHint": "Poste es aus Fotos auf TikTok, Reels oder wo du willst.",
        "replaySaveFailed": "Sichern in Fotos fehlgeschlagen. Versuch es noch mal.",
        "replayDenied": "Wick braucht deine Erlaubnis, um das Video zu Fotos hinzuzufügen. Du kannst sie in den Einstellungen geben.",
        "replayOpenSettings": "Einstellungen öffnen",
        "replayFailed": "Das Video konnte nicht erstellt werden. Versuch es noch mal.",
        "replayTryAgain": "Nochmal versuchen",
        "replayGuessOf": "Versuch %d von %d",
        "replayBest": "Bester",
        "replayTagline": "Stell 20 Fragen, deck als Erster das geheime Wort auf",
        "replayPlayFree": "Spiel gratis auf",
        "replayChallenge": "Schlägst du %d? Spiel gratis auf",
        "replayRevealed": "Aufgedeckt",
        "replayAnswerWas": "Das Wort war %@",
        "replayRevealedAfter": "aufgedeckt nach %d Versuchen",
        "replayFastForward": "+%d Versuche",
    ]
}
