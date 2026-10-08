//
//  LiveDuelView.swift
//  Hunch — Wick 3.0 live multiplayer
//
//  The live-duel screen. It reuses the SAME visual language as the single-player
//  board (GameView): HunchTheme colours + cards, the KeeperView mascot, the
//  warmth ring, ClosenessBar guess rows, and HunchTag verdicts — so a live match
//  looks and feels like Wick, just with a live-opponent strip on top and a clock.
//
//  It stays server-authoritative (LiveDuelViewModel): warmth for a guess arrives
//  from the server (shown as "…" until then), and solve/timing are the server's
//  call. Asking Wick a question is answered server-side on the room secret.
//
//  Deliberately independent of GameViewModel so it can't disturb the 2.1 board;
//  it only borrows the shared, stateless theme components.
//

import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct LiveDuelView: View {
    /// When set (from a tapped invite link), auto-join this code on appear (3.1).
    var joinCode: String? = nil

    @StateObject private var model = LiveDuelViewModel()
    @State private var entry: String = ""
    @State private var codeField: String = ""
    @State private var sortHottest = false
    @State private var didAutoStart = false
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    /// Localized UI strings for the player's chosen language (3.1).
    private var loc: Loc { Loc(lang: .stored) }

    var body: some View {
        NavigationStack {
            ZStack {
                HunchTheme.background(for: myBestScore)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: myBestScore)
                content
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { model.leave(); dismiss() } label: {
                        Label(loc.liveLeave, systemImage: "xmark")
                    }
                }
            }
            .overlay(alignment: .bottom) { banner }
            .overlay { celebration }
            .onAppear {
                guard !didAutoStart, let code = joinCode else { return }
                didAutoStart = true
                model.joinInvite(code: code) // opened from a link → join straight away
            }
        }
    }

    /// A burst of confetti when this device wins — reuses the single-player
    /// celebration. A loss stays gentle (the defeated Wick, no confetti).
    @ViewBuilder
    private var celebration: some View {
        if model.phase == .finished && model.didIWin {
            ConfettiView()
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    // MARK: Phase router

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:             lobbyView
        case .searching:        searchingView
        case .playing:          playingView
        case .finished:         finishedView
        case .disconnected:     disconnectedView
        }
    }

    private var navTitle: String {
        switch model.phase {
        case .playing:  return loc.liveLiveRace
        case .finished: return loc.liveResult
        default:        return loc.liveRace
        }
    }

    // MARK: Lobby (Quick Match / friend code)

    private var lobbyView: some View {
        ScrollView {
            VStack(spacing: HunchTheme.Spacing.xl) {
                VStack(spacing: HunchTheme.Spacing.s) {
                    KeeperView(mood: .idle, size: 104)
                    Text(loc.liveRace)
                        .font(.title.bold())
                    Text(loc.liveRaceBlurb)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Haptics.selection()
                    model.find()
                } label: {
                    Label(loc.liveQuickMatch, systemImage: "bolt.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .tint(HunchTheme.Palette.flame)

                Button {
                    Haptics.selection()
                    model.hostInvite()
                } label: {
                    Label(loc.liveInviteFriend, systemImage: "person.2.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
                }
                .buttonStyle(.bordered)
                .tint(HunchTheme.Palette.keeper)

                VStack(alignment: .leading, spacing: HunchTheme.Spacing.m) {
                    Label(loc.liveHaveACode, systemImage: "arrow.down.circle.fill")
                        .font(.caption.weight(.heavy)).foregroundStyle(.secondary)
                    HStack(spacing: HunchTheme.Spacing.s) {
                        TextField(loc.liveEnterIt, text: $codeField)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: HunchTheme.Radius.field, style: .continuous))
                        Button {
                            Haptics.selection()
                            model.joinInvite(code: codeField)
                        } label: {
                            Text(loc.liveJoin).font(.headline).padding(.horizontal, 18).padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(HunchTheme.Palette.keeper)
                        .disabled(codeField.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Text(loc.liveInviteHintRace)
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(HunchTheme.Spacing.l)
                .hunchCard()
            }
            .padding(HunchTheme.Spacing.l)
            .frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
    }

    // MARK: Searching

    private var searchingView: some View {
        VStack(spacing: HunchTheme.Spacing.l) {
            Spacer()
            KeeperView(mood: .thinking, size: 108)
            Text(model.isFriendMatch ? loc.liveWaitingForFriend : loc.liveFindingOpponent)
                .font(.headline)
            if model.isHosting, let code = model.friendCode {
                Text(code)
                    .font(.system(.largeTitle, design: .monospaced).weight(.heavy))
                    .foregroundStyle(HunchTheme.Palette.keeper)
                    .textSelection(.enabled)
                Button {
                    Haptics.selection()
                    let invite = LiveInvite(mode: .race, code: code)
                    ShareSheet.present([invite.shareMessage, invite.shareURL])
                } label: {
                    Label(loc.liveShareInviteLink, systemImage: "square.and.arrow.up").font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(HunchTheme.Palette.keeper)
                Text(loc.liveShareTapToJoin)
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                QRCodeView(text: LiveInvite(mode: .race, code: code).shareURL.absoluteString)
                Text(loc.liveScanCaption).font(.caption).foregroundStyle(.secondary)
            } else if let startsAt = model.startsAt {
                // 3.3 shared start: everyone in Quick Match counts down to the
                // same moment, so two people a minute apart still race each
                // other. If someone shows up sooner the server pairs early.
                Text(loc.liveNextRaceIn)
                    .font(.subheadline).foregroundStyle(.secondary)
                TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                    Text(Self.fmtCountdown(until: startsAt, now: ctx.date))
                        .monospacedDigit()
                        .font(.system(.largeTitle, design: .monospaced).weight(.heavy))
                        .foregroundStyle(HunchTheme.Palette.keeper)
                }
                Text(loc.livePracticeFlameSteps)
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                Text(model.isFriendMatch
                     ? loc.liveTheyJoinByLink
                     : loc.livePracticeFlameSteps)
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button(loc.liveCancel) { model.leave() }
                .buttonStyle(.bordered)
                .padding(.top, HunchTheme.Spacing.s)
            Spacer()
        }
        .padding(HunchTheme.Spacing.xl)
    }

    /// m:ss until `until`, clamped at 0:00.
    private static func fmtCountdown(until: Date, now: Date) -> String {
        let secs = max(0, Int(ceil(until.timeIntervalSince(now))))
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    // MARK: Playing

    private var playingView: some View {
        ScrollView {
            VStack(spacing: HunchTheme.Spacing.l) {
                opponentStrip
                clockView
                if let latest = model.guesses.first {
                    heroCard(latest)
                } else {
                    welcomeCard
                }
                inputArea
                feedSection
            }
            .padding(HunchTheme.Spacing.l)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Opponent strip

    private var opponentStrip: some View {
        let score = model.opponentGuesses > 0 ? model.opponentWarmth * 100 : 0
        let live = model.opponentKind == .human
        return HStack(spacing: HunchTheme.Spacing.m) {
            ZStack {
                Circle().fill(HunchTheme.Palette.keeper.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: live ? "person.fill" : "flame.fill")
                    .font(.title3)
                    .foregroundStyle(live ? HunchTheme.Palette.keeper : HunchTheme.Palette.flame)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(opponentLabel).font(.headline)
                    if model.snapshot?.opponent.connected == false {
                        Text(loc.liveReconnecting).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Text(loc.liveGuessesCount(model.opponentGuesses))
                        .font(.caption).foregroundStyle(.secondary)
                }
                ClosenessBar(fill: model.opponentWarmth, color: HunchTheme.color(for: score))
            }
        }
        .padding(HunchTheme.Spacing.l)
        .frame(maxWidth: .infinity)
        .hunchCard()
    }

    private var clockView: some View {
        Label(Self.fmtClock(model.remainingMs), systemImage: "timer")
            .font(.title3.monospacedDigit().weight(.semibold))
            .foregroundStyle(model.remainingMs < 30_000 ? HunchTheme.Palette.boiling : Color.secondary)
    }

    // MARK: Welcome (before the first guess) — 1:1 with GameView.welcomeCard

    private var welcomeCard: some View {
        VStack(spacing: HunchTheme.Spacing.s) {
            KeeperView(mood: .idle, size: 96)
            KeeperSpeech(
                text: loc.liveWelcome(KeeperView.name)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(HunchTheme.Spacing.xl)
        .hunchCard(tint: HunchTheme.Palette.keeper, radius: HunchTheme.Radius.hero)
    }

    // MARK: Hero (latest guess) — warmth ring + Wick, mirrors GameView

    @ViewBuilder
    private func heroCard(_ g: LiveDuelViewModel.Guess) -> some View {
        let pending = g.warmth == nil
        let score = g.warmth ?? 0
        let color = g.correct ? HunchTheme.Palette.solved
                  : (pending ? HunchTheme.Palette.keeper : HunchTheme.color(for: score))
        let fill = g.correct ? 1.0 : (pending ? 0.02 : score / 100)
        // A close guess reveals its Contexto "#N" (like the daily board); heat word otherwise.
        let big = Self.heatLabel(warmth: g.warmth, rank: g.rank, correct: g.correct)
        let label = g.correct ? loc.liveYouGotItLower : (pending ? loc.liveScoring : hint(for: score))
        let mood: KeeperMood = g.correct ? .celebrating : (pending ? .thinking : .forScore(score))

        VStack(spacing: HunchTheme.Spacing.m) {
            HStack(spacing: HunchTheme.Spacing.xl) {
                ZStack {
                    Circle().stroke(color.opacity(0.15), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: max(0.02, fill))
                        .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(big)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                            .minimumScaleFactor(0.5).lineLimit(1)
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(color)
                    }
                    .padding(.horizontal, 10)
                }
                .frame(width: 124, height: 124)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: g.id)

                KeeperView(mood: mood, size: 72)
            }
            Text(g.word).font(HunchTheme.Fonts.cardTitle)
            if let t = model.latestTrajectory { trajectoryPill(t) }
        }
        .frame(maxWidth: .infinity)
        .padding(HunchTheme.Spacing.xl)
        .hunchCard(tint: color, radius: HunchTheme.Radius.hero)
        .animation(.easeInOut(duration: 0.25), value: g.id)
    }

    private func hint(for score: Double) -> String { loc.liveKeepGoing }

    @ViewBuilder
    private func trajectoryPill(_ t: LiveDuelViewModel.Trajectory) -> some View {
        switch t {
        case .first:   pill(loc.liveGoodStart, "sparkles", HunchTheme.Palette.keeper)
        case .closest: pill(loc.liveClosestYet, "flame.fill", HunchTheme.Palette.hot)
        case .colder:  pill(loc.liveFurther, "snowflake", HunchTheme.Palette.freezing)
        }
    }

    private func pill(_ text: String, _ icon: String, _ color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.22), lineWidth: 1))
    }

    // MARK: Input

    private var inputArea: some View {
        VStack(spacing: HunchTheme.Spacing.s) {
            HStack(spacing: HunchTheme.Spacing.s) {
                TextField(loc.liveGuessOrAsk, text: $entry)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(
                        Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: HunchTheme.Radius.field, style: .continuous)
                    )
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(HunchTheme.Palette.keeper)
                }
                .disabled(entry.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if model.guesses.isEmpty && model.replies.isEmpty {
                Text(loc.liveGuessOrAskHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, HunchTheme.Spacing.xs)
            }
        }
    }

    // MARK: Feed (questions + guesses, newest first)

    @ViewBuilder
    private var feedSection: some View {
        if !model.replies.isEmpty || !model.guesses.isEmpty {
            VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
                HStack(spacing: HunchTheme.Spacing.s) {
                    Text(loc.liveYourRound)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer(minLength: 0)
                    if !model.guesses.isEmpty { sortToggle }
                }
                .padding(.leading, HunchTheme.Spacing.xs)
                VStack(spacing: HunchTheme.Spacing.m) {
                    ForEach(model.replies) { questionRow($0) }
                    ForEach(sortedGuesses) { guessRow($0) }
                }
                .padding(HunchTheme.Spacing.l)
                .hunchCard()
            }
        }
    }

    private func guessRow(_ g: LiveDuelViewModel.Guess) -> some View {
        let pending = g.warmth == nil
        let score = g.warmth ?? 0
        let color = g.correct ? HunchTheme.Palette.solved : HunchTheme.color(for: score)
        return HStack(spacing: HunchTheme.Spacing.m) {
            Text(g.word)
                .font(.body.weight(.semibold))
                .frame(width: 104, alignment: .leading)
                .lineLimit(1).minimumScaleFactor(0.6)
            ClosenessBar(fill: pending ? 0 : (g.correct ? 1 : score / 100), color: color)
            Text(Self.heatLabel(warmth: g.warmth, rank: g.rank, correct: g.correct))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 84, alignment: .trailing)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.vertical, 2)
    }

    /// A close guess shows its Contexto "#N" (top 100 only); otherwise the heat
    /// word. The server sends the rank in the iOS 1-based convention (rank 2 = the
    /// closest guessable word), so this reveals it exactly like the single-player
    /// board (HunchTheme.rankRevealThreshold == 100).
    static func heatLabel(warmth: Double?, rank: Int?, correct: Bool) -> String {
        if correct { return Loc(lang: .stored).liveSolvedExcl }
        guard let w = warmth else { return "…" }
        if let rank, rank <= 100 { return "#\(rank)" }
        return HunchTheme.label(for: w)
    }

    /// Round-log order: loc.sortRecent keeps insertion order (newest first); loc.sortClosest
    /// sorts by warmth, with still-scoring guesses floated to the top.
    private var sortedGuesses: [LiveDuelViewModel.Guess] {
        guard sortHottest else { return model.guesses }
        return model.guesses.sorted { a, b in
            switch (a.warmth, b.warmth) {
            case (nil, nil): return false
            case (nil, _):   return true
            case (_, nil):   return false
            case (let x?, let y?): return x > y
            }
        }
    }

    /// Two-chip toggle mirroring the single-player round-log control.
    private var sortToggle: some View {
        HStack(spacing: 2) {
            sortChip(hottest: false, icon: "clock", label: loc.sortRecent)
            sortChip(hottest: true, icon: "flame.fill", label: loc.sortClosest)
        }
        .padding(2)
        .background(Capsule().fill(.quaternary.opacity(0.5)))
    }

    private func sortChip(hottest: Bool, icon: String, label: String) -> some View {
        let selected = sortHottest == hottest
        return Button {
            guard !selected else { return }
            withAnimation(.snappy) { sortHottest = hottest }
            Haptics.selection()
        } label: {
            Label(label, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .padding(.horizontal, HunchTheme.Spacing.s)
                .padding(.vertical, 4)
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .background(Capsule().fill(selected ? AnyShapeStyle(.background) : AnyShapeStyle(.clear)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func questionRow(_ r: LiveDuelViewModel.Reply) -> some View {
        HStack(alignment: .top, spacing: HunchTheme.Spacing.m) {
            if r.pending {
                ProgressView()
            } else {
                HunchTag(text: r.verdict, color: HunchTheme.verdictColor(r.verdict))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(r.question).font(.body)
                if !r.text.isEmpty {
                    Text(r.text).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "bubble.left.fill")
                .font(.footnote).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    // MARK: Finished

    private var finishedView: some View {
        let tint = model.isDraw ? HunchTheme.Palette.keeper
                 : (model.didIWin ? HunchTheme.Palette.solved : HunchTheme.Palette.neutral)
        let mood: KeeperMood = model.isDraw ? .idle : (model.didIWin ? .celebrating : .defeated)
        return VStack(spacing: HunchTheme.Spacing.m) {
            Spacer()
            KeeperView(mood: mood, size: 100)
            Text(outcomeTitle).font(.title.bold())
            if let r = model.result {
                Text(outcomeSubtitle(r))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let word = model.revealedWord {
                VStack(spacing: 2) {
                    Text(loc.liveTheWordWas).font(.subheadline).foregroundStyle(.secondary)
                    Text(word).font(HunchTheme.Fonts.revealWord)
                }
                .padding(.top, HunchTheme.Spacing.s)
            }
            Button(action: { model.isFriendMatch ? model.rematch() : model.find() }) {
                Label(model.isFriendMatch ? loc.liveRematch : loc.livePlayAgain,
                      systemImage: "flag.checkered.2.crossed")
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
            Button(loc.liveDone) { model.leave(); dismiss() }
                .buttonStyle(.bordered)
            Spacer()
        }
        .padding(HunchTheme.Spacing.xl)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }

    // MARK: Disconnected

    private var disconnectedView: some View {
        VStack(spacing: HunchTheme.Spacing.m) {
            Spacer()
            KeeperView(mood: .defeated, size: 88)
            Text(loc.liveConnectionLost).font(.title2.bold())
            Button(action: { model.find() }) {
                Label(loc.liveTryAgain, systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(HunchTheme.Palette.keeper)
            Button(loc.liveDone) { model.leave(); dismiss() }
                .buttonStyle(.bordered)
            Spacer()
        }
        .padding(HunchTheme.Spacing.xl)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }

    // MARK: Banner

    @ViewBuilder
    private var banner: some View {
        if let banner = model.banner {
            Text(banner)
                .font(.subheadline)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 12)
                .onTapGesture { model.dismissBanner() }
                .task(id: banner) {
                    try? await Task.sleep(for: .seconds(3))
                    model.dismissBanner()
                }
        }
    }

    // MARK: Actions & helpers

    private func send() {
        model.submit(entry)
        entry = ""
    }

    private var myBestScore: Double {
        model.guesses.compactMap { $0.warmth }.max() ?? 0
    }

    private var opponentLabel: String {
        switch model.opponentKind {
        case .human: return loc.liveLiveOpponent
        case .bot:   return loc.livePracticeFlame
        case .ghost: return loc.liveGhost
        case .none:  return loc.liveOpponent
        }
    }

    private var outcomeTitle: String {
        if model.isDraw { return loc.liveDraw }
        return model.didIWin ? loc.liveYouWin : loc.liveYouLost
    }

    private func outcomeSubtitle(_ r: MatchResult) -> String {
        switch r.reason {
        case .solved:  return model.didIWin ? loc.liveFirstToWord : loc.liveOppFirst
        case .timeout: return loc.liveTimeUpWarmest
        case .forfeit: return model.didIWin ? loc.liveOppLeft : loc.liveYouLeft
        case .void:    return loc.liveBothDropped
        }
    }

    private static func fmtClock(_ ms: Int) -> String {
        let total = max(0, ms) / 1000
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - QR code (3.1 invite links)

/// A crisp QR code for an invite URL — CoreImage, no dependency. Lets a friend in
/// the same room point their camera at the screen to join, no typing or link needed.
struct QRCodeView: View {
    let text: String
    var size: CGFloat = 168

    var body: some View {
        Group {
            if let img = Self.image(from: text) {
                Image(uiImage: img)
                    .interpolation(.none)   // keep the modules crisp, not blurred
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .padding(10)
        .background(Color.white)            // QR needs a light quiet zone
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06)))
    }

    private static func image(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        // Scale the tiny CI output up so it renders sharp at display size.
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

#Preview {
    LiveDuelView()
}
