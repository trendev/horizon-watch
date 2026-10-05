import Foundation

/// Everything the app, the notifications and the widgets need to know at one instant.
public struct AlarmPlan: Equatable, Sendable {
    public let now: Date
    public let today: SolarDay
    /// The day drawn on the arc: today, or tomorrow once the sun has set.
    public let displayDay: SolarDay
    public let isNight: Bool
    public let displayIsTomorrow: Bool
    /// Today and the six days after it.
    public let week: [SolarDay]
    /// Every event after `now`, enabled or not, in ascending order.
    public let upcoming: [SolarEvent]
    /// Enabled, non-skipped events of the planning window.
    public let occurrences: [SolarEvent]
    /// End of the 15-day window, where the refill reminder fires.
    public let windowEnd: Date

    /// Target of the countdown.
    public var nextEvent: SolarEvent? { upcoming.first }

    public var nextOccurrence: SolarEvent? { occurrences.first }

    /// The occurrence that can be armed as a persistent alarm: the next one, if it is close enough.
    public var armable: SolarEvent? {
        guard let next = nextOccurrence, next.date.timeIntervalSince(now) <= AlarmPlanner.armingWindow else {
            return nil
        }
        return next
    }

    public func nextEvent(of kind: SolarEvent.Kind) -> SolarEvent? {
        upcoming.first { $0.kind == kind }
    }

    public func event(after event: SolarEvent) -> SolarEvent? {
        upcoming.first { $0.date > event.date }
    }

    /// Share of the displayed day's daylight already elapsed, from 0 at sunrise to 1 at sunset.
    public func daylightFraction(at date: Date) -> Double {
        guard let sunrise = displayDay.sunrise, let sunset = displayDay.sunset, sunset > sunrise else { return 0 }
        let fraction = date.timeIntervalSince(sunrise) / sunset.timeIntervalSince(sunrise)
        return min(max(fraction, 0), 1)
    }
}

/// Turns coordinates, a time zone and the settings into a plan. Works on events in absolute
/// time, never on calendar dates, so a sunset after midnight or a clock change needs no special case.
public struct AlarmPlanner: Sendable {
    /// 64 pending notifications at most, 4 per day, one refill reminder.
    public static let planningDays = 15
    /// A smart alarm session can be scheduled 36 hours ahead at most.
    public static let armingWindow: TimeInterval = 36 * 3600

    public let coordinates: Coordinates
    public let timeZone: TimeZone

    public init(coordinates: Coordinates, timeZone: TimeZone) {
        self.coordinates = coordinates
        self.timeZone = timeZone
    }

    public func solarDay(_ day: CivilDay) -> SolarDay {
        SunCalculator.solarDay(day, at: coordinates)
    }

    public func plan(now: Date, settings: AlarmSettings) -> AlarmPlan {
        let todayDay = CivilDay(containing: now, in: timeZone)
        let lastDay = todayDay.adding(days: Self.planningDays - 1)

        // Yesterday is included for a sunset that falls after midnight, and one extra day
        // so the last planned event still knows which event follows it.
        let days = (-1...Self.planningDays).map { solarDay(todayDay.adding(days: $0)) }
        let today = days[1]
        let upcoming = days.flatMap(\.events).filter { $0.date > now }.sorted { $0.date < $1.date }

        let occurrences = upcoming
            .filter { $0.day <= lastDay && settings.rings($0) }
            .prefix(Self.planningDays * 2)

        let displayDay: SolarDay
        let isNight: Bool
        if today.polar != .none {
            displayDay = today
            isNight = today.polar == .night
        } else if let next = upcoming.first {
            displayDay = days.first { $0.day == next.day } ?? today
            isNight = next.kind == .sunrise
        } else {
            displayDay = today
            isNight = false
        }

        return AlarmPlan(
            now: now,
            today: today,
            displayDay: displayDay,
            isNight: isNight,
            displayIsTomorrow: displayDay.day > todayDay,
            week: Array(days[1...7]),
            upcoming: upcoming,
            occurrences: Array(occurrences),
            windowEnd: todayDay.adding(days: Self.planningDays).start(in: timeZone))
    }
}
