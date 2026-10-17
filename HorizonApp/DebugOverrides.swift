import Foundation
import HorizonCore

/// Launch arguments used by UI tests and screenshots to reproduce a scene, for example the
/// mockup's "Paris, 29 September 2026, 16:17". They do nothing in release builds.
///
///     -horizonNow 2026-09-29T16:17:00+02:00 -horizonLocation 48.8566,2.3522
///     -horizonTimeZone Europe/Paris -horizonSkipOnboarding YES -horizonReset YES
struct DebugOverrides {
    var clockOffset: TimeInterval = 0
    var coordinates: Coordinates?
    var timeZone: TimeZone?
    var skipOnboarding = false
    var reset = false
    /// Do not show the system permission prompts, which a UI test cannot answer.
    var skipSystemPrompts = false
    var sunriseEnabled: Bool?
    var sunsetEnabled: Bool?
    var armedOccurrenceID: String?
    /// Shows the alarm screen at launch, as if this alarm were ringing.
    var ringing: SolarEvent.Kind?

    var isActive: Bool { clockOffset != 0 || coordinates != nil }

    static let current: DebugOverrides = {
        var overrides = DebugOverrides()
        #if DEBUG
        let defaults = UserDefaults.standard
        if let text = defaults.string(forKey: "horizonNow"), let date = ISO8601DateFormatter().date(from: text) {
            overrides.clockOffset = date.timeIntervalSinceNow
        }
        if let parts = defaults.string(forKey: "horizonLocation")?.split(separator: ",").map({ Double($0) }),
            parts.count == 2, let latitude = parts[0], let longitude = parts[1] {
            overrides.coordinates = Coordinates(latitude: latitude, longitude: longitude)
        }
        overrides.timeZone = defaults.string(forKey: "horizonTimeZone").flatMap(TimeZone.init(identifier:))
        overrides.skipOnboarding = defaults.bool(forKey: "horizonSkipOnboarding")
        overrides.reset = defaults.bool(forKey: "horizonReset")
        overrides.skipSystemPrompts = defaults.bool(forKey: "horizonSkipPrompts")
        overrides.sunriseEnabled = defaults.object(forKey: "horizonSunrise") as? Bool
            ?? defaults.string(forKey: "horizonSunrise").map { ($0 as NSString).boolValue }
        overrides.sunsetEnabled = defaults.string(forKey: "horizonSunset").map { ($0 as NSString).boolValue }
        overrides.armedOccurrenceID = defaults.string(forKey: "horizonArmed")
        overrides.ringing = defaults.string(forKey: "horizonRing").flatMap(SolarEvent.Kind.init(rawValue:))
        #endif
        return overrides
    }()
}
