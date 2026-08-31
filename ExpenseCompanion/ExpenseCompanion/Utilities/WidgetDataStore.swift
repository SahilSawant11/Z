//
//  WidgetDataStore.swift
//  ExpenseCompanion
//
//  Encodes spending data into the shared App Group UserDefaults so
//  WidgetKit can read it from the widget extension process.
//  Call update() after every expense change — it also triggers a
//  WidgetCenter timeline reload so widgets refresh immediately.
//
//  App Group: group.com.sahil.ExpenseCompanion
//  (Enable this capability in both targets in Xcode → Signing & Capabilities)
//

import Foundation
import WidgetKit

// MARK: - Shared Data Model (Codable — used by both app and widget)

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
    /// Last 7 days of daily spending (index 0 = 6 days ago, index 6 = today)
    var weeklySpending: [Double]

    var usedFraction: Double {
        guard dailyLimit > 0 else { return 0 }
        return min(todaySpent / dailyLimit, 1.0)
    }

    var remaining: Double { max(dailyLimit - todaySpent, 0) }
    var isOverBudget: Bool { todaySpent > dailyLimit && dailyLimit > 0 }

    static var placeholder: WidgetSpendingData {
        WidgetSpendingData(
            todaySpent: 2340,
            dailyLimit: 5000,
            currencySymbol: "₹",
            currencyCode: "INR",
            weekTotal: 12500,
            monthTotal: 45200,
            transactionCount: 8,
            lastUpdated: .now,
            recentExpenses: [
                WidgetExpense(id: UUID(), title: "Lunch", amount: 180, categoryName: "Food", categorySymbol: "fork.knife", timeString: "1:30 PM"),
                WidgetExpense(id: UUID(), title: "Uber", amount: 220, categoryName: "Transport", categorySymbol: "car.fill", timeString: "9:15 AM"),
                WidgetExpense(id: UUID(), title: "Amazon", amount: 1940, categoryName: "Shopping", categorySymbol: "bag.fill", timeString: "Yesterday")
            ],
            categoryBreakdown: [
                WidgetCategoryItem(id: "Shopping", name: "Shopping", symbol: "bag.fill", amount: 1940, fraction: 0.46),
                WidgetCategoryItem(id: "Food", name: "Food", symbol: "fork.knife", amount: 850, fraction: 0.36),
                WidgetCategoryItem(id: "Transport", name: "Transport", symbol: "car.fill", amount: 400, fraction: 0.17)
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

// MARK: - Store

@MainActor
final class WidgetDataStore {
    static let appGroupID = "group.com.sahil.ExpenseCompanion"
    static let dataKey    = "widgetSpendingData"

    /// Write latest spending state to the shared container and reload widget timelines.
    static func update(
        todayExpenses: [Expense],
        todaySpent: Double,
        dailyLimit: Double,
        currencySymbol: String,
        currencyCode: String,
        weekTotal: Double,
        monthTotal: Double,
        recentExpenses: [Expense]
    ) {
        let calendar = Calendar.current
        let now = Date.now

        // Last 7 days spending buckets
        var buckets = Array(repeating: 0.0, count: 7)
        for expense in recentExpenses {
            let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: expense.date),
                                               to: calendar.startOfDay(for: now)).day ?? 0
            let idx = 6 - diff
            if idx >= 0 && idx < 7 { buckets[idx] += expense.amount }
        }

        // Recent expenses for list
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"
        let widgetExpenses: [WidgetExpense] = todayExpenses.prefix(5).map { e in
            WidgetExpense(id: e.id, title: e.note.isEmpty ? e.category.rawValue : e.note,
                          amount: e.amount, categoryName: e.category.rawValue,
                          categorySymbol: e.category.symbolName,
                          timeString: timeFmt.string(from: e.date))
        }

        // Category breakdown (from today only)
        var catTotals: [String: (amount: Double, symbol: String)] = [:]
        for e in todayExpenses {
            let key = e.category.rawValue
            catTotals[key] = ((catTotals[key]?.amount ?? 0) + e.amount, e.category.symbolName)
        }
        let breakdown: [WidgetCategoryItem] = catTotals
            .map { k, v in WidgetCategoryItem(id: k, name: k, symbol: v.symbol, amount: v.amount,
                                              fraction: todaySpent > 0 ? v.amount / todaySpent : 0) }
            .sorted { $0.amount > $1.amount }
            .prefix(4).map { $0 }

        let data = WidgetSpendingData(
            todaySpent: todaySpent, dailyLimit: dailyLimit,
            currencySymbol: currencySymbol, currencyCode: currencyCode,
            weekTotal: weekTotal, monthTotal: monthTotal,
            transactionCount: todayExpenses.count,
            lastUpdated: now,
            recentExpenses: widgetExpenses,
            categoryBreakdown: breakdown,
            weeklySpending: buckets
        )

        // Write to shared container
        let defaults = UserDefaults(suiteName: appGroupID)
        if let encoded = try? JSONEncoder().encode(data) {
            defaults?.set(encoded, forKey: dataKey)
        }

        // Reload all widget timelines
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Read from shared container (called from widget extension).
    static func load() -> WidgetSpendingData? {
        let defaults = UserDefaults(suiteName: appGroupID)
        guard let raw = defaults?.data(forKey: dataKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSpendingData.self, from: raw)
    }
}
