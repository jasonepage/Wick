//
//  GhostStripView.swift
//  Hunch
//
//  The opponent strip for a Ghost Race — the iOS twin of `.opp-strip` /
//  `.ghost-strip` in wick-web. It deliberately looks like a live opponent,
//  because the point of ghost racing is to grow the population for live racing:
//  the two should be indistinguishable to a player.
//
//  Shows, for the sender, ONLY: how far along they are right now, the heat band
//  they had reached, and one pip per action — filled if it improved their best,
//  hollow if it didn't, "?" if they asked Wick. Never a word, never a question,
//  never the future.
//

import SwiftUI

struct GhostStripView: View {
    let run: GhostRun
    /// The round's language table — the strip is chrome, so it speaks whatever
    /// the round speaks, not whatever the sender's device spoke.
    let loc: Loc
    /// Seconds into the race. Drive this from a TimelineView so it ticks.
    let elapsed: TimeInterval
    /// Freeze at the end of the round so the final state stays on screen.
    let finished: Bool

    private var reachedIndex: Int {
        let ms = finished ? run.durationMs + 1 : Int(elapsed * 1000)
        var idx = -1
        for (i, a) in run.actions.enumerated() {
            if a.t <= ms { idx = i } else { break }
        }
        return idx
    }

    private var current: GhostAction? {
        let i = reachedIndex
        return i >= 0 ? run.actions[i] : nil
    }

    private var bandColor: Color {
        guard let c = current else { return HunchTheme.Palette.neutral }
        // Representative score per band, so the colour matches the web strip.
        let score: [Double] = [4, 12, 22, 36, 50, 75, 100]
        return HunchTheme.color(for: score[min(max(c.band, 0), 6)])
    }

    /// The canonical HunchTheme band tokens, in band order. `loc.heat` turns
    /// them into the player's language; they are the same seven tokens the
    /// live board and the web strip use, so all three read alike.
    private static let bandTokens = ["Freezing", "Cold", "Cool", "Warm", "Hot", "Boiling", "Solved!"]

    private var bandLabel: String {
        guard let c = current else { return loc.ghostWaiting }
        return loc.heat(Self.bandTokens[min(max(c.band, 0), 6)])
    }

    private var isDone: Bool {
        reachedIndex >= run.actions.count - 1 && run.solved
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HunchTag(text: "👻 " + loc.ghostRival, color: HunchTheme.Palette.keeper)
                Spacer(minLength: 0)
                Text(isDone
                     ? loc.ghostFinished(Ghost.formatDuration(ms: run.durationMs))
                     : bandLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // Progress toward Solved, in band steps — mirrors the web mini-bar.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(bandColor)
                        .frame(width: geo.size.width * fillFraction)
                }
            }
            .frame(height: 8)
            .animation(.easeOut(duration: 0.25), value: reachedIndex)

            // One pip per action taken so far. Never shows the future.
            HStack(spacing: 4) {
                ForEach(0...max(0, reachedIndex), id: \.self) { i in
                    if reachedIndex >= 0 { pip(run.actions[i]) }
                }
            }
            .frame(height: 12)
        }
        .padding(.horizontal, HunchTheme.Spacing.m)
        .padding(.vertical, HunchTheme.Spacing.s)
        .hunchCard(tint: HunchTheme.Palette.keeper, radius: HunchTheme.Radius.field)
    }

    private var fillFraction: CGFloat {
        guard let c = current else { return 0 }
        return CGFloat(min(max(Double(c.band + 1) / 7.0, 0), 1))
    }

    @ViewBuilder
    private func pip(_ a: GhostAction) -> some View {
        if a.kind == 1 {
            Circle()
                .fill(HunchTheme.Palette.keeper.opacity(0.35))
                .frame(width: 11, height: 11)
                .overlay(Text("?").font(.system(size: 7, weight: .black)).foregroundStyle(.white))
        } else if a.improved == 1 {
            Circle()
                .fill(HunchTheme.Palette.flame)
                .frame(width: 11, height: 11)
                .shadow(color: HunchTheme.Palette.flame.opacity(0.5), radius: 4)
        } else {
            Circle()
                .strokeBorder(Color.primary.opacity(0.28), lineWidth: 1.5)
                .frame(width: 11, height: 11)
        }
    }
}

/// Drop this into the board above the hero. TimelineView drives the clock so the
/// ghost keeps moving whether or not the player does — which is what makes it a
/// race rather than a puzzle with a scoreboard.
struct GhostStripLive: View {
    let run: GhostRun
    let startedAt: Date?
    let finished: Bool
    let loc: Loc

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
            GhostStripView(
                run: run,
                loc: loc,
                elapsed: startedAt.map { ctx.date.timeIntervalSince($0) } ?? 0,
                finished: finished
            )
        }
    }
}
