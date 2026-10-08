//
//  WardrobeView.swift
//  Hunch
//
//  Wick's Wardrobe — spend earned coins on cosmetic accessories. The preview Wick
//  wears whatever is equipped and updates live (KeeperView reads the same shared
//  WardrobeStore). Buying debits coins via GameViewModel; equipping is free.
//

import SwiftUI

struct WardrobeView: View {
    @Environment(GameViewModel.self) private var game
    @Environment(\.dismiss) private var dismiss
    @State private var showShop = false

    private var wardrobe: WardrobeStore { game.wardrobe }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    previewCard
                    balanceCard

                    ForEach(AccessorySlot.allCases, id: \.self) { slot in
                        section(for: slot)
                    }
                }
                .padding(16)
                .readableWidth(560)
            }
            .navigationTitle(game.loc.wardrobe)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(game.loc.done) { dismiss() }
                }
            }
            .sheet(isPresented: $showShop) { ShopView().environment(game) }
        }
    }

    // MARK: Preview

    private var previewCard: some View {
        VStack(spacing: HunchTheme.Spacing.s) {
            // Reads the shared wardrobe, so it re-dresses the moment you equip.
            KeeperView(mood: .idle, size: 120)
                .frame(height: 150)
            Text(game.loc.wardrobeBlurb)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(HunchTheme.Spacing.l)
        .hunchCard(tint: HunchTheme.Palette.keeper, radius: 16)
    }

    private var balanceCard: some View {
        HStack(spacing: HunchTheme.Spacing.s) {
            Image(systemName: "circle.hexagongrid.fill")
                .foregroundStyle(HunchTheme.Palette.coin)
            Text("\(game.coins)").font(.title3.weight(.bold))
            Spacer()
            Button(game.loc.getCoins) { showShop = true }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
        }
        .padding(HunchTheme.Spacing.l)
        .hunchCard(tint: HunchTheme.Palette.coin, radius: 16)
    }

    // MARK: Section per slot

    private func section(for slot: AccessorySlot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(game.loc.slotName(slot))
                .font(.headline)
                .padding(.leading, 4)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(WickAccessory.items(in: slot)) { item in
                    tile(item)
                }
            }
        }
    }

    // MARK: Item tile

    private func tile(_ item: WickAccessory) -> some View {
        let owned = wardrobe.owns(item.id)
        let equipped = wardrobe.isEquipped(item.id)
        let affordable = wardrobe.canAfford(item)

        return VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(HunchTheme.Palette.keeper.opacity(0.08))
                WickAccessoryView(id: item.id, size: 88)
            }
            .frame(height: 84)

            Text(game.loc.accessoryName(item.nameKey))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            actionButton(item: item, owned: owned, equipped: equipped, affordable: affordable)
        }
        .padding(HunchTheme.Spacing.m)
        .frame(maxWidth: .infinity)
        .hunchCard(tint: equipped ? HunchTheme.Palette.solved : nil, radius: 14)
    }

    @ViewBuilder
    private func actionButton(item: WickAccessory, owned: Bool, equipped: Bool, affordable: Bool) -> some View {
        if !owned {
            Button {
                wardrobe.purchase(item)
                Haptics.selection()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .foregroundStyle(HunchTheme.Palette.coin)
                    Text("\(item.price)").font(.subheadline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(HunchTheme.Palette.keeper)
            .disabled(!affordable)
            .opacity(affordable ? 1 : 0.5)
        } else {
            Button {
                wardrobe.toggleEquip(item)
                Haptics.selection()
            } label: {
                Text(equipped ? game.loc.take_off : game.loc.equip)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(equipped ? HunchTheme.Palette.solved : .accentColor)
        }
    }
}

#Preview {
    WardrobeView().environment(GameViewModel())
}
