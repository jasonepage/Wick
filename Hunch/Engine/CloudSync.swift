//
//  CloudSync.swift
//  Hunch
//
//  Mirrors the player's *progression* into iCloud's key-value store, so a new
//  phone — or a delete-and-reinstall — doesn't silently wipe the streak, the
//  stats, the achievements, the wardrobe, and coins the player PAID for.
//
//  Before this file, every one of those lived in `UserDefaults.standard` and
//  nowhere else. For a game whose entire retention mechanic is a flame counter,
//  that made the flame a property of the handset rather than of the player.
//
//  WHY KVS AND NOT AN ACCOUNT
//  --------------------------
//  The app has no accounts and no server dependency for single-player (the
//  "moat" constraint, C1/C2 in the planning docs). `NSUbiquitousKeyValueStore`
//  keeps it that way: it is the player's own iCloud, requires no sign-up flow,
//  no backend, no PII, and degrades to a silent no-op when the player isn't
//  signed into iCloud. Nothing here ever blocks play.
//
//  ⚠️ ENTITLEMENT REQUIRED. This needs `com.apple.developer.ubiquity-kvstore-identifier`
//  (added to `Hunch.entitlements`) AND the iCloud capability with *Key-value
//  storage* ticked on the App ID. In Xcode: target → Signing & Capabilities →
//  + Capability → iCloud → check "Key-value storage". Without it the build
//  fails to sign; the CODE is still safe (every call no-ops), but the profile
//  won't match.
//
//  WHAT IS NOT SYNCED, AND WHY
//  ---------------------------
//  • The in-progress board (`hunch.dailyState.*`) — resuming a half-played
//    round on another device is a race condition with no upside.
//  • `RoundHistory` — capped at 5000 records, which can approach the 1 MB KVS
//    ceiling. It is a local archive, not progression.
//  • Device preferences: reminder time, language, Learn mode, feed sort,
//    seen-the-tutorial. These are properties of the handset, not the player.
//
//  MERGE RULES — the interesting part
//  ----------------------------------
//  Two devices can both write. There is no server to arbitrate, so each key
//  gets a rule that converges without one:
//
//  • max      — bestStreak, solves, totalGuesses, lastBonusDay. Monotonic;
//               taking the larger can never destroy progress. (lastBonusDay as
//               max also stops the daily bonus being farmed across devices.)
//  • min      — bestGuessCount. Lower is better; 0 means "none yet" and loses.
//  • union    — achievements, wardrobe owned. Earned things never un-earn.
//  • paired   — streak + lastSolvedDay move TOGETHER, decided by the later
//               lastSolvedDay. Merging them independently is the classic bug:
//               you would take device A's streak of 9 next to device B's
//               lastSolvedDay, and the next solve would read as consecutive
//               when it wasn't.
//  • revision — coins and equipped outfit. Spendable/mutable state can't use
//               max (that would let a two-device player refill by syncing) so
//               it's last-writer-wins on a monotonic `rev` counter. On a fresh
//               install local rev is 0 and any cloud value wins, which is the
//               case that matters: restore.
//

import Foundation

@MainActor
enum CloudSync {

    // MARK: - Mirrored keys

    private static let kCoins          = "hunch.coins"
    private static let kStreak         = "hunch.streak"
    private static let kLastSolvedDay  = "hunch.lastSolvedDay"
    private static let kLastBonusDay   = "hunch.lastBonusDay"
    private static let kSolves         = "hunch.solves"
    private static let kBestStreak     = "hunch.bestStreak"
    private static let kTotalGuesses   = "hunch.totalGuesses"
    private static let kBestGuess      = "hunch.bestGuessCount"
    private static let kAchievements   = "hunch.achievements"
    private static let kWardrobeOwned  = "hunch.wardrobe.owned"
    private static let kWardrobeEquip  = "hunch.wardrobe.equipped"
    /// Monotonic write counter, local and remote, for the revision rule.
    private static let kRev            = "hunch.cloud.rev"

    /// Called on the main actor after a merge that actually changed local
    /// values, so the view model can re-read them. Set by `GameViewModel.init`,
    /// mirroring how `CoinStore.onGrant` and `WardrobeStore.spend` reach it —
    /// a plain closure rather than a `@Sendable` NotificationCenter block.
    static var onMerge: (() -> Void)?

    private static var observing = false

    // MARK: - Lifecycle

    /// Pulls whatever iCloud already has into `UserDefaults` and starts
    /// listening for later arrivals.
    ///
    /// **Call this before `GameViewModel()` is constructed** — the view model
    /// reads every one of these keys in its `init`, so merging afterwards would
    /// leave the model holding the pre-merge values until the next launch.
    /// `HunchApp.init()` does exactly that.
    ///
    /// The first `synchronize()` reads iCloud's *local cache*, which is present
    /// immediately. A genuinely fresh install may have nothing cached yet; that
    /// data lands seconds later via `didChangeExternallyNotification`, which is
    /// why the observer exists rather than a one-shot read.
    static func bootstrap() {
        let kv = NSUbiquitousKeyValueStore.default

        if !observing {
            observing = true
            NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: kv,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    if merge() { onMerge?() }
                }
            }
        }

        kv.synchronize()
        _ = merge()
    }

    /// Whether the player is signed into iCloud. Reporting only — every call in
    /// this file is safe to make regardless, and no-ops when it's false.
    static var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Pull

    /// Merges the cloud copy into `UserDefaults` per the rules in the header.
    /// Returns whether anything local actually changed.
    @discardableResult
    private static func merge() -> Bool {
        let d = UserDefaults.standard
        let kv = NSUbiquitousKeyValueStore.default
        var changed = false

        /// Remote integer, but only when the key genuinely exists. An absent KVS
        /// key reads as 0, which would look like a legitimate "zero" and stomp
        /// sentinels like lastSolvedDay's -1.
        func remoteInt(_ key: String) -> Int? {
            (kv.object(forKey: key) as? NSNumber)?.intValue
        }

        func mergeMax(_ key: String) {
            guard let r = remoteInt(key), r > d.integer(forKey: key) else { return }
            d.set(r, forKey: key)
            changed = true
        }

        func mergeUnion(_ key: String) {
            let remote = Set(kv.array(forKey: key) as? [String] ?? [])
            guard !remote.isEmpty else { return }
            let local = Set(d.stringArray(forKey: key) ?? [])
            let merged = local.union(remote)
            guard merged != local else { return }
            d.set(Array(merged), forKey: key)
            changed = true
        }

        mergeMax(kSolves)
        mergeMax(kBestStreak)
        mergeMax(kTotalGuesses)
        mergeMax(kLastBonusDay)
        mergeUnion(kAchievements)
        mergeUnion(kWardrobeOwned)

        // Fewest guesses to a solve: lower wins, and 0 means "never solved".
        if let r = remoteInt(kBestGuess), r > 0 {
            let l = d.integer(forKey: kBestGuess)
            if l == 0 || r < l {
                d.set(r, forKey: kBestGuess)
                changed = true
            }
        }

        // Streak and its anchor day are one fact, decided by the later day.
        if let remoteDay = remoteInt(kLastSolvedDay) {
            let localDay = d.object(forKey: kLastSolvedDay) as? Int ?? -1
            let remoteStreak = remoteInt(kStreak) ?? 0
            let localStreak = d.object(forKey: kStreak) as? Int ?? 0
            if remoteDay > localDay || (remoteDay == localDay && remoteStreak > localStreak) {
                d.set(remoteDay, forKey: kLastSolvedDay)
                d.set(remoteStreak, forKey: kStreak)
                changed = true
            }
        }

        // Spendable / mutable state: newest writer wins.
        let remoteRev = remoteInt(kRev) ?? 0
        if remoteRev > d.integer(forKey: kRev) {
            if let c = remoteInt(kCoins) { d.set(c, forKey: kCoins) }
            if let e = kv.string(forKey: kWardrobeEquip) { d.set(e, forKey: kWardrobeEquip) }
            d.set(remoteRev, forKey: kRev)
            changed = true
        }

        return changed
    }

    // MARK: - Push

    /// Writes the local copy up. Cheap — KVS writes to a local plist and syncs
    /// on its own schedule — so it is safe to call at every meaningful change
    /// rather than on a timer.
    ///
    /// Monotonic keys are pushed as `max(local, remote)` so a device that
    /// somehow pushes before merging can't drag the cloud backwards.
    static func push() {
        let d = UserDefaults.standard
        let kv = NSUbiquitousKeyValueStore.default

        func pushMax(_ key: String) {
            let remote = (kv.object(forKey: key) as? NSNumber)?.intValue ?? Int.min
            kv.set(Int64(max(d.integer(forKey: key), remote)), forKey: key)
        }

        func pushUnion(_ key: String) {
            let local = Set(d.stringArray(forKey: key) ?? [])
            let remote = Set(kv.array(forKey: key) as? [String] ?? [])
            kv.set(Array(local.union(remote)), forKey: key)
        }

        pushMax(kSolves)
        pushMax(kBestStreak)
        pushMax(kTotalGuesses)
        pushMax(kLastBonusDay)
        pushUnion(kAchievements)
        pushUnion(kWardrobeOwned)

        let localBest = d.integer(forKey: kBestGuess)
        if localBest > 0 {
            let remoteBest = (kv.object(forKey: kBestGuess) as? NSNumber)?.intValue ?? 0
            kv.set(Int64(remoteBest > 0 ? min(localBest, remoteBest) : localBest), forKey: kBestGuess)
        }

        // The paired fact, pushed together — same reason it's merged together.
        let localDay = d.object(forKey: kLastSolvedDay) as? Int ?? -1
        let remoteDay = (kv.object(forKey: kLastSolvedDay) as? NSNumber)?.intValue ?? Int.min
        if localDay >= remoteDay {
            kv.set(Int64(localDay), forKey: kLastSolvedDay)
            kv.set(Int64(d.integer(forKey: kStreak)), forKey: kStreak)
        }

        // Bump the revision so this device's coins/outfit win the next merge.
        let rev = d.integer(forKey: kRev) + 1
        d.set(rev, forKey: kRev)
        kv.set(Int64(rev), forKey: kRev)
        kv.set(Int64(d.integer(forKey: kCoins)), forKey: kCoins)
        kv.set(d.string(forKey: kWardrobeEquip) ?? "", forKey: kWardrobeEquip)

        kv.synchronize()
    }
}
