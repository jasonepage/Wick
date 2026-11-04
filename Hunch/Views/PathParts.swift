// SPDX-License-Identifier: MPL-2.0
//
//  PathParts.swift
//  Hunch: Wick 3.9 Semantic Arena
//
//  The small pieces 3.9 adds to existing screens: the strategic signal under a
//  guess, a Path Report stat tile, and the race's two route comparison. All the
//  thinking is in RouteAnalysis.swift. These only draw what it decides.
//

import SwiftUI

/// Gold for text. The theme's coin gold is too pale to read on a light card.
private func goldInk(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? HunchTheme.Palette.coin : Color(red: 0.56, green: 0.38, blue: 0)
}

/// The look of the 3.9 surfaces: a game reward screen, with a bright face on a
/// darker lip and heavy rounded type. Scoped to these surfaces, so the rest of
/// Wick keeps its look.
enum PathStyle {
    static let face = Color(red: 0.49, green: 0.33, blue: 0.95)
    static let lip = Color(red: 0.30, green: 0.17, blue: 0.69)
    static let gold = Color(red: 1.0, green: 0.83, blue: 0.36)
    static let goldLip = Color(red: 0.79, green: 0.59, blue: 0.12)
    static let radius: CGFloat = 16
    static func font(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
}

extension View {
    /// A raised plate. The lip sits five points below, so leave room under it.
    func raisedPlate(face: Color = PathStyle.face, lip: Color = PathStyle.lip) -> some View {
        self
            .background(face, in: RoundedRectangle(cornerRadius: PathStyle.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: PathStyle.radius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: PathStyle.radius, style: .continuous)
                .fill(lip)
                .offset(y: 5))
    }
}

/// A chunky button that sinks into its lip when pressed.
struct RaisedButtonStyle: ButtonStyle {
    var face: Color = PathStyle.face
    var lip: Color = PathStyle.lip
    var ink: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PathStyle.font(17))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(face, in: RoundedRectangle(cornerRadius: PathStyle.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: PathStyle.radius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 2))
            .offset(y: configuration.isPressed ? 4 : 0)
            .background(RoundedRectangle(cornerRadius: PathStyle.radius, style: .continuous)
                .fill(lip)
                .offset(y: 5))
            .contentShape(RoundedRectangle(cornerRadius: PathStyle.radius, style: .continuous))
    }
}

/// One compact line under a guess's warmth: a glyph and a word, muted, with no
/// card around it. Breakthrough gets one restrained gold pulse, or a still gold
/// state under Reduce Motion. The parent gives it a new `id` per guess.
struct GuessSignalLine: View {
    let signal: RouteAnalysis.Signal
    let loc: Loc
    /// A big hit's gain. It stays here for anyone who misses the burst or has
    /// Reduce Motion on.
    var gain: Int? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var lit = false

    private var emphasis: RouteAnalysis.Emphasis {
        RouteAnalysis.emphasis(signal, reduceMotion: reduceMotion)
    }

    var body: some View {
        let gold = emphasis != .none
        HStack(spacing: 4) {
            Image(systemName: signal.symbol)
                .font(.caption2.weight(.black))
                .accessibilityHidden(true)
            Text(loc.key(signal.key) + (gain.map { " +\($0)\u{00B0}" } ?? ""))
                .font(PathStyle.font(13))
        }
        .foregroundStyle(gold ? AnyShapeStyle(goldInk(colorScheme))
                              : AnyShapeStyle(HierarchicalShapeStyle.secondary))
        .shadow(color: HunchTheme.Palette.coin.opacity(lit ? 0.7 : 0), radius: lit ? 6 : 0)
        .scaleEffect(lit ? 1.12 : 1)
        .onAppear {
            guard emphasis == .pulse else { return }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { lit = true }
            withAnimation(.easeIn(duration: 0.3).delay(0.18)) { lit = false }
        }
    }
}

/// A big jump's moment: the gain pops up and flies off the card, and the
/// biggest ones throw gold sparks. It only decorates, so it hides from VoiceOver
/// and draws nothing under Reduce Motion. The parent gives it a new `id` per guess.
struct HitFloat: View {
    let hit: RouteAnalysis.Hit

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 waiting, 1 popped in, 2 flying off.
    @State private var phase = 0

    private var size: CGFloat { hit.tier == 3 ? 50 : (hit.tier == 2 ? 42 : 32) }

    var body: some View {
        ZStack {
            if !reduceMotion {
                if hit.tier == 3 {
                    ForEach(0..<10, id: \.self) { i in
                        let angle = Double(i) / 10 * 2 * Double.pi
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(PathStyle.gold)
                            .frame(width: 10, height: 10)
                            .rotationEffect(.degrees(phase == 0 ? 0 : 160))
                            .offset(x: phase == 0 ? 0 : cos(angle) * 120, y: phase == 0 ? 0 : sin(angle) * 90)
                            .opacity(phase == 2 ? 0 : 1)
                    }
                }
                Text(verbatim: "+\(hit.gain)\u{00B0}")
                    .font(PathStyle.font(size))
                    .foregroundStyle(PathStyle.gold)
                    .shadow(color: PathStyle.lip, radius: 0, x: 0, y: 3)
                    .shadow(color: PathStyle.lip.opacity(0.8), radius: 3)
                    .scaleEffect(phase == 0 ? 0.5 : 1)
                    .offset(y: phase == 2 ? -70 : (phase == 1 ? -14 : 24))
                    .opacity(phase == 0 || phase == 2 ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { phase = 1 }
            try? await Task.sleep(for: .milliseconds(620))
            if Task.isCancelled { return }
            withAnimation(.easeIn(duration: 0.34)) { phase = 2 }
        }
    }
}

/// One Path Report stat: a label, a value and an optional small line.
struct PathStatTile: View {
    let title: String
    let value: String
    var detail: String? = nil
    var hasInfo = false

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Text(title.uppercased())
                    .font(PathStyle.font(10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if hasInfo {
                    Image(systemName: "info.circle")
                        .font(.caption2.weight(.heavy))
                }
            }
            .foregroundStyle(Color.white.opacity(0.88))
            Text(value)
                .font(PathStyle.font(20))
                .foregroundStyle(Color.white)
                .shadow(color: PathStyle.lip, radius: 0, x: 0, y: 2)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let detail {
                Text(detail)
                    .font(PathStyle.font(11))
                    .foregroundStyle(PathStyle.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 84)
        .raisedPlate()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, value, detail].compactMap { $0 }.joined(separator: ", "))
    }
}

/// Two miniature routes under the race recap, then one neutral sentence. It
/// shows bands, counts and a marker only: never a word or an exact opponent
/// score. An opponent has no Efficiency here, because the protocol hides the
/// guesses where they went colder.
struct PathComparisonCard: View {
    let comparison: RouteAnalysis.Comparison
    let opponentLabel: String
    let loc: Loc

    var body: some View {
        VStack(spacing: HunchTheme.Spacing.s) {
            Text(loc.key("pathCmpTitle").uppercased())
                .font(PathStyle.font(11))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            row(name: loc.raceSeatYou, seat: comparison.you)
            row(name: opponentLabel, seat: comparison.them)
            Text(loc.key(comparison.sentenceKey))
                .font(PathStyle.font(15))
                .multilineTextAlignment(.center)
        }
        .padding(HunchTheme.Spacing.m)
        .frame(maxWidth: .infinity)
        .background(PathStyle.face.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: PathStyle.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PathStyle.radius, style: .continuous)
            .strokeBorder(PathStyle.face.opacity(0.55), lineWidth: 3))
        .background(RoundedRectangle(cornerRadius: PathStyle.radius, style: .continuous)
            .fill(PathStyle.lip.opacity(0.4))
            .offset(y: 4))
    }

    private func row(name: String, seat: RouteAnalysis.ComparisonSeat) -> some View {
        HStack(spacing: HunchTheme.Spacing.s) {
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(PathStyle.font(13))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(verbatim: "\(loc.raceRecapGuesses) \(seat.guessCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 92, alignment: .leading)
            trail(seat)
            Spacer(minLength: 0)
            if let e = seat.efficiency {
                VStack(spacing: 0) {
                    Text(verbatim: "\(e)").font(PathStyle.font(17))
                    Text(loc.key("pathStatEfficiency"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 58)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voice(name: name, seat: seat))
    }

    /// Dots painted by band, with a gold ring on the best jump.
    private func trail(_ seat: RouteAnalysis.ComparisonSeat) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(seat.bands.enumerated()), id: \.offset) { i, band in
                if i > 0 {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 3, height: 1.5)
                }
                Circle()
                    .fill(HunchTheme.color(for: band.paintScore))
                    .frame(width: 11, height: 11)
                    .overlay {
                        if i == seat.jumpNode {
                            Circle()
                                .stroke(HunchTheme.Palette.coin, lineWidth: 2.5)
                                .frame(width: 17, height: 17)
                        }
                    }
            }
        }
    }

    private func voice(name: String, seat: RouteAnalysis.ComparisonSeat) -> String {
        var parts = [name, "\(loc.raceRecapGuesses) \(seat.guessCount)"]
        if let e = seat.efficiency { parts.append("\(loc.key("pathStatEfficiency")) \(e)") }
        parts.append(seat.bands.map { loc.key($0.key) }.joined(separator: ", "))
        return parts.joined(separator: ". ")
    }
}
