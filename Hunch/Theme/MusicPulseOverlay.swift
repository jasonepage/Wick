// SPDX-License-Identifier: MPL-2.0
//
//  MusicPulseOverlay.swift
//  Hunch
//
//  3.5: the live race screen moves with the race music. A warm glow behind
//  the race breathes on every beat, a little harder on the first beat of each
//  bar, much harder once kiai drops for the last minute, with a bright flash
//  at the drop itself. It reads `RaceMusic.shared.pulse()`, which comes off
//  the audio clock, so it stays in time with what the player hears.
//
//  Draws nothing when no race music plays, and nothing at all with Reduce
//  Motion on. Never takes touches.
//

import SwiftUI

struct MusicPulseOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Color.clear.allowsHitTesting(false)
        } else {
            TimelineView(.animation) { _ in
                let p = RaceMusic.shared.pulse()
                let glow = p.beat * (0.05 + 0.13 * p.energy) + p.down * 0.04 + p.flash * 0.35
                ZStack {
                    RadialGradient(colors: [HunchTheme.Palette.hot.opacity(glow), .clear],
                                   center: .top, startRadius: 0, endRadius: 520)
                    RadialGradient(colors: [HunchTheme.Palette.boiling.opacity(glow * p.energy * 0.8), .clear],
                                   center: .bottom, startRadius: 0, endRadius: 420)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// Makes a view bounce slightly on the race music's beat (more on kiai).
struct BeatBounce: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            TimelineView(.animation) { _ in
                let p = RaceMusic.shared.pulse()
                content.scaleEffect(1 + p.beat * (0.025 + 0.04 * p.energy), anchor: .bottom)
            }
        }
    }
}

extension View {
    func beatBounce() -> some View { modifier(BeatBounce()) }
}
