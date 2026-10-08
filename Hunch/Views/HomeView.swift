//
//  HomeView.swift
//  Hunch
//
//  The home hub — the app's landing screen. Every mode is one clearly-labeled tap
//  away (no buried overflow menus), with the daily as the obvious hero. Built for
//  clarity: big targets, icon + label + one line each. Round state lives on the
//  view model, so entering a mode and returning Home never loses progress.
//

import SwiftUI

struct HomeView: View {
    @Environment(GameViewModel.self) private var game

    @State private var showDuel = false
    @State private var showArchive = false
    @State private var showWardrobe = false
    @State private var showStats = false
    @State private var showSettings = false
    @State private var showHowTo = false
    @State private var showPractice = false

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    @Environment(\.colorScheme) private var scheme

    // The home follows system appearance: a light pastel mesh + dark ink in light
    // mode, a dark backdrop + light ink in dark mode.
    private var inkPrimary: Color {
        scheme == .dark ? Color(red: 0.95, green: 0.95, blue: 0.98) : Color(red: 0.15, green: 0.15, blue: 0.18)
    }
    private var inkSecondary: Color {
        scheme == .dark ? Color(red: 0.72, green: 0.72, blue: 0.78) : Color(red: 0.34, green: 0.34, blue: 0.40)
    }

    @ViewBuilder
    private var homeBackground: some View {
        if scheme == .dark {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.07, blue: 0.10), Color(red: 0.11, green: 0.10, blue: 0.15)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        } else {
            // Chromatic, always — Home does NOT track the round's warmth.
            //
            // 3.2 coupled this mesh to `game.bestScore` so the hub "warmed with
            // you". In practice a solved round (score 100) pulled every mesh
            // point up to 84% of the way to solved-green and the entire screen
            // flooded one hue — the mode cards, which are a 12% tint of their own
            // colour, were swallowed whole and Practice and Wardrobe became
            // unreadable. Temperature belongs on the board, where a single
            // reading is the point; the hub is a front door and should look the
            // same every time you open it.
            AnimatedMeshBackground()
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                homeBackground
                ScrollView {
                    VStack(spacing: HunchTheme.Spacing.l) {
                        header
                        heroCard
                        // 3.3: three front doors. Daily (hero), Race, Practice.
                        // Dare is gone; Past puzzles and Wardrobe step down to a
                        // quieter row so Race gets the attention.
                        LazyVGrid(columns: cols, spacing: 12) {
                            modeCard(title: game.loc.duelRace, subtitle: game.loc.homeRaceSub,
                                     system: "flag.checkered", color: HunchTheme.Palette.flame) { showDuel = true }
                            modeCard(title: game.loc.practice, subtitle: game.loc.homePlayAnytime,
                                     system: "dice.fill", color: HunchTheme.Palette.solved) { showPractice = true }
                        }
                        secondaryRow
                        utilityRow
                    }
                    .padding(HunchTheme.Spacing.l)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(KeeperView.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDuel) { DuelView() }
            .sheet(isPresented: $showArchive) { ArchiveView() }
            .sheet(isPresented: $showWardrobe) { WardrobeView() }
            .sheet(isPresented: $showStats) { StatsView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showHowTo) { HowToPlayView() }
            .confirmationDialog(game.loc.chooseDifficulty, isPresented: $showPractice, titleVisibility: .visible) {
                Button(game.loc.easy) { game.startPractice(tier: 2) }
                Button(game.loc.medium) { game.startPractice(tier: 3) }
                Button(game.loc.hard) { game.startPractice(tier: 4) }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: HunchTheme.Spacing.s) {
            Spacer()
            if game.streak > 0 {
                HunchChip(text: "\(game.streak)", systemImage: "flame.fill", color: HunchTheme.Palette.flame)
            }
            HunchChip(text: "\(game.coins)", systemImage: "circle.hexagongrid.fill", color: HunchTheme.Palette.coin)
        }
    }

    // MARK: Hero (today's puzzle)

    private var heroCard: some View {
        Button { Feedback.play(.selection); game.playDaily() } label: {
            HStack(spacing: HunchTheme.Spacing.m) {
                KeeperView(mood: .idle, size: 68)
                    .frame(width: 68)
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.loc.dailyTitle(WordBank.dailyNumber()))
                        .font(.caption).foregroundStyle(HunchTheme.Palette.hot)
                    Text(game.loc.todaysPuzzle)
                        .font(.title2.bold()).foregroundStyle(inkPrimary)
                    Text(game.loc.homeGuessWord)
                        .font(.subheadline).foregroundStyle(inkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(HunchTheme.Palette.hot)
            }
            .padding(HunchTheme.Spacing.l)
            .frame(maxWidth: .infinity)
            .background(HunchTheme.Palette.hot.opacity(0.12), in: RoundedRectangle(cornerRadius: HunchTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: HunchTheme.Radius.card)
                .strokeBorder(HunchTheme.Palette.hot.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Mode cards

    private func modeCard(title: String, subtitle: String, system: String,
                          color: Color, action: @escaping () -> Void) -> some View {
        Button { Feedback.play(.selection); action() } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: system).font(.title2).foregroundStyle(color)
                Text(title).font(.headline).foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.caption).foregroundStyle(inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(HunchTheme.Spacing.l)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: HunchTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: HunchTheme.Radius.card)
                .strokeBorder(color.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Secondary row (Past puzzles, Wardrobe)

    private var secondaryRow: some View {
        HStack(spacing: HunchTheme.Spacing.s) {
            slimButton(game.loc.pastPuzzles, system: "clock.arrow.circlepath",
                       color: HunchTheme.Palette.cool) { showArchive = true }
            slimButton(game.loc.wardrobe, system: "tshirt.fill",
                       color: HunchTheme.Palette.warm) { showWardrobe = true }
        }
    }

    private func slimButton(_ title: String, system: String, color: Color,
                            action: @escaping () -> Void) -> some View {
        Button { Feedback.play(.selection); action() } label: {
            HStack(spacing: HunchTheme.Spacing.s) {
                Image(systemName: system).font(.subheadline).foregroundStyle(color)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(inkPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, HunchTheme.Spacing.m)
            .padding(.vertical, HunchTheme.Spacing.m)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: HunchTheme.Radius.field))
            .overlay(RoundedRectangle(cornerRadius: HunchTheme.Radius.field)
                .strokeBorder(color.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Utility row

    private var utilityRow: some View {
        HStack(spacing: HunchTheme.Spacing.s) {
            utilityButton(game.loc.yourStats, system: "chart.bar.fill") { showStats = true }
            utilityButton(game.loc.howToPlay, system: "questionmark.circle.fill") { showHowTo = true }
            utilityButton(game.loc.settings, system: "gearshape.fill") { showSettings = true }
        }
    }

    private func utilityButton(_ title: String, system: String, action: @escaping () -> Void) -> some View {
        Button { Feedback.play(.selection); action() } label: {
            VStack(spacing: 4) {
                Image(systemName: system).font(.title3).foregroundStyle(.secondary)
                Text(title).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HunchTheme.Spacing.m)
            .hunchCard(radius: HunchTheme.Radius.field)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView().environment(GameViewModel())
}
