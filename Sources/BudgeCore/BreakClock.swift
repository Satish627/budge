import Foundation

/// Decides when to nudge. Counts only time you are actually at the keyboard,
/// treats a long idle gap as a break you already took, and holds while you are busy (call, full screen).
public struct BreakClock: Sendable {
    public enum Decision: Equatable, Sendable { case wait, nudge }

    /// Active time before a nudge.
    public var interval: TimeInterval
    /// Idle this long means you got up: start over.
    public var breakResetsAfter: TimeInterval = 5 * 60
    /// Idle shorter than this still counts as working (reading, thinking).
    public var stillWorkingIdle: TimeInterval = 60

    public private(set) var activeTime: TimeInterval = 0
    public private(set) var snoozedUntil: Date?
    public private(set) var pausedUntil: Date?

    public init(interval: TimeInterval, pausedUntil: Date? = nil) {
        self.interval = interval
        self.pausedUntil = pausedUntil
    }

    /// `elapsed` is the time since the previous tick; a big gap (sleep) counts as a break.
    public mutating func tick(elapsed: TimeInterval, idle: TimeInterval, busy: Bool, now: Date) -> Decision {
        if idle >= breakResetsAfter || elapsed >= breakResetsAfter {
            tookBreak()
            return .wait
        }
        if isPaused(now: now) { return .wait }
        if idle < stillWorkingIdle { activeTime += elapsed }
        guard activeTime >= interval, !busy else { return .wait }
        if let snoozedUntil, now < snoozedUntil { return .wait }
        return .nudge
    }

    public mutating func tookBreak() {
        activeTime = 0
        snoozedUntil = nil
    }

    public mutating func snooze(for duration: TimeInterval, now: Date) {
        snoozedUntil = now.addingTimeInterval(duration)
    }

    public mutating func pause(until date: Date) { pausedUntil = date }
    public mutating func resume() { pausedUntil = nil }

    public func isPaused(now: Date) -> Bool {
        guard let pausedUntil else { return false }
        return now < pausedUntil
    }

    /// Minutes of keyboard time left before the next nudge (snooze included).
    public func minutesLeft(now: Date) -> Int {
        var left = max(0, interval - activeTime)
        if let snoozedUntil { left = max(left, snoozedUntil.timeIntervalSince(now)) }
        return Int((left / 60).rounded(.up))
    }
}
