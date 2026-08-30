//
//  LocationManager.swift
//  ExpenseCompanion
//
//  Singleton wrapper around CoreLocation. Handles permission requests,
//  one-shot location fetches for tagging expenses, and reverse geocoding.
//
//  Privacy notes (see Info.plist keys required below):
//  - Requests "While Using" authorization only — never "Always".
//  - Never sends coordinates anywhere; everything stays in the local/CloudKit-synced store.
//  - Callers must treat every returned value as optional: the user can deny
//    permission or disable location per-expense, and the UI must degrade gracefully.
//
//  Required Info.plist entries:
//  - NSLocationWhenInUseUsageDescription:
//      "We use your location to tag expenses with where you spent money,
//       so you can see spending patterns by place. This never leaves your device."
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject {

    static let shared = LocationManager()

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var isResolvingLocation: Bool = false

    /// User-level toggle, separate from OS permission — lets someone grant location
    /// access but still opt out of automatic tagging per the app's own privacy setting.
    @Published var isLocationTaggingEnabled: Bool {
        didSet { UserDefaults.standard.set(isLocationTaggingEnabled, forKey: Self.taggingPreferenceKey) }
    }

    private static let taggingPreferenceKey = "locationTaggingEnabled"

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    /// Continuation used to bridge CLLocationManagerDelegate's callback style to async/await.
    private var oneShotContinuation: CheckedContinuation<CLLocation?, Never>?

    private override init() {
        self.authorizationStatus = CLLocationManager().authorizationStatus
        self.isLocationTaggingEnabled = UserDefaults.standard.object(forKey: Self.taggingPreferenceKey) as? Bool ?? true
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermissionIfNeeded() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// Fetches a single current location, suitable for tagging a new expense.
    /// Returns nil if permission isn't granted, tagging is disabled, or the fetch fails/times out.
    func fetchCurrentLocation() async -> CLLocation? {
        guard isLocationTaggingEnabled, isAuthorized else { return nil }

        isResolvingLocation = true
        defer { isResolvingLocation = false }

        return await withCheckedContinuation { continuation in
            self.oneShotContinuation = continuation
            manager.requestLocation()

            // Safety timeout so the UI never hangs waiting on a stuck GPS fix.
            Task {
                try? await Task.sleep(for: .seconds(6))
                if let cont = self.oneShotContinuation {
                    self.oneShotContinuation = nil
                    cont.resume(returning: nil)
                }
            }
        }
    }

    /// Reverse-geocodes a location into a display-friendly place name + locality.
    /// e.g. ("Cafe Coffee Day", "Andheri West, Mumbai")
    func reverseGeocode(_ location: CLLocation) async -> (placeName: String?, locality: String?) {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return (nil, nil) }

            let placeName = placemark.name
            let localityParts = [placemark.subLocality, placemark.locality].compactMap { $0 }
            let locality = localityParts.isEmpty ? placemark.locality : localityParts.joined(separator: ", ")

            return (placeName, locality)
        } catch {
            return (nil, nil)
        }
    }

    /// Convenience: fetch + reverse geocode in one call for the Add Expense flow.
    func resolveCurrentPlace() async -> (coordinate: CLLocationCoordinate2D?, placeName: String?, locality: String?) {
        guard let location = await fetchCurrentLocation() else { return (nil, nil, nil) }
        let (placeName, locality) = await reverseGeocode(location)
        return (location.coordinate, placeName, locality)
    }
}

extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
            if let continuation = self.oneShotContinuation {
                self.oneShotContinuation = nil
                continuation.resume(returning: location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let continuation = self.oneShotContinuation {
                self.oneShotContinuation = nil
                continuation.resume(returning: nil)
            }
        }
    }
}
