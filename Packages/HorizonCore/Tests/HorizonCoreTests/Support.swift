import Foundation
import Testing
@testable import HorizonCore

func date(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso)!
}

func timeZone(_ identifier: String) -> TimeZone {
    TimeZone(identifier: identifier)!
}

enum Place {
    static let paris = Coordinates(latitude: 48.8566, longitude: 2.3522)
    static let newYork = Coordinates(latitude: 40.7128, longitude: -74.0060)
    static let reykjavik = Coordinates(latitude: 64.1466, longitude: -21.9426)
    static let tromso = Coordinates(latitude: 69.6492, longitude: 18.9553)
}

struct Fixture: Sendable, CustomTestStringConvertible {
    let city: String
    let coordinates: Coordinates
    let timeZone: TimeZone
    let day: CivilDay
    let sunrise: Date?
    let sunset: Date?
    let note: String

    var testDescription: String { "\(city) \(day.iso)" }

    /// Every row of docs/fixtures/sun-times.csv, read from the repository so there is a single copy.
    static let all: [Fixture] = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.append(path: "docs/fixtures/sun-times.csv")
        let text = try! String(contentsOf: url, encoding: .utf8)
        return text.split(separator: "\n").dropFirst().map { line in
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            let parts = f[4].split(separator: "-").map { Int($0)! }
            return Fixture(
                city: f[0],
                coordinates: Coordinates(latitude: Double(f[1])!, longitude: Double(f[2])!),
                timeZone: TimeZone(identifier: f[3])!,
                day: CivilDay(year: parts[0], month: parts[1], day: parts[2]),
                sunrise: f[5] == "none" ? nil : date(f[5]),
                sunset: f[6] == "none" ? nil : date(f[6]),
                note: f[7]
            )
        }
    }()
}
