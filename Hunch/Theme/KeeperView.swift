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

extension KeeperMood {
    /// The motion director's mood (WickMotion.Mood). The deadpan moods share
    /// the grey "deflate" body language.
    var motionMood: WickMotion.Mood {
        switch self {
        case .idle, .thinking: return .idle
        case .freezing:        return .freezing
        case .cold:            return .cold
        case .warm:            return .warm
        case .hot:             return .hot
        case .boiling:         return .boiling
        case .celebrating:     return .celebrating
        case .defeated, .unamused: return .grey
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
    /// Authored choreography clip and blend strength. The game defaults to the
    /// confident swagger; the web motion studio can audition the same set.
    var danceStyle: WickDance.Style = .swagger
    var danceIntensity: Double = 1
    /// Race mode: the Serious face. Defaults to on whenever he dances (the live race).
    var race: Bool? = nil
    /// Show off every face: a new one every few seconds, with the usual blink
    /// between them (3.7). The Home screen and the round's welcome card use it.
    var showcase: Bool = false
    /// Brief personality performance layered over the heat-driven face.
    var faceOverride: KeeperFaceName? = nil
    /// Bump this to make Wick bounce without a tap (a reaction's poke).
    /// No haptic and no quip: those belong to a real tap.
    var pokeTick: Int = 0
    /// 3.8: the solve was the first guess, so Shocked holds a little longer.
    var firstGuess: Bool = false
    /// 3.8: called once when the solved sequence ends; true when the player
    /// skipped it with a tap. Not called for a round that opens already solved.
    var onSolveDone: ((Bool) -> Void)? = nil
    /// 3.8 motion: bump to play a reaction clip (a scored guess, a personality
    /// beat, an Ask Wick answer). `cueKind` is a WickReactionKind raw value,
    /// "question", or nil for a plain guess. The first value is not cued.
    var cue: Int = 0
    var cueKind: String? = nil
    /// 3.8 typing awareness: the guess field's focus, and a counter that
    /// changes on each keystroke.
    var inputFocused: Bool = false
    var typingTick: Int = 0
    /// 3.8 Race Showdown: a fixed pose added on top of his motion (the
    /// loser's side-eye). nil = none.
    var stance: RaceShowdown.Stance? = nil
    /// 3.8 Race Showdown face-off: when the race clock read 0 (wall clock,
    /// milliseconds) and which way the other Wick sits (+1 right, -1 left).
    /// While set, the face-off glance, lean and pulses play from it.
    var faceOffOrigin: Double? = nil
    var faceOffSide: Double = 1

    /// Picks his face from the mood and runs the blink-and-morph between faces.
    @State private var animator = KeeperFaceAnimator()
    /// 3.8: the five motion channels (WickMotion.swift), one per Wick.
    @State private var director = WickMotion.Director(seed: UInt32.random(in: 0...UInt32.max))
    @State private var pokeStart: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Keep the timeline running even under Reduce Motion so he still
        // blinks, glances and breathes in brightness. All positional motion is
        // removed there by the director (WickMotion.reduceMotionClamp).
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            animator.firstGuess = firstGuess
            let face = animator.frame(t: t, mood: mood, race: race ?? dances, reduceMotion: reduceMotion,
                                      showcase: showcase, override: faceOverride)
            let m = motion(t: t, frame: face)
            // A tap: one squash and release, no wobble (same as pokeSquash on the web).
            let poke: Double = reduceMotion ? 0 : pokeProgress(now: ctx.date)
            let sx: Double = (1 + m.sx) * (1 + 0.06 * poke) * face.solveScale.sx
            let sy: Double = (1 + m.sy) * (1 - 0.10 * poke) * face.solveScale.sy
            let tip: Double = reduceMotion ? WickMotion.clamp(m.tip, -0.4, 0.4) : m.tip
            let flick: Double = min(1, max(0, 0.5 + 0.5 * tip))
            let _ = reportSolveDone(t: t)

            keeperBody(flicker: flick, face: face, motion: m)
                .scaleEffect(x: sx, y: sy, anchor: .bottom)
                .rotationEffect(.degrees(m.rot), anchor: .bottom)
                .offset(x: CGFloat(m.x) * size, y: CGFloat(m.y) * size)
                .opacity(m.glow)
                .shadow(color: face.color.color.opacity(mood == .defeated ? 0 : 0.35),
                        radius: size * 0.12, y: size * 0.05)
        }
        .frame(width: size, height: size * 1.18)
        .contentShape(Rectangle())
        .onTapGesture { poke() }
        .onChange(of: pokeTick) { _, _ in pokeStart = Date() }
        .onChange(of: cue) { _, _ in director.cue(Date().timeIntervalSinceReferenceDate, kind: cueKind) }
        .onChange(of: inputFocused) { _, f in director.input(Date().timeIntervalSinceReferenceDate, focused: f) }
        .onChange(of: typingTick) { _, _ in
            director.input(Date().timeIntervalSinceReferenceDate, focused: inputFocused, typed: true)
        }
        .accessibilityHidden(true)
    }

    /// The director's frame: base pose, idle life, reaction, dance, transition.
    private func motion(t: Double, frame: KeeperFaceAnimator.Frame) -> WickMotion.Motion {
        var pulse: WickMotion.Pulse? = nil
        if dances {
            let p = RaceMusic.shared.pulse()
            if p != .none {
                pulse = WickMotion.Pulse(beat: p.beat, down: p.down, energy: p.energy, flash: p.flash, time: p.time)
            }
        }
        let input = WickMotion.Input(mood: mood.motionMood, rm: reduceMotion,
                                     solveE: animator.solveElapsed(at: t), transitionE: frame.transitionE,
                                     pulse: pulse, style: danceStyle, intensity: danceIntensity)
        var m = director.sample(t, input)
        // 3.8 Race Showdown: the face-off pose or a fixed stance. Both already
        // obey Reduced Motion.
        var add = stance
        if let origin = faceOffOrigin {
            let elapsed = Date().timeIntervalSince1970 * 1000 - origin
            add = RaceShowdown.faceOffStance(elapsed, side: faceOffSide, rm: reduceMotion)
        }
        if let st = add {
            m.gx += st.gx
            m.tip += st.tip
            m.sx += st.sx
            m.sy += st.sy
        }
        return m
    }

    /// 3.8: fire the done callback once, on the main queue after the frame.
    private func reportSolveDone(t: Double) -> Bool {
        guard animator.takeSolveDone(at: t, reduceMotion: reduceMotion) else { return false }
        if let cb = onSolveDone { DispatchQueue.main.async { cb(false) } }
        return true
    }

    /// 0...1 decaying envelope for the poke bounce (about 0.45s long).
    private func pokeProgress(now: Date) -> Double {
        guard let start = pokeStart else { return 0 }
        let e = now.timeIntervalSince(start)
        guard e >= 0, e < 0.45 else { return 0 }
        return cos(e / 0.45 * .pi / 2) * exp(-e * 5)   // quick rise already applied via scale; decays to 0
    }

    private func poke() {
        // During the solved sequence a tap skips to the button pose instead.
        let t = Date().timeIntervalSinceReferenceDate
        if animator.settleSolve(at: t) {
            if animator.takeSolveDone(at: t, reduceMotion: reduceMotion), let cb = onSolveDone { cb(true) }
            return
        }
        pokeStart = Date()
        Haptics.selection()
        onPoke?()
    }

    // MARK: Body

    private func keeperBody(flicker: Double, face: KeeperFaceAnimator.Frame, motion m: WickMotion.Motion) -> some View {
        // 3.8: live accents on the face (pupils, brows, lids, tip) and a
        // colour that travels up the flame, bottom first.
        let f = KeeperFaces.accent(face.face, m)
        var closure = face.closure
        if closure.count > 0 { closure[0] = max(closure[0], max(0, m.ll)) }
        if closure.count > 1 { closure[1] = max(closure[1], max(0, m.lr)) }
        let mid = face.color.color
        return ZStack {
            // Soft glow
            KeeperChunkyFlameShape(flicker: flicker, tip: f.tip)
                .fill(mid.opacity(mood == .defeated ? 0.10 : 0.30))
                .blur(radius: size * 0.10)
                .scaleEffect(1.12)

            // Body: saturated and emissive, without glossy highlights that read as plastic.
            KeeperChunkyFlameShape(flicker: flicker, tip: f.tip)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: face.bodyTop.color.opacity(0.92), location: 0),
                            .init(color: mid, location: 0.55),
                            .init(color: face.bodyBottom.color, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Inner flame: one tone step lighter than the body.
            KeeperPlateShape()
                .fill(Color.white.opacity(0.22))

            // The face: brows, heavy lids, under-eye bags, eyes, mouth
            KeeperFaceCanvas(face: f, closure: closure, color: face.color)

            if mood == .celebrating && face.sparksOn {
                sparkles
            }
            // 3.8: the one solved ring, violet to green, behind nothing and over everything.
            if let ring = face.solveRing {
                Circle()
                    .stroke(Color(red: 0.455 + (0.302 - 0.455) * ring.mix,
                                  green: 0.267 + (0.620 - 0.267) * ring.mix,
                                  blue: 0.941 + (0.278 - 0.941) * ring.mix),
                            lineWidth: 3)
                    .frame(width: size * ring.r * 2, height: size * ring.r * 2)
                    .opacity(ring.opacity)
                    .offset(y: -size * 0.05)
            }
        }
    }

    private var sparkles: some View {
        // Driven by the animation timeline (not an .onAppear repeatForever), so it
        // reliably twinkles on device. Gentler under Reduce Motion, never frozen.
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let amp = reduceMotion ? 0.4 : 1.0
            ZStack {
                // 3.8: three gold sparks, no more (the personality brief).
                ForEach(0..<3, id: \.self) { i in
                    let phase = (sin(t * 2 * .pi / 0.6 - Double(i) * 0.75) + 1) / 2
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.10))
                        .foregroundStyle(HunchTheme.Palette.coin)
                        .offset(
                            x: cos(Double(i) / 3 * 2 * .pi - 0.6) * size * 0.55,
                            y: sin(Double(i) / 3 * 2 * .pi - 0.6) * size * 0.55 - size * 0.05
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
