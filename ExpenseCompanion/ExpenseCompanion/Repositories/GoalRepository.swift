//
//  GoalRepository.swift
//  ExpenseCompanion
//

import Foundation
import SwiftData

@MainActor
final class GoalRepository {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(_ goal: FinancialGoal) throws {
        context.insert(goal)
        try context.save()
    }

    func delete(_ goal: FinancialGoal) throws {
        context.delete(goal)
        try context.save()
    }

    func contribute(_ amount: Double, to goal: FinancialGoal) throws {
        goal.savedAmount = min(goal.savedAmount + amount, goal.targetAmount)
        try context.save()
    }

    func allGoals() throws -> [FinancialGoal] {
        let descriptor = FetchDescriptor<FinancialGoal>(sortBy: [SortDescriptor(\.deadline)])
        return try context.fetch(descriptor)
    }

    /// Fetches the single budget settings record, creating a default one on first launch.
    func fetchOrCreateBudgetSettings() throws -> DailyBudgetSettings {
        let descriptor = FetchDescriptor<DailyBudgetSettings>()
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let settings = DailyBudgetSettings()
        context.insert(settings)
        try context.save()
        return settings
    }
}
