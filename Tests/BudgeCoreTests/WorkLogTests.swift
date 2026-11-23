import Foundation
import Testing
@testable import BudgeCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// 2026-11-23 is a Monday.
private func date(_ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
}

@Test func addStartsADayAndKeepsAdding() {
    var log = WorkLog()
    log.add("Fixed the onboarding bug", on: date(23), calendar: utc)
    log.add("Reviewed 2 PRs\n\n  Wrote docs  ", on: date(23, 15), calendar: utc)
    log.add("Planning", on: date(24), calendar: utc)
    #expect(log.markdown == """
        ## 2026-11-23 Monday
        - Fixed the onboarding bug
        - Reviewed 2 PRs
        - Wrote docs

        ## 2026-11-24 Tuesday
        - Planning

        """)
}

@Test func blankTextIsIgnored() {
    var log = WorkLog()
    log.add("  \n ", on: date(23), calendar: utc)
    #expect(log.days.isEmpty)
}

@Test func markdownRoundTrips() {
    var log = WorkLog()
    log.add("One", on: date(23), calendar: utc)
    log.add("Two", on: date(25), calendar: utc)
    #expect(WorkLog(markdown: log.markdown) == log)
}

@Test func weekIsMondayToSunday() {
    var log = WorkLog()
    log.add("last Sunday", on: date(22), calendar: utc)
    log.add("Monday", on: date(23), calendar: utc)
    log.add("Friday", on: date(27), calendar: utc)
    log.add("Sunday", on: date(29), calendar: utc)
    log.add("next Monday", on: date(30), calendar: utc)
    let week = log.week(of: date(25), calendar: utc)
    #expect(week.map(\.date) == ["2026-11-23", "2026-11-27", "2026-11-29"])
}

@Test func summaryIsOneLinePerDay() {
    var log = WorkLog()
    log.add("Fixed bug\nReviewed PRs", on: date(23), calendar: utc)
    log.add("Planning", on: date(24), calendar: utc)
    #expect(WorkLog.summary(log.days) == "Mon: Fixed bug; Reviewed PRs\nTue: Planning")
}

@Test func asksOnceADayFromFour() {
    #expect(!EndOfDay.isDue(now: date(23, 15, 59), lastAsked: nil, calendar: utc))
    #expect(EndOfDay.isDue(now: date(23, 16), lastAsked: nil, calendar: utc))
    #expect(EndOfDay.isDue(now: date(23, 21), lastAsked: "2026-11-22", calendar: utc))
    #expect(!EndOfDay.isDue(now: date(23, 17), lastAsked: "2026-11-23", calendar: utc))
}

@Test func knowsFriday() {
    #expect(EndOfDay.isFriday(date(27), calendar: utc))
    #expect(!EndOfDay.isFriday(date(26), calendar: utc))
}
