//
//  EmbeddingAssetLoader.swift
//  Hunch
//
//  1.9 — On-Demand Resources delivery for our bundled word embeddings.
//
//  The problem it solves: shipping FR/IT/DE/ES embeddings *inside* the binary
//  would bloat a ~40 MB word game to 250–500 MB. Instead each language's model is
//  an On-Demand Resource (~60 MB) tagged `embedding-<lang>` and downloaded only
//  when the player first selects that language.
//
//  How it fits the existing engine: once `beginAccessingResources` grants an ODR
//  pack, its `.mlmodelc` becomes resolvable from `Bundle.main` — exactly where
//  `SemanticEngine.bundledEmbedding` already looks. So this loader's only jobs are
//  (1) drive the download + progress UI, (2) keep the granted request retained so
//  the model stays accessible, and (3) fall back cleanly when a pack can't be
//  fetched (offline) or gets purged under storage pressure. The engine itself needs
//  no async rewrite — `GameViewModel`'s existing vocabulary-retry loop re-creates
//  the engine when the model appears.
//
//  Safe before ODR is configured: if a language isn't in `odrEnabled`, or its model
//  is already present in the binary (the pilot's bundled-in-binary test), the loader
//  reports it available/idle and never touches the network.
//

import Foundation
import Observation

@MainActor
@Observable
final class EmbeddingAssetLoader {

    static let shared = EmbeddingAssetLoader()
    private init() {}

    /// Languages whose ODR pack exists in the current build. Flip each on as its
    /// `embedding-<lang>` tag is added in Xcode (Phase 2 rollout). Until a language
    /// is listed here the loader leaves it alone, so it keeps using Apple's built-in
    /// vectors exactly as before — no spurious download attempts.
    static let odrEnabled: Set<GameLanguage> = [.french, .italian, .german, .spanish]

    enum State: Equatable {
        case idle                    // not managed / not needed (falls back to Apple's)
        case downloading(Double)     // fractionCompleted, 0...1
        case available               // model present (bundled-in-binary or ODR-granted)
        case failed                  // couldn't start/finish — fall back + keyboard hint
    }

    /// Per-language download state (observed by the UI).
    private(set) var states: [GameLanguage: State] = [:]
    /// The language whose download should currently front a modal sheet, if any.
    /// Set only when a real network download begins; cleared on finish/cancel.
    private(set) var promptLanguage: GameLanguage?

    // Retained requests keep granted ODR resources accessible; observations drive
    // the progress bar. Both are cleared per language when the download settles.
    private var requests: [GameLanguage: NSBundleResourceRequest] = [:]
    private var observations: [GameLanguage: NSKeyValueObservation] = [:]

    func state(for language: GameLanguage) -> State { states[language] ?? .idle }

    // MARK: - Naming

    /// ODR tag for a language pack, e.g. "embedding-fr". nil for English.
    private func tag(for language: GameLanguage) -> String? {
        language == .english ? nil : "embedding-\(language.rawValue)"
    }

    /// True if the compiled model is already resolvable from the main bundle —
    /// either bundled-in-binary, or an ODR pack we've already been granted.
    private func isPresentInBundle(_ language: GameLanguage) -> Bool {
        guard let name = SemanticEngine.bundledResourceName(for: language) else { return false }
        return Bundle.main.url(forResource: name, withExtension: "mlmodelc") != nil
            || Bundle.main.url(forResource: name, withExtension: "mlmodel") != nil
    }

    // MARK: - Public API

    /// Ensure this language's model is available, downloading it via ODR if needed.
    /// Pass `presentModal: true` from an explicit user language switch so a genuine
    /// download surfaces the progress sheet; pass false for silent/background use.
    func ensure(_ language: GameLanguage, presentModal: Bool) {
        // English (and anything without a model name) needs nothing.
        guard tag(for: language) != nil else { states[language] = .available; return }

        // Already usable — bundled-in-binary or previously-granted ODR. No network.
        if isPresentInBundle(language) { states[language] = .available; return }

        // Not an ODR-configured language yet → leave it to Apple's built-in vectors.
        guard Self.odrEnabled.contains(language) else { states[language] = .idle; return }

        // Already downloading → just surface the sheet if asked.
        if case .downloading = state(for: language) {
            if presentModal { promptLanguage = language }
            return
        }

        beginODR(language, presentModal: presentModal)
    }

    /// Pre-fetch every non-English pack (Settings → "Download all languages").
    func preloadAll() {
        for language in GameLanguage.all where language != .english {
            ensure(language, presentModal: false)
        }
    }

    /// Cancel an in-flight download and drop its request (used by the sheet's Cancel).
    func cancel(_ language: GameLanguage) {
        observations[language]?.invalidate()
        observations[language] = nil
        requests[language]?.progress.cancel()
        requests[language] = nil
        states[language] = .idle
        if promptLanguage == language { promptLanguage = nil }
    }

    /// Hide the modal without cancelling — the download continues in the background
    /// and the engine swaps in when it lands (swipe-to-dismiss).
    func dismissPrompt() { promptLanguage = nil }

    // MARK: - ODR

    private func beginODR(_ language: GameLanguage, presentModal: Bool) {
        guard let tag = tag(for: language) else { return }
        let request = NSBundleResourceRequest(tags: [tag])
        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        requests[language] = request

        // Fast path: pack already on device (e.g. downloaded earlier, or via
        // "Download all") → grant without touching the network.
        request.conditionallyBeginAccessingResources { alreadyAvailable in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if alreadyAvailable {
                    self.states[language] = .available
                    return
                }
                // Read the retained request back from storage instead of capturing
                // the non-Sendable NSBundleResourceRequest across the boundary.
                guard let request = self.requests[language] else { return }
                self.startDownload(language, request: request, presentModal: presentModal)
            }
        }
    }

    private func startDownload(_ language: GameLanguage,
                               request: NSBundleResourceRequest,
                               presentModal: Bool) {
        states[language] = .downloading(0)
        if presentModal { promptLanguage = language }

        // KVO on the request's Progress drives the percentage in the sheet.
        observations[language] = request.progress.observe(\.fractionCompleted) { progress, _ in
            let fraction = progress.fractionCompleted
            Task { @MainActor [weak self] in
                guard let self else { return }
                if case .available = self.state(for: language) { return }
                self.states[language] = .downloading(fraction)
            }
        }

        request.beginAccessingResources { error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observations[language]?.invalidate()
                self.observations[language] = nil
                if let error {
                    // Offline / cancelled / storage error → fall back to Apple's
                    // on-demand vectors and the keyboard-hint banner (the safety net).
                    _ = error
                    self.states[language] = .failed
                    self.requests[language] = nil
                } else {
                    // Granted: resources are now resolvable via Bundle.main, and the
                    // retained request keeps them there. GameViewModel's retry loop
                    // rebuilds the engine and picks the model up on its next tick.
                    self.states[language] = .available
                }
                if self.promptLanguage == language { self.promptLanguage = nil }
            }
        }
    }
}
