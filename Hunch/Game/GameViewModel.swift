//
//  GameViewModel.swift
//  Hunch
//
//  Orchestrates a round: guesses (semantic closeness), questions (on-device LLM),
//  hints, streak, solve detection, and the shareable result.
//

import Foundation
import Observation
import UIKit   // UIImage, for the shareable Reveal card

@MainActor
@Observable
final class GameViewModel {

    // Tuning knobs
    static let freeQuestionsPerGame = 3
    /// 3.3: hints are free to serve (on-device), so the first few each day are
    /// free for everyone. Once they are gone, there are no more hints that day.
    static let freeHintsPerDay = 3
    /// Stuck-player spelling aid: after this many guesses the word's first letter
    /// appears, and one more letter every `spellHintStep` guesses after that.
    static let spellHintThreshold = 50
    static let spellHintStep = 25

    /// Words for a candle's wick in each language — the trigger for Wick's
    /// self-aware easter egg (he is, after all, a little wick).
    static func wickWords(for language: GameLanguage) -> Set<String> {
        switch language {
        case .english: return ["wick"]
        case .spanish: return ["mecha", "pabilo"]
        case .french:  return ["mèche", "meche"]
        case .italian: return ["stoppino", "lucignolo"]
        case .german:  return ["docht"]
        }
    }
    /// Meta words that mean "just tell me" — Wick teases instead of scoring them.
    static let cheatWords: Set<String> = ["cheat", "cheating", "answer", "answers", "solution", "spoiler", "tellme"]

    // Round state
    private(set) var mode: GameMode = .daily
    private(set) var target: String = ""
    private(set) var targetTier: Int = 1
    /// The current round's EN/ES pair, so switching language keeps the same word.
    private var currentPair: DailyWord?
    private(set) var puzzleNumber: Int = 0

    private(set) var guesses: [Guess] = []
    private(set) var questions: [AskedQuestion] = []
    private(set) var lastSubmitted: Guess?
    /// Bumped whenever the Wick easter egg fires — GameView flickers Wick on change.
    private(set) var wickEggFlicker = 0
    private(set) var solved = false
    private(set) var revealed = false

    /// A live Race invite opened from a link — drives an app-wide
    /// `fullScreenCover` in ContentView so a tapped guesswick.com/p/… link drops
    /// straight into the match. Set by `HunchApp.onOpenURL`; cleared when dismissed.
    /// Single-player state above is untouched (C1 moat).
    var pendingLiveInvite: LiveInvite?
    /// A race alert was tapped: open the live race screen (no invite code).
    var pendingQuickRace = false

    /// Where in `DailyWords.all` this practice round's word came from, so the
    /// round can be shared as a race. -1 outside practice.
    private(set) var practicePoolIndex = -1

    /// 3.7: the Ghost Race was removed. A race link someone shared before
    /// that (https://guesswick.com/r/<run>) still opens: it plays the same word
    /// as an ordinary round, with no replay to race against. Only the link's
    /// mode and puzzle (or pool index) are used.
    func openRaceLink(_ run: GhostRun) {
        switch run.mode {
        case .daily:
            if run.ref == WordBank.dailyNumber() {
                startDaily()
            } else {
                // A past daily is deterministic from its day index.
                let day = WordBank.dayIndex() - (WordBank.dailyNumber() - run.ref)
                startArchive(dayIndex: day)
            }
        case .practice:
            guard run.ref >= 0, run.ref < DailyWords.all.count else { return }
            let pair = DailyWords.all[run.ref]
            currentPair = pair
            mode = .practice(tier: pair.tier)
            target = pair.word(for: language)
            targetTier = pair.tier
            puzzleNumber = 0
            resetRound()
            practicePoolIndex = run.ref
        }
        onHomeScreen = false
    }

    /// A stuck-player mercy: once the player has made many guesses without solving,
    /// reveal the secret word's leading letters — one at `spellHintThreshold`, then
    /// one more every `spellHintStep` guesses, never more than half the word. Returns
    /// nil until the threshold. Wick stays coy in Q&A; this is a separate, purely
    /// effort-based aid, so it never touches the leak-proofing.
    var spellingHint: String? {
        guard !solved, !revealed, !target.isEmpty else { return nil }
        let count = guesses.count
        guard count >= Self.spellHintThreshold else { return nil }
        let steps = (count - Self.spellHintThreshold) / Self.spellHintStep
        let cap = max(1, target.count / 2)          // never reveal more than half
        let reveal = min(1 + steps, cap)
        return loc.spellHint(target.prefix(reveal).uppercased())
    }

    /// How the latest guess moved relative to the player's previous best —
    /// drives the "warmer / colder" feedback on the hero card.
    private(set) var trajectory: GuessTrajectory?
    /// Consecutive known guesses that did NOT beat the running best. Used to
    /// notice when the player is stuck so Wick can proactively offer help.
    private(set) var coldStreak = 0

    /// Relative movement of a guess vs. the player's previous closest.
    struct GuessTrajectory: Equatable {
        var isFirst: Bool        // first known guess of the round
        var isNewBest: Bool      // closer than anything before it
        var warmer: Bool         // higher closeness than previous best
        var rank: Int            // this guess's rank (0 if not ready)
        var prevRank: Int        // previous best's rank (0 if none/not ready)
        /// Spots gained over the previous best (positive = closer), if known.
        var spotsGained: Int? {
            guard isNewBest, rank > 0, prevRank > 0 else { return nil }
            return max(0, prevRank - rank)
        }
    }

    var freeQuestionsRemaining = freeQuestionsPerGame
    private(set) var isAsking = false
    /// The last question the Keeper failed to answer, kept so the UI can show
    /// a tappable Retry. Cleared on a successful answer or a fresh question.
    private(set) var failedQuestion: String?
    /// Whether the failed question was typed (true) or a starter chip (false).
    private var failedQuestionTyped = true
    /// The English text a failed suggestion was sent as (3.7), so Retry sends it the same way.
    private var failedServerQuestion: String?
    /// True while a hint plays its word, so that word is not counted as typed.
    @ObservationIgnored private var submittingHint = false
    private(set) var openingClue: String?
    private(set) var isLoadingClue = false
    private var clueRequested = false
    private(set) var hintsUsed = 0
    private var hintCandidates: [(word: String, rank: Int)] = []

    // Contexto-style rank (built once per round, lazily)
    private var rankedSims: [Double] = []   // sorted high→low
    private var rankingBuilt = false
    private var rankingBuilding = false
    var transientMessage: String?

    // Persisted progression
    private(set) var streak: Int {
        didSet { UserDefaults.standard.set(streak, forKey: "hunch.streak") }
    }
    private var lastSolvedDay: Int {
        didSet { UserDefaults.standard.set(lastSolvedDay, forKey: "hunch.lastSolvedDay") }
    }

    // Persisted stats
    private(set) var solves: Int {
        didSet { UserDefaults.standard.set(solves, forKey: "hunch.solves") }
    }
    private(set) var bestStreak: Int {
        didSet { UserDefaults.standard.set(bestStreak, forKey: "hunch.bestStreak") }
    }
    private var totalSolveGuesses: Int {
        didSet { UserDefaults.standard.set(totalSolveGuesses, forKey: "hunch.totalGuesses") }
    }
    private(set) var bestGuessCount: Int {   // fewest guesses to solve; 0 = none yet
        didSet { UserDefaults.standard.set(bestGuessCount, forKey: "hunch.bestGuessCount") }
    }
    private(set) var unlocked: Set<String> = [] {
        didSet { UserDefaults.standard.set(Array(unlocked), forKey: "hunch.achievements") }
    }

    // Free daily hints (3.3)
    private var freeHintDay: Int {
        didSet { UserDefaults.standard.set(freeHintDay, forKey: "hunch.freeHintDay") }
    }
    private var freeHintsUsedToday: Int {
        didSet { UserDefaults.standard.set(freeHintsUsedToday, forKey: "hunch.freeHintsUsed") }
    }
    /// Free hints still available today (resets with the daily word).
    var freeHintsLeft: Int {
        freeHintDay == WordBank.dayIndex() ? max(0, Self.freeHintsPerDay - freeHintsUsedToday) : Self.freeHintsPerDay
    }

    // Ratings-prompt gating
    private var lastReviewDay: Int {
        didSet { UserDefaults.standard.set(lastReviewDay, forKey: "hunch.lastReviewDay") }
    }
    private var reviewAsks: Int {
        didSet { UserDefaults.standard.set(reviewAsks, forKey: "hunch.reviewAsks") }
    }
    /// Bumped when the app should show the system review prompt; a view watches this.
    private(set) var reviewRequestID = 0

    var currentStreak: Int { streak }
    var averageGuesses: Double { solves > 0 ? Double(totalSolveGuesses) / Double(solves) : 0 }

    /// The language this game is played in (persisted). Drives the embedding,
    /// word bank, rank vocabulary, and Keeper prompt.
    private(set) var language: GameLanguage = GameLanguage.stored {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: GameLanguage.storageKey) }
    }

    /// The MENU language (persisted): every UI string, verdict badge and hint.
    /// Matches the web app since 2.0: the Settings picker sets this, and the
    /// "Play in X" toggle decides whether the round itself is in this language
    /// or in English with meanings shown (Learn mode) so the player picks up
    /// English while playing.
    private(set) var uiLanguage: GameLanguage = GameLanguage.storedUI {
        didSet { UserDefaults.standard.set(uiLanguage.rawValue, forKey: GameLanguage.uiStorageKey) }
    }

    /// "Play in X" (persisted). On: the round is played in the menu language.
    /// Off: an English round with each guess translated into the menu language.
    private(set) var playNative: Bool = GameLanguage.storedPlayNative {
        didSet { UserDefaults.standard.set(playNative, forKey: GameLanguage.playNativeKey) }
    }

    /// Change the menu language. The play language follows the "Play in X"
    /// choice, so this may also restart the round in a new language.
    func setUILanguage(_ new: GameLanguage) {
        guard new != uiLanguage else { return }
        uiLanguage = new
        applyLanguageChoice()
    }

    /// Flip "Play in X" for the current menu language.
    func setPlayNative(_ on: Bool) {
        guard on != playNative else { return }
        playNative = on
        applyLanguageChoice()
    }

    /// Make the play language and Learn mode agree with the menu language and
    /// the "Play in X" toggle. English menus always play in English with no
    /// Learn mode, exactly as before.
    private func applyLanguageChoice() {
        if playNative || uiLanguage == .english {
            learnMode = false
            setLanguage(uiLanguage)
        } else {
            setLearnLanguage(uiLanguage)
            learnMode = true
            setLanguage(.english)
        }
    }

    /// Learn mode: show each guess (and the revealed answer) translated into the
    /// partner language, so the player picks up vocabulary while playing.
    var learnMode: Bool = UserDefaults.standard.bool(forKey: "hunch.learnMode") {
        didSet { UserDefaults.standard.set(learnMode, forKey: "hunch.learnMode") }
    }
    /// The language being picked up in Learn mode. Independent of the play
    /// language since 1.8 (a French speaker can play in French and learn
    /// English). Defaults to the natural partner of the play language until
    /// the player picks one; a stored choice equal to the play language is
    /// ignored (you can't learn the language you're playing in).
    private var storedLearnLanguage: GameLanguage? = GameLanguage.storedLearn(playing: GameLanguage.stored)
    var learnLanguage: GameLanguage {
        if let picked = storedLearnLanguage, picked != language { return picked }
        return GameLanguage.defaultLearn(playing: language)
    }
    func setLearnLanguage(_ new: GameLanguage) {
        guard new != language else { return }
        storedLearnLanguage = new
        UserDefaults.standard.set(new.rawValue, forKey: GameLanguage.learnStorageKey)
    }
    /// The play-language form of a guess typed in a language this round
    /// accepts: the learn language when Learn mode is on, English otherwise.
    /// Exact same-language lookups only — never homograph guessing. nil when
    /// the guess isn't a known word of the accepted language.
    private func crossLanguageTranslation(of typed: String) -> String? {
        let source: GameLanguage = learnMode ? learnLanguage : .english
        guard source != language else { return nil }
        return DailyWords.translate(typed, from: source, to: language)
    }

    /// A word translated into the learn language, if it's a known pair and
    /// Learn mode is on. nil otherwise (so callers can skip the arrow entirely).
    /// The word is always in the PLAY language here (guesses are normalized
    /// before display), so translate from it exactly — never homograph-guess.
    func learnTranslation(_ word: String) -> String? {
        guard learnMode else { return nil }
        return DailyWords.translate(word, from: language, to: learnLanguage)
    }

    private var engine = SemanticEngine(language: GameLanguage.stored)
    private var keeper = QuestionService(language: GameLanguage.stored)
    /// Background loop that re-attempts loading a missing/degraded embedding
    /// (Apple's non-English vectors are download-on-demand — the first round in
    /// a new language can beat the download). nil when not retrying.
    private var vocabularyRetryTask: Task<Void, Never>?
    /// 1.9 — drives On-Demand Resource downloads of our bundled embeddings and
    /// the progress modal. The vocabulary-retry loop above still swaps the engine
    /// in once a pack lands, and Apple's vectors remain the offline fallback.
    let assetLoader = EmbeddingAssetLoader.shared
    /// The language in play before the current download started, so cancelling the
    /// download can revert to something that actually scores.
    private var languageBeforeDownload: GameLanguage = .english

    init() {
        let d = UserDefaults.standard
        streak = d.object(forKey: "hunch.streak") as? Int ?? 0
        lastSolvedDay = d.object(forKey: "hunch.lastSolvedDay") as? Int ?? -1
        solves = d.integer(forKey: "hunch.solves")
        bestStreak = d.integer(forKey: "hunch.bestStreak")
        totalSolveGuesses = d.integer(forKey: "hunch.totalGuesses")
        bestGuessCount = d.integer(forKey: "hunch.bestGuessCount")
        unlocked = Set(d.stringArray(forKey: "hunch.achievements") ?? [])
        lastReviewDay = d.object(forKey: "hunch.lastReviewDay") as? Int ?? -100_000
        reviewAsks = d.integer(forKey: "hunch.reviewAsks")
        freeHintDay = d.object(forKey: "hunch.freeHintDay") as? Int ?? -1
        freeHintsUsedToday = d.integer(forKey: "hunch.freeHintsUsed")

        startDaily()
        // Kick an ODR download if the stored language needs one (silent at launch —
        // the retry loop + scoring banner cover it; no modal over a cold start).
        assetLoader.ensure(language, presentModal: false)
        startVocabularyRetryIfNeeded()

        // A fresh install often opens BEFORE iCloud has handed over the player's
        // progression — it arrives seconds later. `CloudSync.bootstrap()` (called
        // from `HunchApp.init`) merges it into UserDefaults and posts this; we
        // re-read so the streak on screen isn't a stale zero.
        CloudSync.onMerge = { [weak self] in self?.adoptCloudState() }
        refreshReminders()

        // 3.6: a brand-new player opens straight into the tutorial level, not
        // Home: Wick is asking for a word within a couple of seconds. A link
        // that arrives on the same launch still wins (ContentView covers it).
        if TutorialFlags.shouldAutoStart(solves: solves) {
            startTutorial()
        }
    }

    // MARK: - Vocabulary auto-retry

    /// If the current language's embedding isn't usable yet, quietly re-attempt
    /// the load every few seconds (for ~3 minutes) until it appears — the OS
    /// downloads the vectors on demand, so getting online mid-round should just
    /// fix itself. On success: swap in the fresh engine, rebuild the rank list,
    /// and tell the player they're good to go. Re-armed by every blocked guess,
    /// so it can never permanently give up while the player is still trying.
    private func startVocabularyRetryIfNeeded() {
        guard !engine.hasVocabulary, vocabularyRetryTask == nil else { return }
        vocabularyRetryTask = Task { [weak self] in
            defer { self?.vocabularyRetryTask = nil }
            for attempt in 0..<45 {
                try? await Task.sleep(for: .seconds(4))
                guard let self, !Task.isCancelled else { return }
                let fresh = SemanticEngine(language: self.language)
                guard fresh.hasVocabulary else {
                    // Still nothing after ~25s: being online may not be enough —
                    // iOS fetches a language's dictionary when the DEVICE uses
                    // the language. Tell the player the keyboard trick once.
                    if attempt == 6 { self.transientMessage = self.loc.scoringKeyboardHint }
                    continue
                }
                self.engine = fresh
                self.rankedSims = []
                self.rankingBuilt = false
                self.rankingBuilding = false
                self.ensureRanking()
                self.transientMessage = self.loc.vocabularyReady
                Haptics.success()
                return
            }
        }
    }

    // MARK: - Language

    /// Key for the saved daily board, namespaced by language so the English and
    /// Spanish dailies don't overwrite each other.
    private var dailyStateKey: String { "hunch.dailyState.\(language.rawValue)" }

    /// Switches the game language: rebuilds the engine/Keeper for the new
    /// embedding + word bank, then restarts the current mode. English ⇄ Spanish.
    func setLanguage(_ new: GameLanguage) {
        guard new != language else { return }
        languageBeforeDownload = language
        language = new
        engine = SemanticEngine(language: new)
        keeper = QuestionService(language: new)
        // Explicit switch → surface the download modal if this language's pack
        // isn't present yet. No-op when the model is already available (bundled or
        // previously downloaded), or when the language isn't ODR-managed.
        assetLoader.ensure(new, presentModal: true)
        vocabularyRetryTask?.cancel()
        vocabularyRetryTask = nil
        startVocabularyRetryIfNeeded()
        // Pending reminders still carry the OLD language's text — rewrite them.
        rescheduleReminders()
        switch mode {
        case .daily:
            // Same day → same pair, just shown translated. Restores this
            // language's saved board if you'd already started today.
            startDaily()
        case .practice(let tier):
            // Keep the SAME practice word (translated) — don't reroll a new one.
            if let pair = currentPair {
                targetTier = pair.tier
                target = pair.word(for: new)
                resetRound()
            } else {
                startPractice(tier: tier)
            }
        case .archive(let day):
            // Same past word, shown translated. Stays ephemeral.
            if let pair = currentPair {
                targetTier = pair.tier
                target = pair.word(for: new)
                resetRound()
            } else {
                startArchive(dayIndex: day)
            }
        case .duel:
            // A duel is locked to its own language (the word index is per-language),
            // so switching language leaves the duel and drops to today's daily.
            startDaily()
        case .tutorial:
            // Same animal, new language, from the top.
            startTutorial(animal: currentPair, track: false)
        }
    }

    /// Cancel the in-flight embedding download (from the modal's Cancel button) and
    /// revert to a language that scores — the one in play before the switch, or
    /// English as a guaranteed-available fallback.
    func cancelPendingDownload() {
        guard let downloading = assetLoader.promptLanguage else { return }
        assetLoader.cancel(downloading)
        let fallback: GameLanguage = (languageBeforeDownload == downloading) ? .english : languageBeforeDownload
        if fallback != language { setLanguage(fallback) }
    }

    /// Per-language verdict labels for the canonical tokens the Keeper emits.
    /// Tokens are canonical English, so English needs no table; a language
    /// without a table shows the token as-is. Add an entry per new language.
    private static let verdictTables: [GameLanguage: [String: String]] = [
        .spanish: [
            "yes": "Sí",
            "no": "No",
            "sort of": "Más o menos",
            "idk": "No lo sé",
            "won't say": "No lo diré",
        ],
        .french: [
            "yes": "Oui",
            "no": "Non",
            "sort of": "Plus ou moins",
            "idk": "Je ne sais pas",
            "won't say": "Je ne dirai rien",
        ],
        .italian: [
            "yes": "Sì",
            "no": "No",
            "sort of": "Più o meno",
            "idk": "Non lo so",
            "won't say": "Non lo dirò",
        ],
        .german: [
            "yes": "Ja",
            "no": "Nein",
            "sort of": "Teilweise",
            "idk": "Weiß nicht",
            "won't say": "Sag ich nicht",
        ],
    ]

    /// Localized label for a canonical verdict token ("Yes"/"No"/"Sort of"/…).
    func displayVerdict(_ token: String) -> String {
        Self.verdictTables[uiLanguage]?[token.lowercased()] ?? token
    }

    /// UI string table for the MENU language (not the play language).
    var loc: Loc { Loc(lang: uiLanguage) }

    // MARK: - Round setup

    // MARK: - Top-level navigation (Home hub ⇄ game)

    /// Whether the Home menu is showing. Launch on Home; entering any mode flips
    /// it off, the in-game "Home" button flips it back on. The round state lives
    /// on the view model, so leaving to Home and returning never loses progress.
    var onHomeScreen = true

    func goHome() { onHomeScreen = true }

    /// Play today's daily from Home (startDaily also runs at launch to prep the
    /// board, so the screen flip lives here rather than inside startDaily).
    func playDaily() {
        startDaily()
        onHomeScreen = false
    }

    func startDaily() {
        let entry = pickDaily()
        mode = .daily
        target = entry.word
        targetTier = entry.tier
        puzzleNumber = WordBank.dailyNumber()

        // Restore today's board if we have it; otherwise start fresh.
        if let data = UserDefaults.standard.data(forKey: dailyStateKey),
           let saved = try? JSONDecoder().decode(DailyState.self, from: data),
           saved.day == WordBank.dayIndex() {
            restore(saved)
        } else {
            resetRound()
            saveDailyState()
            Events.track(.dailyStart, n: puzzleNumber)
        }
    }

    func startPractice(tier: Int) {
        // Practice is free so players can always play.
        let entry = pickPractice(maxTier: tier)
        mode = .practice(tier: tier)
        target = entry.word
        targetTier = entry.tier
        puzzleNumber = 0
        resetRound()
        onHomeScreen = false
    }

    /// Replay a past daily from the archive. The word is deterministic from the
    /// day index, so no stored word is needed. Ephemeral by design: it never
    /// overwrites today's saved board (saveDailyState guards on `.daily`) and
    /// never advances the streak or inflates stats
    /// (see `markSolved` / `recordRound`).
    func startArchive(dayIndex day: Int) {
        // Clamp into the valid window: launch day … yesterday.
        let clamped = min(max(day, WordBank.launchDayIndex), WordBank.dayIndex() - 1)
        let pair = DailyWords.daily(for: clamped)
        currentPair = pair
        mode = .archive(dayIndex: clamped)
        target = pair.word(for: language)
        targetTier = pair.tier
        puzzleNumber = WordBank.dailyNumber(forDayIndex: clamped)
        resetRound()
        onHomeScreen = false
    }

    /// The current duel, if we're in one (for the UI to share/compare).
    var currentDuel: DuelPayload? {
        if case let .duel(p) = mode { return p }
        return nil
    }

    /// Start a Friend Duel from a decoded code. The word is a curated bank entry
    /// resolved by index in the duel's OWN language (a duel is language-locked),
    /// so it scores identically on both players' devices. Ephemeral like archive:
    /// no streak, stats, or history (see `markSolved` / `recordRound`).
    func startDuel(_ payload: DuelPayload) {
        let entries = WordBank.entries(for: payload.language)
        guard entries.indices.contains(payload.wordIndex) else { return }
        let entry = entries[payload.wordIndex]

        // Rebuild the engine/Keeper for the duel's language if the app is in a
        // different one (mirrors setLanguage, minus the mode restart — we set the
        // duel up ourselves below). Downloads the pack if needed; the retry loop
        // swaps the engine in when it lands.
        if language != payload.language {
            language = payload.language
            engine = SemanticEngine(language: payload.language)
            keeper = QuestionService(language: payload.language)
            assetLoader.ensure(payload.language, presentModal: true)
        }

        currentPair = nil           // duels have no DailyWords translation pair
        mode = .duel(payload)
        target = entry.word
        targetTier = entry.tier
        puzzleNumber = 0
        vocabularyRetryTask?.cancel()
        vocabularyRetryTask = nil
        startVocabularyRetryIfNeeded()
        resetRound()
        onHomeScreen = false
    }

    /// The result code to send back after finishing a duel (nil if not in one or
    /// the round hasn't ended).
    func duelResultCode() -> String? {
        guard case let .duel(payload) = mode, solved || revealed else { return nil }
        let result = DuelResult(language: payload.language,
                                wordIndex: payload.wordIndex,
                                solved: solved,
                                gaveUp: revealed && !solved,
                                guessCount: guesses.filter(\.known).count)
        return DuelCode.encode(result)
    }

    // MARK: - Tutorial (3.6)
    //
    // The hands-on tutorial level. Steps, notes and animals are defined in
    // Game/Tutorial.swift; the coaching UI is Views/TutorialCoach.swift. The
    // logic lives here because it reacts to the round's private state.
    //
    // Sandbox rules, enforced where each side effect happens: `markSolved`
    // returns before rewards, `recordRound` skips it, `saveDailyState` only
    // saves `.daily`, `revealHint` spends nothing, and the weekly tally,
    // coaching tips and Wick's offer cards all stand down in `.tutorial`.

    /// The step the player is on. Meaningless outside `.tutorial`.
    private(set) var tutorialStep: TutorialStep = .firstGuess
    /// What just happened, so Wick can react before restating the goal.
    private(set) var tutorialNote: TutorialNote = .none
    /// Tries at the current step that didn't complete it. In the solve step it
    /// drives the escalating clues (animal, then letters).
    private(set) var tutorialMisses = 0
    /// Bumped on every step change; the coach plays its level-up beat on it.
    private(set) var tutorialBeat = 0
    /// Bumped for a big on-screen cheer; `tutorialCheerKind` says which.
    private(set) var tutorialCheerID = 0
    private(set) var tutorialCheerKind: TutorialCheer = .warmer
    /// Animals used this run, so a bonus animal is never a repeat.
    private var tutorialUsed: Set<String> = []
    /// The first guess's heat word, frozen when step 2 starts, so Wick's line
    /// doesn't change mid-sentence when the rank list finishes building.
    private var tutorialFirstHeat = ""

    /// Start (or restart) the tutorial. `animal` keeps the same animal (a
    /// language switch); nil picks a random one of the ten.
    func startTutorial(animal: DailyWord? = nil, track: Bool = true) {
        let pick = animal ?? TutorialAnimals.random()
        currentPair = pick
        mode = .tutorial
        target = pick.word(for: language)
        targetTier = pick.tier
        puzzleNumber = 0
        practicePoolIndex = -1
        resetRound()
        tutorialStep = .firstGuess
        tutorialNote = .none
        tutorialMisses = 0
        tutorialUsed = [pick.en]
        tutorialBeat &+= 1
        onHomeScreen = false
        if track { Events.track(.tutorialStart) }
    }

    /// The Skip button (any step). Marks the tutorial done and lands on Home
    /// with today's board restored.
    func skipTutorial() {
        guard mode == .tutorial else { return }
        if tutorialStep != .done {
            // `n` carries the step they left on (1...5), to see where kids drop off.
            Events.track(.tutorialSkip, n: tutorialStep.rawValue)
        }
        markTutorialDone()
        startDaily()
        onHomeScreen = true
    }

    /// "Play today's puzzle" on the finished tutorial.
    func leaveTutorialForDaily() {
        markTutorialDone()
        playDaily()
    }

    /// "Is it alive?" in the play language: the question step 3 offers to type.
    var tutorialQuestion: String {
        let item = StarterQuestions.categories.flatMap(\.items).first { $0.key == .alive }
        return item.map { StarterQuestions.localizedFull($0, language) } ?? "Is it alive?"
    }

    /// The solve step is close to a giveaway on purpose: every wrong guess
    /// unlocks a stronger clue. The word itself is never spelled out.
    ///   0 misses: it's an animal
    ///   1: where it lives (farm, pet, wild, water)
    ///   2: its sound or giveaway trait ("it hops and says ribbit")
    ///   3: it starts with F
    ///   4: it starts with F and ends with G
    ///   5+: it has 4 letters, starts with F and ends with G
    var tutorialClues: [String] {
        guard tutorialStep == .solve else { return [] }
        let L = loc
        var out = [L.tutItsAnAnimal]
        let m = tutorialMisses
        guard let pair = currentPair, let info = TutorialAnimals.clues[pair.en] else { return out }
        if m >= 1 {
            switch info.group {
            case .farm:  out.append(L.tutGroupFarm)
            case .pet:   out.append(L.tutGroupPet)
            case .wild:  out.append(L.tutGroupWild)
            case .water: out.append(L.tutGroupWater)
            }
        }
        if m >= 2 { out.append(L.tutClue(info.soundKey)) }
        let word = target.uppercased()
        if m >= 3, let first = word.first {
            let last = String(word.last ?? first)
            if m == 3 || word.count < 2 {
                out.append(L.tutStartsWith(String(first)))
            } else if m == 4 {
                out.append(L.tutStartsEnds(String(first), last))
            } else {
                out.append(L.tutLetterCount(word.count, String(first), last))
            }
        }
        return out
    }

    /// What Wick says right now. Short on purpose: a reaction, then the goal.
    var tutorialLine: String {
        let L = loc
        switch tutorialStep {
        case .firstGuess:
            switch tutorialNote {
            case .notAWord: return L.tutNotAWord
            case .lucky:    return L.tutLucky + " " + L.tutGuessAny
            default:        return L.tutGuessAny
            }
        case .warmer:
            switch tutorialNote {
            case .notAWord: return L.tutNotAWord
            case .colder:   return L.tutColder
            default:        return L.tutHeat(tutorialFirstHeat)
            }
        case .ask:
            switch tutorialNote {
            case .warmer:     return L.tutWarmer + " " + L.tutAsk
            case .askInstead: return L.tutAskInstead
            case .notAWord:   return L.tutNotAWord + " " + L.tutAsk
            case .lucky:      return L.tutLucky + " " + L.tutAsk
            default:          return L.tutAsk
            }
        case .hint:
            switch tutorialNote {
            case .answered(let verdict): return L.tutAnswered(displayVerdict(verdict)) + " " + L.tutHint
            case .hintInstead:           return L.tutHintInstead
            case .notAWord:              return L.tutNotAWord + " " + L.tutHint
            case .lucky:                 return L.tutLucky + " " + L.tutHint
            default:                     return L.tutHint
            }
        case .solve:
            // Always ends on the newest clue; a short reaction in front of it.
            let clue = tutorialClues.last ?? L.tutFindIt
            switch tutorialNote {
            case .answered(let verdict): return L.tutAnswered(displayVerdict(verdict)) + " " + clue
            case .alreadyHot:            return L.tutAlreadyHot + " " + clue
            case .notAWord:              return L.tutNotAWord + " " + clue
            default:                     return clue
            }
        case .done:
            return L.tutDoneTitle
        }
    }

    /// The latest guess's heat word ("Freezing" ... "Boiling"), localized.
    var tutorialHeatName: String {
        guard let last = lastSubmitted, last.known else { return loc.heat("Cold") }
        let r = rank(forScore: last.score)
        return r > 0 ? loc.heat(HunchTheme.rankLabel(r)) : loc.heat(HunchTheme.label(for: last.score))
    }

    private func advanceTutorial(to step: TutorialStep, note: TutorialNote) {
        tutorialStep = step
        tutorialNote = note
        tutorialMisses = 0
        tutorialBeat &+= 1
        Feedback.play(.levelUp)
    }

    private func cheerTutorial(_ kind: TutorialCheer) {
        tutorialCheerKind = kind
        tutorialCheerID &+= 1
    }

    /// A scored guess the player typed (never a hint's word).
    private func tutorialGuessed(isNewBest: Bool) {
        switch tutorialStep {
        case .firstGuess:
            tutorialFirstHeat = tutorialHeatName
            advanceTutorial(to: .warmer, note: .none)
        case .warmer:
            if isNewBest {
                cheerTutorial(.warmer)
                advanceTutorial(to: .ask, note: .warmer)
            } else {
                tutorialMisses += 1
                // Never a dead end: three misses and the lesson moves on.
                if tutorialMisses >= 3 {
                    advanceTutorial(to: .ask, note: .movedOn)
                } else {
                    tutorialNote = .colder
                }
            }
        case .ask:
            tutorialNote = .askInstead
        case .hint:
            tutorialNote = .hintInstead
        case .solve:
            tutorialNote = isNewBest ? .warmer : .colder
            tutorialMisses += 1
            Haptics.soft()   // a new clue just unlocked
        case .done:
            break
        }
    }

    /// Wick answered a question. Only step 3 is waiting for one; later
    /// questions are just play.
    private func tutorialAnswered(_ verdict: String) {
        if tutorialStep == .ask {
            advanceTutorial(to: .hint, note: .answered(verdict))
        } else if tutorialStep == .solve {
            tutorialNote = .answered(verdict)
        }
    }

    /// A hint word landed.
    private func tutorialHinted() {
        if tutorialStep == .hint {
            advanceTutorial(to: .solve, note: .hintLanded)
        }
    }

    /// The hint had nothing to give (already in the top 20, or no closer word
    /// left). In step 4 that still counts: the button was found and tapped.
    private func tutorialHintNotNeeded() {
        if tutorialStep == .hint {
            advanceTutorial(to: .solve, note: .alreadyHot)
        } else {
            transientMessage = loc.topTakeIt(Self.minHintRank)
        }
    }

    /// Found the animal before step 5. Cheer, then a bonus animal carries on
    /// from the same step, so the remaining lessons still happen.
    private func tutorialLuckySolve() {
        Feedback.play(.solved)
        cheerTutorial(.lucky)
        let next = TutorialAnimals.random(excluding: tutorialUsed)
        tutorialUsed.insert(next.en)
        currentPair = next
        target = next.word(for: language)
        targetTier = next.tier
        resetRound()
        // "Warmer" needs a first guess to beat, so step 2 starts over at 1.
        if tutorialStep == .warmer { tutorialStep = .firstGuess }
        tutorialNote = .lucky
        tutorialMisses = 0
        tutorialBeat &+= 1
    }

    /// Solved in step 5: the tutorial is complete. Called from `markSolved`
    /// before anything is recorded or rewarded.
    private func finishTutorialBySolving() {
        tutorialStep = .done
        tutorialNote = .none
        tutorialBeat &+= 1
        cheerTutorial(.solved)
        markTutorialDone()
        Events.track(.tutorialDone, g: guessCount)
    }

    private func markTutorialDone() {
        TutorialFlags.done = true
        // The pre-3.6 flag too, so nothing old ever shows the sheet again.
        UserDefaults.standard.set(true, forKey: TutorialFlags.legacySeenHowToKey)
    }

    /// A player who wanders off mid-round shouldn't produce a ghost that stands
    /// still for four minutes, and a round resumed tomorrow shouldn't record a
    /// 20-hour gap. Any single pause counts as at most this. Mirrors IDLE_CAP_MS
    /// in wick-web/src/main.ts.
    private static let idleCapMs = 45_000

    /// Milliseconds of active play so far this round.
    private var elapsedMs = 0
    /// Wall clock of the last action, for measuring the next gap.
    private var lastActionAt: Date?

    /// Stamp an action with its position in the round. Call once, at the moment
    /// the player commits a guess or a question.
    private func stampNow() -> Int {
        let now = Date()
        if let last = lastActionAt {
            elapsedMs += min(max(0, Int(now.timeIntervalSince(last) * 1000)), Self.idleCapMs)
        }
        lastActionAt = now
        return elapsedMs
    }

    /// Begin (or resume) timing. Resuming keeps the time already banked and
    /// restarts the gap clock from now, so the pause isn't counted.
    private func startRoundClock(elapsedMs banked: Int = 0) {
        elapsedMs = banked
        lastActionAt = Date()
    }

    private func resetRound() {
        startRoundClock()
        guesses = []
        questions = []
        failedQuestion = nil
        lastSubmitted = nil
        trajectory = nil
        coldStreak = 0
        nudgeSnoozeUntilGuess = 0
        solved = false
        revealed = false
        freeQuestionsRemaining = Self.freeQuestionsPerGame
        hintsUsed = 0
        hintCandidates = []
        openingClue = nil
        isLoadingClue = false
        clueRequested = false
        rankedSims = []
        rankingBuilt = false
        rankingBuilding = false
        transientMessage = nil
        ensureRanking()   // start building the rank list now, off the main thread
    }

    // MARK: - Rank

    /// Builds the rank list off the main thread (10k similarities), then
    /// publishes it on the main actor so the UI re-renders with real ranks.
    private func ensureRanking() {
        guard !rankingBuilt, !rankingBuilding, !target.isEmpty else { return }
        rankingBuilding = true
        let target = self.target
        let engine = self.engine
        DispatchQueue.global(qos: .userInitiated).async {
            let sims = engine.rankingSimilarities(for: target)
            DispatchQueue.main.async {
                self.rankedSims = sims
                self.rankingBuilt = true
                self.rankingBuilding = false
            }
        }
    }

    /// Contexto-style rank for a guess score (1 = the answer). 0 = not ready yet.
    func rank(forScore score: Double) -> Int {
        if score >= 100 { return 1 }
        guard rankingBuilt, !rankedSims.isEmpty else {
            ensureRanking()   // not ready: kick it off, fall back for now
            return 0
        }
        let s = score / 100.0
        // Count similarities strictly greater than s (array is sorted high→low).
        var lo = 0, hi = rankedSims.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if rankedSims[mid] > s { lo = mid + 1 } else { hi = mid }
        }
        return lo + 2   // +1 for the answer (rank 1), +1 for the guess's own slot
    }

    var maxRank: Int { rankedSims.isEmpty ? 1 : rankedSims.count + 2 }

    private func pickDaily() -> WordBank.Entry {
        // The daily is a shared multilingual translation pair, so every language
        // gets the same concept each day, and switching language keeps the same word.
        let pair = DailyWords.daily(for: WordBank.dayIndex())
        currentPair = pair
        return WordBank.Entry(word: pair.word(for: language), tier: pair.tier)
    }

    private func pickPractice(maxTier: Int) -> WordBank.Entry {
        // Practice is also a translation pair, so it's the same concept in every
        // language and survives a language switch.
        let picked = DailyWords.randomPracticeIndexed(maxTier: maxTier)
        currentPair = picked.word
        practicePoolIndex = picked.index
        return WordBank.Entry(word: picked.word.word(for: language), tier: picked.word.tier)
    }

    // MARK: - Daily persistence (lock + resume)

    private struct DailyState: Codable {
        var day: Int
        var guesses: [Guess]
        var questions: [AskedQuestion]
        var lastSubmitted: Guess?
        var solved: Bool
        var revealed: Bool
        var hintsUsed: Int
        var freeQuestionsRemaining: Int
    }

    /// Persists the daily board so relaunching the same day restores it.
    /// Only the daily round is saved — practice rounds are ephemeral.
    private func saveDailyState() {
        guard case .daily = mode else { return }
        let state = DailyState(
            day: WordBank.dayIndex(),
            guesses: guesses,
            questions: questions,
            lastSubmitted: lastSubmitted,
            solved: solved,
            revealed: revealed,
            hintsUsed: hintsUsed,
            freeQuestionsRemaining: freeQuestionsRemaining
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: dailyStateKey)
        }
    }

    /// Today's finished daily for the race board: the first result this phone
    /// remembered, or, for a round finished before 3.6, one rebuilt from the
    /// saved board (any language; a give-up wins over a solve so it can't be
    /// dodged). The time is the stamp of the last action. Nil if today's
    /// daily isn't finished, or a pre-3.6 round has no time stamps.
    func boardResultToday() -> BoardResult? {
        let n = WordBank.dailyNumber()
        if let r = DailyBoard.shared.recorded(n) { return r }
        let today = WordBank.dayIndex()
        var found: [BoardResult] = []
        for lang in GameLanguage.all {
            guard let data = UserDefaults.standard.data(forKey: "hunch.dailyState.\(lang.rawValue)"),
                  let s = try? JSONDecoder().decode(DailyState.self, from: data),
                  s.day == today, s.solved || s.revealed else { continue }
            let stamps = s.guesses.compactMap(\.at) + s.questions.compactMap(\.at)
            guard let ms = stamps.max(), ms > 0 else { continue }
            found.append(BoardResult(n: n, g: s.guesses.count, h: s.hintsUsed, ms: ms,
                                     lang: lang.rawValue, gaveUp: !s.solved))
        }
        guard let pick = found.first(where: \.gaveUp) ?? found.first else { return nil }
        DailyBoard.shared.record(pick)   // pin it, so it can't change later
        return pick
    }

    private func restore(_ s: DailyState) {
        guesses = s.guesses
        questions = s.questions
        lastSubmitted = s.lastSubmitted
        solved = s.solved
        revealed = s.revealed
        hintsUsed = s.hintsUsed
        freeQuestionsRemaining = s.freeQuestionsRemaining
        hintCandidates = []   // rebuilt lazily on next hint
        transientMessage = nil
    }

    // MARK: - Guessing

    func submit(_ raw: String) {
        let typed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !typed.isEmpty, !solved, !revealed else { return }

        // Easter egg: guessing the candle-wick word (in any language) breaks Wick's
        // fourth wall — he IS a wick. A wink + flicker, not scored as a guess.
        if Self.wickWords(for: language).contains(typed) {
            transientMessage = loc.wickEgg
            wickEggFlicker &+= 1
            Feedback.play(.newClosest(closeness: 100))
            return
        }
        // "hunch" — a wink to the app's former name.
        if typed == "hunch" {
            transientMessage = loc.eggHunch
            wickEggFlicker &+= 1
            Feedback.play(.newClosest(closeness: 100))
            return
        }
        // "cheat" / "answer" / … — Wick playfully refuses to hand it over.
        if Self.cheatWords.contains(typed) {
            transientMessage = loc.eggCheat
            Feedback.play(.selection)
            return
        }

        // If the selected language's embedding didn't load (e.g. Spanish vectors
        // aren't present on the Simulator), say so plainly instead of rejecting
        // every guess as "unknown."
        guard engine.hasVocabulary else {
            transientMessage = loc.scoringUnavailable
            startVocabularyRetryIfNeeded()   // re-arm; resolves itself once online
            return
        }

        // Fold inflections to a canonical, in-vocabulary form ("running" → "run").
        let resolved = engine.resolveGuess(typed)
        var word = resolved.word
        var known = resolved.known
        // Cross-language forgiveness, scoped to the round's language pair:
        // with Learn mode on, ONLY the learn language is accepted (typing the
        // word you're learning should count — "apfel" in an ES→DE session —
        // but "apple" is not a Spanish guess). With Learn mode off, English
        // (the hub) is accepted, so "cat" still works in a casual Spanish game.
        if !known,
           let translated = crossLanguageTranslation(of: typed),
           engine.isKnown(translated) {
            word = translated
            known = true
        }
        let normalized = known && word != typed

        if let existing = guesses.first(where: { $0.word == word }) {
            lastSubmitted = existing
            transientMessage = normalized
                ? loc.countsAsAlready(typed, word)
                : loc.alreadyGuessed(word)
            return
        }

        // Solve on any reading of the typed word — "windmills" solves
        // "windmill", "häuser" solves "haus" — not just the canonical form.
        if word == target || engine.matchesTarget(typed, target: target) {
            // Tutorial: found it before step 5. Celebrate, then a bonus animal
            // carries on from the same step, so the lessons still happen.
            if mode == .tutorial, tutorialStep < .solve, !submittingHint {
                tutorialLuckySolve()
                return
            }
            let g = Guess(word: target, score: 100, known: true, order: guesses.count + 1,
                          seq: guesses.count + questions.count, at: stampNow())
            guesses.insert(g, at: 0)
            lastSubmitted = g
            markSolved()
            return
        }

        if known, let s = engine.score(word, target: target) {
            // Capture the previous best BEFORE inserting this guess so we can
            // tell the player whether they got warmer or colder.
            let prevKnown = guesses.filter(\.known)
            let prevBest = prevKnown.map(\.score).max()
            let prevRank = prevBest.map { rank(forScore: $0) } ?? 0

            let g = Guess(word: word, score: s, known: true, order: guesses.count + 1,
                          seq: guesses.count + questions.count, at: stampNow())
            guesses.append(g)
            guesses.sort { $0.score > $1.score }
            lastSubmitted = g

            let isNewBest = prevBest == nil || s > prevBest!
            trajectory = GuessTrajectory(
                isFirst: prevBest == nil,
                isNewBest: isNewBest,
                warmer: prevBest == nil ? true : s > prevBest!,
                rank: rank(forScore: s),
                prevRank: prevRank
            )
            coldStreak = isNewBest ? 0 : coldStreak + 1

            // 3.6 weekly Stats: only a guess that reads Cool or colder leaves
            // the phone, so the shared list never hints at the answer.
            if !submittingHint, mode != .tutorial, WordTallyRules.shouldSendGuess(rank: rank(forScore: s)) {
                WordTally.guess(word, language: language)
            }

            if normalized { transientMessage = loc.normalizedTo(typed, word) }
            Feedback.play(isNewBest ? .newClosest(closeness: s) : .guessScored(closeness: s))
            saveDailyState()
            if mode == .tutorial, !submittingHint { tutorialGuessed(isNewBest: isNewBest) }
        } else {
            lastSubmitted = Guess(word: typed, score: 0, known: false, order: guesses.count + 1, seq: nil)
            if mode == .tutorial { tutorialNote = .notAWord }
            if let suggestion = engine.spellingSuggestion(for: typed) {
                transientMessage = loc.didYouMean(typed, suggestion)
            } else {
                transientMessage = loc.notInVocabToast(typed)
            }
            Haptics.soft()
        }
    }

    var bestScore: Double { guesses.map(\.score).max() ?? 0 }
    var guessCount: Int { guesses.count }

    /// Points for "The Reveal" post-round semantic map. Built from the round's known
    /// guesses (in guess order) via the private engine; RevealMap does the geometry.
    var revealPoints: [RevealPoint] {
        let known = guesses.filter(\.known).sorted { $0.order < $1.order }
        return RevealMap.layout(words: known.map(\.word),
                                scores: known.map(\.score),
                                similarity: { engine.similarity($0, $1) })
    }

    /// How the round feed is ordered.
    enum FeedSort: String, CaseIterable {
        case recent   // newest first (the default timeline)
        case closest  // hottest guesses first, questions after
    }

    /// Persisted feed ordering, toggled from the round-log header.
    var feedSort: FeedSort = FeedSort(rawValue: UserDefaults.standard.string(forKey: "hunch.feedSort") ?? "") ?? .recent {
        didSet { UserDefaults.standard.set(feedSort.rawValue, forKey: "hunch.feedSort") }
    }

    /// Guesses and questions merged into a single play feed. Only known guesses
    /// appear (unknown ones surface as a toast, not a feed row).
    ///
    /// `.recent`: one timeline, newest first (legacy nil-seq boards sort oldest).
    /// `.closest`: guesses hottest-first (ties newest-first), then questions
    /// newest-first — so the top of the list is always your best lead.
    var feed: [FeedItem] {
        let g = guesses.filter(\.known).map(FeedItem.guess)
        let q = questions.map(FeedItem.question)
        switch feedSort {
        case .recent:
            return (g + q).sorted { $0.seq > $1.seq }
        case .closest:
            let hotFirst = guesses.filter(\.known)
                .sorted { ($0.score, $0.seq ?? 0) > ($1.score, $1.seq ?? 0) }
                .map(FeedItem.guess)
            return hotFirst + q.sorted { $0.seq > $1.seq }
        }
    }

    /// An occasional, in-character line from Wick that reacts to how the round
    /// is going — fired only at notable moments (closing in, circling, or stuck)
    /// so it feels alive without nagging. Deliberately leak-free: never hints at
    /// the word's category or properties.
    // MARK: - First-run coaching

    /// Whether the player is still learning what "close" means here.
    ///
    /// Two finished rounds, lifetime — after that the coaching goes away for
    /// good and the ordinary nudges take over.
    private var isLearningTheGame: Bool {
        RoundHistory.records.count < 2
    }

    /// A line from Wick aimed at the ONE misconception that kills first rounds.
    ///
    /// A new player types "apple", gets back "#3,412 · Freezing", and concludes
    /// the game is broken — because every other word game they have played
    /// scores letters, and this one scores meaning. `HowToPlayView` explains
    /// that before they have played, which is precisely when it does not stick.
    /// This says it at the moment it bites, in Wick's voice, using their own
    /// guess as the example.
    ///
    /// Deliberately leak-free, like every other Wick line: it talks about how
    /// scoring works, never about what the word is or is near. And it is gated
    /// on lifetime rounds, not on the current round, so a returning player never
    /// sees it again.
    var coachTip: String? {
        guard isLearningTheGame, mode != .tutorial, !solved, !revealed, let last = lastSubmitted else { return nil }

        // Not a real word to the engine. The toast says "not in my vocabulary";
        // this says what to do about it.
        guard last.known else { return loc.coachNotAWord }

        let scored = guesses.filter(\.known)
        let best = rank(forScore: bestScore)
        let isCold = (best == 0 || best > 1000) && bestScore < 25

        switch scored.count {
        case 1:
            return isCold ? loc.coachFirstCold : loc.coachFirstWarm
        case 2...4 where isCold:
            // Still nothing warm — the useful move is to spread out, not to
            // keep probing near a guess that was never close.
            return loc.coachTriangulate
        default:
            return nil
        }
    }

    var keeperNudge: String? {
        guard !solved, !revealed, mode != .tutorial, lastSubmitted?.known == true,
              let traj = trajectory else { return nil }
        let best = rank(forScore: bestScore)

        if best > 0 && best <= 8 {
            return loc.nudgeSoClose
        }
        if traj.isNewBest && ((best > 0 && best <= 40) || bestScore >= 50) {
            return loc.nudgeCircling
        }
        // The "you're stuck, ask me something" line used to live here. It now
        // duplicates Wick's offer card, which says the same thing and hands the
        // player an actual question to tap — so this only speaks when the card
        // isn't already on screen (e.g. the player snoozed it).
        if !traj.isNewBest && coldStreak >= 3 && questionNudge == nil {
            return loc.nudgeStuck
        }
        return nil
    }

    private func markSolved() {
        solved = true
        Feedback.play(.solved)
        if guesses.count == 1 { wickEggFlicker &+= 1 }   // first-guess solve — Wick pops with delight
        // The tutorial ends here, before anything is recorded or rewarded.
        if mode == .tutorial {
            finishTutorialBySolving()
            return
        }
        recordRound(solved: true)

        // Archive replays are for completion only — no streak, stats,
        // achievements, or review prompts, so the daily economy stays honest
        // and old puzzles can't be farmed. (recordRound still logs the win.)
        if case .archive = mode {
            transientMessage = loc.archiveSolvedToast
            return
        }
        // Duels are competitive but ephemeral — no streak/stats (can't be
        // farmed by replaying a code). The UI surfaces the result-code sharing.
        if case .duel = mode {
            saveMyDuelResult()
            transientMessage = loc.duelSolvedToast
            return
        }

        if case .daily = mode {
            let today = WordBank.dayIndex()
            // Only the FIRST solve of a day advances the streak — re-solving the
            // same daily in another language keeps it, but never inflates it.
            if lastSolvedDay != today {
                streak = (lastSolvedDay == today - 1) ? streak + 1 : 1
                lastSolvedDay = today
            }
            // 3.6: remember the day's result for the race board. Nothing is
            // posted until the player taps Submit there.
            DailyBoard.shared.record(BoardResult(n: puzzleNumber, g: guessCount, h: hintsUsed,
                                                 ms: elapsedMs, lang: language.rawValue, gaveUp: false))
        }

        // Stats
        solves += 1
        totalSolveGuesses += guesses.count
        if bestGuessCount == 0 || guesses.count < bestGuessCount {
            bestGuessCount = guesses.count
        }
        if streak > bestStreak { bestStreak = streak }

        let newBadges = evaluateAchievements()
        if let first = newBadges.first {
            transientMessage = loc.solvedBadge(first)
        } else {
            transientMessage = loc.solvedTitle
        }
        saveDailyState()
        // Progression changed (streak, stats, badges) — mirror it before
        // anything can happen to this device, and stand the streak warning down
        // now that today is safe.
        CloudSync.push()
        refreshReminders()
        // Leaderboards, if the player ever opted in. Dailies only — practice and
        // archive aren't a shared contest, and both are unbounded, so ranking
        // them would be farmable. No-ops entirely when Game Center is untouched.
        if case .daily = mode {
            GameCenter.reportDailySolve(guesses: guessCount,
                                        elapsedMs: elapsedMs,
                                        bestStreak: bestStreak)
        }
        GameCenter.report(unlocked: unlocked)
        // One ask per solve: if the rating prompt is coming, the reminder offer
        // waits for a later solve (it stays unoffered until it is shown).
        let reviewBefore = reviewRequestID
        maybeRequestReview()
        if reviewRequestID == reviewBefore { maybeOfferReminder() }
    }

    // MARK: - iCloud progression

    /// Re-reads the cloud-backed keys after a merge. Deliberately narrow: it
    /// touches the streak and the stats, and never the round in
    /// play — adopting a board mid-guess from another device would be a worse
    /// bug than the one this fixes.
    private func adoptCloudState() {
        let d = UserDefaults.standard
        streak            = d.object(forKey: "hunch.streak") as? Int ?? streak
        lastSolvedDay     = d.object(forKey: "hunch.lastSolvedDay") as? Int ?? lastSolvedDay
        solves            = d.integer(forKey: "hunch.solves")
        bestStreak        = d.integer(forKey: "hunch.bestStreak")
        totalSolveGuesses = d.integer(forKey: "hunch.totalGuesses")
        bestGuessCount    = d.integer(forKey: "hunch.bestGuessCount")
        unlocked          = Set(d.stringArray(forKey: "hunch.achievements") ?? [])
        refreshReminders()
        // 3.6: a returning player on a new phone can land in the tutorial
        // before their progress arrives. If they haven't started it, let them go.
        if mode == .tutorial, tutorialStep == .firstGuess, guesses.isEmpty, questions.isEmpty, solves > 0 {
            startDaily()
            onHomeScreen = true
        }
    }

    // MARK: - Reminders

    /// Re-writes the daily reminders and arms or stands down the "your flame is
    /// about to go out" warning. Cheap and idempotent: call it whenever the
    /// streak, the solved state, the language, the reminder time or the toggle
    /// could have changed, and on every launch and foreground (that also tops
    /// the two-week queue of daily reminders back up).
    func refreshReminders() {
        let d = UserDefaults.standard
        let on = d.bool(forKey: "hunch.reminderOn")
        if on {
            HunchNotifications.schedule(
                hour: d.object(forKey: "hunch.reminderHour") as? Int ?? 9,
                minute: d.object(forKey: "hunch.reminderMinute") as? Int ?? 0,
                lastSolvedDay: lastSolvedDay,
                loc: loc
            )
        }
        HunchNotifications.refreshStreakReminder(
            streak: streak,
            lastSolvedDay: lastSolvedDay,
            enabled: on,
            loc: loc
        )
    }

    /// Re-writes every reminder in the current language. Notification copy is
    /// baked in when it's scheduled, so a pending reminder keeps speaking the
    /// old language until something re-schedules it — this is that something.
    func rescheduleReminders() {
        guard UserDefaults.standard.bool(forKey: "hunch.reminderOn") else { return }
        refreshReminders()
    }

    /// Bumped once, after the first daily solve, to offer the daily reminder.
    /// A view watches it and asks. 3.5: most players never open Settings, so
    /// the reminder has to be offered at a happy moment to be found at all.
    private(set) var reminderOfferID = 0

    /// Offers the reminder after a daily solve, once ever, and only to a player
    /// who doesn't have it on.
    private func maybeOfferReminder() {
        guard case .daily = mode else { return }
        let d = UserDefaults.standard
        guard !d.bool(forKey: "hunch.reminderOn"),
              !d.bool(forKey: "hunch.reminderOffered") else { return }
        d.set(true, forKey: "hunch.reminderOffered")
        reminderOfferID += 1
    }

    /// The player said yes to the reminder offer: ask iOS, then schedule at the
    /// time saved in Settings (9 AM unless they changed it).
    func acceptReminderOffer() async {
        let ok = await HunchNotifications.requestPermission()
        UserDefaults.standard.set(ok, forKey: "hunch.reminderOn")
        refreshReminders()
    }

    // MARK: - Ratings

    /// Asks for an App Store rating at a genuinely happy moment — a couple of wins
    /// in, or a good streak — and no more than a few times ever, well spaced.
    /// (Apple also enforces its own ~3/year cap.) A view watches
    /// `reviewRequestID` and presents the system prompt.
    private func maybeRequestReview() {
        let today = WordBank.dayIndex()
        // 3.3: the first ask only needs the solve gate, so a new player who
        // solves twice on day one is asked before they can churn. Later asks
        // keep the 60 day gap (Apple allows three prompts a year).
        guard reviewAsks < 3, reviewAsks == 0 || today - lastReviewDay >= 60 else { return }
        guard solves >= 2 || streak >= 3 else { return }
        lastReviewDay = today
        reviewAsks += 1
        reviewRequestID += 1
    }

    // MARK: - Achievements

    func isUnlocked(_ id: String) -> Bool { unlocked.contains(id) }
    var unlockedCount: Int { unlocked.count }

    private func evaluateAchievements() -> [String] {
        var newly: [String] = []
        func unlock(_ id: String) {
            if !unlocked.contains(id) {
                unlocked.insert(id)
                newly.append(Achievements.title(for: id, language))
            }
        }
        unlock("first_solve")
        if guesses.count <= 5 { unlock("guesses_5") }
        if guesses.count <= 3 { unlock("guesses_3") }
        if hintsUsed == 0 { unlock("no_hints") }
        if questions.isEmpty { unlock("no_questions") }
        if streak >= 3 { unlock("streak_3") }
        if streak >= 7 { unlock("streak_7") }
        if streak >= 30 { unlock("streak_30") }
        if solves >= 10 { unlock("solves_10") }
        if solves >= 50 { unlock("solves_50") }
        if solves >= 100 { unlock("solves_100") }
        return newly
    }

    /// Give up: reveal the word and end the round (no reward, streak untouched).
    func giveUp() {
        guard !solved, !revealed, mode != .tutorial else { return }
        revealed = true
        Feedback.play(.gaveUp)
        recordRound(solved: false)
        saveMyDuelResult()
        transientMessage = loc.theWordWasToast(target)
        saveDailyState()
        // A give-up is the day's result too (it lands at the bottom of the
        // board if submitted), so a quick re-solve afterward can't replace it.
        if case .daily = mode {
            DailyBoard.shared.record(BoardResult(n: puzzleNumber, g: guessCount, h: hintsUsed,
                                                 ms: elapsedMs, lang: language.rawValue, gaveUp: true))
        }
    }

    /// Persist my result for the current duel so a friend's pasted result code can
    /// be shown head-to-head. No-op outside a duel.
    private func saveMyDuelResult() {
        guard case let .duel(p) = mode else { return }
        DuelResultStore.save(DuelResult(language: p.language, wordIndex: p.wordIndex,
                                        solved: solved, gaveUp: revealed && !solved,
                                        guessCount: guesses.filter(\.known).count))
    }

    // MARK: - Duel helpers (word choices for creating a duel)

    /// Curated, fair (tier ≤ 2) words a challenger can pick, with their index into
    /// `WordBank.entries` (what the duel code encodes).
    func duelWordChoices() -> [(index: Int, word: String)] {
        WordBank.entries(for: language).enumerated()
            .filter { $0.element.tier <= 2 }
            .map { (index: $0.offset, word: $0.element.word) }
    }

    /// A random fair word index for a Race (Wick picks; neither player sees it).
    func randomDuelWordIndex() -> Int? {
        duelWordChoices().randomElement()?.index
    }

    /// Writes the finished round into the permanent local history (see
    /// RoundHistory — 2.0 archive/stats groundwork; write-only in 1.8).
    private func recordRound(solved: Bool) {
        let modeName: String
        let puzzle: Int?
        let recDayIndex: Int
        switch mode {
        case .daily:
            modeName = "daily";    puzzle = puzzleNumber; recDayIndex = WordBank.dayIndex()
        case .practice:
            modeName = "practice"; puzzle = nil;          recDayIndex = WordBank.dayIndex()
        case .archive(let day):
            // Record under the ORIGINAL day so the archive marks it complete.
            modeName = "archive";  puzzle = puzzleNumber; recDayIndex = day
        case .duel:
            // Duels aren't logged to history/stats/archive.
            return
        case .tutorial:
            // The tutorial is a sandbox. Logging it would also count as one of
            // the two "learning" rounds and switch the coaching off too soon.
            return
        }
        if mode == .daily {
            Events.track(solved ? .dailySolve : .dailyGiveup, n: puzzleNumber, g: guesses.count)
        }
        RoundHistory.record(RoundRecord(
            date: Date(),
            dayIndex: recDayIndex,
            puzzleNumber: puzzle,
            mode: modeName,
            tier: targetTier,
            language: language.rawValue,
            word: target,
            wordEN: WordAttributes.englishForm(target, language: language),
            solved: solved,
            guessCount: guesses.filter(\.known).count,
            questionCount: questions.count,
            hintsUsed: hintsUsed,
            scores: guesses.filter(\.known).sorted { $0.order < $1.order }.map(\.score)
        ))
    }

    // MARK: - Hints

    /// Closest rank a hint will ever hand out. Keeps the last stretch — the
    /// genuinely-close words — for the player to find themselves.
    private static let minHintRank = 20

    /// How far each hint closes the gap toward the answer. 0.7 = move ~30%
    /// closer per hint, so progress stays gradual instead of halving.
    private static let hintStepFactor = 0.7

    /// Reveals a stepping-stone word drawn from the secret's true semantic
    /// neighbourhood. Each hint adapts to where you are, landing roughly halfway
    /// from your current best guess toward the answer.
    func revealHint() {
        guard !solved, !revealed else { return }

        // Hints need the rank list to be ready.
        guard rankingBuilt, !rankedSims.isEmpty else {
            ensureRanking()
            transientMessage = loc.hintWarmingUp
            return
        }

        // The tutorial's hint is always free and never counts against the
        // day's free hints. Outside it, once the day's free hints are gone
        // there are no more hints until tomorrow.
        let tutorial = mode == .tutorial
        guard tutorial || freeHintsLeft > 0 else {
            transientMessage = loc.noHintsToday
            return
        }

        // Your current best (closest) rank, or the bottom of the list if you
        // haven't landed a known guess yet.
        let bestRank = guesses.filter(\.known)
            .map { rank(forScore: $0.score) }
            .filter { $0 > 0 }
            .min() ?? maxRank

        // Already close — a hint would just give the answer away.
        if bestRank <= Self.minHintRank {
            if tutorial { tutorialHintNotNeeded(); return }
            transientMessage = loc.topTakeIt(Self.minHintRank)
            return
        }

        // Build the candidate pool once per round: the secret's actual nearest
        // neighbours from the embedding (the most relevant stepping stones),
        // widened with the curated vocab, each tagged with its Contexto rank.
        if hintCandidates.isEmpty {
            // Only offer hints the player will recognize: the curated hint list,
            // plus embedding neighbours that are also common words. Raw neighbours
            // and niche secret words (e.g. "plinth", "aqueduct") are excluded so a
            // hint is always a familiar stepping stone.
            let neighbours = engine.relatedWords(to: target, max: 150)
                .filter { engine.hintCommonSet.contains($0) }
            // Fallback vocabulary so there's always a recognizable stepping stone,
            // even when few embedding neighbours are common words. English adds its
            // curated list; both languages fall back to the bilingual word pool
            // (concrete nouns) so Spanish hints are never empty.
            let extra = language == .english
                ? HintVocabulary.words + DailyWords.all.map(\.en)
                : DailyWords.all.map { $0.word(for: language) }
            let pool = Set(neighbours + extra)
            hintCandidates = pool
                .filter { $0 != target && !$0.contains(target) && !target.contains($0) && engine.isKnown($0) }
                .compactMap { w -> (word: String, rank: Int)? in
                    guard let s = engine.similarity(w, target) else { return nil }
                    return (w, rank(forScore: s * 100))
                }
                .filter { $0.rank >= Self.minHintRank }
                .sorted { $0.rank < $1.rank }
        }

        // Ranks already showing in the guess list. A hint should hand you a new,
        // strictly-better number rather than repeat one you already have
        // (e.g. don't give another #21 when you're already at #21).
        let existingRanks = Set(
            guesses.filter(\.known)
                .map { rank(forScore: $0.score) }
                .filter { $0 > 0 }
        )

        // Words strictly closer than your best and not already guessed. Prefer
        // ones whose rank you don't already hold so every hint advances the
        // number; only fall back to repeats if nothing else is left.
        func candidates(skipExistingRanks: Bool) -> [(word: String, rank: Int)] {
            hintCandidates.filter { c in
                c.rank < bestRank
                && !guesses.contains { $0.word == c.word }
                && (!skipExistingRanks || !existingRanks.contains(c.rank))
            }
        }
        let preferred = candidates(skipExistingRanks: true)
        let available = preferred.isEmpty ? candidates(skipExistingRanks: false) : preferred
        guard !available.isEmpty else {
            if tutorial { tutorialHintNotNeeded(); return }
            transientMessage = loc.noCloserHint
            return
        }

        // Move only a gentle step closer (≈30%) toward the answer. To avoid
        // overshooting, prefer the candidate nearest the target that isn't
        // already closer than it; only if every option is closer do we take the
        // gentlest one (nearest your current best) so the step stays small.
        let targetRank = max(Self.minHintRank, Int(Double(bestRank) * Self.hintStepFactor))
        let pick: (word: String, rank: Int)
        if let notPast = available.filter({ $0.rank >= targetRank }).min(by: { $0.rank < $1.rank }) {
            pick = notPast
        } else {
            pick = available.max(by: { $0.rank < $1.rank })!
        }

        if tutorial {
            Feedback.play(.selection)
        } else {
            let today = WordBank.dayIndex()
            if freeHintDay != today { freeHintDay = today; freeHintsUsedToday = 0 }
            freeHintsUsedToday += 1
        }
        hintsUsed += 1
        // The hint's word is Wick's pick, not the player's, so it stays out of
        // the weekly Stats list.
        submittingHint = true
        submit(pick.word)
        submittingHint = false
        transientMessage = loc.hintLands(pick.word, pick.rank)
        saveDailyState()
        if tutorial { tutorialHinted() }
    }

#if DEBUG
    /// Audits every daily-pool word for solvability and prints a report to the
    /// Xcode console. Flags words whose closest common word is still cold (an
    /// embedding outlier that plays unfairly) or that have too few warm words.
    /// Returns a one-line summary for the on-screen toast.
    @discardableResult
    func auditDailyPool() -> String {
        let pool = DailyWords.dailyPool.map { WordBank.Entry(word: $0.word(for: language), tier: $0.tier) }
        var oov: [String] = []
        var rows: [(word: String, best: Double, warm: Int, risky: Bool)] = []

        for entry in pool {
            guard engine.isKnown(entry.word) else { oov.append(entry.word); continue }
            let f = engine.fairness(for: entry.word)
            let risky = f.best < 35 || f.warmCount < 8
            rows.append((entry.word, f.best, f.warmCount, risky))
        }
        rows.sort { $0.best < $1.best }   // worst (coldest) first

        print("=== Hunch daily-pool fairness audit ===")
        print("pool=\(pool.count)  known=\(rows.count)  OOV(skipped)=\(oov.count)")
        if !oov.isEmpty { print("OOV: \(oov.joined(separator: ", "))") }
        print("word            best  warm  flag")
        for r in rows {
            let w = r.word.padding(toLength: 14, withPad: " ", startingAt: 0)
            let best = String(format: "%5.0f", r.best)
            let warm = String(format: "%5d", r.warm)
            print("\(w) \(best) \(warm)  \(r.risky ? "RISKY" : "")")
        }
        let risky = rows.filter(\.risky).map(\.word)
        print("RISKY (\(risky.count)): \(risky.joined(separator: ", "))")
        print("=== end audit ===")

        return "Audit: \(rows.count) words · \(risky.count) risky · \(oov.count) OOV; see console"
    }
#endif

    // MARK: - Opening clue

    /// Generates the Keeper's opening riddle/category once per round (on-device).
    func ensureOpeningClue() async {
        guard !clueRequested, !solved, !revealed else { return }
        clueRequested = true
        isLoadingClue = true
        openingClue = await keeper.openingClue(secret: target)
        isLoadingClue = false
    }

    // MARK: - Questions

    /// Whether Apple Intelligence (the on-device LLM) is usable on this device.
    /// Free-form typed questions need it; tapped starter questions do not.
    var aiAvailable: Bool { keeper.isAvailable }

    /// True while this language's word dictionary hasn't loaded yet (Apple's
    /// non-English vectors download on demand). Guesses can't be scored until it
    /// does — drives a persistent help banner telling the player how to fix it,
    /// instead of relying on a toast that flashes by.
    var scoringUnavailable: Bool { !engine.hasVocabulary }

    /// Questions are free — talking to Wick never costs anything.
    /// Kept as a property so existing call sites read naturally.
    var canAffordQuestion: Bool { true }

    /// Typed questions work on every device: the Wick server answers them (3.7),
    /// and Apple's on-device model answers when the server can't be reached.
    var canAsk: Bool {
        !solved && !revealed && canAffordQuestion
    }

    /// Tapped starter questions work on every device, answered like any other
    /// question (3.7: by the server, which saved the daily word's answers early).
    var canUseStarters: Bool {
        !solved && !revealed && canAffordQuestion
    }

    var questionUnavailableReason: String { keeper.unavailableReason }

    /// Tappable starter questions for this round. Seeded by the shared day index
    /// (never the secret word), so the set is identical for every player and
    /// leaks nothing. Already-asked questions are filtered out so chips retire
    /// as the player uses them. 3.7: every chip is shown on every iPhone, since
    /// the server answers them all.
    var starterQuestions: [StarterQuestions.Item] {
        let alreadyAsked = Set(questions.map { $0.question.lowercased() })
        return StarterQuestions.daily(dayIndex: WordBank.dayIndex()).filter { item in
            !alreadyAsked.contains(StarterQuestions.localizedFull(item, language).lowercased())
        }
    }

    // MARK: - Adaptive question offer

    /// Why Wick is offering to answer something right now. Drives the tone of
    /// his line — nothing here depends on the secret word, so the offer itself
    /// leaks nothing.
    enum QuestionNudge: Equatable {
        case stuck      // several guesses in a row further from your best
        case cold       // a few guesses in and still nothing warm
        case routine    // playing along fine, but hasn't discovered asking yet
    }

    /// Guess count at which a snoozed offer is allowed to come back.
    private var nudgeSnoozeUntilGuess = 0

    /// Whether — and why — to surface Wick's prefilled question offer.
    ///
    /// Deliberately adaptive rather than a fixed "every 5 guesses" timer: the
    /// player who is closing in doesn't need help and resents being handed it,
    /// while the player who has gone cold three times in a row needs it *now*.
    /// The routine case still exists so someone who never gets stuck eventually
    /// learns that questions are a thing.
    var questionNudge: QuestionNudge? {
        guard !solved, !revealed, !isAsking, mode != .tutorial,
              offeredStarter != nil,
              guessCount >= nudgeSnoozeUntilGuess else { return nil }
        // Closing in — get out of the way. Ranks may not be built yet on a
        // fresh round, so fall back to the raw score rather than pestering
        // someone who is plainly hot.
        let best = rank(forScore: bestScore)
        if (best > 0 && best <= 40) || bestScore >= 55 { return nil }

        if coldStreak >= 3 { return .stuck }
        if guessCount >= 3 && bestScore < 40 { return .cold }
        if guessCount >= 4 && questions.isEmpty { return .routine }
        if guessCount >= 10 && questions.count < 2 { return .routine }
        return nil
    }

    /// The single question Wick offers to answer. Rotates with the guess count
    /// so a repeat offer isn't the same card twice — and, like the starter bank
    /// itself, depends only on the day and the count, never on the secret.
    var offeredStarter: StarterQuestions.Item? {
        let pool = starterQuestions
        guard !pool.isEmpty else { return nil }
        return pool[guessCount % pool.count]
    }

    /// "Not now" — hold the offer back for a few more guesses rather than
    /// killing it for the round.
    func snoozeQuestionNudge() {
        nudgeSnoozeUntilGuess = guessCount + 4
        Haptics.selection()
    }

    /// A question just landed. Wick has said his piece — give the player a
    /// couple of guesses with it before offering another.
    private func quietQuestionNudge() {
        nudgeSnoozeUntilGuess = max(nudgeSnoozeUntilGuess, guessCount + 2)
    }

    /// Handles a tapped starter chip. 3.7: asked like any other question, sent
    /// to the server as its English text so it matches the answers saved early
    /// for the daily word. Only the tutorial still answers from the word's tags:
    /// its words are hand-picked, and it must work offline on a first launch.
    func askStarter(_ item: StarterQuestions.Item) async {
        guard !solved, !revealed, !isAsking else { return }
        let full = StarterQuestions.localizedFull(item, language)

        if mode == .tutorial,
           let category = WordAttributes.category(for: target, language: language),
           let verdict = WordAttributes.deterministicVerdict(word: target, language: language, category: category, property: item.key) {
            // Questions are free, so no gate — just record it, with a
            // short in-character flavor line so tapped chips feel like Wick too.
            let flavor = OfflineKeeper.reply(verdict: verdict, seed: full, language: language)
            questions.insert(AskedQuestion(question: full, verdict: verdict, reply: flavor,
                                           seq: guesses.count + questions.count, at: stampNow()), at: 0)
            Haptics.selection()
            quietQuestionNudge()
            saveDailyState()
            if mode == .tutorial { tutorialAnswered(verdict) }
            return
        }

        // Shown in the round's language, sent to the server in English.
        await ask(full, typed: false, serverQuestion: item.full)
    }

    /// `typed` is false for a tapped starter chip, which stays out of the
    /// weekly Stats list (everyone is offered the same chips). `serverQuestion`
    /// is the English text of a chip (see QuestionService.answer).
    func ask(_ raw: String, typed: Bool = true, serverQuestion: String? = nil) async {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !solved, !revealed, !isAsking else { return }
        // Tutorial: Wick's own "Is it alive?" gets the sure answer from the
        // animal's tags (always Yes), never a model's guess.
        if mode == .tutorial, typed,
           let item = StarterQuestions.categories.flatMap(\.items).first(where: { $0.key == .alive }),
           q.lowercased() == StarterQuestions.localizedFull(item, language).lowercased(),
           WordAttributes.category(for: target, language: language) != nil {
            await askStarter(item)
            return
        }

        failedQuestion = nil   // new attempt — clear any prior failure
        failedQuestionTyped = typed
        failedServerQuestion = serverQuestion
        isAsking = true
        // Pass the round's prior exchanges (memory). Wick wears nothing now.
        let result = await keeper.answer(question: q, secret: target,
                                         facts: WordAttributes.facts(for: target, language: language),
                                         history: questions, wearing: [],
                                         serverQuestion: serverQuestion)
        isAsking = false

        switch result {
        case .answered(let verdict, let reply):
            questions.insert(AskedQuestion(question: q, verdict: verdict, reply: reply,
                                           seq: guesses.count + questions.count, at: stampNow()), at: 0)
            quietQuestionNudge()
            saveDailyState()
            if mode == .tutorial { tutorialAnswered(verdict) }
            // 3.6 weekly Stats: a typed question, unless it names the answer.
            if typed, mode != .tutorial, !WordTallyRules.namesAnswer(q, answers: [target, DailyWords.english(of: target, in: language)]) {
                WordTally.question(q, language: language)
            }
        case .unavailable(let reason):
            transientMessage = reason
        case .failed:
            // Keep the question so the player can retry with one tap. No free
            // question is spent on a failed answer.
            failedQuestion = q
            transientMessage = loc.keeperDidntRespond
        }
    }

    /// Re-asks the last question the Keeper failed to answer.
    func retryFailedQuestion() async {
        guard let q = failedQuestion, !isAsking else { return }
        await ask(q, typed: failedQuestionTyped, serverQuestion: failedServerQuestion)
    }

    // MARK: - Sharing

    /// The copy-paste result card. Fully localized; a flag marks non-English
    /// rounds; the heat grid wraps at 10 per row so long rounds stay tidy; the
    /// streak flame rides along when it's worth bragging about.
    /// "Wick #1359 🇩🇪" — the header on both the text share and the image card.
    /// Extracted so the two can never drift apart.
    var shareTitle: String {
        let flag = language == .english ? "" : " \(language.flag)"
        switch mode {
        case .daily:    return "Wick #\(puzzleNumber)\(flag)"
        case .practice: return "Wick\(flag) · \(loc.practice)"
        case .archive:  return "Wick #\(puzzleNumber)\(flag)"
        case .duel:     return "Wick\(flag) · \(loc.duel)"
        case .tutorial: return "Wick"
        }
    }

    /// "solved in 7 · 2 questions · 🔥2". Counts only — deliberately never the
    /// word, so both shares stay safe to post publicly on the day.
    var shareStats: String {
        var stats = solved ? loc.shareSolvedIn(guessCount) : loc.theWordWas.lowercased() + " …"
        if !questions.isEmpty { stats += " · " + loc.shareQuestions(questions.count) }
        if hintsUsed > 0 { stats += " · " + loc.shareHints(hintsUsed) }
        if case .daily = mode, streak > 1 { stats += " · 🔥\(streak)" }
        return stats
    }

    func shareText() -> String {
        let squares = guesses.filter(\.known)
            .sorted { $0.order < $1.order }
            .map { HunchTheme.rankSquare(rank(forScore: $0.score)) }
        let grid = stride(from: 0, to: squares.count, by: 10)
            .map { squares[$0..<min($0 + 10, squares.count)].joined() }
            .joined(separator: "\n")

        return "\(shareTitle): \(shareStats)\n\(grid)\n\(loc.shareTagline)"
    }

    /// The semantic map as a flat image, for the share sheet.
    ///
    /// Spoiler-free by construction — `RevealShareCard` drops the guess words at
    /// its initializer, so nothing downstream can print one. See that file's
    /// header before changing what goes on the card.
    ///
    /// Returns nil when there is nothing worth plotting (fewer than two scored
    /// guesses makes a bullseye with one dot on it, which reads as a mistake) or
    /// if `ImageRenderer` fails. Callers fall back to sharing the text alone.
    func shareImage() -> UIImage? {
        let plotted = revealPoints
        guard plotted.filter({ $0.score < 100 }).count >= 2 else { return nil }
        return RevealShareCard(title: shareTitle,
                               stats: shareStats,
                               points: plotted,
                               solved: solved,
                               loc: loc).rendered()
    }

    /// Everything the share sheet should carry: the emoji-grid text always, plus
    /// the map image when there was enough of a round to draw one. Some targets
    /// take the image, some the text, most take both.
    func shareItems() -> [Any] {
        Events.track(.shareGrid, n: mode == .daily ? puzzleNumber : nil)
        var items: [Any] = [shareText()]
        if let image = shareImage() { items.append(image) }
        return items
    }
}
