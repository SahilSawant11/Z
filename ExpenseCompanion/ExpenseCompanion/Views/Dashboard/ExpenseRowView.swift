//
//  ExpenseRowView.swift
//  ExpenseCompanion
//

import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense
    @State private var showingDetail = false

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: expense.category, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.category.rawValue)
                    .font(.subheadline.weight(.semibold))

                if let placeName = expense.placeName {
                    Label(placeName, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if !expense.note.isEmpty {
                    Text(expense.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.format(expense.amount))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(expense.date.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showingDetail = true }
        .sheet(isPresented: $showingDetail) {
            ExpenseDetailView(expense: expense)
        }
    }
}
