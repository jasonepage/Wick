// SPDX-License-Identifier: MPL-2.0
//
//  WickDance.swift
//  Hunch
//
//  Wick's pure motion engine: the hard boiling shake plus an authored library
//  of beat-locked dance clips, blended with anticipation, hops, landings and
//  flame-tip follow-through. KeeperView reads it every frame. Nothing here
//  touches the screen, so it is unit tested in HunchTests/WickDanceTests.swift.
//
//  The web has the same numbers in wick-web/src/game/wick.ts (`boilingShake`
//  and `danceAt`). KEEP THEM IN LOCKSTEP: when a number changes here, change it
//  there too, so Wick dances the same on both platforms.
//

import Foundation

enum WickDance {
    /// Authored motion clips shared conceptually with the web motion studio.
    enum Style: String, CaseIterable, Sendable {
        case groove
        case swagger
        case hype
    }

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

    private struct DanceKey {
        /// Fractions of Wick's width.
        var x: Double
        var y: Double
        var rotation: Double
        var scaleX: Double
        var scaleY: Double
        var tip: Double
    }

    private struct Clip {
        var keys: [DanceKey]
        var hop: Double
        var travel: Double
        var turn: Double
    }

    /// Eight-beat authored clips. Keeping choreography as data makes the
    /// timing inspectable and gives the web studio and iOS one motion model.
    private static func clip(for style: Style) -> Clip {
        switch style {
        case .groove:
            return Clip(keys: [
                .init(x: -0.05, y: 0.01, rotation: -4, scaleX: 1.03, scaleY: 0.98, tip: 0.28),
                .init(x: 0.03, y: 0, rotation: 3, scaleX: 0.99, scaleY: 1.02, tip: -0.18),
                .init(x: 0.05, y: 0.01, rotation: 5, scaleX: 1.02, scaleY: 0.99, tip: -0.30),
                .init(x: -0.02, y: 0, rotation: -2, scaleX: 0.99, scaleY: 1.01, tip: 0.12),
                .init(x: -0.05, y: 0.01, rotation: -5, scaleX: 1.03, scaleY: 0.98, tip: 0.32),
                .init(x: 0.02, y: 0, rotation: 2, scaleX: 0.99, scaleY: 1.02, tip: -0.12),
                .init(x: 0.05, y: 0.01, rotation: 4, scaleX: 1.02, scaleY: 0.99, tip: -0.26),
                .init(x: -0.03, y: 0, rotation: -3, scaleX: 1, scaleY: 1.01, tip: 0.18),
            ], hop: 0.72, travel: 0.72, turn: 0.72)
        case .swagger:
            return Clip(keys: [
                .init(x: -0.08, y: 0.015, rotation: -9, scaleX: 1.06, scaleY: 0.96, tip: 0.55),
                .init(x: 0.045, y: -0.01, rotation: 5, scaleX: 0.98, scaleY: 1.04, tip: -0.30),
                .init(x: 0.085, y: 0.01, rotation: 10, scaleX: 1.04, scaleY: 0.97, tip: -0.58),
                .init(x: -0.025, y: 0, rotation: -3, scaleX: 0.99, scaleY: 1.02, tip: 0.20),
                .init(x: -0.095, y: 0.02, rotation: -11, scaleX: 1.07, scaleY: 0.95, tip: 0.65),
                .init(x: 0.02, y: -0.01, rotation: 2, scaleX: 0.98, scaleY: 1.04, tip: -0.14),
                .init(x: 0.075, y: 0.01, rotation: 8, scaleX: 1.04, scaleY: 0.97, tip: -0.50),
                .init(x: -0.04, y: 0, rotation: -5, scaleX: 1, scaleY: 1.02, tip: 0.32),
            ], hop: 1, travel: 1, turn: 1)
        case .hype:
            return Clip(keys: [
                .init(x: -0.08, y: 0.025, rotation: -11, scaleX: 1.08, scaleY: 0.93, tip: 0.72),
                .init(x: 0.055, y: -0.02, rotation: 7, scaleX: 0.96, scaleY: 1.07, tip: -0.45),
                .init(x: 0.09, y: 0.015, rotation: 12, scaleX: 1.06, scaleY: 0.95, tip: -0.76),
                .init(x: -0.035, y: -0.01, rotation: -5, scaleX: 0.97, scaleY: 1.05, tip: 0.34),
                .init(x: -0.10, y: 0.03, rotation: -13, scaleX: 1.09, scaleY: 0.92, tip: 0.82),
                .init(x: 0.025, y: -0.02, rotation: 4, scaleX: 0.96, scaleY: 1.08, tip: -0.28),
                .init(x: 0.085, y: 0.015, rotation: 11, scaleX: 1.06, scaleY: 0.95, tip: -0.70),
                .init(x: -0.045, y: -0.01, rotation: -6, scaleX: 0.98, scaleY: 1.05, tip: 0.40),
            ], hop: 1.34, travel: 1.12, turn: 1.18)
        }
    }

    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(high, max(low, value))
    }

    private static func mix(_ a: Double, _ b: Double, _ u: Double) -> Double {
        a + (b - a) * u
    }

    private static func smoother(_ value: Double) -> Double {
        let x = clamp(value, 0, 1)
        return x * x * x * (x * (x * 6 - 15) + 10)
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

    /// Wick's dance for one reading of the race music. Eight authored beat
    /// poses blend underneath hop, landing, riser-anticipation and drop layers.
    /// `energy` sets how hard he goes: chill on the loop, building through the
    /// riser, full out on kiai. No music (`.none`) means no dance.
    static func move(for p: RaceMusic.Pulse,
                     size: Double,
                     style: Style = .swagger,
                     intensity: Double = 1) -> Move {
        if p == .none { return .still }
        let beatLength = 0.5
        let idx = Int(floor(p.time / beatLength))
        let ph = (p.time - Double(idx) * beatLength) / beatLength     // 0...1 through the beat
        let downbeat = idx % 4 == 0
        let clip = clip(for: style)
        let amp = (0.55 + 0.75 * p.energy) * clamp(intensity, 0.35, 1.65)

        let key = ((idx % clip.keys.count) + clip.keys.count) % clip.keys.count
        let next = (key + 1) % clip.keys.count
        let a = clip.keys[key]
        let b = clip.keys[next]
        let u = smoother(ph)
        let x = mix(a.x, b.x, u) * size * amp * clip.travel
        // Feet stay planted on authored keys; vertical travel comes from the
        // hop, anticipation and landing layers below.
        var y = 0.0
        var rotation = mix(a.rotation, b.rotation, u) * amp * clip.turn
        var sx = 1 + (mix(a.scaleX, b.scaleX, u) - 1) * amp
        var sy = 1 + (mix(a.scaleY, b.scaleY, u) - 1) * amp
        var tip = mix(a.tip, b.tip, u) * amp

        // The hop: in the air between beats, feet down on the beat.
        let arc = pow(sin(.pi * ph), 1.15)
        y -= arc * size * (downbeat ? 0.105 : 0.055) * amp * clip.hop
        let landing = exp(-ph * 13) * p.beat
        let squash = 0.13 * landing * amp * clip.hop
        let stretch = 0.065 * arc * amp * clip.hop
        sx *= 1 + squash - stretch
        sy *= 1 - squash + stretch
        tip += -rotation / 22 + sin(.pi * ph) * (idx % 2 == 0 ? 0.12 : -0.12)

        // Crouch through the end of the riser before the drop exists.
        if p.flash <= 0, p.energy > 0.82, p.energy < 1 {
            let crouch = smoother((p.energy - 0.82) / 0.18)
            y += size * 0.055 * crouch
            sx *= 1 + 0.10 * crouch
            sy *= 1 - 0.15 * crouch
            rotation *= 1 - 0.45 * crouch
            tip *= 1 - 0.65 * crouch
        }

        // The drop: launch, spin, land and recoil over one second.
        if p.flash > 0 {
            let u = min(1, -log(max(p.flash, 1e-9)) / 3)              // seconds since the drop
            if u < 1 {
                let flight = clamp(u / 0.78, 0, 1)
                let jump = sin(.pi * flight)
                let spin = smoother(flight)
                let settle = u > 0.78 ? exp(-(u - 0.78) * 14) * sin((u - 0.78) * 34) : 0
                y -= jump * size * 0.37
                y += settle * size * 0.035
                rotation += 360 * spin + settle * 6
                sx *= 1 - 0.10 * jump + max(0, settle) * 0.08
                sy *= 1 + 0.11 * jump - max(0, settle) * 0.10
                tip += -sin(.pi * flight) * 0.72 + settle * 0.35
            }
        }
        return Move(x: x, y: y, rotation: rotation, scaleX: sx, scaleY: sy,
                    tip: clamp(tip, -1, 1))
    }
}
