// SPDX-License-Identifier: MPL-2.0
//
//  WickDance.swift
//  Hunch
//
//  Pure math for two of Wick's moves: the hard shake he does when boiling, and
//  the dance he does to the race music in live races. KeeperView reads these
//  every frame. Nothing here touches the screen, so it is unit tested in
//  HunchTests/WickDanceTests.swift.
//
//  The web has the same numbers in wick-web/src/game/wick.ts (`boilingShake`
//  and `danceAt`). KEEP THEM IN LOCKSTEP: when a number changes here, change it
//  there too, so Wick dances the same on both platforms.
//

import Foundation

enum WickDance {
    /// One frame of movement, applied around Wick's feet.
    struct Move: Equatable {
        var x: Double = 0
        var y: Double = 0
        /// Degrees.
        var rotation: Double = 0
        var scaleX: Double = 1
        var scaleY: Double = 1
        static let still = Move()
    }

    /// Boiling is a hard shake: a fast jitter in two directions plus a little
    /// rotation. Two sine waves at unrelated speeds, so it never looks like a
    /// loop. Clearly stronger than hot (which only bobs fast), still readable.
    /// `size` is Wick's width in points.
    static func boilingShake(t: Double, size: Double) -> Move {
        Move(x: (sin(t * 71) * 0.6 + sin(t * 113) * 0.4) * size * 0.045,
             y: (sin(t * 89 + 1.3) * 0.6 + sin(t * 131) * 0.4) * size * 0.02,
             rotation: sin(t * 97) * 2.5)
    }

    /// Wick's dance for one reading of the race music. Locked to the beat:
    ///   a hop on each beat (squash on landing, stretch on the way up),
    ///   a step and lean to alternating sides each beat,
    ///   a bigger hop and lean on beat 1 of each bar,
    ///   and when kiai drops (flash), a big jump with a full spin.
    /// `energy` sets how hard he goes: a groove on chill, building through the
    /// riser, full out on kiai. No music (`.none`) means no dance.
    static func move(for p: RaceMusic.Pulse, size: Double) -> Move {
        if p == .none { return .still }
        let beatLength = 0.5
        let idx = Int(floor(p.time / beatLength))
        let ph = (p.time - Double(idx) * beatLength) / beatLength     // 0...1 through the beat
        let side: Double = idx % 2 == 0 ? -1 : 1                      // step side alternates
        let downbeat = idx % 4 == 0
        let amp = 0.55 + 0.75 * p.energy                               // chill 0.55, kiai 1.3

        // The hop: in the air between beats, feet down on the beat.
        let arc = sin(.pi * ph)
        var y = -arc * size * (downbeat ? 0.10 : 0.06) * amp
        // Squash on landing (the beat pulse is 1 on the beat and decays), stretch in the air.
        let squash = 0.14 * p.beat * amp
        let stretch = 0.07 * arc * amp
        var sx = 1 + squash - stretch
        var sy = 1 - squash + stretch

        // The step: slide from one side to the other over the beat, leaning that way.
        let ease = (1 - cos(.pi * min(1, ph * 1.4))) / 2
        let travel = side * (2 * ease - 1)
        let x = travel * size * 0.06 * amp
        var rotation = travel * 7 * amp * (downbeat ? 1.5 : 1)

        // The drop: one big jump with a full spin in the first second of kiai.
        if p.flash > 0 {
            let u = min(1, -log(max(p.flash, 1e-9)) / 3)              // seconds since the drop
            if u < 1 {
                let jump = sin(.pi * u)
                y -= jump * size * 0.35
                rotation += 360 * (u * u * (3 - 2 * u))
                sx *= 1 - 0.1 * jump
                sy *= 1 + 0.1 * jump
            }
        }
        return Move(x: x, y: y, rotation: rotation, scaleX: sx, scaleY: sy)
    }
}
