//
//  GeofenceManager.swift
//  ExpenseCompanion
//
//  Location-based budgeting alerts ("You're near your favorite mall, you've
//  spent ₹X here this month"). This is intentionally SEPARATE from
//  LocationManager's "While Using" expense-tagging permission:
//
//  Geofence monitoring only fires reliably in the background with "Always"
//  authorization — a materially bigger privacy ask than tagging an expense
//  while the app is open. So this manager is opt-in only, behind its own
//  toggle in Settings, and requests "Always" only at the moment the user
//  turns that toggle on — never bundled into onboarding.
//
//  iOS caps region monitoring at 20 regions per app, so we only monitor the
//  user's most-visited places (see LocationInsightsEngine.minVisitsForFrequentPlace).
//
//  Required Info.plist entries (only needed if you ship this feature):
//  - NSLocationAlwaysAndWhenInUseUsageDescription:
//      "To alert you when you're near a place you tend to overspend at, we
//       need location access even when the app is closed. This stays on your
//       device and you can turn it off anytime in Settings."
//

import Foundation
import CoreLocation
import UserNotifications
import Combine

@MainActor
final class GeofenceManager: NSObject, ObservableObject {

    static let shared = GeofenceManager()

    @Published private(set) var isMonitoringEnabled: Bool {
        didSet { UserDefaults.standard.set(isMonitoringEnabled, forKey: Self.enabledKey) }
    }
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private static let enabledKey = "geofenceMonitoringEnabled"
    private let manager = CLLocationManager()
    private let maxMonitoredRegions = 20

    private override init() {
        self.isMonitoringEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        self.authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
    }

    /// Call this only from an explicit user action (a Settings toggle), never automatically.
    func enableMonitoring(for places: [FrequentPlace]) {
        manager.requestAlwaysAuthorization()
        isMonitoringEnabled = true
        Task { await requestNotificationPermission() }
        refreshMonitoredRegions(places: places)
    }

    func disableMonitoring() {
        isMonitoringEnabled = false
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
    }

    /// Re-syncs the monitored regions to match the given places (e.g. after the
    /// user relabels or deletes a frequent place). Only the top N by spending
    /// limit relevance are monitored, respecting the 20-region OS cap.
    func refreshMonitoredRegions(places: [FrequentPlace]) {
        guard isMonitoringEnabled else { return }

        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }

        let placesToMonitor = places
            .filter { $0.spendingLimit != nil } // only monitor places with a set limit — that's the useful signal
            .prefix(maxMonitoredRegions)

        for place in placesToMonitor {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                radius: max(place.radiusMeters, 100),
                identifier: place.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
    }

    private func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    /// Builds the alert copy: "Alert: You're near {place}. You've spent ₹X here this month."
    private func notifyEntered(regionIdentifier: String, spentThisMonth: Double, currencyCode: String, placeLabel: String) {
        let content = UNMutableNotificationContent()
        content.title = "Nearby: \(placeLabel)"
        content.body = "You've spent \(CurrencyFormatter.format(spentThisMonth, currencyCode: currencyCode)) here this month."
        content.sound = .default

        let request = UNNotificationRequest(identifier: regionIdentifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

extension GeofenceManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // The actual spend lookup needs a ModelContext, which this manager doesn't
        // own — the app delegate / scene should observe region-entry via
        // NotificationCenter and call back into a repository to fetch the real
        // total before calling notifyEntered(...). Wired up as a TODO for the
        // app target since it needs a live ModelContext at delivery time.
        NotificationCenter.default.post(name: .didEnterMonitoredRegion, object: region.identifier)
    }
}

extension Notification.Name {
    nonisolated static let didEnterMonitoredRegion = Notification.Name("didEnterMonitoredRegion")
}
