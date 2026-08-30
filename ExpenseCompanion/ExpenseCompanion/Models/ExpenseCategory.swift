//
//  ExpenseCategory.swift
//  ExpenseCompanion
//

import SwiftUI

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case food = "Food"
    case transport = "Transport"
    case shopping = "Shopping"
    case bills = "Bills"
    case entertainment = "Entertainment"
    case health = "Health"
    case education = "Education"
    case other = "Other"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .food: return "🍔"
        case .transport: return "🚗"
        case .shopping: return "🛍️"
        case .bills: return "🧾"
        case .entertainment: return "🎬"
        case .health: return "💊"
        case .education: return "📚"
        case .other: return "✨"
        }
    }

    var symbolName: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .shopping: return "bag.fill"
        case .bills: return "doc.text.fill"
        case .entertainment: return "film.fill"
        case .health: return "cross.case.fill"
        case .education: return "book.fill"
        case .other: return "sparkles"
        }
    }

    /// A stable, distinguishable color per category — used for map pins,
    /// pie chart slices, and category chips.
    var color: Color {
        switch self {
        case .food: return .orange
        case .transport: return .blue
        case .shopping: return .pink
        case .bills: return .red
        case .entertainment: return .purple
        case .health: return .green
        case .education: return .indigo
        case .other: return .gray
        }
    }
}
