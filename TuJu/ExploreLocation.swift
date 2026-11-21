import Combine
import CoreLocation
import Foundation

enum ExploreLocationIssue: Error, Identifiable, LocalizedError {
    case denied, restricted, unavailable

    var id: Self { self }

    var errorDescription: String? {
        switch self {
        case .denied: "Allow TuJu to use your location in Settings and check that Location Services is on."
        case .restricted: "Location access is restricted on this device."
        case .unavailable: "TuJu couldn’t get a current location. Move to a clearer area or try again."
        }
    }
}

@MainActor
final class ExploreLocation: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var current: CLLocation?
    @Published private(set) var authorization: CLAuthorizationStatus
    private let manager: CLLocationManager
    private var pending: [UUID: CheckedContinuation<CLLocation, Error>] = [:]
    private var timeout: Task<Void, Never>?
    private var requestingPermission = false

    var isAuthorized: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    /// A fresh foreground fix for a user-initiated locate or route request.
    func currentFix() async throws -> CLLocation {
        try Task.checkCancellation()
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways,
           let fix = [current, manager.location].compactMap({ $0 }).filter(Self.isRecent).max(by: { $0.timestamp < $1.timestamp }) {
            current = fix
            return fix
        }

        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[id] = continuation
                handlePermission()
            }
        } onCancel: {
            Task { @MainActor in
                self.pending.removeValue(forKey: id)?.resume(throwing: CancellationError())
                if self.pending.isEmpty { self.stop() }
            }
        }
    }

    private static func isRecent(_ fix: CLLocation) -> Bool {
        fix.horizontalAccuracy >= 0 && CLLocationCoordinate2DIsValid(fix.coordinate) &&
            abs(fix.timestamp.timeIntervalSinceNow) <= 30
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if !isAuthorized { current = nil }
        if authorization != .notDetermined { requestingPermission = false }
        handlePermission()
    }

    private func handlePermission() {
        guard !pending.isEmpty else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            if !requestingPermission {
                requestingPermission = true
                manager.requestWhenInUseAuthorization()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            guard timeout == nil else { return }
            manager.startUpdatingLocation()
            timeout = Task {
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                finish(.failure(ExploreLocationIssue.unavailable))
            }
        case .denied: finish(.failure(ExploreLocationIssue.denied))
        case .restricted: finish(.failure(ExploreLocationIssue.restricted))
        @unknown default: finish(.failure(ExploreLocationIssue.unavailable))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !pending.isEmpty, isAuthorized, let fix = locations.last(where: Self.isRecent) else { return }
        current = fix
        finish(.success(fix))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !pending.isEmpty else { return }
        // Core Location keeps looking after a transient locationUnknown response.
        if let failure = error as? CLError, failure.code == .locationUnknown { return }
        let issue: ExploreLocationIssue = manager.authorizationStatus == .denied ? .denied : .unavailable
        finish(.failure(issue))
    }

    private func stop() {
        manager.stopUpdatingLocation()
        timeout?.cancel()
        timeout = nil
        requestingPermission = false
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        let requests = pending
        pending.removeAll()
        stop()
        for request in requests.values { request.resume(with: result) }
    }
}
