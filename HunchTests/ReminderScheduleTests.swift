//
//  ReminderScheduleTests.swift
//  HunchTests
//
//  3.5: the daily reminder is a run of one-shot notifications so a day whose
//  puzzle is already solved can be skipped. These tests cover the pure part,
//  `HunchNotifications.dailyFireTimes`; the notification center itself is not
//  touched.
//

import Foundation
import Testing
@testable import Hunch

private var losAngeles: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return cal
}

/// A local time in Los Angeles. October 2026 has no clock change, so every
/// day in these tests is exactly 24 hours long.
private func la(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    losAngeles.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
}

struct ReminderScheduleTests {

    @Test func queuesTwoWeeksWhenTodaysTimeIsStillAhead() {
        let times = HunchNotifications.dailyFireTimes(hour: 9, minute: 0, lastSolvedDay: -1,
                                                      now: la(15, 8), calendar: losAngeles)
        #expect(times.count == HunchNotifications.daysAhead)
        #expect(times.first?.fireAt == la(15, 9))
    }

    @Test func skipsTodayWhenTheTimeHasPassed() {
        let times = HunchNotifications.dailyFireTimes(hour: 9, minute: 0, lastSolvedDay: -1,
                                                      now: la(15, 10), calendar: losAngeles)
        #expect(times.count == HunchNotifications.daysAhead - 1)
        #expect(times.first?.fireAt == la(16, 9))
    }

    @Test func skipsTheDayWhosePuzzleIsAlreadySolved() {
        let todaysPuzzle = WordBank.dayIndex(for: la(15, 9))
        let times = HunchNotifications.dailyFireTimes(hour: 9, minute: 0, lastSolvedDay: todaysPuzzle,
                                                      now: la(15, 8), calendar: losAngeles)
        #expect(times.first?.fireAt == la(16, 9))
        #expect(!times.contains { $0.puzzleDay == todaysPuzzle })
    }

    @Test func pointsAtThePuzzleLiveAtFireTime() {
        // 9 AM in Los Angeles is 16:00 UTC, the same UTC day. 6 PM is 01:00 UTC
        // the next day, after the puzzle has already changed.
        let morning = HunchNotifications.dailyFireTimes(hour: 9, minute: 0, lastSolvedDay: -1,
                                                        now: la(15, 8), calendar: losAngeles)
        let evening = HunchNotifications.dailyFireTimes(hour: 18, minute: 0, lastSolvedDay: -1,
                                                        now: la(15, 8), calendar: losAngeles)
        #expect(evening.first!.puzzleDay == morning.first!.puzzleDay + 1)
    }

    @Test func oneReminderPerPuzzle() {
        let times = HunchNotifications.dailyFireTimes(hour: 9, minute: 0, lastSolvedDay: -1,
                                                      now: la(15, 8), calendar: losAngeles)
        let days = times.map(\.puzzleDay)
        #expect(Set(days).count == days.count)
        #expect(zip(days, days.dropFirst()).allSatisfy { $1 == $0 + 1 })
    }
}
