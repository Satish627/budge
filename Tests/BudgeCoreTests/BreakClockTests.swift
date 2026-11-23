import Foundation
import Testing
@testable import BudgeCore

private let t0 = Date(timeIntervalSince1970: 1_000_000)

/// Runs the clock for `minutes` of ticks every 15 s and returns the first nudge time, if any.
private func run(_ clock: inout BreakClock, minutes: Double, idle: TimeInterval = 5,
                 inCall: Bool = false, from start: Date = t0) -> Date? {
    var now = start
    let end = start.addingTimeInterval(minutes * 60)
    while now < end {
        now = now.addingTimeInterval(15)
        if clock.tick(elapsed: 15, idle: idle, inCall: inCall, now: now) == .nudge { return now }
    }
    return nil
}

@Test func nudgesAfterThirtyActiveMinutes() {
    var clock = BreakClock(interval: 30 * 60)
    let nudgeAt = run(&clock, minutes: 40)
    #expect(nudgeAt == t0.addingTimeInterval(30 * 60))
}

@Test func readingWithoutTypingStillCounts() {
    var clock = BreakClock(interval: 30 * 60)
    #expect(run(&clock, minutes: 31, idle: 45) != nil)
}

@Test func idleBetweenOneAndFiveMinutesDoesNotCount() {
    var clock = BreakClock(interval: 30 * 60)
    #expect(run(&clock, minutes: 60, idle: 120) == nil)
    #expect(clock.activeTime == 0)
}

@Test func fiveMinutesAwayResetsTheClock() {
    var clock = BreakClock(interval: 30 * 60)
    _ = run(&clock, minutes: 20)
    _ = clock.tick(elapsed: 15, idle: 5 * 60, inCall: false, now: t0.addingTimeInterval(21 * 60))
    #expect(clock.activeTime == 0)
}

@Test func sleepGapResetsTheClock() {
    var clock = BreakClock(interval: 30 * 60)
    _ = run(&clock, minutes: 20)
    _ = clock.tick(elapsed: 3600, idle: 2, inCall: false, now: t0.addingTimeInterval(80 * 60))
    #expect(clock.activeTime == 0)
}

@Test func waitsWhileOnACallThenNudges() {
    var clock = BreakClock(interval: 30 * 60)
    #expect(run(&clock, minutes: 45, inCall: true) == nil)
    let after = t0.addingTimeInterval(45 * 60)
    #expect(clock.tick(elapsed: 15, idle: 5, inCall: false, now: after) == .nudge)
}

@Test func snoozeHoldsForTenMinutes() {
    var clock = BreakClock(interval: 30 * 60)
    let first = run(&clock, minutes: 31)!
    clock.snooze(for: 10 * 60, now: first)
    let second = run(&clock, minutes: 15, from: first)
    #expect(second == first.addingTimeInterval(10 * 60))
}

@Test func doneStartsOver() {
    var clock = BreakClock(interval: 30 * 60)
    let first = run(&clock, minutes: 31)!
    clock.tookBreak()
    #expect(clock.minutesLeft(now: first) == 30)
}

@Test func pauseStopsNudgesAndCounting() {
    var clock = BreakClock(interval: 30 * 60)
    clock.pause(until: t0.addingTimeInterval(60 * 60))
    #expect(run(&clock, minutes: 59) == nil)
    #expect(clock.activeTime == 0)
    clock.resume()
    #expect(run(&clock, minutes: 31) != nil)
}

@Test func promptsRotateWithoutRepeating() {
    var prompts = Prompts(start: 0)
    let a = prompts.next(), b = prompts.next()
    #expect(a != b)
}
