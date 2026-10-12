//
//  ReplayExportView.swift
//  Hunch
//
//  Solve Replay (3.4): the sheet. Builds the video on the phone, plays a
//  looping preview, and saves it to Photos. The player posts it to TikTok,
//  Reels or Shorts themselves; the app never posts anything.
//
//  Photos access is "add only": Wick can save the video but can never see the
//  player's library.
//

import AVKit
import Photos
import SwiftUI
import UIKit

@MainActor
@Observable
final class ReplayExportModel {

    enum Phase: Equatable {
        case rendering(Double)
        case failed
        case ready
        case saving
        case saveFailed
        case saved
        case denied
    }

    private(set) var phase: Phase = .rendering(0)
    private(set) var player: AVQueuePlayer?

    private let request: ReplayRequest
    private var looper: AVPlayerLooper?
    private var renderJob: Task<Void, Error>?
    private var videoURL: URL?

    init(request: ReplayRequest) {
        self.request = request
    }

    /// Starts (or restarts after a failure) the offscreen render.
    func start() {
        guard renderJob == nil, videoURL == nil else { return }
        phase = .rendering(0)
        let request = self.request
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(request.fileName)
            .appendingPathExtension("mp4")
        let progress: @Sendable (Double) -> Void = { [model = self] p in
            Task { @MainActor in model.reportProgress(p) }
        }
        let job = Task.detached(priority: .userInitiated) {
            try await ReplayRenderer.render(request, to: url, progress: progress)
        }
        renderJob = job
        Task {
            do {
                try await job.value
                finished(url)
            } catch is CancellationError {
                // Sheet closed mid-render; nothing to show.
            } catch {
                phase = .failed
            }
            renderJob = nil
        }
    }

    /// Stops any render and cleans up the temporary file.
    func cancel() {
        renderJob?.cancel()
        renderJob = nil
        player?.pause()
        looper = nil
        player = nil
        if let url = videoURL { try? FileManager.default.removeItem(at: url) }
        videoURL = nil
    }

    func save() async {
        guard let url = videoURL else { return }
        phase = .saving
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            phase = .denied
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
            phase = .saved
            Haptics.success()
        } catch {
            phase = .saveFailed
        }
    }

    private func reportProgress(_ p: Double) {
        if case .rendering = phase { phase = .rendering(p) }
    }

    private func finished(_ url: URL) {
        videoURL = url
        let queue = AVQueuePlayer()
        queue.isMuted = true
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        player = queue
        queue.play()
        phase = .ready
    }
}

struct ReplayExportView: View {
    let loc: Loc
    @State private var model: ReplayExportModel
    @Environment(\.dismiss) private var dismiss

    init(request: ReplayRequest, loc: Loc) {
        self.loc = loc
        _model = State(initialValue: ReplayExportModel(request: request))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: HunchTheme.Spacing.l) {
                stage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                controls
            }
            .padding(HunchTheme.Spacing.l)
            .readableWidth(520)
            .navigationTitle(loc.replayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.done) { dismiss() }
                }
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.cancel() }
    }

    // MARK: Stage: progress, failure, or the video

    @ViewBuilder
    private var stage: some View {
        switch model.phase {
        case .rendering(let p):
            VStack(spacing: HunchTheme.Spacing.l) {
                KeeperView(mood: .thinking, size: 84)
                Text(loc.replayMaking)
                    .font(.headline)
                ProgressView(value: p)
                    .tint(HunchTheme.Palette.keeper)
                    .frame(maxWidth: 240)
            }
        case .failed:
            VStack(spacing: HunchTheme.Spacing.m) {
                KeeperView(mood: .defeated, size: 72)
                Text(loc.replayFailed)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button(loc.replayTryAgain) { model.start() }
                    .buttonStyle(.bordered)
            }
        default:
            if let player = model.player {
                VideoPlayer(player: player)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: HunchTheme.Radius.card, style: .continuous))
                    .accessibilityLabel(loc.replayTitle)
            }
        }
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        switch model.phase {
        case .ready, .saving, .saveFailed:
            Button {
                Feedback.play(.selection)
                Task { await model.save() }
            } label: {
                Label(model.phase == .saving ? loc.replaySaving : loc.replaySave,
                      systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(HunchTheme.Palette.keeper)
            .disabled(model.phase == .saving)
            if model.phase == .saveFailed {
                Text(loc.replaySaveFailed)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .saved:
            VStack(spacing: HunchTheme.Spacing.s) {
                Label(loc.replaySaved, systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(HunchTheme.Palette.solved)
                Text(loc.replaySavedHint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .denied:
            VStack(spacing: HunchTheme.Spacing.m) {
                Text(loc.replayDenied)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(loc.replayOpenSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        case .rendering, .failed:
            EmptyView()
        }
    }
}
