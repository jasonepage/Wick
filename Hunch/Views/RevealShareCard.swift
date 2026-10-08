//
//  RevealShareCard.swift
//  Hunch
//
//  The Reveal, rendered to a flat image you can paste anywhere.
//
//  WHY THIS EXISTS
//  ---------------
//  `shareText()` produces the emoji grid, which is the share every guessing
//  game has had since Wordle — instantly legible, and instantly interchangeable
//  with a dozen other apps. The semantic map is the one artifact this game makes
//  that nothing else does, and until now it lived and died inside a sheet. This
//  file gets it out of the phone.
//
//  THE RULE IT MUST NOT BREAK
//  --------------------------
//  > **Shape crosses over. Content never does.**
//
//  The same rule Ghost Race is built on, and it matters more here: a share card
//  is seen by people who have not played today, and one legible guess label next
//  to the bullseye spoils the daily for everyone who scrolls past it. `RevealView`
//  deliberately labels the six hottest guesses and prints the answer at the
//  centre — that is correct for the player who has just finished, and completely
//  wrong for a public image.
//
//  So this card does not "remember not to draw the words": `Dot` has no `word`
//  field at all. The words are dropped at the initializer, one layer above the
//  drawing code, which makes a spoiler structurally impossible rather than a
//  thing a future edit has to be careful about. **Do not add a label field to
//  `Dot`.** If something seems to need one, it wants `RevealView`, not this.
//
//  SIZE
//  ----
//  360 × 450 pt at scale 3 = 1080 × 1350, which is the 4:5 portrait aspect that
//  survives Instagram, Messages and X previews without a centre crop. Colours are
//  hard-coded dark rather than environment-driven, so the rendered PNG is
//  identical regardless of the player's appearance setting — an ImageRenderer
//  picks up whatever environment it is handed, and a card that is sometimes
//  white and sometimes black is not a brand.
//

import SwiftUI
import UIKit

struct RevealShareCard: View {

    /// A plotted guess with the word REMOVED. See the file header — this
    /// omission is the feature.
    struct Dot: Identifiable {
        let id: Int
        let x: Double
        let y: Double
        let score: Double
    }

    let title: String       // "Wick #1359 🇩🇪 🎩"
    let stats: String       // "solved in 7 · 2 questions · 🔥2"
    let dots: [Dot]
    let solved: Bool
    let loc: Loc

    /// Drops the words on the way in.
    init(title: String, stats: String, points: [RevealPoint], solved: Bool, loc: Loc) {
        self.title = title
        self.stats = stats
        self.solved = solved
        self.loc = loc
        self.dots = points
            .filter { $0.score < 100 }      // the answer is the centre, not a dot
            .map { Dot(id: $0.index, x: $0.x, y: $0.y, score: $0.score) }
    }

    static let size = CGSize(width: 360, height: 450)

    private static let ink        = Color(red: 0.06, green: 0.07, blue: 0.10)
    private static let inkLift    = Color(red: 0.11, green: 0.10, blue: 0.15)
    private static let onInk      = Color(red: 0.95, green: 0.95, blue: 0.98)
    private static let onInkDim   = Color(red: 0.62, green: 0.62, blue: 0.70)

    /// Band ring radii as a fraction of the plot radius. These MUST stay in step
    /// with `RevealView.bands` and `RevealMap.radius(forScore:)`, or the rings on
    /// the shared image won't line up with the heat the player actually saw.
    private static let bands: [(fraction: CGFloat, color: Color)] = [
        (0.30, HunchTheme.Palette.boiling),
        (0.48, HunchTheme.Palette.hot),
        (0.64, HunchTheme.Palette.warm),
        (0.78, HunchTheme.Palette.cool),
        (0.90, HunchTheme.Palette.cold),
        (1.00, HunchTheme.Palette.freezing),
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Self.onInk)
                Text(stats)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HunchTheme.Palette.hot)
            }
            .padding(.top, 26)

            map
                .frame(width: 300, height: 300)
                .padding(.vertical, 8)

            VStack(spacing: 3) {
                Text(loc.revealCaption)
                    .font(.system(size: 11))
                    .foregroundStyle(Self.onInkDim)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text("guesswick.com")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(HunchTheme.Palette.keeper)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 22)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            LinearGradient(colors: [Self.ink, Self.inkLift],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: - The map

    private var map: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let plotR = side / 2 * 0.88

            ZStack {
                // Bands, drawn as filled discs from the outside in so each ring
                // reads as its own colour rather than as six overlapping strokes.
                ForEach(Self.bands.indices.reversed(), id: \.self) { i in
                    let r = plotR * Self.bands[i].fraction
                    Circle()
                        .fill(Self.bands[i].color.opacity(0.13))
                        .frame(width: r * 2, height: r * 2)
                        .position(center)
                }
                ForEach(Self.bands.indices, id: \.self) { i in
                    let r = plotR * Self.bands[i].fraction
                    Circle()
                        .stroke(Self.bands[i].color.opacity(0.32), lineWidth: 1)
                        .frame(width: r * 2, height: r * 2)
                        .position(center)
                }

                // The hunt, in guess order.
                Path { p in
                    let ordered = dots.sorted { $0.id < $1.id }
                    guard let first = ordered.first else { return }
                    p.move(to: screen(first, center, plotR))
                    for d in ordered.dropFirst() { p.addLine(to: screen(d, center, plotR)) }
                }
                .stroke(Self.onInk.opacity(0.28),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4]))

                ForEach(dots) { d in
                    let color = HunchTheme.color(for: d.score)
                    Circle()
                        .fill(color)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().strokeBorder(Self.ink.opacity(0.55), lineWidth: 2))
                        .position(screen(d, center, plotR))
                }

                centerMark(center: center, plotR: plotR)
            }
        }
    }

    /// The answer's place on the map — a mark, never the word.
    private func centerMark(center: CGPoint, plotR: CGFloat) -> some View {
        let tint = solved ? HunchTheme.Palette.solved : HunchTheme.Palette.neutral
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [tint.opacity(0.55), .clear],
                                     center: .center, startRadius: 0, endRadius: plotR * 0.20))
                .frame(width: plotR * 0.46, height: plotR * 0.46)
            Image(systemName: solved ? "flame.fill" : "questionmark")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(tint)
        }
        .position(center)
    }

    /// Unit disc (−1…1) → screen. SwiftUI's y grows downward and `RevealMap`
    /// puts the hottest guess at −π/2, so it lands at the top. Same as `RevealView`.
    private func screen(_ d: Dot, _ center: CGPoint, _ plotR: CGFloat) -> CGPoint {
        CGPoint(x: center.x + CGFloat(d.x) * plotR, y: center.y + CGFloat(d.y) * plotR)
    }
}

// MARK: - Rendering

extension RevealShareCard {
    /// Flattens the card to a PNG-backed `UIImage` for the share sheet.
    ///
    /// `ImageRenderer` is main-actor-only and runs synchronously; at 1080 × 1350
    /// that is a few milliseconds, so there is no need to push it off the tap.
    /// Returns nil if rendering fails, and every caller treats that as "share the
    /// text alone" rather than as an error worth showing anyone.
    @MainActor
    func rendered() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

#if DEBUG
#Preview {
    // Points built by hand rather than through `RevealMap.layout` — that call
    // takes a `similarity` closure and runs it from a nonisolated context, which
    // a main-actor `#Preview` body cannot supply without ceremony (see the note
    // in RevealView's preview). Fixed geometry is also a steadier preview.
    RevealShareCard(
        title: "Wick #1359",
        stats: "solved in 6 · 2 questions · 🔥2",
        points: [
            RevealPoint(index: 0, word: "", score: 78, radius: 0.24, angle: -1.57, x:  0.00, y: -0.24),
            RevealPoint(index: 1, word: "", score: 70, radius: 0.33, angle: -0.90, x:  0.21, y: -0.26),
            RevealPoint(index: 2, word: "", score: 52, radius: 0.46, angle:  0.60, x:  0.38, y:  0.26),
            RevealPoint(index: 3, word: "", score: 22, radius: 0.74, angle:  2.40, x: -0.55, y:  0.50),
            RevealPoint(index: 4, word: "", score:  6, radius: 0.93, angle:  3.60, x: -0.83, y: -0.41),
        ],
        solved: true,
        loc: Loc(lang: .english)
    )
}
#endif
