//
//  HowToPlayView.swift
//  Hunch
//

import SwiftUI

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GameViewModel.self) private var game
    var onClose: (() -> Void)? = nil

    private struct Step: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let title: String
        let detail: String
    }

    private var steps: [Step] {
        [
            Step(icon: "brain.head.profile", color: HunchTheme.Palette.freezing,
                 title: game.loc.howStep1Title, detail: game.loc.howStep1Detail),
            Step(icon: "thermometer.medium", color: HunchTheme.Palette.hot,
                 title: game.loc.howStep2Title, detail: game.loc.howStep2Detail),
            Step(icon: "sparkles", color: HunchTheme.Palette.keeper,
                 title: game.loc.howStep3Title, detail: game.loc.howStep3Detail),
            Step(icon: "calendar", color: HunchTheme.Palette.warm,
                 title: game.loc.howStep4Title, detail: game.loc.howStep4Detail)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HunchTheme.Spacing.l) {
                    // Meet the Keeper
                    VStack(spacing: HunchTheme.Spacing.s) {
                        KeeperView(mood: .idle, size: 92)
                        Text(game.loc.meetKeeper)
                            .font(HunchTheme.Fonts.cardTitle)
                        Text(game.loc.meetKeeperSub)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HunchTheme.Spacing.s)

                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: HunchTheme.Spacing.l) {
                            ZStack {
                                Circle().fill(step.color.opacity(0.14)).frame(width: 46, height: 46)
                                Image(systemName: step.icon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(step.color)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.title).font(.headline)
                                Text(step.detail).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
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
                .buttonStyle(.borderedProminent)
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

    private func close() {
        onClose?()
        dismiss()
    }
}

#Preview {
    HowToPlayView().environment(GameViewModel())
}
