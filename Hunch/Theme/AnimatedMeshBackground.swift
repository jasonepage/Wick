//
//  AnimatedMeshBackground.swift
//  Hunch
//
//  The living mesh behind the Home hub — and, since 3.2, a TEMPERATURE display
//  rather than decoration.
//
//  HISTORY, because this has now gone both ways and the next person deserves to
//  know why. 3.2 coupled the mesh to the round's warmth — "Home is as warm as you
//  are" — mirroring `HunchTheme.background(for:)` on the board and the `.heat`
//  wash on web. It was reverted: at a solved round the blend pulled every point
//  up to 84% of the way to one band colour and the whole hub flooded green,
//  swallowing the mode cards (which are a 12% tint of their own hue) until
//  Practice and Wardrobe were unreadable.
//
//  So `score` now defaults to 0 and **Home passes nothing**, which renders the
//  resting rainbow and only the resting rainbow. The blend machinery below is
//  kept because it is correct and was expensive to tune — if a future surface
//  wants a warmth-reactive mesh it is ready — but the hub is a front door, not a
//  readout. Temperature belongs on the board, where one reading is the point.
//
//  Deliberately pastel and gentle so the cards stay readable, and it never tires
//  the eye. Honors Reduce Motion by holding the mesh still (it still looks nice,
//  it just doesn't move).
//

import SwiftUI
import UIKit

struct AnimatedMeshBackground: View {
    /// Warmth to lean the mesh toward, 0...100. **Home deliberately leaves this
    /// at 0**, which renders the resting palette unchanged — see the file header.
    /// Non-zero is currently unused by any caller.
    var score: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The resting wash — UNCHANGED from the original Home mesh: icy blue →
    /// lavender → mint → amber → peach → coral → violet. An untouched Home should
    /// still look like the app's front door, chromatic and inviting; it is a hub,
    /// not a readout, until there is something to read out.
    ///
    /// The temperature is what MOVES it. As the round warms, every point leans
    /// toward the band colour, so the rainbow collapses toward a single hue the
    /// closer you get — chromatic at rest, one colour when you're boiling.
    private let restingColors: [Color] = [
        Color(red: 0.80, green: 0.87, blue: 0.98),  // icy blue
        Color(red: 0.88, green: 0.85, blue: 0.98),  // lavender
        Color(red: 0.80, green: 0.93, blue: 0.90),  // mint teal
        Color(red: 0.99, green: 0.93, blue: 0.82),  // amber
        Color(red: 0.99, green: 0.90, blue: 0.86),  // peach
        Color(red: 0.82, green: 0.92, blue: 0.92),  // cool teal
        Color(red: 0.99, green: 0.88, blue: 0.83),  // coral
        Color(red: 0.98, green: 0.92, blue: 0.84),  // warm amber
        Color(red: 0.90, green: 0.87, blue: 0.99),  // soft violet
    ]

    /// How far each mesh point leans into the heat colour at full warmth. Uneven
    /// on purpose: a uniform blend would flatten the mesh into a single sheet of
    /// colour and lose the drift entirely.
    private let lean: [Double] = [0.33, 0.66, 0.45, 0.78, 0.54, 0.39, 0.84, 0.48, 0.60]

    private var colors: [Color] {
        // 0 → resting palette exactly; 100 → each point pulled `lean` of the way
        // to the band colour.
        //
        // LINEAR, not eased. An earlier draft squared this to keep early guesses
        // quiet, and it flattened the whole middle: Warm and Hot were a 5% tint,
        // visually identical to Cold, and the screen only came alive at Boiling.
        // Rendering every band side by side is what caught it — the curve looked
        // reasonable written down and was useless on screen.
        let t = min(max(score / 100, 0), 1)
        guard t > 0.001 else { return restingColors }
        let intensity = t
        // Saturate the band colour BEFORE mixing. Dropping a band colour straight
        // into a pastel is what made Warm come out tan rather than yellow: the mix
        // halves the saturation, and amber at half saturation is sand. Pushing
        // saturation up first means each band survives the blend as itself —
        // Warm reads yellow, Hot orange, Boiling red.
        let heat = Self.vivid(HunchTheme.color(for: score))
        return zip(restingColors, lean).map { base, l in
            Self.blend(base, heat, min(1, l) * intensity)
        }
    }

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { ctx in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    MeshGradient(width: 3, height: 3, points: points(t), colors: colors)
                        .ignoresSafeArea()
                }
            } else {
                // Pre-iOS 18: no MeshGradient — a soft static wash in the same
                // palette, so Home still warms, just without the drift.
                LinearGradient(colors: [colors[0], colors[4], colors[6]],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            }
        }
        // Matches the board's 0.6s ease, so walking Home after a good guess feels
        // like the same room getting warmer rather than a different screen.
        .animation(.easeInOut(duration: 0.6), value: score)
    }

    /// A more saturated version of a band colour, for mixing into pastel. The
    /// board uses `HunchTheme.color(for:)` unchanged — this is a local adjustment
    /// for THIS blend, not a redefinition of the palette.
    private static func vivid(_ c: Color) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(c).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return c }
        return Color(hue: Double(h), saturation: Double(min(1, s * 1.45)), brightness: Double(min(1, b * 1.03)))
    }

    /// Linear blend in sRGB. `Color.mix(with:by:)` would do this in one line but
    /// is iOS 18+, and this view still has to render on 17.
    private static func blend(_ a: Color, _ b: Color, _ amount: Double) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(a).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(b).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(min(max(amount, 0), 1))
        return Color(red: Double(r1 + (r2 - r1) * t),
                     green: Double(g1 + (g2 - g1) * t),
                     blue: Double(b1 + (b2 - b1) * t))
    }

    /// Corners stay pinned; edge midpoints drift along their free axis and the
    /// center drifts on both — so the mesh morphs without tearing at the edges.
    private func points(_ t: Double) -> [SIMD2<Float>] {
        let a: Float = 0.10
        let s  = Float(sin(t * 0.25))
        let c  = Float(cos(t * 0.20))
        let s2 = Float(sin(t * 0.17))
        let c2 = Float(cos(t * 0.23))
        return [
            [0, 0],            [0.5 + a * s, 0],              [1, 0],
            [0, 0.5 + a * c],  [0.5 + a * s2, 0.5 + a * c2],  [1, 0.5 - a * s],
            [0, 1],            [0.5 - a * c2, 1],             [1, 1],
        ]
    }
}
