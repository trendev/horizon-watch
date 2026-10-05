import Foundation

/// Sunrise and sunset from the NOAA solar calculator equations (Meeus, *Astronomical Algorithms*).
///
/// Sunrise and sunset are the moments the sun's upper limb touches the horizon with standard
/// refraction: solar altitude −0.833°, the convention of Apple Weather, NOAA and most almanacs.
public enum SunCalculator {
    static let zenith = 90.833

    public static func solarDay(_ day: CivilDay, at coordinates: Coordinates) -> SolarDay {
        let julianDay = day.julianDay
        let origin = day.midnightUTC
        let latitude = coordinates.latitude
        let longitude = coordinates.longitude

        // Minutes are counted from 00:00 UTC of the civil day. They can be negative (Sydney)
        // or above 1440 (Reykjavik in June): the event still belongs to this day.
        var noon = 720 - 4 * longitude
        for _ in 0..<2 {
            noon = 720 - 4 * longitude - sun(at: julianDay + noon / 1440).equationOfTime
        }

        func date(_ minutes: Double) -> Date {
            origin.addingTimeInterval(minutes * 60)
        }

        let cosine = hourAngleCosine(latitude: latitude, declination: sun(at: julianDay + noon / 1440).declination)
        if cosine > 1 || cosine < -1 {
            return SolarDay(
                day: day, sunrise: nil, sunset: nil, solarNoon: date(noon),
                polar: cosine > 1 ? .night : .day)
        }

        // NOAA's procedure: evaluate at 0 h UTC, then once more at the time just found.
        func event(rising: Bool) -> Date? {
            var minutes = 0.0
            for _ in 0..<2 {
                let sun = sun(at: julianDay + minutes / 1440)
                let cosine = hourAngleCosine(latitude: latitude, declination: sun.declination)
                guard (-1...1).contains(cosine) else { return nil }
                let hourAngle = degrees(acos(cosine))
                minutes = 720 - 4 * (longitude + (rising ? hourAngle : -hourAngle)) - sun.equationOfTime
            }
            return date(minutes)
        }

        return SolarDay(
            day: day, sunrise: event(rising: true), sunset: event(rising: false),
            solarNoon: date(noon), polar: .none)
    }

    public static func solarDay(containing date: Date, in timeZone: TimeZone, at coordinates: Coordinates) -> SolarDay {
        solarDay(CivilDay(containing: date, in: timeZone), at: coordinates)
    }

    // MARK: - NOAA equations

    /// Declination in degrees and equation of time in minutes.
    private static func sun(at julianDay: Double) -> (declination: Double, equationOfTime: Double) {
        let t = (julianDay - 2_451_545) / 36_525

        let meanLongitude = (280.46646 + t * (36_000.76983 + 0.0003032 * t)).truncatingRemainder(dividingBy: 360)
        let meanAnomaly = 357.52911 + t * (35_999.05029 - 0.0001537 * t)
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        let m = radians(meanAnomaly)
        let centre = sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * m) * (0.019993 - 0.000101 * t)
            + sin(3 * m) * 0.000289
        let omega = radians(125.04 - 1934.136 * t)
        let apparentLongitude = meanLongitude + centre - 0.00569 - 0.00478 * sin(omega)

        let seconds = 21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))
        let obliquity = radians(23 + (26 + seconds / 60) / 60 + 0.00256 * cos(omega))

        let declination = degrees(asin(sin(obliquity) * sin(radians(apparentLongitude))))

        let y = tan(obliquity / 2) * tan(obliquity / 2)
        let l = radians(meanLongitude)
        let equationOfTime = 4 * degrees(
            y * sin(2 * l)
                - 2 * eccentricity * sin(m)
                + 4 * eccentricity * y * sin(m) * cos(2 * l)
                - 0.5 * y * y * sin(4 * l)
                - 1.25 * eccentricity * eccentricity * sin(2 * m))

        return (declination, equationOfTime)
    }

    /// Above 1: the sun stays below the horizon. Below −1: it stays above.
    private static func hourAngleCosine(latitude: Double, declination: Double) -> Double {
        let lat = radians(latitude)
        let dec = radians(declination)
        return cos(radians(zenith)) / (cos(lat) * cos(dec)) - tan(lat) * tan(dec)
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}
