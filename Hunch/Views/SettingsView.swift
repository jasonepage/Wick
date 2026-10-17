//
//  SettingsView.swift
//  Hunch
//
//  A single, card-styled settings page: language, notifications, and about.
//  The language picker sets the MENU language; the "Play in X" toggle under it
//  decides whether the round is played in that language or in English with
//  meanings shown (the same two controls as the web app). Either change can
//  rebuild the engine/Keeper and start a fresh round.
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
    @AppStorage("hunch.music") private var musicOn = true
    @AppStorage(WordTally.shareKey) private var shareWords = true

    @State private var showHowTo = false
    @State private var alerts = RaceAlerts.shared

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HunchTheme.Spacing.l) {
                    languageSection
                    feedbackSection
                    if !odrLanguages.isEmpty { dictionariesSection }
                    notificationsSection
                    weeklyStatsSection
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
            .sheet(isPresented: $showHowTo) {
                HowToPlayView(onPlayTutorial: {
                    showHowTo = false
                    playTutorial()
                })
            }
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
                        selected: game.uiLanguage == lang,
                        tint: HunchTheme.Palette.keeper
                    ) {
                        withAnimation(.snappy) { game.setUILanguage(lang) }
                    }
                }
            }
            .hunchCard(radius: 18)
            if game.uiLanguage != .english {
                VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
                    Toggle(game.loc.setPlayIn(game.uiLanguage.nativeName), isOn: playNativeBinding)
                        .font(.body.weight(.medium))
                        .tint(HunchTheme.Palette.keeper)
                    Text(game.playNative ? game.loc.setPlayInHintOn : game.loc.setPlayInHintOff)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(HunchTheme.Spacing.l)
                .hunchCard(radius: 18)
            } else {
                Text(game.loc.languagePickHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, HunchTheme.Spacing.xs)
            }
        }
    }

    private var playNativeBinding: Binding<Bool> {
        Binding(get: { game.playNative }, set: { on in withAnimation(.snappy) { game.setPlayNative(on) } })
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
                Divider()
                Toggle(game.loc.musicToggle, isOn: $musicOn)
                    .font(.body.weight(.medium))
                    .tint(HunchTheme.Palette.keeper)
                    .disabled(!soundOn)
            }
            .padding(HunchTheme.Spacing.l)
            .hunchCard(radius: 18)
        }
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

            // Race alerts: pushes from the server when there is someone to race.
            sectionHeader(game.loc.raceAlerts, system: "flag.checkered", color: HunchTheme.Palette.keeper)
            VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
                Toggle(game.loc.alertWaiting, isOn: alertBinding(.waiting))
                    .font(.body.weight(.medium))
                    .tint(HunchTheme.Palette.keeper)
                Divider()
                Toggle(game.loc.alertBusy, isOn: alertBinding(.busy))
                    .font(.body.weight(.medium))
                    .tint(HunchTheme.Palette.keeper)
                Divider()
                Toggle(game.loc.alertSurge, isOn: alertBinding(.surge))
                    .font(.body.weight(.medium))
                    .tint(HunchTheme.Palette.keeper)
                Text(game.loc.raceAlertsBlurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(HunchTheme.Spacing.l)
            .hunchCard(radius: 18)
        }
    }

    // MARK: - Weekly stats (3.6)

    /// Whether this phone adds its cool-or-colder guesses and typed questions
    /// to everyone's weekly lists on the Stats page. On by default.
    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
            sectionHeader(game.loc.weeklySettingsHeader, system: "person.3.fill", color: HunchTheme.Palette.keeper)
            VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
                Toggle(game.loc.shareWordsToggle, isOn: $shareWords)
                    .font(.body.weight(.medium))
                    .tint(HunchTheme.Palette.keeper)
                Text(game.loc.shareWordsBlurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(HunchTheme.Spacing.l)
            .hunchCard(radius: 18)
        }
    }

    /// One race alert kind. Reads the stored choice; writing asks the server
    /// (and iOS, the first time) through RaceAlerts.
    private func alertBinding(_ kind: RaceAlerts.Kind) -> Binding<Bool> {
        Binding(
            get: { alerts.wants(kind) },
            set: { on in alerts.set(kind, on: on) }
        )
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: HunchTheme.Spacing.s) {
            sectionHeader(game.loc.about, system: "info.circle.fill", color: HunchTheme.Palette.freezing)
            VStack(spacing: 0) {
                // 3.6: replay the hands-on tutorial level.
                Button(action: playTutorial) {
                    aboutRow(game.loc.tutPlayTutorial, system: "graduationcap.fill", trailing: "play.fill")
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 60)
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

    /// Close Settings and drop straight into the tutorial level.
    private func playTutorial() {
        Feedback.play(.selection)
        dismiss()
        // Let the sheet slide away first, so the board isn't swapped under it.
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            game.startTutorial()
        }
    }

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
                    Task {
                        let ok = await HunchNotifications.requestPermission()
                        if !ok {
                            reminderOn = false
                        } else {
                            // Schedules the daily reminders and the streak
                            // warning; the @AppStorage write above has landed.
                            game.refreshReminders()
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
                    game.refreshReminders()
                }
            }
        )
    }
}

#Preview {
    SettingsView().environment(GameViewModel())
}
