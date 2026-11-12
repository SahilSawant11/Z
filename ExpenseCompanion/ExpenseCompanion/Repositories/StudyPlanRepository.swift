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

    // MARK: - Salary

    func buckets() throws -> [SalaryBucket] {
        try context.fetch(FetchDescriptor<SalaryBucket>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    func paydays() throws -> [PaydayEntry] {
        try context.fetch(FetchDescriptor<PaydayEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
    }

    /// Seeds the default buckets the first time, then keeps derived values in sync.
    func ensureSalaryPlan(_ plan: StudyAbroadPlan) throws {
        if try context.fetchCount(FetchDescriptor<SalaryBucket>()) == 0 {
            SalaryBucket.defaults().forEach { context.insert($0) }
        }
        try syncFromSalary(plan)
    }

    /// Monthly savings = expected salary − buckets; the daily-spending bucket sets the daily budget.
    func syncFromSalary(_ plan: StudyAbroadPlan) throws {
        let all = try buckets()
        guard !all.isEmpty else { return }
        plan.monthlySavings = SalaryMath.monthlySavings(salary: plan.expectedSalary, buckets: all)
        if let daily = all.first(where: { $0.isDailySpending }), daily.perDayAmount > 0 {
            let settings = try context.fetch(FetchDescriptor<DailyBudgetSettings>()).first ?? {
                let s = DailyBudgetSettings()
                context.insert(s)
                return s
            }()
            settings.dailyLimit = daily.perDayAmount
        }
        try context.save()
    }

    func addBucket(_ bucket: SalaryBucket, plan: StudyAbroadPlan) throws {
        bucket.sortOrder = (try buckets().map(\.sortOrder).max() ?? -1) + 1
        context.insert(bucket)
        try syncFromSalary(plan)
    }

    func deleteBucket(_ bucket: SalaryBucket, plan: StudyAbroadPlan) throws {
        context.delete(bucket)
        try context.save()
        try syncFromSalary(plan)
    }

    /// Records a salary. What's left after the buckets goes into Germany savings.
    @discardableResult
    func logPayday(amount: Double, date: Date, note: String, plan: StudyAbroadPlan) throws -> PaydayEntry {
        let entry = PaydayEntry(date: date, amount: amount,
                                bucketsTotal: SalaryMath.bucketsTotal(try buckets()), note: note)
        context.insert(entry)
        plan.currentSavings += entry.savedAmount
        try context.save()
        return entry
    }

    /// Removes a payday and takes its savings back out.
    func deletePayday(_ entry: PaydayEntry, plan: StudyAbroadPlan) throws {
        plan.currentSavings -= entry.savedAmount
        context.delete(entry)
        try context.save()
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

    /// Points the plan's application-fee cost at the tracked programs: amount from the
    /// computed fees, due date from the earliest deadline. Creates the cost if it is missing.
    @discardableResult
    func syncApplicationFees(_ apps: [UniversityApplication], plan: StudyAbroadPlan) throws -> PlanMilestone? {
        guard !apps.isEmpty else { return nil }
        let amount = (ApplicationFees.totalEUR(apps) * plan.eurToInr).rounded()
        let earliest = apps.map(\.deadline).min() ?? .now
        let all = try milestones()
        let milestone = all.first { $0.key == PlanMilestone.uniAssistKey }
            ?? all.first { $0.title.lowercased().hasPrefix("uni-assist") }

        let target: PlanMilestone
        if let milestone {
            if milestone.isPaid { plan.currentSavings -= amount - milestone.amount }
            target = milestone
        } else {
            target = PlanMilestone(title: "", amount: 0, dueDate: earliest,
                                   symbolName: "paperplane.fill", key: PlanMilestone.uniAssistKey)
            context.insert(target)
        }
        target.key = PlanMilestone.uniAssistKey
        target.title = "Applications × \(apps.count)"
        target.amount = amount
        target.dueDate = earliest
        target.note = "Synced from university tracker"
        try context.save()
        return target
    }

    func save() throws {
        try context.save()
    }
}
