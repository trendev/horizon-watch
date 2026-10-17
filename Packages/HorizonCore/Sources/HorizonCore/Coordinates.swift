import Foundation

public struct Coordinates: Hashable, Codable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// A move beyond this distance shifts sun times by about a minute and triggers a replan.
    public static let significantDistance: Double = 20_000

    /// Great-circle distance in metres (haversine).
    public func distance(to other: Coordinates) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    public func isSignificantlyFar(from other: Coordinates) -> Bool {
        distance(to: other) > Self.significantDistance
    }
}
