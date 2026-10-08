//
//  GhostChallengeView.swift
//  Hunch
//
//  The screen a race link lands on — the iOS twin of screenChallenge() in
//  wick-web. Shown before the board so the challenge is the first thing you see,
//  with an explicit way out into an ordinary round.
//
//  Then a 3-2-1 count-in, so the race clock doesn't start while you're still
//  reading the screen. The ghost replays in real time from there: it keeps moving
//  whether or not you do, which is what makes it a race rather than a puzzle with
//  a scoreboard attached.
//

import SwiftUI

struct GhostChallengeView: View {
    let run: GhostRun
    /// The language the round will be played in.
    let loc: Loc
    /// Called when the player accepts and the count-in has finished.
    let onStart: () -> Void
    let onDecline: () -> Void

    @State private var counting = false
    @State private var step = 0

    private var blurb: String {
        switch run.mode {
        case .practice: return loc.raceChallengeBlurbPractice(run.actions.count)
        case .daily:    return loc.raceChallengeBlurb(run.ref, run.actions.count)
        }
    }

    private var steps: [String] { ["3", "2", "1", loc.raceGo] }

    var body: some View {
        ZStack {
            HunchTheme.background(for: 0).ignoresSafeArea()

            VStack(spacing: HunchTheme.Spacing.l) {
                KeeperView(mood: .idle, size: 108)
                Text(loc.raceChallengeTitle)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(blurb)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    Feedback.play(.selection)
                    beginCountIn()
                } label: {
                    Text(loc.raceStart)
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(HunchTheme.Palette.hot)
                .disabled(counting)

                Button(role: .cancel) { onDecline() } label: {
                    Text(loc.raceDecline)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .disabled(counting)
            }
            .padding(HunchTheme.Spacing.xl)
            .frame(maxWidth: 480)

            if counting {
                Color.black.opacity(0.72).ignoresSafeArea()
                Text(steps[min(step, steps.count - 1)])
                    .font(.system(size: 88, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
                    .id(step)   // re-triggers the transition on each tick
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: step)
    }

    private func beginCountIn() {
        counting = true
        step = 0
        tick()
    }

    private func tick() {
        guard step < steps.count else {
            onStart()
            return
        }
        Feedback.play(.selection)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            step += 1
            tick()
        }
    }
}
