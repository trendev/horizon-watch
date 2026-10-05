import Foundation
import HorizonCore
import Observation
import UserNotifications
import WatchKit
import WidgetKit

/// Confirmation shown for two seconds in place of the bottom pill.
struct Toast: Equatable {
    var title: String
    var subtitle: String?
    var kind: SolarEvent.Kind?
}

/// State of the app. Every change that can move an alarm ends in `replan()`.
@Observable
final class AppModel {
    static let shared = AppModel()
    static let refreshTask = "refresh"

    let overrides = DebugOverrides.current
    let cities: CityIndex?
    @ObservationIgnored let locationProvider = LocationProvider()
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let scheduler = NotificationScheduler(center: UNUserNotificationCenter.current())

    private(set) var settings: AlarmSettings
    private(set) var location: StoredLocation?
    private(set) var timeZone: TimeZone
    private(set) var plan: AlarmPlan?
    private(set) var onboardingDone: Bool
    /// Occurrence scheduled as a persistent alarm: the ring around a bell.
    private(set) var armedID: String?
    private(set) var isLocating = false
    var toast: Toast?

    @ObservationIgnored private var tick: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var notificationTask: Task<Void, Never>?
    @ObservationIgnored private var notificationGeneration = 0
    /// WatchKit refuses background scheduling until the app has finished launching.
    @ObservationIgnored private var hasLaunched = false

    init() {
        if overrides.reset, let domain = UserDefaults(suiteName: SettingsStore.appGroup) {
            domain.removePersistentDomain(forName: SettingsStore.appGroup)
        }
        store = SettingsStore.shared
        cities = Bundle.main.url(forResource: "cities15000", withExtension: "bin")
            .flatMap { try? CityIndex(contentsOf: $0) }

        var settings = store.alarm
        if let enabled = overrides.sunriseEnabled { settings.sunriseEnabled = enabled }
        if let enabled = overrides.sunsetEnabled { settings.sunsetEnabled = enabled }
        self.settings = settings
        timeZone = overrides.timeZone ?? .current
        onboardingDone = overrides.skipOnboarding || store.onboardingDone
        armedID = overrides.armedOccurrenceID ?? store.armedOccurrenceID
        location = store.lastLocation

        if let coordinates = overrides.coordinates {
            location = located(coordinates, source: .gps)
        }

        NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.timeZoneChanged() }
        }
        replan()
    }

    // MARK: - Time

    /// The app's idea of now. Differs from the wall clock only under a debug override.
    func now() -> Date {
        Date().addingTimeInterval(overrides.clockOffset)
    }

    /// Wall-clock instant of an app date, for the system-driven timers.
    func wallClock(_ date: Date) -> Date {
        date.addingTimeInterval(-overrides.clockOffset)
    }

    // MARK: - Derived

    var placeName: String {
        location?.cityName ?? location.map { Fmt.coordinates($0.coordinates) } ?? ""
    }

    var isNextOccurrenceArmed: Bool {
        armedID != nil && armedID == plan?.nextOccurrence?.id
    }

    func isArmed(_ kind: SolarEvent.Kind) -> Bool {
        guard let next = plan?.nextOccurrence, next.kind == kind else { return false }
        return next.id == armedID
    }

    // MARK: - Settings

    func update(_ change: (inout AlarmSettings) -> Void) {
        change(&settings)
        store.alarm = settings
        replan()
    }

    /// A tap on a bell.
    func toggle(_ kind: SolarEvent.Kind) {
        let enabled = !settings.isEnabled(kind)
        update { $0.setEnabled(enabled, for: kind) }
        WKInterfaceDevice.current().play(.click)
        show(Toast(
            title: L10n.string("toast.\(enabled ? "on" : "off").\(kind.rawValue)"),
            subtitle: enabled ? L10n.string("toast.on.subtitle") : nil,
            kind: kind))
    }

    func show(_ toast: Toast) {
        self.toast = toast
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { self.toast = nil }
        }
    }

    func finishOnboarding() {
        onboardingDone = true
        store.onboardingDone = true
        replan()
    }

    // MARK: - Location

    private func located(_ coordinates: Coordinates, source: StoredLocation.Source) -> StoredLocation {
        let city = cities?.nearest(to: coordinates)
        return StoredLocation(
            coordinates: coordinates, timestamp: now(), source: source,
            cityName: city?.name, countryCode: city?.countryCode)
    }

    /// Asks the watch for its position. Keeps the last known one when no fix is available.
    func refreshLocation() async {
        guard overrides.coordinates == nil, locationProvider.isAuthorized, !isLocating else { return }
        isLocating = true
        defer { isLocating = false }
        guard let coordinates = try? await locationProvider.currentCoordinates() else { return }
        setLocation(located(coordinates, source: .gps))
    }

    func choose(_ city: City) {
        setLocation(StoredLocation(
            coordinates: city.coordinates, timestamp: now(), source: .manual,
            cityName: city.name, countryCode: city.countryCode))
    }

    private func setLocation(_ new: StoredLocation) {
        let moved = location.map { $0.coordinates.isSignificantlyFar(from: new.coordinates) } ?? true
        // A small move keeps the planned times: they would shift by less than a minute.
        location = moved || new.source == .manual ? new : StoredLocation(
            coordinates: location?.coordinates ?? new.coordinates, timestamp: new.timestamp, source: new.source,
            cityName: location?.cityName ?? new.cityName, countryCode: location?.countryCode ?? new.countryCode)
        store.lastLocation = location
        if moved || new.source == .manual { replan() }
    }

    private func timeZoneChanged() {
        guard overrides.timeZone == nil else { return }
        NSTimeZone.resetSystemTimeZone()
        timeZone = .current
        replan()
    }

    // MARK: - Lifecycle

    func finishedLaunching() {
        hasLaunched = true
        replan()
    }

    /// Launch, return to the foreground, complication tap, notification tap.
    func becameActive() {
        replan()
        Task { await refreshLocation() }
    }

    func backgroundRefresh() async {
        replan()
        await notificationTask?.value
    }

    // MARK: - Planning

    /// Recomputes the plan and pushes it everywhere: notifications, widgets, next refresh.
    func replan() {
        tick?.cancel()
        guard let location else {
            plan = nil
            return
        }
        let now = now()
        settings.pruneSkips(before: CivilDay(containing: now, in: timeZone).adding(days: -1))
        let plan = AlarmPlanner(coordinates: location.coordinates, timeZone: timeZone).plan(now: now, settings: settings)
        self.plan = plan
        guard hasLaunched else { return }

        scheduleNotifications(plan)
        WidgetCenter.shared.reloadAllTimelines()
        scheduleBackgroundRefresh()

        // The plan changes shape when the next event passes: day turns to night, the countdown retargets.
        if let next = plan.nextEvent {
            let delay = max(1, next.date.timeIntervalSince(now) + 1)
            tick = Task {
                try? await Task.sleep(for: .seconds(delay))
                if !Task.isCancelled { self.replan() }
            }
        }
    }

    private func scheduleNotifications(_ plan: AlarmPlan) {
        // Nothing is scheduled before the user has seen onboarding, or under a fake clock.
        guard onboardingDone, overrides.clockOffset == 0 else { return }
        let planned = NotificationPlan.make(plan: plan, settings: settings, armedOccurrenceID: armedID)
        let placeName = placeName
        let timeZone = timeZone
        notificationGeneration += 1
        let generation = notificationGeneration
        let previous = notificationTask
        notificationTask = Task {
            await previous?.value
            // A newer plan is already queued behind this one.
            guard generation == self.notificationGeneration else { return }
            try? await self.scheduler.apply(planned) {
                Notifications.content(for: $0, placeName: placeName, timeZone: timeZone)
            }
            #if DEBUG
            let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            print("HORIZON pending=\(pending.count) refill=\(pending.contains { $0.identifier == NotificationPlan.refillID })")
            #endif
        }
    }

    func requestNotificationAuthorization() async {
        guard !overrides.skipSystemPrompts else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func acknowledge(eventID: String) {
        scheduler.acknowledge(eventID: eventID)
    }

    private func scheduleBackgroundRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(12 * 3600),
            userInfo: Self.refreshTask as NSString
        ) { _ in }
    }
}
