//
//  KeeperView.swift
//  Hunch
//
//  "Wick" — the Keeper mascot. A little flame spirit drawn entirely in
//  SwiftUI shapes. Its color and expression track the temperature of the
//  game: icy blue when you're freezing, blazing orange when you're hot,
//  green and starry-eyed when you solve it.
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
    case boiling       // wide-eyed, vibrating
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
    /// Whether Wick wears the player's equipped accessories. Pass `false` for a
    /// bare Wick (e.g. onboarding, or the wardrobe's own preview handles its own).
    var showsAccessories: Bool = true

    /// Equipped cosmetics, read reactively from the shared wardrobe.
    @State private var wardrobe = WardrobeStore.shared

    @State private var blinking = false
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
            let vibrate = (mood == .boiling && !reduceMotion) ? sin(t * 26) * 0.8 : 0
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

            keeperBody(flicker: flick)
                .scaleEffect(breathe * pokeScale, anchor: .bottom)
                .rotationEffect(.degrees(pokeWiggle), anchor: .bottom)
                .offset(x: shiver + vibrate, y: bob)
                .opacity(glow)
                .shadow(color: mood.bodyColor.opacity(mood == .defeated ? 0 : 0.35),
                        radius: size * 0.12, y: size * 0.05)
        }
        .frame(width: size, height: size * 1.18)
        .contentShape(Rectangle())
        .onTapGesture { poke() }
        .task(id: mood) { await blinkLoop() }
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

    private func keeperBody(flicker: Double) -> some View {
        ZStack {
            // Soft glow
            KeeperFlameShape(flicker: flicker)
                .fill(mood.bodyColor.opacity(mood == .defeated ? 0.10 : 0.30))
                .blur(radius: size * 0.10)
                .scaleEffect(1.12)

            // Body
            KeeperFlameShape(flicker: flicker)
                .fill(
                    LinearGradient(
                        colors: [mood.bodyColor.opacity(0.92), mood.bodyColor],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Inner core highlight
            KeeperFlameShape(flicker: flicker)
                .fill(Color.white.opacity(mood == .defeated ? 0.08 : 0.22))
                .scaleEffect(x: 0.55, y: 0.55, anchor: .bottom)
                .offset(y: -size * 0.04)

            face
                .offset(y: size * 0.16)

            if mood == .celebrating {
                sparkles
            }

            // Accessories ride on top of the body. They sit in the SAME ZStack, so
            // the outer bob/breathe/poke transforms apply to them too; each only
            // has to match the intra-body flicker lean to stay anchored.
            if showsAccessories {
                accessoryLayer(flicker: flicker)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: mood)
    }

    // MARK: Accessories

    /// Draws every equipped accessory at its slot's anchor. The flame tip leans by
    /// `lean` at the very top; each slot follows a damped fraction so hats perch on
    /// the tip while face/neck props barely drift. Anchors are tuned to `size`.
    @ViewBuilder
    private func accessoryLayer(flicker: Double) -> some View {
        let lean = (flicker - 0.5) * 0.22 * size   // identical formula to KeeperFlameShape
        // Eyes are drawn in the face (they replace the eyeballs), not perched at a
        // slot anchor, so exclude them here.
        ForEach(wardrobe.equippedAccessories.filter { $0.slot != .eyes }) { item in
            WickAccessoryView(id: item.id, size: size)
                .offset(x: lean * Self.leanFactor(item.slot),
                        y: size * Self.slotY(item.slot))
                .rotationEffect(.degrees(lean * Self.rotFactor(item.slot)))
        }
        // Holiday Wick: an auto-worn seasonal hat, shown only when the player hasn't
        // equipped a hat of their own — so it never overrides a chosen look.
        if wardrobe.equipped[.hat] == nil, let seasonal = Self.seasonalHatID() {
            WickAccessoryView(id: seasonal, size: size)
                .offset(x: lean * Self.leanFactor(.hat), y: size * Self.slotY(.hat))
                .rotationEffect(.degrees(lean * Self.rotFactor(.hat)))
        }
    }

    /// The auto-worn seasonal hat id for a date, or nil. Christmas gets the drawn
    /// Santa hat; New Year's Day and Halloween reuse existing hats.
    static func seasonalHatID(for date: Date = Date()) -> String? {
        let cal = Calendar.current
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        switch (m, d) {
        case (12, 18...31): return "hat.santa"    // Christmas season
        case (1, 1):        return "hat.party"     // New Year's Day
        case (10, 28...31): return "hat.wizard"    // Halloween week
        default:            return nil
        }
    }

    /// Vertical anchor per slot, as a fraction of `size` from the ZStack center.
    /// Hat sits above the tip; face over the eyes; neck near the base.
    private static func slotY(_ slot: AccessorySlot) -> CGFloat {
        switch slot {
        case .hat:   return -0.52
        case .eyes:  return  0.10   // unused (eyes are drawn in the face)
        case .face:  return  0.10
        case .mouth: return  0.32
        case .neck:  return  0.44
        }
    }
    /// How much each slot tracks the tip's horizontal sway.
    private static func leanFactor(_ slot: AccessorySlot) -> CGFloat {
        switch slot {
        case .hat:   return 0.9
        case .eyes:  return 0.3     // unused
        case .face:  return 0.3
        case .mouth: return 0.2
        case .neck:  return 0.1
        }
    }
    private static func rotFactor(_ slot: AccessorySlot) -> CGFloat {
        switch slot {
        case .hat:   return 0.25
        case .eyes:  return 0.0     // unused
        case .face:  return 0.05
        case .mouth: return 0.0
        case .neck:  return 0.0
        }
    }

    // MARK: Face

    /// When the tongue accessory is worn, hide the drawn mouth so the tongue
    /// reads as sticking out — not floating beneath a smile.
    private var hidesMouth: Bool {
        showsAccessories && wardrobe.isEquipped("mouth.tongue")
    }

    private var face: some View {
        VStack(spacing: size * 0.07) {
            HStack(spacing: size * 0.16) {
                eye
                eye
            }
            if !hidesMouth { mouth }
        }
    }

    /// The equipped eye-cosmetic id, if any (nil when accessories are hidden).
    private var equippedEyeID: String? {
        showsAccessories ? wardrobe.equipped[.eyes] : nil
    }

    /// Cosmetic eyes replace the mood eyes; Wick still emotes via body color and
    /// mouth. When none is equipped, fall back to the mood-driven eyes.
    @ViewBuilder
    private var eye: some View {
        if let eyeID = equippedEyeID {
            WickEye(id: eyeID, size: size)
        } else {
            moodEye
        }
    }

    @ViewBuilder
    private var moodEye: some View {
        let eyeW = size * 0.115
        switch mood {
        case .celebrating:
            Image(systemName: "star.fill")
                .font(.system(size: eyeW * 1.5))
                .foregroundStyle(.white)
        case .defeated:
            Capsule().fill(.white.opacity(0.85))
                .frame(width: eyeW, height: eyeW * 0.22)
        case .freezing:
            Capsule().fill(.white)
                .frame(width: eyeW, height: blinking ? eyeW * 0.18 : eyeW * 0.45)
        case .thinking:
            Circle().fill(.white)
                .frame(width: eyeW, height: blinking ? eyeW * 0.18 : eyeW)
                .offset(x: eyeW * 0.18, y: -eyeW * 0.22)   // gazing up & away
        case .boiling, .hot:
            Circle().fill(.white)
                .frame(width: eyeW * 1.18, height: blinking ? eyeW * 0.18 : eyeW * 1.18)
        case .unamused:
            // Flat dashes: the "-_-" look.
            Capsule().fill(.white.opacity(0.9))
                .frame(width: eyeW * 1.15, height: eyeW * 0.22)
        default:
            Circle().fill(.white)
                .frame(width: eyeW, height: blinking ? eyeW * 0.18 : eyeW)
        }
    }

    @ViewBuilder
    private var mouth: some View {
        let mw = size * 0.16
        switch mood {
        case .celebrating, .boiling:
            // Open, delighted
            Circle()
                .trim(from: 0, to: 0.5)
                .fill(.white.opacity(0.9))
                .frame(width: mw, height: mw)
        case .hot, .warm:
            // Smile
            Circle()
                .trim(from: 0.05, to: 0.45)
                .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: size * 0.028, lineCap: .round))
                .frame(width: mw, height: mw * 0.9)
        case .thinking:
            // Small pondering "o", nudged to one side
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: mw * 0.34, height: mw * 0.34)
                .offset(x: mw * 0.22)
        case .defeated:
            // Flat line
            Capsule().fill(.white.opacity(0.7))
                .frame(width: mw * 0.7, height: size * 0.025)
        case .unamused:
            // Flat, unimpressed line
            Capsule().fill(.white.opacity(0.85))
                .frame(width: mw * 0.7, height: size * 0.026)
        case .freezing, .cold:
            // Wobbly frown
            Circle()
                .trim(from: 0.55, to: 0.95)
                .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: size * 0.028, lineCap: .round))
                .frame(width: mw * 0.8, height: mw * 0.7)
                .offset(y: mw * 0.18)
        default:
            // Small contented smile
            Circle()
                .trim(from: 0.1, to: 0.4)
                .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: size * 0.026, lineCap: .round))
                .frame(width: mw * 0.8, height: mw * 0.8)
        }
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

    // MARK: Blink loop

    private func blinkLoop() async {
        guard mood != .defeated, mood != .celebrating, mood != .unamused else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.2...4.5)))
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.07)) { blinking = true }
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.easeIn(duration: 0.09)) { blinking = false }
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
