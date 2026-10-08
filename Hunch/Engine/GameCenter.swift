//
//  GameCenter.swift
//  Hunch
//
//  Leaderboards and cross-device achievement sync, via GameKit.
//
//  WHY IT'S LAZY, NOT LAUNCH-TIME
//  ------------------------------
//  The textbook GameKit integration authenticates in `didFinishLaunching`, which
//  throws Apple's sign-in sheet at a first-time player before they have seen the
//  game. That is the wrong trade here: this app's whole posture is *no accounts,
//  no sign-up, plays offline* (C1/C2), and a modal identity prompt on first
//  launch contradicts it in the first three seconds.
//
//  So nothing happens until the player taps "Leaderboards" — an explicit,
//  reversible request to be ranked. `authenticateIfAsked()` runs then, and only
//  then. After that, `isAuthenticated` is true for the session and scores submit
//  silently in the background on every solve. A player who never taps it never
//  sees Game Center at all, and loses nothing: the local achievements in
//  `Achievements.swift` and the local stats remain the source of truth. GameKit
//  is a mirror, never the record.
//
//  ⚠️ REQUIRES APP STORE CONNECT SETUP. Until the capability and the IDs below
//  exist, every call here fails silently and the button says so. Specifically:
//
//  1. Xcode → target → Signing & Capabilities → + Capability → **Game Center**.
//  2. App Store Connect → your app → **Game Center**, then create:
//     • Leaderboard `wick.streak.best`   — Integer, **High to Low**, all-time.
//     • Leaderboard `wick.daily.guesses` — Integer, **Low to High**, recurring
//       daily. Fewest guesses on today's word.
//     • Leaderboard `wick.daily.time`    — Elapsed time (ms), **Low to High**,
//       recurring daily.
//     • One achievement per id in `Achievements.all` — the ids are reused
//       verbatim (`first_solve`, `streak_7`, …), so nothing needs mapping.
//
//  If an id doesn't exist server-side, GameKit returns an error, `report` eats
//  it, and play is unaffected. That is deliberate: a leaderboard misconfiguration
//  must never be able to interrupt a round.
//
//  LEAK SAFETY. Only counts and durations are ever submitted — number of
//  guesses, milliseconds, streak length. No word, in any language, ever reaches
//  a leaderboard.
//

import Foundation
import GameKit
import SwiftUI

@MainActor
enum GameCenter {

    enum LeaderboardID: String, CaseIterable {
        case bestStreak   = "wick.streak.best"
        case dailyGuesses = "wick.daily.guesses"
        case dailyTime    = "wick.daily.time"
    }

    /// True once the local player has signed in this session. Everything else in
    /// this file is a no-op while it's false, so callers never have to check.
    static var isAuthenticated: Bool { GKLocalPlayer.local.isAuthenticated }

    /// Set when authentication has been tried and refused/failed, so the UI can
    /// say "Game Center isn't available" instead of showing a button that does
    /// nothing when tapped twice.
    private(set) static var lastError: String?

    private static var authenticationStarted = false

    // MARK: - Authentication

    /// Starts authentication. Call this ONLY from an explicit player action —
    /// tapping Leaderboards — never on launch. See the file header.
    ///
    /// GameKit's handler can fire more than once over a session (sign-out,
    /// sign-in on another device), which is why the closure is assigned rather
    /// than awaited, and why `isAuthenticated` is read live from `GKLocalPlayer`
    /// rather than cached into a flag of our own.
    static func authenticateIfAsked() {
        guard !authenticationStarted else { return }
        authenticationStarted = true

        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            MainActor.assumeIsolated {
                if let error {
                    lastError = error.localizedDescription
                    return
                }
                lastError = nil
                if let viewController {
                    present(viewController)
                }
            }
        }
    }

    // MARK: - Submitting

    /// Mirrors a finished DAILY round. No-ops for practice, archive and duels —
    /// those aren't a shared contest, so ranking them would be meaningless at
    /// best and farmable at worst.
    ///
    /// - Parameters:
    ///   - guesses: guesses taken to solve.
    ///   - elapsedMs: active play time, already idle-clamped by the round clock.
    ///   - bestStreak: the player's all-time best.
    static func reportDailySolve(guesses: Int, elapsedMs: Int, bestStreak: Int) {
        guard isAuthenticated else { return }
        var scores: [(LeaderboardID, Int)] = [(.bestStreak, bestStreak)]
        if guesses > 0 { scores.append((.dailyGuesses, guesses)) }
        if elapsedMs > 0 { scores.append((.dailyTime, elapsedMs)) }

        for (board, value) in scores {
            GKLeaderboard.submitScore(value, context: 0, player: GKLocalPlayer.local,
                                      leaderboardIDs: [board.rawValue]) { _ in
                // Swallowed on purpose — see the header. A leaderboard that
                // doesn't exist yet must not be able to disturb a round.
            }
        }
    }

    /// Mirrors the local achievement set. Ids match `Achievements.all` verbatim,
    /// so this is a straight copy with no mapping table to drift.
    ///
    /// Everything reported is 100% complete: these are binary badges locally, and
    /// inventing partial percentages for GameKit would make the two disagree.
    static func report(unlocked: Set<String>) {
        guard isAuthenticated, !unlocked.isEmpty else { return }
        let achievements = unlocked.map { id -> GKAchievement in
            let a = GKAchievement(identifier: id)
            a.percentComplete = 100
            a.showsCompletionBanner = false   // the app shows its own toast
            return a
        }
        GKAchievement.report(achievements) { _ in }
    }

    // MARK: - Presenting

    /// Opens the Game Center dashboard, authenticating first if needed.
    ///
    /// When the player isn't signed in, assigning the handler above triggers
    /// Apple's sheet and this call does nothing further — which is correct: the
    /// dashboard would be empty anyway, and the player gets one prompt rather
    /// than a prompt stacked under a dashboard.
    static func showDashboard(_ state: GKGameCenterViewControllerState = .leaderboards) {
        authenticateIfAsked()
        guard isAuthenticated else { return }
        let vc = GKGameCenterViewController(state: state)
        vc.gameCenterDelegate = Delegate.shared
        present(vc)
    }

    private static func present(_ viewController: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.keyWindow?.rootViewController
        else { return }

        var top = root
        while let presented = top.presentedViewController { top = presented }
        guard !(top is GKGameCenterViewController) else { return }   // already up
        top.present(viewController, animated: true)
    }

    /// GameKit needs an NSObject delegate to dismiss its own dashboard; without
    /// one the Done button does nothing.
    private final class Delegate: NSObject, GKGameCenterControllerDelegate {
        static let shared = Delegate()
        func gameCenterViewControllerDidFinish(_ vc: GKGameCenterViewController) {
            vc.dismiss(animated: true)
        }
    }
}
