import Foundation

/// A sunrise or a sunset, as an absolute instant.
public struct SolarEvent: Identifiable, Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case sunrise
        case sunset
    }

    public let kind: Kind
    public let date: Date
    /// The day the event belongs to. A sunset that falls after local midnight keeps the evening's day.
    public let day: CivilDay

    public init(kind: Kind, date: Date, day: CivilDay) {
        self.kind = kind
        self.date = date
        self.day = day
    }

    /// Stable across recalculations, e.g. "sunset-2026-06-21". Used for skips and notification ids.
    public var id: String {
        "\(kind.rawValue)-\(day.iso)"
    }
}

public enum PolarState: String, Codable, Sendable {
    case none
    /// The sun does not set.
    case day
    /// The sun does not rise.
    case night
}

/// Sun times for one civil day at one place.
public struct SolarDay: Hashable, Codable, Sendable {
    public let day: CivilDay
    public let sunrise: Date?
    public let sunset: Date?
    public let solarNoon: Date
    public let polar: PolarState

    public var dayLength: TimeInterval? {
        guard let sunrise, let sunset else { return nil }
        return sunset.timeIntervalSince(sunrise)
    }

    public var events: [SolarEvent] {
        var events: [SolarEvent] = []
        if let sunrise { events.append(SolarEvent(kind: .sunrise, date: sunrise, day: day)) }
        if let sunset { events.append(SolarEvent(kind: .sunset, date: sunset, day: day)) }
        return events
    }

    public func date(of kind: SolarEvent.Kind) -> Date? {
        kind == .sunrise ? sunrise : sunset
    }
}
