//
//  Feedback.swift
//  Hunch
//
//  One place that turns a game moment into feel + sound. Call sites say WHAT
//  happened (a guess landed, the word was solved); this routes to Haptics and
//  Sound, each independently gated by its own Settings toggle. Keeping them
//  together means the haptic and the sound for a moment never drift apart.
//

import Foundation

/// A moment in the game worth reacting to.
enum FeedbackEvent {
    case guessScored(closeness: Double)   // a valid guess landed (0...100 warmth)
    case newClosest(closeness: Double)    // …and it is the warmest guess so far
    case solved                            // the secret word was found
    case gaveUp                            // the player revealed the answer
    case coinSpent                         // a hint / question / purchase debit
    case selection                         // a light UI tick (question asked, minor tap)
}

@MainActor
enum Feedback {
    /// Fire the haptic and the sound for a moment. Each channel checks its own
    /// Settings toggle, so this is always safe to call.
    static func play(_ event: FeedbackEvent) {
        Haptics.play(event)
        Sound.play(event)
    }
}
