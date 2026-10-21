//
//  TutorialCoach.swift
//  Hunch
//
//  3.6: everything the tutorial level draws on top of the real game board.
//
//  - TutorialCoachCard: Wick, the 5 step badges, and one short typewriter
//    line. Step 2 shows the heat bar with your guess on it; step 3 offers
//    "Is it alive?" as a bubble that types itself into the real input field.
//  - TutorialSpotlight: dims the board and cuts holes around the controls
//    being taught, with a pulsing ring on the one to touch next.
//  - TutorialCheerBurst: the big "Warmer!" / "Lucky!" / "You got it!" pop.
//  - TutorialDoneCard: the finish line, pointing at Today's puzzle and the
//    race board.
//  - HeatScaleStrip: Freezing to Boiling as a bar, shared with How to play.
//
//  The step logic is in GameViewModel (MARK: Tutorial); the types are in
//  Game/Tutorial.swift. No copy lives here: every string comes from Loc.
//

import SwiftUI

// MARK: - Spotlight anchors

/// The pieces of the game screen the tutorial can light up.
nonisolated enum TutorialTarget: Hashable {
    case coach   // Wick's coaching card
    case hero    // the latest guess and its heat
    case input   // the guess-or-ask field and its send button
    case hint    // the hint button
}

/// Collects the bounds of every tagged control so the spotlight can cut
/// around them, in the scroll content's own coordinates (so the holes scroll
/// with the content).
nonisolated struct TutorialAnchorKey: PreferenceKey {
    static var defaultValue: [TutorialTarget: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [TutorialTarget: Anchor<CGRect>],
                       nextValue: () -> [TutorialTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Tags this view as a tutorial spotlight target.
    func tutorialAnchor(_ target: TutorialTarget) -> some View {
        anchorPreference(key: TutorialAnchorKey.self, value: .bounds) { [target: $0] }
    }
}

// MARK: - Spotlight

/// A full-bleed dim with rounded holes. The outer rect reaches far past the
/// view so it covers the whole scroll viewport; the ScrollView clips it.
struct SpotlightShape: Shape {
    var holes: [CGRect]
    var radius: CGFloat = 20

    func path(in rect: CGRect) -> Path {
        var p = Path(rect.insetBy(dx: -3000, dy: -3000))
        for h in holes {
            p.addRoundedRect(in: h, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        }
        return p
    }
}

/// Dims everything except `lit`, and pulses a ring around `ring`. Never takes
/// a touch: the player taps the real controls underneath.
struct TutorialSpotlight: View {
    let anchors: [TutorialTarget: Anchor<CGRect>]
    let lit: [TutorialTarget]
    let ring: TutorialTarget?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { proxy in
            let holes = lit.compactMap { t in anchors[t].map { proxy[$0].insetBy(dx: -8, dy: -8) } }
            ZStack(alignment: .topLeading) {
                SpotlightShape(holes: holes)
                    .fill(Color.black.opacity(scheme == .dark ? 0.62 : 0.48), style: FillStyle(eoFill: true))

                if let ring, let anchor = anchors[ring] {
                    let r = proxy[anchor].insetBy(dx: -8, dy: -8)
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { ctx in
                        let t = ctx.date.timeIntervalSinceReferenceDate
                        let phase = reduceMotion ? 0 : t.truncatingRemainder(dividingBy: 1.3) / 1.3
                        ZStack {
                            // Steady outline...
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(HunchTheme.Palette.keeper, lineWidth: 3)
                            // ...and a ping that grows and fades, like a heartbeat.
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(HunchTheme.Palette.keeper, lineWidth: 3)
                                .scaleEffect(1 + phase * 0.12)
                                .opacity(reduceMotion ? 0 : 1 - phase)
                        }
                        .frame(width: r.width, height: r.height)
                        .position(x: r.midX, y: r.midY)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Coach card

/// Wick's card: step badges, a typewriter line, and the step's one helper.
struct TutorialCoachCard: View {
    @Environment(GameViewModel.self) private var game
    /// Types a question into the real input field (step 3).
    var onFill: (String) -> Void

    @State private var pop = false

    var body: some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.m) {
            TutorialStepBadges(step: game.tutorialStep, loc: game.loc)
            HStack(alignment: .top, spacing: HunchTheme.Spacing.m) {
                KeeperView(mood: mood, size: 54)
                    .frame(width: 54)
                VStack(alignment: .leading, spacing: HunchTheme.Spacing.m) {
                    TypewriterText(text: game.tutorialLine)
                        .font(.body.weight(.semibold))
                    helper
                }
            }
        }
        .padding(HunchTheme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hunchCard(tint: HunchTheme.Palette.keeper, radius: HunchTheme.Radius.hero)
        .scaleEffect(pop ? 1.04 : 1)
        .onChange(of: game.tutorialBeat) { _, _ in
            // A little hop every time a step is cleared.
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pop = true }
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { pop = false }
            }
        }
    }

    /// Wick's face follows what just happened.
    private var mood: KeeperMood {
        if game.isAsking { return .thinking }
        switch game.tutorialNote {
        case .warmer, .lucky: return .celebrating
        case .colder:         return .cold
        case .notAWord:       return .unamused
        case .answered:       return .hot
        default:              break
        }
        if game.tutorialStep == .warmer, let last = game.lastSubmitted, last.known {
            return .forScore(last.score)
        }
        return .idle
    }

    @ViewBuilder
    private var helper: some View {
        switch game.tutorialStep {
        case .warmer:
            // The heat lesson: where your guess sits between Freezing and Boiling.
            if let last = game.lastSubmitted, last.known, game.tutorialNote != .notAWord {
                HeatScaleStrip(fill: heatFill(last), loc: game.loc)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        case .ask:
            if game.isAsking {
                ProgressView().tint(HunchTheme.Palette.keeper)
            } else {
                askBubble
            }
        case .solve:
            // The clues so far (the newest one is Wick's line above).
            let earlier = Array(game.tutorialClues.dropLast())
            if !earlier.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(earlier.enumerated()), id: \.offset) { _, clue in
                        Label(clue, systemImage: "lightbulb.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity)
            }
        default:
            EmptyView()
        }
    }

    /// "Is it alive?" as a tappable speech bubble. Tapping types it into the
    /// real field; the player still presses send, so they learn the field
    /// takes questions as well as words.
    private var askBubble: some View {
        Button {
            Feedback.play(.selection)
            onFill(game.tutorialQuestion)
        } label: {
            HStack(spacing: HunchTheme.Spacing.s) {
                Image(systemName: "bubble.left.fill")
                    .foregroundStyle(HunchTheme.Palette.keeper)
                Text(game.tutorialQuestion)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: "hand.tap.fill")
                    .foregroundStyle(HunchTheme.Palette.keeper)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .padding(.horizontal, HunchTheme.Spacing.m)
            .padding(.vertical, HunchTheme.Spacing.m)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: HunchTheme.Radius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HunchTheme.Radius.field, style: .continuous)
                .strokeBorder(HunchTheme.Palette.keeper.opacity(0.5), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func heatFill(_ g: Guess) -> Double {
        let rank = game.rank(forScore: g.score)
        return rank > 0 ? HunchTheme.rankFill(rank, maxRank: game.maxRank) : g.score / 100
    }
}

/// The five steps as little badges: done ones turn into checkmarks, the
/// current one glows. Reads as a level map, not a progress bar.
struct TutorialStepBadges: View {
    let step: TutorialStep
    let loc: Loc

    static func icon(_ s: TutorialStep) -> String {
        switch s {
        case .firstGuess: return "target"
        case .warmer:     return "flame.fill"
        case .ask:        return "bubble.left.fill"
        case .hint:       return "lightbulb.fill"
        case .solve:      return "trophy.fill"
        case .done:       return "checkmark"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TutorialStep.playable, id: \.self) { s in
                let done = s < step
                let current = s == step
                ZStack {
                    Circle()
                        .fill(done ? HunchTheme.Palette.keeper
                              : (current ? HunchTheme.Palette.keeper.opacity(0.18) : Color.primary.opacity(0.06)))
                    Image(systemName: done ? "checkmark" : Self.icon(s))
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(done ? Color.white
                                         : (current ? HunchTheme.Palette.keeper : Color.secondary.opacity(0.6)))
                }
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(HunchTheme.Palette.keeper, lineWidth: current ? 2 : 0))
                .scaleEffect(current ? 1.12 : 1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(loc.tutStepOf(min(step.rawValue, 5), 5))
    }
}

/// Text that types itself out, without the layout jumping: the part not yet
/// typed is drawn clear, so every line wraps exactly where it will end up.
/// Tap to finish it at once. Reduce Motion shows it whole.
struct TypewriterText: View {
    let text: String

    @State private var shown = 0
    @State private var typing = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let count = typing == text ? shown : (reduceMotion ? text.count : 0)
        (Text(String(text.prefix(count)))
            + Text(String(text.dropFirst(count))).foregroundStyle(Color.clear))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
            .onTapGesture { shown = text.count }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .task(id: text) {
                typing = text
                if reduceMotion { shown = text.count; return }
                shown = 0
                let total = text.count
                while shown < total {
                    try? await Task.sleep(for: .milliseconds(16))
                    if Task.isCancelled { return }
                    shown = min(total, shown + 1)
                }
            }
    }
}

// MARK: - Heat scale

/// Freezing to Boiling as one bar. `fill` (0...1) drops a marker where a
/// guess sits; nil shows the bare scale (How to play).
struct HeatScaleStrip: View {
    var fill: Double?
    let loc: Loc

    @State private var appeared = false

    private static let colors: [Color] = [
        HunchTheme.Palette.freezing, HunchTheme.Palette.cold, HunchTheme.Palette.cool,
        HunchTheme.Palette.warm, HunchTheme.Palette.hot, HunchTheme.Palette.boiling,
    ]

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: Self.colors, startPoint: .leading, endPoint: .trailing))
                        .frame(height: 10)
                    if let fill {
                        let x = (appeared ? max(0, min(1, fill)) : 0) * geo.size.width
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 1))
                            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                            .offset(x: max(0, min(geo.size.width - 20, x - 10)))
                    }
                }
                .frame(height: 20)
            }
            .frame(height: 20)

            HStack {
                Label(loc.heat("Freezing"), systemImage: "snowflake")
                    .foregroundStyle(HunchTheme.Palette.freezing)
                Spacer(minLength: HunchTheme.Spacing.s)
                Label(loc.heat("Boiling"), systemImage: "flame.fill")
                    .foregroundStyle(HunchTheme.Palette.boiling)
            }
            .font(.caption.weight(.bold))
            .labelStyle(.titleAndIcon)
        }
        .onAppear {
            // The marker slides in from Freezing, so the eye follows it.
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.15)) { appeared = true }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: fill)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Cheer burst

/// The big pop in the middle of the screen. Plays once per `tutorialCheerID`.
struct TutorialCheerBurst: View {
    @Environment(GameViewModel.self) private var game
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var visible = false
    @State private var shownID = 0

    var body: some View {
        ZStack {
            // Keeps the view alive (and listening) while nothing is showing.
            Color.clear
            if visible {
                if game.tutorialCheerKind == .lucky {
                    ConfettiView().ignoresSafeArea()
                }
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(color)
                        .symbolEffect(.bounce, value: shownID)
                    Text(title)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: color.opacity(0.45), radius: 24)
                .rotationEffect(.degrees(reduceMotion ? 0 : -4))
                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
        .onChange(of: game.tutorialCheerID) { _, id in
            shownID = id
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { visible = true }
            Task {
                try? await Task.sleep(for: .milliseconds(1150))
                guard shownID == id else { return }
                withAnimation(.easeOut(duration: 0.3)) { visible = false }
            }
        }
        .accessibilityHidden(true)
    }

    private var title: String {
        switch game.tutorialCheerKind {
        case .warmer: return game.loc.tutCheerWarmer
        case .lucky:  return game.loc.tutCheerLucky
        case .solved: return game.loc.tutCheerSolved
        }
    }

    private var icon: String {
        switch game.tutorialCheerKind {
        case .warmer: return "flame.fill"
        case .lucky:  return "sparkles"
        case .solved: return "trophy.fill"
        }
    }

    private var color: Color {
        switch game.tutorialCheerKind {
        case .warmer: return HunchTheme.Palette.hot
        case .lucky:  return HunchTheme.Palette.coin
        case .solved: return HunchTheme.Palette.solved
        }
    }
}

// MARK: - Finish line

/// "You did it!" Then the two real places to go: Today's puzzle (the big
/// button) and the race board.
struct TutorialDoneCard: View {
    @Environment(GameViewModel.self) private var game
    var onBoard: () -> Void

    @State private var badgesShown = 0

    private var labels: [String] {
        let L = game.loc
        return [L.tutBadgeGuess, L.tutBadgeWarmer, L.tutBadgeAsk, L.tutBadgeHint, L.tutBadgeSolve]
    }

    var body: some View {
        VStack(spacing: HunchTheme.Spacing.m) {
            KeeperView(mood: .celebrating, size: 96)
            Text(game.loc.tutDoneTitle)
                .font(.system(.largeTitle, design: .rounded).weight(.black))
                .multilineTextAlignment(.center)
            Text(game.loc.tutDoneWord(game.target.uppercased()))
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // The five skills, stamped one by one.
            HStack(alignment: .top, spacing: HunchTheme.Spacing.s) {
                ForEach(Array(TutorialStep.playable.enumerated()), id: \.offset) { i, s in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle().fill(HunchTheme.Palette.solved)
                            Image(systemName: TutorialStepBadges.icon(s))
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 38, height: 38)
                        Text(labels[i])
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .scaleEffect(i < badgesShown ? 1 : 0.2)
                    .opacity(i < badgesShown ? 1 : 0)
                }
            }
            .padding(.vertical, HunchTheme.Spacing.xs)

            Text(game.loc.tutDoneHeadline)
                .font(.title3.weight(.heavy))
                .foregroundStyle(HunchTheme.Palette.keeper)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Feedback.play(.selection)
                game.leaveTutorialForDaily()
            } label: {
                Label(game.loc.tutPlayDaily, systemImage: "play.fill")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(HunchTheme.Palette.hot)

            Button {
                Feedback.play(.selection)
                onBoard()
            } label: {
                Label(game.loc.boardOpen, systemImage: "trophy.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.bordered)
            .tint(HunchTheme.Palette.keeper)
        }
        .padding(HunchTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .hunchCard(tint: HunchTheme.Palette.solved, radius: HunchTheme.Radius.hero)
        .task {
            // Stamp the badges in after the cheer has had its moment.
            try? await Task.sleep(for: .milliseconds(700))
            for i in 1...TutorialStep.playable.count {
                if Task.isCancelled { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { badgesShown = i }
                Haptics.selection()
                try? await Task.sleep(for: .milliseconds(160))
            }
        }
    }
}
