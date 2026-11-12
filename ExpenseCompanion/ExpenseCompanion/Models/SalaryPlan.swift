//
//  SalaryPlan.swift
//  ExpenseCompanion
//
//  Where each salary goes. Monthly buckets (daily spending, rent, data,
//  fuel, …) are taken off the top; whatever is left is savings, which feeds
//  the Germany plan. Each payday is logged with the amount actually received.
//
//  All properties have defaults so the models stay CloudKit-compatible.
//

import Foundation
import SwiftData

@Model
final class SalaryBucket {
    var id: UUID = UUID()
    var name: String = ""
    var symbolName: String = "tag.fill"
    /// Monthly amount (₹) for fixed buckets.
    var monthlyAmount: Double = 0
    /// For per-day buckets (e.g. daily spending): amount per day. 0 means a fixed monthly bucket.
    var perDayAmount: Double = 0
    /// The per-day bucket that also drives the app's daily budget.
    var isDailySpending: Bool = false
    var sortOrder: Int = 0

    static let daysPerMonth = 30.0

    var isPerDay: Bool { perDayAmount > 0 }

    /// What this bucket takes from each salary.
    var monthlyTotal: Double { isPerDay ? perDayAmount * Self.daysPerMonth : monthlyAmount }

    init(name: String, symbolName: String, monthlyAmount: Double = 0, perDayAmount: Double = 0,
         isDailySpending: Bool = false, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.symbolName = symbolName
        self.monthlyAmount = monthlyAmount
        self.perDayAmount = perDayAmount
        self.isDailySpending = isDailySpending
        self.sortOrder = sortOrder
    }

    static func defaults() -> [SalaryBucket] {
        [
            SalaryBucket(name: "Daily spending", symbolName: "fork.knife", perDayAmount: 350, isDailySpending: true, sortOrder: 0),
            SalaryBucket(name: "Room rent", symbolName: "house.fill", monthlyAmount: 4_500, sortOrder: 1),
            SalaryBucket(name: "Wi-Fi & mobile data", symbolName: "wifi", monthlyAmount: 1_000, sortOrder: 2),
            SalaryBucket(name: "Fuel", symbolName: "fuelpump.fill", monthlyAmount: 1_000, sortOrder: 3),
        ]
    }
}

@Model
final class PaydayEntry {
    var id: UUID = UUID()
    var date: Date = Date.now
    /// Amount actually received (₹).
    var amount: Double = 0
    /// Sum of all buckets at the time it was logged (₹).
    var bucketsTotal: Double = 0
    var note: String = ""

    /// What this salary added to Germany savings. Negative if it didn't cover the buckets.
    var savedAmount: Double { amount - bucketsTotal }

    init(date: Date = .now, amount: Double, bucketsTotal: Double, note: String = "") {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.bucketsTotal = bucketsTotal
        self.note = note
    }
}

enum SalaryMath {
    static func bucketsTotal(_ buckets: [SalaryBucket]) -> Double {
        buckets.reduce(0) { $0 + $1.monthlyTotal }
    }

    static func monthlySavings(salary: Double, buckets: [SalaryBucket]) -> Double {
        salary - bucketsTotal(buckets)
    }
}
