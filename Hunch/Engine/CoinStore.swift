//
//  CoinStore.swift
//  Hunch
//
//  StoreKit 2 consumable coin packs. Coins buy extra hints and questions; the
//  game stays free and always completable without them.
//
//  NOTE: Foundation/StoreKit APIs follow Apple's documented forms; adjust if a
//  signature differs slightly in your SDK.
//

import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class CoinStore {
    /// Product ID -> coins granted. Must match the .storekit file and App Store Connect.
    static let packs: [(id: String, coins: Int)] = [
        ("party.heirloom.Hunch.coins.small", 100),
        ("party.heirloom.Hunch.coins.medium", 550),
        ("party.heirloom.Hunch.coins.large", 1500)
    ]

    enum LoadPhase { case loading, ready, failed }

    private(set) var products: [Product] = []
    private(set) var phase: LoadPhase = .loading
    private(set) var isWorking = false
    var errorMessage: String?

    /// Set by the game; called with the number of coins to credit on success.
    var onGrant: ((Int) -> Void)?

    private var updates: Task<Void, Never>?
    private var processed = Set<UInt64>()

    init() {
        updates = listenForTransactions()
        Task { await load() }
    }

    func load() async {
        phase = .loading
        do {
            let ids = Self.packs.map(\.id)
            let loaded = try await Product.products(for: ids).sorted { $0.price < $1.price }
            products = loaded
            phase = loaded.isEmpty ? .failed : .ready
        } catch {
            errorMessage = "Couldn't load the shop. Check your connection and try again."
            phase = .failed
        }
    }

    func coins(for productID: String) -> Int {
        Self.packs.first { $0.id == productID }?.coins ?? 0
    }

    func purchase(_ product: Product) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    grant(for: transaction)
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
        }
    }

    /// Credits coins for a transaction exactly once, then finishes it.
    private func grant(for transaction: Transaction) {
        guard !processed.contains(transaction.id) else { return }
        processed.insert(transaction.id)
        let amount = coins(for: transaction.productID)
        if amount > 0 { onGrant?(amount) }
        Task { await transaction.finish() }
    }

    /// Handles deferred/interrupted purchases (e.g. Ask to Buy approved later).
    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                if case .verified(let transaction) = result {
                    self.grant(for: transaction)
                }
            }
        }
    }
}
