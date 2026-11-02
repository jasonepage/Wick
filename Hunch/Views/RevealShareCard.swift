//
//  RevealShareCard.swift
//  Hunch
//
//  The postable result card (3.8): the brand line, the guess count, the heat
//  trail, and the solved green Wick on the right. Same layout and copy as the
//  web card in wick-web/src/game/revealcard.ts.
//
//  THE RULE IT MUST NOT BREAK
//  --------------------------
//  > **Shape crosses over. Content never does.**
//
//  The card is seen by people who have not played today. It never carries the
//  word or a guess. It takes only numbers: how many guesses, and the warmth of
//  each one, oldest first. There is no field for a word, on purpose. If
//  something seems to need one, it wants RevealView, not this.
//
//  SIZE
//  ----
//  360 by 360 points at scale 3 = 1080 by 1080, square, so it survives Messages,
//  Instagram and X previews without a crop. Colours are hard coded dark so the
//  PNG is the same whatever the player's appearance setting.
//

import SwiftUI
import UIKit

/// One node of the heat trail: color, size and a ring that mark the band, so
/// the trail reads without color too. Same rule as heatTrail() on the web.
nonisolated struct HeatTrailNode: Equatable {
    let score: Double
    let band: Int        // 0 freezing ... 5 boiling, 6 the word
    var radius: Double { 5 + Double(band) * 1.3 }
    var ring: Bool { score >= 100 }

    static func band(for score: Double) -> Int {
        score >= 100 ? 6 : score >= 60 ? 5 : score >= 45 ? 4 : score >= 30 ? 3 : score >= 18 ? 2 : score >= 8 ? 1 : 0
    }

    /// Pick 5 to 8 nodes from the real guesses: the first, the last (always
    /// kept, so a solve ends green), and the ones between spread evenly. Fewer
    /// than eight guesses show as they are.
    static func trail(_ heat: [Double]) -> [HeatTrailNode] {
        var picked: [Double] = []
        if heat.count <= 8 {
            picked = heat
        } else {
            let n = 8
            for i in 0..<n {
                let idx = Int((Double(i) * Double(heat.count - 1) / Double(n - 1)).rounded())
                picked.append(heat[idx])
            }
            picked[n - 1] = heat[heat.count - 1]
        }
        return picked.map { HeatTrailNode(score: $0, band: band(for: $0)) }
    }
}

struct RevealShareCard: View {
    let brand: String        // "WICK DAILY #1436"
    let guesses: Int
    let solved: Bool
    let heat: [Double]       // every scored guess, oldest first, 0...100 (100 = the word)
    let loc: Loc

    static let size = CGSize(width: 360, height: 360)

    private static let margin: CGFloat = 360 * 0.08
    private static let brandInk = Color(red: 0.725, green: 0.659, blue: 1.0)
    private static let mainInk = Color(red: 1.0, green: 0.965, blue: 0.918)
    private static let softInk = Color(red: 0.851, green: 0.816, blue: 0.941)

    private var nodes: [HeatTrailNode] { HeatTrailNode.trail(heat) }

    var body: some View {
        let S = Self.size.width
        let m = Self.margin
        let textW = S * 0.44
        let wickSize = S * 0.50
        ZStack(alignment: .topLeading) {
            RadialGradient(colors: [Color(red: 0.165, green: 0.114, blue: 0.306), Color(red: 0.071, green: 0.047, blue: 0.133)],
                           center: UnitPoint(x: 0.72, y: 0.42), startRadius: 0, endRadius: S * 0.75)

            if solved {
                RadialGradient(colors: [HunchTheme.Palette.solved.opacity(0.45), HunchTheme.Palette.solved.opacity(0)],
                               center: .center, startRadius: 0, endRadius: wickSize * 0.7)
                    .frame(width: wickSize * 1.4, height: wickSize * 1.4)
                    .position(x: S - m - wickSize / 2 + 10, y: S * 0.24 + wickSize * 0.55)
            }

            // Copy block: the left 44 percent.
            VStack(alignment: .leading, spacing: 0) {
                Text(brand)
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(Self.brandInk)
                Group {
                    if solved {
                        Text("\(guesses) \(loc.cardGuesses)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                    } else {
                        Text(loc.cardUnsolved)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                    }
                }
                .foregroundStyle(Self.mainInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 8)
                Spacer()
            }
            .frame(width: textW, alignment: .leading)
            .padding(.leading, m)
            .padding(.top, m)

            trail(width: textW)
                .position(x: m + textW / 2, y: S * 0.56)

            VStack(alignment: .leading, spacing: 4) {
                Text(loc.cardTease)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Self.softInk)
                Text("guesswick.com")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(Self.brandInk)
            }
            .padding(.leading, m)
            .padding(.top, S - m - 34)

            // Wick, head only, green when solved and grey when not.
            KeeperStill(face: solved ? .sly : .calm,
                        color: solved ? KeeperRGB.body(for: .celebrating) : KeeperRGB.body(for: .defeated),
                        sparks: solved, size: wickSize)
                .frame(width: wickSize, height: wickSize * 128 / 120)
                .position(x: S - m - wickSize / 2 + 10, y: S * 0.24 + wickSize * 128 / 120 / 2)
        }
        .frame(width: S, height: S)
        .clipped()
    }

    /// The heat trail: nodes across the text column, joined by a faint line.
    private func trail(width: CGFloat) -> some View {
        let ns = nodes
        let cell: CGFloat = ns.count > 1 ? min(16.8, (width - 24) / CGFloat(ns.count - 1)) : 20
        let span: CGFloat = CGFloat(max(0, ns.count - 1)) * cell
        return ZStack(alignment: .leading) {
            if ns.count > 1 {
                Rectangle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: span, height: 1.2)
                    .offset(x: cell / 2)
            }
            HStack(spacing: 0) {
                ForEach(Array(ns.enumerated()), id: \.offset) { _, nd in
                    ZStack {
                        if nd.ring {
                            Circle()
                                .stroke(HunchTheme.color(for: nd.score), lineWidth: 1.2)
                                .frame(width: (nd.radius + 5) * 1.2, height: (nd.radius + 5) * 1.2)
                                .opacity(0.8)
                        }
                        Circle()
                            .fill(HunchTheme.color(for: nd.score))
                            .frame(width: nd.radius * 1.2, height: nd.radius * 1.2)
                    }
                    .frame(width: cell, height: 20)
                }
            }
        }
        .frame(width: width, height: 20, alignment: .leading)
    }

    /// ImageRenderer is main actor only and runs synchronously; at 1080 by 1080
    /// that is a few milliseconds. Returns nil if rendering fails, and every
    /// caller treats that as "share the text alone".
    @MainActor
    func rendered() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// Wick drawn once, no animation: the same flame, plate, sparks and face the
/// game draws, for a flat picture.
struct KeeperStill: View {
    let face: KeeperFaceName
    let color: KeeperRGB
    let sparks: Bool
    let size: CGFloat

    var body: some View {
        let f = KeeperFaces.face(face)
        let body = Color(red: color.r / 255, green: color.g / 255, blue: color.b / 255)
        ZStack {
            KeeperChunkyFlameShape(flicker: 0.5, tip: f.tip)
                .fill(body.opacity(0.30))
                .blur(radius: size * 0.10)
                .scaleEffect(1.12)
            KeeperChunkyFlameShape(flicker: 0.5, tip: f.tip)
                .fill(LinearGradient(colors: [body.opacity(0.92), body], startPoint: .top, endPoint: .bottom))
            KeeperPlateShape()
                .fill(Color.white.opacity(0.22))
            KeeperFaceCanvas(face: f, closure: f.eyes.map { $0.closed }, color: color)
            if sparks {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.10))
                        .foregroundStyle(HunchTheme.Palette.coin)
                        .offset(x: cos(Double(i) / 3 * 2 * .pi - 0.6) * size * 0.55,
                                y: sin(Double(i) / 3 * 2 * .pi - 0.6) * size * 0.55 - size * 0.05)
                }
            }
        }
        .frame(width: size, height: size * 128 / 120)
    }
}

#if DEBUG
#Preview {
    RevealShareCard(brand: "WICK DAILY #248", guesses: 7, solved: true,
                    heat: [3, 5, 9, 12, 20, 25, 33, 40, 48, 55, 61, 70, 100], loc: Loc(lang: .english))
}
#endif
