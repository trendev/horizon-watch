import HorizonCore
import WidgetKit

/// A `SolarMoment` from HorizonCore, with what the extension adds to display it.
struct SolarSnapshot: Sendable {
    let moment: SolarMoment
    let placeName: String
    let timeZone: TimeZone

    var next: SolarEvent { moment.next }
    var isNight: Bool { moment.isNight }
    var isTomorrow: Bool { moment.isTomorrow }

    static func planner(store: SettingsStore = .shared, timeZone: TimeZone = .current) -> AlarmPlanner? {
        store.lastLocation.map { AlarmPlanner(coordinates: $0.coordinates, timeZone: timeZone) }
    }

    static func make(at date: Date, store: SettingsStore = .shared, timeZone: TimeZone = .current) -> SolarSnapshot? {
        guard let planner = planner(store: store, timeZone: timeZone),
            let moment = SolarMoment.make(at: date, planner: planner, settings: store.alarm)
        else { return nil }
        return SolarSnapshot(moment: moment, placeName: store.lastLocation?.cityName ?? "", timeZone: timeZone)
    }

    /// Paris on the mockup's day, for the watch face editor.
    static let sample: SolarSnapshot = {
        let zone = TimeZone(identifier: "Europe/Paris") ?? .current
        let date = ISO8601DateFormatter().date(from: "2026-09-29T16:17:00+02:00") ?? .now
        let planner = AlarmPlanner(coordinates: Coordinates(latitude: 48.8566, longitude: 2.3522), timeZone: zone)
        return SolarSnapshot(
            moment: SolarMoment.make(at: date, planner: planner, settings: AlarmSettings())!,
            placeName: "Paris", timeZone: zone)
    }()
}

struct SolarEntry: TimelineEntry {
    let date: Date
    let snapshot: SolarSnapshot?
    let relevance: TimelineEntryRelevance?
    /// The editor preview shows a fixed scene, so its timers must not run from the real clock.
    var isSample = false
}

struct SolarTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SolarEntry {
        SolarEntry(date: .now, snapshot: .sample, relevance: nil, isSample: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SolarEntry) -> Void) {
        if context.isPreview, SolarSnapshot.make(at: .now) == nil {
            completion(placeholder(in: context))
        } else {
            completion(entry(at: .now))
        }
    }

    /// An entry at each sunrise and sunset, plus one every 15 minutes for the gauge position.
    /// Countdowns are live text, not timeline-driven.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SolarEntry>) -> Void) {
        let now = Date()
        let dates = SolarSnapshot.planner().map {
            SolarMoment.timelineDates(from: now, planner: $0, settings: SettingsStore.shared.alarm)
        } ?? [now]
        completion(Timeline(entries: dates.map(entry(at:)), policy: .atEnd))
    }

    private func entry(at date: Date) -> SolarEntry {
        let snapshot = SolarSnapshot.make(at: date)
        return SolarEntry(date: date, snapshot: snapshot, relevance: snapshot.map { relevance($0, at: date) })
    }

    /// The Smart Stack card rises in the two hours before sunset and around dawn.
    private func relevance(_ snapshot: SolarSnapshot, at date: Date) -> TimelineEntryRelevance {
        let remaining = snapshot.next.date.timeIntervalSince(date)
        let window: TimeInterval = snapshot.next.kind == .sunset ? 2 * 3600 : 3600
        let justAfterDawn = snapshot.next.kind == .sunset && date.timeIntervalSince(snapshot.moment.periodStart) < 20 * 60
        if remaining <= window || justAfterDawn {
            return TimelineEntryRelevance(score: 100, duration: min(remaining, window))
        }
        return TimelineEntryRelevance(score: 10)
    }
}
