//
//  AchievementsView.swift
//  Hunch
//

import SwiftUI
import UIKit

struct AchievementsView: View {
    @Environment(GameViewModel.self) private var game

    var body: some View {
        ScrollView {
            VStack(spacing: HunchTheme.Spacing.s) {
                ForEach(Achievements.all) { a in
                    row(a, unlocked: game.isUnlocked(a.id))
                }
            }
            .padding(HunchTheme.Spacing.l)
            .readableWidth()
        }
        .navigationTitle(game.loc.achievements)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ a: Achievement, unlocked: Bool) -> some View {
        let tint = HunchTheme.Palette.warm
        return HStack(spacing: HunchTheme.Spacing.l) {
            ZStack {
                Circle()
                    .fill((unlocked ? tint : Color.gray).opacity(unlocked ? 0.16 : 0.10))
                    .frame(width: 46, height: 46)
                Image(systemName: unlocked ? a.icon : "lock.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(unlocked ? tint : Color.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Achievements.title(for: a.id, game.language))
                    .font(.headline)
                    .foregroundStyle(unlocked ? .primary : .secondary)
                Text(Achievements.detail(for: a.id, game.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(HunchTheme.Palette.solved)
            }
        }
        .padding(HunchTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hunchCard(tint: unlocked ? tint : nil, radius: 16)
        .opacity(unlocked ? 1 : 0.65)
    }
}

#Preview {
    NavigationStack { AchievementsView() }
        .environment(GameViewModel())
}
