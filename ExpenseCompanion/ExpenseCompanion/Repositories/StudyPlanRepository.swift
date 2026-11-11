//
//  StudyPlanRepository.swift
//  ExpenseCompanion
//

import Foundation
import SwiftData

@MainActor
final class StudyPlanRepository {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Returns the single plan, seeding it and its default milestones on first use.
    func fetchOrCreatePlan() throws -> StudyAbroadPlan {
        if let existing = try context.fetch(FetchDescriptor<StudyAbroadPlan>()).first {
            return existing
        }
        let plan = StudyAbroadPlan.makeDefault()
        context.insert(plan)
        if try context.fetchCount(FetchDescriptor<PlanMilestone>()) == 0 {
            StudyAbroadPlan.defaultMilestones().forEach { context.insert($0) }
        }
        try context.save()
        return plan
    }

    func milestones() throws -> [PlanMilestone] {
        try context.fetch(FetchDescriptor<PlanMilestone>(sortBy: [SortDescriptor(\.dueDate)]))
    }

    func add(_ milestone: PlanMilestone) throws {
        context.insert(milestone)
        try context.save()
    }

    func delete(_ milestone: PlanMilestone, plan: StudyAbroadPlan) throws {
        if milestone.isPaid { plan.currentSavings += milestone.amount }
        context.delete(milestone)
        try context.save()
    }

    /// Paying moves money out of savings; un-paying puts it back.
    func setPaid(_ paid: Bool, _ milestone: PlanMilestone, plan: StudyAbroadPlan) throws {
        guard milestone.isPaid != paid else { return }
        milestone.isPaid = paid
        milestone.paidDate = paid ? .now : nil
        plan.currentSavings += paid ? -milestone.amount : milestone.amount
        try context.save()
    }

    func save() throws {
        try context.save()
    }
}
