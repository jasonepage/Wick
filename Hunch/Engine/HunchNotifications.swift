//
//  HunchNotifications.swift
//  Hunch
//
//  Local notifications. No server, no push certificate, no tokens — everything
//  here is scheduled on-device against `UNUserNotificationCenter`.
//
//  Two reminders:
//
//  1. The DAILY nudge: "today's word is ready" at a time the player picks in
//     Settings. Since 3.5 it is a run of one-shot reminders, one per day for
//     the next two weeks, so a day whose puzzle is already solved can be
//     skipped. A repeating trigger cannot skip a day.
//  2. The STREAK-AT-RISK nudge — a one-shot, fired a few hours before the day
//     rolls over, and ONLY when there is actually a streak to lose and today's
//     word is still unsolved. This is the one that moves retention: "a new word
//     exists" is information, "your 6-day flame goes out in three hours" is a
//     reason to open the app.
//
//  LOCALIZATION. Both notifications are written through `Loc`, in the language
//  the player chose *in the app* — not the device language. That distinction is
//  the whole point: language is an in-app setting here (see `Loc.swift`'s
//  header), so a French player on an English phone must get French copy. The
//  caller passes the current `Loc`; nothing in this file reads the bundle.
//
//  Because the text is baked in at schedule time, every reminder must be
//  re-scheduled when the game language changes. `GameViewModel.setLanguage`
//  does that.
//

import Foundation
import UserNotifications

enum HunchNotifications {
    private static let dailyID  = "hunch.daily"
    private static let streakID = "hunch.streakRisk"

    /// How long before the day rolls over the streak warning fires.
    private static let streakWarningLead: TimeInterval = 3 * 3600

    /// Below this there's nothing worth warning about — losing a 1-day streak
    /// is not a loss the player feels, and pretending otherwise is nagging.
    private static let minStreakToWarn = 2

    // MARK: - The day boundary

    /// The instant the daily puzzle changes.
    ///
    /// **This is UTC midnight, not the player's local midnight.**
    /// `WordBank.dayIndex()` is `timeIntervalSinceReferenceDate / 86_400`, so
    /// the day advances on the absolute 86,400-second boundary. A player in Los
    /// Angeles loses the day at 4pm or 5pm *their* time, and a reminder written
    /// against local midnight would fire hours after the streak had already
    /// broken. Scheduling off this function is what keeps the warning honest.
    static func dayRollover(after date: Date = Date()) -> Date {
        let nextDay = floor(date.timeIntervalSinceReferenceDate / 86_400) + 1
        return Date(timeIntervalSinceReferenceDate: nextDay * 86_400)
    }

    // MARK: - Permission

    /// Asks iOS for permission to show notifications. Returns whether they are
    /// allowed. Scheduling is the caller's job (`GameViewModel.refreshReminders`),
    /// because only the view model knows which puzzle was last solved.
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - The daily reminder

    /// How many days of daily reminders to keep queued. iOS allows 64 pending
    /// requests per app; two weeks leaves room and still reaches a player who
    /// skips a few days. Opening the app tops the queue back up.
    static let daysAhead = 14

    /// Every identifier a daily reminder could be using around `now`, including
    /// the single repeating request that versions before 3.5 scheduled.
    private static func dailyIDs(around now: Date) -> [String] {
        let today = WordBank.dayIndex(for: now)
        return [dailyID] + ((today - 2)...(today + daysAhead + 2)).map { "\(dailyID).\($0)" }
    }

    /// The local fire times for the next `daysAhead` days, each paired with the
    /// puzzle day it points at. A day whose puzzle is `lastSolvedDay` is left
    /// out, so a player who already solved never hears "today's word is ready".
    ///
    /// Pure, so it can be tested without the notification center.
    static func dailyFireTimes(hour: Int, minute: Int, lastSolvedDay: Int,
                               now: Date = Date(),
                               calendar: Calendar = .current) -> [(fireAt: Date, puzzleDay: Int)] {
        let startOfToday = calendar.startOfDay(for: now)
        var out: [(fireAt: Date, puzzleDay: Int)] = []
        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  let fireAt = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fireAt > now else { continue }
            // The puzzle changes at UTC midnight (see `dayRollover`), so the
            // puzzle a reminder points at is the one live at its fire time.
            let puzzleDay = WordBank.dayIndex(for: fireAt)
            if puzzleDay == lastSolvedDay { continue }
            out.append((fireAt, puzzleDay))
        }
        return out
    }

    /// (Re)schedules the daily reminders at the given local time.
    ///
    /// This one *is* local-time-anchored on purpose: it's a "come play" nudge
    /// tied to the player's morning, not to the puzzle deadline. The deadline
    /// is what `refreshStreakReminder` handles.
    static func schedule(hour: Int, minute: Int, lastSolvedDay: Int, loc: Loc, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: dailyIDs(around: now))

        let calendar = Calendar.current
        for (fireAt, puzzleDay) in dailyFireTimes(hour: hour, minute: minute,
                                                  lastSolvedDay: lastSolvedDay,
                                                  now: now, calendar: calendar) {
            let content = UNMutableNotificationContent()
            content.title = loc.notifDailyTitle
            content.subtitle = "Wick #\(WordBank.dailyNumber(forDayIndex: puzzleDay))"
            content.body  = loc.notifDailyBody
            content.sound = .default

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: "\(dailyID).\(puzzleDay)",
                                             content: content, trigger: trigger))
        }
    }

    // MARK: - The streak-at-risk reminder

    /// Arms — or clears — the one-shot streak warning for the current day.
    ///
    /// Safe and cheap to call often; it always clears the pending request first,
    /// so re-arming can't stack duplicates. Call it on launch, on foreground,
    /// after a solve, and when the language changes.
    ///
    /// - Parameters:
    ///   - streak: the player's current streak.
    ///   - lastSolvedDay: the `WordBank.dayIndex()` of their last daily solve.
    ///   - enabled: the player's reminder toggle. When off, this only cancels.
    static func refreshStreakReminder(streak: Int, lastSolvedDay: Int, enabled: Bool, loc: Loc) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [streakID])

        guard enabled, streak >= minStreakToWarn else { return }
        // Already solved today — there is nothing at risk, so say nothing.
        guard lastSolvedDay != WordBank.dayIndex() else { return }
        // Yesterday must be the anchor, or the streak is already broken and a
        // warning would be a lie about a flame that has gone out.
        guard lastSolvedDay == WordBank.dayIndex() - 1 else { return }

        let fireAt = dayRollover().addingTimeInterval(-streakWarningLead)
        let delay = fireAt.timeIntervalSinceNow
        // Inside the lead window already (or past it) — don't fire immediately
        // at someone who just opened the app; they're here.
        guard delay > 60 else { return }

        let content = UNMutableNotificationContent()
        content.title = loc.notifStreakTitle
        content.body  = loc.notifStreakBody(streak)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        center.add(UNNotificationRequest(identifier: streakID, content: content, trigger: trigger))
    }

    // MARK: - Teardown

    /// Cancels every reminder, when the Settings toggle goes off.
    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: dailyIDs(around: Date()) + [streakID])
    }
}
