//
//  Haptics.swift
//  Hunch
//
//  Light wrapper around UIKit feedback generators, routed by FeedbackEvent.
//  No-ops in the simulator and on devices without a Taptic Engine, and gated
//  by the "hunch.haptics" Settings toggle, which defaults on. The named methods
//  (closeness/soft/success/selection) are kept so existing call sites that only
//  want a haptic (no sound) keep working; gameplay moments that should also
//  make a sound go through `Feedback.play`.
//

import UIKit

@MainActor
enum Haptics {
    /// Default ON — a missing key means "not yet toggled", i.e. enabled.
    static var enabled: Bool { UserDefaults.standard.object(forKey: "hunch.haptics") as? Bool ?? true }

    /// Event-routed entry, used via `Feedback` for moments that also play sound.
    static func play(_ event: FeedbackEvent) {
        switch event {
        case .guessScored(let score): closeness(score)
        case .newClosest:             newClosest()
        case .solved:                 success()
        case .gaveUp:                 soft()
        case .coinSpent:              coin()
        case .selection:              selection()
        }
    }

    /// A tap whose strength scales with how warm the guess is (0...100).
    static func closeness(_ score: Double) {
        guard enabled else { return }
        let style: UIImpactFeedbackGenerator.FeedbackStyle =
            score >= 60 ? .heavy : score >= 30 ? .medium : .light
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        let intensity = max(0.3, min(1.0, 0.3 + score / 100))
        generator.impactOccurred(intensity: intensity)
    }

    /// A crisp, full-strength tick for a new warmest guess — the best moment.
    static func newClosest() {
        guard enabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
    }

    static func soft() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// A short, firm tap for spending coins.
    static func coin() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
    }

    static func selection() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
