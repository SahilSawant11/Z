//
//  ExpenseRowView.swift
//  ExpenseCompanion
//

import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense
    @State private var showingDetail = false

    var body: some View {
        HStack(spacing: 14) {
            CategoryBadge(category: expense.category, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.category.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                if let placeName = expense.placeName {
                    Label(placeName, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                } else if !expense.note.isEmpty {
                    Text(expense.note)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(CurrencyFormatter.format(expense.amount))
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.textPrimary)
                Text(expense.date.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showingDetail = true }
        .sheet(isPresented: $showingDetail) {
            ExpenseDetailView(expense: expense)
        }
    }
}
