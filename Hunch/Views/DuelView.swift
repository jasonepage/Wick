//
//  DuelView.swift
//  Hunch
//
//  The Race hub (3.3). Dare was retired in 3.3, so this screen does one job:
//  get two people racing the same word.
//
//   • Race someone live (the hero) opens the server-matched live race
//     (LiveDuelView), which pairs you with a real player or a disclosed bot and
//     also handles private friend codes. It is the fun one, so it leads.
//   • Race a friend (the Ghost Race from 3.2) was removed in 3.7. Friends race
//     live instead, with an invite code inside the live race screen.
//
//  The struct keeps its old name so HomeView and previews need no churn. The
//  legacy offline WK-/WR- duel codes are still honoured by deep links in
//  HunchApp; their unused in-app create/join UI was removed with Dare.
//

import SwiftUI
import UIKit

struct DuelView: View {
    @Environment(GameViewModel.self) private var game
    @Environment(\.dismiss) private var dismiss

    @State private var showLiveDuel = false

    private let liveColor = HunchTheme.Palette.keeper    // Wick violet

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    liveCard
                    Label(game.loc.raceLiveDisclosure, systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, HunchTheme.Spacing.s)
                }
                .padding(16)
                .readableWidth(560)
            }
            .navigationTitle(game.loc.duelRace)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(game.loc.done) { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showLiveDuel) {
                LiveDuelView()
            }
        }
    }

    // MARK: Race someone live (hero)

    private var liveCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(.white.opacity(0.25)).frame(width: 64, height: 64)
                Image(systemName: "bolt.fill").font(.title).foregroundStyle(.white)
            }
            Text(game.loc.raceStrangerTitle)
                .font(.title2.bold()).foregroundStyle(.white)
            Text(game.loc.liveRaceBlurb)
                .font(.subheadline).foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.selection()
                showLiveDuel = true
            } label: {
                Label(game.loc.raceLiveNow, systemImage: "bolt.fill")
                    .font(.headline)
                    .foregroundStyle(liveColor)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(HunchTheme.Spacing.l)
        .background(liveColor, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: liveColor.opacity(0.4), radius: 8, y: 4)
    }
}

#Preview {
    DuelView().environment(GameViewModel())
}
