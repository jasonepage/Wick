//
//  ArchiveView.swift
//  Hunch
//
//  Replay past dailies. Every daily word is deterministic from its day index
//  (WordBank.dailyEntry / DailyWords.daily), so the archive needs no stored
//  words — it just lists past days and seeds a round from the chosen one via
//  `GameViewModel.startArchive`. Per-day status comes from RoundHistory.
//
//  Archive rounds are ephemeral: they never overwrite today's board and never
//  award coins, streak, or stats (see GameViewModel).
//

import SwiftUI

struct ArchiveView: View {
    @Environment(GameViewModel.self) private var game
    @Environment(\.dismiss) private var dismiss

    /// Past daily day-indexes, newest first. Today itself is played on the main
    /// screen, so the archive runs launch-day … yesterday.
    private var days: [Int] {
        let yesterday = WordBank.dayIndex() - 1
        let first = WordBank.launchDayIndex
        guard yesterday >= first else { return [] }
        return Array(stride(from: yesterday, through: first, by: -1))
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if days.isEmpty {
                    emptyState
                } else {
                    List(days, id: \.self) { day in
                        Button { play(day) } label: { row(for: day) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(game.loc.archive)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(game.loc.done) { dismiss() }
                }
            }
        }
    }

    private func play(_ day: Int) {
        game.startArchive(dayIndex: day)
        dismiss()
    }

    @ViewBuilder
    private func row(for day: Int) -> some View {
        let record = RoundHistory.outcome(dayIndex: day)
        HStack(spacing: HunchTheme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.loc.dailyTitle(WordBank.dailyNumber(forDayIndex: day)))
                    .font(.headline)
                Text(Self.dateFormatter.string(from: WordBank.date(forDay: day)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusIcon(for: record)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func statusIcon(for record: RoundRecord?) -> some View {
        if let record, record.solved {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(HunchTheme.Palette.solved)
        } else if record != nil {
            // Finished but not solved → the player revealed it.
            Image(systemName: "flag.fill")
                .foregroundStyle(.secondary)
        } else {
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: HunchTheme.Spacing.m) {
            Image(systemName: "calendar")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(game.loc.archiveEmpty)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(HunchTheme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
