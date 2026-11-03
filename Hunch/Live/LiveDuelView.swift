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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var hSizeClass
    /// 3.8: the race music switch, right on the race screen.
    @AppStorage("hunch.music") private var musicOn = true
    /// 3.8: the recap's Wicks act out the result once it is on screen.
    @State private var recapShown = false

    /// Localized UI strings for the player's chosen language (3.1).
    private var loc: Loc { Loc(lang: .storedUI) }

    var body: some View {
        NavigationStack {
            ZStack {
                HunchTheme.background(for: myBestScore)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: myBestScore)
                // 3.5: breathes with the race music; draws nothing without it.
                MusicPulseOverlay()
                    .ignoresSafeArea()
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
                // Music mute stays one tap away during the race.
                ToolbarItem(placement: .topBarTrailing) {
                    if model.phase == .playing || model.phase == .finished {
                        Button {
                            musicOn.toggle()
                            if musicOn, model.phase == .playing {
                                RaceMusic.shared.start()
                                RaceMusic.shared.update(remainingMs: model.remainingMs)
                            } else if !musicOn {
                                RaceMusic.shared.stop()
                            }
                        } label: {
                            Image(systemName: musicOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        }
                        .accessibilityLabel(loc.musicToggle)
                        .accessibilityAddTraits(musicOn ? .isSelected : [])
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

    // MARK: Playing (3.8 Race Showdown)
    //
    // One compact two-seat arena on top (never stacked: that breaks the duel),
    // then the latest result and the input, then the scrolling guess history.
    // Every height in the arena is fixed, so an event never moves the input.

    private var playingView: some View {
        VStack(spacing: HunchTheme.Spacing.m) {
            arena
            latestRow
            inputArea
            ScrollView {
                feedSection
                    .padding(.bottom, HunchTheme.Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal, HunchTheme.Spacing.l)
        .padding(.top, HunchTheme.Spacing.s)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        // On GUESS the input takes focus (it was usable all along).
        .task(id: model.faceOff) {
            guard model.faceOff, let c = model.raceClock() else { return }
            let wait = max(0, RaceShowdown.faceOffMs - c.elapsedMs)
            try? await Task.sleep(for: .milliseconds(wait))
            if !Task.isCancelled { focused = true }
        }
    }

    /// Wicks scale down on a phone but their faces stay readable.
    private var seatSize: CGFloat { hSizeClass == .regular ? 96 : 68 }

    private var arena: some View {
        let phase = model.racePhase
        let tint: Double = phase == .finalMinute ? 0.16 : phase == .final15 ? 0.20 : phase == .expired ? 0.08 : 0.10
        let stroke: Color = phase == .final15 ? HunchTheme.Palette.boiling.opacity(0.5)
            : HunchTheme.Palette.keeper.opacity(phase == .finalMinute ? 0.4 : 0.22)
        return VStack(spacing: 2) {
            HStack(alignment: .top, spacing: HunchTheme.Spacing.s) {
                youSeat
                themSeat
            }
            .frame(maxWidth: 420)
            RaceArenaCenter(model: model, loc: loc, reduceMotion: reduceMotion)
        }
        .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(HunchTheme.Palette.keeper.opacity(tint)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(stroke, lineWidth: 1))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: phase)
    }

    /// Local seat: color and face from the latest scored guess, status from the best.
    private var youSeat: some View {
        let latest = model.guesses.first { $0.warmth != nil }?.warmth
        let mood: KeeperMood = latest.map { KeeperMood.forScore($0) } ?? .idle
        let band = RaceShowdown.band(model.youBest, solved: model.youSolved)
        let style = RaceShowdown.dance(model.racePhase)
        let m = model
        let rm = reduceMotion
        return seat(label: loc.raceSeatYou, band: band, count: model.youScoredCount, connected: true,
                    paint: latest == nil ? nil : band.paintScore) {
            KeeperView(mood: mood, size: seatSize, dances: style != nil, danceStyle: style ?? .groove, race: true,
                       cue: model.youCue, cueKind: model.youCueKind, inputFocused: focused,
                       stance: { m.faceOffStance(side: 1, rm: rm) })
        }
    }

    /// Opponent seat: public progress only (OpponentView), painted by band.
    private var themSeat: some View {
        let seatInfo = model.opponentSeat
        let mood: KeeperMood = seatInfo.paintScore.map { KeeperMood.forScore($0) } ?? .idle
        let style = RaceShowdown.dance(model.racePhase)
        let m = model
        let rm = reduceMotion
        return seat(label: opponentLabel, band: seatInfo.band, count: seatInfo.guessCount,
                    connected: seatInfo.connected, paint: seatInfo.paintScore) {
            KeeperView(mood: mood, size: seatSize, dances: style != nil, danceStyle: style ?? .groove, race: true,
                       cue: model.oppCue, cueKind: model.oppCueKind,
                       stance: { m.faceOffStance(side: -1, rm: rm) })
        }
    }

    private func seat<W: View>(label: String, band: RaceShowdown.Band, count: Int, connected: Bool,
                               paint: Double?, green: Bool = false, @ViewBuilder wick: () -> W) -> some View {
        let status = connected ? loc.key(band.key) : loc.raceReconnecting
        let color: Color = (paint == nil || !connected) ? .primary : HunchTheme.color(for: paint!)
        return VStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.heavy)).tracking(1)
                .foregroundStyle(.secondary)
            wick()
            Text(status)
                .font(.caption.weight(.heavy))
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.75)
                .foregroundStyle(color)
                .frame(minHeight: 32)
            Text(loc.liveGuessesCount(count))
                .font(.caption2).monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(green ? HunchTheme.Palette.solved.opacity(0.22) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(green ? HunchTheme.Palette.solved.opacity(0.5) : Color.clear, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(loc.raceSeatVoice(label, status, count))
    }

    /// The latest guess and its heat, in one fixed-height line.
    @ViewBuilder
    private var latestRow: some View {
        if let g = model.guesses.first {
            let color = g.correct ? HunchTheme.Palette.solved
                : (g.warmth == nil ? HunchTheme.Palette.keeper : HunchTheme.color(for: g.warmth ?? 0))
            HStack(spacing: HunchTheme.Spacing.s) {
                Text(g.word).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                Text(Self.heatLabel(warmth: g.warmth, rank: g.rank, correct: g.correct))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(color.opacity(0.14), in: Capsule())
                if let t = model.latestTrajectory { trajectoryPill(t) }
            }
            .frame(height: 32)
        } else {
            Color.clear.frame(height: 32)
        }
    }

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
                    .disabled(model.racePhase == .expired)
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
                .disabled(entry.trimmingCharacters(in: .whitespaces).isEmpty || model.racePhase == .expired)
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
        if correct { return Loc(lang: .storedUI).liveSolvedExcl }
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

    // MARK: Finished (3.8 recap)

    private var finishedView: some View {
        ScrollView {
            if let info = model.recapInfo {
                recapContent(info)
                    .padding(HunchTheme.Spacing.xl)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
            }
        }
        // Let the Wicks start from their race pose, then act out the result.
        .task(id: model.result?.endedAtMs) {
            recapShown = false
            try? await Task.sleep(for: .milliseconds(80))
            recapShown = true
        }
    }

    private func recapContent(_ info: LiveDuelViewModel.RecapInfo) -> some View {
        let r = info.recap
        // Only a seat the server marks solved is green. A local solve plays the
        // solved sequence; a loss gives the opponent a short accent and the
        // local Wick one annoyed side-eye. Timeouts and draws keep both still.
        let youRest: KeeperMood = r.youGuesses == 0 ? .idle
            : KeeperMood.forScore(info.youStartScore ?? (r.youBand == .solved ? RaceShowdown.Band.danger : r.youBand).paintScore)
        let youMood: KeeperMood = r.youGreen && recapShown ? .celebrating : youRest
        let themMood: KeeperMood = r.themGreen ? .celebrating
            : (r.themGuesses == 0 ? .idle : KeeperMood.forScore(r.themBand.paintScore))
        let loss = r.outcome == .loss
        return VStack(spacing: HunchTheme.Spacing.m) {
            HStack(alignment: .top, spacing: HunchTheme.Spacing.s) {
                seat(label: loc.raceSeatYou, band: r.youBand, count: r.youGuesses, connected: true,
                     paint: r.youGuesses == 0 ? nil : r.youBand.paintScore, green: r.youGreen) {
                    KeeperView(mood: youMood, size: seatSize, race: true,
                               cue: loss && recapShown ? 1 : 0, cueKind: "repeat",
                               stance: loss ? { () -> RaceShowdown.Stance? in RaceShowdown.sideEye } : nil)
                }
                seat(label: opponentLabel, band: r.themBand, count: r.themGuesses, connected: true,
                     paint: r.themGuesses == 0 ? nil : r.themBand.paintScore, green: r.themGreen) {
                    KeeperView(mood: themMood, size: seatSize, race: true,
                               cue: r.themGreen && recapShown ? 1 : 0, cueKind: "leap")
                }
            }
            .frame(maxWidth: 420)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(HunchTheme.Palette.keeper.opacity(0.08)))

            Text(recapHeadline(r.headline))
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(r.outcome == .win ? HunchTheme.Palette.solved : Color.primary)
            if let res = model.result, r.outcome != .void {
                Text(outcomeSubtitle(res))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let word = info.word {
                VStack(spacing: 2) {
                    Text(loc.liveTheWordWas).font(.subheadline).foregroundStyle(.secondary)
                    Text(word).font(HunchTheme.Fonts.revealWord)
                    if let theirs = info.opponentWord {
                        Text(loc.raceTheirWord(theirs.word, theirs.language))
                            .font(.footnote).foregroundStyle(.secondary).padding(.top, 2)
                    }
                }
            }
            // Finish time when someone solved; a timeout already says so above.
            Text((r.finishMs.map { "\(loc.raceRecapFinish) \(RaceShowdown.fmtElapsed($0)) · " } ?? "")
                 + "\(loc.raceRecapLeadChanges) \(info.leadChanges)")
                .font(.subheadline).foregroundStyle(.secondary)

            Grid(alignment: .center, horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    Color.clear.frame(height: 1)
                    Text(loc.raceSeatYou).font(.caption2.weight(.heavy)).foregroundStyle(.secondary)
                    Text(loc.raceSeatOpponent).font(.caption2.weight(.heavy)).foregroundStyle(.secondary)
                }
                GridRow {
                    Text(loc.raceRecapGuesses).gridColumnAlignment(.leading).foregroundStyle(.secondary)
                    Text("\(r.youGuesses)").bold()
                    Text("\(r.themGuesses)").bold()
                }
                GridRow {
                    Text(loc.raceRecapBest).foregroundStyle(.secondary)
                    Text(loc.key(r.youBand.key)).font(.caption.weight(.bold)).multilineTextAlignment(.center)
                    Text(loc.key(r.themBand.key)).font(.caption.weight(.bold)).multilineTextAlignment(.center)
                }
                if !info.youTrail.isEmpty {
                    // The opponent trail only shows when this device saw their progress live.
                    GridRow {
                        Text(loc.raceRecapTrail).foregroundStyle(.secondary)
                        trailView(info.youTrail)
                        if info.themTrail.isEmpty { Color.clear.frame(height: 1) } else { trailView(info.themTrail) }
                    }
                }
            }
            .font(.subheadline)
            .frame(maxWidth: 420)

            Button {
                Haptics.selection()
                model.playAgain()
            } label: {
                Text(model.waitingRematch ? loc.raceWaitingRematch
                     : (model.isFriendMatch ? loc.raceRematch : loc.raceSomeoneNew))
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(r.outcome == .win ? HunchTheme.Palette.solved : HunchTheme.Palette.keeper)
            .disabled(model.waitingRematch)

            Button {
                Haptics.selection()
                let text = r.outcome == .win ? loc.raceShareWon(r.youGuesses)
                    : (r.outcome == .loss ? loc.raceShareLost : loc.raceShareDraw)
                ShareSheet.present([text, URL(string: "https://guesswick.com")!])
            } label: {
                Text(loc.raceShareResult).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(HunchTheme.Palette.keeper)

            Button(loc.liveDone) { model.leave(); dismiss() }
                .buttonStyle(.borderless)
        }
    }

    private func recapHeadline(_ h: RaceShowdown.Headline) -> String {
        switch h {
        case .turnedGreen:   return loc.raceYouTurnedGreen
        case .gotThereFirst: return loc.raceTheyGotThere
        case .won:           return loc.liveYouWin
        case .lost:          return loc.liveYouLost
        case .draw:          return loc.liveDraw
        case .void:          return loc.liveBothDropped
        }
    }

    /// A heat trail as dots, oldest first, painted by band (no scores).
    private func trailView(_ bands: [RaceShowdown.Band]) -> some View {
        let capped = RaceShowdown.capTrail(bands)
        return HStack(spacing: 3) {
            ForEach(Array(capped.enumerated()), id: \.offset) { _, b in
                Circle()
                    .fill(HunchTheme.color(for: b.paintScore))
                    .frame(width: 10, height: 10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(capped.map { loc.key($0.key) }.joined(separator: ", "))
    }

    // MARK: Disconnected

    /// A dropped race is a network problem, never drawn as a loss.
    private var disconnectedView: some View {
        VStack(spacing: HunchTheme.Spacing.m) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(HunchTheme.Palette.keeper)
                .accessibilityHidden(true)
            Text(loc.raceConnLostTitle).font(.title2.bold())
            if model.snapshot != nil {
                Text(loc.raceConnLostBody)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
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

    /// The opponent seat's label. Anonymous for a person; a practice flame
    /// (a bot) is always labeled honestly.
    private var opponentLabel: String {
        switch model.opponentKind {
        case .bot:   return loc.livePracticeFlame.uppercased()
        case .ghost: return loc.liveGhost.uppercased()
        default:     return loc.raceSeatOpponent
        }
    }

    private func outcomeSubtitle(_ r: MatchResult) -> String {
        switch r.reason {
        case .solved:  return model.didIWin ? loc.liveFirstToWord : loc.liveOppFirst
        case .timeout: return loc.liveTimeUpWarmest
        case .forfeit: return model.didIWin ? loc.liveOppLeft : loc.liveYouLeft
        case .void:    return loc.liveBothDropped
        }
    }

}

// MARK: - Race Showdown arena center (3.8)

/// The face-off, the lead, the clock and the momentum slot, redrawn every
/// frame from the server clock. Its height never changes, so nothing below it
/// moves. Reduced Motion: opacity only, no slide or scale.
struct RaceArenaCenter: View {
    @ObservedObject var model: LiveDuelViewModel
    let loc: Loc
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let now = ctx.date.timeIntervalSince1970 * 1000
            let c = model.raceClock(now)
            let remaining = c?.remainingMs ?? 0
            let elapsed = c?.elapsedMs ?? 0
            let phase: RaceShowdown.Phase = c == nil ? .opening : RaceShowdown.phase(remainingMs: remaining, hasResult: false)
            let step: Int? = model.faceOff && c != nil ? RaceShowdown.faceOffStep(elapsed) : nil
            VStack(spacing: 0) {
                ZStack {
                    live(remaining: remaining, phase: phase, hasClock: c != nil)
                        .opacity(step == nil ? 1 : 0)
                    faceOffView(step: step, elapsed: elapsed)
                        .opacity(step == nil ? 0 : 1)
                }
                momentum(now: now)
            }
        }
    }

    // Lead and clock.
    private func live(remaining: Int, phase: RaceShowdown.Phase, hasClock: Bool) -> some View {
        let lead = model.raceFrame?.lead ?? .tied
        let pulse = RaceShowdown.timerPulse(remaining, rm: reduceMotion)
        let grow = phase == .final15 ? RaceShowdown.timerGrow : 1
        let count = RaceShowdown.finalCount(remaining)
        let since = Double((1000 - remaining % 1000) % 1000)
        let leadColor: Color = lead == .you ? HunchTheme.Palette.hot : (lead == .them ? HunchTheme.Palette.cold : .primary)
        let timerText = !hasClock ? " " : (phase == .expired ? loc.raceTimeUpWaiting : RaceShowdown.fmtClock(remaining))
        return VStack(spacing: 0) {
            ZStack {
                Text(loc.key(lead.key))
                    .id(lead)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: reduceMotion ? 0 : 5)).animation(.easeOut(duration: 0.16).delay(0.1)),
                        removal: .opacity.combined(with: .offset(y: reduceMotion ? 0 : -5)).animation(.easeIn(duration: 0.1))))
                    .font(.subheadline.weight(.black)).tracking(1)
                    .foregroundStyle(leadColor)
                    .brightness(phase == .finalMinute || phase == .final15 ? 0.08 : 0)
            }
            .frame(height: 22)
            .animation(.easeOut(duration: 0.16), value: lead)
            Text(timerText)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(phase == .final15 ? HunchTheme.Palette.boiling : Color.primary)
                .opacity((phase == .opening ? 0.85 : 1) * pulse.opacity)
                .scaleEffect(grow * pulse.scale)
                .frame(height: 40)
                .overlay(alignment: .trailing) {
                    if let n = count {
                        Text("\(n)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(HunchTheme.Palette.boiling)
                            .scaleEffect(reduceMotion ? 1 : 1 + 0.16 * (1 - WickMotion.smoother(since / 300)))
                            .opacity(reduceMotion ? WickMotion.smoother(since / 200) : 1)
                            .offset(x: 52)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityAddTraits(.updatesFrequently)
        }
        .accessibilityElement(children: .combine)
    }

    // 3, 2, 1, GUESS over the first seconds of the real clock.
    private func faceOffView(step: Int?, elapsed: Int) -> some View {
        let start = step.map { $0 == 0 ? RaceShowdown.faceOffMs : (3 - $0) * 1000 } ?? 0
        let e = Double(max(0, elapsed - start))
        return VStack(spacing: 2) {
            Text(loc.raceFaceOffTitle)
                .font(.caption.weight(.black)).tracking(0.6)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.8)
            Text(step == 0 ? loc.raceFaceOffGo : "\(step ?? 3)")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(HunchTheme.Palette.keeper)
                .scaleEffect(reduceMotion ? 1 : 1 + 0.16 * (1 - WickMotion.smoother(e / 260)))
                .opacity(reduceMotion ? WickMotion.smoother(e / 200) : 1)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 62)
    }

    // One slot under the clock: an event shows for 800 ms and never covers input.
    private func momentum(now: Double) -> some View {
        let ev = model.raceFrame?.event
        let age = now - (model.raceFrame?.eventAt ?? 0)
        let u = age / RaceShowdown.momentumShowMs
        let alpha = ev == nil || u >= 1 ? 0 : (u < 0.18 ? u / 0.18 : (u > 0.78 ? (1 - u) / 0.22 : 1))
        let color: Color
        switch ev {
        case .youHotter: color = HunchTheme.Palette.hot
        case .closingIn: color = HunchTheme.Palette.cold
        case .deadHeat, .suddenHeat: color = HunchTheme.Palette.coin
        case .final15: color = HunchTheme.Palette.boiling
        default: color = HunchTheme.Palette.keeper
        }
        return Text(ev.map { loc.key($0.key) } ?? " ")
            .font(.subheadline.weight(.black)).tracking(1)
            .foregroundStyle(color)
            .lineLimit(1).minimumScaleFactor(0.7)
            .opacity(max(0, alpha))
            .scaleEffect(reduceMotion || u >= 0.18 ? 1 : 0.94 + 0.06 * (u / 0.18))
            .frame(height: 22)
            .accessibilityHidden(true)
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
