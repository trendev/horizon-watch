import Foundation
import HorizonCore

/// Every time, duration and place name goes through a formatter, so it follows the watch's
/// language, 12/24-hour setting and numbering system. Strings are never concatenated.
enum Fmt {
    /// "19:33" or "7:33 PM"
    static func time(_ date: Date, in timeZone: TimeZone) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// "11h 46m", rounded down to the minute.
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    /// "Wed 30"
    static func weekday(_ day: CivilDay, in timeZone: TimeZone) -> String {
        var style = Date.FormatStyle().weekday(.abbreviated).day()
        style.timeZone = timeZone
        return day.start(in: timeZone).addingTimeInterval(12 * 3600).formatted(style)
    }

    /// "12 min. ago"
    static func relative(_ date: Date, to now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: min(date, now), relativeTo: now)
    }

    /// "Paris, France"
    static func place(city: String, countryCode: String?) -> String {
        guard let countryCode, let country = Locale.current.localizedString(forRegionCode: countryCode) else {
            return city
        }
        return [city, country].formatted(.list(type: .and, width: .narrow))
    }

    /// "48.86° N · 2.35° E" style coordinates, with localized numbers.
    static func coordinates(_ coordinates: Coordinates) -> String {
        let latitude = Measurement(value: abs(coordinates.latitude), unit: UnitAngle.degrees)
        let longitude = Measurement(value: abs(coordinates.longitude), unit: UnitAngle.degrees)
        let style = Measurement<UnitAngle>.FormatStyle(
            width: .narrow, numberFormatStyle: .number.precision(.fractionLength(2)))
        let north = coordinates.latitude >= 0 ? "N" : "S"
        let east = coordinates.longitude >= 0 ? "E" : "W"
        return ["\(latitude.formatted(style)) \(north)", "\(longitude.formatted(style)) \(east)"]
            .joined(separator: " · ")
    }
}

/// Lookups in the String Catalog generated from docs/strings.csv.
enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    /// For keys with `%@`, `%lld` or positional arguments.
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: .current, arguments: arguments)
    }

    static func eventName(_ kind: SolarEvent.Kind) -> String {
        "event.\(kind.rawValue)"
    }
}
