import Foundation
import Testing
@testable import HorizonCore

struct AltitudeFixture: Sendable, CustomTestStringConvertible {
    let city: String
    let coordinates: Coordinates
    let time: Date
    let altitude: Double

    var testDescription: String { "\(city) \(time)" }

    /// Every row of docs/fixtures/sun-altitudes.csv (astral, no refraction).
    static let all: [AltitudeFixture] = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        let text = try! String(contentsOf: url.appending(path: "docs/fixtures/sun-altitudes.csv"), encoding: .utf8)
        return text.split(separator: "\n").dropFirst().map { line in
            let f = line.split(separator: ",").map(String.init)
            return AltitudeFixture(
                city: f[0], coordinates: Coordinates(latitude: Double(f[1])!, longitude: Double(f[2])!),
                time: date(f[3]), altitude: Double(f[4])!)
        }
    }()
}

@Suite struct SunAltitudeTests {
    @Test func fixtureFileHasEveryRow() {
        #expect(AltitudeFixture.all.count == 14)
    }

    @Test(arguments: AltitudeFixture.all)
    func matchesTheReferenceWithinATenthOfADegree(_ fixture: AltitudeFixture) {
        let altitude = SunCalculator.altitude(at: fixture.time, coordinates: fixture.coordinates)
        #expect(abs(altitude - fixture.altitude) < 0.1)
    }
}

@Suite struct SunPathTests {
    let october = SunCalculator.solarDay(CivilDay(year: 2026, month: 10, day: 17), at: Place.paris)

    func path(_ month: Int, _ day: Int, at place: Coordinates = Place.paris) -> SunPath? {
        SunPath(day: SunCalculator.solarDay(CivilDay(year: 2026, month: month, day: day), at: place), coordinates: place)
    }

    @Test func acrossIsLinearInTime() throws {
        let path = try #require(SunPath(day: october, coordinates: Place.paris))
        let sunrise = try #require(october.sunrise)
        let sunset = try #require(october.sunset)
        let length = sunset.timeIntervalSince(sunrise)

        #expect(path.point(at: sunrise).x == 0)
        #expect(path.point(at: sunset).x == 1)
        #expect(abs(path.point(at: sunrise.addingTimeInterval(length / 2)).x - 0.5) < 1e-9)
        let afternoon = date("2026-10-17T16:17:00+02:00")
        #expect(abs(path.point(at: afternoon).x - afternoon.timeIntervalSince(sunrise) / length) < 1e-9)
        // Outside daylight the point stays at the ends.
        #expect(path.point(at: sunrise.addingTimeInterval(-3600)).x == 0)
        #expect(path.point(at: sunset.addingTimeInterval(3600)).x == 1)
    }

    @Test func heightIsTheRealAltitudeOnAFixedScale() throws {
        let path = try #require(SunPath(day: october, coordinates: Place.paris))
        let afternoon = date("2026-10-17T16:17:00+02:00")
        let expected = (21.8590 + 0.833) / (SunPath.altitudeScale + 0.833)
        #expect(abs(path.point(at: afternoon).height - expected) < 0.002)
    }

    @Test func heightIsZeroAtBothEndsAndHighestAtSolarNoon() throws {
        let path = try #require(SunPath(day: october, coordinates: Place.paris))
        let samples = path.samples(count: 48)
        #expect(samples.count == 49)
        #expect(abs(samples.first!.height) < 0.005)
        #expect(abs(samples.last!.height) < 0.005)

        let highest = try #require(samples.max { $0.height < $1.height })
        let length = try #require(october.dayLength)
        let highestTime = try #require(october.sunrise).addingTimeInterval(highest.x * length)
        #expect(abs(highestTime.timeIntervalSince(october.solarNoon)) < 10 * 60)
    }

    @Test func theArcIsHighInSummerAndLowInWinter() throws {
        let june = try #require(path(6, 21)).samples(count: 48).map(\.height).max()!
        let december = try #require(path(12, 21)).samples(count: 48).map(\.height).max()!
        #expect(abs(june - 0.92) < 0.02)
        #expect(abs(december - 0.26) < 0.02)
    }

    @Test func aSunHigherThanTheScaleIsClamped() throws {
        let quito = try #require(path(3, 21, at: Coordinates(latitude: -0.1807, longitude: -78.4678)))
        #expect(quito.samples(count: 48).map(\.height).max() == 1)
    }

    @Test func theSunIsOnTheDrawnCurve() throws {
        let path = try #require(SunPath(day: october, coordinates: Place.paris))
        let samples = path.samples(count: 48)
        let length = try #require(october.dayLength)
        for index in [0, 7, 24, 31, 48] {
            let time = try #require(october.sunrise).addingTimeInterval(length * Double(index) / 48)
            // Equal up to the rounding of date arithmetic.
            #expect(abs(path.point(at: time).x - samples[index].x) < 1e-9)
            #expect(abs(path.point(at: time).height - samples[index].height) < 1e-9)
        }
    }

    @Test func partialSamplesStartAndEndOnThePath() throws {
        let path = try #require(SunPath(day: october, coordinates: Place.paris))
        let travelled = path.samples(from: 0, to: 0.7, count: 20)
        #expect(travelled.first == path.point(atFraction: 0))
        #expect(travelled.last == path.point(atFraction: 0.7))
        #expect(path.samples(from: 0.7, to: 0.7, count: 20).count <= 1)
    }

    @Test func theMoonCrossesTheNightFromTheSunsetEndToTheSunriseEnd() throws {
        let evening = try #require(SunCalculator.solarDay(CivilDay(year: 2026, month: 10, day: 17), at: Place.paris).sunset)
        let tomorrow = SunCalculator.solarDay(CivilDay(year: 2026, month: 10, day: 18), at: Place.paris)
        let morning = try #require(tomorrow.sunrise)
        let path = try #require(SunPath(day: tomorrow, coordinates: Place.paris))
        let middle = evening.addingTimeInterval(morning.timeIntervalSince(evening) / 2)

        #expect(SunPath.nightProgress(at: evening, sunset: evening, sunrise: morning) == 0)
        #expect(abs(SunPath.nightProgress(at: middle, sunset: evening, sunrise: morning) - 0.5) < 1e-9)
        #expect(SunPath.nightProgress(at: morning, sunset: evening, sunrise: morning) == 1)

        #expect(path.moonPoint(at: evening, sunset: evening).x == 1)
        #expect(abs(path.moonPoint(at: middle, sunset: evening).x - 0.5) < 1e-9)
        #expect(path.moonPoint(at: morning, sunset: evening).x == 0)
        // The moon rides on the drawn arc.
        #expect(path.moonPoint(at: middle, sunset: evening) == path.point(atFraction: 0.5))
    }

    @Test func polarDaysHaveNoPath() {
        #expect(path(6, 21, at: Place.tromso) == nil)
        #expect(path(12, 21, at: Place.tromso) == nil)
    }
}
