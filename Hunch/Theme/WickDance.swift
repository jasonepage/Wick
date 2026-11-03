// SPDX-License-Identifier: MPL-2.0
//
//  WickDance.swift
//  Hunch
//
//  Wick's dance as a Move in points. Since the 3.8 motion pass the phrases
//  themselves live in WickMotion.swift (the same tables as wickmotion.ts on
//  the web); this file keeps the older Move API for callers and tests.
//

import Foundation

enum WickDance {
    /// The three phrases (WickMotion.DanceStyle): groove, swagger, hype.
    typealias Style = WickMotion.DanceStyle

    /// One frame of movement, applied around Wick's feet.
    struct Move: Equatable {
        var x: Double = 0
        var y: Double = 0
        /// Degrees.
        var rotation: Double = 0
        var scaleX: Double = 1
        var scaleY: Double = 1
        /// -1...1. Secondary motion for the flame crown.
        var tip: Double = 0
        static let still = Move()
    }

    /// The old boiling shake (two sine waves at unrelated speeds). 3.8 no
    /// longer shakes him endlessly: the red entrance is the authored
    /// "hide-panic" clip and the ambient tremor is a small fraction of this
    /// (WickMotion.idleBody). Kept for the replay renderer and its tests.
    /// `size` is Wick's width in points.
    static func boilingShake(t: Double, size: Double) -> Move {
        Move(x: (sin(t * 71) * 0.6 + sin(t * 113) * 0.4) * size * 0.045,
             y: (sin(t * 89 + 1.3) * 0.6 + sin(t * 131) * 0.4) * size * 0.02,
             rotation: sin(t * 97) * 2.5)
    }

    /// Wick's dance for one reading of the race music, in points. The phrases,
    /// the riser crouch and the drop live in WickMotion.danceInto (3.8). No
    /// music (`.none`) means no dance.
    static func move(for p: RaceMusic.Pulse,
                     size: Double,
                     style: Style? = .swagger,
                     intensity: Double = 1) -> Move {
        if p == .none { return .still }
        var m = WickMotion.Motion()
        let pulse = WickMotion.Pulse(beat: p.beat, down: p.down, energy: p.energy, flash: p.flash, time: p.time)
        WickMotion.danceInto(pulse, &m, style: style, intensity: intensity)
        return Move(x: m.x * size, y: m.y * size, rotation: m.rot, scaleX: 1 + m.sx, scaleY: 1 + m.sy,
                    tip: WickMotion.clamp(m.tip, -1, 1))
    }
}
