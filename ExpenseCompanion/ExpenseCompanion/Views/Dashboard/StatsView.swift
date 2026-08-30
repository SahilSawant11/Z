//
//  StatsView.swift
//  ExpenseCompanion
//
//  Category breakdown for the current month using Swift Charts.
//  Phase 3 will extend this with week-over-week trend lines, spending
//  velocity, and the calendar heatmap view described in the spec.
//

import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var monthExpenses: [Expense] = []

    private var categoryTotals: [(category: ExpenseCategory, total: Double)] {
        let grouped = Dictionary(grouping: monthExpenses, by: { $0.category })
        return grouped.map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DynamicGradientBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        if categoryTotals.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "chart.pie")
                                    .font(.system(size: 44, weight: .light))
                                    .foregroundStyle(.secondary)
                                Text("No expenses this month yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 60)
                        } else {
                            chartCard
                            breakdownList
                        }
                        LocationInsightsView()
                    }
                    .padding(16)
                    .padding(.bottom, 90)
                }
            }
            .navigationTitle("Stats")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: loadMonthExpenses)
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassSectionHeader(title: "This Month by Category", systemImage: "chart.pie.fill")
            Chart(categoryTotals, id: \.category) { item in
                SectorMark(
                    angle: .value("Amount", item.total),
                    innerRadius: .ratio(0.62),
                    angularInset: 2
                )
                .foregroundStyle(item.category.color)
                .cornerRadius(4)
            }
            .frame(height: 220)
        }
        .glassCard()
    }

    private var breakdownList: some View {
        VStack(spacing: 0) {
            ForEach(Array(categoryTotals.enumerated()), id: \.element.category) { index, item in
                HStack(spacing: 12) {
                    CategoryBadge(category: item.category, size: 34)

                    Text(item.category.rawValue)
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text(CurrencyFormatter.format(item.total))
                        .monospacedDigit()
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, 10)

                if index < categoryTotals.count - 1 {
                    Divider().opacity(0.25)
                }
            }
        }
        .glassCard()
    }

    private func loadMonthExpenses() {
        let calendar = Calendar.current
        let now = Date.now
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return }

        let repo = ExpenseRepository(context: modelContext)
        monthExpenses = (try? repo.expenses(from: monthStart, to: now)) ?? []
    }
}
