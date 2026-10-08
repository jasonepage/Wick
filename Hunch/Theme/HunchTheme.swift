//
//  HunchTheme.swift
//  Hunch
//
//  Design system: semantic colors, spacing & type scales, reusable surfaces,
//  plus the hot/cold color + label mapping for closeness scores (0...100).
//  NOTE: thresholds are tuned for NLEmbedding cosine similarity * 100.
//

import SwiftUI
import UIKit

// MARK: - Design tokens

enum HunchTheme {

    // MARK: Palette

    /// Temperature ramp + supporting semantic colors.
    enum Palette {
        static let solved   = Color(red: 0.30, green: 0.62, blue: 0.28)   // verdant green
        static let boiling  = Color(red: 0.91, green: 0.26, blue: 0.21)   // ember red
        static let hot      = Color(red: 0.93, green: 0.42, blue: 0.18)   // coral
        static let warm     = Color(red: 0.95, green: 0.65, blue: 0.14)   // amber
        static let cool     = Color(red: 0.13, green: 0.63, blue: 0.55)   // teal
        static let cold     = Color(red: 0.35, green: 0.74, blue: 0.71)   // mint-teal
        static let freezing = Color(red: 0.27, green: 0.52, blue: 0.90)   // glacier blue

        static let coin     = Color(red: 0.93, green: 0.69, blue: 0.18)   // gold
        static let flame    = Color(red: 0.95, green: 0.45, blue: 0.12)   // streak orange
        static let keeper   = Color(red: 0.49, green: 0.36, blue: 0.92)   // keeper violet
        static let neutral  = Color(red: 0.45, green: 0.45, blue: 0.50)   // "won't say" gray
    }

    // MARK: Spacing scale

    enum Spacing {
        static let xs: CGFloat = 4
        static let s:  CGFloat = 8
        static let m:  CGFloat = 12
        static let l:  CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }

    // MARK: Corner radii

    enum Radius {
        static let chip: CGFloat = 10
        static let field: CGFloat = 14
        static let card: CGFloat = 20
        static let hero: CGFloat = 26
    }

    // MARK: Type scale (rounded display numbers, standard text elsewhere)

    enum Fonts {
        static let heroNumber = Font.system(size: 44, weight: .bold, design: .rounded)
        static let bigNumber  = Font.system(size: 30, weight: .bold, design: .rounded)
        static let revealWord = Font.system(size: 32, weight: .bold, design: .rounded)
        static let cardTitle  = Font.title3.weight(.semibold)
        static let label      = Font.subheadline.weight(.semibold)
        static let chip       = Font.subheadline.weight(.bold)
        static let caption    = Font.caption
    }

    // MARK: - Temperature mapping (score 0...100)

    static func color(for score: Double) -> Color {
        switch score {
        case 100...:   return Palette.solved
        case 60..<100: return Palette.boiling
        case 45..<60:  return Palette.hot
        case 30..<45:  return Palette.warm
        case 18..<30:  return Palette.cool
        case 8..<18:   return Palette.cold
        default:       return Palette.freezing
        }
    }

    static func label(for score: Double) -> String {
        switch score {
        case 100...:   return "Solved!"
        case 60..<100: return "Boiling"
        case 45..<60:  return "Hot"
        case 30..<45:  return "Warm"
        case 18..<30:  return "Cool"
        case 8..<18:   return "Cold"
        default:       return "Freezing"
        }
    }

    // MARK: - Rank (Contexto-style)

    static func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1:          return Palette.solved
        case 2...25:     return Palette.boiling
        case 26...100:   return Palette.hot
        case 101...400:  return Palette.warm
        case 401...1200: return Palette.cool
        default:         return Palette.freezing
        }
    }

    static func rankLabel(_ rank: Int) -> String {
        switch rank {
        case 1:          return "Solved!"
        case 2...25:     return "Boiling"
        case 26...100:   return "Hot"
        case 101...400:  return "Warm"
        case 401...1200: return "Cool"
        default:         return "Cold"
        }
    }

    /// Only reveal the exact rank number once a guess is this close or better.
    static let rankRevealThreshold = 100

    /// Compact label: the number once you're close, otherwise just the heat word.
    static func rankShortText(_ rank: Int) -> String {
        rank <= rankRevealThreshold ? "#\(rank)" : rankLabel(rank)
    }

    /// Emoji square for the shareable grid, by rank tier.
    static func rankSquare(_ rank: Int) -> String {
        switch rank {
        case 1:          return "🟩"
        case 2...25:     return "🟥"
        case 26...100:   return "🟧"
        case 101...400:  return "🟨"
        case 401...1200: return "🟩"
        default:         return "🟦"
        }
    }

    /// Bar/ring fill (0...1) for a rank, on a log scale so early progress shows.
    static func rankFill(_ rank: Int, maxRank: Int) -> Double {
        guard rank > 0, maxRank > 1 else { return 0 }
        if rank == 1 { return 1 }
        let f = 1.0 - (log(Double(rank)) / log(Double(maxRank)))
        return max(0.04, min(1.0, f))
    }

    /// Chip color for an Ask-the-Keeper verdict.
    static func verdictColor(_ verdict: String) -> Color {
        switch verdict.lowercased() {
        case "yes":     return Palette.solved
        case "no":      return Palette.boiling
        case "sort of": return Palette.warm
        case "idk":     return Palette.cool   // an honest "don't know" — calm, not a refusal
        default:        return Palette.neutral // Won't say
        }
    }

    /// A warm-as-you-get-closer background gradient driven by the best score so far.
    static func background(for bestScore: Double) -> LinearGradient {
        LinearGradient(
            colors: [color(for: bestScore).opacity(0.16), Color(.systemBackground)],
            startPoint: .top,
            endPoint: .center
        )
    }

    /// Emoji square used in the shareable result grid.
    static func square(for score: Double) -> String {
        switch score {
        case 100...:   return "🟩"
        case 60..<100: return "🟥"
        case 45..<60:  return "🟧"
        case 30..<45:  return "🟨"
        case 18..<30:  return "🟩"
        default:       return "🟦"
        }
    }
}

// MARK: - Layout helpers

extension View {
    /// Caps content to a comfortable reading width and centers it. Keeps cards,
    /// lists, and sheets from stretching edge-to-edge on iPad / wide windows.
    func readableWidth(_ maxWidth: CGFloat = 640) -> some View {
        self.frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}

// MARK: - Reusable surfaces & components

/// A soft card: subtle fill + hairline stroke instead of heavy opacity washes.
struct HunchCardModifier: ViewModifier {
    var tint: Color? = nil
    var radius: CGFloat = HunchTheme.Radius.card

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint.map { $0.opacity(0.08) } ?? Color(.secondarySystemBackground).opacity(0.9))
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder((tint ?? Color.primary).opacity(tint == nil ? 0.06 : 0.18), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    /// Standard card surface. Pass a tint for colored cards.
    func hunchCard(tint: Color? = nil, radius: CGFloat = HunchTheme.Radius.card) -> some View {
        modifier(HunchCardModifier(tint: tint, radius: radius))
    }
}

/// Compact capsule stat chip (streak, coins…).
struct HunchChip: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(HunchTheme.Fonts.chip)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.13), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.22), lineWidth: 1))
    }
}

/// Small colored verdict/status tag.
struct HunchTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }
}

/// A small upward-pointing triangle — the tail of Wick's speech bubble.
private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A speech bubble for the Keeper (Wick) — a little tail points up toward the
/// mascot so its lines read as the character talking to the player.
struct KeeperSpeech: View {
    let text: String
    var tint: Color = HunchTheme.Palette.keeper

    var body: some View {
        VStack(spacing: 0) {
            BubbleTail()
                .fill(tint.opacity(0.10))
                .frame(width: 18, height: 9)
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal, HunchTheme.Spacing.l)
                .padding(.vertical, HunchTheme.Spacing.m)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: HunchTheme.Radius.field, style: .continuous)
                        .fill(tint.opacity(0.10))
                    RoundedRectangle(cornerRadius: HunchTheme.Radius.field, style: .continuous)
                        .strokeBorder(tint.opacity(0.18), lineWidth: 1)
                }
        }
    }
}

/// Horizontal closeness meter used in guess rows.
struct ClosenessBar: View {
    let fill: Double   // 0...1
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.06))
                Capsule()
                    .fill(
                        LinearGradient(colors: [color.opacity(0.65), color],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(5, geo.size.width * CGFloat(min(1, max(0, fill)))))
            }
        }
        .frame(height: 7)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: fill)
    }
}
