import CoreLocation
import Foundation

/// The watch's own position, asked once at a time. About 1 km is enough: 20 km moves the
/// sun times by roughly a minute.
@MainActor
public final class LocationProvider: NSObject {
    public enum LocationError: Error {
        case denied
        case unavailable
    }

    private let manager = CLLocationManager()
    private var locationWaiters: [CheckedContinuation<Coordinates, Error>] = []
    private var authorizationWaiters: [CheckedContinuation<Void, Never>] = []

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    public var isAuthorized: Bool {
        let status = manager.authorizationStatus
        #if os(macOS)
        return status == .authorizedAlways
        #else
        return status == .authorizedAlways || status == .authorizedWhenInUse
        #endif
    }

    public var isDenied: Bool {
        let status = manager.authorizationStatus
        return status == .denied || status == .restricted
    }

    /// Shows the system prompt if the user has not answered yet. Returns whether location is allowed.
    public func requestAuthorization() async -> Bool {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                authorizationWaiters.append(continuation)
                manager.requestWhenInUseAuthorization()
            }
        }
        return isAuthorized
    }

    public func currentCoordinates() async throws -> Coordinates {
        guard isAuthorized else { throw LocationError.denied }
        return try await withCheckedThrowingContinuation { continuation in
            locationWaiters.append(continuation)
            if locationWaiters.count == 1 {
                manager.requestLocation()
            }
        }
    }

    private func finish(_ result: Result<Coordinates, Error>) {
        let waiters = locationWaiters
        locationWaiters.removeAll()
        waiters.forEach { $0.resume(with: result) }
    }

    private func authorizationChanged() {
        guard manager.authorizationStatus != .notDetermined else { return }
        let waiters = authorizationWaiters
        authorizationWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        let coordinates = Coordinates(latitude: coordinate.latitude, longitude: coordinate.longitude)
        Task { @MainActor in self.finish(.success(coordinates)) }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(.failure(LocationError.unavailable)) }
    }

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.authorizationChanged() }
    }
}
