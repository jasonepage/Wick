//
//  AskQuestionView.swift
//  Hunch
//
//  Ask the on-device Keeper yes/no-ish questions about the secret word.
//

import SwiftUI
import UIKit

struct AskQuestionView: View {
    @Environment(GameViewModel.self) private var game
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var mode: InputMode = .ask

    private enum InputMode: String, CaseIterable {
        case ask = "Ask"
        case guess = "Guess"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !game.aiAvailable {
                    banner(game.loc.offlineBanner, system: "sparkles")
                }
                if game.scoringUnavailable {
                    // Persistent (not a 2.5s toast): the language's dictionary is
                    // still downloading, so guesses can't be scored yet. Show the
                    // fix — the keyboard trick — where the player can actually read it.
                    banner(game.loc.scoringKeyboardHint, system: "keyboard")
                }

                ScrollView {
                    VStack(spacing: HunchTheme.Spacing.s) {
                        keeperHeader

                        if game.isLoadingClue {
                            clueCard(game.loc.dreamingClue(KeeperView.name), loading: true)
                        } else if let clue = game.openingClue {
                            KeeperSpeech(text: clue)
                        }
                        if game.questions.isEmpty {
                            Text(game.loc.askIntro)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, HunchTheme.Spacing.l)
                                .padding(.horizontal, HunchTheme.Spacing.xl)
                        }

                        starterChips

                        if let failed = game.failedQuestion {
                            failedCard(failed)
                        }
                        ForEach(game.questions) { q in
                            questionCard(q)
                        }
                    }
                    .padding(HunchTheme.Spacing.l)
                    .readableWidth()
                }

                inputBar
            }
            .navigationTitle(game.loc.askTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(game.loc.done) { dismiss() }
                }
            }
            .task { await game.ensureOpeningClue() }
        }
    }

    // MARK: - Keeper header

    private var keeperHeader: some View {
        KeeperView(mood: keeperMood, size: 76)
            .padding(.top, HunchTheme.Spacing.xs)
    }

    private var keeperMood: KeeperMood {
        if game.isAsking || game.isLoadingClue { return .thinking }
        if game.solved { return .celebrating }
        return .idle
    }

    // MARK: - Cards

    private func clueCard(_ text: String, loading: Bool) -> some View {
        HStack(alignment: .top, spacing: HunchTheme.Spacing.s) {
            Image(systemName: "sparkles")
                .foregroundStyle(HunchTheme.Palette.keeper)
            if loading {
                ProgressView()
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text(text).font(.subheadline)
            }
            Spacer(minLength: 0)
        }
        .padding(HunchTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hunchCard(tint: HunchTheme.Palette.keeper, radius: HunchTheme.Radius.field)
    }

    /// Shown when the on-device Keeper failed to answer — offers a one-tap retry.
    private func failedCard(_ question: String) -> some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.xs) {
            Text(question).font(.subheadline.weight(.semibold))
            HStack(alignment: .center, spacing: HunchTheme.Spacing.s) {
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

    private func questionCard(_ q: AskedQuestion) -> some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.xs) {
            Text(q.question).font(.subheadline.weight(.semibold))
            HStack(alignment: .top, spacing: HunchTheme.Spacing.s) {
                if !q.verdict.isEmpty {
                    HunchTag(text: game.displayVerdict(q.verdict), color: HunchTheme.verdictColor(q.verdict))
                }
                if !q.reply.isEmpty {
                    Text(q.reply).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .padding(HunchTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hunchCard(radius: HunchTheme.Radius.field)
    }

    // MARK: - Input bar

    /// Tappable starter questions to scaffold the start of a round. Same set for
    /// every player (seeded by the day, not the word). Hidden once the Keeper is
    /// unavailable, the round is over, or the player has used them all.
    @ViewBuilder
    private var starterChips: some View {
        // Show just two suggestions at a time. As the player taps one it's
        // recorded and the next pair fills in — far calmer than a wall of chips.
        let suggestions = Array(game.starterQuestions.prefix(2))
        if game.canUseStarters && !game.isAsking && !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
                Text(game.loc.suggestedQuestions)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, HunchTheme.Spacing.xs)

                ForEach(suggestions, id: \.self) { item in
                    Button {
                        Task { await game.askStarter(item) }
                    } label: {
                        HStack(spacing: HunchTheme.Spacing.s) {
                            Image(systemName: "sparkles")
                                .font(.subheadline)
                                .foregroundStyle(HunchTheme.Palette.warm)
                            Text(StarterQuestions.localizedFull(item, game.language))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
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
                                .strokeBorder(.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, HunchTheme.Spacing.xs)
        }
    }

    private var inputBar: some View {
        VStack(spacing: HunchTheme.Spacing.s) {
            Picker("Mode", selection: $mode) {
                ForEach(InputMode.allCases, id: \.self) { m in
                    Text(m == .ask ? game.loc.askTab : game.loc.guessTab).tag(m)
                }
            }
            .pickerStyle(.segmented)

            if mode == .guess, let g = game.lastSubmitted {
                HStack {
                    Text(g.word).font(.subheadline.weight(.semibold))
                    Spacer()
                    if g.known {
                        let rank = game.rank(forScore: g.score)
                        let txt = rank <= 0 ? game.loc.heat(HunchTheme.label(for: g.score))
                            : (rank <= HunchTheme.rankRevealThreshold
                               ? "#\(rank) · \(game.loc.heat(HunchTheme.rankLabel(rank)))"
                               : game.loc.heat(HunchTheme.rankLabel(rank)))
                        Text(txt)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(rank > 0 ? HunchTheme.rankColor(rank) : HunchTheme.color(for: g.score))
                    } else {
                        Text(game.loc.notAKnownWord).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(footnoteText)
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: HunchTheme.Spacing.s) {
                TextField(mode == .ask ? game.loc.askPlaceholder : game.loc.guessPlaceholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(
                        Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: HunchTheme.Radius.field, style: .continuous)
                    )
                if game.isAsking && mode == .ask {
                    ProgressView().frame(width: 32)
                } else {
                    Button(action: send) {
                        Image(systemName: "paperplane.circle.fill").font(.system(size: 32))
                    }
                    .disabled(sendDisabled)
                }
            }
        }
        .padding(HunchTheme.Spacing.m)
        .background(.bar)
    }

    private var sendDisabled: Bool {
        if text.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        return mode == .ask && !game.canAsk
    }

    private var footnoteText: String {
        if mode == .ask && !game.aiAvailable {
            return game.loc.offlineFootnote
        }
        // Questions are free now — only hints cost coins.
        return game.loc.questionsFree
    }

    private func banner(_ text: String, system: String) -> some View {
        Label(text, systemImage: system)
            .font(.footnote)
            .padding(HunchTheme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HunchTheme.Palette.warm.opacity(0.15))
    }

    private func send() {
        let input = text
        text = ""
        if mode == .ask {
            Task { await game.ask(input) }
        } else {
            game.submit(input)
            if game.solved { dismiss() }
        }
    }
}

#Preview {
    AskQuestionView().environment(GameViewModel())
}
