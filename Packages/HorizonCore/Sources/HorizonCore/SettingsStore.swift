import Foundation

/// Where the sun times are computed for, and how that position was obtained.
public struct StoredLocation: Equatable, Codable, Sendable {
    public enum Source: String, Codable, Sendable {
        case gps
        /// Picked from the offline city list.
        case manual
    }

    public var coordinates: Coordinates
    public var timestamp: Date
    public var source: Source
    public var cityName: String?
    public var countryCode: String?

    public init(
        coordinates: Coordinates, timestamp: Date, source: Source, cityName: String? = nil, countryCode: String? = nil
    ) {
        self.coordinates = coordinates
        self.timestamp = timestamp
        self.source = source
        self.cityName = cityName
        self.countryCode = countryCode
    }
}

/// Persisted state, kept on the watch only. The app and the widget extension share it
/// through the App Group.
public final class SettingsStore: @unchecked Sendable {
    public static let appGroup = "group.fr.trendev.horizon"

    public static let shared = SettingsStore(defaults: UserDefaults(suiteName: appGroup) ?? .standard)

    private enum Key {
        static let alarm = "alarm"
        static let lastLocation = "lastLocation"
        static let onboardingDone = "onboardingDone"
        static let armedOccurrenceID = "armedOccurrenceID"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var alarm: AlarmSettings {
        get { decode(AlarmSettings.self, Key.alarm) ?? AlarmSettings() }
        set { encode(newValue, Key.alarm) }
    }

    public var lastLocation: StoredLocation? {
        get { decode(StoredLocation.self, Key.lastLocation) }
        set { encode(newValue, Key.lastLocation) }
    }

    public var onboardingDone: Bool {
        get { defaults.bool(forKey: Key.onboardingDone) }
        set { defaults.set(newValue, forKey: Key.onboardingDone) }
    }

    /// Id of the occurrence currently scheduled as a persistent alarm, if any.
    public var armedOccurrenceID: String? {
        get { defaults.string(forKey: Key.armedOccurrenceID) }
        set { defaults.set(newValue, forKey: Key.armedOccurrenceID) }
    }

    private func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private func encode<T: Encodable>(_ value: T?, _ key: String) {
        defaults.set(value.flatMap { try? JSONEncoder().encode($0) }, forKey: key)
    }
}
