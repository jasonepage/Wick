//
//  RevealView.swift
//  Hunch
//
//  "The Reveal" (3.2) — the post-round semantic map. The day's word sits at the
//  center of a bullseye; each guess is plotted by how close it came in MEANING
//  (distance from center = the warmth the player saw), with similar guesses
//  clustering by angle. The hunt animates inward in guess order.
//
//  3.9: this is "Your Path", a 15 second debrief. The map stays the hero. The
//  route now runs through every guess in the order it was made, the best jump
//  gets a gold halo, and three stats and one coach line follow. The numbers come
//  from RouteAnalysis.swift. The sequence takes about 1.2 seconds, a tap skips
//  it, and Reduce Motion or VoiceOver shows the finished report at once.
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
    /// 3.9: the round's stats and coach line. nil shows the map alone.
    var report: RouteAnalysis.Report? = nil
    /// 3.9: the category chip's label, only when the word has a reliable one.
    var category: String? = nil
    /// 3.9: hands the Path Card to the share sheet.
    var onShare: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    /// Drives the slow halo behind the word.
    @State private var pulse = false
    /// How far the reveal sequence has got: 1 Wick, 2 word, 3 route, 4 halo,
    /// 5 stats, 6 coach.
    @State private var beat = 0
    @State private var sequence: Task<Void, Never>? = nil
    @State private var showEfficiencyInfo = false

    private static let lastBeat = 6
    /// Nothing moves: Reduce Motion, and VoiceOver, which must not reach for
    /// tiles that have not faded in yet.
    private var still: Bool { reduceMotion || voiceOver }
    private var solved: Bool { solvedInGuesses != nil }

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
        ScrollView {
            VStack(spacing: HunchTheme.Spacing.m) {
                header
                map
                if let report {
                    stats(report)
                        .padding(.bottom, 5)
                        .scaleEffect(beat >= 5 || still ? 1 : 0.8)
                        .opacity(beat >= 5 ? 1 : 0)
                    if let key = report.coachKey {
                        Text(loc.key(key))
                            .font(PathStyle.font(15))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(PathStyle.face.opacity(0.10),
                                        in: RoundedRectangle(cornerRadius: PathStyle.radius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: PathStyle.radius, style: .continuous)
                                .strokeBorder(PathStyle.face.opacity(0.55), lineWidth: 3))
                            .scaleEffect(beat >= Self.lastBeat || still ? 1 : 0.8)
                            .opacity(beat >= Self.lastBeat ? 1 : 0)
                    }
                }
                actions
                Text(loc.revealCaption)
                    .font(HunchTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(HunchTheme.Spacing.l)
            .contentShape(Rectangle())
            // A tap anywhere skips to the finished report.
            .onTapGesture { if beat < Self.lastBeat { finish() } }
        }
        .onAppear {
            play()
            if !still {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
            }
        }
        .onDisappear { sequence?.cancel() }
        .sheet(isPresented: $showEfficiencyInfo) { efficiencyInfo }
    }

    // MARK: - Report

    /// Result first: `Solved in 8`, with the green Wick and, now that the word
    /// is on screen, its broad category.
    private var header: some View {
        VStack(spacing: HunchTheme.Spacing.xs) {
            KeeperStill(face: solved ? .sly : .calm,
                        color: solved ? KeeperRGB.body(for: .celebrating) : KeeperRGB.body(for: .defeated),
                        sparks: false, size: 42)
                .scaleEffect(beat >= 1 || still ? 1 : 0.7)
                .opacity(beat >= 1 ? 1 : 0)
                .accessibilityHidden(true)
            Text((solvedInGuesses.map { loc.pathSolvedIn($0) } ?? loc.key("pathUnsolved")).uppercased())
                .font(PathStyle.font(29))
                .foregroundStyle(solved ? HunchTheme.Palette.solved : PathStyle.face)
                .shadow(color: (solved ? HunchTheme.Palette.solved : PathStyle.lip).opacity(0.35), radius: 0, x: 0, y: 3)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            if let category {
                Text(category)
                    .font(PathStyle.font(11))
                    .tracking(0.8)
                    .foregroundStyle(Color(red: 0.23, green: 0.16, blue: 0))
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(PathStyle.goldLip, in: RoundedRectangle(cornerRadius: 10, style: .continuous).offset(y: 3))
                    .background(PathStyle.gold, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .rotationEffect(.degrees(-2))
                    .opacity(beat >= 2 ? 1 : 0)
            }
        }
    }

    private func stats(_ r: RouteAnalysis.Report) -> some View {
        let none = loc.key("pathStatNone")
        return HStack(alignment: .top, spacing: HunchTheme.Spacing.s) {
            Button {
                showEfficiencyInfo = true
            } label: {
                PathStatTile(title: loc.key("pathStatEfficiency"),
                             value: r.efficiency.map { "\($0)" } ?? none,
                             hasInfo: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint(loc.key("pathEfficiencyInfoBtn"))
            PathStatTile(title: loc.key("pathStatBestJump"),
                         value: r.firstTry ? loc.key("pathFirstTry") : (r.bestJump?.word ?? none),
                         detail: r.firstTry ? nil : r.bestJump.map { loc.pathJumpGain($0.gain) })
            // Without similarity it is unknown, not zero, so the tile stays off.
            if let directions = r.exploration {
                PathStatTile(title: loc.key("pathStatExploration"), value: loc.pathDirections(directions))
            }
        }
    }

    private var actions: some View {
        VStack(spacing: HunchTheme.Spacing.s) {
            if let onShare, !points.isEmpty {
                Button {
                    Feedback.play(.selection)
                    onShare()
                } label: {
                    Label(loc.key("pathShare").uppercased(), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(RaisedButtonStyle())
            }
            HStack(spacing: HunchTheme.Spacing.s) {
                Button {
                    play()
                } label: {
                    Label(loc.revealReplay, systemImage: "arrow.counterclockwise")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .buttonStyle(RaisedButtonStyle(face: PathStyle.face.opacity(0.14), lip: PathStyle.lip.opacity(0.35), ink: PathStyle.face))
                .disabled(still)
                .opacity(still ? 0.5 : 1)
                Button {
                    dismiss()
                } label: {
                    Text(loc.liveDone)
                }
                .buttonStyle(RaisedButtonStyle(face: PathStyle.face.opacity(0.14), lip: PathStyle.lip.opacity(0.35), ink: PathStyle.face))
            }
            .padding(.top, 4)
            .padding(.bottom, 5)
        }
    }

    private var efficiencyInfo: some View {
        VStack(spacing: HunchTheme.Spacing.s) {
            Text(loc.key("pathStatEfficiency")).font(.headline)
            Text(loc.key("pathEfficiencyInfo"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(HunchTheme.Spacing.xl)
        .presentationDetents([.height(170)])
    }

    /// Run the reveal from the top. With nothing to animate, go straight to
    /// the finished composition.
    private func play() {
        sequence?.cancel()
        guard !still else {
            beat = Self.lastBeat
            appeared = true
            return
        }
        beat = 0
        appeared = false
        let b = RouteAnalysis.pathSequence(reduceMotion: false)
        let steps: [(beat: Int, at: Int)] = [(1, b.wick), (2, b.word), (3, b.route), (4, b.halo), (5, b.stats), (6, b.coach)]
        sequence = Task { @MainActor in
            var now = 0
            for step in steps {
                try? await Task.sleep(for: .milliseconds(max(0, step.at - now)))
                if Task.isCancelled { return }
                now = step.at
                withAnimation(.spring(response: 0.26, dampingFraction: 0.55)) { beat = step.beat }
                if step.beat == 3 { appeared = true }
            }
        }
    }

    /// Skip whatever is left of the reveal.
    private func finish() {
        sequence?.cancel()
        withAnimation(.easeOut(duration: 0.12)) { beat = Self.lastBeat }
        appeared = true
    }

    // MARK: - Map

    private var map: some View {
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
                    halo(center: center, plotR: plotR)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc.revealMapA11y + " " + loc.revealCaption)
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

    /// Every guess in the order it was made: the route the player really took.
    private var routePoints: [RevealPoint] {
        points.sorted(by: { $0.index < $1.index }).filter { $0.score < 100 }
    }

    /// The guesses that were the closest yet when they were made. They get the
    /// large dots.
    private var closestYet: Set<Int> {
        var best = -1.0
        var out = Set<Int>()
        for p in routePoints where p.score > best {
            out.insert(p.index)
            best = p.score
        }
        return out
    }

    /// When a dot pops in, so the dots follow the route line.
    private func dotDelay(_ index: Int) -> Double {
        let b = RouteAnalysis.pathSequence(reduceMotion: still)
        return Double(b.routeMs) / 1000 * Double(index) / Double(max(1, points.count))
    }

    /// One glowing, smoothed trail through every guess, first to last, ending at
    /// the word when it was solved. Colored cold to hot along the way.
    private func trail(center: CGPoint, plotR: CGFloat, size: CGSize) -> some View {
        var pts = routePoints.map { screen($0, center, plotR) }
        if solvedInGuesses != nil { pts.append(center) }
        let colors = routePoints.map { HunchTheme.color(for: $0.score) }
            + (solvedInGuesses != nil ? [HunchTheme.Palette.solved] : [])
        let start = pts.first ?? center
        let end = pts.last ?? center
        let gradient = LinearGradient(
            colors: colors.count > 1 ? colors : [colors.first ?? .clear, colors.first ?? .clear],
            startPoint: UnitPoint(x: start.x / max(1, size.width), y: start.y / max(1, size.height)),
            endPoint: UnitPoint(x: end.x / max(1, size.width), y: end.y / max(1, size.height)))
        let shape = SmoothPath(points: pts)
        let progress: CGFloat = appeared ? 1 : 0
        let routeMs = RouteAnalysis.pathSequence(reduceMotion: still).routeMs
        let animation: Animation? = still ? nil : .easeInOut(duration: Double(routeMs) / 1000)
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
        let onTrail = closestYet
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
                        .animation(still ? nil : .spring(response: 0.4, dampingFraction: 0.72).delay(dotDelay(pt.index)), value: appeared)
                        .accessibilityLabel(loc.revealGuessA11y(pt.index + 1,
                                                                pt.word,
                                                                loc.heat(HunchTheme.label(for: pt.score))))
                }
            }
        }
    }

    /// The gold halo on the round's pivotal move. A jump that landed on the
    /// word itself rings the word at the center.
    @ViewBuilder
    private func halo(center: CGPoint, plotR: CGFloat) -> some View {
        if let jump = report?.bestJump, let p = points.first(where: { $0.index == jump.index }) {
            let onWord = p.score >= 100
            RoundedRectangle(cornerRadius: onWord ? 26 : 14, style: .continuous)
                .stroke(HunchTheme.Palette.coin, lineWidth: 3.5)
                .frame(width: onWord ? wordWidth + 34 : 28, height: onWord ? 52 : 28)
                .shadow(color: HunchTheme.Palette.coin.opacity(0.6), radius: 6)
                .position(onWord ? center : screen(p, center, plotR))
                .opacity(beat >= 4 ? 1 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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
                    .animation(still ? nil : .easeOut(duration: 0.3).delay(dotDelay(item.point.index) + 0.2), value: appeared)
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
        .opacity(beat >= 2 ? 1 : 0)
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
