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
