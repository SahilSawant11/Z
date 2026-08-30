//
//  AddExpenseViewModel.swift
//  ExpenseCompanion
//

import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class AddExpenseViewModel {

    private let repository: ExpenseRepository
    private let locationManager: LocationManager

    var amountText: String = ""
    var category: ExpenseCategory = .food
    var note: String = ""
    var date: Date = .now

    // Location state
    var resolvedCoordinate: CLLocationCoordinate2D?
    var resolvedPlaceName: String?
    var resolvedLocality: String?
    var isResolvingLocation: Bool = false
    var locationTaggingEnabled: Bool

    var saveError: String?

    var isValid: Bool {
        guard let amount = Double(amountText) else { return false }
        return amount > 0
    }

    init(repository: ExpenseRepository, locationManager: LocationManager = .shared) {
        self.repository = repository
        self.locationManager = locationManager
        self.locationTaggingEnabled = locationManager.isLocationTaggingEnabled
    }

    /// Kicks off location resolution as soon as the Add Expense sheet appears,
    /// so by the time the user finishes typing the amount, the location chip is ready.
    func resolveLocationIfEnabled() async {
        guard locationTaggingEnabled else { return }
        locationManager.requestPermissionIfNeeded()
        isResolvingLocation = true
        let result = await locationManager.resolveCurrentPlace()
        resolvedCoordinate = result.coordinate
        resolvedPlaceName = result.placeName
        resolvedLocality = result.locality
        isResolvingLocation = false
    }

    func clearLocation() {
        resolvedCoordinate = nil
        resolvedPlaceName = nil
        resolvedLocality = nil
    }

    @discardableResult
    func save() -> Bool {
        guard let amount = Double(amountText), amount > 0 else {
            saveError = "Enter a valid amount."
            return false
        }

        let expense = Expense(
            amount: amount,
            category: category,
            note: note,
            date: date,
            latitude: resolvedCoordinate?.latitude,
            longitude: resolvedCoordinate?.longitude,
            placeName: resolvedPlaceName,
            locality: resolvedLocality
        )

        do {
            try repository.add(expense)
            Haptics.light()
            return true
        } catch {
            saveError = "Couldn't save that expense. Try again."
            return false
        }
    }
}
