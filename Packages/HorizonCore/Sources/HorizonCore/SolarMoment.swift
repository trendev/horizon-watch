import Foundation

/// What a complication shows at one instant: the next event and the period its gauge covers.
public struct SolarMoment: Equatable, Sendable {
    /// Target of the countdown: sunset during the day, sunrise at night.
    public let next: SolarEvent
    public let following: SolarEvent?
    /// The gauge runs from sunrise to sunset during the day, from sunset to sunrise at night.
    public let periodStart: Date
    public let periodEnd: Date
    /// The next event belongs to a later day than the instant.
    public let isTomorrow: Bool
    /// Whether the next event rings: its alarm is on and it is not skipped.
    public let isEnabled: Bool

    public var isNight: Bool { next.kind == .sunrise }

    public func progress(at date: Date) -> Double {
        let length = periodEnd.timeIntervalSince(periodStart)
        guard length > 0 else { return 0 }
        return min(max(date.timeIntervalSince(periodStart) / length, 0), 1)
    }

    /// Nil during a polar day or night: there is nothing to count down to.
    public static func make(at date: Date, planner: AlarmPlanner, settings: AlarmSettings) -> SolarMoment? {
        let plan = planner.plan(now: date, settings: settings)
        guard let next = plan.nextEvent else { return nil }

        let start: Date
        if next.kind == .sunset {
            start = plan.displayDay.sunrise ?? date
        } else {
            // The night began at the sunset of the day before the coming sunrise.
            start = planner.solarDay(next.day.adding(days: -1)).sunset ?? next.date.addingTimeInterval(-12 * 3600)
        }
        return SolarMoment(
            next: next, following: plan.event(after: next), periodStart: start, periodEnd: next.date,
            isTomorrow: next.day > plan.today.day, isEnabled: settings.rings(next))
    }

    /// Dates of the widget timeline: now, every quarter hour for the gauge position, and one
    /// second after each sunrise and sunset so that entry already targets the following event.
    public static func timelineDates(
        from now: Date, planner: AlarmPlanner, settings: AlarmSettings,
        duration: TimeInterval = 24 * 3600, step: TimeInterval = 15 * 60
    ) -> [Date] {
        let end = now.addingTimeInterval(duration)
        var dates: Set<Date> = [now]

        var tick = Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / step).rounded(.up) * step)
        while tick < end {
            dates.insert(tick)
            tick.addTimeInterval(step)
        }

        var cursor = now
        while let next = make(at: cursor, planner: planner, settings: settings)?.next, next.date < end {
            cursor = next.date.addingTimeInterval(1)
            if cursor < end { dates.insert(cursor) }
        }
        return dates.sorted()
    }
}
