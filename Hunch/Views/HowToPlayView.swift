//
//  HowToPlayView.swift
//  Hunch
//
//  3.6: How to play is a glance, not a read. The big button replays the
//  hands-on tutorial level (the real way to learn); under it, four rules of a
//  few words each, shown rather than told: the heat bar, a real question with
//  Wick's answer, the hint, and the daily race.
//

import SwiftUI

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GameViewModel.self) private var game
    var onClose: (() -> Void)? = nil
    /// Replaces the default "Play the tutorial" action (dismiss, then start).
    /// Settings passes one so it can close itself too.
    var onPlayTutorial: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HunchTheme.Spacing.l) {
                    tutorialButton

                    ruleCard(icon: "thermometer.medium", tint: HunchTheme.Palette.hot,
                             text: game.loc.howGuessLine) {
                        HeatScaleStrip(fill: nil, loc: game.loc)
                    }

                    ruleCard(icon: "bubble.left.fill", tint: HunchTheme.Palette.keeper,
                             text: game.loc.howAskLine) {
                        // A real exchange, the way it shows in the round log.
                        HStack(spacing: HunchTheme.Spacing.s) {
                            HunchTag(text: game.displayVerdict("Yes"), color: HunchTheme.verdictColor("Yes"))
                            Text(game.tutorialQuestion)
                                .font(.subheadline.weight(.medium))
                            Spacer(minLength: 0)
                        }
                    }

                    ruleCard(icon: "lightbulb.fill", tint: HunchTheme.Palette.warm,
                             text: game.loc.howHintLine) { EmptyView() }

                    ruleCard(icon: "trophy.fill", tint: HunchTheme.Palette.coin,
                             text: game.loc.howDailyLine) { EmptyView() }
                }
                .padding(HunchTheme.Spacing.xl)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: close) {
                    Text(game.loc.letsPlay)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
                .frame(maxWidth: 560)
                .padding(.horizontal, HunchTheme.Spacing.xl)
                .padding(.vertical, HunchTheme.Spacing.m)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
            .navigationTitle(game.loc.howToPlay)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// The hero: Wick and one big "Play the tutorial".
    private var tutorialButton: some View {
        Button(action: playTutorial) {
            HStack(spacing: HunchTheme.Spacing.m) {
                KeeperView(mood: .idle, size: 60, showsAccessories: false)
                    .frame(width: 60)
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.loc.tutPlayTutorial)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(game.loc.tutPlayTutorialSub)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(HunchTheme.Palette.keeper)
            }
            .padding(HunchTheme.Spacing.l)
            .frame(maxWidth: .infinity)
            .background(HunchTheme.Palette.keeper.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: HunchTheme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HunchTheme.Radius.card, style: .continuous)
                .strokeBorder(HunchTheme.Palette.keeper.opacity(0.35), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    /// One rule: an icon, a few words, and (optionally) the thing itself.
    private func ruleCard<Extra: View>(icon: String, tint: Color, text: String,
                                       @ViewBuilder extra: () -> Extra) -> some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.m) {
            HStack(spacing: HunchTheme.Spacing.m) {
                ZStack {
                    Circle().fill(tint.opacity(0.14)).frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Text(text)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            extra()
        }
        .padding(HunchTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hunchCard()
    }

    private func playTutorial() {
        Feedback.play(.selection)
        if let onPlayTutorial {
            onPlayTutorial()
            return
        }
        onClose?()
        dismiss()
        // Let the sheet slide away first, so the board isn't swapped under it.
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            game.startTutorial()
        }
    }

    private func close() {
        onClose?()
        dismiss()
    }
}

#Preview {
    HowToPlayView().environment(GameViewModel())
}
