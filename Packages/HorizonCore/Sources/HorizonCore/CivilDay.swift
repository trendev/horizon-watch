import Foundation

/// A calendar date with no time and no time zone.
public struct CivilDay: Hashable, Comparable, Codable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(containing date: Date, in timeZone: TimeZone) {
        let parts = Self.calendar(timeZone).dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// "2026-06-21"
    public var iso: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// 00:00 UTC of this date, the origin of the NOAA minute counts.
    public var midnightUTC: Date {
        start(in: .gmt)
    }

    /// 00:00 of this date in the given time zone.
    public func start(in timeZone: TimeZone) -> Date {
        Self.calendar(timeZone).date(from: DateComponents(year: year, month: month, day: day))!
    }

    public func adding(days: Int) -> CivilDay {
        CivilDay(containing: midnightUTC.addingTimeInterval(Double(days) * 86_400), in: .gmt)
    }

    var julianDay: Double {
        midnightUTC.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    public static func < (lhs: CivilDay, rhs: CivilDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
