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

nonisolated enum KeeperFaceName: String, CaseIterable {
    case sly, flustered, shocked, calm, serious, focus, warm, hot
}

/// One eye. lidL/lidR/sag: the heavy upper lid (y at its left and right ends,
/// and how far it sags in the middle). closed 1 = shut (Calm); bow and tilt
/// shape the shut lash line. pdx/pdy/pr: the pupil.
nonisolated struct KeeperEye {
    var cx, cy, rx, ry, lidL, lidR, sag, pdx, pdy, pr, closed, bow, tilt: Double
}

/// One sculpted purple brow. `c` is a cubic curve (x0, y0 ... x3, y3) from the
/// INNER end to the OUTER end. `hairs` positions two broad crown tufts
/// (t, height, lean); `tail` describes the restrained outer taper.
nonisolated struct KeeperBrow {
    var c: [Double]
    var th: Double
    var taper: Double
    var peak: Double
    var hairs: [Double]
    var tail: [Double]
}

/// The mouth: a white stroke through `pts` (x, y pairs), or (oval 1) the small dark "o".
nonisolated struct KeeperMouth {
    var pts: [Double]
    var w: Double
    var oval: Double
    var ocx: Double
    var ocy: Double
    var orx: Double
    var ory: Double
}

nonisolated struct KeeperDrop {
    var on, x, y, r, h, tilt: Double
}

/// The flame tip's reaction, in viewBox units: curl (Sly), droop (Flustered), spike (Shocked).
nonisolated struct KeeperTip {
    var dx, dy, sharp: Double
}

nonisolated struct KeeperFace {
    var eyes: [KeeperEye]
    var brows: [KeeperBrow]
    var mouth: KeeperMouth
    var drop: KeeperDrop
    var tip: KeeperTip
}

/// A colour as 0...255 channels, so the shading rule can do arithmetic on it.
nonisolated struct KeeperRGB: Equatable {
    var r: Double
    var g: Double
    var b: Double

    var color: Color { Color(red: r / 255, green: g / 255, blue: b / 255) }

    static func mix(_ a: KeeperRGB, _ b: KeeperRGB, _ u: Double) -> KeeperRGB {
        KeeperRGB(r: a.r + (b.r - a.r) * u, g: a.g + (b.g - a.g) * u, b: a.b + (b.b - a.b) * u)
    }

    /// Wick's body colour for a mood, as numbers. Same values as HunchTheme.Palette.
    @MainActor static func body(for mood: KeeperMood) -> KeeperRGB {
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

nonisolated enum KeeperFaces {
    private static func mouthLine(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, bend: Double, width: Double) -> KeeperMouth {
        var points: [Double] = []
        for i in 0...32 {
            let t = Double(i) / 32
            points += [x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + bend * 4 * t * (1 - t)]
        }
        return KeeperMouth(pts: points, w: width, oval: 0, ocx: 512, ocy: 712, orx: 18, ory: 23)
    }

    static let sly = KeeperFace(
        eyes: [
            KeeperEye(cx: 413.0, cy: 590.0, rx: 52.0, ry: 40.0, lidL: 584.0, lidR: 596.0, sag: 5.0, pdx: -18.0, pdy: 9.0, pr: 19.0, closed: 0.0, bow: 5.0, tilt: 0.0),
            KeeperEye(cx: 611.0, cy: 590.0, rx: 52.0, ry: 40.0, lidL: 596.0, lidR: 584.0, sag: 5.0, pdx: -18.0, pdy: 9.0, pr: 19.0, closed: 0.0, bow: 5.0, tilt: 0.0),
        ],
        brows: [
            KeeperBrow(c: [482.0, 554.0, 452.0, 538.0, 402.0, 510.0, 350.0, 494.0], th: 39.0, taper: 0.68, peak: 0.18,
                       hairs: [0.18, 10.0, 40.0, 0.47, 8.0, 55.0], tail: [6.0, 20.0, 5.0, 0.0, 0.0, 0.0]),
            KeeperBrow(c: [542.0, 554.0, 572.0, 536.0, 624.0, 506.0, 674.0, 490.0], th: 39.0, taper: 0.68, peak: 0.18,
                       hairs: [0.22, 9.0, 35.0, 0.4, 12.0, 45.0], tail: [18.0, 28.0, 6.0, -10.0, 18.0, 4.0]),
        ],
        mouth: KeeperMouth(pts: [
            561.68, 702.36, 558.58, 703.35, 555.46, 704.29, 552.32, 705.16, 549.18, 705.98, 546.02, 706.73,
            542.86, 707.42, 539.68, 708.04, 536.49, 708.6, 533.3, 709.09, 530.1, 709.51, 526.9, 709.85,
            523.68, 710.11, 520.46, 710.29, 517.25, 710.38, 514.03, 710.37, 510.81, 710.26, 507.59, 710.03,
            504.38, 709.68, 501.19, 709.21, 498.01, 708.58, 494.86, 707.8, 491.75, 706.86, 488.68, 705.72,
            485.67, 704.39, 482.73, 702.83, 479.9, 701.04, 477.2, 699.0, 474.63, 696.71, 472.26, 694.16,
            470.1, 691.37, 468.17, 688.35, 466.48, 685.14
        ], w: 21.0, oval: 0.0, ocx: 512.0, ocy: 712.0, orx: 18.0, ory: 23.0),
        drop: KeeperDrop(on: 0.0, x: 714.0, y: 560.0, r: 19.0, h: 50.0, tilt: -14.0),
        tip: KeeperTip(dx: -4.0, dy: 0.0, sharp: 0.92)   // curl
    )
    static let flustered = KeeperFace(
        eyes: [
            KeeperEye(cx: 413.0, cy: 590.0, rx: 53.0, ry: 41.0, lidL: 576.0, lidR: 594.0, sag: 4.0, pdx: -20.0, pdy: 10.0, pr: 20.0, closed: 0.0, bow: 5.0, tilt: 0.0),
            KeeperEye(cx: 611.0, cy: 586.0, rx: 53.0, ry: 41.0, lidL: 590.0, lidR: 574.0, sag: 4.0, pdx: -20.0, pdy: 10.0, pr: 20.0, closed: 0.0, bow: 5.0, tilt: 0.0),
        ],
        brows: [
            KeeperBrow(c: [484.0, 550.0, 452.0, 530.0, 402.0, 504.0, 352.0, 494.0], th: 39.0, taper: 0.7, peak: 0.18,
                       hairs: [0.15, 9.0, 30.0, 0.42, 7.0, 50.0], tail: [10.0, 18.0, 4.0, 0.0, 0.0, 0.0]),
            KeeperBrow(c: [540.0, 530.0, 574.0, 510.0, 624.0, 488.0, 674.0, 486.0], th: 39.0, taper: 0.7, peak: 0.18,
                       hairs: [0.25, 8.0, 40.0, 0.55, 9.0, 55.0], tail: [-4.0, 16.0, 4.0, 0.0, 0.0, 0.0]),
        ],
        mouth: mouthLine(478, 704, 548, 711, bend: 5, width: 19),
        drop: KeeperDrop(on: 0.55, x: 714.0, y: 560.0, r: 16.0, h: 42.0, tilt: -14.0),
        tip: KeeperTip(dx: 2.0, dy: -2.0, sharp: 0.88)   // hot, resisting reaction
    )
    static let shocked = KeeperFace(
        eyes: [
            KeeperEye(cx: 410.0, cy: 584.0, rx: 60.0, ry: 59.0, lidL: 526.0, lidR: 519.0, sag: 2.0, pdx: 12.0, pdy: -5.0, pr: 12.0, closed: 0.0, bow: 5.0, tilt: 0.0),
            KeeperEye(cx: 616.0, cy: 576.0, rx: 57.0, ry: 55.0, lidL: 518.0, lidR: 528.0, sag: 2.0, pdx: -10.0, pdy: 5.0, pr: 12.0, closed: 0.0, bow: 5.0, tilt: 0.0),
        ],
        brows: [
            KeeperBrow(c: [474.0, 480.0, 446.0, 438.0, 398.0, 420.0, 350.0, 442.0], th: 37.0, taper: 0.68, peak: 0.18,
                       hairs: [0.2, 8.0, 35.0, 0.5, 10.0, 50.0], tail: [14.0, 20.0, 5.0, 0.0, 0.0, 0.0]),
            KeeperBrow(c: [550.0, 466.0, 580.0, 424.0, 632.0, 412.0, 678.0, 444.0], th: 37.0, taper: 0.68, peak: 0.18,
                       hairs: [0.3, 11.0, 40.0, 0.58, 8.0, 55.0], tail: [20.0, 24.0, 5.0, -6.0, 14.0, 4.0]),
        ],
        mouth: KeeperMouth(pts: [
            512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0,
            512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0,
            512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0,
            512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0,
            512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0, 512.0, 712.0,
            512.0, 712.0, 512.0, 712.0, 512.0, 712.0
        ], w: 24.0, oval: 1.0, ocx: 516.0, ocy: 718.0, orx: 31.0, ory: 37.0),
        drop: KeeperDrop(on: 0.0, x: 714.0, y: 560.0, r: 19.0, h: 50.0, tilt: -14.0),
        tip: KeeperTip(dx: -1.0, dy: -6.0, sharp: 0.76)   // explosive spike
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
            KeeperEye(cx: 413.0, cy: 586.0, rx: 52.0, ry: 40.0, lidL: 588.0, lidR: 598.0, sag: 4.0, pdx: 19.0, pdy: 5.0, pr: 19.0, closed: 0.0, bow: 5.0, tilt: 0.0),
            KeeperEye(cx: 611.0, cy: 578.0, rx: 54.0, ry: 44.0, lidL: 568.0, lidR: 576.0, sag: 4.0, pdx: 19.0, pdy: 5.0, pr: 19.0, closed: 0.0, bow: 5.0, tilt: 0.0),
        ],
        brows: [
            KeeperBrow(c: [480.0, 548.0, 448.0, 542.0, 404.0, 540.0, 362.0, 544.0], th: 36.0, taper: 0.68, peak: 0.18,
                       hairs: [0.25, 10.0, 35.0, 0.52, 8.0, 50.0], tail: [4.0, 18.0, 4.0, 0.0, 0.0, 0.0]),
            KeeperBrow(c: [544.0, 522.0, 576.0, 496.0, 624.0, 486.0, 668.0, 500.0], th: 36.0, taper: 0.68, peak: 0.18,
                       hairs: [0.2, 8.0, 40.0, 0.48, 10.0, 45.0], tail: [14.0, 20.0, 5.0, 0.0, 0.0, 0.0]),
        ],
        mouth: mouthLine(490, 708, 542, 704, bend: 0, width: 18),
        drop: KeeperDrop(on: 0.0, x: 714.0, y: 560.0, r: 19.0, h: 50.0, tilt: -14.0),
        tip: KeeperTip(dx: 0.0, dy: 0.0, sharp: 1.0)   // neutral
    )
    static let calm = KeeperFace(
        eyes: [
            KeeperEye(cx: 413.0, cy: 590.0, rx: 52.0, ry: 39.0, lidL: 596.0, lidR: 600.0, sag: 5.0, pdx: -5.0, pdy: 12.0, pr: 18.0, closed: 0.0, bow: 8.0, tilt: 1.0),
            KeeperEye(cx: 611.0, cy: 590.0, rx: 52.0, ry: 39.0, lidL: 600.0, lidR: 596.0, sag: 5.0, pdx: -5.0, pdy: 12.0, pr: 18.0, closed: 0.0, bow: 8.0, tilt: -1.0),
        ],
        brows: [
            KeeperBrow(c: [478.0, 548.0, 448.0, 546.0, 404.0, 546.0, 362.0, 550.0], th: 34.0, taper: 0.7, peak: 0.18,
                       hairs: [0.2, 9.0, 35.0, 0.5, 8.0, 50.0], tail: [12.0, 20.0, 5.0, 0.0, 0.0, 0.0]),
            KeeperBrow(c: [546.0, 548.0, 576.0, 546.0, 620.0, 546.0, 662.0, 550.0], th: 34.0, taper: 0.7, peak: 0.18,
                       hairs: [0.25, 10.0, 40.0, 0.55, 8.0, 55.0], tail: [16.0, 24.0, 5.0, -8.0, 14.0, 4.0]),
        ],
        mouth: mouthLine(480, 710, 544, 712, bend: 0, width: 18),
        drop: KeeperDrop(on: 0.0, x: 714.0, y: 560.0, r: 19.0, h: 50.0, tilt: -14.0),
        tip: KeeperTip(dx: 0.0, dy: 0.0, sharp: 1.0)   // neutral
    )

    // Yellow: alert, inviting confidence.
    static let warm = KeeperFace(
        eyes: [
            KeeperEye(cx: 413, cy: 580, rx: 53, ry: 45, lidL: 570, lidR: 576, sag: 5, pdx: 10, pdy: 8, pr: 21, closed: 0, bow: 5, tilt: 0),
            KeeperEye(cx: 611, cy: 580, rx: 53, ry: 45, lidL: 576, lidR: 570, sag: 5, pdx: 10, pdy: 8, pr: 21, closed: 0, bow: 5, tilt: 0),
        ],
        brows: [
            KeeperBrow(c: [480, 520, 446, 506, 400, 500, 358, 510], th: 36, taper: 0.62, peak: 0.2, hairs: [], tail: []),
            KeeperBrow(c: [544, 516, 578, 500, 624, 494, 666, 504], th: 36, taper: 0.62, peak: 0.2, hairs: [], tail: []),
        ],
        mouth: mouthLine(468, 704, 558, 697, bend: 8, width: 21),
        drop: KeeperDrop(on: 0, x: 714, y: 560, r: 19, h: 50, tilt: -14),
        tip: KeeperTip(dx: -1.5, dy: -1, sharp: 0.96)
    )

    // Orange: locked-in determination.
    static let hot = KeeperFace(
        eyes: [
            KeeperEye(cx: 413, cy: 586, rx: 52, ry: 40, lidL: 578, lidR: 594, sag: 4, pdx: 6, pdy: 10, pr: 20, closed: 0, bow: 5, tilt: 0),
            KeeperEye(cx: 611, cy: 586, rx: 52, ry: 40, lidL: 594, lidR: 578, sag: 4, pdx: -6, pdy: 10, pr: 20, closed: 0, bow: 5, tilt: 0),
        ],
        brows: [
            KeeperBrow(c: [484, 552, 450, 536, 402, 512, 354, 492], th: 39, taper: 0.7, peak: 0.18, hairs: [], tail: []),
            KeeperBrow(c: [540, 552, 574, 536, 622, 510, 670, 488], th: 39, taper: 0.7, peak: 0.18, hairs: [], tail: []),
        ],
        mouth: mouthLine(474, 708, 550, 704, bend: -2, width: 20),
        drop: KeeperDrop(on: 0, x: 714, y: 560, r: 19, h: 50, tilt: -14),
        tip: KeeperTip(dx: 1.5, dy: -2, sharp: 0.88)
    )

    static func face(_ name: KeeperFaceName) -> KeeperFace {
        switch name {
        case .sly:       return sly
        case .flustered: return flustered
        case .shocked:   return shocked
        case .calm:      return calm
        case .serious:   return serious
        case .focus:     return focus
        case .warm:      return warm
        case .hot:       return hot
        }
    }

    /// Art units to viewBox units.
    static let k: Double = 120.0 / 718.0
    /// How far the flame tip leans across the full flicker, in viewBox units.
    static let lean: Double = 0.09 * 102.0

    static let eyeWhite = KeeperRGB(r: 245, g: 243, b: 254)
    static let pupil = KeeperRGB(r: 31, g: 23, b: 59)
    /// Keep Wick's brows in the same hue family as his current flame while
    /// making them dark enough to read as one strong graphic mask.
    static func browFill(_ c: KeeperRGB) -> KeeperRGB {
        KeeperRGB(r: c.r * 0.63, g: c.g * 0.63, b: c.b * 0.63)
    }

    static func browKey(_ c: KeeperRGB) -> KeeperRGB {
        let fill = browFill(c)
        return KeeperRGB(r: fill.r * 0.52, g: fill.g * 0.52, b: fill.b * 0.52)
    }

    // MARK: State to face

    /// Which face for the game's state. Solved stays Shocked (he keeps blinking).
    /// Thinking (an Ask Wick answer on its way) is Focus, except in a race,
    /// where a pending guess keeps the Serious race face.
    @MainActor static func faceFor(mood: KeeperMood, race: Bool) -> KeeperFaceName {
        switch mood {
        case .celebrating:
            return .shocked
        case .defeated, .unamused:
            return .calm
        case .thinking:
            return race ? .serious : .focus
        default:
            break
        }
        if race { return .serious }
        switch mood {
        case .freezing:                   return .serious
        case .cold:                       return .focus
        case .warm:                       return .warm
        case .hot:                        return .hot
        case .boiling:                    return .flustered
        default:                    return .sly
        }
    }

    // MARK: Timing (same as the web)

    /// The transition blink: shut in 90 ms, hold while the face morphs, open by 420 ms.
    /// 3.8 motion pass: closing 0 to 70 ms, shut 70 to 240 ms while the face
    /// and colour change behind the lids, open by 360 ms (wickface.ts swapBlink).
    static func swapBlink(_ e: Double) -> Double {
        if e < 0 { return 0 }
        if e < 0.07 { return e / 0.07 }
        if e < 0.24 { return 1 }
        if e < 0.36 { return 1 - (e - 0.24) / 0.12 }
        return 0
    }

    /// How far through the morph the brows, mouth and tip are.
    static func swapMorph(_ e: Double) -> Double {
        let x: Double = max(0, min(1, (e - 0.07) / 0.17))
        return x * x * (3 - 2 * x)
    }

    /// During the solved sequence the face changes without a blink (the shock
    /// must read first): a plain 160 ms morph.
    static func solveMorph(_ e: Double) -> Double {
        let x: Double = max(0, min(1, e / 0.16))
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

    /// A sleek brow built as one strong silhouette without loose hair texture.
    static func browPath(_ b: KeeperBrow) -> Path {
        let n = 64
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
            let smoothRise: Double = rise * rise * (3 - 2 * rise)
            let s1: Double = 0.96 + 0.12 * smoothRise
            let s2: Double = 1 - b.taper * 0.98 * pow(fall, 1.15)
            return th * s1 * s2
        }
        var top: [CGPoint] = [], bot: [CGPoint] = []
        for i in 0...n {
            let f = frame(i)
            let t: Double = Double(i) / Double(n)
            let w: Double = width(t) / 2
            let x = cen[i].0, y = cen[i].1
            top.append(pt(x + f.2 * w, y + f.3 * w))
            bot.append(pt(x - f.2 * w, y - f.3 * w))
        }
        let f0 = frame(0)
        let w0: Double = width(0) / 2
        let fn = frame(n)
        let wn: Double = width(1) / 2
        let outerTip = pt(cen[n].0 + fn.0 * wn * 0.9,
                          cen[n].1 + fn.1 * wn * 0.9)
        var cap: [CGPoint] = []
        for kk in 1..<20 {
            let a: Double = Double.pi * Double(kk) / 20
            cap.append(pt(cen[0].0 + f0.2 * w0 * cos(a) - f0.0 * w0 * sin(a),
                          cen[0].1 + f0.3 * w0 * cos(a) - f0.1 * w0 * sin(a)))
        }
        var path = Path()
        var outline: [CGPoint] = top
        outline.append(outerTip)
        outline.append(contentsOf: bot.reversed())
        outline.append(contentsOf: cap.reversed())
        path.move(to: outline[0])
        for q in outline.dropFirst() { path.addLine(to: q) }
        path.closeSubpath()

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
    @MainActor static func draw(in ctx: inout GraphicsContext, face: KeeperFace, closure: [Double], color: KeeperRGB) {
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
        ctx.stroke(brows, with: .color(browKey(color).color.opacity(0.72)),
                   style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
        ctx.fill(brows, with: .color(browFill(color).color))
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

/// The chunky flame from the approved icon art, fitted as curves in viewBox units.
struct KeeperChunkyFlameShape: Shape {
    var flicker: Double
    var tip: KeeperTip

    var animatableData: Double {
        get { flicker }
        set { flicker = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // Scale from width exactly like the web's 120-unit viewBox. The extra
        // frame height is breathing room, not a reason to widen his face.
        let s: CGFloat = rect.width / 120
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
        let s: CGFloat = rect.width / 120
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
            let s: Double = Double(sz.width) / 120.0
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
        /// 3.8: the flame's gradient while the colour travels up it.
        let bodyTop: KeeperRGB
        let bodyBottom: KeeperRGB
        /// 3.8: seconds since the last face or colour change began (nil long after).
        let transitionE: Double?
        /// 3.8: the solved sequence, when one is running.
        let solveScale: KeeperSolve.Scale
        let solveRing: KeeperSolve.Ring?
        let sparksOn: Bool
        /// The hit beat: hold every other motion still.
        let freeze: Bool
    }

    /// 3.8: when the solved sequence began. -infinity when the first mood seen
    /// was already celebrating (a reopened round), so the final pose shows at once.
    private var solvedAt: Double? = nil
    private var solveDoneFired = false
    var firstGuess = false

    /// Seconds into a running solved sequence, or nil.
    func solveElapsed(at t: Double) -> Double? {
        guard lastMood == .celebrating, let s = solvedAt, s.isFinite else { return nil }
        return t - s
    }

    /// Jump to the end of the sequence (the player tapped). The hit itself cannot
    /// be skipped. Returns true when a sequence was running.
    func settleSolve(at t: Double) -> Bool {
        guard let e = solveElapsed(at: t), e >= KeeperSolve.hit, e < KeeperSolve.done else { return false }
        solvedAt = t - KeeperSolve.done
        return true
    }

    /// True exactly once, on the first frame after the sequence has ended.
    func takeSolveDone(at t: Double, reduceMotion: Bool) -> Bool {
        guard !solveDoneFired, let e = solveElapsed(at: t) else { return false }
        let end: Double = reduceMotion ? KeeperSolve.rmDone : KeeperSolve.done
        guard e >= end else { return false }
        solveDoneFired = true
        return true
    }

    private var name: KeeperFaceName? = nil
    private var from: KeeperFace = KeeperFaces.sly
    private var to: KeeperFace = KeeperFaces.sly
    private var faceAt: Double = -100
    private var lastMood: KeeperMood? = nil
    private var blinkAt: Double? = nil
    private var nextBlinkAt: Double = 0
    private var colorFrom = KeeperRGB.body(for: .idle)
    private var colorTo = KeeperRGB.body(for: .idle)
    private var colorAt: Double = -100
    /// When the showcase started (the first frame), so it always opens on Sly.
    private var showcaseStart: Double? = nil
    /// Seconds on each face in the showcase.
    static let showcaseSeconds: Double = 5

    /// The colour at stop (top, middle, bottom) of the wipe, at time `t`.
    private func colors(at t: Double, rm: Bool) -> (top: KeeperRGB, mid: KeeperRGB, bottom: KeeperRGB) {
        let w = WickMotion.colorWipe(t - colorAt, rm: rm)
        return (KeeperRGB.mix(colorFrom, colorTo, w.top), KeeperRGB.mix(colorFrom, colorTo, w.mid),
                KeeperRGB.mix(colorFrom, colorTo, w.bottom))
    }

    func frame(t: Double, mood: KeeperMood, race: Bool, reduceMotion: Bool, showcase: Bool = false,
               override: KeeperFaceName? = nil) -> Frame {
        if mood != lastMood {
            let target = KeeperRGB.body(for: mood)
            if lastMood == nil {
                colorFrom = target; colorTo = target; colorAt = t - 10
            } else {
                colorFrom = colors(at: t, rm: reduceMotion).mid; colorTo = target; colorAt = t
            }
            // 3.8: entering the solved color starts the sequence; a Wick that
            // was born solved shows the final pose.
            if mood == .celebrating {
                solvedAt = lastMood == nil ? -Double.infinity : t
                solveDoneFired = lastMood == nil
            } else {
                solvedAt = nil
                solveDoneFired = false
            }
            lastMood = mood
        }
        let solveE: Double? = solveElapsed(at: t)
        var want: KeeperFaceName = override ?? KeeperFaces.faceFor(mood: mood, race: race)
        if mood == .celebrating, let sAt = solvedAt {
            // The sequence owns the face while it runs; afterwards he holds Sly.
            let e: Double = sAt.isFinite ? t - sAt : KeeperSolve.done + 1
            want = KeeperSolve.face(e, reduceMotion: reduceMotion, firstGuess: firstGuess)
        }
        // Showcase: walk through every face in order, one every few seconds.
        // Not with Reduce Motion on (the swaps would be instant jumps).
        if override == nil && showcase && !reduceMotion {
            let start: Double = showcaseStart ?? t
            showcaseStart = start
            let all: [KeeperFaceName] = KeeperFaceName.allCases
            let step: Int = Int((t - start) / Self.showcaseSeconds)
            want = all[step % all.count]
        }
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
        // 3.8: the solve outranks the transition: no blink, a fast plain morph.
        let solving: Bool = solveE.map { $0 < (reduceMotion ? KeeperSolve.rmDone : KeeperSolve.done) } ?? false
        let u: Double = reduceMotion ? 1 : (solving ? KeeperFaces.solveMorph(e) : KeeperFaces.swapMorph(e))
        let face: KeeperFace = u >= 1 ? to : KeeperFaces.mix(from, to, u)
        let shut = face.eyes.allSatisfy { $0.closed > 0.99 }
        // The transition is the latest face or colour change: one blink for both.
        let te: Double = t - max(faceAt, colorAt)

        // Idle blinks: a random wait, then a quick shut and open (not while shut or changing faces).
        var blink: Double = 0
        if !reduceMotion && !shut && te > 0.6 {
            if blinkAt == nil && t >= nextBlinkAt { blinkAt = t }
            if let b = blinkAt {
                let be: Double = t - b
                blink = KeeperFaces.blinkAmount(be)
                if be >= 0.27 { blinkAt = nil; nextBlinkAt = t + Double.random(in: 2.2...4.5) }
            }
        }
        let swap: Double = (reduceMotion || solving) ? 0 : KeeperFaces.swapBlink(te)
        let closure: [Double] = face.eyes.map { max($0.closed, blink, swap) }
        let current = name ?? want
        // The pop is now the director's transition silhouette (WickMotion).
        let pop: Double = 0
        let sScale: KeeperSolve.Scale = (solveE != nil && !reduceMotion) ? KeeperSolve.scale(solveE!) : KeeperSolve.Scale(sx: 1, sy: 1)
        let sRing: KeeperSolve.Ring? = solveE.flatMap { KeeperSolve.ring($0, reduceMotion: reduceMotion) }
        let sparks: Bool = solveE.map { KeeperSolve.sparks($0, reduceMotion: reduceMotion) } ?? true
        let freeze: Bool = (solveE != nil && !reduceMotion) ? solveE! < KeeperSolve.hit : false
        let cs = colors(at: t, rm: reduceMotion)
        let transitionE: Double? = (te >= 0 && te < 2) ? te : nil
        return Frame(face: face, closure: closure, pop: pop, name: current, color: cs.mid,
                     bodyTop: cs.top, bodyBottom: cs.bottom, transitionE: transitionE,
                     solveScale: sScale, solveRing: sRing, sparksOn: sparks, freeze: freeze)
    }
}


// MARK: - 3.8: the solved sequence "You got me"

/// Five beats, 1.8 seconds, the same numbers as wickface.ts (SOLVE_*).
///   hit        0.00 to 0.12  freeze, Shocked
///   disbelief  0.12 to 0.42  green, Shocked
///   release    0.42 to 0.82  compress then rebound to 1.08, one ring, sparks
///   recovery   0.82 to 1.28  Sly: the reluctant impressed look
///   button     1.28 to 1.80  hold green Sly, normal blinks
/// A first-guess solve holds Shocked longer (firstHold).
nonisolated enum KeeperSolve {
    static let hit: Double = 0.12
    static let disbelief: Double = 0.42
    static let release: Double = 0.82
    static let recovery: Double = 1.28
    static let done: Double = 1.8
    static let firstHold: Double = 0.5
    /// Reduced Motion: a crossfade to green Shocked, one ring fades, then Sly.
    static let rmSwap: Double = 0.4
    static let rmDone: Double = 0.8
    static let rebound: Double = 1.08

    struct Scale: Equatable { var sx: Double; var sy: Double }
    struct Ring: Equatable { var r: Double; var opacity: Double; var mix: Double }

    /// The face Wick wears `e` seconds into the sequence.
    static func face(_ e: Double, reduceMotion: Bool, firstGuess: Bool = false) -> KeeperFaceName {
        if reduceMotion { return e < rmSwap ? .shocked : .sly }
        let swap: Double = release + (firstGuess ? firstHold : 0)
        return e < swap ? .shocked : .sly
    }

    /// Squash and rebound during the release beat.
    static func scale(_ e: Double) -> Scale {
        if e < disbelief || e >= release { return Scale(sx: 1, sy: 1) }
        let u: Double = (e - disbelief) / (release - disbelief)
        if u < 0.3 {
            let k: Double = u / 0.3
            return Scale(sx: 1 + 0.06 * k, sy: 1 - 0.10 * k)
        }
        if u < 0.65 {
            let k: Double = (u - 0.3) / 0.35
            return Scale(sx: 1.06 - 0.10 * k, sy: 0.90 + (rebound - 0.90) * k)
        }
        let k: Double = (u - 0.65) / 0.35
        return Scale(sx: 0.96 + 0.04 * k, sy: rebound - (rebound - 1) * k)
    }

    /// The one ring: radius as a factor of Wick's size, opacity, and the mix
    /// from violet (0) to solved green (1). Nil outside the release beat.
    static func ring(_ e: Double, reduceMotion: Bool) -> Ring? {
        if reduceMotion {
            let start: Double = rmSwap * 0.5
            if e < start || e >= rmDone { return nil }
            let u: Double = (e - start) / (rmDone - start)
            return Ring(r: 0.75, opacity: 0.5 * sin(u * .pi), mix: u)
        }
        if e < disbelief || e >= release { return nil }
        let u: Double = (e - disbelief) / (release - disbelief)
        return Ring(r: 0.55 + 0.6 * u, opacity: 0.7 * (1 - u), mix: u)
    }

    /// The gold sparks show from the release beat on.
    static func sparks(_ e: Double, reduceMotion: Bool) -> Bool {
        reduceMotion ? e >= rmSwap : e >= disbelief
    }
}
