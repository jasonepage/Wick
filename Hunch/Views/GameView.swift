//
//  GameView.swift
//  Hunch
//

import SwiftUI
import UIKit
import StoreKit

struct GameView: View {
    @Environment(GameViewModel.self) private var game
    @Environment(\.requestReview) private var requestReview
    @State private var guessText = ""
    @State private var showReveal = false
    @State private var showGiveUpConfirm = false
    @State private var showShop = false
    @State private var showSettings = false
    @State private var wickEggScale: CGFloat = 1
    @AppStorage("hunch.seenHowTo") private var seenHowTo = false
    @FocusState private var guessFocused: Bool
    /// Drives the guess-row reflow at accessibility text sizes — the fixed-width
    /// word column below cannot hold a word at AX5.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var coinPop = false
    @State private var showStarters = false

    /// Cute one-liners Wick says when you poke him. Never reveal anything.
    private static let pokeQuips = [
        "Hey, that tickles!", "Boop!", "I'm not telling, you know.",
        "Careful — I'm flammable.", "You rang?", "Still guarding the word…",
        "Stop poking, I'm concentrating!", "Warm hands, warm heart.",
        "Psst… the answer is… nope, almost got me.", "Hehe.",
    ]

    /// Hidden reactions for a few special guesses (purely for fun; scoring is
    /// unaffected). Shown only when the guess isn't the actual answer.
    private static let wordEggs: [String: String] = [
        "wick": "Hey, that's my name! But it's not the word.",
        "keeper": "I keep secrets — I don't hand them out.",
        "hunch": "Cute. That's the name of the game, not the word.",
        "flame": "Warm… but that's just my vibe.",
        "fire": "You're playing with fire now. Still not it though.",
        "secret": "Nice try!",
        "love": "Aww. Still guarding the word, though.",
        "answer": "If only it were that easy.",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                HunchTheme.background(for: game.bestScore)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: game.bestScore)

                ScrollView {
                    VStack(spacing: HunchTheme.Spacing.l) {
                        header
                        if let run = game.ghost {
                            GhostStripLive(
                                run: run,
                                startedAt: game.raceStartedAt,
                                finished: game.solved || game.revealed,
                                loc: game.loc
                            )
                        }
                        if let last = game.lastSubmitted {
                            heroCard(last)
                        } else if !game.solved && !game.revealed {
                            welcomeCard
                        }
                        if game.solved {
                            solvedCard
                        } else if game.revealed {
                            revealedCard
                        } else {
                            // Order is deliberate: the thing you came to do
                            // (type) sits directly under the board, help is
                            // offered below it, and the paid escape hatch
                            // (Hint) sits below that — and only once the
                            // player has actually tried something.
                            inputArea
                            wickOfferCard
                            hintButton
                            if game.guessCount == 0 && game.questions.isEmpty {
                                waysToPlayCard
                            }
                        }
                        feedSection
                    }
                    .padding(HunchTheme.Spacing.l)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                    .animation(.snappy(duration: 0.28), value: game.questionNudge)
                    .animation(.snappy(duration: 0.28), value: game.guessCount)
                }
            }
            .navigationTitle("Wick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Feedback.play(.selection); game.goHome() } label: {
                        Label(game.loc.home, systemImage: "house.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // ONE icon. Give up used to sit in the bar as a permanent flag,
                    // which offered surrender before the player had made a single
                    // guess; tucking it in here keeps it one tap away without
                    // putting it in front of them. Stats moved out entirely — it
                    // lives on Home ("Your stats"), which is where you go to look
                    // back, not mid-round.
                    Menu {
                        if !game.solved && !game.revealed {
                            Button(role: .destructive) {
                                Feedback.play(.selection)
                                showGiveUpConfirm = true
                            } label: {
                                Label(game.loc.giveUp, systemImage: "flag")
                            }
                        }
                        Button {
                            Feedback.play(.selection)
                            showSettings = true
                        } label: {
                            Label(game.loc.settings, systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel(game.loc.settings)
                }
            }
            .sheet(isPresented: $showShop) { ShopView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showReveal) {
                RevealView(word: game.target,
                           points: game.revealPoints,
                           loc: game.loc,
                           solvedInGuesses: game.solved ? game.guessCount : nil)
            }
            .fullScreenCover(isPresented: Binding(get: { !seenHowTo }, set: { _ in })) {
                HowToPlayView { seenHowTo = true }
            }
            .confirmationDialog(game.loc.giveUpTitle, isPresented: $showGiveUpConfirm, titleVisibility: .visible) {
                Button(game.loc.giveUp, role: .destructive) { game.giveUp() }
                Button(game.loc.keepTrying, role: .cancel) {}
            } message: {
                Text(game.loc.giveUpMessage)
            }
            .overlay(alignment: .bottom) { toast }
            .overlay { celebration }
            .onChange(of: game.reviewRequestID) { _, _ in
                // Let the solve celebration land first, then ask.
                Task { try? await Task.sleep(for: .seconds(1.2)); requestReview() }
            }
        }
    }

    // MARK: - Celebration overlay

    @ViewBuilder
    private var celebration: some View {
        if game.solved {
            ConfettiView()
                .id(game.target)          // replay for each newly solved word
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private func pokeWick() {
        game.transientMessage = Self.pokeQuips.randomElement()
    }

    // MARK: - Keeper mood (derived, UI-only)

    private var keeperMood: KeeperMood {
        if game.solved { return .celebrating }
        if game.revealed { return .defeated }
        if let last = game.lastSubmitted, last.known {
            return .forScore(last.score)
        }
        return .idle
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: HunchTheme.Spacing.s) {
            Text(titleText)
                .font(.headline)
                .lineLimit(1)
            HunchTag(text: game.loc.tier(game.targetTier), color: HunchTheme.Palette.keeper)
            Spacer(minLength: HunchTheme.Spacing.s)
            if game.streak > 0 {
                HunchChip(text: "\(game.streak)", systemImage: "flame.fill",
                          color: HunchTheme.Palette.flame)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(game.loc.streakDays(game.streak))
            }
            Button { showShop = true } label: {
                HunchChip(text: "\(game.coins)", systemImage: "circle.hexagongrid.fill",
                          color: HunchTheme.Palette.coin)
                    .scaleEffect(coinPop ? 1.22 : 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(game.coins) \(game.loc.coins)")
            .accessibilityHint(game.loc.a11yShop)
            .onChange(of: game.coins) { old, new in
                guard new > old else { return }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) { coinPop = true }
                Task {
                    try? await Task.sleep(for: .milliseconds(220))
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { coinPop = false }
                }
            }
#if DEBUG
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in game.debugAddCoins(10000) }
            )
#endif
        }
    }

    private var titleText: String {
        switch game.mode {
        case .daily: return game.loc.dailyTitle(game.puzzleNumber)
        case .practice: return game.loc.practice
        case .archive: return game.loc.dailyTitle(game.puzzleNumber)
        case .duel: return game.loc.duel
        }
    }

    // MARK: - Welcome (first guess of the round)

    private var welcomeCard: some View {
        VStack(spacing: HunchTheme.Spacing.s) {
            KeeperView(mood: .idle, size: 84, onPoke: pokeWick)
            KeeperSpeech(
                text: game.loc.welcome(KeeperView.name)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(HunchTheme.Spacing.l)
        .hunchCard(tint: HunchTheme.Palette.keeper, radius: HunchTheme.Radius.hero)
    }

    // MARK: - Hero (latest guess)

    @ViewBuilder
    private func heroCard(_ g: Guess) -> some View {
        if g.known {
            let rank = game.rank(forScore: g.score)
            let useRank = rank > 0
            let color = useRank ? HunchTheme.rankColor(rank) : HunchTheme.color(for: g.score)
            let fill = useRank ? HunchTheme.rankFill(rank, maxRank: game.maxRank) : g.score / 100
            let revealed = rank <= HunchTheme.rankRevealThreshold
            let big = useRank ? (revealed ? "#\(rank)" : game.loc.heat(HunchTheme.rankLabel(rank))) : "\(Int(g.score))"
            let label = useRank ? (revealed ? game.loc.heat(HunchTheme.rankLabel(rank)) : game.loc.keepGoing) : game.loc.heat(HunchTheme.label(for: g.score))

            VStack(spacing: HunchTheme.Spacing.m) {
                HStack(spacing: HunchTheme.Spacing.xl) {
                    ZStack {
                        Circle().stroke(color.opacity(0.15), lineWidth: 12)
                        Circle()
                            .trim(from: 0, to: max(0.02, fill))
                            .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text(big)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(color)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(color)
                        }
                        .padding(.horizontal, 10)
                    }
                    .frame(width: 124, height: 124)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: g.id)

                    KeeperView(mood: keeperMood, size: 72, onPoke: pokeWick)
                        .scaleEffect(wickEggScale)
                        .onChange(of: game.wickEggFlicker) { _, _ in
                            withAnimation(.easeOut(duration: 0.12)) { wickEggScale = 1.3 }
                            withAnimation(.easeIn(duration: 0.4).delay(0.12)) { wickEggScale = 1.0 }
                        }
                }

                Text(g.word)
                    .font(HunchTheme.Fonts.cardTitle)
                if let tr = game.learnTranslation(g.word) {
                    Text(tr)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(HunchTheme.Palette.keeper)
                }

                if let t = game.trajectory {
                    trajectoryPill(t)
                }
                if let line = wickLine {
                    KeeperSpeech(text: line)
                        .transition(.opacity)
                }
            }
            // The whole card is one verdict — "animal, boiling, rank 12, closest
            // yet". Left as separate elements it reads out as a ring, a number,
            // a label and a pill, in that order, which is four swipes to learn
            // one thing. Wick's line rides along at the end, or collapsing the
            // card would silence it entirely.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(heroA11y(word: g.word, big: big, label: label))
            .frame(maxWidth: .infinity)
            .padding(HunchTheme.Spacing.xl)
            .hunchCard(tint: color, radius: HunchTheme.Radius.hero)
            .animation(.easeInOut(duration: 0.25), value: g.id)
        } else {
            VStack(spacing: HunchTheme.Spacing.s) {
                KeeperView(mood: .unamused, size: 72, onPoke: pokeWick)
                Text(g.word)
                    .font(HunchTheme.Fonts.cardTitle)
                Text(game.loc.notInVocabulary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let coach = game.coachTip {
                    KeeperSpeech(text: coach)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(HunchTheme.Spacing.xl)
            .hunchCard(radius: HunchTheme.Radius.hero)
        }
    }

    // MARK: - Trajectory ("warmer / colder")

    @ViewBuilder
    private func trajectoryPill(_ t: GameViewModel.GuessTrajectory) -> some View {
        if t.isFirst {
            pill(text: game.loc.firstGuess,
                 systemImage: "sparkles",
                 color: HunchTheme.Palette.keeper)
        } else if t.isNewBest {
            let spots = t.spotsGained
            let text = spots != nil && spots! > 0
                ? game.loc.warmestUp(spots!)
                : game.loc.warmest
            pill(text: text, systemImage: "flame.fill", color: HunchTheme.Palette.hot)
        } else {
            pill(text: game.loc.colder,
                 systemImage: "snowflake",
                 color: HunchTheme.Palette.freezing)
        }
    }

    private func pill(text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.22), lineWidth: 1))
    }

    // MARK: - Input

    private var inputArea: some View {
        HStack(spacing: HunchTheme.Spacing.s) {
            HStack(spacing: HunchTheme.Spacing.s) {
                // The field's leading glyph is the mode read-out: a target
                // when this will be scored as a guess, a speech bubble when
                // it will be sent to Wick. It changes as you type, so the
                // dual-purpose field stops being a guessing game of its own.
                Image(systemName: draftIsQuestion ? "bubble.left.fill" : "target")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(draftTint)
                    .frame(width: 16)
                    .contentTransition(.symbolEffect(.replace))

                TextField(game.loc.guessOrAskPlaceholder, text: $guessText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($guessFocused)
                    .submitLabel(.send)
                    .onSubmit(submitInput)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: HunchTheme.Radius.field, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HunchTheme.Radius.field, style: .continuous)
                    .strokeBorder(draftTint.opacity(guessText.isEmpty ? 0 : 0.35), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.18), value: draftIsQuestion)

            if game.isAsking {
                ProgressView().frame(width: 34, height: 34)
            } else {
                Button(action: submitInput) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(draftTint)
                }
                .disabled(guessText.trimmingCharacters(in: .whitespaces).isEmpty)
                .animation(.easeInOut(duration: 0.18), value: draftIsQuestion)
                .accessibilityLabel(game.loc.a11ySend)
            }
        }
    }

    /// Whether what's currently typed will be sent to Wick as a question rather
    /// than scored as a guess. Drives the field's leading glyph and tint, so the
    /// dual-purpose input tells you which of the two it's about to do.
    private var draftIsQuestion: Bool {
        let trimmed = guessText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && isQuestion(trimmed)
    }

    private var draftTint: Color {
        draftIsQuestion ? HunchTheme.Palette.keeper : HunchTheme.Palette.hot
    }

    // MARK: - Hint (demoted until the player has actually tried)

    /// Hint costs coins, so it has no business being the loudest control on a
    /// board where nothing has been guessed yet. It appears after the first
    /// guess as a quiet link, and only grows into a real button once the player
    /// looks stuck.
    @ViewBuilder
    private var hintButton: some View {
        if game.guessCount >= 1 {
            let urgent = game.coldStreak >= 3 || game.guessCount >= 6
            Button {
                guessFocused = false
                game.revealHint()
            } label: {
                Label(game.freeHintsLeft > 0
                      ? game.loc.hintFreeLeft(game.freeHintsLeft)
                      : game.loc.hintCoinPrice(GameViewModel.hintCoinCost),
                      systemImage: "lightbulb.fill")
                    .font(urgent ? HunchTheme.Fonts.label : .subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, urgent ? 12 : 6)
            }
            .buttonStyle(.bordered)
            .tint(HunchTheme.Palette.warm)
            .opacity(urgent ? 1 : 0.75)
            .animation(.easeInOut(duration: 0.25), value: urgent)
        }
    }

    // MARK: - Opening legend

    /// Shown only on a board with nothing on it. Names the two verbs of the
    /// game side by side — and hands the player one real, tappable question so
    /// the second verb is used once before it's ever needed. Disappears the
    /// moment the round actually starts, so it never becomes clutter.
    @ViewBuilder
    private var waysToPlayCard: some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.m) {
            Text(game.loc.waysTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            wayRow(icon: "target",
                   tint: HunchTheme.Palette.hot,
                   title: game.loc.wayGuessTitle,
                   detail: game.loc.wayGuessBody)

            Divider().opacity(0.35)

            wayRow(icon: "bubble.left.fill",
                   tint: HunchTheme.Palette.keeper,
                   title: game.loc.wayAskTitle,
                   detail: game.loc.wayAskBody)

            if game.canUseStarters, !game.isAsking, let item = game.offeredStarter {
                starterRow(item)
            }
        }
        .padding(HunchTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hunchCard()
    }

    private func wayRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: HunchTheme.Spacing.m) {
            Image(systemName: icon)
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Wick's adaptive offer

    /// Wick offering to answer something, in character, at the moment it helps:
    /// after a cold streak, after a few flat guesses, or once it's clear the
    /// player hasn't discovered questions at all. One tap sends it; "Something
    /// else" opens the rest; "Not now" snoozes him for a few guesses instead of
    /// leaving a dead control on screen.
    @ViewBuilder
    private var wickOfferCard: some View {
        if let reason = game.questionNudge, let item = game.offeredStarter {
            VStack(alignment: .leading, spacing: HunchTheme.Spacing.m) {
                HStack(alignment: .center, spacing: HunchTheme.Spacing.m) {
                    KeeperView(mood: .idle, size: 40, onPoke: pokeWick)
                    Text(offerLine(reason))
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                starterRow(item)

                HStack(spacing: HunchTheme.Spacing.m) {
                    Button {
                        guessFocused = false
                        withAnimation(.easeInOut(duration: 0.2)) { showStarters.toggle() }
                    } label: {
                        Label(game.loc.offerAskElse,
                              systemImage: showStarters ? "chevron.up" : "chevron.down")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(HunchTheme.Palette.keeper)

                    Spacer(minLength: 0)

                    Button {
                        withAnimation(.snappy) {
                            showStarters = false
                            game.snoozeQuestionNudge()
                        }
                    } label: {
                        Text(game.loc.offerNotNow)
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                if showStarters {
                    VStack(spacing: HunchTheme.Spacing.s) {
                        ForEach(otherStarters, id: \.self) { other in
                            starterRow(other)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(HunchTheme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hunchCard(tint: HunchTheme.Palette.keeper)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// The remaining suggestions, minus the one already offered.
    private var otherStarters: [StarterQuestions.Item] {
        let offered = game.offeredStarter
        return Array(game.starterQuestions.filter { $0 != offered }.prefix(4))
    }

    private func offerLine(_ reason: GameViewModel.QuestionNudge) -> String {
        switch reason {
        case .stuck:   return game.loc.offerStuck
        case .cold:    return game.loc.offerCold
        case .routine: return game.loc.offerRoutine
        }
    }

    /// One tappable, prefilled question. Used both in the opening legend and in
    /// Wick's offer so the affordance reads identically wherever it shows up.
    private func starterRow(_ item: StarterQuestions.Item) -> some View {
        Button {
            guessFocused = false
            Task { await game.askStarter(item) }
        } label: {
            HStack(spacing: HunchTheme.Spacing.s) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(HunchTheme.Palette.keeper)
                Text(StarterQuestions.localizedFull(item, game.language))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(HunchTheme.Palette.keeper.opacity(0.55))
            }
            .padding(.horizontal, HunchTheme.Spacing.m)
            .padding(.vertical, HunchTheme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: HunchTheme.Radius.field, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HunchTheme.Radius.field, style: .continuous)
                    .strokeBorder(HunchTheme.Palette.keeper.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(game.isAsking)
        .accessibilityHint(game.loc.a11yAskThis)
    }

    /// One input, two actions: a bare word is scored as a guess; anything with a
    /// space or a trailing "?" — or an explicit tap on "Ask Wick" — is sent to
    /// Wick as a yes/no question.
    private func submitInput() {
        let raw = guessText
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let asking = draftIsQuestion
        guessText = ""

        if asking {
            guessFocused = false
            Task { await game.ask(trimmed) }
            return
        }

        game.submit(raw)
        // Hidden reaction for a few playful guesses — only if it wasn't the
        // answer and nothing more important is already being shown.
        let key = trimmed.lowercased()
        if !game.solved, key != game.target, game.transientMessage == nil,
           let egg = Self.wordEggs[key] {
            game.transientMessage = egg
        }
    }

    /// Guesses are always single words, so a space or trailing "?" marks a question.
    private func isQuestion(_ s: String) -> Bool {
        s.hasSuffix("?") || s.contains(" ")
    }

    // MARK: - The Reveal

    /// Opens "The Reveal" — the post-round semantic map of your guesses.
    private var revealMapButton: some View {
        Button {
            Feedback.play(.selection)
            showReveal = true
        } label: {
            Label(game.loc.revealSeeMap, systemImage: "scope")
                .frame(maxWidth: .infinity).padding(.vertical, 11)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Solved

    private var solvedCard: some View {
        VStack(spacing: HunchTheme.Spacing.m) {
            KeeperView(mood: .celebrating, size: 92, onPoke: pokeWick)
            Text(game.loc.solvedTitle).font(.title2.bold())
            Text(game.loc.solvedIn(game.target, game.guessCount))
                .foregroundStyle(.secondary)
            if game.learnTranslation(game.target) != nil {
                learnLabel(game.target)
                    .font(.headline)
            }
            if game.streak > 1 {
                Label(game.loc.streakDays(game.streak), systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HunchTheme.Palette.flame)
            }
            raceShareButton
            if game.currentDuel != nil {
                duelResultShareButton
            } else {
                Button {
                    // Emoji grid AND the semantic map image — the grid is what
                    // every guessing game shares, the map is the one only this
                    // game can. Both are spoiler-free; see RevealShareCard.
                    ShareSheet.present(game.shareItems())
                } label: {
                    Label(game.loc.shareResult, systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent)
                .tint(HunchTheme.Palette.solved)
            }
            revealMapButton
            Menu {
                Button(game.loc.easy) { game.startPractice(tier: 2) }
                Button(game.loc.medium) { game.startPractice(tier: 3) }
                Button(game.loc.hard) { game.startPractice(tier: 4) }
            } label: {
                Label(game.loc.playRandom, systemImage: "dice.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
            }
            .buttonStyle(.bordered)
        }
        .padding(HunchTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .hunchCard(tint: HunchTheme.Palette.solved, radius: HunchTheme.Radius.hero)
    }

    // MARK: - Revealed (gave up)

    private var revealedCard: some View {
        VStack(spacing: HunchTheme.Spacing.m) {
            KeeperView(mood: .defeated, size: 80, onPoke: pokeWick)
            Text(game.loc.theWordWas).font(.subheadline).foregroundStyle(.secondary)
            Text(game.target)
                .font(HunchTheme.Fonts.revealWord)
            if let tr = game.learnTranslation(game.target) {
                Text(tr)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HunchTheme.Palette.keeper)
            }
            // A give-up is still a run worth racing — same as web.
            raceShareButton
            // Even a give-up counts in a duel — let the player send their result.
            if game.currentDuel != nil { duelResultShareButton }
            revealMapButton
            Menu {
                Button(game.loc.easy) { game.startPractice(tier: 2) }
                Button(game.loc.medium) { game.startPractice(tier: 3) }
                Button(game.loc.hard) { game.startPractice(tier: 4) }
            } label: {
                Label(game.loc.playRandom, systemImage: "dice.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .padding(.top, HunchTheme.Spacing.xs)
        }
        .padding(HunchTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .hunchCard(radius: HunchTheme.Radius.hero)
    }

    /// "Race a friend" / "Race them back". Shown on BOTH end cards — solved and
    /// gave-up — because a give-up is still a perfectly good run to race against,
    /// and because keeping them in one place stops the two drifting apart.
    @ViewBuilder
    private var raceShareButton: some View {
        if let run = game.ghostRun() {
            Button {
                Feedback.play(.selection)
                // Same wording as the web share sheet (shareRace in main.ts):
                // a solved round leads with your time, an unsolved one just dares.
                let text = run.solved
                    ? game.loc.raceShareSolved(Ghost.formatDuration(ms: run.durationMs))
                    : game.loc.raceShareUnsolved
                Events.track(.raceLinkCreated, n: run.mode == .daily ? run.ref : nil)
                ShareSheet.present([text, Ghost.link(run)])
            } label: {
                Label(game.ghost == nil ? game.loc.raceAFriend : game.loc.raceThemBack,
                      systemImage: "flag.checkered")
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(HunchTheme.Palette.hot)
        }
    }

    /// Shares the player's duel result code (WR-…) so a friend can compare
    /// head-to-head. Shown only inside a duel, after it ends.
    @ViewBuilder
    private var duelResultShareButton: some View {
        if let code = game.duelResultCode() {
            Button {
                ShareSheet.present([game.loc.duelResultMsg(code)])
            } label: {
                Label(game.loc.duelResultShare, systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(HunchTheme.Palette.keeper)
        }
    }

    // MARK: - Guess list

    // MARK: - Unified feed (guesses + questions, newest first)

    @ViewBuilder
    private var feedSection: some View {
        if game.failedQuestion != nil || !game.feed.isEmpty {
            VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
                if let hint = game.spellingHint {
                    HStack(spacing: HunchTheme.Spacing.xs) {
                        Image(systemName: "key.fill").font(.caption)
                        Text(hint).font(.subheadline.weight(.semibold))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(HunchTheme.Palette.warm)
                    .padding(.horizontal, HunchTheme.Spacing.m)
                    .padding(.vertical, HunchTheme.Spacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HunchTheme.Palette.warm.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: HunchTheme.Radius.field))
                }
                if let failed = game.failedQuestion {
                    failedQuestionCard(failed)
                }
                if !game.feed.isEmpty {
                HStack(spacing: HunchTheme.Spacing.s) {
                    Text(game.loc.roundLog)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer(minLength: 0)
                    feedSortToggle
                }
                .padding(.leading, HunchTheme.Spacing.xs)

                VStack(spacing: HunchTheme.Spacing.m) {
                    ForEach(game.feed) { item in
                        switch item {
                        case .guess(let g):    guessRow(g)
                        case .question(let q): questionRow(q)
                        }
                    }
                }
                .padding(HunchTheme.Spacing.l)
                .hunchCard()
                }
            }
        }
    }

    /// Compact two-chip toggle for the round-log order: newest first, or
    /// hottest guesses first. Persisted across rounds.
    private var feedSortToggle: some View {
        HStack(spacing: 2) {
            feedSortChip(.recent,  icon: "clock",      label: game.loc.sortRecent)
            feedSortChip(.closest, icon: "flame.fill", label: game.loc.sortClosest)
        }
        .padding(2)
        .background(Capsule().fill(.quaternary.opacity(0.5)))
    }

    private func feedSortChip(_ sort: GameViewModel.FeedSort, icon: String, label: String) -> some View {
        let selected = game.feedSort == sort
        return Button {
            guard !selected else { return }
            withAnimation(.snappy) { game.feedSort = sort }
            Haptics.selection()
        } label: {
            Label(label, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .padding(.horizontal, HunchTheme.Spacing.s)
                .padding(.vertical, 4)
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .background(
                    Capsule().fill(selected ? AnyShapeStyle(.background) : AnyShapeStyle(.clear))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - VoiceOver composers
    //
    // Composed from copy that is already localized (the word, the heat band, the
    // rank, the trajectory pill) rather than from new translated sentences —
    // fewer strings to keep in parity across five tables, and the screen reader
    // says exactly what the screen says.

    /// Whatever Wick has to say about the last guess. Coaching wins while the
    /// player is still learning the game — a first-timer needs "cold means wrong
    /// topic, not wrong word" far more than they need "ooh, you're circling it".
    private var wickLine: String? {
        game.coachTip ?? game.keeperNudge
    }

    /// "animal. Boiling. 12. Closest yet. Cold doesn't mean it's a bad word…"
    private func heroA11y(word: String, big: String, label: String) -> String {
        var parts = [word, label, big.replacingOccurrences(of: "#", with: "")]
        if let t = game.trajectory {
            if t.isFirst { parts.append(game.loc.firstGuess) }
            else if t.isNewBest { parts.append(game.loc.warmest) }
            else { parts.append(game.loc.colder) }
        }
        if let line = wickLine { parts.append(line) }
        return parts.joined(separator: ". ")
    }

    /// "animal. Boiling. 12." — or the raw score on a board with no ranks yet.
    private func guessA11y(_ g: Guess, rank: Int) -> String {
        let word = game.learnTranslation(g.word).map { "\(g.word), \($0)" } ?? g.word
        if rank > 0 {
            return "\(word). \(game.loc.heat(HunchTheme.rankLabel(rank))). \(rank)."
        }
        return "\(word). \(game.loc.heat(HunchTheme.label(for: g.score))). \(Int(g.score))."
    }

    /// "Yes. Is it an animal? Quite so."
    private func questionA11y(_ q: AskedQuestion) -> String {
        var parts: [String] = []
        if !q.verdict.isEmpty { parts.append(game.displayVerdict(q.verdict)) }
        parts.append(q.question)
        if !q.reply.isEmpty { parts.append(q.reply) }
        return parts.joined(separator: ". ")
    }

    /// A word, shown as "word → translation" when Learn mode has a known pairing
    /// (the translation is emphasized; the original dims). Plain word otherwise.
    private func learnLabel(_ word: String) -> Text {
        if let tr = game.learnTranslation(word) {
            return Text(word).foregroundStyle(.secondary)
                + Text("  →  ").foregroundStyle(.tertiary)
                + Text(tr)
        }
        return Text(word)
    }

    /// A guess row: word + closeness bar + rank/label, colored by how warm it is.
    @ViewBuilder
    private func guessRow(_ g: Guess) -> some View {
        let rank = game.rank(forScore: g.score)
        let color = rank > 0 ? HunchTheme.rankColor(rank) : HunchTheme.color(for: g.score)
        let fill = rank > 0 ? HunchTheme.rankFill(rank, maxRank: game.maxRank) : g.score / 100
        let heat = rank > 0 ? game.loc.heat(HunchTheme.rankShortText(rank)) : "\(Int(g.score))"

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // The word column is a fixed 104pt (152 in Learn mode), which is
                // the right call at normal sizes and impossible at AX3 and up —
                // the word gets clipped or squashed to 60%. Stack instead.
                VStack(alignment: .leading, spacing: HunchTheme.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: HunchTheme.Spacing.s) {
                        learnLabel(g.word)
                            .font(.body.weight(.semibold))
                        Spacer(minLength: 0)
                        Text(heat)
                            .font(.body.weight(.bold))
                            .foregroundStyle(color)
                    }
                    ClosenessBar(fill: fill, color: color)
                }
            } else {
                HStack(spacing: HunchTheme.Spacing.m) {
                    learnLabel(g.word)
                        .font(.body.weight(.semibold))
                        .frame(width: game.learnMode ? 152 : 104, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    ClosenessBar(fill: fill, color: color)
                    Text(heat)
                        .font(.body.weight(.bold))
                        .foregroundStyle(color)
                        .frame(width: 64, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 2)
        // Warmth is carried entirely by a colour and a bar length, neither of
        // which VoiceOver can convey. Speak the verdict instead.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(guessA11y(g, rank: rank))
    }

    /// A question row: Wick's yes/no verdict tag + the question (and any reply).
    private func questionRow(_ q: AskedQuestion) -> some View {
        HStack(alignment: .top, spacing: HunchTheme.Spacing.m) {
            if !q.verdict.isEmpty {
                HunchTag(text: game.displayVerdict(q.verdict), color: HunchTheme.verdictColor(q.verdict))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(q.question)
                    .font(.body)
                if !q.reply.isEmpty {
                    Text(q.reply)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "bubble.left.fill")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(questionA11y(q))
    }

    /// Shown when the on-device Keeper failed to answer — offers a one-tap retry.
    private func failedQuestionCard(_ question: String) -> some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.xs) {
            Text(question).font(.subheadline.weight(.semibold))
            HStack(spacing: HunchTheme.Spacing.s) {
                Label(game.loc.keeperNoRespond, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if game.isAsking {
                    ProgressView()
                } else {
                    Button {
                        Task { await game.retryFailedQuestion() }
                    } label: {
                        Label(game.loc.retry, systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HunchTheme.Palette.keeper)
                }
            }
        }
        .padding(HunchTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hunchCard(tint: HunchTheme.Palette.warm, radius: HunchTheme.Radius.field)
    }

    // MARK: - Toast

    @ViewBuilder private var toast: some View {
        if let msg = game.transientMessage {
            Text(msg)
                .font(.subheadline)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 12)
                .onTapGesture { game.transientMessage = nil }
                .task(id: msg) {
                    try? await Task.sleep(for: .seconds(2.5))
                    if game.transientMessage == msg { game.transientMessage = nil }
                }
        }
    }
}

#Preview {
    GameView().environment(GameViewModel())
}
