//
//  WidgetDataStore.swift  (widget extension copy — READ ONLY)
//  ExpenseCompanionWidgets
//
//  Contains the shared Codable models and the load() function.
//  The update() function and WidgetCenter.reloadAllTimelines() live
//  only in the main app copy at ExpenseCompanion/Utilities/WidgetDataStore.swift
//

import Foundation
import SwiftUI

// MARK: - Shared Data Models

struct WidgetSpendingData: Codable {
    var todaySpent: Double
    var dailyLimit: Double
    var currencySymbol: String
    var currencyCode: String
    var weekTotal: Double
    var monthTotal: Double
    var transactionCount: Int
    var lastUpdated: Date
    var recentExpenses: [WidgetExpense]
    var categoryBreakdown: [WidgetCategoryItem]
    var weeklySpending: [Double]

    var usedFraction: Double {
        guard dailyLimit > 0 else { return 0 }
        return min(todaySpent / dailyLimit, 1.0)
    }
    var remaining: Double { max(dailyLimit - todaySpent, 0) }
    var isOverBudget: Bool { todaySpent > dailyLimit && dailyLimit > 0 }

    static var placeholder: WidgetSpendingData {
        WidgetSpendingData(
            todaySpent: 2340, dailyLimit: 5000,
            currencySymbol: "₹", currencyCode: "INR",
            weekTotal: 12500, monthTotal: 45200,
            transactionCount: 8, lastUpdated: .now,
            recentExpenses: [
                WidgetExpense(id: UUID(), title: "Lunch",  amount: 180,  categoryName: "Food",      categorySymbol: "fork.knife", timeString: "1:30 PM"),
                WidgetExpense(id: UUID(), title: "Uber",   amount: 220,  categoryName: "Transport", categorySymbol: "car.fill",   timeString: "9:15 AM"),
                WidgetExpense(id: UUID(), title: "Amazon", amount: 1940, categoryName: "Shopping",  categorySymbol: "bag.fill",   timeString: "Yesterday")
            ],
            categoryBreakdown: [
                WidgetCategoryItem(id: "Shopping",  name: "Shopping",  symbol: "bag.fill",  amount: 1940, fraction: 0.46),
                WidgetCategoryItem(id: "Food",      name: "Food",      symbol: "fork.knife",amount: 850,  fraction: 0.36),
                WidgetCategoryItem(id: "Transport", name: "Transport", symbol: "car.fill",  amount: 400,  fraction: 0.17)
            ],
            weeklySpending: [320, 850, 1100, 420, 610, 900, 2340]
        )
    }
}

struct WidgetExpense: Codable, Identifiable {
    var id: UUID
    var title: String
    var amount: Double
    var categoryName: String
    var categorySymbol: String
    var timeString: String
}

struct WidgetCategoryItem: Codable, Identifiable {
    var id: String
    var name: String
    var symbol: String
    var amount: Double
    var fraction: Double
}

// MARK: - Read-only store (widget extension)

enum WidgetDataStore {
    static let appGroupID = "group.com.sahil.ExpenseCompanion"
    static let dataKey    = "widgetSpendingData"

    static func load() -> WidgetSpendingData? {
        let defaults = UserDefaults(suiteName: appGroupID)
        guard let raw = defaults?.data(forKey: dataKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSpendingData.self, from: raw)
    }
}
