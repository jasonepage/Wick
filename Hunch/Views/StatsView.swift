//
//  StatsView.swift
//  Hunch
//

import SwiftUI
import UIKit

struct StatsView: View {
    @Environment(GameViewModel.self) private var game
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HunchTheme.Spacing.l) {
                    LazyVGrid(columns: columns, spacing: HunchTheme.Spacing.m) {
                        statCard(game.loc.currentStreak, value: "\(game.currentStreak)",
                                 system: "flame.fill", color: HunchTheme.Palette.flame)
                        statCard(game.loc.bestStreak, value: "\(game.bestStreak)",
                                 system: "crown.fill", color: HunchTheme.Palette.warm)
                        statCard(game.loc.wordsSolved, value: "\(game.solves)",
                                 system: "checkmark.seal.fill", color: HunchTheme.Palette.solved)
                        statCard(game.loc.avgGuesses, value: averageText,
                                 system: "chart.bar.fill", color: HunchTheme.Palette.freezing)
                        statCard(game.loc.fewestGuesses, value: bestGuessText,
                                 system: "target", color: HunchTheme.Palette.hot)
                        statCard(game.loc.coins, value: "\(game.coins)",
                                 system: "circle.hexagongrid.fill", color: HunchTheme.Palette.coin)
                    }
                    achievementsLink
                    leaderboardsLink
                }
                .padding(HunchTheme.Spacing.l)
                .readableWidth()
            }
            .navigationTitle(game.loc.yourStats)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(game.loc.done) { dismiss() }
                }
            }
        }
    }

    private var averageText: String {
        game.solves > 0 ? String(format: "%.1f", game.averageGuesses) : "—"
    }

    private var bestGuessText: String {
        game.bestGuessCount > 0 ? "\(game.bestGuessCount)" : "—"
    }

    /// The ONLY place Game Center is ever reached from. Tapping it is the
    /// player's explicit request to be ranked; nothing authenticates before
    /// this. See `GameCenter.swift` for why that matters.
    private var leaderboardsLink: some View {
        Button {
            Feedback.play(.selection)
            GameCenter.showDashboard()
        } label: {
            HStack(spacing: HunchTheme.Spacing.m) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(HunchTheme.Palette.coin)
                Text(game.loc.leaderboards).font(.headline).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .padding(HunchTheme.Spacing.l)
            .hunchCard(radius: 16)
        }
        .buttonStyle(.plain)
    }

    private var achievementsLink: some View {
        NavigationLink {
            AchievementsView()
        } label: {
            HStack(spacing: HunchTheme.Spacing.m) {
                Image(systemName: "rosette")
                    .foregroundStyle(HunchTheme.Palette.warm)
                Text(game.loc.achievements).font(.headline).foregroundStyle(.primary)
                Spacer()
                Text("\(game.unlockedCount)/\(Achievements.all.count)")
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .padding(HunchTheme.Spacing.l)
            .hunchCard(radius: 16)
        }
        .buttonStyle(.plain)
    }

    private func statCard(_ title: String, value: String, system: String, color: Color) -> some View {
        VStack(spacing: HunchTheme.Spacing.xs) {
            Image(systemName: system).font(.title3).foregroundStyle(color)
            Text(value).font(HunchTheme.Fonts.bigNumber)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HunchTheme.Spacing.l)
        .hunchCard(tint: color, radius: 18)
    }
}

#Preview {
    StatsView().environment(GameViewModel())
}
