//
//  StatsView.swift
//  Hunch
//

import SwiftUI
import UIKit

struct StatsView: View {
    @Environment(GameViewModel.self) private var game
    @Environment(\.dismiss) private var dismiss
    @State private var weekly = WeeklyStats.shared
    @State private var showBoard = false

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
                    }
                    boardLink
                    achievementsLink
                    weeklySection
                }
                .padding(HunchTheme.Spacing.l)
                .readableWidth()
            }
            .task(id: game.language) {
                await weekly.refreshIfStale(language: game.language)
            }
            .sheet(isPresented: $showBoard) { DailyBoardView() }
            .navigationTitle(game.loc.yourStats)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(game.loc.done) { dismiss() }
                }
            }
        }
    }

    // MARK: - Everyone's week (3.6)

    /// Top guesses and most asked questions across all players this week.
    /// Fetched from the server and cached (see WeeklyStats), so opening Stats
    /// does not ask the server every time.
    private var weeklySection: some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
            HStack(spacing: HunchTheme.Spacing.s) {
                Image(systemName: "person.3.fill").foregroundStyle(HunchTheme.Palette.keeper)
                Text(game.loc.weeklyHeader).font(.headline)
            }
            .padding(.top, HunchTheme.Spacing.m)
            Text(game.loc.weeklyResets)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let snap = weekly.snapshot {
                weeklyList(game.loc.weeklyTopGuesses, system: "text.cursor",
                           color: HunchTheme.Palette.flame, rows: snap.guesses)
                weeklyList(game.loc.weeklyTopQuestions, system: "questionmark.bubble.fill",
                           color: HunchTheme.Palette.keeper, rows: snap.questions)
            } else if weekly.loading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(HunchTheme.Spacing.l)
            } else if weekly.failed {
                Text(game.loc.weeklyOffline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(HunchTheme.Spacing.l)
                    .hunchCard(radius: 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weeklyList(_ title: String, system: String, color: Color,
                            rows: [WeeklySnapshot.Row]) -> some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
            HStack(spacing: HunchTheme.Spacing.s) {
                Image(systemName: system).foregroundStyle(color)
                Text(title).font(.subheadline.weight(.semibold))
            }
            if rows.isEmpty {
                Text(game.loc.weeklyEmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element) { index, row in
                    if index > 0 { Divider() }
                    HStack(alignment: .firstTextBaseline, spacing: HunchTheme.Spacing.m) {
                        Text("\(index + 1)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 20, alignment: .trailing)
                        Text(row.text)
                            .font(.body)
                            .lineLimit(2)
                        Spacer(minLength: HunchTheme.Spacing.s)
                        Text("\(row.count)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HunchTheme.Spacing.l)
        .hunchCard(tint: color, radius: 16)
    }

    private var averageText: String {
        game.solves > 0 ? String(format: "%.1f", game.averageGuesses) : "—"
    }

    private var bestGuessText: String {
        game.bestGuessCount > 0 ? "\(game.bestGuessCount)" : "—"
    }

    /// 3.6: today's race board.
    private var boardLink: some View {
        Button {
            Feedback.play(.selection)
            showBoard = true
        } label: {
            HStack(spacing: HunchTheme.Spacing.m) {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(HunchTheme.Palette.keeper)
                Text(game.loc.boardOpen).font(.headline).foregroundStyle(.primary)
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
