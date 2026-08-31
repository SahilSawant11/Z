//
//  BudgetActivityAttributes.swift
//  ExpenseCompanion
//
//  ActivityAttributes for the budget Live Activity.
//  This file must be added to BOTH the main app target AND
//  the ExpenseCompanionWidgets widget extension target.
//

import ActivityKit
import Foundation

// MARK: - Attributes

public struct BudgetActivityAttributes: ActivityAttributes {
    public typealias ContentState = BudgetState

    // Static info (set once when activity starts)
    public var currencySymbol: String

    public init(currencySymbol: String) {
        self.currencySymbol = currencySymbol
    }
}

// MARK: - Dynamic State

extension BudgetActivityAttributes {
    public struct BudgetState: Codable, Hashable {
        public var spent: Double
        public var limit: Double
        public var transactionCount: Int
        public var currencyCode: String
        public var lastUpdated: Date

        public init(spent: Double, limit: Double, transactionCount: Int,
                    currencyCode: String, lastUpdated: Date = .now) {
            self.spent = spent
            self.limit = limit
            self.transactionCount = transactionCount
            self.currencyCode = currencyCode
            self.lastUpdated = lastUpdated
        }

        // MARK: Computed helpers

        public var usedFraction: Double {
            guard limit > 0 else { return 0 }
            return min(spent / limit, 1.0)
        }

        public var remaining: Double { max(limit - spent, 0) }

        public var isOverBudget: Bool { spent > limit && limit > 0 }

        /// Short form for compact trailing slot: "₹2.3k" or "₹450"
        public func compactText(symbol: String) -> String {
            let val = spent
            if val >= 1_000 {
                return "\(symbol)\(String(format: "%.1f", val / 1000))k"
            }
            return "\(symbol)\(Int(val))"
        }

        /// Relative time label: "just now", "2 min ago"
        public var relativeTime: String {
            let diff = Date.now.timeIntervalSince(lastUpdated)
            if diff < 60 { return "just now" }
            return "\(Int(diff / 60))m ago"
        }
    }
}
