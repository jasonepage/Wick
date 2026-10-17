//
//  RevealView.swift
//  Hunch
//
//  "The Reveal" (3.2) — the post-round semantic map. The day's word sits at the
//  center of a bullseye; each guess is plotted by how close it came in MEANING
//  (distance from center = the warmth the player saw), with similar guesses
//  clustering by angle. The hunt animates inward in guess order.
//
//  Geometry + determinism live in RevealMap.swift (pure, unit-tested). This file is
//  purely presentation: it draws the RevealPoints RevealMap produces, using the same
//  hot/cold palette + bands as the board (HunchTheme). Reduce-Motion aware.
//
//  Wired: GameView.revealMapButton → showReveal → this view as a sheet, on both
//  the solved and gave-up cards. (This file carried a "needs wiring" DRAFT banner
//  through 3.2 long after it was wired — if you change the presentation, change
//  this line too.)
//

import SwiftUI

struct RevealView: View {
    let word: String
    let points: [RevealPoint]
    /// The round's language table. The map is post-round chrome, so it speaks
    /// whatever the round spoke.
    let loc: Loc
    /// Optional: number of guesses to solve, for the header ("You found X in N").
    var solvedInGuesses: Int? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    /// Drives the slow halo behind the word.
    @State private var pulse = false

    /// Concentric band rings, outer radius as a fraction of the plot radius. These
    /// fractions MUST match RevealMap.radius(forScore:) breakpoints so the rings line
    /// up with the heat bands the player saw on the board.
    /// `token` is the canonical HunchTheme band name, not a display string —
    /// it goes through `loc.heat` before it is drawn, so the rings read in the
    /// round's language and match the board.
    private struct Band { let fraction: CGFloat; let color: Color; let token: String }
    private let bands: [Band] = [
        Band(fraction: 0.30, color: HunchTheme.Palette.boiling,  token: "Boiling"),
        Band(fraction: 0.48, color: HunchTheme.Palette.hot,      token: "Hot"),
        Band(fraction: 0.64, color: HunchTheme.Palette.warm,     token: "Warm"),
        Band(fraction: 0.78, color: HunchTheme.Palette.cool,     token: "Cool"),
        Band(fraction: 0.90, color: HunchTheme.Palette.cold,     token: "Cold"),
        Band(fraction: 1.00, color: HunchTheme.Palette.freezing, token: "Freezing"),
    ]

    var body: some View {
        VStack(spacing: HunchTheme.Spacing.l) {
            if let n = solvedInGuesses {
                Text(loc.revealFound(word, n))
                    .font(HunchTheme.Fonts.cardTitle)
                    .multilineTextAlignment(.center)
            }

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let plotR = side / 2 * 0.86 // inset so the dots stay inside

                ZStack {
                    rings(center: center, plotR: plotR)
                    trail(center: center, plotR: plotR, size: geo.size)
                    dots(center: center, plotR: plotR)
                    labels(center: center, plotR: plotR, size: geo.size)
                    centerWord(center: center)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc.revealMapA11y + " " + loc.revealCaption)

            Button {
                replay()
            } label: {
                Label(loc.revealReplay, systemImage: "arrow.counterclockwise")
                    .font(HunchTheme.Fonts.label)
            }
            .buttonStyle(.bordered)
            .disabled(reduceMotion)

            Text(loc.revealCaption)
                .font(HunchTheme.Fonts.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(HunchTheme.Spacing.l)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                DispatchQueue.main.async { appeared = true }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
            }
        }
    }

    // MARK: - Layers

    /// A heat target: each band is a soft tinted disc, stacked outside in, so the
    /// middle glows hottest. Ring names sit on a diagonal at the lower left, on
    /// small pills, away from the hot cluster (which RevealMap puts at the top).
    private func rings(center: CGPoint, plotR: CGFloat) -> some View {
        ZStack {
            ForEach(Array(bands.indices.reversed()), id: \.self) { i in
                let r = plotR * bands[i].fraction
                Circle()
                    .fill(bands[i].color.opacity(0.07))
                    .overlay(Circle().stroke(bands[i].color.opacity(0.28), lineWidth: 1))
                    .frame(width: r * 2, height: r * 2)
                    .position(center)
            }
            ForEach(bands.indices, id: \.self) { i in
                // Each name sits just inside its own ring, on the lower-left diagonal.
                let r = plotR * bands[i].fraction - 9
                let a = Self.ringLabelAngle
                Text(loc.heat(bands[i].token).uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(bands[i].color)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color(.systemBackground).opacity(0.7), in: Capsule())
                    .fixedSize()
                    .position(x: center.x + r * cos(a), y: center.y + r * sin(a))
            }
        }
    }

    /// Lower left, in screen terms (y grows downward).
    private static let ringLabelAngle: CGFloat = .pi * 0.72

    /// The guesses that were the closest yet when they were made, in order: the
    /// actual route the player took in toward the word.
    private var trailPoints: [RevealPoint] {
        var best = -1.0
        var out: [RevealPoint] = []
        for p in points.sorted(by: { $0.index < $1.index }) where p.score < 100 {
            if p.score > best { out.append(p); best = p.score }
        }
        return out
    }

    private var trailIndices: Set<Int> { Set(trailPoints.map(\.index)) }

    /// One glowing, smoothed trail through every new "closest yet" guess, ending
    /// at the word when it was solved. Colored cold to hot along the way.
    private func trail(center: CGPoint, plotR: CGFloat, size: CGSize) -> some View {
        var pts = trailPoints.map { screen($0, center, plotR) }
        if solvedInGuesses != nil { pts.append(center) }
        let colors = trailPoints.map { HunchTheme.color(for: $0.score) }
            + (solvedInGuesses != nil ? [HunchTheme.Palette.solved] : [])
        let start = pts.first ?? center
        let end = pts.last ?? center
        let gradient = LinearGradient(
            colors: colors.count > 1 ? colors : [colors.first ?? .clear, colors.first ?? .clear],
            startPoint: UnitPoint(x: start.x / max(1, size.width), y: start.y / max(1, size.height)),
            endPoint: UnitPoint(x: end.x / max(1, size.width), y: end.y / max(1, size.height)))
        let shape = SmoothPath(points: pts)
        let progress: CGFloat = appeared ? 1 : 0
        let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: max(0.6, Double(pts.count) * 0.22))
        return ZStack {
            // Soft glow under the line.
            shape.trim(from: 0, to: progress)
                .stroke(gradient, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                .blur(radius: 7)
                .opacity(0.45)
            shape.trim(from: 0, to: progress)
                .stroke(gradient, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        .animation(animation, value: appeared)
        .allowsHitTesting(false)
    }

    private func dots(center: CGPoint, plotR: CGFloat) -> some View {
        let onTrail = trailIndices
        return ZStack {
            ForEach(points, id: \.index) { pt in
                if pt.score < 100 { // the solved word is drawn at the center, not as a dot
                    let pos = screen(pt, center, plotR)
                    let color = HunchTheme.color(for: pt.score)
                    let big = onTrail.contains(pt.index)
                    Circle()
                        .fill(color)
                        .frame(width: big ? 15 : 10, height: big ? 15 : 10)
                        .overlay(Circle().strokeBorder(Color.white.opacity(big ? 0.85 : 0.25), lineWidth: big ? 2 : 1))
                        .shadow(color: color.opacity(big ? 0.7 : 0.3), radius: big ? 6 : 2)
                        .opacity(big ? 1 : 0.7)
                        .position(pos)
                        .scaleEffect(appeared ? 1 : 0.1)
                        .opacity(appeared ? 1 : 0)
                        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.72).delay(Double(pt.index) * 0.05), value: appeared)
                        .accessibilityLabel(loc.revealGuessA11y(pt.index + 1,
                                                                pt.word,
                                                                loc.heat(HunchTheme.label(for: pt.score))))
                }
            }
        }
    }

    /// Words for the hottest guesses, placed so no two ever overlap: each tries
    /// above, below, right and left of its dot and is skipped if none fits. Every
    /// dot still has a VoiceOver label.
    private func labels(center: CGPoint, plotR: CGFloat, size: CGSize) -> some View {
        let placed = labelPlacements(center: center, plotR: plotR, size: size)
        return ZStack {
            ForEach(placed, id: \.point.index) { item in
                let color = HunchTheme.color(for: item.point.score)
                Text(item.point.word)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color(.systemBackground).opacity(0.78), in: Capsule())
                    .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 0.5))
                    .fixedSize()
                    .position(item.at)
                    .opacity(appeared ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(Double(item.point.index) * 0.05 + 0.2), value: appeared)
                    .accessibilityHidden(true)
            }
        }
        .allowsHitTesting(false)
    }

    private struct PlacedLabel { let point: RevealPoint; let at: CGPoint }

    private func labelPlacements(center: CGPoint, plotR: CGFloat, size: CGSize) -> [PlacedLabel] {
        let candidates = points.filter { $0.score < 100 }
            .sorted { $0.score > $1.score }
            .prefix(7)
        // The center word is off limits.
        var taken: [CGRect] = [CGRect(x: center.x - 50, y: center.y - 22, width: 100, height: 44)]
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
        var out: [PlacedLabel] = []
        for pt in candidates {
            let dot = screen(pt, center, plotR)
            let w = CGFloat(pt.word.count) * 6.3 + 12
            let h: CGFloat = 15
            let offsets = [CGPoint(x: 0, y: -15), CGPoint(x: 0, y: 15),
                           CGPoint(x: w / 2 + 10, y: 0), CGPoint(x: -(w / 2 + 10), y: 0)]
            for o in offsets {
                let c = CGPoint(x: dot.x + o.x, y: dot.y + o.y)
                let rect = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
                if bounds.contains(rect), !taken.contains(where: { $0.intersects(rect) }) {
                    taken.append(rect)
                    out.append(PlacedLabel(point: pt, at: c))
                    break
                }
            }
        }
        return out
    }

    /// The word on a solid disc (green when solved, grey after a give-up), with
    /// a slow breathing halo.
    private func centerWord(center: CGPoint) -> some View {
        let tint = solvedInGuesses != nil ? HunchTheme.Palette.solved : HunchTheme.Palette.neutral
        return ZStack {
            Capsule()
                .fill(tint.opacity(0.35))
                .frame(width: wordWidth + 22, height: 42)
                .blur(radius: 10)
                .scaleEffect(pulse ? 1.25 : 0.95)
            VStack(spacing: 0) {
                Text(word.uppercased())
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(loc.revealTheWord)
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(tint, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: tint.opacity(0.6), radius: 8)
        }
        .position(center)
        .accessibilityHidden(true)
    }

    private var wordWidth: CGFloat { CGFloat(word.count) * 10 + 10 }

    // MARK: - Helpers

    /// Map a RevealPoint on the unit disc (−1...1) to a screen point. Note SwiftUI's
    /// y grows downward, and RevealMap puts the hottest guess at angle −π/2 (y < 0),
    /// so it lands at the TOP — exactly what we want.
    private func screen(_ p: RevealPoint, _ center: CGPoint, _ plotR: CGFloat) -> CGPoint {
        CGPoint(x: center.x + CGFloat(p.x) * plotR, y: center.y + CGFloat(p.y) * plotR)
    }

    private func replay() {
        appeared = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true }
    }
}

/// A smooth line through `points`: each corner is rounded off with a quadratic
/// curve through the midpoints, so the trail reads as one sweeping route.
private struct SmoothPath: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        guard points.count > 1 else { return p }
        for i in 1..<points.count {
            let prev = points[i - 1]
            let cur = points[i]
            let mid = CGPoint(x: (prev.x + cur.x) / 2, y: (prev.y + cur.y) / 2)
            if i == 1 { p.addLine(to: mid) } else { p.addQuadCurve(to: mid, control: prev) }
        }
        p.addLine(to: points[points.count - 1])
        return p
    }
}

extension RevealView {
    /// Build straight from a finished round: words + scores + a pairwise similarity
    /// function (pass `engine.similarity`). Mirrors the single-player board's data.
    init(word: String,
         guesses: [(word: String, score: Double)],
         loc: Loc,
         solvedInGuesses: Int? = nil,
         similarity: (String, String) -> Double?) {
        self.init(
            word: word,
            points: RevealMap.layout(words: guesses.map { $0.word },
                                     scores: guesses.map { $0.score },
                                     similarity: similarity),
            loc: loc,
            solvedInGuesses: solvedInGuesses
        )
    }
}

#if DEBUG
private enum RevealPreviewData {
    // `nonisolated`: RevealMap.layout calls `similarity` synchronously from a
    // nonisolated context, so a main-actor-isolated helper cannot be passed to it
    // under Swift 6 concurrency. Both members are immutable and pure, so opting
    // them out of the actor is safe as well as necessary.
    nonisolated static let vecs: [String: [Double]] = [
        "flame": [1.0, 0.05, 0.02], "spark": [0.98, 0.10, 0.00], "coal": [0.90, 0.15, 0.05],
        "ocean": [0.02, 1.0, 0.10], "chair": [0.05, 0.10, 1.0], "ember": [0.99, 0.04, 0.03],
    ]
    nonisolated static func sim(_ a: String, _ b: String) -> Double? {
        guard let x = vecs[a], let y = vecs[b] else { return nil }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<min(x.count, y.count) { dot += x[i] * y[i]; na += x[i] * x[i]; nb += y[i] * y[i] }
        return (na == 0 || nb == 0) ? 0 : dot / (na.squareRoot() * nb.squareRoot())
    }
}

#Preview {
    RevealView(
        word: "ember",
        guesses: [("flame", 78), ("spark", 70), ("coal", 52), ("ocean", 6), ("chair", 4), ("ember", 100)],
        loc: Loc(lang: .english),
        solvedInGuesses: 6,
        similarity: RevealPreviewData.sim
    )
    .padding()
}
#endif
