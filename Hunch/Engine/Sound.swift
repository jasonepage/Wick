//
//  Sound.swift
//  Hunch
//
//  Tiny, tasteful sound cues for the core loop. Plays short bundled .wav files
//  through AVAudioPlayer, pre-loaded and reused so there's no first-play hitch.
//  The session category is .ambient, so Wick RESPECTS the silent switch and
//  mixes with (never interrupts) the player's own music. Gated by the
//  "hunch.sound" Settings toggle, which defaults on.
//

import AVFoundation

@MainActor
enum Sound {
    /// Default ON — a missing key means "not yet toggled", i.e. enabled.
    static var enabled: Bool { UserDefaults.standard.object(forKey: "hunch.sound") as? Bool ?? true }

    private static var players: [String: AVAudioPlayer] = [:]
    private static var sessionReady = false

    private static func prepareSession() {
        guard !sessionReady else { return }
        sessionReady = true
        // .ambient obeys the mute switch and mixes with background audio.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
    }

    private static func player(for name: String) -> AVAudioPlayer? {
        if let existing = players[name] { return existing }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let made = try? AVAudioPlayer(contentsOf: url) else { return nil }
        made.prepareToPlay()
        players[name] = made
        return made
    }

    /// Number of pitched guess tones (guess_00 … guess_12), a pentatonic scale
    /// from low/dull (cold) to high/bright (hot). Warmer guesses climb the scale.
    private static let guessSteps = 13

    /// The scale note for a given closeness (0...100) — the core "getting warmer"
    /// cue: a warmer guess rings a higher, brighter note than the last.
    private static func guessNote(for closeness: Double) -> String {
        let clamped = max(0, min(100, closeness))
        let index = Int((clamped / 100 * Double(guessSteps - 1)).rounded())
        return String(format: "guess_%02d", index)
    }

    private static func playFile(_ name: String) {
        guard let p = player(for: name) else { return }
        p.currentTime = 0
        p.play()
    }

    static func play(_ event: FeedbackEvent) {
        guard enabled else { return }
        prepareSession()
        switch event {
        case .guessScored(let closeness):
            playFile(guessNote(for: closeness))
        case .newClosest(let closeness):
            // The note it lands on (high, since it's the best) plus a sparkle on top.
            playFile(guessNote(for: closeness))
            playFile("sparkle")
        case .solved:     playFile("solved")
        case .gaveUp:     playFile("gaveup")
        case .coinSpent:  playFile("coin")
        case .selection:  playFile("tap")   // soft UI click on menu / nav taps
        }
    }
}
