import Foundation

public enum FollowUp: String, Codable, Sendable, CaseIterable {
    case off
    case twoMinutes
    case fiveMinutes

    public var minutes: Int? {
        switch self {
        case .off: nil
        case .twoMinutes: 2
        case .fiveMinutes: 5
        }
    }

    public var interval: TimeInterval? {
        minutes.map { TimeInterval($0 * 60) }
    }
}

public enum Vibration: String, Codable, Sendable, CaseIterable {
    /// Rising pattern at sunrise, falling at sunset.
    case signature
    case standard
}

/// What the user has chosen. Both alarms are on by default.
public struct AlarmSettings: Equatable, Codable, Sendable {
    public var sunriseEnabled = true
    public var sunsetEnabled = true
    /// Ids of single occurrences the user skipped from the 7-day page.
    public var skipped: Set<String> = []
    public var followUp: FollowUp = .twoMinutes
    public var vibration: Vibration = .signature

    public init() {}

    public var anyEnabled: Bool {
        sunriseEnabled || sunsetEnabled
    }

    public func isEnabled(_ kind: SolarEvent.Kind) -> Bool {
        kind == .sunrise ? sunriseEnabled : sunsetEnabled
    }

    public mutating func setEnabled(_ enabled: Bool, for kind: SolarEvent.Kind) {
        switch kind {
        case .sunrise: sunriseEnabled = enabled
        case .sunset: sunsetEnabled = enabled
        }
    }

    public func rings(_ event: SolarEvent) -> Bool {
        isEnabled(event.kind) && !skipped.contains(event.id)
    }

    public mutating func toggleSkip(_ id: String) {
        if skipped.remove(id) == nil {
            skipped.insert(id)
        }
    }

    /// Drops skips of days that are over, so the set cannot grow for ever.
    public mutating func pruneSkips(before day: CivilDay) {
        let limit = day.iso
        skipped = skipped.filter { id in
            guard let dash = id.firstIndex(of: "-") else { return false }
            return String(id[id.index(after: dash)...]) >= limit
        }
    }
}
