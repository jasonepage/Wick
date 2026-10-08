//
//  ShopView.swift
//  Hunch
//

import SwiftUI
import StoreKit
import UIKit

struct ShopView: View {
    @Environment(GameViewModel.self) private var game
    @Environment(\.dismiss) private var dismiss

    private var store: CoinStore { game.coinStore }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    balanceCard

                    switch store.phase {
                    case .loading:
                        VStack(spacing: 8) {
                            ProgressView()
                            Text(game.loc.loadingShop)
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                    case .ready:
                        ForEach(store.products, id: \.id) { product in
                            packRow(product)
                        }
                    case .failed:
                        VStack(spacing: 10) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text(game.loc.shopUnavailable)
                                .font(.headline)
                            Text(game.loc.shopUnavailableDetail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button(game.loc.retry) { Task { await store.load() } }
                                .buttonStyle(.bordered)
                        }
                        .padding(.top, 30)
                        .padding(.horizontal, 12)
                    }

                    Text(game.loc.coinsBuyBlurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(16)
                .readableWidth(560)
            }
            .navigationTitle(game.loc.getCoins)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(game.loc.done) { dismiss() }
                }
            }
        }
    }

    private var balanceCard: some View {
        HStack(spacing: HunchTheme.Spacing.s) {
            Image(systemName: "circle.hexagongrid.fill")
                .foregroundStyle(HunchTheme.Palette.coin)
            Text(game.loc.yourBalance).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text("\(game.coins)").font(.title3.weight(.bold))
        }
        .padding(HunchTheme.Spacing.l)
        .hunchCard(tint: HunchTheme.Palette.coin, radius: 16)
    }

    private func packRow(_ product: Product) -> some View {
        let amount = store.coins(for: product.id)
        return Button {
            Task { await game.buyCoins(product) }
        } label: {
            HStack(spacing: HunchTheme.Spacing.l) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.title2)
                    .foregroundStyle(HunchTheme.Palette.coin)
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.loc.coinsAmount(amount)).font(.headline)
                    Text(product.displayName).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if store.isWorking {
                    ProgressView()
                } else {
                    Text(product.displayPrice)
                        .font(.headline)
                        .foregroundStyle(.tint)
                }
            }
            .padding(HunchTheme.Spacing.l)
            .hunchCard(radius: 16)
        }
        .buttonStyle(.plain)
        .disabled(store.isWorking)
    }
}

#Preview {
    ShopView().environment(GameViewModel())
}
