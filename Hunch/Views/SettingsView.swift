//
//  SettingsView.swift
//  Hunch
//
//  A single, card-styled settings page: language, notifications, and about.
//  Switching language rebuilds the engine/Keeper and starts a fresh round.
//

import SwiftUI

struct SettingsView: View {
    @Environment(GameViewModel.self) private var game
    @Environment(\.dismiss) private var dismiss

    @AppStorage("hunch.reminderOn") private var reminderOn = false
    @AppStorage("hunch.reminderHour") private var reminderHour = 9
    @AppStorage("hunch.reminderMinute") private var reminderMinute = 0
    @AppStorage("hunch.haptics") private var hapticsOn = true
    @AppStorage("hunch.sound") private var soundOn = true

    @State private var showHowTo = false

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HunchTheme.Spacing.l) {
                    languageSection
                    learnSection
                    feedbackSection
                    if !odrLanguages.isEmpty { dictionariesSection }
                    notificationsSection
                    aboutSection

                    Text("Wick v\(appVersion)")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, HunchTheme.Spacing.s)
                }
                .padding(HunchTheme.Spacing.l)
                .readableWidth()
            }
            .navigationTitle(game.loc.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(game.loc.done) { dismiss() }
                }
            }
            .sheet(isPresented: $showHowTo) { HowToPlayView() }
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
            sectionHeader(game.loc.language, system: "globe", color: HunchTheme.Palette.keeper)
            VStack(spacing: 0) {
                ForEach(GameLanguage.all) { lang in
                    if lang != GameLanguage.all.first { Divider().padding(.leading, 60) }
                    languageRow(
                        lang,
                        selected: game.language == lang,
                        tint: HunchTheme.Palette.keeper
                    ) {
                        withAnimation(.snappy) { game.setLanguage(lang) }
                    }
                }
            }
            .hunchCard(radius: 18)
            Text(game.loc.languagePickHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, HunchTheme.Spacing.xs)
        }
    }

    /// One flag-and-name row, shared by the Play and Learn pickers.
    private func languageRow(
        _ lang: GameLanguage,
        selected: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard !selected else { return }
            action()
            Haptics.selection()
        } label: {
            HStack(spacing: HunchTheme.Spacing.m) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(selected ? 0.16 : 0.10))
                        .frame(width: 36, height: 36)
                    Text(lang.flag)
                        .font(.footnote)
                }
                Text(lang.nativeName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(HunchTheme.Palette.solved)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, HunchTheme.Spacing.l)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Offline dictionaries (1.9 ODR)

    /// Languages delivered as downloadable dictionaries (On-Demand Resources).
    private var odrLanguages: [GameLanguage] {
        GameLanguage.all.filter { EmbeddingAssetLoader.odrEnabled.contains($0) }
    }

    private var dictionariesSection: some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
            sectionHeader(game.loc.dictionaries, system: "arrow.down.circle.fill", color: HunchTheme.Palette.cool)
            VStack(spacing: 0) {
                ForEach(odrLanguages) { lang in
                    if lang != odrLanguages.first { Divider().padding(.leading, 60) }
                    dictionaryRow(lang)
                }
            }
            .hunchCard(radius: 18)
            Button {
                game.assetLoader.preloadAll()
                Haptics.selection()
            } label: {
                Label(game.loc.downloadAll, systemImage: "square.and.arrow.down.on.square")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HunchTheme.Palette.cool)
            }
            .buttonStyle(.plain)
            .padding(.leading, HunchTheme.Spacing.xs)
            Text(game.loc.dictionariesBlurb)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, HunchTheme.Spacing.xs)
        }
    }

    /// One dictionary row: flag, language name, and a status/action trailing that
    /// reflects the loader's live state (Ready · nn% · Download).
    private func dictionaryRow(_ lang: GameLanguage) -> some View {
        HStack(spacing: HunchTheme.Spacing.m) {
            ZStack {
                Circle()
                    .fill(HunchTheme.Palette.cool.opacity(0.10))
                    .frame(width: 36, height: 36)
                Text(lang.flag).font(.footnote)
            }
            Text(lang.nativeName)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            dictionaryStatus(lang)
        }
        .padding(.horizontal, HunchTheme.Spacing.l)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func dictionaryStatus(_ lang: GameLanguage) -> some View {
        switch game.assetLoader.state(for: lang) {
        case .available:
            Label(game.loc.dictionaryReady, systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(HunchTheme.Palette.solved)
        case .downloading(let fraction):
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(HunchTheme.Palette.cool)
                .monospacedDigit()
        case .idle, .failed:
            Button {
                game.assetLoader.ensure(lang, presentModal: false)
                Haptics.selection()
            } label: {
                Text(game.loc.dictionaryDownload)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(HunchTheme.Palette.cool)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Learn mode

    private var learnSection: some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
            sectionHeader(game.loc.learnTitle, system: "character.book.closed.fill", color: HunchTheme.Palette.solved)
            VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
                Toggle(game.loc.learnToggle(game.learnLanguage.name(in: game.language)), isOn: learnBinding)
                    .font(.body.weight(.medium))
                    .tint(HunchTheme.Palette.solved)
                if game.learnMode, learnChoices.count > 1 {
                    Divider()
                    VStack(spacing: 0) {
                        ForEach(learnChoices) { lang in
                            if lang != learnChoices.first { Divider().padding(.leading, 60) }
                            languageRow(
                                lang,
                                selected: game.learnLanguage == lang,
                                tint: HunchTheme.Palette.solved
                            ) {
                                withAnimation(.snappy) { game.setLearnLanguage(lang) }
                            }
                        }
                    }
                }
                Text(learnBlurbText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(HunchTheme.Spacing.l)
            .hunchCard(radius: 18)
        }
    }

    // MARK: - Sound & Haptics

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
            sectionHeader(game.loc.soundHapticsTitle, system: "waveform", color: HunchTheme.Palette.keeper)
            VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
                Toggle(game.loc.hapticsToggle, isOn: $hapticsOn)
                    .font(.body.weight(.medium))
                    .tint(HunchTheme.Palette.keeper)
                Divider()
                Toggle(game.loc.soundToggle, isOn: $soundOn)
                    .font(.body.weight(.medium))
                    .tint(HunchTheme.Palette.keeper)
            }
            .padding(HunchTheme.Spacing.l)
            .hunchCard(radius: 18)
        }
    }

    /// Languages you can learn: everything except the one you're playing in.
    private var learnChoices: [GameLanguage] {
        GameLanguage.all.filter { $0 != game.language }
    }

    /// The learn blurb with a live example pair (playWord → learnWord),
    /// pulled from the shared "apple" concept so it's right in any language.
    private var learnBlurbText: String {
        let pair = DailyWords.all.first { $0.en == "apple" }
        return game.loc.learnBlurb(
            game.learnLanguage.name(in: game.language),
            pair?.word(for: game.language) ?? "apple",
            pair?.word(for: game.learnLanguage) ?? "manzana"
        )
    }

    private var learnBinding: Binding<Bool> {
        Binding(get: { game.learnMode }, set: { game.learnMode = $0 })
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
            sectionHeader(game.loc.notifications, system: "bell.badge.fill", color: HunchTheme.Palette.warm)
            VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
                Toggle(game.loc.dailyReminder, isOn: reminderBinding)
                    .font(.body.weight(.medium))
                    .tint(HunchTheme.Palette.warm)
                if reminderOn {
                    Divider()
                    DatePicker(game.loc.time, selection: timeBinding, displayedComponents: .hourAndMinute)
                }
                Text(game.loc.reminderBlurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(HunchTheme.Spacing.l)
            .hunchCard(radius: 18)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
            sectionHeader(game.loc.about, system: "info.circle.fill", color: HunchTheme.Palette.freezing)
            VStack(spacing: 0) {
                Button { showHowTo = true } label: {
                    aboutRow(game.loc.howToPlay, system: "questionmark.circle.fill", trailing: "chevron.right")
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 60)
                Link(destination: URL(string: "https://jasonepage.github.io/hunch/")!) {
                    aboutRow(game.loc.privacyPolicy, system: "lock.shield.fill", trailing: "arrow.up.right")
                }
            }
            .hunchCard(radius: 18)
        }
    }

    private func aboutRow(_ title: String, system: String, trailing: String) -> some View {
        HStack(spacing: HunchTheme.Spacing.m) {
            ZStack {
                Circle()
                    .fill(HunchTheme.Palette.freezing.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: system)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(HunchTheme.Palette.freezing)
            }
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: trailing)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, HunchTheme.Spacing.l)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, system: String, color: Color) -> some View {
        Label(title, systemImage: system)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(.leading, HunchTheme.Spacing.xs)
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { reminderOn },
            set: { on in
                reminderOn = on
                if on {
                    let loc = game.loc   // read before the hop, not inside it
                    Task {
                        let ok = await HunchNotifications.enable(hour: reminderHour,
                                                                 minute: reminderMinute,
                                                                 loc: loc)
                        if !ok {
                            reminderOn = false
                        } else {
                            // The toggle also gates the streak warning, and the
                            // @AppStorage write above has landed by now.
                            game.refreshStreakReminder()
                        }
                    }
                } else {
                    HunchNotifications.cancel()
                }
            }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderHour = c.hour ?? 9
                reminderMinute = c.minute ?? 0
                if reminderOn {
                    HunchNotifications.schedule(hour: reminderHour, minute: reminderMinute, loc: game.loc)
                }
            }
        )
    }
}

#Preview {
    SettingsView().environment(GameViewModel())
}
