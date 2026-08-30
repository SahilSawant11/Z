//
//  DailyBudgetSettings.swift
//  ExpenseCompanion
//

import Foundation
import SwiftData

/// Singleton-style settings record (the app maintains exactly one of these).
/// Kept as a SwiftData model rather than UserDefaults so it syncs via CloudKit
/// alongside the rest of the user's data.
@Model
final class DailyBudgetSettings {
    var id: UUID
    var dailyLimit: Double
    var rolloverEnabled: Bool
    var currencyCode: String // e.g. "INR", "USD", "EUR"

    init(dailyLimit: Double = 500, rolloverEnabled: Bool = false, currencyCode: String = "INR") {
        self.id = UUID()
        self.dailyLimit = dailyLimit
        self.rolloverEnabled = rolloverEnabled
        self.currencyCode = currencyCode
    }
}

/// Auto-detected or user-labeled frequent location (Home, Work, Gym, Cafe...).
/// Populated by clustering expense coordinates in LocationInsightsEngine (Phase 2/4).
@Model
final class FrequentPlace {
    var id: UUID
    var label: String // "Home", "Work", "Gym", or custom
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    /// Optional per-location spending limit for location-based budgeting alerts.
    var spendingLimit: Double?

    init(label: String, latitude: Double, longitude: Double, radiusMeters: Double = 150, spendingLimit: Double? = nil) {
        self.id = UUID()
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.spendingLimit = spendingLimit
    }
}
