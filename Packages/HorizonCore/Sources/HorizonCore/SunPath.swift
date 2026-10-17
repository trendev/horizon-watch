import Foundation

/// A point of the arc, normalized for drawing: `x` runs from 0 at sunrise to 1 at sunset,
/// `height` from 0 on the horizon to 1 at the top of the scale.
public struct SunPathPoint: Equatable, Sendable {
    public let x: Double
    public let height: Double

    public init(x: Double, height: Double) {
        self.x = x
        self.height = height
    }
}

/// The sun's real path over one day, as drawn on the main screen's arc.
///
/// Across, time is linear: halfway between sunrise and sunset is the middle of the arc.
/// Up, the height is the sun's true altitude on a fixed scale, so the arc is low in winter and
/// high in summer, and the sun sits on the curve at exactly the current minute.
public struct SunPath: Equatable, Sendable {
    /// Altitude drawn at the top of the arc. Higher suns (in the tropics) are clamped.
    public static let altitudeScale = 70.0
    /// Altitude of the sun's centre at sunrise and sunset (standard refraction): the horizon.
    static let horizonAltitude = -0.833

    public let sunrise: Date
    public let sunset: Date
    public let coordinates: Coordinates

    /// Nil during a polar day or night: the sun neither rises nor sets.
    public init?(day: SolarDay, coordinates: Coordinates) {
        guard let sunrise = day.sunrise, let sunset = day.sunset, sunset > sunrise else { return nil }
        self.sunrise = sunrise
        self.sunset = sunset
        self.coordinates = coordinates
    }

    private var length: TimeInterval { sunset.timeIntervalSince(sunrise) }

    /// Where the sun is at `date`. Before sunrise and after sunset it stays at the ends.
    public func point(at date: Date) -> SunPathPoint {
        point(atFraction: date.timeIntervalSince(sunrise) / length)
    }

    /// The point at a share of the daylight, 0 at sunrise and 1 at sunset.
    public func point(atFraction fraction: Double) -> SunPathPoint {
        let x = min(max(fraction, 0), 1)
        let altitude = SunCalculator.altitude(at: sunrise.addingTimeInterval(x * length), coordinates: coordinates)
        let height = (altitude - Self.horizonAltitude) / (Self.altitudeScale - Self.horizonAltitude)
        return SunPathPoint(x: x, height: min(max(height, 0), 1))
    }

    /// The whole path, `count + 1` points from sunrise to sunset.
    public func samples(count: Int) -> [SunPathPoint] {
        samples(from: 0, to: 1, count: count)
    }

    /// Part of the path, for the travelled and the remaining stretch. Both ends are included.
    public func samples(from start: Double, to end: Double, count: Int) -> [SunPathPoint] {
        guard end > start, count > 0 else { return [] }
        return (0...count).map { point(atFraction: start + (end - start) * Double($0) / Double(count)) }
    }

    /// Share of the night elapsed: 0 at sunset, 1 at the next sunrise.
    public static func nightProgress(at date: Date, sunset: Date, sunrise: Date) -> Double {
        let night = sunrise.timeIntervalSince(sunset)
        guard night > 0 else { return 0 }
        return min(max(date.timeIntervalSince(sunset) / night, 0), 1)
    }

    /// Where the moon is drawn at night, on this (the coming) day's path. It starts at the
    /// sunset end when the sun goes down and reaches the sunrise end when it comes back.
    public func moonPoint(at date: Date, sunset previousSunset: Date) -> SunPathPoint {
        point(atFraction: 1 - Self.nightProgress(at: date, sunset: previousSunset, sunrise: sunrise))
    }
}
