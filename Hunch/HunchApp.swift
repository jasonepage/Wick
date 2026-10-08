//
//  HunchApp.swift
//  Hunch
//

import SwiftUI

@main
struct HunchApp: App {
    @State private var game: GameViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // ORDER MATTERS. `GameViewModel.init` reads the streak, coins, stats and
        // achievements straight out of UserDefaults, so iCloud has to be merged
        // in FIRST — otherwise a fresh install shows a zeroed profile until the
        // next launch. This is why `game` is initialised here rather than inline.
        CloudSync.bootstrap()
        _game = State(wrappedValue: GameViewModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(game)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .background, .inactive:
                        // Last safe moment to mirror progression off this device.
                        CloudSync.push()
                    case .active:
                        // Re-arm the streak warning: the day may have rolled over
                        // while the app was closed, which changes both whether the
                        // warning applies and when it should fire.
                        game.refreshStreakReminder()
                    @unknown default:
                        break
                    }
                }
                // Deep links, in priority order:
                //  • 3.1 LIVE invite  https://guesswick.com/p/<code>?m=race
                //    (or wick://race/<code>) → opens the live screen and joins.
                //    Dare links (retired in 3.3) are ignored and land on Home.
                //  • Legacy offline duel  wick://duel/<code>  or
                //    https://jasonepage.github.io/wick/d/?c=<code>  → offline duel.
                // Both need the Associated Domains entitlement + the AASA on the host;
                // pasting a code in-app works without either.
                .onOpenURL { url in
                    // Ghost race:  https://guesswick.com/r/<run>  (AASA claims "/r/*"),
                    // the legacy query form  https://guesswick.com/?r=<run>, and the
                    // custom-scheme fallback  wick://r/<run>. The scheme matters: a
                    // Universal Link does not fire from Safari's address bar, from a
                    // page already on guesswick.com, or while iOS holds a stale
                    // association, and the web challenge screen offers wick:// for
                    // exactly those cases. Checked first because a race link is the
                    // most specific shape of the three handlers below.
                    if let run = Ghost.from(url: url) {
                        Events.track(.raceLinkOpened, n: run.mode == .daily ? run.ref : nil)
                        game.pendingGhostRace = run
                        return
                    }
                    if let invite = LiveInvite.from(url: url) {
                        game.pendingLiveInvite = invite
                        return
                    }
                    guard let code = Self.duelCode(from: url),
                          let payload = DuelCode.decodeDuel(code),
                          payload.mode == .race else { return }  // 3.3: Dare-mode codes land on Home
                    game.startDuel(payload)
                }
        }
    }

    /// Pull the duel code out of a wick:// scheme link or a Universal Link —
    /// either `…?c=<code>` (query) or `…/<code>` (last path component).
    private static func duelCode(from url: URL) -> String? {
        let scheme = url.scheme?.lowercased()
        guard scheme == "wick" || scheme == "https" else { return nil }
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let c = comps.queryItems?.first(where: { $0.name == "c" })?.value,
           DuelCode.looksLikeCode(c) {
            return c
        }
        let parts = url.pathComponents.filter { $0 != "/" }
        if let last = parts.last, DuelCode.looksLikeCode(last) { return last }
        return nil
    }
}
