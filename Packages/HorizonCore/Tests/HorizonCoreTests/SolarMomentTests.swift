import Foundation
import Testing
@testable import HorizonCore

/// What the complications show at one instant.
@Suite struct SolarMomentTests {
    let paris = AlarmPlanner(coordinates: Place.paris, timeZone: timeZone("Europe/Paris"))

    @Test func daytimeGaugeRunsFromSunriseToSunset() throws {
        let now = date("2026-09-29T16:17:00+02:00")
        let moment = try #require(SolarMoment.make(at: now, planner: paris, settings: AlarmSettings()))
        #expect(moment.next.id == "sunset-2026-09-29")
        #expect(moment.isNight == false)
        #expect(moment.isTomorrow == false)
        #expect(abs(moment.periodStart.timeIntervalSince(date("2026-09-29T07:47:03+02:00"))) <= 60)
        #expect(moment.periodEnd == moment.next.date)
        #expect(abs(moment.progress(at: now) - 0.722) < 0.01)
        #expect(moment.following?.id == "sunrise-2026-09-30")
    }

    @Test func nightGaugeRunsFromSunsetToTomorrowsSunrise() throws {
        let now = date("2026-09-29T22:40:00+02:00")
        let moment = try #require(SolarMoment.make(at: now, planner: paris, settings: AlarmSettings()))
        #expect(moment.next.id == "sunrise-2026-09-30")
        #expect(moment.isNight)
        #expect(moment.isTomorrow)
        #expect(abs(moment.periodStart.timeIntervalSince(date("2026-09-29T19:33:55+02:00"))) <= 60)
        // 3 h 06 into a night of 12 h 14.
        #expect(abs(moment.progress(at: now) - 0.254) < 0.01)
    }

    @Test func beforeDawnTheNightStartedYesterday() throws {
        let now = date("2026-09-29T03:00:00+02:00")
        let moment = try #require(SolarMoment.make(at: now, planner: paris, settings: AlarmSettings()))
        #expect(moment.next.id == "sunrise-2026-09-29")
        #expect(moment.isTomorrow == false)
        #expect(moment.periodStart < now)
        #expect(CivilDay(containing: moment.periodStart, in: timeZone("Europe/Paris")).iso == "2026-09-28")
    }

    @Test func progressStaysBetweenZeroAndOne() throws {
        let moment = try #require(SolarMoment.make(
            at: date("2026-09-29T16:17:00+02:00"), planner: paris, settings: AlarmSettings()))
        #expect(moment.progress(at: date("2026-09-29T02:00:00+02:00")) == 0)
        #expect(moment.progress(at: date("2026-09-29T23:00:00+02:00")) == 1)
    }

    @Test func tellsWhetherTheNextEventRings() throws {
        var settings = AlarmSettings()
        settings.sunsetEnabled = false
        let moment = try #require(SolarMoment.make(
            at: date("2026-09-29T16:17:00+02:00"), planner: paris, settings: settings))
        #expect(moment.isEnabled == false)
    }

    @Test func polarDayHasNoMoment() {
        let tromso = AlarmPlanner(coordinates: Place.tromso, timeZone: timeZone("Europe/Oslo"))
        #expect(SolarMoment.make(at: date("2026-06-21T12:00:00+02:00"), planner: tromso, settings: AlarmSettings()) == nil)
    }

    @Test func timelineHasAnEntryEveryQuarterHourAndJustAfterEachEvent() throws {
        let now = date("2026-09-29T16:17:00+02:00")
        let dates = SolarMoment.timelineDates(from: now, planner: paris, settings: AlarmSettings())

        #expect(dates.first == now)
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == dates.count)
        #expect(dates.allSatisfy { $0 < now.addingTimeInterval(24 * 3600) })
        #expect(dates.contains(date("2026-09-29T16:30:00+02:00")))
        #expect(dates.contains(date("2026-09-30T16:15:00+02:00")))
        // 96 quarter hours, now, and the two events of the next 24 hours.
        #expect(dates.count == 99)

        // The entry just after sunset already targets tomorrow's sunrise.
        let afterSunset = try #require(dates.first { $0 > date("2026-09-29T19:33:00+02:00") && $0 < date("2026-09-29T19:45:00+02:00") })
        let moment = try #require(SolarMoment.make(at: afterSunset, planner: paris, settings: AlarmSettings()))
        #expect(moment.next.id == "sunrise-2026-09-30")
        #expect(afterSunset.timeIntervalSince(date("2026-09-29T19:33:55+02:00")) < 62)
    }
}
