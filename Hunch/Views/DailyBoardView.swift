// SPDX-License-Identifier: MPL-2.0
//
//  DailyBoardView.swift
//  Wick
//
//  3.6: today's race board. Opened from the solved card and from Stats.
//  Top 50 for today's daily, your own row pinned on top, and a button to
//  roll a new auto name. See DailyBoard.swift for how results get here.
//

import SwiftUI

struct DailyBoardView: View {
    @Environment(GameViewModel.self) private var game
    @Environment(\.dismiss) private var dismiss
    @State private var board = DailyBoard.shared
    @State private var renaming = false

    private var n: Int { WordBank.dailyNumber() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HunchTheme.Spacing.l) {
                    youCard
                    Text(game.loc.boardRules)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    listCard
                }
                .padding(HunchTheme.Spacing.l)
                .readableWidth()
            }
            .refreshable { await board.refresh(n: n) }
            .navigationTitle(game.loc.boardTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(game.loc.done) { dismiss() }
                }
            }
            .task { await board.refresh(n: n) }
        }
    }

    // MARK: - You

    private var youCard: some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
            if let me = board.myRow, let snap = board.snapshot {
                Text(game.loc.boardRankLine(me.rank, snap.total))
                    .font(.title2.bold())
                HStack(spacing: HunchTheme.Spacing.m) {
                    stat(me.g, label: game.loc.boardColGuesses, extra: me.h)
                    stat(text: BoardFormat.time(ms: me.ms), label: game.loc.boardColTime)
                }
            } else {
                Text(game.loc.boardSolveFirst)
                    .font(.headline)
            }
            if let name = board.myName {
                HStack {
                    Text(game.loc.boardRacingAs(name))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Feedback.play(.selection)
                        renaming = true
                        Task {
                            await board.rerollName(n: n)
                            renaming = false
                        }
                    } label: {
                        Label(game.loc.boardNewName, systemImage: "dice.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(HunchTheme.Palette.keeper)
                    .disabled(renaming)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HunchTheme.Spacing.l)
        .hunchCard(tint: HunchTheme.Palette.keeper, radius: 18)
    }

    private func stat(_ g: Int, label: String, extra hints: Int) -> some View {
        stat(text: hints > 0 ? "\(g + hints)" : "\(g)", label: label)
    }

    private func stat(text: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text).font(HunchTheme.Fonts.bigNumber)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Board

    @ViewBuilder
    private var listCard: some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
            HStack {
                Text(game.loc.boardPlayers(board.snapshot?.total ?? 0))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(game.loc.boardColGuesses).frame(width: 64, alignment: .trailing)
                Text(game.loc.boardColTime).frame(width: 64, alignment: .trailing)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let snap = board.snapshot {
                if snap.top.isEmpty {
                    Text(game.loc.boardEmpty)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, HunchTheme.Spacing.m)
                } else {
                    ForEach(snap.top, id: \.id) { row in
                        if row.rank > 1 { Divider() }
                        boardRow(row, isMe: row.id == board.myId(n))
                    }
                }
            } else if board.loading {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if board.failed {
                Text(game.loc.boardOffline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(HunchTheme.Spacing.l)
        .hunchCard(radius: 18)
    }

    private func boardRow(_ row: BoardRow, isMe: Bool) -> some View {
        HStack(spacing: HunchTheme.Spacing.m) {
            Text("\(row.rank)")
                .font(.subheadline.monospacedDigit().weight(row.rank <= 3 ? .bold : .regular))
                .foregroundStyle(row.rank <= 3 ? HunchTheme.Palette.coin : .secondary)
                .frame(minWidth: 26, alignment: .trailing)
            Text(BoardFormat.flag(row.lang))
            Text(row.name)
                .font(.body.weight(isMe ? .bold : .regular))
                .lineLimit(1)
            if isMe {
                Text(game.loc.boardYou)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(HunchTheme.Palette.keeper.opacity(0.2), in: Capsule())
                    .foregroundStyle(HunchTheme.Palette.keeper)
            }
            Spacer(minLength: HunchTheme.Spacing.s)
            HStack(spacing: 2) {
                Text("\(row.g + row.h)")
                if row.h > 0 {
                    Text("(\(row.h)💡)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .font(.body.monospacedDigit())
            .frame(width: 64, alignment: .trailing)
            Text(BoardFormat.time(ms: row.ms))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DailyBoardView().environment(GameViewModel())
}
