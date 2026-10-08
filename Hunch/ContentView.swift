//
//  ContentView.swift
//  Hunch
//

import SwiftUI

struct ContentView: View {
    @Environment(GameViewModel.self) private var game

    var body: some View {
        @Bindable var game = game
        Group {
            // Land on the Home hub; entering a mode shows the game. Round state
            // lives on the view model, so switching between them loses nothing.
            if game.onHomeScreen {
                HomeView()
            } else {
                GameView()
            }
        }
            // 1.9 — the ODR embedding-download modal, presented app-wide the first
            // time a language whose dictionary needs downloading is selected. The
            // loader sets `promptLanguage` when a real download begins and clears it
            // when the download finishes, so the sheet appears and dismisses on its own.
            .sheet(item: downloadPrompt) { language in
                EmbeddingDownloadView(language: language)
            }
            // 3.1 — a live invite tapped from a link opens the right live screen
            // straight away and auto-joins, no matter which screen we're on.
            .fullScreenCover(item: $game.pendingLiveInvite) { invite in
                switch invite.mode {
                case .race: LiveDuelView(joinCode: invite.code)
                }
            }
            // Ghost Race — a tapped race link shows the challenge, counts in, and
            // drops straight onto the board with the ghost already running.
            .fullScreenCover(item: $game.pendingGhostRace) { run in
                GhostChallengeView(
                    run: run,
                    loc: game.loc,
                    onStart: {
                        game.startGhostRace(run)
                        game.startRaceClock()
                    },
                    onDecline: { game.pendingGhostRace = nil }
                )
            }
    }

    /// Bridges the loader's `promptLanguage` to a `sheet(item:)` binding. Setting
    /// nil (swipe-to-dismiss) hides the sheet but leaves the download running.
    private var downloadPrompt: Binding<GameLanguage?> {
        Binding(
            get: { game.assetLoader.promptLanguage },
            set: { if $0 == nil { game.assetLoader.dismissPrompt() } }
        )
    }
}

#Preview {
    ContentView().environment(GameViewModel())
}
