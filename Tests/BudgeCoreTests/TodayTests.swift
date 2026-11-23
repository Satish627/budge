import Foundation
import Testing
@testable import BudgeCore

private let noon = Date(timeIntervalSince1970: 1_700_000_000)
private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

@Test func tallyCountsDoneAndSnoozed() {
    var tally = DayTally()
    tally.record(done: true, at: noon, calendar: utc)
    tally.record(done: false, at: noon, calendar: utc)
    tally.record(done: true, at: noon, calendar: utc)
    let today = tally.counts(on: noon, calendar: utc)
    #expect(today.done == 2 && today.snoozed == 1)
}

@Test func tallyStartsFreshTheNextDay() {
    var tally = DayTally()
    tally.record(done: true, at: noon, calendar: utc)
    let tomorrow = noon.addingTimeInterval(86_400)
    #expect(tally.counts(on: tomorrow, calendar: utc).done == 0)
    tally.record(done: false, at: tomorrow, calendar: utc)
    let next = tally.counts(on: tomorrow, calendar: utc)
    #expect(next.done == 0 && next.snoozed == 1)
}

@Test func tallySurvivesSaving() throws {
    var tally = DayTally()
    tally.record(done: true, at: noon, calendar: utc)
    let restored = try JSONDecoder().decode(DayTally.self, from: JSONEncoder().encode(tally))
    #expect(restored == tally)
}
