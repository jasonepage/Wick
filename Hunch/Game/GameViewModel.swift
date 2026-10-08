//
//  GameViewModel.swift
//  Hunch
//
//  Orchestrates a round: guesses (semantic closeness), questions (on-device LLM),
//  coins, streak, solve detection, and the shareable result.
//

import Foundation
import Observation
import StoreKit
import UIKit   // UIImage, for the shareable Reveal card

@MainActor
@Observable
final class GameViewModel {

    // Tuning knobs
    static let freeQuestionsPerGame = 3
    static let questionCoinCost = 5
    static let hintCoinCost = 8
    /// 3.3: hints are free to serve (on-device), so the first few each day are
    /// free for everyone. Coins only after these are gone. A player who runs
    /// out of hints loses, quits and never shares; this is the biggest leak.
    static let freeHintsPerDay = 3
    static let dailyBonus = 5
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

    /// A ghost run opened from a race link, waiting to be started — drives the
    /// same kind of app-wide presentation as `pendingLiveInvite`. Set by
    /// `HunchApp.onOpenURL`; cleared when the race begins or is declined.
    var pendingGhostRace: GhostRun?

    /// The run currently being raced, or nil for an ordinary round.
    private(set) var ghost: GhostRun?

    /// Where in `DailyWords.all` this practice round's word came from, so the
    /// round can be shared as a race. -1 outside practice.
    private(set) var practicePoolIndex = -1

    /// When the race clock started, set after the 3-2-1 count-in. The race uses
    /// REAL elapsed time — a race cannot be paused — unlike the recorded round
    /// clock, which clamps idle gaps so a shared run is still sane if the player
    /// wanders off mid-round.
    private(set) var raceStartedAt: Date?

    /// Seconds into the race right now, or 0 before the count-in finishes.
    var raceElapsed: TimeInterval {
        guard let s = raceStartedAt else { return 0 }
        return Date().timeIntervalSince(s)
    }

    /// Where the ghost stands at this instant: the last action whose timestamp
    /// has been reached, or nil before their first move.
    var ghostAction: GhostAction? {
        guard let run = ghost else { return nil }
        let ms = Int(raceElapsed * 1000)
        var found: GhostAction?
        for a in run.actions {
            if a.t <= ms { found = a } else { break }
        }
        return found
    }

    /// Begin racing a run. The caller starts the round itself first (daily or
    /// practice), then hands the ghost over; the clock starts when `countIn`
    /// completes so the player doesn't lose seconds to reading the board.
    func beginGhostRace(_ run: GhostRun) {
        ghost = run
        raceStartedAt = nil
        pendingGhostRace = nil
    }

    /// Called when the count-in finishes.
    func startRaceClock() {
        raceStartedAt = Date()
    }

    /// Clear any race state — called from resetRound().
    func clearGhostRace() {
        ghost = nil
        raceStartedAt = nil
    }

    /// Build a shareable run from the round just played, or nil if there's
    /// nothing replayable. Numbers only — no word, question or reply travels.
    ///
    /// Practice refs are capped to the words iOS and web share (see
    /// Ghost.sharedPoolCount): sending an index the web client can't resolve
    /// would put the two players on different words with both boards looking
    /// entirely normal.
    func ghostRun() -> GhostRun? {
        var events: [(atMs: Int, isQuestion: Bool, score: Double?)] = []
        for g in guesses {
            guard let at = g.at else { continue }
            events.append((at, false, g.known ? g.score : nil))
        }
        for q in questions {
            guard let at = q.at else { continue }
            events.append((at, true, nil))
        }
        guard !events.isEmpty else { return nil }
        events.sort { $0.atMs < $1.atMs }

        switch mode {
        case .daily:
            return Ghost.build(mode: .daily, ref: puzzleNumber,
                               solved: solved, events: events)
        case .practice:
            guard let ref = Ghost.practiceRef(poolIndex: practicePoolIndex) else { return nil }
            return Ghost.build(mode: .practice, ref: ref, solved: solved, events: events)
        default:
            return nil   // archive rounds aren't raceable: no stable shared ref
        }
    }

    /// Start racing a run that arrived from a link: enter the right round, then
    /// hand the ghost over. The clock starts when the count-in finishes.
    func startGhostRace(_ run: GhostRun) {
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
            guard run.ref >= 0, run.ref < DailyWords.all.count else {
                pendingGhostRace = nil
                return
            }
            let pair = DailyWords.all[run.ref]
            currentPair = pair
            mode = .practice(tier: pair.tier)
            target = pair.word(for: language)
            targetTier = pair.tier
            puzzleNumber = 0
            resetRound()
            practicePoolIndex = run.ref
        }
        beginGhostRace(run)
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

    // Persisted economy
    var coins: Int {
        didSet { UserDefaults.standard.set(coins, forKey: "hunch.coins") }
    }
    private(set) var streak: Int {
        didSet { UserDefaults.standard.set(streak, forKey: "hunch.streak") }
    }
    private var lastSolvedDay: Int {
        didSet { UserDefaults.standard.set(lastSolvedDay, forKey: "hunch.lastSolvedDay") }
    }
    private var lastBonusDay: Int {
        didSet { UserDefaults.standard.set(lastBonusDay, forKey: "hunch.lastBonusDay") }
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
    /// Wick's cosmetic wardrobe. Shared so every `KeeperView` shows the equipped
    /// look; coins stay owned here and are reached via injected closures below.
    let wardrobe = WardrobeStore.shared
    /// The language in play before the current download started, so cancelling the
    /// download can revert to something that actually scores.
    private var languageBeforeDownload: GameLanguage = .english
    let coinStore = CoinStore()

    init() {
        let d = UserDefaults.standard
        coins = d.object(forKey: "hunch.coins") as? Int ?? 50
        streak = d.object(forKey: "hunch.streak") as? Int ?? 0
        lastSolvedDay = d.object(forKey: "hunch.lastSolvedDay") as? Int ?? -1
        solves = d.integer(forKey: "hunch.solves")
        bestStreak = d.integer(forKey: "hunch.bestStreak")
        totalSolveGuesses = d.integer(forKey: "hunch.totalGuesses")
        bestGuessCount = d.integer(forKey: "hunch.bestGuessCount")
        unlocked = Set(d.stringArray(forKey: "hunch.achievements") ?? [])
        lastBonusDay = d.object(forKey: "hunch.lastBonusDay") as? Int ?? -1
        lastReviewDay = d.object(forKey: "hunch.lastReviewDay") as? Int ?? -100_000
        reviewAsks = d.integer(forKey: "hunch.reviewAsks")
        freeHintDay = d.object(forKey: "hunch.freeHintDay") as? Int ?? -1
        freeHintsUsedToday = d.integer(forKey: "hunch.freeHintsUsed")

        // Small daily bonus so a player can never run dry. (didSet doesn't fire
        // during init, so persist explicitly here.)
        var bonus = 0
        let today = WordBank.dayIndex()
        if lastBonusDay != today {
            bonus = Self.dailyBonus
            coins += bonus
            lastBonusDay = today
            d.set(coins, forKey: "hunch.coins")
            d.set(lastBonusDay, forKey: "hunch.lastBonusDay")
        }

        coinStore.onGrant = { [weak self] amount in self?.creditCoins(amount) }

        // Wardrobe reaches the economy only through these closures (mirrors
        // CoinStore.onGrant): spend debits coins iff affordable, balance reads them.
        wardrobe.balance = { [weak self] in self?.coins ?? 0 }
        wardrobe.spend = { [weak self] price in
            guard let self, self.coins >= price else { return false }
            self.coins -= price
            return true   // WardrobeStore mirrors to iCloud once the item lands
        }

        startDaily()
        if bonus > 0 { transientMessage = loc.dailyBonus(bonus) }
        // Kick an ODR download if the stored language needs one (silent at launch —
        // the retry loop + scoring banner cover it; no modal over a cold start).
        assetLoader.ensure(language, presentModal: false)
        startVocabularyRetryIfNeeded()

        // A fresh install often opens BEFORE iCloud has handed over the player's
        // progression — it arrives seconds later. `CloudSync.bootstrap()` (called
        // from `HunchApp.init`) merges it into UserDefaults and posts this; we
        // re-read so the streak on screen isn't a stale zero.
        CloudSync.onMerge = { [weak self] in self?.adoptCloudState() }
        refreshStreakReminder()
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
        Self.verdictTables[language]?[token.lowercased()] ?? token
    }

    /// UI string table for the current language.
    var loc: Loc { Loc(lang: language) }

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
        // Practice is free so players can always play and earn coins back.
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
    /// never awards coins, advances the streak, or inflates stats
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
    /// no coins, streak, stats, or history (see `markSolved` / `recordRound`).
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
        clearGhostRace()
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

            if normalized { transientMessage = loc.normalizedTo(typed, word) }
            Feedback.play(isNewBest ? .newClosest(closeness: s) : .guessScored(closeness: s))
            saveDailyState()
        } else {
            lastSubmitted = Guess(word: typed, score: 0, known: false, order: guesses.count + 1, seq: nil)
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
        guard isLearningTheGame, !solved, !revealed, let last = lastSubmitted else { return nil }

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
        guard !solved, !revealed, lastSubmitted?.known == true,
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
        recordRound(solved: true)

        // Archive replays are for completion only — no coins, streak, stats,
        // achievements, or review prompts, so the daily economy stays honest
        // and old puzzles can't be farmed. (recordRound still logs the win.)
        if case .archive = mode {
            transientMessage = loc.archiveSolvedToast
            return
        }
        // Duels are competitive but ephemeral — no coins/streak/stats (can't be
        // farmed by replaying a code). The UI surfaces the result-code sharing.
        if case .duel = mode {
            saveMyDuelResult()
            transientMessage = loc.duelSolvedToast
            return
        }

        let reward = max(5, 30 - guesses.count) + targetTier * 3
        coins += reward

        if case .daily = mode {
            let today = WordBank.dayIndex()
            // Only the FIRST solve of a day advances the streak — re-solving the
            // same daily in another language keeps it, but never inflates it.
            if lastSolvedDay != today {
                streak = (lastSolvedDay == today - 1) ? streak + 1 : 1
                lastSolvedDay = today
            }
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
            transientMessage = loc.solvedBadge(reward, first)
        } else {
            transientMessage = loc.solvedCoins(reward)
        }
        saveDailyState()
        // Progression changed (streak, stats, coins, badges) — mirror it before
        // anything can happen to this device, and stand the streak warning down
        // now that today is safe.
        CloudSync.push()
        refreshStreakReminder()
        // Leaderboards, if the player ever opted in. Dailies only — practice and
        // archive aren't a shared contest, and both are unbounded, so ranking
        // them would be farmable. No-ops entirely when Game Center is untouched.
        if case .daily = mode {
            GameCenter.reportDailySolve(guesses: guessCount,
                                        elapsedMs: elapsedMs,
                                        bestStreak: bestStreak)
        }
        GameCenter.report(unlocked: unlocked)
        maybeRequestReview()
    }

    // MARK: - iCloud progression

    /// Re-reads the cloud-backed keys after a merge. Deliberately narrow: it
    /// touches the economy, the stats and the wardrobe, and never the round in
    /// play — adopting a board mid-guess from another device would be a worse
    /// bug than the one this fixes.
    private func adoptCloudState() {
        let d = UserDefaults.standard
        coins             = d.object(forKey: "hunch.coins") as? Int ?? coins
        streak            = d.object(forKey: "hunch.streak") as? Int ?? streak
        lastSolvedDay     = d.object(forKey: "hunch.lastSolvedDay") as? Int ?? lastSolvedDay
        solves            = d.integer(forKey: "hunch.solves")
        bestStreak        = d.integer(forKey: "hunch.bestStreak")
        totalSolveGuesses = d.integer(forKey: "hunch.totalGuesses")
        bestGuessCount    = d.integer(forKey: "hunch.bestGuessCount")
        unlocked          = Set(d.stringArray(forKey: "hunch.achievements") ?? [])
        wardrobe.reloadFromDefaults()
        refreshStreakReminder()
    }

    // MARK: - Reminders

    /// Arms or stands down the "your flame is about to go out" notification for
    /// today. Cheap and idempotent — call it whenever the streak, the solved
    /// state, the language or the reminder toggle could have changed.
    func refreshStreakReminder() {
        HunchNotifications.refreshStreakReminder(
            streak: streak,
            lastSolvedDay: lastSolvedDay,
            enabled: UserDefaults.standard.bool(forKey: "hunch.reminderOn"),
            loc: loc
        )
    }

    /// Re-writes both reminders in the current language. Notification copy is
    /// baked in when it's scheduled, so a pending reminder keeps speaking the
    /// old language until something re-schedules it — this is that something.
    func rescheduleReminders() {
        let d = UserDefaults.standard
        guard d.bool(forKey: "hunch.reminderOn") else { return }
        HunchNotifications.schedule(
            hour: d.object(forKey: "hunch.reminderHour") as? Int ?? 9,
            minute: d.object(forKey: "hunch.reminderMinute") as? Int ?? 0,
            loc: loc
        )
        refreshStreakReminder()
    }

    // MARK: - Ratings

    /// Asks for an App Store rating at a genuinely happy moment — a couple of wins
    /// in, or a good streak — and no more than a few times ever, well spaced.
    /// (StoreKit also enforces its own ~3/year cap.) A view watches
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
        guard !solved, !revealed else { return }
        revealed = true
        Feedback.play(.gaveUp)
        recordRound(solved: false)
        saveMyDuelResult()
        transientMessage = loc.theWordWasToast(target)
        saveDailyState()
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

        let useFree = freeHintsLeft > 0
        guard useFree || coins >= Self.hintCoinCost else {
            transientMessage = loc.hintsCost(Self.hintCoinCost)
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

        if useFree {
            let today = WordBank.dayIndex()
            if freeHintDay != today { freeHintDay = today; freeHintsUsedToday = 0 }
            freeHintsUsedToday += 1
        } else {
            coins -= Self.hintCoinCost
            Feedback.play(.coinSpent)
        }
        hintsUsed += 1
        submit(pick.word)
        transientMessage = loc.hintLands(pick.word, pick.rank)
        saveDailyState()
    }

    // MARK: - Coins shop

    /// Credits purchased coins (called back from CoinStore).
    func creditCoins(_ amount: Int) {
        coins += amount
        transientMessage = loc.plusCoins(amount)
        // Real money changed hands. Mirror it now, not at the next convenient
        // moment — a player who loses paid coins to a lost handset writes to
        // support, and rightly.
        CloudSync.push()
    }

    func buyCoins(_ product: Product) async {
        await coinStore.purchase(product)
    }

#if DEBUG
    /// Debug-only coin grant for testing. Compiled out of release builds.
    func debugAddCoins(_ amount: Int = 1000) {
        coins += amount
        transientMessage = "Debug +\(amount) coins"
    }

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

        return "Audit: \(rows.count) words · \(risky.count) risky · \(oov.count) OOV — see console"
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

    /// Questions are free — talking to Wick never costs coins (only hints do).
    /// Kept as a property so existing call sites read naturally.
    var canAffordQuestion: Bool { true }

    /// Typed questions work on every device: with Apple Intelligence the Keeper
    /// uses the on-device model; without it, Wick answers offline from the word's
    /// category tags (QuestionService.offlineAnswer).
    var canAsk: Bool {
        !solved && !revealed && canAffordQuestion
    }

    /// Tapped starter questions work on EVERY device — answers come from the
    /// on-device category tags, not the LLM — so this does not require AI.
    var canUseStarters: Bool {
        !solved && !revealed && canAffordQuestion
    }

    var questionUnavailableReason: String { keeper.unavailableReason }

    /// Tappable starter questions for this round. Seeded by the shared day index
    /// (never the secret word), so the set is identical for every player and
    /// leaks nothing. Already-asked questions are filtered out so chips retire
    /// as the player uses them. On devices without Apple Intelligence, only
    /// questions we can answer deterministically from the tags are shown, so
    /// every visible chip works.
    var starterQuestions: [StarterQuestions.Item] {
        let alreadyAsked = Set(questions.map { $0.question.lowercased() })
        let category = WordAttributes.category(for: target, language: language)
        return StarterQuestions.daily(dayIndex: WordBank.dayIndex()).filter { item in
            guard !alreadyAsked.contains(StarterQuestions.localizedFull(item, language).lowercased()) else { return false }
            if aiAvailable { return true }
            // No AI: only keep chips with a confident deterministic answer.
            guard let category,
                  WordAttributes.deterministicVerdict(word: target, language: language, category: category, property: item.key) != nil
            else { return false }
            return true
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
        guard !solved, !revealed, !isAsking,
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

    /// Handles a tapped starter chip. If the word's category gives a confident
    /// answer, we record it instantly — no model call, always correct, no
    /// variance. Otherwise we fall back to the on-device Keeper (which still
    /// receives the category facts).
    func askStarter(_ item: StarterQuestions.Item) async {
        guard !solved, !revealed, !isAsking else { return }
        let full = StarterQuestions.localizedFull(item, language)

        if let category = WordAttributes.category(for: target, language: language),
           let verdict = WordAttributes.deterministicVerdict(word: target, language: language, category: category, property: item.key) {
            // Questions are free now, so no coin gate — just record it, with a
            // short in-character flavor line so tapped chips feel like Wick too.
            let flavor = OfflineKeeper.reply(verdict: verdict, seed: full, language: language)
            questions.insert(AskedQuestion(question: full, verdict: verdict, reply: flavor,
                                           seq: guesses.count + questions.count, at: stampNow()), at: 0)
            Haptics.selection()
            quietQuestionNudge()
            saveDailyState()
            return
        }

        // No deterministic answer: hand it to ask(), which uses the on-device
        // model when available and the offline answerer otherwise.
        await ask(full)
    }

    func ask(_ raw: String) async {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !solved, !revealed, !isAsking else { return }

        failedQuestion = nil   // new attempt — clear any prior failure
        isAsking = true
        // Pass the round's prior exchanges (memory) and what Wick is currently
        // wearing (so he reacts truthfully to his own outfit).
        let wearing = wardrobe.equippedAccessories.map { loc.accessoryName($0.nameKey) }
        let result = await keeper.answer(question: q, secret: target,
                                         facts: WordAttributes.facts(for: target, language: language),
                                         history: questions, wearing: wearing)
        isAsking = false

        switch result {
        case .answered(let verdict, let reply):
            questions.insert(AskedQuestion(question: q, verdict: verdict, reply: reply,
                                           seq: guesses.count + questions.count, at: stampNow()), at: 0)
            quietQuestionNudge()
            saveDailyState()
        case .unavailable(let reason):
            transientMessage = reason
        case .failed:
            // Keep the question so the player can retry with one tap. No free
            // question or coins are spent on a failed answer.
            failedQuestion = q
            transientMessage = loc.keeperDidntRespond
        }
    }

    /// Re-asks the last question the Keeper failed to answer.
    func retryFailedQuestion() async {
        guard let q = failedQuestion, !isAsking else { return }
        await ask(q)
    }

    // MARK: - Sharing

    /// The copy-paste result card. Fully localized; a flag marks non-English
    /// rounds; the heat grid wraps at 10 per row so long rounds stay tidy; the
    /// streak flame rides along when it's worth bragging about.
    /// Emoji signature of whatever Wick is wearing, so cosmetics travel in shares.
    /// Empty when he's bare.
    private var outfitEmoji: String {
        let map: [String: String] = [
            "hat.tophat": "🎩", "hat.party": "🥳", "hat.wizard": "🧙", "hat.crown": "👑",
            "eyes.hearts": "😍", "eyes.googly": "👀", "eyes.star": "🤩",
            "face.glasses": "👓", "face.monocle": "🧐", "mouth.tongue": "😛",
            "neck.bowtie": "🎀", "neck.tie": "👔",
        ]
        let e = wardrobe.equippedAccessories.compactMap { map[$0.id] }.joined()
        return e.isEmpty ? "" : " \(e)"
    }

    /// "Wick #1359 🇩🇪 🎩" — the header on both the text share and the image card.
    /// Extracted so the two can never drift apart.
    private var shareTitle: String {
        let flag = language == .english ? "" : " \(language.flag)"
        switch mode {
        case .daily:    return "Wick #\(puzzleNumber)\(flag)\(outfitEmoji)"
        case .practice: return "Wick\(flag) · \(loc.practice)\(outfitEmoji)"
        case .archive:  return "Wick #\(puzzleNumber)\(flag)\(outfitEmoji)"
        case .duel:     return "Wick\(flag) · \(loc.duel)\(outfitEmoji)"
        }
    }

    /// "solved in 7 · 2 questions · 🔥2". Counts only — deliberately never the
    /// word, so both shares stay safe to post publicly on the day.
    private var shareStats: String {
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

        return "\(shareTitle) — \(shareStats)\n\(grid)\n\(loc.shareTagline)"
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
