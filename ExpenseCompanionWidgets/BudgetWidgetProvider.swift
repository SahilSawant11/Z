//
//  BudgetWidgetProvider.swift
//  ExpenseCompanionWidgets
//
//  WidgetKit timeline provider + entry type.
//  Reads spending data from the shared App Group UserDefaults written by
//  WidgetDataStore in the main app.
//

import WidgetKit
import SwiftUI

// MARK: - Re-export shared models (must also compile in this target)
// WidgetSpendingData, WidgetExpense, WidgetCategoryItem are defined in
// WidgetDataStore.swift which is added to BOTH targets.

// MARK: - Timeline Entry

struct BudgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetSpendingData

    static var placeholder: BudgetEntry {
        BudgetEntry(date: .now, data: .placeholder)
    }
}

// MARK: - Timeline Provider

struct BudgetWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> BudgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        let data = WidgetDataStore.load() ?? .placeholder
        completion(BudgetEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let data  = WidgetDataStore.load() ?? .placeholder
        let entry = BudgetEntry(date: .now, data: data)

        // Refresh at midnight for the new day, or every 30 min whichever is sooner
        let cal      = Calendar.current
        let midnight = cal.startOfDay(for: .now.addingTimeInterval(86400))
        let halfHour = Date.now.addingTimeInterval(1800)
        let next     = min(midnight, halfHour)

        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Formatting helpers (widget-safe, no UIKit dependency)

extension WidgetSpendingData {
    func fmt(_ value: Double) -> String {
        if value >= 1_00_000 { return String(format: "%.1fL", value / 1_00_000) }
        if value >= 1_000    { return String(format: "%.1fk", value / 1_000) }
        return String(format: "%.0f", value)
    }

    var spentText:     String { currencySymbol + fmt(todaySpent) }
    var limitText:     String { currencySymbol + fmt(dailyLimit) }
    var remainingText: String { currencySymbol + fmt(remaining) }
    var percentText:   String { "\(Int(usedFraction * 100))%" }
}

// MARK: - Widget-side color lookup for categories (no SwiftData / UIKit dependency)

extension String {
    /// Category color from its rawValue string.
    var categoryWidgetColor: Color {
        switch self {
        case "Food":          return .orange
        case "Transport":     return Color(red: 0.0, green: 0.63, blue: 0.93)
        case "Shopping":      return Color(red: 1.0, green: 0.18, blue: 0.47)
        case "Bills":         return .red
        case "Entertainment": return .purple
        case "Health":        return .green
        case "Education":     return Color(red: 0.39, green: 0.40, blue: 0.94)
        default:              return .gray
        }
    }
}
