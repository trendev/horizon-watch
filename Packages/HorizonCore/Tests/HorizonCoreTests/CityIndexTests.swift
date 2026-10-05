import Foundation
import Testing
@testable import HorizonCore

/// Writes the cities15000.bin layout, mirroring Tools/build_cities.py.
func encodeCities(_ cities: [(name: String, cc: String, lat: Float, lon: Float, population: UInt32)]) -> Data {
    var header = Data("HZC1".utf8)
    var records = Data()
    var names = Data()
    func append<T>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
    }
    append(UInt32(cities.count).littleEndian, to: &header)
    for city in cities {
        let name = Data(city.name.utf8)
        append(city.lat.bitPattern.littleEndian, to: &records)
        append(city.lon.bitPattern.littleEndian, to: &records)
        append(city.population.littleEndian, to: &records)
        append(UInt32(names.count).littleEndian, to: &records)
        append(UInt16(name.count).littleEndian, to: &records)
        records.append(contentsOf: Array(city.cc.utf8))
        names.append(name)
    }
    return header + records + names
}

@Suite struct CityIndexTests {
    let index = try! CityIndex(data: encodeCities([
        ("São Paulo", "BR", -23.5475, -46.6361, 12_400_232),
        ("New York City", "US", 40.7143, -74.006, 8_804_190),
        ("London", "GB", 51.5085, -0.1257, 8_961_989),
        ("Paris", "FR", 48.8534, 2.3488, 2_138_551),
        ("Parma", "IT", 44.8027, 10.3290, 146_299),
        ("Versailles", "FR", 48.8047, 2.1204, 85_416)
    ]))

    @Test func readsEveryRecord() {
        #expect(index.count == 6)
        let first = index.city(at: 0)
        #expect(first.name == "São Paulo")
        #expect(first.countryCode == "BR")
        #expect(first.population == 12_400_232)
        #expect(abs(first.coordinates.latitude - -23.5475) < 0.001)
    }

    @Test func findsTheNearestCity() {
        #expect(index.nearest(to: Place.paris)?.name == "Paris")
        #expect(index.nearest(to: Coordinates(latitude: 48.80, longitude: 2.13))?.name == "Versailles")
        #expect(index.nearest(to: Place.newYork)?.name == "New York City")
    }

    @Test func placeNamePrefersTheBigCityOverACloserSmallTown() throws {
        let index = try CityIndex(data: encodeCities([
            ("New York City", "US", 40.7143, -74.006, 8_804_190),
            ("Hoboken", "US", 40.7440, -74.0324, 60_419),
            ("Versailles", "FR", 48.8047, 2.1204, 85_416),
            ("Paris", "FR", 48.8534, 2.3488, 2_138_551)
        ]))
        // Midtown: Hoboken's centre is 4 km away, New York's 5 km, yet this is New York.
        let midtown = Coordinates(latitude: 40.7549, longitude: -73.9840)
        #expect(index.nearest(to: midtown)?.name == "Hoboken")
        #expect(index.place(near: midtown)?.name == "New York City")
        // In a smaller town itself, the town keeps its name.
        #expect(index.place(near: Coordinates(latitude: 48.80, longitude: 2.13))?.name == "Versailles")
        #expect(index.place(near: Coordinates(latitude: 40.7450, longitude: -74.03))?.name == "Hoboken")
    }

    @Test func searchesByPrefixInFileOrder() {
        #expect(index.search(prefix: "par", limit: 10).map(\.name) == ["Paris", "Parma"])
        #expect(index.search(prefix: "par", limit: 1).map(\.name) == ["Paris"])
    }

    @Test func searchIgnoresCaseAndAccents() {
        #expect(index.search(prefix: "sao", limit: 10).map(\.name) == ["São Paulo"])
        #expect(index.search(prefix: "LOND", limit: 10).map(\.name) == ["London"])
    }

    @Test func emptySearchListsTheBiggestCities() {
        #expect(index.search(prefix: "  ", limit: 2).map(\.name) == ["São Paulo", "New York City"])
    }

    @Test func rejectsForeignData() {
        #expect(throws: CityIndex.FormatError.self) { try CityIndex(data: Data("nope".utf8)) }
        #expect(throws: CityIndex.FormatError.self) {
            try CityIndex(data: Data("HZC1".utf8) + Data([9, 0, 0, 0]))
        }
    }
}

@Suite struct CoordinatesTests {
    @Test func distanceIsGreatCircle() {
        let london = Coordinates(latitude: 51.5085, longitude: -0.1257)
        #expect(abs(Place.paris.distance(to: london) - 344_000) < 3_000)
    }

    @Test func aMoveOfMoreThanTwentyKilometresIsSignificant() {
        let versailles = Coordinates(latitude: 48.8047, longitude: 2.1204)
        let meaux = Coordinates(latitude: 48.9603, longitude: 2.8884)
        #expect(Place.paris.isSignificantlyFar(from: versailles) == false)
        #expect(Place.paris.isSignificantlyFar(from: meaux))
    }
}

/// Checks against the real list shipped in the app.
@Suite struct BundledCitiesTests {
    let index: CityIndex = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return try! CityIndex(contentsOf: url.appending(path: "HorizonApp/Resources/cities15000.bin"))
    }()

    @Test func holdsTheWorldsCities() {
        #expect(index.count > 25_000)
        #expect(index.city(at: 0).population > 10_000_000)
    }

    @Test(arguments: [
        ("Paris", 48.8566, 2.3522), ("New York City", 40.7128, -74.0060), ("Sydney", -33.8688, 151.2093),
        ("Quito", -0.1807, -78.4678), ("Reykjavík", 64.1466, -21.9426), ("Tromsø", 69.6492, 18.9553),
        ("Tokyo", 35.6762, 139.6503), ("Marseille", 43.2965, 5.3698)
    ])
    func namesThePlaceAPersonWouldName(name: String, latitude: Double, longitude: Double) {
        #expect(index.place(near: Coordinates(latitude: latitude, longitude: longitude))?.name == name)
    }

    @Test func hasNoNumberedDistricts() {
        #expect(index.search(prefix: "Paris 0", limit: 5).isEmpty)
        #expect(index.search(prefix: "Paris", limit: 1).first?.countryCode == "FR")
    }
}
