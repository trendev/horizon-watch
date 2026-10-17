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
    /// The alarm vibrating right now, shown full screen.
    private(set) var ringing: SolarEvent?
    /// A day picked on the 7-day page, shown on the arc instead of today.
    var viewedDay: SolarDay?
    var toast: Toast?
    /// Set by a complication tap or the "Open Horizon" shortcut: the next activation confirms
    /// the armed alarm with "Persistent alarm · Set for 19:33".
    @ObservationIgnored var confirmsArming = false

    @ObservationIgnored private let sessions = AlarmSessionController()
    /// An occurrence whose session was refused; not retried until the app next becomes active.
    @ObservationIgnored private var refusedArmID: String?

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

        sessions.haptic = { [weak self] in self?.haptic ?? .notification }
        sessions.onStart = { [weak self] in self?.alarmStarted() }
        sessions.onEnd = { [weak self] failed in self?.alarmEnded(failed: failed) }

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

    /// The real path of a day, drawn on the arc.
    func sunPath(_ day: SolarDay) -> SunPath? {
        location.flatMap { SunPath(day: day, coordinates: $0.coordinates) }
    }

    /// The sunset that began the night ending with `day`'s sunrise.
    func sunset(before day: SolarDay) -> Date? {
        location.flatMap {
            AlarmPlanner(coordinates: $0.coordinates, timeZone: timeZone).solarDay(day.day.adding(days: -1)).sunset
        }
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
        let city = cities?.place(near: coordinates)
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
        if let kind = overrides.ringing {
            ringing = plan?.nextEvent(of: kind)
        }
    }

    /// Launch, return to the foreground, complication tap, notification tap.
    func becameActive() {
        refusedArmID = nil
        // The Control Center toggle writes the settings from outside the app.
        var stored = store.alarm
        if overrides.sunriseEnabled != nil { stored.sunriseEnabled = settings.sunriseEnabled }
        if overrides.sunsetEnabled != nil { stored.sunsetEnabled = settings.sunsetEnabled }
        settings = stored
        replan()
        if confirmsArming { confirmArming() }
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

        updateArming(plan)
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

    // MARK: - Persistent alarm

    private var isActive: Bool {
        WKApplication.shared().applicationState == .active
    }

    /// Signature: rising at sunrise, falling at sunset, so the wrist tells which one it is.
    private var haptic: WKHapticType {
        guard settings.vibration == .signature, let kind = armedEvent?.kind ?? ringing?.kind else {
            return .notification
        }
        return kind == .sunrise ? .directionUp : .directionDown
    }

    private var armedEvent: SolarEvent? {
        guard let armedID, let location else { return nil }
        let planner = AlarmPlanner(coordinates: location.coordinates, timeZone: timeZone)
        let today = CivilDay(containing: now(), in: timeZone)
        return (-1...2).flatMap { planner.solarDay(today.adding(days: $0)).events }.first { $0.id == armedID }
    }

    private func setArmed(_ id: String?) {
        armedID = id
        store.armedOccurrenceID = id
    }

    /// Arming rule of the spec: whenever the app is active, the next enabled, non-skipped
    /// occurrence within 36 hours becomes a persistent alarm. Only one can be armed.
    private func updateArming(_ plan: AlarmPlan) {
        guard overrides.armedOccurrenceID == nil, onboardingDone, ringing == nil else { return }
        if isActive {
            if let event = plan.armable, event.id != refusedArmID {
                sessions.arm(id: event.id, at: wallClock(event.date))
                setArmed(event.id)
            } else {
                sessions.disarm()
                setArmed(nil)
            }
        } else if armedID != plan.nextOccurrence?.id {
            // In the background nothing can be armed, but a stale alarm must not ring.
            sessions.disarm()
            setArmed(nil)
        }
    }

    /// A complication or the shortcut opened the app. If it is already active, confirm now.
    func openedFromOutside() {
        confirmsArming = true
        if hasLaunched, isActive {
            replan()
            confirmArming()
        }
    }

    private func confirmArming() {
        confirmsArming = false
        guard isNextOccurrenceArmed, let event = plan?.nextOccurrence else { return }
        show(Toast(
            title: L10n.string("mode.persistent"),
            subtitle: L10n.format("toast.armed.subtitle", Fmt.time(event.date, in: timeZone)),
            kind: event.kind))
    }

    /// watchOS relaunched the app for a session armed by an earlier launch.
    func adopt(_ session: WKExtendedRuntimeSession) {
        sessions.adopt(session, id: armedID)
    }

    private func alarmStarted() {
        ringing = armedEvent ?? plan?.nextOccurrence
        // The session works, so the fallback notification and its follow-up are not needed.
        if let armedID { scheduler.cancelAll(eventID: armedID) }
    }

    private func alarmEnded(failed: Bool) {
        if failed { refusedArmID = armedID }
        ringing = nil
        setArmed(nil)
        // In the foreground this arms the next occurrence. After Stop on the system alert the
        // app is in the background, and the next occurrence stays automatic.
        replan()
    }

    /// Stop on the alarm screen, or a double tap.
    func stopAlarm() {
        if sessions.isRinging {
            sessions.stop()
        } else {
            alarmEnded(failed: false)
        }
    }

    // MARK: - Week

    func toggleSkip(_ event: SolarEvent) {
        update { $0.toggleSkip(event.id) }
    }

    var isLocationDenied: Bool {
        overrides.coordinates == nil && locationProvider.isDenied
    }

    // MARK: - Notifications

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
            do {
                try await self.scheduler.apply(planned) {
                    Notifications.content(for: $0, placeName: placeName, timeZone: timeZone)
                }
            } catch {
                // Typically: notifications are not allowed. The alarms then rely on the session only.
                #if DEBUG
                print("HORIZON scheduling failed: \(error.localizedDescription)")
                #endif
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
