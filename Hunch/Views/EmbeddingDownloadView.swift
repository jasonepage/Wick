//
//  EmbeddingDownloadView.swift
//  Hunch
//
//  1.9 — the modal shown the first time a player selects a language whose word
//  dictionary (embedding) still needs downloading via On-Demand Resources.
//  Presented from ContentView while `assetLoader.promptLanguage != nil`; it
//  dismisses itself when the download finishes (the loader clears the prompt) or
//  when the player cancels (reverting to a language that already scores).
//

import SwiftUI

struct EmbeddingDownloadView: View {
    @Environment(GameViewModel.self) private var game
    /// The language being downloaded (drives copy + flag). Passed by the presenter.
    let language: GameLanguage

    private var state: EmbeddingAssetLoader.State { game.assetLoader.state(for: language) }

    var body: some View {
        VStack(spacing: HunchTheme.Spacing.l) {
            Text(language.flag)
                .font(.system(size: 52))
                .padding(.top, HunchTheme.Spacing.xl)

            Text(language.nativeName)
                .font(HunchTheme.Fonts.cardTitle)

            Text(game.loc.downloadDictionaryTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            progress
                .padding(.vertical, HunchTheme.Spacing.s)

            Text(game.loc.downloadDictionaryBlurb)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HunchTheme.Spacing.l)

            Spacer(minLength: 0)

            Button(role: .cancel) {
                game.cancelPendingDownload()
            } label: {
                Text(game.loc.cancelDownload)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HunchTheme.Spacing.m)
            }
            .buttonStyle(.plain)
            .foregroundStyle(HunchTheme.Palette.neutral)
        }
        .padding(HunchTheme.Spacing.l)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private var progress: some View {
        switch state {
        case .downloading(let fraction) where fraction > 0:
            VStack(spacing: HunchTheme.Spacing.xs) {
                ProgressView(value: fraction)
                    .tint(HunchTheme.Palette.keeper)
                    .padding(.horizontal, HunchTheme.Spacing.xl)
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(HunchTheme.Fonts.bigNumber)
                    .foregroundStyle(HunchTheme.Palette.keeper)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        case .failed:
            Label(game.loc.downloadDictionaryFailed, systemImage: "wifi.exclamationmark")
                .font(.footnote)
                .foregroundStyle(HunchTheme.Palette.boiling)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HunchTheme.Spacing.l)
        default:
            // Just starting / indeterminate.
            ProgressView()
                .controlSize(.large)
                .tint(HunchTheme.Palette.keeper)
        }
    }
}
