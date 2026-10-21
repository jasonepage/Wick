//
//  KeeperView.swift
//  Hunch
//
//  "Wick" — the Keeper mascot. A little flame spirit drawn entirely in
//  SwiftUI. His colour tracks the temperature of the game (icy blue when
//  you're freezing, blazing orange when you're hot, green when you solve it),
//  and he wears one of the Keeper's six faces (KeeperFace.swift): Sly when
//  cold, Flustered when close, Shocked when the word is cracked (he stays
//  Shocked and keeps blinking), Calm for the grey Wick,
//  Serious in a race, Focus while he answers a question. He changes faces with
//  a blink: the brows, mouth and flame tip morph while his eyes are shut.
//
//  UI-only: no game logic lives here.
//

import SwiftUI

// MARK: - Mood

enum KeeperMood: Equatable {
    case idle          // gentle bob, occasional blink
    case freezing      // shivering, squinting
    case cold          // slow bob, droopy
    case warm          // perked up
    case hot           // excited, fast flicker
    case boiling       // wide-eyed, shaking hard
    case thinking      // eyes drift up, slow sway
    case celebrating   // star eyes, bouncing
    case defeated      // dimmed, eyes closed
    case unamused      // deadpan "-_-" — e.g. an unknown word

    /// Map a closeness score (0...100) to a mood.
    static func forScore(_ score: Double) -> KeeperMood {
        switch score {
        case 100...:   return .celebrating
        case 60..<100: return .boiling
        case 45..<60:  return .hot
        case 30..<45:  return .warm
        case 18..<30:  return .cold
        default:       return .freezing
        }
    }

    var bodyColor: Color {
        switch self {
        case .idle, .thinking: return HunchTheme.Palette.keeper
        case .freezing:        return HunchTheme.Palette.freezing
        case .cold:            return HunchTheme.Palette.cold
        case .warm:            return HunchTheme.Palette.warm
        case .hot:             return HunchTheme.Palette.hot
        case .boiling:         return HunchTheme.Palette.boiling
        case .celebrating:     return HunchTheme.Palette.solved
        case .defeated:        return HunchTheme.Palette.neutral
        case .unamused:        return HunchTheme.Palette.keeper
        }
    }

    /// Bob cycle duration — faster when hotter.
    var bobPeriod: Double {
        switch self {
        case .boiling:                 return 0.55
        case .hot, .celebrating:       return 0.8
        case .warm:                    return 1.2
        case .idle, .thinking:         return 1.8
        case .cold:                    return 2.4
        case .freezing, .defeated:     return 2.8
        case .unamused:                return 2.2
        }
    }
}

// MARK: - Flame body shape

/// A teardrop / flame silhouette with a softly waving tip.
struct KeeperFlameShape: Shape {
    /// 0...1 phase of the flicker animation; the tip leans with it.
    var flicker: Double

    var animatableData: Double {
        get { flicker }
        set { flicker = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let lean = (flicker - 0.5) * 0.22 * w   // tip sways side to side
        var p = Path()
        // Bottom of the rounded body
        p.move(to: CGPoint(x: w * 0.5, y: h))
        // Left side up
        p.addCurve(to: CGPoint(x: w * 0.07, y: h * 0.52),
                   control1: CGPoint(x: w * 0.16, y: h * 0.98),
                   control2: CGPoint(x: w * 0.07, y: h * 0.78))
        // Left side toward the tip
        p.addCurve(to: CGPoint(x: w * 0.5 + lean, y: 0),
                   control1: CGPoint(x: w * 0.07, y: h * 0.22),
                   control2: CGPoint(x: w * 0.32 + lean * 0.6, y: h * 0.10))
        // Right side down from tip
        p.addCurve(to: CGPoint(x: w * 0.93, y: h * 0.52),
                   control1: CGPoint(x: w * 0.68 + lean * 0.6, y: h * 0.10),
                   control2: CGPoint(x: w * 0.93, y: h * 0.22))
        // Right side to bottom
        p.addCurve(to: CGPoint(x: w * 0.5, y: h),
                   control1: CGPoint(x: w * 0.93, y: h * 0.78),
                   control2: CGPoint(x: w * 0.84, y: h * 0.98))
        p.closeSubpath()
        return p
    }
}

// MARK: - Keeper view

struct KeeperView: View {
    /// The mascot's name, used in copy throughout the app.
    static let name = "Wick"

    var mood: KeeperMood = .idle
    var size: CGFloat = 84
    /// Called when the player pokes Wick — lets the parent react (e.g. a quip).
    var onPoke: (() -> Void)? = nil
    /// Dance to the race music when it plays (see WickDance). Only the live
    /// race screen sets this; everywhere else Wick just bobs.
    var dances: Bool = false
    /// Race mode: the Serious face. Defaults to on whenever he dances (the live race).
    var race: Bool? = nil

    /// Picks his face from the mood and runs the blink-and-morph between faces.
    @State private var animator = KeeperFaceAnimator()
    @State private var pokeStart: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Keep the timeline running even under Reduce Motion so the flame still
        // flickers in place (a subtle, non-vestibular motion). The larger
        // movements (bob, shiver, vibrate) are still suppressed below.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            // Reduce Motion: suppress ALL positional/scaling motion (vestibular-safe)
            // and keep Wick alive with a gentle opacity pulse only — Apple's
            // recommended substitute for motion (a cross-fade, not movement).
            let bob = reduceMotion ? 0 : sin(t * 2 * .pi / mood.bobPeriod) * bobAmplitude
            let shiver = (mood == .freezing && !reduceMotion) ? sin(t * 30) * 1.2 : 0
            // Boiling is a hard shake (jitter plus a little rotation), shared with the web.
            let shake = (mood == .boiling && !reduceMotion) ? WickDance.boilingShake(t: t, size: size) : .still
            // In a live race Wick dances to the music, locked to the beat the player hears.
            let dance = (dances && !reduceMotion) ? WickDance.move(for: RaceMusic.shared.pulse(), size: size) : .still
            // Hold the flame tip centered when Reduce Motion is on (no side-to-side sway).
            let flick = reduceMotion ? 0.5 : 0.5 + sin(t * 2 * .pi / (mood.bobPeriod * 0.8)) / 2
            // Subtle breathing scale only when motion is allowed.
            let breathe = reduceMotion ? 1 : 1 + sin(t * 2 * .pi / (mood.bobPeriod * 1.7)) * 0.03
            // Opacity-only "breath" under Reduce Motion so it reads as alive, not frozen.
            let glow = reduceMotion ? 0.86 + 0.14 * (sin(t * 2 * .pi / 2.4) + 1) / 2 : 1.0

            // Poke reaction: a quick springy squash-and-stretch that decays.
            let poke = pokeProgress(now: ctx.date)
            let pokeScale = reduceMotion ? 1 : 1 + poke * 0.20
            let pokeWiggle = reduceMotion ? 0 : poke * 6 * sin((pokeStart.map { ctx.date.timeIntervalSince($0) } ?? 0) * 34)

            // The face for this frame, and the pop as he opens on a new one
            // (squash and stretch, plus a little hop for Shocked).
            let face = animator.frame(t: t, mood: mood, race: race ?? dances, reduceMotion: reduceMotion)
            let popX: Double = 1 - 0.06 * face.pop
            let popY: Double = 1 + 0.10 * face.pop
            let hop: CGFloat = face.name == .shocked ? -size * 0.04 * CGFloat(face.pop) : 0

            keeperBody(flicker: flick, face: face)
                .scaleEffect(x: breathe * pokeScale * dance.scaleX * popX,
                             y: breathe * pokeScale * dance.scaleY * popY, anchor: .bottom)
                .rotationEffect(.degrees(pokeWiggle + shake.rotation + dance.rotation), anchor: .bottom)
                .offset(x: shiver + shake.x + dance.x, y: bob + shake.y + dance.y + hop)
                .opacity(glow)
                .shadow(color: mood.bodyColor.opacity(mood == .defeated ? 0 : 0.35),
                        radius: size * 0.12, y: size * 0.05)
        }
        .frame(width: size, height: size * 1.18)
        .contentShape(Rectangle())
        .onTapGesture { poke() }
        .accessibilityHidden(true)
    }

    /// 0...1 decaying envelope for the poke bounce (about 0.45s long).
    private func pokeProgress(now: Date) -> Double {
        guard let start = pokeStart else { return 0 }
        let e = now.timeIntervalSince(start)
        guard e >= 0, e < 0.45 else { return 0 }
        return cos(e / 0.45 * .pi / 2) * exp(-e * 5)   // quick rise already applied via scale; decays to 0
    }

    private func poke() {
        pokeStart = Date()
        Haptics.selection()
        onPoke?()
    }

    private var bobAmplitude: CGFloat {
        switch mood {
        case .celebrating: return size * 0.07
        case .defeated:    return size * 0.01
        default:           return size * 0.035
        }
    }

    // MARK: Body

    private func keeperBody(flicker: Double, face: KeeperFaceAnimator.Frame) -> some View {
        ZStack {
            // Soft glow
            KeeperChunkyFlameShape(flicker: flicker, tip: face.face.tip)
                .fill(mood.bodyColor.opacity(mood == .defeated ? 0.10 : 0.30))
                .blur(radius: size * 0.10)
                .scaleEffect(1.12)

            // Body: the chunky flame from the icon art
            KeeperChunkyFlameShape(flicker: flicker, tip: face.face.tip)
                .fill(
                    LinearGradient(
                        colors: [mood.bodyColor.opacity(0.92), mood.bodyColor],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Inner flame: one tone step lighter than the body (white at 22%)
            KeeperPlateShape()
                .fill(Color.white.opacity(0.22))

            // The face: brows, heavy lids, under-eye bags, eyes, mouth
            KeeperFaceCanvas(face: face.face, closure: face.closure, color: face.color)

            if mood == .celebrating {
                sparkles
            }
        }
        .animation(.easeInOut(duration: 0.5), value: mood)
    }

    private var sparkles: some View {
        // Driven by the animation timeline (not an .onAppear repeatForever), so it
        // reliably twinkles on device. Gentler under Reduce Motion, never frozen.
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let amp = reduceMotion ? 0.4 : 1.0
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    let phase = (sin(t * 2 * .pi / 0.6 - Double(i) * 0.75) + 1) / 2
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.10))
                        .foregroundStyle(HunchTheme.Palette.coin)
                        .offset(
                            x: cos(Double(i) / 5 * 2 * .pi) * size * 0.55,
                            y: sin(Double(i) / 5 * 2 * .pi) * size * 0.55 - size * 0.05
                        )
                        .opacity(0.25 + 0.75 * phase * amp)
                }
            }
        }
    }


}

// MARK: - Previews

#Preview("Moods") {
    ScrollView {
        let moods: [(String, KeeperMood)] = [
            ("Idle", .idle), ("Freezing", .freezing), ("Cold", .cold),
            ("Warm", .warm), ("Hot", .hot), ("Boiling", .boiling),
            ("Thinking", .thinking), ("Celebrating", .celebrating), ("Defeated", .defeated)
        ]
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 24) {
            ForEach(moods, id: \.0) { name, mood in
                VStack(spacing: 8) {
                    KeeperView(mood: mood, size: 72)
                    Text(name).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}
