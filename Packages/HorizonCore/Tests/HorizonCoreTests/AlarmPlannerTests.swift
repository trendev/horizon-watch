import Foundation
import Testing
@testable import HorizonCore

@Suite struct AlarmPlannerTests {
    let paris = AlarmPlanner(coordinates: Place.paris, timeZone: timeZone("Europe/Paris"))
    let afternoon = date("2026-09-29T16:17:00+02:00")
    let evening = date("2026-09-29T22:40:00+02:00")

    @Test func daytimeTargetsTodaysSunset() throws {
        let plan = paris.plan(now: afternoon, settings: AlarmSettings())
        let next = try #require(plan.nextEvent)
        #expect(next.id == "sunset-2026-09-29")
        #expect(abs(next.date.timeIntervalSince(date("2026-09-29T19:33:39+02:00"))) <= 60)
        #expect(plan.isNight == false)
        #expect(plan.displayIsTomorrow == false)
        #expect(plan.displayDay.day.iso == "2026-09-29")
    }

    @Test func afterSunsetLooksAtTomorrow() throws {
        let plan = paris.plan(now: evening, settings: AlarmSettings())
        #expect(try #require(plan.nextEvent).id == "sunrise-2026-09-30")
        #expect(plan.isNight)
        #expect(plan.displayIsTomorrow)
        #expect(plan.displayDay.day.iso == "2026-09-30")
    }

    @Test func beforeSunriseIsNightButShowsToday() {
        let plan = paris.plan(now: date("2026-09-29T03:00:00+02:00"), settings: AlarmSettings())
        #expect(plan.isNight)
        #expect(plan.displayIsTomorrow == false)
        #expect(plan.displayDay.day.iso == "2026-09-29")
    }

    @Test func daylightFractionRunsFromZeroToOne() {
        let plan = paris.plan(now: afternoon, settings: AlarmSettings())
        // 07:47 → 19:33, at 16:17: 8.5 h of 11.77 h.
        #expect(abs(plan.daylightFraction(at: afternoon) - 0.722) < 0.01)
        #expect(plan.daylightFraction(at: date("2026-09-29T05:00:00+02:00")) == 0)
        #expect(plan.daylightFraction(at: date("2026-09-29T21:00:00+02:00")) == 1)
    }

    @Test func nextOccurrenceIsArmableWithinThirtySixHours() throws {
        let plan = paris.plan(now: afternoon, settings: AlarmSettings())
        #expect(try #require(plan.nextOccurrence).id == "sunset-2026-09-29")
        #expect(plan.armable == plan.nextOccurrence)
    }

    @Test func skippedOccurrenceIsPassedOver() throws {
        var settings = AlarmSettings()
        settings.skipped = ["sunset-2026-09-29"]
        let plan = paris.plan(now: afternoon, settings: settings)
        #expect(try #require(plan.nextOccurrence).id == "sunrise-2026-09-30")
        // The countdown still targets the real next event.
        #expect(try #require(plan.nextEvent).id == "sunset-2026-09-29")
    }

    @Test func disabledKindNeverOccurs() {
        var settings = AlarmSettings()
        settings.sunriseEnabled = false
        let plan = paris.plan(now: afternoon, settings: settings)
        #expect(plan.occurrences.allSatisfy { $0.kind == .sunset })
        #expect(plan.occurrences.count == 15)
    }

    @Test func bothAlarmsOffLeavesNothingToRing() {
        var settings = AlarmSettings()
        settings.sunriseEnabled = false
        settings.sunsetEnabled = false
        let plan = paris.plan(now: afternoon, settings: settings)
        #expect(plan.occurrences.isEmpty)
        #expect(plan.armable == nil)
        #expect(plan.nextEvent != nil)
    }

    @Test func occurrenceBeyondThirtySixHoursIsNotArmable() throws {
        var settings = AlarmSettings()
        settings.sunriseEnabled = false
        settings.skipped = ["sunset-2026-09-30"]
        let plan = paris.plan(now: date("2026-09-29T20:00:00+02:00"), settings: settings)
        #expect(try #require(plan.nextOccurrence).id == "sunset-2026-10-01")
        #expect(plan.armable == nil)
    }

    @Test func fifteenDaysArePlannedInAscendingOrder() {
        let plan = paris.plan(now: date("2026-09-29T00:00:01+02:00"), settings: AlarmSettings())
        #expect(plan.occurrences.count == 30)
        #expect(plan.occurrences.first?.id == "sunrise-2026-09-29")
        #expect(plan.occurrences.last?.id == "sunset-2026-10-13")
        #expect(zip(plan.occurrences, plan.occurrences.dropFirst()).allSatisfy { $0.date < $1.date })
        #expect(plan.occurrences.allSatisfy { $0.date < plan.windowEnd })
    }

    @Test func pastEventsOfTodayAreNotPlanned() {
        let plan = paris.plan(now: afternoon, settings: AlarmSettings())
        #expect(plan.occurrences.allSatisfy { $0.date > afternoon })
        #expect(plan.occurrences.count == 29)
    }

    @Test func polarDayPlansNothing() {
        let tromso = AlarmPlanner(coordinates: Place.tromso, timeZone: timeZone("Europe/Oslo"))
        let plan = tromso.plan(now: date("2026-06-21T12:00:00+02:00"), settings: AlarmSettings())
        #expect(plan.today.polar == .day)
        #expect(plan.displayDay.polar == .day)
        #expect(plan.nextEvent == nil)
        #expect(plan.occurrences.isEmpty)
        #expect(plan.armable == nil)
    }

    @Test func polarNightIsNight() {
        let tromso = AlarmPlanner(coordinates: Place.tromso, timeZone: timeZone("Europe/Oslo"))
        let plan = tromso.plan(now: date("2026-12-21T12:00:00+01:00"), settings: AlarmSettings())
        #expect(plan.today.polar == .night)
        #expect(plan.isNight)
    }

    @Test func sunsetAfterMidnightIsStillTheNextEventJustBeforeIt() throws {
        let reykjavik = AlarmPlanner(coordinates: Place.reykjavik, timeZone: timeZone("Atlantic/Reykjavik"))
        let plan = reykjavik.plan(now: date("2026-06-22T00:01:00+00:00"), settings: AlarmSettings())
        let next = try #require(plan.nextEvent)
        #expect(next.id == "sunset-2026-06-21")
        #expect(plan.nextOccurrence == next)
        #expect(plan.isNight == false)
    }

    @Test func daylightSavingDayUsesAbsoluteTimes() throws {
        let plan = paris.plan(now: date("2026-03-28T12:00:00+01:00"), settings: AlarmSettings())
        let sunrise = try #require(plan.occurrences.first { $0.id == "sunrise-2026-03-29" })
        #expect(abs(sunrise.date.timeIntervalSince(date("2026-03-29T07:35:01+02:00"))) <= 60)
        let sunset = try #require(plan.occurrences.first { $0.id == "sunset-2026-03-29" })
        #expect(abs(sunset.date.timeIntervalSince(date("2026-03-29T20:16:33+02:00"))) <= 60)
    }

    @Test func newYorkDaylightSavingDay() throws {
        let newYork = AlarmPlanner(coordinates: Place.newYork, timeZone: timeZone("America/New_York"))
        let plan = newYork.plan(now: date("2026-03-07T12:00:00-05:00"), settings: AlarmSettings())
        let sunrise = try #require(plan.occurrences.first { $0.id == "sunrise-2026-03-08" })
        #expect(abs(sunrise.date.timeIntervalSince(date("2026-03-08T07:19:06-04:00"))) <= 60)
    }

    @Test func timeZoneChangeKeepsTheSameInstant() throws {
        let now = date("2026-09-29T12:00:00-04:00")
        let local = AlarmPlanner(coordinates: Place.newYork, timeZone: timeZone("America/New_York"))
        let stale = AlarmPlanner(coordinates: Place.newYork, timeZone: timeZone("Europe/Paris"))
        let a = try #require(local.plan(now: now, settings: AlarmSettings()).nextEvent)
        let b = try #require(stale.plan(now: now, settings: AlarmSettings()).nextEvent)
        #expect(a.kind == .sunset)
        #expect(abs(a.date.timeIntervalSince(b.date)) <= 60)
    }

    @Test func weekStartsTodayAndHasSevenDays() {
        let plan = paris.plan(now: afternoon, settings: AlarmSettings())
        #expect(plan.week.map(\.day.iso) == [
            "2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02",
            "2026-10-03", "2026-10-04", "2026-10-05"
        ])
    }

    @Test func eventAfterGivesTheFollowingEvent() throws {
        let plan = paris.plan(now: afternoon, settings: AlarmSettings())
        let sunset = try #require(plan.nextEvent)
        #expect(plan.event(after: sunset)?.id == "sunrise-2026-09-30")
        #expect(plan.nextEvent(of: .sunrise)?.id == "sunrise-2026-09-30")
    }
}
