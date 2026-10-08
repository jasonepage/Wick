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
                let plotR = side / 2 * 0.82 // inset so ring labels + dots stay inside

                ZStack {
                    rings(center: center, plotR: plotR)
                    coreGlow(center: center, plotR: plotR)
                    path(center: center, plotR: plotR)
                    dots(center: center, plotR: plotR)
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
        .onAppear { appeared = reduceMotion ? true : false; if !reduceMotion { DispatchQueue.main.async { appeared = true } } else { appeared = true } }
    }

    // MARK: - Layers

    private func rings(center: CGPoint, plotR: CGFloat) -> some View {
        ZStack {
            ForEach(bands.indices, id: \.self) { i in
                let r = plotR * bands[i].fraction
                Circle()
                    .stroke(bands[i].color.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                    .frame(width: r * 2, height: r * 2)
                    .position(center)
                Text(loc.heat(bands[i].token).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(bands[i].color.opacity(0.7))
                    .position(x: center.x, y: center.y - r + 8)
            }
        }
    }

    private func coreGlow(center: CGPoint, plotR: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [HunchTheme.Palette.solved.opacity(0.5), .clear],
                                 center: .center, startRadius: 0, endRadius: plotR * 0.22))
            .frame(width: plotR * 0.5, height: plotR * 0.5)
            .position(center)
    }

    private func path(center: CGPoint, plotR: CGFloat) -> some View {
        Path { p in
            let ordered = points.sorted { $0.index < $1.index }
            guard let first = ordered.first else { return }
            p.move(to: screen(first, center, plotR))
            for pt in ordered.dropFirst() { p.addLine(to: screen(pt, center, plotR)) }
        }
        .trim(from: 0, to: appeared ? 1 : 0)
        .stroke(Color.primary.opacity(0.22), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 5]))
        .animation(reduceMotion ? nil : .easeInOut(duration: max(0.4, Double(points.count) * 0.09)), value: appeared)
    }

    /// Only the hottest handful of guesses get a text label — otherwise the tight hot
    /// cluster becomes an unreadable pile. Every dot still has a tap/VoiceOver label.
    private var labeledIndices: Set<Int> {
        Set(points.filter { $0.score < 100 }
                  .sorted { $0.score > $1.score }
                  .prefix(6)
                  .map(\.index))
    }

    private func dots(center: CGPoint, plotR: CGFloat) -> some View {
        ZStack {
            ForEach(points, id: \.index) { pt in
                if pt.score < 100 { // the solved word is drawn at the center, not as a dot
                    let pos = screen(pt, center, plotR)
                    let color = HunchTheme.color(for: pt.score)
                    ZStack {
                        Circle()
                            .fill(color)
                            .frame(width: 15, height: 15)
                            .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 2))
                            .shadow(color: color.opacity(0.5), radius: 4)
                        if labeledIndices.contains(pt.index) {
                            Text(pt.word)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(color)
                                .offset(y: -16)
                                .fixedSize()
                        }
                    }
                    .position(pos)
                    .scaleEffect(appeared ? 1 : 0.1)
                    .opacity(appeared ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.72).delay(Double(pt.index) * 0.09), value: appeared)
                    .accessibilityLabel(loc.revealGuessA11y(pt.index + 1,
                                                            pt.word,
                                                            loc.heat(HunchTheme.label(for: pt.score))))
                }
            }
        }
    }

    private func centerWord(center: CGPoint) -> some View {
        VStack(spacing: 1) {
            Text(word.uppercased())
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(HunchTheme.Palette.solved)
            Text(loc.revealTheWord)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .position(center)
    }

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
