//
//  Expense.swift
//  ExpenseCompanion
//
//  Core SwiftData model for a single expense entry, including optional
//  location metadata captured at the moment the expense was logged.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class Expense {
    var id: UUID
    var amount: Double
    var categoryRaw: String
    var note: String
    var date: Date
    var createdAt: Date

    // MARK: Location (all optional — user can disable location tracking entirely)
    var latitude: Double?
    var longitude: Double?
    /// Human-readable place name from reverse geocoding, e.g. "Cafe Coffee Day, Andheri"
    var placeName: String?
    /// Broader locality, e.g. "Andheri West, Mumbai"
    var locality: String?

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var hasLocation: Bool { latitude != nil && longitude != nil }

    init(
        amount: Double,
        category: ExpenseCategory,
        note: String = "",
        date: Date = .now,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        locality: String? = nil
    ) {
        self.id = UUID()
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.note = note
        self.date = date
        self.createdAt = .now
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.locality = locality
    }
}
