import Foundation

/// Your end-of-day notes, kept as a small Markdown file:
///
///     ## 2026-11-23 Monday
///     - Fixed the onboarding status bug
///     - Reviewed 2 PRs
public struct WorkLog: Equatable, Sendable {
    public struct Day: Equatable, Sendable {
        public let date: String // "2026-11-23"
        public let weekday: String // "Monday"
        public var items: [String]
    }

    public private(set) var days: [Day] = []

    public init(markdown: String = "") {
        for line in markdown.split(whereSeparator: \.isNewline) {
            if line.hasPrefix("## ") {
                let parts = line.dropFirst(3).split(separator: " ", maxSplits: 1)
                guard let date = parts.first, date.count == 10 else { continue }
                days.append(Day(date: String(date), weekday: parts.count > 1 ? String(parts[1]) : "", items: []))
            } else if line.hasPrefix("- "), !days.isEmpty {
                days[days.count - 1].items.append(String(line.dropFirst(2)))
            }
        }
    }

    public var markdown: String {
        days.map { day in
            (["## \(day.date) \(day.weekday)"] + day.items.map { "- \($0)" }).joined(separator: "\n")
        }
        .joined(separator: "\n\n") + "\n"
    }

    /// Adds each non-blank line of `text` under the day's heading, starting a new day when needed.
    public mutating func add(_ text: String, on date: Date, calendar: Calendar = .current) {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return }
        let key = Self.dayKey(date, calendar)
        if days.last?.date != key {
            days.append(Day(date: key, weekday: Self.weekdayName(date, calendar), items: []))
        }
        days[days.count - 1].items += lines
    }

    /// The logged days in the Monday-to-Sunday week that contains `date`.
    public func week(of date: Date, calendar: Calendar = .current) -> [Day] {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        guard let monday = iso.dateInterval(of: .weekOfYear, for: date)?.start,
              let sunday = iso.date(byAdding: .day, value: 6, to: monday) else { return [] }
        let first = Self.dayKey(monday, iso), last = Self.dayKey(sunday, iso)
        return days.filter { $0.date >= first && $0.date <= last }
    }

    /// One line per day, ready to paste into a standup message.
    public static func summary(_ days: [Day]) -> String {
        days.map { "\($0.weekday.prefix(3)): \($0.items.joined(separator: "; "))" }.joined(separator: "\n")
    }

    public static func dayKey(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func weekdayName(_ date: Date, _ calendar: Calendar) -> String {
        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][
            calendar.component(.weekday, from: date) - 1]
    }
}

/// When to ask "What did you finish today?": once a day, from 16:00.
public enum EndOfDay {
    public static let hour = 16

    public static func isDue(now: Date, lastAsked: String?, calendar: Calendar = .current) -> Bool {
        calendar.component(.hour, from: now) >= hour && lastAsked != WorkLog.dayKey(now, calendar)
    }

    public static func isFriday(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.component(.weekday, from: date) == 6
    }
}
