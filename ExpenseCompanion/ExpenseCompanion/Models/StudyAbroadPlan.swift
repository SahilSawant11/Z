//
//  StudyAbroadPlan.swift
//  ExpenseCompanion
//
//  Germany MS plan: pre-departure costs as dated milestones, a savings
//  projection against those due dates, and a loan / EMI calculator for
//  the post-admission costs (blocked account, deposit, cushion, setup).
//
//  All properties have defaults so the models stay CloudKit-compatible.
//

import Foundation
import SwiftData

@Model
final class StudyAbroadPlan {
    var id: UUID = UUID()
    var title: String = "MS CS · Germany"
    var intakeDate: Date = Date.now

    // Savings
    /// Cash already set aside for the plan (₹). Marking a milestone paid deducts from this.
    var currentSavings: Double = 0
    /// Expected amount saved per month going forward (₹). Derived from the salary
    /// plan (expected salary − buckets) once salary buckets exist.
    var monthlySavings: Double = 20_000
    /// Expected monthly salary (₹), fixed part. Actual paydays are logged separately.
    var expectedSalary: Double = 35_534

    // Post-admission costs (EUR), funded by the loan
    var eurToInr: Double = 90
    var blockedAccountEUR: Double = 11_904
    var rentDepositEUR: Double = 1_500
    var firstMonthCushionEUR: Double = 1_000
    var setupBufferEUR: Double = 1_200

    // Loan terms
    var loanCap: Double = 1_500_000
    var loanInterestRate: Double = 11 // % per year
    /// Months of simple interest accrual before EMIs start (course + grace period).
    var moratoriumMonths: Int = 30
    var loanTenureMonths: Int = 84
    /// Monthly in-hand income during repayment (₹), e.g. an 8–10 LPA job in India.
    var repaymentIncome: Double = 60_000

    init() {}
}

@Model
final class PlanMilestone {
    var id: UUID = UUID()
    var title: String = ""
    var amount: Double = 0 // ₹
    var dueDate: Date = Date.now
    var isPaid: Bool = false
    var paidDate: Date?
    var note: String = ""
    var symbolName: String = "circle"
    /// Stable identifier for milestones the app updates itself (e.g. "uniassist").
    var key: String = ""
    var createdAt: Date = Date.now

    static let uniAssistKey = "uniassist"

    init(title: String, amount: Double, dueDate: Date, symbolName: String = "circle", note: String = "", key: String = "") {
        self.key = key
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.dueDate = dueDate
        self.symbolName = symbolName
        self.note = note
        self.createdAt = .now
    }
}

// MARK: - Defaults (from GERMANY_MS.md, WS 2027 intake)

extension StudyAbroadPlan {
    static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? .now
    }

    static func makeDefault() -> StudyAbroadPlan {
        let plan = StudyAbroadPlan()
        plan.intakeDate = date(2027, 10, 1)
        return plan
    }

    /// Pre-departure costs, with due dates set so applications go out in time for WS 2027.
    static func defaultMilestones() -> [PlanMilestone] {
        [
            PlanMilestone(title: "IELTS", amount: 19_000, dueDate: date(2026, 12, 15),
                          symbolName: "text.bubble.fill", note: "Score needed before applying"),
            PlanMilestone(title: "Documents", amount: 4_950, dueDate: date(2027, 1, 10),
                          symbolName: "doc.text.fill", note: "Translations, attestations, copies"),
            PlanMilestone(title: "APS certificate", amount: 18_000, dueDate: date(2027, 1, 15),
                          symbolName: "checkmark.seal.fill", note: "Processing can take weeks to months"),
            PlanMilestone(title: "A1 German course", amount: 25_200, dueDate: date(2027, 2, 1),
                          symbolName: "character.book.closed.fill", note: "Placeholder: get a real quote"),
            PlanMilestone(title: "uni-assist × 10", amount: 31_050, dueDate: date(2027, 3, 1),
                          symbolName: "paperplane.fill", note: "€75 first + €30 × 9 others", key: PlanMilestone.uniAssistKey),
            PlanMilestone(title: "Visa fee", amount: 6_750, dueDate: date(2027, 7, 1),
                          symbolName: "airplane.departure", note: "€75"),
        ]
    }
}

// MARK: - Projection

struct MilestoneProjection: Identifiable {
    let milestone: PlanMilestone
    /// Cash projected to be on hand on the due date, after paying earlier unpaid milestones.
    let projectedCash: Double
    var id: UUID { milestone.id }
    var shortfall: Double { max(milestone.amount - projectedCash, 0) }
    var isCovered: Bool { shortfall == 0 }
}

enum PlanProjector {
    static let daysPerMonth = 30.4375

    static func months(from start: Date, to end: Date) -> Double {
        max(end.timeIntervalSince(start) / 86_400 / daysPerMonth, 0)
    }

    /// Walks unpaid milestones in due-date order, accruing monthly savings and spending as it goes.
    static func project(plan: StudyAbroadPlan, milestones: [PlanMilestone], now: Date = .now) -> [MilestoneProjection] {
        var spent = 0.0
        return milestones
            .filter { !$0.isPaid }
            .sorted { $0.dueDate < $1.dueDate }
            .map { m in
                let accrued = plan.monthlySavings * months(from: now, to: m.dueDate)
                let cash = plan.currentSavings + accrued - spent
                spent += m.amount
                return MilestoneProjection(milestone: m, projectedCash: cash)
            }
    }

    /// Date on which savings cover every remaining unpaid milestone, or nil if monthly savings is zero.
    static func fullyFundedDate(plan: StudyAbroadPlan, milestones: [PlanMilestone], now: Date = .now) -> Date? {
        let remaining = milestones.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
        let gap = remaining - plan.currentSavings
        if gap <= 0 { return now }
        guard plan.monthlySavings > 0 else { return nil }
        let days = gap / plan.monthlySavings * daysPerMonth
        return Calendar.current.date(byAdding: .day, value: Int(days.rounded(.up)), to: now)
    }
}

// MARK: - Loan

extension StudyAbroadPlan {
    var loanNeedEUR: Double {
        blockedAccountEUR + rentDepositEUR + firstMonthCushionEUR + setupBufferEUR
    }

    var loanNeedINR: Double { loanNeedEUR * eurToInr }

    var loanPrincipal: Double { min(loanNeedINR, loanCap) }

    /// Simple interest accrued during the moratorium, added to principal when EMIs begin.
    var principalAtRepayment: Double {
        loanPrincipal * (1 + loanInterestRate / 100 * Double(moratoriumMonths) / 12)
    }

    var emi: Double {
        let p = principalAtRepayment
        let n = Double(max(loanTenureMonths, 1))
        let r = loanInterestRate / 100 / 12
        guard r > 0 else { return p / n }
        let f = pow(1 + r, n)
        return p * r * f / (f - 1)
    }

    var totalRepayment: Double { emi * Double(max(loanTenureMonths, 1)) }

    var emiShareOfIncome: Double {
        guard repaymentIncome > 0 else { return 0 }
        return emi / repaymentIncome
    }
}
