import Foundation
import Testing
@testable import HorizonCore

@Suite struct SunCalculatorTests {
    @Test func fixtureFileHasEveryRow() {
        #expect(Fixture.all.count == 30)
    }

    @Test(arguments: Fixture.all)
    func matchesNOAAReferenceWithinSixtySeconds(_ fixture: Fixture) throws {
        let solar = SunCalculator.solarDay(fixture.day, at: fixture.coordinates)

        if let expected = fixture.sunrise {
            let sunrise = try #require(solar.sunrise)
            #expect(abs(sunrise.timeIntervalSince(expected)) <= 60)
        } else {
            #expect(solar.sunrise == nil)
        }
        if let expected = fixture.sunset {
            let sunset = try #require(solar.sunset)
            #expect(abs(sunset.timeIntervalSince(expected)) <= 60)
        } else {
            #expect(solar.sunset == nil)
        }
    }

    @Test func polarDayHasNoEventsAndSaysSo() {
        let solar = SunCalculator.solarDay(CivilDay(year: 2026, month: 6, day: 21), at: Place.tromso)
        #expect(solar.polar == .day)
        #expect(solar.events.isEmpty)
        #expect(solar.dayLength == nil)
    }

    @Test func polarNightHasNoEventsAndSaysSo() {
        let solar = SunCalculator.solarDay(CivilDay(year: 2026, month: 12, day: 21), at: Place.tromso)
        #expect(solar.polar == .night)
        #expect(solar.events.isEmpty)
    }

    @Test func sunsetAfterLocalMidnightBelongsToTheEveningBefore() throws {
        let solar = SunCalculator.solarDay(CivilDay(year: 2026, month: 6, day: 21), at: Place.reykjavik)
        let sunset = try #require(solar.events.last)
        #expect(sunset.kind == .sunset)
        #expect(sunset.id == "sunset-2026-06-21")
        #expect(sunset.date > date("2026-06-22T00:00:00+00:00"))
    }

    @Test func dayLengthIsSunsetMinusSunrise() throws {
        let solar = SunCalculator.solarDay(CivilDay(year: 2026, month: 9, day: 29), at: Place.paris)
        let length = try #require(solar.dayLength)
        // Mockup: 11 h 46 of daylight in Paris on 29 September 2026.
        #expect(abs(length - (11 * 3600 + 46 * 60)) < 60)
        #expect(solar.polar == .none)
    }

    @Test func solarNoonLiesBetweenSunriseAndSunset() throws {
        let solar = SunCalculator.solarDay(CivilDay(year: 2026, month: 9, day: 29), at: Place.paris)
        #expect(try #require(solar.sunrise) < solar.solarNoon)
        #expect(solar.solarNoon < (try #require(solar.sunset)))
    }

    @Test func civilDayFollowsTheTimeZone() {
        let instant = date("2026-09-29T23:30:00+02:00")
        #expect(CivilDay(containing: instant, in: timeZone("Europe/Paris")).iso == "2026-09-29")
        #expect(CivilDay(containing: instant, in: timeZone("Asia/Tokyo")).iso == "2026-09-30")
    }

    @Test func civilDayArithmeticCrossesMonths() {
        let day = CivilDay(year: 2026, month: 9, day: 29)
        #expect(day.adding(days: 2).iso == "2026-10-01")
        #expect(day.adding(days: -29).iso == "2026-08-31")
        #expect(day < day.adding(days: 1))
    }
}
