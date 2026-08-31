//
//  StatsView.swift
//  ExpenseCompanion
//

import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var monthExpenses: [Expense] = []
    @State private var allRecentExpenses: [Expense] = []

    private var categoryTotals: [(category: ExpenseCategory, total: Double)] {
        let grouped = Dictionary(grouping: monthExpenses, by: { $0.category })
        return grouped.map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                RadialGradient(
                    colors: [Color.heroDeep.opacity(0.25), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 360
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        // Page header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("STATS")
                                    .font(.system(size: 10, weight: .semibold))
                                    .kerning(1.5)
                                    .foregroundStyle(Color.textTertiary)
                                Text("This Month")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)
                            }
                            Spacer()
                        }
                        .padding(.top, 4)

                        // ── FULL SPENDING HEATMAP ──────────────────────────────
                        VStack(alignment: .leading, spacing: 0) {
                            SpendingHeatmapView(expenses: allRecentExpenses, compact: false)
                        }
                        .glassCard()

                        if categoryTotals.isEmpty {
                            VStack(spacing: 14) {
                                Image(systemName: "chart.pie")
                                    .font(.system(size: 48, weight: .ultraLight))
                                    .foregroundStyle(Color.textTertiary)
                                Text("No expenses this month yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            .padding(.top, 30)
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
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: loadExpenses)
        }
        
    }


    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassSectionHeader(title: "Breakdown by Category", systemImage: "chart.pie.fill")
            Chart(categoryTotals, id: \.category) { item in
                SectorMark(
                    angle: .value("Amount", item.total),
                    innerRadius: .ratio(0.65),
                    angularInset: 2.5
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
                HStack(spacing: 14) {
                    CategoryBadge(category: item.category, size: 38)
                    Text(item.category.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(CurrencyFormatter.format(item.total))
                        .monospacedDigit()
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.vertical, 10)

                if index < categoryTotals.count - 1 {
                    Divider().background(Color.white.opacity(0.07))
                }
            }
        }
        .glassCard()
    }

    // MARK: - Data

    private func loadExpenses() {
        let calendar = Calendar.current
        let now = Date.now

        // Month expenses for chart
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return }
        let repo = ExpenseRepository(context: modelContext)
        monthExpenses = (try? repo.expenses(from: monthStart, to: now)) ?? []

        // 28-day window for heatmap
        let heatmapStart = calendar.date(byAdding: .day, value: -27, to: calendar.startOfDay(for: now)) ?? now
        allRecentExpenses = (try? repo.expenses(from: heatmapStart, to: now)) ?? []
    }
}
