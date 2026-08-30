//
//  FinancialGoal.swift
//  ExpenseCompanion
//

import Foundation
import SwiftData

enum GoalCategory: String, Codable, CaseIterable, Identifiable {
    case vacation = "Vacation"
    case emergencyFund = "Emergency Fund"
    case investment = "Investment"
    case education = "Education"
    case bigPurchase = "Big Purchase"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .vacation: return "🏖️"
        case .emergencyFund: return "🛟"
        case .investment: return "📈"
        case .education: return "🎓"
        case .bigPurchase: return "🏆"
        }
    }

    var symbolName: String {
        switch self {
        case .vacation: return "beach.umbrella.fill"
        case .emergencyFund: return "lifepreserver.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .education: return "graduationcap.fill"
        case .bigPurchase: return "trophy.fill"
        }
    }
}

@Model
final class FinancialGoal {
    var id: UUID
    var title: String
    var categoryRaw: String
    var targetAmount: Double
    var savedAmount: Double
    var deadline: Date
    var createdAt: Date

    var category: GoalCategory {
        get { GoalCategory(rawValue: categoryRaw) ?? .bigPurchase }
        set { categoryRaw = newValue.rawValue }
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(savedAmount / targetAmount, 1.0)
    }

    var remainingAmount: Double {
        max(targetAmount - savedAmount, 0)
    }

    /// Days left until the deadline, floored at 0.
    var daysRemaining: Int {
        max(Calendar.current.dateComponents([.day], from: .now, to: deadline).day ?? 0, 0)
    }

    /// Naive daily-savings suggestion: remaining amount spread evenly over remaining days.
    /// This is the "Smart Suggestion" surfaced in the goal detail view. A more advanced
    /// version (Phase 4) can factor in the user's historical savings rate.
    var suggestedDailySaving: Double {
        guard daysRemaining > 0 else { return remainingAmount }
        return remainingAmount / Double(daysRemaining)
    }

    init(
        title: String,
        category: GoalCategory,
        targetAmount: Double,
        savedAmount: Double = 0,
        deadline: Date
    ) {
        self.id = UUID()
        self.title = title
        self.categoryRaw = category.rawValue
        self.targetAmount = targetAmount
        self.savedAmount = savedAmount
        self.deadline = deadline
        self.createdAt = .now
    }
}
