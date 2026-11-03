// SPDX-License-Identifier: MPL-2.0
//
//  WickMotion.swift
//  Hunch
//
//  Wick's motion director (3.8). A line for line port of
//  wick-web/src/game/wickmotion.ts: the same five channels, the same tables,
//  the same arithmetic in the same order. KEEP THEM IN LOCKSTEP. The tables
//  in `Tables` are generated from the TypeScript; HunchTests/WickMotionTests
//  checks golden numbers printed by wick-web/tests/wickmotion.test.ts.
//
//  Every frame is the sum of five channels, highest priority first:
//
//    5. solve        the solved sequence (KeeperSolve) owns everything
//    4. transition   the face and colour change: blink, compress, release
//    3. reaction     a short authored clip after a guess or a question
//    2. dance        the beat-locked phrase, only while race music plays
//    1. idle life    breath, tip drift, blinks and small attention events
//
//  A higher channel fades the lower ones out (120 ms) and back in (150 ms),
//  and a new reaction starts from the pose on screen, never from rest.
//
//  Units: x and y are fractions of Wick's width (y down), rot is degrees,
//  sx and sy are scale DELTAS (0 is rest), tip is the tip's lean from -1 to 1,
//  tu raises the tip (viewBox units, negative is taller). Face accents are in
//  the face art's units: gx, gy move the pupils, bl, br a brow (negative is
//  up), ll, lr close a lid (0 to 1) or, below 0, lift it.
//
//  Pure value code, no UI: everything is nonisolated so it can be unit tested.
//

import Foundation

nonisolated enum WickMotion {

    nonisolated enum Mood: String, CaseIterable, Sendable {
        case idle, freezing, cold, warm, hot, boiling, celebrating, grey
    }

    nonisolated enum Channel: String, CaseIterable, Sendable {
        case x, y, rot, sx, sy, tip, tu, gx, gy, bl, br, ll, lr
    }

    nonisolated enum DanceStyle: String, CaseIterable, Sendable {
        case groove, swagger, hype
    }

    nonisolated enum Clip: String, CaseIterable, Sendable {
        case deflate, coldShoulder = "cold-shoulder", inspect, interest, caught, hidePanic = "hide-panic"
        case judge, perk, turnAway = "turn-away", faceLead = "face-lead"
    }

    nonisolated enum AttentionKind: String, CaseIterable, Sendable {
        case glance, brow, blink, listen
    }

    /// What the director needs to know about the music (RaceMusic.Pulse).
    nonisolated struct Pulse: Equatable, Sendable {
        var beat: Double
        var down: Double
        var energy: Double
        var flash: Double
        var time: Double
    }

    /// One frame of motion. `glow` is a brightness/opacity factor.
    nonisolated struct Motion: Equatable, Sendable {
        var x = 0.0, y = 0.0, rot = 0.0, sx = 0.0, sy = 0.0, tip = 0.0, tu = 0.0
        var gx = 0.0, gy = 0.0, bl = 0.0, br = 0.0, ll = 0.0, lr = 0.0
        var glow = 1.0

        subscript(c: Channel) -> Double {
            get {
                switch c {
                case .x: return x
                case .y: return y
                case .rot: return rot
                case .sx: return sx
                case .sy: return sy
                case .tip: return tip
                case .tu: return tu
                case .gx: return gx
                case .gy: return gy
                case .bl: return bl
                case .br: return br
                case .ll: return ll
                case .lr: return lr
                }
            }
            set {
                switch c {
                case .x: x = newValue
                case .y: y = newValue
                case .rot: rot = newValue
                case .sx: sx = newValue
                case .sy: sy = newValue
                case .tip: tip = newValue
                case .tu: tu = newValue
                case .gx: gx = newValue
                case .gy: gy = newValue
                case .bl: bl = newValue
                case .br: br = newValue
                case .ll: ll = newValue
                case .lr: lr = newValue
                }
            }
        }

        mutating func add(_ m: Motion, _ w: Double) {
            if w == 0 { return }
            for c in Channel.allCases { self[c] += m[c] * w }
        }
    }

    nonisolated struct ClipDef: Sendable {
        let dur: Double
        /// When the new mood's base pose ramps in, in clip seconds.
        let baseIn: (Double, Double)
        let tracks: [Channel: [Double]]
    }

    /// One beat of a phrase: where he is ON the beat, and how he gets there.
    nonisolated struct DanceKey: Sendable {
        let x: Double, y: Double, rot: Double, sx: Double, sy: Double, tip: Double
        let gx: Double, bl: Double, br: Double
        /// Peak hop while travelling INTO this key.
        let hop: Double
        /// Squash on arriving at this key.
        let land: Double
        /// Fraction of the beat he holds the previous key before moving.
        let hold: Double

        func value(_ c: Channel) -> Double {
            switch c {
            case .x: return x
            case .y: return y
            case .rot: return rot
            case .sx: return sx
            case .sy: return sy
            case .tip: return tip
            case .gx: return gx
            case .bl: return bl
            case .br: return br
            default: return 0
            }
        }
    }

    // MARK: - Tables (generated)

    // GENERATED from wick-web/src/game/wickmotion.ts by the 3.8 motion pass. Edit both together.

    static let base: [Mood: [Channel: Double]] = [
        .idle: [:],
        .celebrating: [:],
        .grey: [.y: 0.008, .sx: 0.02, .sy: -0.04, .tip: -0.32, .tu: 1.5, .gy: 8.0, .ll: 0.14, .lr: 0.14],
        .freezing: [.sx: -0.012, .sy: -0.008, .ll: 0.12, .lr: 0.12],
        .cold: [.rot: 0.6, .tip: 0.08, .bl: 3.0],
        .warm: [.sx: -0.004, .sy: 0.01, .tu: -1.0, .bl: -3.0, .br: -3.0],
        .hot: [.x: -0.012, .rot: -1.0, .sx: 0.004, .sy: -0.006, .bl: 2.0, .br: 2.0],
        .boiling: [.sy: -0.004, .gx: 6.0],
    ]

    static let breath: [Mood: (period: Double, amp: Double)] = [
        .idle: (3.2, 0.013),
        .freezing: (3.6, 0.01),
        .cold: (3.4, 0.011),
        .warm: (3.0, 0.015),
        .hot: (2.9, 0.016),
        .boiling: (2.8, 0.018),
        .celebrating: (3.0, 0.015),
        .grey: (3.6, 0.01),
    ]

    static let clips: [Clip: ClipDef] = [
        .deflate: ClipDef(dur: 0.62, baseIn: (0.04, 0.4), tracks: [
            .sx: [0.0, 0.0, 0.3, 0.003, 0.5, 0.0],
            .sy: [0.0, 0.0, 0.3, -0.006, 0.5, 0.0],
            .tip: [0.0, 0.0, 0.12, 0.06, 0.62, 0.0],
            .gy: [0.0, 0.0, 0.04, 7.0, 0.2, 4.0, 0.4, 0.0],
        ]),
        .coldShoulder: ClipDef(dur: 0.52, baseIn: (0.1, 0.4), tracks: [
            .x: [0.0, 0.0, 0.14, 0.0, 0.19, -0.012, 0.25, 0.009, 0.31, 0.0],
            .rot: [0.0, 0.0, 0.14, 0.0, 0.19, -0.6, 0.25, 0.45, 0.31, 0.0],
            .sx: [0.0, 0.0, 0.05, -0.004, 0.12, -0.03, 0.3, -0.02, 0.45, 0.0],
            .sy: [0.0, 0.0, 0.05, 0.008, 0.12, -0.02, 0.3, -0.012, 0.45, 0.0],
            .tip: [0.0, 0.0, 0.3, 0.0, 0.36, 0.28, 0.44, -0.06, 0.52, 0.0],
            .ll: [0.0, 0.0, 0.06, 0.12, 0.4, 0.04, 0.52, 0.0],
            .lr: [0.0, 0.0, 0.06, 0.12, 0.4, 0.04, 0.52, 0.0],
        ]),
        .inspect: ClipDef(dur: 0.68, baseIn: (0.47, 0.68), tracks: [
            .x: [0.0, 0.0, 0.04, 0.0, 0.1, -0.004, 0.23, 0.02, 0.47, 0.018, 0.6, -0.002, 0.68, 0.0],
            .rot: [0.0, 0.0, 0.04, 0.0, 0.1, -0.6, 0.23, 2.7, 0.47, 2.5, 0.6, -0.25, 0.68, 0.0],
            .sx: [0.0, 0.0, 0.04, 0.0, 0.1, -0.004, 0.23, 0.025, 0.47, 0.022, 0.62, 0.0],
            .sy: [0.0, 0.0, 0.04, 0.0, 0.1, -0.01, 0.23, 0.015, 0.47, 0.012, 0.62, 0.0],
            .tip: [0.0, 0.0, 0.12, 0.0, 0.3, -0.32, 0.55, -0.18, 0.68, 0.0],
            .gx: [0.0, 0.0, 0.13, 8.0, 0.47, 8.0, 0.62, 0.0],
            .gy: [0.0, 0.0, 0.13, 10.0, 0.47, 10.0, 0.62, 0.0],
            .bl: [0.0, 0.0, 0.14, 10.0, 0.47, 10.0, 0.66, 0.0],
            .br: [0.0, 0.0, 0.14, -5.0, 0.47, -5.0, 0.66, 0.0],
        ]),
        .interest: ClipDef(dur: 0.56, baseIn: (0.3, 0.56), tracks: [
            .y: [0.0, 0.0, 0.04, 0.0, 0.1, 0.004, 0.23, -0.025, 0.38, 0.003, 0.56, 0.0],
            .sx: [0.0, 0.0, 0.04, 0.0, 0.1, 0.008, 0.23, -0.02, 0.38, 0.003, 0.56, 0.0],
            .sy: [0.0, 0.0, 0.04, 0.0, 0.1, -0.012, 0.23, 0.02, 0.38, -0.003, 0.56, 0.0],
            .tu: [0.0, 0.0, 0.08, -3.5, 0.24, -2.5, 0.56, 0.0],
            .gx: [0.0, 0.0, 0.05, -9.0, 0.4, -9.0, 0.56, 0.0],
            .bl: [0.0, 0.0, 0.05, -6.0, 0.4, -5.0, 0.56, 0.0],
            .br: [0.0, 0.0, 0.05, -6.0, 0.4, -5.0, 0.56, 0.0],
        ]),
        .caught: ClipDef(dur: 0.65, baseIn: (0.4, 0.65), tracks: [
            .x: [0.0, 0.0, 0.06, 0.0, 0.1, 0.003, 0.22, -0.028, 0.4, -0.024, 0.55, 0.002, 0.65, 0.0],
            .rot: [0.0, 0.0, 0.06, 0.0, 0.1, 0.35, 0.22, -2.1, 0.4, -1.8, 0.55, 0.12, 0.65, 0.0],
            .sx: [0.0, 0.0, 0.06, 0.0, 0.1, -0.003, 0.22, 0.01, 0.4, 0.008, 0.55, 0.0],
            .sy: [0.0, 0.0, 0.06, 0.0, 0.1, 0.006, 0.22, -0.018, 0.4, -0.012, 0.55, 0.0],
            .tip: [0.0, 0.0, 0.14, 0.0, 0.3, 0.35, 0.5, -0.08, 0.65, 0.0],
            .bl: [0.0, 0.0, 0.04, -8.0, 0.22, -6.0, 0.45, 2.0, 0.65, 0.0],
            .br: [0.0, 0.0, 0.04, -8.0, 0.22, -6.0, 0.45, 2.0, 0.65, 0.0],
            .ll: [0.0, 0.0, 0.04, -0.35, 0.2, -0.35, 0.45, 0.0],
            .lr: [0.0, 0.0, 0.04, -0.35, 0.2, -0.35, 0.45, 0.0],
        ]),
        .hidePanic: ClipDef(dur: 0.76, baseIn: (0.3, 0.62), tracks: [
            .x: [0.0, 0.0, 0.09, 0.0, 0.107, 0.022, 0.123, -0.015, 0.14, 0.007, 0.16, 0.0],
            .rot: [0.0, 0.0, 0.09, 0.0, 0.107, 1.6, 0.123, -1.1, 0.14, 0.5, 0.16, 0.0],
            .sx: [0.0, 0.0, 0.09, 0.0, 0.16, 0.01, 0.3, -0.002, 0.45, 0.0],
            .sy: [0.0, 0.0, 0.09, 0.0, 0.16, -0.015, 0.3, 0.004, 0.45, 0.0],
            .tip: [0.0, 0.0, 0.1, 0.0, 0.17, -0.6, 0.32, 0.24, 0.48, -0.05, 0.62, 0.0],
            .tu: [0.0, 0.0, 0.1, 0.0, 0.17, -2.0, 0.4, 0.0],
            .gx: [0.0, 0.0, 0.16, 0.0, 0.32, 8.0, 0.62, 0.0],
            .bl: [0.0, 0.0, 0.03, -6.0, 0.3, -2.0, 0.62, 0.0],
            .br: [0.0, 0.0, 0.03, -8.0, 0.3, -3.0, 0.62, 0.0],
        ]),
        .judge: ClipDef(dur: 0.9, baseIn: (0.0, 0.3), tracks: [
            .sy: [0.0, 0.0, 0.3, 0.0, 0.42, 0.006, 0.9, 0.0],
            .br: [0.0, 0.0, 0.3, 0.0, 0.42, -12.0, 0.72, -12.0, 0.9, 0.0],
            .ll: [0.0, 0.0, 0.09, 1.0, 0.13, 1.0, 0.21, 0.0],
            .lr: [0.0, 0.0, 0.03, 0.0, 0.12, 1.0, 0.16, 1.0, 0.24, 0.0],
        ]),
        .perk: ClipDef(dur: 0.6, baseIn: (0.3, 0.6), tracks: [
            .sx: [0.0, 0.0, 0.06, -0.005, 0.16, 0.022, 0.45, 0.018, 0.6, 0.0],
            .sy: [0.0, 0.0, 0.06, -0.008, 0.16, 0.018, 0.45, 0.014, 0.6, 0.0],
            .tip: [0.0, 0.0, 0.09, 0.0, 0.14, 0.18, 0.24, -0.06, 0.34, 0.0],
            .tu: [0.0, 0.0, 0.04, 0.0, 0.09, -4.5, 0.28, -3.0, 0.6, 0.0],
            .gy: [0.0, 0.0, 0.04, -3.0, 0.45, -3.0, 0.6, 0.0],
            .bl: [0.0, 0.0, 0.04, -6.0, 0.45, -5.0, 0.6, 0.0],
            .br: [0.0, 0.0, 0.04, -6.0, 0.45, -5.0, 0.6, 0.0],
        ]),
        .turnAway: ClipDef(dur: 0.8, baseIn: (0.6, 0.8), tracks: [
            .x: [0.0, 0.0, 0.08, 0.0, 0.13, 0.002, 0.28, -0.012, 0.6, -0.01, 0.8, 0.0],
            .rot: [0.0, 0.0, 0.08, 0.0, 0.13, 0.3, 0.28, -2.6, 0.6, -2.4, 0.74, 0.2, 0.8, 0.0],
            .tip: [0.0, 0.0, 0.18, 0.0, 0.36, 0.26, 0.6, 0.1, 0.8, 0.0],
            .gx: [0.0, 0.0, 0.08, -12.0, 0.62, -12.0, 0.8, 0.0],
            .bl: [0.0, 0.0, 0.08, 3.0, 0.6, 3.0, 0.8, 0.0],
        ]),
        .faceLead: ClipDef(dur: 0.5, baseIn: (0.0, 0.3), tracks: [
            .sy: [0.0, 0.0, 0.12, 0.0, 0.2, 0.01, 0.34, 0.0],
            .gy: [0.0, 0.0, 0.06, -4.0, 0.35, -4.0, 0.5, 0.0],
            .bl: [0.0, 0.0, 0.06, -9.0, 0.3, -7.0, 0.5, 0.0],
            .br: [0.0, 0.0, 0.06, -6.0, 0.3, -5.0, 0.5, 0.0],
        ]),
    ]

    static let transition: [Channel: [Double]] = [
        .sx: [0.0, 0.0, 0.07, -0.008, 0.2, 0.025, 0.24, 0.025, 0.31, -0.003, 0.36, 0.0],
        .sy: [0.0, 0.0, 0.07, 0.015, 0.2, -0.04, 0.24, -0.04, 0.31, 0.005, 0.36, 0.0],
        .tip: [0.0, 0.0, 0.1, 0.0, 0.22, -0.16, 0.34, 0.12, 0.44, 0.0],
        .tu: [0.0, 0.0, 0.1, 0.0, 0.22, 1.2, 0.34, -0.8, 0.44, 0.0],
    ]

    static let drop: [Channel: [Double]] = [
        .y: [0.0, 0.02, 0.06, 0.02, 0.3, -0.22, 0.5, 0.0, 0.6, 0.006, 0.75, 0.0],
        .sx: [0.0, 0.06, 0.06, 0.06, 0.18, -0.05, 0.4, -0.02, 0.5, 0.065, 0.6, -0.008, 0.75, 0.0],
        .sy: [0.0, -0.1, 0.06, -0.1, 0.18, 0.08, 0.4, 0.03, 0.5, -0.11, 0.6, 0.012, 0.75, 0.0],
        .tip: [0.0, 0.0, 0.2, -0.55, 0.45, 0.3, 0.6, -0.12, 0.8, 0.0],
    ]

    static let dance: [DanceStyle: [DanceKey]] = [
        .groove: [
            DanceKey(x: -0.035, y: 0.0, rot: -4.0, sx: 0.008, sy: -0.01, tip: 0.1, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.0, land: 0.02, hold: 0.25),
            DanceKey(x: 0.0, y: 0.0, rot: 0.0, sx: -0.005, sy: 0.01, tip: 0.35, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.0, land: 0.0, hold: 0.2),
            DanceKey(x: 0.028, y: 0.0, rot: 3.2, sx: 0.0, sy: 0.0, tip: -0.1, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.0, land: 0.015, hold: 0.25),
            DanceKey(x: 0.0, y: 0.0, rot: 0.0, sx: 0.0, sy: 0.0, tip: 0.0, gx: 0.0, bl: 0.0, br: -10.0, hop: 0.0, land: 0.0, hold: 0.35),
            DanceKey(x: -0.045, y: -0.02, rot: -4.4, sx: 0.0, sy: 0.0, tip: 0.3, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.012, land: 0.0, hold: 0.2),
            DanceKey(x: 0.0, y: 0.0, rot: 0.0, sx: 0.018, sy: -0.03, tip: 0.0, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.0, land: 0.02, hold: 0.25),
            DanceKey(x: 0.035, y: 0.0, rot: 4.0, sx: 0.0, sy: 0.0, tip: -0.25, gx: -10.0, bl: 0.0, br: 0.0, hop: 0.0, land: 0.0, hold: 0.25),
            DanceKey(x: 0.0, y: 0.0, rot: 0.0, sx: 0.0, sy: 0.0, tip: 0.0, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.0, land: 0.02, hold: 0.35),
        ],
        .swagger: [
            DanceKey(x: -0.07, y: 0.0, rot: -8.0, sx: 0.015, sy: -0.025, tip: 0.0, gx: 12.0, bl: 0.0, br: 0.0, hop: 0.0, land: 0.04, hold: 0.2),
            DanceKey(x: 0.0, y: 0.0, rot: 0.0, sx: -0.02, sy: 0.035, tip: -0.45, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.03, land: 0.0, hold: 0.15),
            DanceKey(x: 0.07, y: 0.0, rot: 8.0, sx: 0.0, sy: 0.0, tip: 0.0, gx: -6.0, bl: 0.0, br: -6.0, hop: 0.0, land: 0.04, hold: 0.2),
            DanceKey(x: 0.005, y: 0.0, rot: 0.5, sx: 0.0, sy: 0.0, tip: 0.0, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.0, land: 0.0, hold: 0.45),
            DanceKey(x: -0.05, y: 0.0, rot: -6.0, sx: 0.035, sy: -0.06, tip: 0.0, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.0, land: 0.0, hold: 0.2),
            DanceKey(x: 0.02, y: 0.0, rot: 3.0, sx: -0.022, sy: 0.04, tip: -0.4, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.05, land: 0.0, hold: 0.05),
            DanceKey(x: 0.075, y: 0.0, rot: 9.0, sx: 0.0, sy: 0.0, tip: 0.0, gx: 4.0, bl: 0.0, br: -16.0, hop: 0.0, land: 0.035, hold: 0.2),
            DanceKey(x: 0.0, y: 0.0, rot: 0.0, sx: 0.0, sy: -0.01, tip: 0.0, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.0, land: 0.05, hold: 0.3),
        ],
        .hype: [
            DanceKey(x: -0.09, y: 0.0, rot: -9.0, sx: 0.018, sy: -0.03, tip: 0.0, gx: 12.0, bl: 0.0, br: 0.0, hop: 0.0, land: 0.05, hold: 0.15),
            DanceKey(x: 0.0, y: 0.0, rot: 0.0, sx: -0.024, sy: 0.04, tip: -0.5, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.05, land: 0.0, hold: 0.1),
            DanceKey(x: 0.09, y: 0.0, rot: 9.0, sx: 0.0, sy: 0.0, tip: 0.0, gx: 0.0, bl: 0.0, br: -8.0, hop: 0.0, land: 0.05, hold: 0.15),
            DanceKey(x: 0.0, y: 0.0, rot: 0.0, sx: 0.0, sy: 0.0, tip: 0.0, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.0, land: 0.0, hold: 0.4),
            DanceKey(x: 0.0, y: 0.02, rot: 0.0, sx: 0.06, sy: -0.1, tip: 0.0, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.0, land: 0.0, hold: 0.15),
            DanceKey(x: 0.03, y: -0.22, rot: 4.0, sx: -0.05, sy: 0.08, tip: -0.6, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.0, land: 0.0, hold: 0.0),
            DanceKey(x: 0.06, y: 0.0, rot: 2.0, sx: 0.0, sy: 0.0, tip: 0.0, gx: 0.0, bl: 0.0, br: 0.0, hop: 0.06, land: 0.11, hold: 0.0),
            DanceKey(x: 0.02, y: 0.0, rot: 1.0, sx: 0.0, sy: 0.0, tip: 0.0, gx: 0.0, bl: 0.0, br: -10.0, hop: 0.0, land: 0.0, hold: 0.6),
        ],
    ]


    // MARK: - Constants (same as wickmotion.ts)

    static let baseWindow: (Double, Double) = (0.15, 0.4)
    static let tipLag = 0.08
    static let tipExtra = 0.1
    static let attnGap: (Double, Double) = (3.5, 7)
    static let attnQuietAfterGuess = 0.8
    static let typingQuiet = 1.6
    static let transitionDur = 0.44
    static let beat = 0.5
    static let danceTipLag = 0.08
    static let dropDur = 0.8
    static let crouch = (y: 0.02, sx: 0.06, sy: -0.1)
    static let fadeIn = 0.12
    static let fadeOut = 0.15
    static let carryDur = 0.15

    static let moodClip: [Mood: Clip] = [
        .grey: .deflate, .freezing: .coldShoulder, .cold: .inspect, .warm: .interest,
        .hot: .caught, .boiling: .hidePanic,
    ]

    // MARK: - Small math

    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { max(lo, min(hi, v)) }

    /// Quintic smootherstep: zero speed and acceleration at both ends.
    static func smoother(_ u: Double) -> Double {
        let x = clamp(u, 0, 1)
        return x * x * x * (x * (x * 6 - 15) + 10)
    }

    /// A repeatable number in [0, 1) for (seed, n). Same bits as hash01 in wickmotion.ts.
    static func hash01(_ seed: UInt32, _ n: Int) -> Double {
        var h: UInt32 = seed ^ (UInt32(truncatingIfNeeded: n + 1) &* 0x9E37_79B1)
        h = (h ^ (h >> 16)) &* 0x85EB_CA6B
        h = (h ^ (h >> 13)) &* 0xC2B2_AE35
        h = h ^ (h >> 16)
        return Double(h) / 4_294_967_296.0
    }

    /// A keyframe track [t0, v0, t1, v1, ...] at `e` seconds (see wickmotion.ts `track`).
    static func track(_ keys: [Double], _ e: Double) -> Double {
        let n = keys.count
        if n < 2 { return 0 }
        if e <= keys[0] { return keys[1] }
        var i = 2
        while i < n {
            let t1 = keys[i]
            if e <= t1 {
                let t0 = keys[i - 2], v0 = keys[i - 1], v1 = keys[i + 1]
                let u: Double = t1 > t0 ? (e - t0) / (t1 - t0) : 1
                return v0 + (v1 - v0) * smoother(u)
            }
            i += 2
        }
        return keys[n - 1]
    }

    static func addTracks(_ out: inout Motion, _ tracks: [Channel: [Double]], _ e: Double, _ w: Double) {
        for c in Channel.allCases {
            if let k = tracks[c] { out[c] += track(k, e) * w }
        }
    }

    static func baseMotion(_ mood: Mood) -> Motion {
        var m = Motion()
        for (c, v) in base[mood] ?? [:] { m[c] = v }
        return m
    }

    // MARK: - Idle life

    /// Breath, tip drift and (boiling only) a small ambient tremor, added to `out`.
    static func idleBody(_ lt: Double, _ seed: UInt32, _ mood: Mood, _ out: inout Motion, _ w: Double = 1) {
        if w == 0 { return }
        let b0: (period: Double, amp: Double) = breath[mood] ?? (period: 3.2, amp: 0.013)
        let period = b0.period, amp = b0.amp
        let b = sin(2 * Double.pi * lt / period + 2 * Double.pi * hash01(seed, 1))
        out.sy += amp * b * w
        out.sx += -0.55 * amp * b * w
        out.y += -0.5 * amp * b * w
        let q = 3.4 + 1.8 * hash01(seed, 2)
        let drift1 = 0.62 * sin(2 * Double.pi * lt / q + 2 * Double.pi * hash01(seed, 3))
        let drift2 = 0.16 * sin(2 * Double.pi * lt / (q * 0.61) + 2 * Double.pi * hash01(seed, 4))
        out.tip += (drift1 + drift2) * w
        if mood == .boiling {
            out.x += 0.006 * (sin(lt * 71) * 0.6 + sin(lt * 113) * 0.4) * w
            out.rot += 0.35 * sin(lt * 97) * w
        }
    }

    /// Reduced Motion: no movement, only a soft brightness breath.
    static func idleGlow(_ lt: Double) -> Double {
        0.86 + 0.14 * (sin(lt * 2 * Double.pi / 2.4) + 1) / 2
    }

    nonisolated struct AttnCursor { var n = -1; var start = 0.0 }
    nonisolated struct AttnEvent { var kind: AttentionKind = .glance; var n = 0; var start = 0.0; var dur = 0.0; var side = 0.0 }

    /// The attention event running at local time `lt`, if any.
    static func attentionAt(_ lt: Double, _ seed: UInt32, _ cur: inout AttnCursor) -> AttnEvent? {
        if cur.n < 0 || lt < cur.start { cur.n = 0; cur.start = 2 + 1.5 * hash01(seed, 100) }
        while true {
            let next = cur.start + attnGap.0 + (attnGap.1 - attnGap.0) * hash01(seed, 300 + cur.n)
            if next > lt { break }
            cur.n += 1
            cur.start = next
        }
        if lt < cur.start { return nil }
        let n = cur.n
        let kinds = AttentionKind.allCases
        let kind = kinds[min(3, Int(floor(hash01(seed, 200 + n) * 4)))]
        let r = hash01(seed, 500 + n)
        let dur: Double = kind == .glance ? 0.45 + 0.25 * r : (kind == .blink ? 0.17 + 0.06 * r : 0.9)
        if lt - cur.start >= dur { return nil }
        return AttnEvent(kind: kind, n: n, start: cur.start, dur: dur, side: hash01(seed, 400 + n))
    }

    private static func env(_ e: Double, _ dur: Double, _ a: Double, _ b: Double) -> Double {
        smoother(e / a) * smoother((dur - e) / b)
    }

    /// An asymmetric slow blink lasting `d` seconds.
    static func blinkShape(_ e: Double, _ d: Double) -> Double {
        if e < 0 { return 0 }
        if e < 0.07 { return e / 0.07 }
        if e < d - 0.1 { return 1 }
        if e < d { return (d - e) / 0.1 }
        return 0
    }

    static func attentionInto(_ ev: AttnEvent, _ lt: Double, _ out: inout Motion, _ w: Double) {
        let e = lt - ev.start
        switch ev.kind {
        case .glance:
            let k = env(e, ev.dur, 0.15, 0.15) * w
            out.gy += 13 * k
            out.gx += 3 * k
        case .brow:
            let k = env(e, ev.dur, 0.2, 0.35) * w
            if ev.side < 0.5 { out.bl -= 16 * k } else { out.br -= 16 * k }
        case .blink:
            out.ll += blinkShape(e, ev.dur) * w
            out.lr += blinkShape(e - 0.03, ev.dur - 0.03) * w
        case .listen:
            out.tip += 0.4 * env(e, ev.dur, 0.25, 0.35) * w
        }
    }

    // MARK: - Reaction clips

    /// The physical clip for a cue: a personality beat (WickReactionKind raw
    /// values) wins over the temperature entrance; "question" is Ask Wick.
    static func clipForCue(_ mood: Mood, _ kind: String?) -> (clip: Clip, amp: Double)? {
        switch kind {
        case "repeat": return (.judge, 1)
        case "leap": return (.perk, 1)
        case "near": return (.hidePanic, 0.7)
        case "regress": return (.turnAway, 1)
        case "stall": return (.deflate, 1)
        case "question": return (.faceLead, 1)
        default:
            if let c = moodClip[mood] { return (c, 1) }
            return nil
        }
    }

    /// Reduced Motion keeps the face, pupils, brows and tip, and at most a 2% scale change.
    static func reduceMotionClamp(_ m: inout Motion) {
        m.x = 0; m.y = 0; m.rot = 0
        m.sx = clamp(m.sx, -0.02, 0.02)
        m.sy = clamp(m.sy, -0.02, 0.02)
    }

    static func clipInto(_ name: Clip, _ e: Double, _ amp: Double, _ out: inout Motion, _ w: Double = 1) {
        guard let c = clips[name] else { return }
        addTracks(&out, c.tracks, e, amp * w)
    }

    static func clipDur(_ name: Clip) -> Double { clips[name]?.dur ?? 0 }

    // MARK: - Face and colour transition

    /// The colour travels up the flame: (top, middle, bottom), 0...1, done by 240 ms.
    static func colorWipe(_ e: Double, rm: Bool) -> (top: Double, mid: Double, bottom: Double) {
        if rm { let u = smoother(e / 0.3); return (u, u, u) }
        return (smoother((e - 0.13) / 0.11), smoother((e - 0.1) / 0.1), smoother((e - 0.07) / 0.1))
    }

    // MARK: - Dance

    private static func keyOf(_ s: DanceStyle, _ i: Int) -> DanceKey {
        let keys = dance[s] ?? []
        return keys[((i % 8) + 8) % 8]
    }

    private static func phraseRot(_ s: DanceStyle, _ beats: Double) -> Double {
        let k = Int(floor(beats)), ph = beats - floor(beats)
        let a = keyOf(s, k), b = keyOf(s, k + 1), p = keyOf(s, k - 1)
        let u = smoother((ph - b.hold) / (1 - b.hold))
        var rot = a.rot + (b.rot - a.rot) * u
        if ph < 0.35 { rot += (a.rot - p.rot) * 0.12 * sin(Double.pi * ph / 0.35) }
        return rot
    }

    private static let phraseChannels: [Channel] = [.x, .y, .rot, .sx, .sy, .tip, .gx, .bl, .br]

    /// One phrase at `beats` into the music, added to `out` with weight `w`.
    static func phraseInto(_ s: DanceStyle, _ beats: Double, _ out: inout Motion, _ w: Double) {
        if w == 0 { return }
        let k = Int(floor(beats)), ph = beats - floor(beats)
        let a = keyOf(s, k), b = keyOf(s, k + 1), p = keyOf(s, k - 1)
        let u = smoother((ph - b.hold) / (1 - b.hold))
        for c in phraseChannels { out[c] += (a.value(c) + (b.value(c) - a.value(c)) * u) * w }
        out.y -= b.hop * sin(Double.pi * u) * w
        if ph < 0.3 {
            let s2 = a.land * sin(Double.pi * ph / 0.3) * w
            out.sy -= s2
            out.sx += 0.6 * s2
        }
        if ph < 0.35 {
            let r = 0.12 * sin(Double.pi * ph / 0.35) * w
            out.x += (a.x - p.x) * r
            out.rot += (a.rot - p.rot) * r
        }
        out.tip += -clamp(phraseRot(s, beats - danceTipLag / beat) / 18, -0.6, 0.6) * w
    }

    /// Vocabulary weights when no style is fixed: groove to 0.45, swagger to 0.82, then hype.
    static func vocabulary(_ energy: Double) -> (groove: Double, swagger: Double, hype: Double) {
        let toSwagger = smoother((energy - 0.4) / 0.1)
        let toHype = smoother((energy - 0.9) / 0.1)
        return ((1 - toSwagger) * (1 - toHype), toSwagger * (1 - toHype), toHype)
    }

    /// The dance for one reading of the music, as fractions of size (see danceInto in wickmotion.ts).
    static func danceInto(_ p: Pulse, _ out: inout Motion, style: DanceStyle? = nil, intensity: Double = 1) {
        let beats = p.time / beat
        let amp = (0.85 + 0.15 * p.energy) * clamp(intensity, 0.35, 1.65)
        var wG: Double, wS: Double, wH: Double
        if let style {
            let h: Double = style == .hype ? 0 : smoother((p.energy - 0.9) / 0.1)
            wG = style == .groove ? 1 - h : 0
            wS = style == .swagger ? 1 - h : 0
            wH = style == .hype ? 1 : h
        } else {
            let v = vocabulary(p.energy)
            wG = v.groove; wS = v.swagger; wH = v.hype
        }
        let crouchK: Double = (p.flash <= 0 && p.energy > 0.82) ? smoother((p.energy - 0.82) / 0.18) : 0
        let since: Double = p.flash > 0 ? -log(max(p.flash, 1e-9)) / 3 : Double.infinity
        let dropW: Double = since < dropDur ? 1 : (since < dropDur + 0.15 ? 1 - smoother((since - dropDur) / 0.15) : 0)
        let phraseW = amp * (1 - 0.6 * crouchK) * (1 - dropW)
        phraseInto(.groove, beats, &out, wG * phraseW)
        phraseInto(.swagger, beats, &out, wS * phraseW)
        phraseInto(.hype, beats, &out, wH * phraseW)
        if crouchK > 0 {
            out.y += crouch.y * crouchK
            out.sx += crouch.sx * crouchK
            out.sy += crouch.sy * crouchK
        }
        if dropW > 0 { addTracks(&out, drop, min(since, dropDur), dropW) }
    }

    /// Reduced Motion dance: a beat-timed brightness and an eyebrow on the bar.
    static func danceReducedInto(_ p: Pulse, _ out: inout Motion, _ w: Double = 1) {
        out.glow *= 1 - 0.08 * (1 - p.beat) * w
        out.bl -= 5 * p.down * w
        out.br -= 5 * p.down * w
    }

    /// How much a window [start, start + dur] suppresses the channels below it.
    static func overrideEnv(_ e: Double, _ dur: Double) -> Double {
        if e < 0 || e > dur + fadeOut { return 0 }
        return smoother(e / fadeIn) * (e < dur ? 1 : 1 - smoother((e - dur) / fadeOut))
    }

    // MARK: - Director

    nonisolated struct Input {
        var mood: Mood
        var rm: Bool
        /// Seconds into the solved sequence (nil when none, or it was over at mount).
        var solveE: Double? = nil
        /// Seconds since the last face or colour change began.
        var transitionE: Double? = nil
        /// The race music, or nil when he is not dancing.
        var pulse: Pulse? = nil
        var style: DanceStyle? = nil
        var intensity: Double = 1
    }

    /// One per mounted Wick (held in KeeperView's @State). Same logic as
    /// MotionDirector in wickmotion.ts.
    nonisolated final class Director {
        let seed: UInt32
        private var epoch: Double? = nil
        private var mood: Mood? = nil
        private var baseFrom = Motion()
        private var baseTo = Motion()
        private var baseAt = -99.0
        private var baseD0 = WickMotion.baseWindow.0
        private var baseD1 = WickMotion.baseWindow.1
        private var clip: Clip? = nil
        private var clipAmp = 1.0
        private var clipAt = -99.0
        private var pending = false
        private var pendingKind: String? = nil
        private var pendingAt = 0.0
        private var carry = Motion()
        private var carryAt = -99.0
        private var carryEnv = 0.0
        private var guessAt = -99.0
        private var focused = false
        private var focusAt = -99.0
        private var typedAt = -99.0
        private var typedCount = 0
        private var gazeW = 0.0
        private var lastLt: Double? = nil
        private var cur = AttnCursor()

        init(seed: UInt32) { self.seed = seed }

        private func local(_ t: Double) -> Double {
            if epoch == nil { epoch = t }
            return t - (epoch ?? t)
        }

        /// A guess was scored, or Wick reacted. `kind` is a WickReactionKind raw
        /// value, "question" for Ask Wick, or nil for a plain guess.
        func cue(_ t: Double, kind: String?) {
            let lt = local(t)
            pending = true
            pendingKind = kind
            pendingAt = lt
            guessAt = lt
        }

        /// The input field gained or lost focus, or a key was typed.
        func input(_ t: Double, focused f: Bool, typed: Bool = false) {
            let lt = local(t)
            if f && !focused { focusAt = lt }
            focused = f
            if typed { typedAt = lt; typedCount += 1 }
        }

        func baseInto(_ lt: Double, _ out: inout Motion) {
            let u = smoother((lt - baseAt - baseD0) / max(1e-6, baseD1 - baseD0))
            let ut = smoother((lt - baseAt - baseD0 - tipLag) / max(1e-6, baseD1 - baseD0 + tipExtra))
            for c in Channel.allCases {
                let k: Double = (c == .tip || c == .tu) ? ut : u
                out[c] += baseFrom[c] + (baseTo[c] - baseFrom[c]) * k
            }
        }

        private func setMood(_ lt: Double, _ m: Mood) {
            let to = baseMotion(m)
            if mood == nil {
                baseFrom = to; baseTo = to; baseAt = -99
            } else {
                var from = Motion()
                baseInto(lt, &from)
                baseFrom = from
                baseTo = to
                baseAt = lt
                baseD0 = baseWindow.0
                baseD1 = baseWindow.1
                if let c = clip, abs(lt - clipAt) < 0.1, let def = clips[c] {
                    baseAt = clipAt
                    baseD0 = def.baseIn.0
                    baseD1 = def.baseIn.1
                }
            }
            mood = m
        }

        private func clipEnvAt(_ lt: Double) -> Double {
            guard let c = clip else { return 0 }
            return overrideEnv(lt - clipAt, clipDur(c))
        }

        /// How much a reaction clip suppresses the lower channels (0...1).
        func clipEnv(_ lt: Double) -> Double {
            let carried: Double = lt - carryAt < carryDur ? carryEnv * (1 - smoother((lt - carryAt) / carryDur)) : 0
            return max(clipEnvAt(lt), carried)
        }

        /// The clip running at `t` (for tests).
        func activeClip(_ t: Double) -> Clip? {
            let lt = local(t)
            guard let c = clip, lt - clipAt < clipDur(c) else { return nil }
            return c
        }

        private func startClip(_ m: Mood) {
            pending = false
            guard let pick = clipForCue(m, pendingKind) else { return }
            let at = pendingAt
            let keep: Double = at - carryAt < carryDur ? 1 - smoother((at - carryAt) / carryDur) : 0
            carryEnv = max(clipEnvAt(at), carryEnv * keep)
            var c2 = Motion()
            c2.add(carry, keep)
            if let old = clip, at - clipAt < clipDur(old) { clipInto(old, at - clipAt, clipAmp, &c2) }
            c2.glow = 1
            carry = c2
            carryAt = at
            clip = pick.clip
            clipAmp = pick.amp
            clipAt = at
            if abs(baseAt - at) < 0.1, let def = clips[pick.clip] {
                baseAt = at
                baseD0 = def.baseIn.0
                baseD1 = def.baseIn.1
            }
        }

        func sample(_ t: Double, _ inp: Input) -> Motion {
            let lt = local(t)
            let dt: Double = lastLt == nil ? 0 : clamp(lt - (lastLt ?? lt), 0, 0.1)
            lastLt = lt
            if inp.mood != mood { setMood(lt, inp.mood) }
            if pending { startClip(inp.mood) }
            var out = Motion()

            let sw: Double
            if let se = inp.solveE {
                sw = se < KeeperSolve.done ? 0 : smoother((se - KeeperSolve.done) / fadeOut)
            } else {
                sw = 1
            }

            baseInto(lt, &out)

            let ce = clipEnv(lt)
            if let c = clip {
                let e = lt - clipAt
                if e < clipDur(c) { clipInto(c, e, clipAmp, &out) }
            }
            if lt - carryAt < carryDur { out.add(carry, 1 - smoother((lt - carryAt) / carryDur)) }

            let te = inp.transitionE
            let tEnv: Double = te.map { overrideEnv($0, transitionDur) } ?? 0
            if let te, te < transitionDur, !inp.rm { addTracks(&out, transition, te, 1 - ce) }

            let dancing = inp.pulse != nil
            if let p = inp.pulse {
                if inp.rm {
                    danceReducedInto(p, &out, 1 - ce)
                } else {
                    var m = Motion()
                    danceInto(p, &m, style: inp.style, intensity: inp.intensity)
                    out.add(m, 1 - ce)
                }
            }

            let typing = focused && lt - typedAt < typingQuiet
            var idleW = (1 - max(ce, tEnv)) * (dancing ? 0.25 : 1) * (typing ? 0.4 : 1)
            if inp.rm { out.glow *= idleGlow(lt); idleW = 0 }
            idleBody(lt, seed, inp.mood, &out, idleW)
            if !dancing, let ev = attentionAt(lt, seed, &cur) {
                let s = ev.start
                let trStart: Double? = te.map { lt - $0 }
                var blocked = (s >= guessAt && s - guessAt < attnQuietAfterGuess) || s - typedAt < typingQuiet
                if let c = clip, s >= clipAt, s - clipAt < clipDur(c) + fadeOut { blocked = true }
                if let tr = trStart, s >= tr, s - tr < transitionDur + fadeOut { blocked = true }
                if !blocked { attentionInto(ev, lt, &out, 1 - max(ce, tEnv)) }
            }

            let look = focused && lt - max(focusAt, typedAt) < typingQuiet
            gazeW = look ? min(1, gazeW + dt / 0.18) : max(0, gazeW - dt / 0.25)
            if gazeW > 0 {
                let g = smoother(gazeW) * (1 - ce)
                out.gy += 13 * g
                if typing { out.gx += Double((typedCount % 7) - 3) * 1.2 * g }
            }

            if sw < 1 {
                for c in Channel.allCases { out[c] *= sw }
            }
            if inp.rm { reduceMotionClamp(&out) }
            return out
        }
    }
}

// MARK: - Face accents

extension KeeperFaces {
    /// The face with live accents applied (see accentFace in wickface.ts):
    /// pupils (gx, gy), each brow (bl, br; negative is up), each lid (below 0
    /// lifts it; above 0 is closure, applied by the caller) and the tip (tu).
    static func accent(_ p: KeeperFace, _ a: WickMotion.Motion) -> KeeperFace {
        if a.gx == 0 && a.gy == 0 && a.bl == 0 && a.br == 0 && a.ll >= 0 && a.lr >= 0 && a.tu == 0 { return p }
        var f = p
        let lids: [Double] = [a.ll, a.lr]
        for i in f.eyes.indices {
            let lift: Double = min(0, i < lids.count ? lids[i] : 0) * 24
            f.eyes[i].pdx += a.gx
            f.eyes[i].pdy += a.gy
            f.eyes[i].lidL += lift
            f.eyes[i].lidR += lift
        }
        for i in f.brows.indices {
            let dy: Double = i == 0 ? a.bl : a.br
            if dy == 0 { continue }
            var c = f.brows[i].c
            var k = 1
            while k < c.count { c[k] += dy; k += 2 }
            f.brows[i].c = c
        }
        f.tip.dy += a.tu
        return f
    }
}
