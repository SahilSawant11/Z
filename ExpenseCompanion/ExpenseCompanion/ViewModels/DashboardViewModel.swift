//
//  DashboardViewModel.swift
//  ExpenseCompanion
//
//  Drives the main dashboard: today/week/month totals, budget progress,
//  the primary goal's progress, and today's expense list.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class DashboardViewModel {

    private let expenseRepository: ExpenseRepository
    private let goalRepository: GoalRepository

    // Published-equivalent state (via @Observable)
    var todayExpenses: [Expense] = []
    var todayTotal: Double = 0
    var weekTotal: Double = 0
    var monthTotal: Double = 0
    var dailyAverageThisMonth: Double = 0

    var budgetSettings: DailyBudgetSettings?
    var primaryGoal: FinancialGoal?

    var errorMessage: String?

    init(expenseRepository: ExpenseRepository, goalRepository: GoalRepository) {
        self.expenseRepository = expenseRepository
        self.goalRepository = goalRepository
    }

    /// Reloads every piece of dashboard state. Call on appear and after any mutation.
    func refresh() {
        let calendar = Calendar.current
        let now = Date.now

        do {
            todayExpenses = try expenseRepository.expenses(on: now)
            todayTotal = todayExpenses.reduce(0) { $0 + $1.amount }

            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            weekTotal = try expenseRepository.expenses(from: weekStart, to: now).reduce(0) { $0 + $1.amount }

            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let monthExpenses = try expenseRepository.expenses(from: monthStart, to: now)
            monthTotal = monthExpenses.reduce(0) { $0 + $1.amount }

            let daysElapsedThisMonth = max(calendar.dateComponents([.day], from: monthStart, to: now).day ?? 1, 1)
            dailyAverageThisMonth = monthTotal / Double(daysElapsedThisMonth)

            budgetSettings = try goalRepository.fetchOrCreateBudgetSettings()
            primaryGoal = try goalRepository.allGoals().first

            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load your data. Pull to refresh to try again."
        }
    }

    /// Fraction of today's budget used, clamped to [0, 1] for the progress ring.
    var budgetUsedFraction: Double {
        guard let limit = budgetSettings?.dailyLimit, limit > 0 else { return 0 }
        return min(todayTotal / limit, 1.0)
    }

    var isApproachingBudgetLimit: Bool {
        guard let limit = budgetSettings?.dailyLimit, limit > 0 else { return false }
        return todayTotal / limit >= 0.8
    }

    var remainingBudgetToday: Double {
        guard let limit = budgetSettings?.dailyLimit else { return 0 }
        return max(limit - todayTotal, 0)
    }

    func deleteExpense(_ expense: Expense) {
        do {
            try expenseRepository.delete(expense)
            refresh()
        } catch {
            errorMessage = "Couldn't delete that expense."
        }
    }
}
