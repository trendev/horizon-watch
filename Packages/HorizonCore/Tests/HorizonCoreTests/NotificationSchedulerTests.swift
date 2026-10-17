import Foundation
import Testing
import UserNotifications
@testable import HorizonCore

final class FakeNotificationCenter: NotificationCenterProtocol {
    var pending: [UNNotificationRequest] = []
    var log: [String] = []

    func removeAllPendingNotificationRequests() {
        log.append("removeAll")
        pending.removeAll()
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        log.append("remove")
        pending.removeAll { identifiers.contains($0.identifier) }
    }

    func add(_ request: UNNotificationRequest) async throws {
        log.append("add")
        pending.append(request)
    }
}

@Suite struct NotificationPlanTests {
    let paris = AlarmPlanner(coordinates: Place.paris, timeZone: timeZone("Europe/Paris"))
    let now = date("2026-09-29T00:00:01+02:00")

    func planned(_ settings: AlarmSettings = AlarmSettings(), armed: String? = nil) -> [PlannedNotification] {
        NotificationPlan.make(plan: paris.plan(now: now, settings: settings), settings: settings, armedOccurrenceID: armed)
    }

    @Test func fullWindowStaysUnderTheSystemLimit() {
        let all = planned()
        #expect(all.count == 61)
        #expect(all.count <= NotificationPlan.systemLimit)
        #expect(Set(all.map(\.id)).count == all.count)
    }

    @Test func eachOccurrenceHasAMainAndAFollowUp() throws {
        let all = planned()
        let main = try #require(all.first { $0.id == "sunset-2026-09-29.main" })
        let followUp = try #require(all.first { $0.id == "sunset-2026-09-29.followup" })
        #expect(main.kind == .main)
        #expect(followUp.kind == .followUp)
        #expect(main.fireDate == main.event?.date)
        #expect(followUp.fireDate.timeIntervalSince(main.fireDate) == 120)
    }

    @Test func fiveMinuteFollowUp() throws {
        var settings = AlarmSettings()
        settings.followUp = .fiveMinutes
        let all = planned(settings)
        let main = try #require(all.first { $0.id == "sunrise-2026-09-29.main" })
        let followUp = try #require(all.first { $0.id == "sunrise-2026-09-29.followup" })
        #expect(followUp.fireDate.timeIntervalSince(main.fireDate) == 300)
    }

    @Test func followUpOffSchedulesOnlyMains() {
        var settings = AlarmSettings()
        settings.followUp = .off
        let all = planned(settings)
        #expect(all.count == 31)
        #expect(all.contains { $0.kind == .followUp } == false)
    }

    @Test func refillReminderClosesTheWindow() throws {
        let all = planned()
        let refill = try #require(all.last)
        #expect(refill.id == "refill")
        #expect(refill.kind == .refill)
        #expect(all.dropLast().allSatisfy { $0.fireDate < refill.fireDate })
        #expect(refill.fireDate == paris.plan(now: now, settings: AlarmSettings()).windowEnd)
    }

    @Test func noAlarmsMeansNoNotificationsAtAll() {
        var settings = AlarmSettings()
        settings.sunriseEnabled = false
        settings.sunsetEnabled = false
        #expect(planned(settings).isEmpty)
    }

    @Test func armedOccurrenceRingsSixtySecondsLateAsAFallback() throws {
        let all = planned(armed: "sunrise-2026-09-29")
        let main = try #require(all.first { $0.id == "sunrise-2026-09-29.main" })
        #expect(main.fireDate.timeIntervalSince(try #require(main.event).date) == 60)
        let other = try #require(all.first { $0.id == "sunset-2026-09-29.main" })
        #expect(other.fireDate == other.event?.date)
    }

    @Test func mainCarriesTheEventThatFollows() throws {
        let main = try #require(planned().first { $0.id == "sunset-2026-09-29.main" })
        #expect(main.following?.id == "sunrise-2026-09-30")
    }

    @Test func nothingIsScheduledInThePast() {
        let afternoon = date("2026-09-29T16:17:00+02:00")
        let all = NotificationPlan.make(
            plan: paris.plan(now: afternoon, settings: AlarmSettings()),
            settings: AlarmSettings(),
            armedOccurrenceID: nil
        )
        #expect(all.allSatisfy { $0.fireDate > afternoon })
        #expect(all.contains { $0.id.hasPrefix("sunrise-2026-09-29") } == false)
    }
}

@MainActor
@Suite struct NotificationSchedulerTests {
    let paris = AlarmPlanner(coordinates: Place.paris, timeZone: timeZone("Europe/Paris"))
    let now = date("2026-09-29T00:00:01+02:00")

    func content(_ planned: PlannedNotification) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = planned.id
        return content
    }

    @Test func replacesEverythingPending() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let planned = NotificationPlan.make(
            plan: paris.plan(now: now, settings: AlarmSettings()), settings: AlarmSettings(), armedOccurrenceID: nil)

        try await scheduler.apply(planned, content: content)
        try await scheduler.apply(planned, content: content)

        #expect(center.pending.count == 61)
        #expect(center.pending.count <= 64)
        #expect(center.log.first == "removeAll")
        #expect(center.pending.first?.content.title == "sunrise-2026-09-29.main")
    }

    @Test func triggersFireAtTheExactSecond() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let planned = NotificationPlan.make(
            plan: paris.plan(now: now, settings: AlarmSettings()), settings: AlarmSettings(), armedOccurrenceID: nil)
        try await scheduler.apply(planned, content: content)

        let request = try #require(center.pending.first { $0.identifier == "sunset-2026-09-29.main" })
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats == false)
        let fire = try #require(Calendar.current.date(from: trigger.dateComponents))
        let expected = try #require(planned.first { $0.id == "sunset-2026-09-29.main" }).fireDate
        #expect(abs(fire.timeIntervalSince(expected)) < 1)
    }

    @Test func acknowledgingCancelsOnlyThatFollowUp() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let planned = NotificationPlan.make(
            plan: paris.plan(now: now, settings: AlarmSettings()), settings: AlarmSettings(), armedOccurrenceID: nil)
        try await scheduler.apply(planned, content: content)

        scheduler.acknowledge(eventID: "sunset-2026-09-29")

        #expect(center.pending.count == 60)
        #expect(center.pending.contains { $0.identifier == "sunset-2026-09-29.followup" } == false)
        #expect(center.pending.contains { $0.identifier == "sunset-2026-09-30.followup" })
    }

    @Test func sessionStartCancelsTheFallbackAndItsFollowUp() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let planned = NotificationPlan.make(
            plan: paris.plan(now: now, settings: AlarmSettings()), settings: AlarmSettings(),
            armedOccurrenceID: "sunrise-2026-09-29")
        try await scheduler.apply(planned, content: content)

        scheduler.cancelAll(eventID: "sunrise-2026-09-29")

        #expect(center.pending.count == 59)
        #expect(center.pending.contains { $0.identifier.hasPrefix("sunrise-2026-09-29") } == false)
    }
}
