import Foundation
import Testing
@testable import HorizonCore

@Suite struct SettingsStoreTests {
    func makeStore() -> (SettingsStore, String) {
        let suite = "horizon.tests.\(UUID().uuidString)"
        return (SettingsStore(defaults: UserDefaults(suiteName: suite)!), suite)
    }

    @Test func defaultsMatchTheSpec() {
        let (store, suite) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        #expect(store.alarm.sunriseEnabled)
        #expect(store.alarm.sunsetEnabled)
        #expect(store.alarm.skipped.isEmpty)
        #expect(store.alarm.followUp == .twoMinutes)
        #expect(store.alarm.vibration == .signature)
        #expect(store.lastLocation == nil)
        #expect(store.onboardingDone == false)
        #expect(store.armedOccurrenceID == nil)
    }

    @Test func valuesSurviveANewStoreOnTheSameSuite() {
        let (store, suite) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        store.alarm.sunriseEnabled = false
        store.alarm.followUp = .fiveMinutes
        store.alarm.vibration = .standard
        store.alarm.skipped = ["sunset-2026-09-29"]
        store.onboardingDone = true
        store.armedOccurrenceID = "sunset-2026-09-30"
        store.lastLocation = StoredLocation(
            coordinates: Place.paris, timestamp: date("2026-09-29T16:05:00+02:00"),
            source: .gps, cityName: "Paris", countryCode: "FR")

        let reopened = SettingsStore(defaults: UserDefaults(suiteName: suite)!)
        #expect(reopened.alarm.sunriseEnabled == false)
        #expect(reopened.alarm.sunsetEnabled)
        #expect(reopened.alarm.followUp == .fiveMinutes)
        #expect(reopened.alarm.vibration == .standard)
        #expect(reopened.alarm.skipped == ["sunset-2026-09-29"])
        #expect(reopened.onboardingDone)
        #expect(reopened.armedOccurrenceID == "sunset-2026-09-30")
        #expect(reopened.lastLocation?.cityName == "Paris")
        #expect(reopened.lastLocation?.source == .gps)
        #expect(reopened.lastLocation?.coordinates == Place.paris)
    }

    @Test func clearingTheArmedOccurrenceRemovesIt() {
        let (store, suite) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        store.armedOccurrenceID = "sunset-2026-09-30"
        store.armedOccurrenceID = nil
        #expect(store.armedOccurrenceID == nil)
    }
}

@Suite struct AlarmSettingsTests {
    @Test func enabledFlagFollowsTheKind() {
        var settings = AlarmSettings()
        settings.setEnabled(false, for: .sunrise)
        #expect(settings.isEnabled(.sunrise) == false)
        #expect(settings.isEnabled(.sunset))
        #expect(settings.anyEnabled)
        settings.setEnabled(false, for: .sunset)
        #expect(settings.anyEnabled == false)
    }

    @Test func skipTogglesAndOldSkipsArePruned() {
        var settings = AlarmSettings()
        settings.toggleSkip("sunset-2026-09-29")
        settings.toggleSkip("sunrise-2026-10-02")
        #expect(settings.skipped == ["sunset-2026-09-29", "sunrise-2026-10-02"])
        settings.toggleSkip("sunset-2026-09-29")
        #expect(settings.skipped == ["sunrise-2026-10-02"])

        settings.skipped = ["sunset-2026-09-27", "sunrise-2026-09-29", "sunset-2026-10-02"]
        settings.pruneSkips(before: CivilDay(year: 2026, month: 9, day: 29))
        #expect(settings.skipped == ["sunrise-2026-09-29", "sunset-2026-10-02"])
    }

    @Test func followUpMinutes() {
        #expect(FollowUp.off.interval == nil)
        #expect(FollowUp.twoMinutes.interval == 120)
        #expect(FollowUp.fiveMinutes.interval == 300)
    }
}
