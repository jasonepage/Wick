//
//  KeeperFace.swift
//  Hunch
//
//  The Keeper's six faces from the final approved sheet (October 2026): Sly,
//  Flustered, Shocked, Calm, Serious and Focus, on the chunky icon flame, with
//  bushy grey brows, heavy drooping lids, under-eye bags and the lighter inner
//  flame.
//
//  Every number comes straight from the code that drew that sheet, in the art's
//  own units: the 1024 pt icon, where the flame's tip is at (512, 152) and its
//  base at (512, 870). `k` maps art units to Wick's 120 x 128 viewBox (the same
//  one the web uses), and KeeperView maps the viewBox onto its frame.
//
//  KEEP IN LOCKSTEP with wick-web/src/game/wickface.ts: same data, same
//  geometry, same state-to-face rules, same transition timing.
//
//  UI-only: no game logic lives here.
//

import SwiftUI

// MARK: - Data

enum KeeperFaceName: String, CaseIterable {
    case sly, flustered, shocked, calm, serious, focus
}

/// One eye. lidL/lidR/sag: the heavy upper lid (y at its left and right ends,
/// and how far it sags in the middle). closed 1 = shut (Calm); bow and tilt
/// shape the shut lash line. pdx/pdy/pr: the pupil.
struct KeeperEye {
    var cx, cy, rx, ry, lidL, lidR, sag, pdx, pdy, pr, closed, bow, tilt: Double
}

/// One bushy grey brow. `c` is a cubic curve (x0, y0 ... x3, y3) from the
/// INNER end to the OUTER end. `hairs` holds two loose hairs (t, length, lean);
/// `tail` two wisps off the tip (lift, length, width).
struct KeeperBrow {
    var c: [Double]
    var th: Double
    var taper: Double
    var peak: Double
    var hairs: [Double]
    var tail: [Double]
}

/// The mouth: a white stroke through `pts` (x, y pairs), or (oval 1) the small dark "o".
struct KeeperMouth {
    var pts: [Double]
    var w: Double
    var oval: Double
    var ocx: Double
    var ocy: Double
    var orx: Double
    var ory: Double
}

struct KeeperDrop {
    var on, x, y, r, h, tilt: Double
}

/// The flame tip's reaction, in viewBox units: curl (Sly), droop (Flustered), spike (Shocked).
struct KeeperTip {
    var dx, dy, sharp: Double
}

struct KeeperFace {
    var eyes: [KeeperEye]
    var brows: [KeeperBrow]
    var mouth: KeeperMouth
    var drop: KeeperDrop
    var tip: KeeperTip
}

/// A colour as 0...255 channels, so the shading rule can do arithmetic on it.
struct KeeperRGB: Equatable {
    var r: Double
    var g: Double
    var b: Double

    var color: Color { Color(red: r / 255, green: g / 255, blue: b / 255) }

    static func mix(_ a: KeeperRGB, _ b: KeeperRGB, _ u: Double) -> KeeperRGB {
        KeeperRGB(r: a.r + (b.r - a.r) * u, g: a.g + (b.g - a.g) * u, b: a.b + (b.b - a.b) * u)
    }

    /// Wick's body colour for a mood, as numbers. Same values as HunchTheme.Palette.
    static func body(for mood: KeeperMood) -> KeeperRGB {
        switch mood {
        case .idle, .thinking, .unamused: return KeeperRGB(r: 0.49 * 255, g: 0.36 * 255, b: 0.92 * 255)
        case .freezing:                   return KeeperRGB(r: 0.27 * 255, g: 0.52 * 255, b: 0.90 * 255)
        case .cold:                       return KeeperRGB(r: 0.35 * 255, g: 0.74 * 255, b: 0.71 * 255)
        case .warm:                       return KeeperRGB(r: 0.95 * 255, g: 0.65 * 255, b: 0.14 * 255)
        case .hot:                        return KeeperRGB(r: 0.93 * 255, g: 0.42 * 255, b: 0.18 * 255)
        case .boiling:                    return KeeperRGB(r: 0.91 * 255, g: 0.26 * 255, b: 0.21 * 255)
        case .celebrating:                return KeeperRGB(r: 0.30 * 255, g: 0.62 * 255, b: 0.28 * 255)
        case .defeated:                   return KeeperRGB(r: 0.45 * 255, g: 0.45 * 255, b: 0.50 * 255)
        }
    }
}

enum KeeperFaces {
    static let sly = KeeperFace(
        eyes: [
            KeeperEye(cx: 413.0, cy: 578.0, rx: 54.0, ry: 42.0, lidL: 590.0, lidR: 582.0, sag: 7.0, pdx: -24.0, pdy: 8.0, pr: 23.0, closed: 0.0, bow: 5.0, tilt: 0.0),
            KeeperEye(cx: 611.0, cy: 578.0, rx: 54.0, ry: 42.0, lidL: 588.0, lidR: 583.0, sag: 7.0, pdx: -24.0, pdy: 8.0, pr: 23.0, closed: 0.0, bow: 5.0, tilt: 0.0),
        ],
        brows: [
            KeeperBrow(c: [474.0, 537.0, 444.0, 533.0, 398.0, 534.0, 356.0, 544.0], th: 35.84, taper: 0.5, peak: 0.25,
                       hairs: [0.18, 10.0, 40.0, 0.47, 8.0, 55.0], tail: [6.0, 20.0, 5.0, 0.0, 0.0, 0.0]),
            KeeperBrow(c: [554.0, 522.0, 584.0, 494.0, 634.0, 480.0, 674.0, 494.0], th: 35.84, taper: 0.5, peak: 0.35,
                       hairs: [0.22, 9.0, 35.0, 0.4, 12.0, 45.0], tail: [18.0, 28.0, 6.0, -10.0, 18.0, 4.0]),
        ],
        mouth: KeeperMouth(pts: [
            582.97, 702.0, 578.54, 703.21, 574.08, 704.35, 569.6, 705.42, 565.11, 706.41, 560.6, 707.33,
            556.08, 708.17, 551.54, 708.93, 546.99, 709.61, 542.43, 710.21, 537.86, 710.72, 533.28, 711.13,
            528.69, 711.45, 524.09, 711.67, 519.5, 711.78, 514.9, 711.77, 510.3, 711.63, 505.7, 711.35,
            501.12, 710.93, 496.56, 710.35, 492.02, 709.59, 487.52, 708.64, 483.07, 707.49, 478.68, 706.1,
            474.38, 704.47, 470.19, 702.57, 466.14, 700.39, 462.28, 697.9, 458.62, 695.11, 455.23, 692.0,
            452.14, 688.6, 449.38, 684.92, 446.97, 681.0
        ], w: 24.0, oval: 0.0, ocx: 512.0, ocy: 712.0, orx: 18.0, ory: 23.0),
        drop: KeeperDrop(on: 0.0, x: 714.0, y: 560.0, r: 19.0, h: 50.0, tilt: -14.0),
        tip: KeeperTip(dx: -4.0, dy: 0.0, sharp: 0.92)   // curl
    )
    static let flustered = KeeperFace(
        eyes: [
            KeeperEye(cx: 413.0, cy: 578.0, rx: 54.0, ry: 50.0, lidL: 558.0, lidR: 540.0, sag: 6.0, pdx: 22.0, pdy: 14.0, pr: 23.0, closed: 0.0, bow: 5.0, tilt: 0.0),
            KeeperEye(cx: 611.0, cy: 578.0, rx: 54.0, ry: 50.0, lidL: 540.0, lidR: 558.0, sag: 6.0, pdx: 22.0, pdy: 14.0, pr: 23.0, closed: 0.0, bow: 5.0, tilt: 0.0),
        ],
        brows: [
            KeeperBrow(c: [462.0, 460.0, 430.0, 474.0, 392.0, 494.0, 358.0, 514.0], th: 35.84, taper: 0.5, peak: 0.2,
                       hairs: [0.15, 9.0, 30.0, 0.42, 7.0, 50.0], tail: [10.0, 18.0, 4.0, 0.0, 0.0, 0.0]),
            KeeperBrow(c: [564.0, 468.0, 592.0, 474.0, 628.0, 492.0, 662.0, 512.0], th: 35.84, taper: 0.5, peak: 0.3,
                       hairs: [0.25, 8.0, 40.0, 0.55, 9.0, 55.0], tail: [-4.0, 16.0, 4.0, 0.0, 0.0, 0.0]),
        ],
        mouth: KeeperMouth(pts: [
            464.0, 712.0, 466.6, 714.53, 469.29, 716.96, 472.16, 719.18, 475.31, 720.96, 478.79, 721.93,
            482.4, 721.72, 485.78, 720.43, 488.82, 718.47, 491.62, 716.17, 494.27, 713.69, 496.86, 711.15,
            499.48, 708.65, 502.22, 706.27, 505.17, 704.17, 508.44, 702.61, 512.0, 702.0, 515.56, 702.61,
            518.83, 704.17, 521.78, 706.27, 524.52, 708.65, 527.14, 711.15, 529.73, 713.69, 532.38, 716.17,
            535.18, 718.47, 538.22, 720.43, 541.6, 721.72, 545.21, 721.93, 548.69, 720.96, 551.84, 719.18,
            554.71, 716.96, 557.4, 714.53, 560.0, 712.0
        ], w: 22.0, oval: 0.0, ocx: 512.0, ocy: 712.0, orx: 18.0, ory: 23.0),
        drop: KeeperDrop(on: 1.0, x: 714.0, y: 560.0, r: 19.0, h: 50.0, tilt: -14.0),
        tip: KeeperTip(dx: 3.3, dy: 2.3, sharp: 1.08)   // droop
    )
    static let shocked = KeeperFace(
        eyes: [
            KeeperEye(cx: 413.0, cy: 578.0, rx: 54.0, ry: 52.0, lidL: 531.0, lidR: 531.0, sag: 4.0, pdx: 0.0, pdy: 2.0, pr: 17.0, closed: 0.0, bow: 5.0, tilt: 0.0),
            KeeperEye(cx: 611.0, cy: 578.0, rx: 54.0, ry: 52.0, lidL: 531.0, lidR: 531.0, sag: 4.0, pdx: 0.0, pdy: 2.0, pr: 17.0, closed: 0.0, bow: 5.0, tilt: 0.0),
        ],
        brows: [
            KeeperBrow(c: [470.0, 488.0, 446.0, 466.0, 400.0, 458.0, 360.0, 472.0], th: 35.84, taper: 0.5, peak: 0.3,
                       hairs: [0.2, 8.0, 35.0, 0.5, 10.0, 50.0], tail: [14.0, 20.0, 5.0, 0.0, 0.0, 0.0]),
            KeeperBrow(c: [556.0, 474.0, 578.0, 446.0, 628.0, 436.0, 666.0, 452.0], th: 35.84, taper: 0.5, peak: 0.4,
                       hairs: [0.3, 11.0, 40.0, 0.58, 8.0, 55.0], tail: [20.0, 24.0, 5.0, -6.0, 14.0, 4.0]),
        ],
        mouth: KeeperMouth(pts: [
            512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0,
            512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0,
            512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0,
            512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0,
            512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0,
            512.0, 712.0, 512.0, 712.0, 512.0, 712.0
        ], w: 24.0, oval: 1.0, ocx: 512.0, ocy: 712.0, orx: 18.0, ory: 23.0),
        drop: KeeperDrop(on: 0.0, x: 714.0, y: 560.0, r: 19.0, h: 50.0, tilt: -14.0),
        tip: KeeperTip(dx: 0.0, dy: -3.0, sharp: 0.82)   // spike
    )
    static let serious = KeeperFace(
        eyes: [
            KeeperEye(cx: 413.0, cy: 578.0, rx: 54.0, ry: 42.0, lidL: 566.0, lidR: 586.0, sag: 5.0, pdx: 4.0, pdy: 8.0, pr: 23.0, closed: 0.0, bow: 5.0, tilt: 0.0),
            KeeperEye(cx: 611.0, cy: 578.0, rx: 54.0, ry: 42.0, lidL: 586.0, lidR: 566.0, sag: 5.0, pdx: -4.0, pdy: 8.0, pr: 23.0, closed: 0.0, bow: 5.0, tilt: 0.0),
        ],
        brows: [
            KeeperBrow(c: [484.0, 556.0, 448.0, 544.0, 402.0, 526.0, 356.0, 514.0], th: 35.84, taper: 0.5, peak: 0.25,
                       hairs: [0.2, 9.0, 30.0, 0.45, 11.0, 45.0], tail: [8.0, 22.0, 5.0, 0.0, 0.0, 0.0]),
            KeeperBrow(c: [540.0, 548.0, 578.0, 536.0, 624.0, 514.0, 668.0, 496.0], th: 35.84, taper: 0.5, peak: 0.3,
                       hairs: [0.3, 8.0, 40.0, 0.6, 10.0, 50.0], tail: [12.0, 18.0, 4.0, -8.0, 14.0, 3.0]),
        ],
        mouth: KeeperMouth(pts: [
            474.0, 710.0, 476.38, 710.0, 478.75, 710.0, 481.12, 710.0, 483.5, 710.0, 485.88, 710.0,
            488.25, 710.0, 490.62, 710.0, 493.0, 710.0, 495.38, 710.0, 497.75, 710.0, 500.12, 710.0,
            502.5, 710.0, 504.88, 710.0, 507.25, 710.0, 509.62, 710.0, 512.0, 710.0, 514.38, 710.0,
            516.75, 710.0, 519.12, 710.0, 521.5, 710.0, 523.88, 710.0, 526.25, 710.0, 528.62, 710.0,
            531.0, 710.0, 533.38, 710.0, 535.75, 710.0, 538.12, 710.0, 540.5, 710.0, 542.88, 710.0,
            545.25, 710.0, 547.62, 710.0, 550.0, 710.0
        ], w: 24.0, oval: 0.0, ocx: 512.0, ocy: 712.0, orx: 18.0, ory: 23.0),
        drop: KeeperDrop(on: 0.0, x: 714.0, y: 560.0, r: 19.0, h: 50.0, tilt: -14.0),
        tip: KeeperTip(dx: 0.0, dy: 0.0, sharp: 1.0)   // neutral
    )
    static let focus = KeeperFace(
        eyes: [
            KeeperEye(cx: 413.0, cy: 578.0, rx: 54.0, ry: 42.0, lidL: 592.0, lidR: 596.0, sag: 5.0, pdx: -2.0, pdy: 26.0, pr: 21.0, closed: 0.0, bow: 5.0, tilt: 0.0),
            KeeperEye(cx: 611.0, cy: 578.0, rx: 54.0, ry: 42.0, lidL: 586.0, lidR: 582.0, sag: 5.0, pdx: -2.0, pdy: 26.0, pr: 21.0, closed: 0.0, bow: 5.0, tilt: 0.0),
        ],
        brows: [
            KeeperBrow(c: [484.0, 550.0, 450.0, 548.0, 406.0, 548.0, 364.0, 552.0], th: 35.84, taper: 0.5, peak: 0.25,
                       hairs: [0.25, 10.0, 35.0, 0.52, 8.0, 50.0], tail: [4.0, 18.0, 4.0, 0.0, 0.0, 0.0]),
            KeeperBrow(c: [540.0, 548.0, 574.0, 544.0, 620.0, 542.0, 660.0, 546.0], th: 35.84, taper: 0.5, peak: 0.3,
                       hairs: [0.2, 8.0, 40.0, 0.48, 10.0, 45.0], tail: [14.0, 20.0, 5.0, 0.0, 0.0, 0.0]),
        ],
        mouth: KeeperMouth(pts: [
            486.01, 710.0, 487.63, 709.92, 489.24, 709.86, 490.86, 709.8, 492.48, 709.75, 494.1, 709.72,
            495.71, 709.7, 497.33, 709.69, 498.95, 709.7, 500.57, 709.72, 502.19, 709.76, 503.81, 709.82,
            505.42, 709.9, 507.04, 710.0, 508.65, 710.13, 510.26, 710.28, 511.87, 710.46, 513.48, 710.67,
            515.08, 710.91, 516.67, 711.19, 518.26, 711.5, 519.84, 711.85, 521.41, 712.24, 522.97, 712.68,
            524.52, 713.16, 526.04, 713.69, 527.55, 714.28, 529.04, 714.92, 530.5, 715.61, 531.93, 716.37,
            533.33, 717.18, 534.69, 718.06, 536.01, 719.0
        ], w: 24.0, oval: 0.0, ocx: 512.0, ocy: 712.0, orx: 18.0, ory: 23.0),
        drop: KeeperDrop(on: 0.0, x: 714.0, y: 560.0, r: 19.0, h: 50.0, tilt: -14.0),
        tip: KeeperTip(dx: 0.0, dy: 0.0, sharp: 1.0)   // neutral
    )
    static let calm = KeeperFace(
        eyes: [
            KeeperEye(cx: 413.0, cy: 578.0, rx: 54.0, ry: 40.0, lidL: 587.0, lidR: 581.0, sag: 24.0, pdx: 0.0, pdy: 0.0, pr: 20.0, closed: 1.0, bow: 24.0, tilt: 3.0),
            KeeperEye(cx: 611.0, cy: 578.0, rx: 54.0, ry: 40.0, lidL: 582.0, lidR: 586.0, sag: 24.0, pdx: 0.0, pdy: 0.0, pr: 20.0, closed: 1.0, bow: 24.0, tilt: -2.0),
        ],
        brows: [
            KeeperBrow(c: [470.0, 506.0, 442.0, 492.0, 400.0, 488.0, 360.0, 498.0], th: 35.84, taper: 0.5, peak: 0.3,
                       hairs: [0.2, 9.0, 35.0, 0.5, 8.0, 50.0], tail: [12.0, 20.0, 5.0, 0.0, 0.0, 0.0]),
            KeeperBrow(c: [556.0, 498.0, 586.0, 482.0, 630.0, 476.0, 666.0, 488.0], th: 35.84, taper: 0.5, peak: 0.35,
                       hairs: [0.25, 10.0, 40.0, 0.55, 8.0, 55.0], tail: [16.0, 24.0, 5.0, -8.0, 14.0, 4.0]),
        ],
        mouth: KeeperMouth(pts: [
            454.0, 700.0, 457.0, 702.79, 460.2, 705.37, 463.56, 707.72, 467.06, 709.85, 470.69, 711.77,
            474.42, 713.47, 478.25, 714.96, 482.14, 716.24, 486.1, 717.31, 490.11, 718.19, 494.16, 718.86,
            498.23, 719.33, 502.32, 719.61, 506.43, 719.7, 510.53, 719.59, 514.62, 719.28, 518.69, 718.78,
            522.73, 718.08, 526.73, 717.18, 530.69, 716.09, 534.58, 714.8, 538.4, 713.31, 542.14, 711.62,
            545.78, 709.73, 549.32, 707.65, 552.73, 705.37, 556.01, 702.9, 559.14, 700.25, 562.11, 697.43,
            564.92, 694.44, 567.55, 691.29, 570.0, 688.0
        ], w: 24.0, oval: 0.0, ocx: 512.0, ocy: 712.0, orx: 18.0, ory: 23.0),
        drop: KeeperDrop(on: 0.0, x: 714.0, y: 560.0, r: 19.0, h: 50.0, tilt: -14.0),
        tip: KeeperTip(dx: 0.0, dy: 0.0, sharp: 1.0)   // neutral
    )

    static func face(_ name: KeeperFaceName) -> KeeperFace {
        switch name {
        case .sly:       return sly
        case .flustered: return flustered
        case .shocked:   return shocked
        case .calm:      return calm
        case .serious:   return serious
        case .focus:     return focus
        }
    }

    /// Art units to viewBox units.
    static let k: Double = 120.0 / 718.0
    /// How far the flame tip leans across the full flicker, in viewBox units.
    static let lean: Double = 0.09 * 102.0
    /// Seconds Shocked holds after the word is cracked before settling to Calm.
    static let shockHold: Double = 1.5

    static let eyeWhite = KeeperRGB(r: 245, g: 243, b: 254)
    static let pupil = KeeperRGB(r: 31, g: 23, b: 59)
    static let browGrey = KeeperRGB(r: 214, g: 210, b: 228)

    // MARK: State to face

    /// Which face for the game's state. Solved shows Shocked, then settles to Calm.
    /// Thinking (an Ask Wick answer on its way) is Focus, except in a race,
    /// where a pending guess keeps the Serious race face.
    static func faceFor(mood: KeeperMood, race: Bool, sinceSolved: Double) -> KeeperFaceName {
        switch mood {
        case .celebrating:
            return sinceSolved < shockHold ? .shocked : .calm
        case .defeated, .unamused:
            return .calm
        case .thinking:
            return race ? .serious : .focus
        default:
            break
        }
        if race { return .serious }
        switch mood {
        case .warm, .hot, .boiling: return .flustered
        default:                    return .sly
        }
    }

    // MARK: Timing (same as the web)

    /// The transition blink: shut in 90 ms, hold while the face morphs, open by 420 ms.
    static func swapBlink(_ e: Double) -> Double {
        if e < 0 { return 0 }
        if e < 0.09 { return e / 0.09 }
        if e < 0.30 { return 1 }
        if e < 0.42 { return 1 - (e - 0.30) / 0.12 }
        return 0
    }

    /// How far through the morph the brows, mouth and tip are.
    static func swapMorph(_ e: Double) -> Double {
        let x: Double = max(0, min(1, (e - 0.06) / 0.32))
        return x * x * (3 - 2 * x)
    }

    /// An idle blink: 70 ms shut, hold 110 ms, 90 ms open.
    static func blinkAmount(_ e: Double) -> Double {
        if e < 0 { return 0 }
        if e < 0.07 { return e / 0.07 }
        if e < 0.18 { return 1 }
        if e < 0.27 { return 1 - (e - 0.18) / 0.09 }
        return 0
    }

    /// The squash-and-stretch envelope (same curve as a poke).
    static func popEnvelope(_ e: Double) -> Double {
        if e < 0 || e >= 0.45 { return 0 }
        return cos(e / 0.45 * Double.pi / 2) * exp(-e * 5)
    }

    // MARK: Blending

    private static func mixD(_ a: Double, _ b: Double, _ u: Double) -> Double { a + (b - a) * u }
    private static func mixA(_ a: [Double], _ b: [Double], _ u: Double) -> [Double] {
        var out: [Double] = []
        out.reserveCapacity(a.count)
        for i in 0..<min(a.count, b.count) { out.append(a[i] + (b[i] - a[i]) * u) }
        return out
    }

    static func mix(_ a: KeeperFace, _ b: KeeperFace, _ u: Double) -> KeeperFace {
        var eyes: [KeeperEye] = []
        for i in 0..<min(a.eyes.count, b.eyes.count) {
            let p = a.eyes[i], q = b.eyes[i]
            eyes.append(KeeperEye(cx: mixD(p.cx, q.cx, u), cy: mixD(p.cy, q.cy, u), rx: mixD(p.rx, q.rx, u), ry: mixD(p.ry, q.ry, u),
                                  lidL: mixD(p.lidL, q.lidL, u), lidR: mixD(p.lidR, q.lidR, u), sag: mixD(p.sag, q.sag, u),
                                  pdx: mixD(p.pdx, q.pdx, u), pdy: mixD(p.pdy, q.pdy, u), pr: mixD(p.pr, q.pr, u),
                                  closed: mixD(p.closed, q.closed, u), bow: mixD(p.bow, q.bow, u), tilt: mixD(p.tilt, q.tilt, u)))
        }
        var brows: [KeeperBrow] = []
        for i in 0..<min(a.brows.count, b.brows.count) {
            let p = a.brows[i], q = b.brows[i]
            brows.append(KeeperBrow(c: mixA(p.c, q.c, u), th: mixD(p.th, q.th, u), taper: mixD(p.taper, q.taper, u),
                                    peak: mixD(p.peak, q.peak, u), hairs: mixA(p.hairs, q.hairs, u), tail: mixA(p.tail, q.tail, u)))
        }
        let m = a.mouth, n = b.mouth
        let mouth = KeeperMouth(pts: mixA(m.pts, n.pts, u), w: mixD(m.w, n.w, u), oval: mixD(m.oval, n.oval, u),
                                ocx: mixD(m.ocx, n.ocx, u), ocy: mixD(m.ocy, n.ocy, u), orx: mixD(m.orx, n.orx, u), ory: mixD(m.ory, n.ory, u))
        let d = a.drop, e = b.drop
        let drop = KeeperDrop(on: mixD(d.on, e.on, u), x: mixD(d.x, e.x, u), y: mixD(d.y, e.y, u),
                              r: mixD(d.r, e.r, u), h: mixD(d.h, e.h, u), tilt: mixD(d.tilt, e.tilt, u))
        let tip = KeeperTip(dx: mixD(a.tip.dx, b.tip.dx, u), dy: mixD(a.tip.dy, b.tip.dy, u), sharp: mixD(a.tip.sharp, b.tip.sharp, u))
        return KeeperFace(eyes: eyes, brows: brows, mouth: mouth, drop: drop, tip: tip)
    }

    // MARK: Geometry (art units)

    private static func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

    /// A region swept column by column: for each x, the (top, bottom) span, or nil.
    private static func columns(_ x0: Double, _ x1: Double, _ n: Int, _ span: (Double) -> (Double, Double)?) -> Path {
        var best: [(Double, Double, Double)] = []
        var cur: [(Double, Double, Double)] = []
        for i in 0..<n {
            let f: Double = 0.5 - 0.5 * cos(Double.pi * Double(i) / Double(n - 1))
            let x: Double = x0 + (x1 - x0) * f
            if let s = span(x), s.1 - s.0 > 0.05 {
                cur.append((x, s.0, s.1))
            } else {
                if cur.count > best.count { best = cur }
                cur = []
            }
        }
        if cur.count > best.count { best = cur }
        var p = Path()
        guard best.count >= 2 else { return p }
        p.move(to: pt(best[0].0, best[0].1))
        for c in best.dropFirst() { p.addLine(to: pt(c.0, c.1)) }
        for c in best.reversed() { p.addLine(to: pt(c.0, c.2)) }
        p.closeSubpath()
        return p
    }

    /// sqrt(1 - ((x - cx) / r)^2), or -1 outside the ellipse.
    private static func half(_ x: Double, _ cx: Double, _ r: Double) -> Double {
        let d: Double = (x - cx) / r
        let q: Double = 1 - d * d
        return q > 0 ? sqrt(q) : -1
    }

    private static func quad(_ x: Double, _ x0: Double, _ x1: Double, _ yL: Double, _ yR: Double, _ sag: Double) -> Double {
        let u: Double = max(0, min(1, (x - x0) / (x1 - x0)))
        let mid: Double = (yL + yR) / 2 + sag
        let a: Double = (1 - u) * (1 - u) * yL
        let b: Double = 2 * u * (1 - u) * mid
        return a + b + u * u * yR
    }

    /// The open lid line.
    private static func lidY(_ e: KeeperEye, _ x: Double) -> Double {
        quad(x, e.cx - e.rx - 10, e.cx + e.rx + 10, e.lidL, e.lidR, e.sag)
    }
    /// The shut lash line.
    private static func shutY(_ e: KeeperEye, _ x: Double) -> Double {
        quad(x, e.cx - e.rx, e.cx + e.rx, e.cy + 6 + e.tilt, e.cy + 6 - e.tilt, e.bow)
    }

    struct EyeShapes {
        var lid: Path
        var bag: Path
        var white: Path
        var pupil: Path
        var lash: Path
        var lashOpacity: Double
    }

    /// One eye at closure `c` (0 open, 1 shut): heavy lid, under-eye bag, white, pupil, lash line.
    static func eyeShapes(_ e: KeeperEye, _ c: Double) -> EyeShapes {
        func upper(_ x: Double) -> Double {
            let l: Double = lidY(e, x)
            return l + (shutY(e, x) - l) * c
        }
        func lower(_ x: Double) -> Double {
            let b: Double = e.cy + e.ry
            return b + (shutY(e, x) - b) * c
        }
        func inEye(_ x: Double) -> (Double, Double)? {
            let h = half(x, e.cx, e.rx)
            if h < 0 { return nil }
            return (max(e.cy - e.ry * h, upper(x)), min(e.cy + e.ry * h, lower(x)))
        }
        let white = columns(e.cx - e.rx, e.cx + e.rx, 40, inEye)
        let px: Double = e.cx + e.pdx
        let py: Double = e.cy + e.pdy
        let pupil = columns(px - e.pr, px + e.pr, 28) { x in
            guard let w = inEye(x) else { return nil }
            let h = half(x, px, e.pr)
            if h < 0 { return nil }
            return (max(w.0, py - e.pr * h), min(w.1, py + e.pr * h))
        }
        let lid = columns(e.cx - e.rx - 6, e.cx + e.rx + 6, 40) { x in
            let h = half(x, e.cx, e.rx + 6)
            if h < 0 { return nil }
            return (e.cy - (e.ry + 6) * h, min(e.cy + (e.ry + 6) * h, upper(x)))
        }
        let bag = columns(e.cx - e.rx * 0.8, e.cx + e.rx * 0.8, 28) { x in
            let h1 = half(x, e.cx, e.rx * 0.8)
            let h2 = half(x, e.cx, e.rx + 5)
            if h1 < 0 { return nil }
            let bottom: Double = e.cy + 5 + (e.ry + 10) * h1
            let inner: Double = h2 < 0 ? -Double.infinity : e.cy + (e.ry + 4) * h2
            let top: Double = max(inner, e.cy + e.ry * 0.35)
            return (top, bottom)
        }
        var lash = Path()
        for i in 0...24 {
            let x: Double = e.cx - e.rx + 2 * e.rx * Double(i) / 24
            if i == 0 { lash.move(to: pt(x, upper(x))) } else { lash.addLine(to: pt(x, upper(x))) }
        }
        let lo: Double = max(0, min(1, (c - 0.55) / 0.35))
        return EyeShapes(lid: lid, bag: bag, white: white, pupil: pupil, lash: lash, lashOpacity: lo * lo * (3 - 2 * lo))
    }

    /// A strand: a centre line widened by `ws` either side along (px, py).
    private static func strand(_ pts: [(Double, Double)], _ ws: [Double], _ px: Double, _ py: Double) -> Path {
        var p = Path()
        guard pts.count >= 2 else { return p }
        for (k, q) in pts.enumerated() {
            let a = pt(q.0 + px * ws[k], q.1 + py * ws[k])
            if k == 0 { p.move(to: a) } else { p.addLine(to: a) }
        }
        for (k, q) in pts.enumerated().reversed() { p.addLine(to: pt(q.0 - px * ws[k], q.1 - py * ws[k])) }
        p.closeSubpath()
        return p
    }

    /// A bushy grey brow: tapered body with a soft uneven top, loose hairs and tip wisps.
    static func browPath(_ b: KeeperBrow) -> Path {
        let n = 120
        let th = b.th
        let c = b.c
        func bez(_ t: Double) -> (Double, Double) {
            let a: Double = (1 - t) * (1 - t) * (1 - t)
            let bb: Double = 3 * (1 - t) * (1 - t) * t
            let d: Double = 3 * (1 - t) * t * t
            let e: Double = t * t * t
            let x: Double = a * c[0] + bb * c[2] + d * c[4] + e * c[6]
            let y: Double = a * c[1] + bb * c[3] + d * c[5] + e * c[7]
            return (x, y)
        }
        var cen: [(Double, Double)] = []
        for i in 0...n { cen.append(bez(Double(i) / Double(n))) }
        func frame(_ i: Int) -> (Double, Double, Double, Double) {
            let a = cen[max(i - 1, 0)], q = cen[min(i + 1, n)]
            var tx: Double = q.0 - a.0, ty: Double = q.1 - a.1
            let len: Double = max(1e-9, (tx * tx + ty * ty).squareRoot())
            tx /= len; ty /= len
            var nx: Double = ty, ny: Double = -tx
            if ny > 0 { nx = -nx; ny = -ny }
            return (tx, ty, nx, ny)
        }
        func width(_ t: Double) -> Double {
            let rise: Double = b.peak > 0 ? min(1, t / b.peak) : 1
            let fall: Double = max(0, (t - b.peak) / (1 - b.peak))
            let s1: Double = 0.72 + 0.28 * sin(rise * Double.pi / 2)
            let s2: Double = 1 - b.taper * pow(fall, 1.4)
            return th * s1 * s2
        }
        let ph: Double = (c[0] * 0.37 + c[1] * 0.11).truncatingRemainder(dividingBy: 6.28)
        var top: [CGPoint] = [], bot: [CGPoint] = []
        for i in 0...n {
            let f = frame(i)
            let t: Double = Double(i) / Double(n)
            let w: Double = width(t) / 2
            let wave: Double = sin(2 * Double.pi * 2.4 * t + ph) + 0.5 * sin(2 * Double.pi * 5.3 * t + ph * 1.7)
            let rough: Double = th * 0.055 * wave * (0.3 + 0.7 * t)
            let x = cen[i].0, y = cen[i].1
            top.append(pt(x + f.2 * (w + rough), y + f.3 * (w + rough)))
            bot.append(pt(x - f.2 * w, y - f.3 * w))
        }
        let f0 = frame(0)
        let w0: Double = width(0) / 2
        var cap: [CGPoint] = []
        for kk in 1..<20 {
            let a: Double = Double.pi * Double(kk) / 20
            cap.append(pt(cen[0].0 + f0.2 * w0 * cos(a) - f0.0 * w0 * sin(a),
                          cen[0].1 + f0.3 * w0 * cos(a) - f0.1 * w0 * sin(a)))
        }
        var path = Path()
        var outline: [CGPoint] = top
        outline.append(contentsOf: bot.reversed())
        outline.append(contentsOf: cap.reversed())
        path.move(to: outline[0])
        for q in outline.dropFirst() { path.addLine(to: q) }
        path.closeSubpath()

        for j in 0..<2 {
            let t = b.hairs[j * 3], ln = b.hairs[j * 3 + 1], lean = b.hairs[j * 3 + 2]
            if ln < 0.5 { continue }
            let i = min(n, max(0, Int((t * Double(n)).rounded(.down))))
            let f = frame(i)
            let w: Double = width(t) / 2
            let bx: Double = cen[i].0 + f.2 * (w - 3), by: Double = cen[i].1 + f.3 * (w - 3)
            let a: Double = lean * Double.pi / 180
            let dx: Double = f.2 * cos(a) + f.0 * sin(a), dy: Double = f.3 * cos(a) + f.1 * sin(a)
            let len: Double = ln * 1.4
            var pts: [(Double, Double)] = [], ws: [Double] = []
            for kk in 0...20 {
                let u: Double = Double(kk) / 20
                pts.append((bx + dx * len * u + f.0 * len * 0.35 * u * u, by + dy * len * u + f.1 * len * 0.35 * u * u))
                ws.append(3.2 * (1 - u) + 0.4)
            }
            path.addPath(strand(pts, ws, -dy, dx))
        }
        let ft = frame(n - 6)
        let ex = cen[n - 6].0, ey = cen[n - 6].1
        for j in 0..<2 {
            let lift = b.tail[j * 3], ln = b.tail[j * 3 + 1], wd = b.tail[j * 3 + 2]
            if ln < 0.5 { continue }
            let a: Double = lift * Double.pi / 180
            let dx: Double = ft.0 * cos(a) + ft.2 * sin(a), dy: Double = ft.1 * cos(a) + ft.3 * sin(a)
            var pts: [(Double, Double)] = [], ws: [Double] = []
            for kk in 0...24 {
                let u: Double = Double(kk) / 24
                pts.append((ex + dx * ln * u + ft.2 * ln * 0.18 * u * u, ey + dy * ln * u + ft.3 * ln * 0.18 * u * u))
                ws.append(wd * (1 - u))
            }
            path.addPath(strand(pts, ws, -dy, dx))
        }
        return path
    }

    /// The sweat drop: a circle and the triangle up to its tip, turned by `tilt`.
    static func dropPath(_ d: KeeperDrop) -> Path {
        let s: Double = 0.4 + 0.6 * d.on
        let r: Double = d.r * s, h: Double = d.h * s
        let a: Double = d.tilt * Double.pi / 180
        let kq: Double = r / h
        let tx: Double = r * (1 - kq * kq).squareRoot(), ty: Double = -r * kq
        func rot(_ x: Double, _ y: Double) -> CGPoint {
            pt(d.x + x * cos(a) - y * sin(a), d.y + x * sin(a) + y * cos(a))
        }
        var p = Path()
        p.move(to: rot(0, -h))
        p.addLine(to: rot(tx, ty))
        p.addLine(to: rot(-tx, ty))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: d.x - r, y: d.y - r, width: 2 * r, height: 2 * r))
        return p
    }

    static func mouthStroke(_ m: KeeperMouth) -> Path {
        var p = Path()
        var i = 0
        while i + 1 < m.pts.count {
            let q = pt(m.pts[i], m.pts[i + 1])
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
            i += 2
        }
        return p
    }

    static func mouthOval(_ m: KeeperMouth) -> Path {
        let s: Double = 0.3 + 0.7 * m.oval
        let rx: Double = m.orx * s, ry: Double = m.ory * s
        return Path(ellipseIn: CGRect(x: m.ocx - rx, y: m.ocy - ry, width: 2 * rx, height: 2 * ry))
    }

    /// The inner flame (lighter core) in art units, for clipping the face shading.
    static let plateArt: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 511.5, y: 448.0))
        p.addCurve(to: CGPoint(x: 655.9, y: 657.5), control1: CGPoint(x: 585.0, y: 490.4), control2: CGPoint(x: 655.9, y: 540.0))
        p.addCurve(to: CGPoint(x: 511.5, y: 841.0), control1: CGPoint(x: 655.9, y: 776.5), control2: CGPoint(x: 598.8, y: 841.0))
        p.addCurve(to: CGPoint(x: 368.1, y: 657.5), control1: CGPoint(x: 425.2, y: 841.0), control2: CGPoint(x: 368.1, y: 776.5))
        p.addCurve(to: CGPoint(x: 511.5, y: 448.0), control1: CGPoint(x: 368.1, y: 540.0), control2: CGPoint(x: 439.0, y: 490.4))
        p.closeSubpath()
        return p
    }()

    // MARK: Shading: one rule for the whole face
    //  The inner flame is one tone step UP from the body (white at 22%). The
    //  under-eye bags are that same step DOWN, and the heavy lids 1.3 steps down.

    static func plateRGB(_ c: KeeperRGB) -> KeeperRGB {
        KeeperRGB(r: c.r + (255 - c.r) * 0.22, g: c.g + (255 - c.g) * 0.22, b: c.b + (255 - c.b) * 0.22)
    }

    /// `base` stepped down `steps` tone steps for body colour `c`.
    static func shadeRGB(_ base: KeeperRGB, _ c: KeeperRGB, _ steps: Double) -> KeeperRGB {
        let p = plateRGB(c)
        func ch(_ v: Double, _ cv: Double, _ pv: Double) -> Double {
            let ratio: Double = cv / max(1, pv)
            return max(0, min(255, (v * pow(ratio, steps)).rounded()))
        }
        return KeeperRGB(r: ch(base.r, c.r, p.r), g: ch(base.g, c.g, p.g), b: ch(base.b, c.b, p.b))
    }

    // MARK: Drawing

    /// Draw the face, back to front, in art units (the caller sets the transform).
    static func draw(in ctx: inout GraphicsContext, face: KeeperFace, closure: [Double], color: KeeperRGB) {
        let plate = plateRGB(color)
        var shapes: [EyeShapes] = []
        for i in face.eyes.indices {
            let c: Double = i < closure.count ? closure[i] : 0
            shapes.append(eyeShapes(face.eyes[i], c))
        }
        let bagBody = shadeRGB(color, color, 1).color, bagPlate = shadeRGB(plate, color, 1).color
        let lidBody = shadeRGB(color, color, 1.3).color, lidPlate = shadeRGB(plate, color, 1.3).color
        for s in shapes {
            ctx.fill(s.bag, with: .color(bagBody))
            ctx.drawLayer { layer in
                layer.clip(to: plateArt)
                layer.fill(s.bag, with: .color(bagPlate))
            }
            ctx.fill(s.lid, with: .color(lidBody))
            ctx.drawLayer { layer in
                layer.clip(to: plateArt)
                layer.fill(s.lid, with: .color(lidPlate))
            }
        }
        let white = eyeWhite.color
        for s in shapes {
            ctx.fill(s.white, with: .color(white))
            ctx.fill(s.pupil, with: .color(pupil.color))
            if s.lashOpacity > 0.001 {
                ctx.stroke(s.lash, with: .color(white.opacity(s.lashOpacity)),
                           style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
            }
        }
        var brows = Path()
        for b in face.brows { brows.addPath(browPath(b)) }
        ctx.fill(brows, with: .color(browGrey.color))
        let m = face.mouth
        if m.oval < 0.999 {
            ctx.stroke(mouthStroke(m), with: .color(white.opacity(1 - m.oval)),
                       style: StrokeStyle(lineWidth: m.w, lineCap: .round, lineJoin: .round))
        }
        if m.oval > 0.01 {
            ctx.fill(mouthOval(m), with: .color(pupil.color.opacity(m.oval)))
        }
        if face.drop.on > 0.01 {
            ctx.fill(dropPath(face.drop), with: .color(white.opacity(face.drop.on)))
        }
    }
}

// MARK: - Shapes and the face layer

/// The chunky flame from the approved icon art, fitted as curves in viewBox
/// units (tip at y 4, widest at y 67.2, base at y 124) and scaled so the flame's
/// height fills the frame. The tip leans with the flicker and reacts to the face.
struct KeeperChunkyFlameShape: Shape {
    var flicker: Double
    var tip: KeeperTip

    var animatableData: Double {
        get { flicker }
        set { flicker = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let s: CGFloat = rect.height / 120
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.midX + CGFloat(x - 60) * s, y: rect.minY + CGFloat(y - 4) * s)
        }
        let lean: Double = (flicker - 0.5) * KeeperFaces.lean
        let tx: Double = 60 + lean + tip.dx, ty: Double = 4 + tip.dy
        let sh: Double = 43.986 * tip.sharp, sy: Double = 20.605 + tip.dy * 0.5, sl: Double = lean * 0.6
        var path = Path()
        path.move(to: p(60, 124))
        path.addCurve(to: p(16, 67.2), control1: p(37.084, 124), control2: p(16, 109.2))
        path.addCurve(to: p(tx, ty), control1: p(60 - sh + sl, sy), control2: p(tx, ty))
        path.addCurve(to: p(104, 67.2), control1: p(tx, ty), control2: p(60 + sh + sl, sy))
        path.addCurve(to: p(60, 124), control1: p(104, 109.2), control2: p(82.916, 124))
        path.closeSubpath()
        return path
    }
}

/// The inner flame (lighter core), in the same viewBox mapping as the flame.
struct KeeperPlateShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s: CGFloat = rect.height / 120
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.midX + CGFloat(x - 60) * s, y: rect.minY + CGFloat(y - 4) * s)
        }
        var path = Path()
        path.move(to: p(60, 53.5))
        path.addCurve(to: p(84, 88.5), control1: p(72.2, 60.6), control2: p(84, 68.8))
        path.addCurve(to: p(60, 119.2), control1: p(84, 108.4), control2: p(74.5, 119.2))
        path.addCurve(to: p(36, 88.5), control1: p(45.5, 119.2), control2: p(36, 108.4))
        path.addCurve(to: p(60, 53.5), control1: p(36, 68.8), control2: p(47.8, 60.6))
        path.closeSubpath()
        return path
    }
}

/// Paints one face frame. Fills the same frame as the flame shapes.
struct KeeperFaceCanvas: View {
    let face: KeeperFace
    let closure: [Double]
    let color: KeeperRGB

    var body: some View {
        Canvas { ctx, sz in
            let s: Double = Double(sz.height) / 120.0
            let m: Double = KeeperFaces.k * s
            let tx: Double = Double(sz.width) / 2 - 512 * m
            let ty: Double = -152 * m
            ctx.concatenate(CGAffineTransform(a: CGFloat(m), b: 0, c: 0, d: CGFloat(m), tx: CGFloat(tx), ty: CGFloat(ty)))
            KeeperFaces.draw(in: &ctx, face: face, closure: closure, color: color)
        }
    }
}

// MARK: - Animator

/// Picks the face from the game state and runs the change: blink, morph behind
/// the lids, pop open. Also eases the face's shading colour with the body.
/// Held in KeeperView's @State and stepped once per TimelineView frame.
final class KeeperFaceAnimator {
    struct Frame {
        let face: KeeperFace
        let closure: [Double]
        let pop: Double
        let name: KeeperFaceName
        let color: KeeperRGB
    }

    private var name: KeeperFaceName? = nil
    private var from: KeeperFace = KeeperFaces.sly
    private var to: KeeperFace = KeeperFaces.sly
    private var faceAt: Double = -100
    private var solvedAt: Double = -1e9
    private var lastMood: KeeperMood? = nil
    private var blinkAt: Double? = nil
    private var nextBlinkAt: Double = 0
    private var colorFrom = KeeperRGB.body(for: .idle)
    private var colorTo = KeeperRGB.body(for: .idle)
    private var colorAt: Double = -100

    private func color(at t: Double) -> KeeperRGB {
        KeeperRGB.mix(colorFrom, colorTo, max(0, min(1, (t - colorAt) / 0.5)))
    }

    func frame(t: Double, mood: KeeperMood, race: Bool, reduceMotion: Bool) -> Frame {
        if mood != lastMood {
            if mood == .celebrating { solvedAt = t }
            let target = KeeperRGB.body(for: mood)
            if lastMood == nil {
                colorFrom = target; colorTo = target; colorAt = t - 1
            } else {
                colorFrom = color(at: t); colorTo = target; colorAt = t
            }
            lastMood = mood
        }
        let want = KeeperFaces.faceFor(mood: mood, race: race, sinceSolved: t - solvedAt)
        if name == nil {
            name = want
            from = KeeperFaces.face(want)
            to = from
            faceAt = t - 10   // no pop on first appearance
            nextBlinkAt = t + Double.random(in: 2.2...4.5)
        } else if want != name {
            from = KeeperFaces.mix(from, to, KeeperFaces.swapMorph(t - faceAt))   // from wherever he is now
            to = KeeperFaces.face(want)
            name = want
            faceAt = t
            blinkAt = nil
            nextBlinkAt = t + 1.2 + Double.random(in: 2.2...4.5)
        }
        let e: Double = t - faceAt
        let u: Double = reduceMotion ? 1 : KeeperFaces.swapMorph(e)
        let face: KeeperFace = u >= 1 ? to : KeeperFaces.mix(from, to, u)
        let shut = face.eyes.allSatisfy { $0.closed > 0.99 }

        // Idle blinks: a random wait, then a quick shut and open (not while shut or changing faces).
        var blink: Double = 0
        if !reduceMotion && !shut && e > 0.6 {
            if blinkAt == nil && t >= nextBlinkAt { blinkAt = t }
            if let b = blinkAt {
                let be: Double = t - b
                blink = KeeperFaces.blinkAmount(be)
                if be >= 0.27 { blinkAt = nil; nextBlinkAt = t + Double.random(in: 2.2...4.5) }
            }
        }
        let swap: Double = reduceMotion ? 0 : KeeperFaces.swapBlink(e)
        let closure: [Double] = face.eyes.map { max($0.closed, blink, swap) }
        let current = name ?? want
        let strength: Double = current == .shocked ? 1.6 : 1
        let pop: Double = reduceMotion ? 0 : KeeperFaces.popEnvelope(e - 0.3) * strength
        return Frame(face: face, closure: closure, pop: pop, name: current, color: color(at: t))
    }
}
