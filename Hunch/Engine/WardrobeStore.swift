//
//  WardrobeStore.swift
//  Hunch
//
//  Owns what Wick accessories the player has bought (`owned`) and what's currently
//  worn (`equipped`, one id per slot). Purely cosmetic; the daily economy, streak
//  and stats are untouched.
//
//  Coins stay authoritative on `GameViewModel`. Like `CoinStore.onGrant`, this
//  store reaches the economy only through injected closures (`spend` / `balance`)
//  wired up in `GameViewModel.init`, so it stays decoupled and testable.
//
//  A shared instance lets `KeeperView` read `equipped` reactively (it's
//  `@Observable`), so every Wick on screen updates the moment an item is equipped
//  — without threading state through ~8 call sites.
//

import SwiftUI

@MainActor
@Observable
final class WardrobeStore {

    /// Shared so `KeeperView` can render the equipped look everywhere. The app has
    /// a single player, so a single wardrobe is correct.
    static let shared = WardrobeStore()

    private static let ownedKey    = "hunch.wardrobe.owned"
    private static let equippedKey = "hunch.wardrobe.equipped"   // "slot:id,slot:id"

    private(set) var owned: Set<String>
    private(set) var equipped: [AccessorySlot: String]

    /// Injected by `GameViewModel`. `spend` debits coins and returns whether it
    /// succeeded (false = can't afford); `balance` reads the current coin count.
    var spend: (Int) -> Bool = { _ in false }
    var balance: () -> Int = { 0 }

    init() {
        let d = UserDefaults.standard
        owned = Set(d.stringArray(forKey: Self.ownedKey) ?? [])
        equipped = Self.decodeEquipped(d.string(forKey: Self.equippedKey))
        // Drop any equipped id the player doesn't actually own (defensive against
        // a catalog change or corrupt defaults).
        equipped = equipped.filter { owned.contains($0.value) }
    }

    /// Re-reads both sets from `UserDefaults`. Called after `CloudSync` merges a
    /// copy in from another device, so an outfit bought on the iPad shows up on
    /// the phone without a relaunch.
    func reloadFromDefaults() {
        let d = UserDefaults.standard
        owned = Set(d.stringArray(forKey: Self.ownedKey) ?? [])
        equipped = Self.decodeEquipped(d.string(forKey: Self.equippedKey)).filter { owned.contains($0.value) }
    }

    // MARK: Queries

    func owns(_ id: String) -> Bool { owned.contains(id) }

    func isEquipped(_ id: String) -> Bool {
        guard let a = WickAccessory.by(id: id) else { return false }
        return equipped[a.slot] == id
    }

    func canAfford(_ accessory: WickAccessory) -> Bool { balance() >= accessory.price }

    /// Resolved accessories currently worn — what `KeeperView` draws.
    var equippedAccessories: [WickAccessory] {
        equipped.values.compactMap { WickAccessory.by(id: $0) }
    }

    // MARK: Mutations

    /// Buy an accessory. No-op if already owned or unaffordable. Returns success.
    /// On purchase it is auto-equipped (players expect to see what they just bought).
    @discardableResult
    func purchase(_ accessory: WickAccessory) -> Bool {
        guard !owns(accessory.id) else { return false }
        guard spend(accessory.price) else { return false }   // debits coins iff affordable
        owned.insert(accessory.id)
        persistOwned()
        equip(accessory)
        return true
    }

    func equip(_ accessory: WickAccessory) {
        guard owns(accessory.id) else { return }
        equipped[accessory.slot] = accessory.id
        persistEquipped()
    }

    /// Toggle: equipping the already-equipped item removes it (bare that slot).
    func toggleEquip(_ accessory: WickAccessory) {
        guard owns(accessory.id) else { return }
        if equipped[accessory.slot] == accessory.id {
            equipped[accessory.slot] = nil
        } else {
            equipped[accessory.slot] = accessory.id
        }
        persistEquipped()
    }

    func unequipSlot(_ slot: AccessorySlot) {
        equipped[slot] = nil
        persistEquipped()
    }

    // MARK: Persistence

    // Both persist paths mirror to iCloud. This is the right place rather than
    // inside `spend`: a purchase debits coins BEFORE the item is written, so
    // pushing from the spend closure would ship the new balance with the old
    // wardrobe. By the time these run, both halves are on disk.

    private func persistOwned() {
        UserDefaults.standard.set(Array(owned), forKey: Self.ownedKey)
        CloudSync.push()
    }

    private func persistEquipped() {
        let s = equipped.map { "\($0.key.rawValue):\($0.value)" }.joined(separator: ",")
        UserDefaults.standard.set(s, forKey: Self.equippedKey)
        CloudSync.push()
    }

    private static func decodeEquipped(_ raw: String?) -> [AccessorySlot: String] {
        guard let raw, !raw.isEmpty else { return [:] }
        var out: [AccessorySlot: String] = [:]
        for pair in raw.split(separator: ",") {
            let parts = pair.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, let slot = AccessorySlot(rawValue: String(parts[0])) else { continue }
            out[slot] = String(parts[1])
        }
        return out
    }
}
