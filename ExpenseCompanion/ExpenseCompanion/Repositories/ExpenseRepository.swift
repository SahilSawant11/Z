//
//  ExpenseRepository.swift
//  ExpenseCompanion
//
//  Thin data-access layer over SwiftData. ViewModels talk to this instead
//  of touching ModelContext directly, which keeps persistence concerns out
//  of the view layer and makes the ViewModels unit-testable with a mock repo.
//

import Foundation
import SwiftData

protocol ExpenseRepositoryProtocol {
    func add(_ expense: Expense) throws
    func delete(_ expense: Expense) throws
    func update(_ expense: Expense, amount: Double, category: ExpenseCategory, note: String) throws
    func expenses(from startDate: Date, to endDate: Date) throws -> [Expense]
    func allExpenses() throws -> [Expense]
    func expenses(on day: Date) throws -> [Expense]
}

@MainActor
final class ExpenseRepository: ExpenseRepositoryProtocol {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(_ expense: Expense) throws {
        context.insert(expense)
        try context.save()
    }

    func delete(_ expense: Expense) throws {
        context.delete(expense)
        try context.save()
    }

    func update(_ expense: Expense, amount: Double, category: ExpenseCategory, note: String) throws {
        expense.amount = amount
        expense.category = category
        expense.note = note
        try context.save()
    }

    func expenses(from startDate: Date, to endDate: Date) throws -> [Expense] {
        let predicate = #Predicate<Expense> { $0.date >= startDate && $0.date <= endDate }
        let descriptor = FetchDescriptor<Expense>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func allExpenses() throws -> [Expense] {
        let descriptor = FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func expenses(on day: Date) throws -> [Expense] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = #Predicate<Expense> { $0.date >= start && $0.date < end }
        let descriptor = FetchDescriptor<Expense>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
