import CoreGraphics
import Foundation

/// Done vs snoozed for one day, so you can see whether the interval suits you.
public struct DayTally: Codable, Equatable, Sendable {
    public private(set) var day: String
    public private(set) var done = 0
    public private(set) var snoozed = 0

    public init(day: String = "") { self.day = day }

    public mutating func record(done tookBreak: Bool, at date: Date, calendar: Calendar = .current) {
        let today = Self.dayKey(date, calendar)
        if today != day { self = DayTally(day: today) }
        if tookBreak { done += 1 } else { snoozed += 1 }
    }

    /// Counts for the day containing `date`; zeros if nothing was recorded that day.
    public func counts(on date: Date, calendar: Calendar = .current) -> (done: Int, snoozed: Int) {
        Self.dayKey(date, calendar) == day ? (done, snoozed) : (0, 0)
    }

    static func dayKey(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}

public enum FullScreen {
    /// True when one window covers the whole screen, like a full-screen app or a slideshow.
    /// A maximized window stops below the menu bar, so it doesn't count.
    public static func isCovered(_ screen: CGRect, byAnyOf windows: [CGRect]) -> Bool {
        windows.contains { $0.insetBy(dx: -1, dy: -1).contains(screen) }
    }
}
