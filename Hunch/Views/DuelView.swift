//
//  DuelView.swift
//  Hunch
//
//  The Race hub (3.3). Dare was retired in 3.3, so this screen does one job:
//  get two people racing the same word.
//
//   • Race a friend (the hero) is the Ghost Race from 3.2. You finish a round,
//     send a link, and your friend races a replay of your run. Nobody has to be
//     online at the same time, and the link plays on the web with no install.
//     That is the version of racing that works with a small player base.
//   • Race someone live (secondary) opens the server-matched live race
//     (LiveDuelView), which pairs you with a real player or a disclosed bot and
//     also handles private friend codes.
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

    private let raceColor = HunchTheme.Palette.flame     // energetic orange
    private let liveColor = HunchTheme.Palette.keeper    // Wick violet

    /// The round in memory is finished and can be sent as a ghost race. At
    /// launch the app preloads today's daily, so a finished daily counts here
    /// even before the player opens the board.
    private var finishedRun: GhostRun? {
        guard game.solved || game.revealed else { return nil }
        return game.ghostRun()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    friendCard
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

    // MARK: Race a friend (ghost)

    private var friendCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(.white.opacity(0.25)).frame(width: 64, height: 64)
                Image(systemName: "flag.checkered").font(.title).foregroundStyle(.white)
            }
            Text(game.loc.raceAFriend)
                .font(.title2.bold()).foregroundStyle(.white)
            Text(game.loc.raceFriendBlurb)
                .font(.subheadline).foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let run = finishedRun {
                Button {
                    Feedback.play(.selection)
                    // Same wording as the end-of-round button in GameView and
                    // the web share sheet (shareRace in main.ts).
                    let text = run.solved
                        ? game.loc.raceShareSolved(Ghost.formatDuration(ms: run.durationMs))
                        : game.loc.raceShareUnsolved
                    Events.track(.raceLinkCreated, n: run.mode == .daily ? run.ref : nil)
                    ShareSheet.present([text, Ghost.link(run)])
                } label: {
                    Label(game.loc.raceSendYourRun, systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundStyle(raceColor)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
            } else {
                Button {
                    Feedback.play(.selection)
                    dismiss()
                    game.playDaily()
                } label: {
                    Label(game.loc.racePlayTodayFirst, systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(raceColor)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(HunchTheme.Spacing.l)
        .background(raceColor, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: raceColor.opacity(0.4), radius: 8, y: 4)
    }

    // MARK: Race someone live

    private var liveCard: some View {
        Button {
            Haptics.selection()
            showLiveDuel = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(liveColor)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.loc.raceStrangerTitle)
                        .font(.headline).foregroundStyle(liveColor)
                    Text(game.loc.liveRaceBlurb)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(HunchTheme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hunchCard(radius: 16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DuelView().environment(GameViewModel())
}
