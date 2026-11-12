//
//  StatsView.swift
//  ExpenseCompanion
//
//  Month at a glance: total vs. last month (pink hero), category split as a
//  segmented bar with per-category share rows, then the heatmap and places.
//

import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var monthExpenses: [Expense] = []
    @State private var allRecentExpenses: [Expense] = []
    /// Spending last month up to the same day-of-month, for a like-for-like comparison.
    @State private var lastMonthToDate: Double = 0

    private var categoryTotals: [(category: ExpenseCategory, total: Double)] {
        let grouped = Dictionary(grouping: monthExpenses, by: { $0.category })
        return grouped.map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    private var monthTotal: Double { monthExpenses.reduce(0) { $0 + $1.amount } }

    var body: some View {
        NavigationStack {
            ZStack {
                DynamicGradientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ScreenHeader(caption: Date.now.formatted(.dateTime.month(.wide).year()),
                                     light: "This", bold: "month")

                        heroCard

                        if categoryTotals.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "chart.bar")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.textSecondary)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(Color.cardSurfaceRaised))
                                Text("No expenses this month yet.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard()
                        } else {
                            breakdownCard
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Activity")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                            SpendingHeatmapView(expenses: allRecentExpenses, compact: false)
                        }
                        .glassCard()

                        LocationInsightsView()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: loadExpenses)
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        let delta = lastMonthToDate > 0 ? (monthTotal - lastMonthToDate) / lastMonthToDate : nil
        let lastMonthName = (Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now)
            .formatted(.dateTime.month(.abbreviated))
        let days = max(Calendar.current.component(.day, from: .now), 1)

        return HeroCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spent so far")
                            .font(.system(size: 15, weight: .medium))
                        Text("\(monthExpenses.count) transactions · \(days) days")
                            .font(.system(size: 12))
                            .opacity(0.6)
                    }
                    Spacer()
                    if let delta {
                        HStack(spacing: 4) {
                            Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                            Text("\(Int((abs(delta) * 100).rounded()))%")
                                .monospacedDigit()
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(Color.onAccent.opacity(0.1)))
                    }
                }

                BigAmount(amount: monthTotal, size: 56)

                Text(comparisonText(delta: delta, lastMonthName: lastMonthName))
                    .font(.system(size: 13))
                    .opacity(0.7)
            }
        }
    }

    private func comparisonText(delta: Double?, lastMonthName: String) -> String {
        guard let delta else { return "Nothing logged last month to compare with." }
        let amount = CurrencyFormatter.format(lastMonthToDate.rounded())
        if abs(delta) < 0.02 { return "Level with \(lastMonthName) at this point (\(amount))." }
        return delta > 0
            ? "More than \(lastMonthName) at this point (\(amount))."
            : "Less than \(lastMonthName) at this point (\(amount))."
    }

    // MARK: - Breakdown

    private var breakdownCard: some View {
        let total = max(monthTotal, 1)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("By category")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text("\(categoryTotals.count) categories")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }

            // Segmented share bar
            GeometryReader { geo in
                let spacing: CGFloat = 3
                let usable = geo.size.width - spacing * CGFloat(max(categoryTotals.count - 1, 0))
                HStack(spacing: spacing) {
                    ForEach(categoryTotals, id: \.category) { item in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(item.category.color)
                            .frame(width: max(usable * item.total / total, 4))
                    }
                }
            }
            .frame(height: 28)

            VStack(spacing: 0) {
                ForEach(Array(categoryTotals.enumerated()), id: \.element.category) { index, item in
                    let share = item.total / total
                    HStack(spacing: 14) {
                        CategoryBadge(category: item.category, size: 40)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.category.rawValue)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Text(CurrencyFormatter.format(item.total))
                                    .font(.system(size: 15, weight: .regular))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.textPrimary)
                            }
                            HStack(spacing: 8) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.cardSurfaceRaised)
                                        Capsule().fill(item.category.color)
                                            .frame(width: geo.size.width * share)
                                    }
                                }
                                .frame(height: 4)
                                Text("\(Int((share * 100).rounded()))%")
                                    .font(.system(size: 11, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.textTertiary)
                                    .frame(width: 34, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.vertical, 10)

                    if index < categoryTotals.count - 1 {
                        Divider().overlay(Color.cardBorder)
                    }
                }
            }
        }
        .glassCard()
    }

    // MARK: - Data

    private func loadExpenses() {
        let calendar = Calendar.current
        let now = Date.now
        let repo = ExpenseRepository(context: modelContext)

        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return }
        monthExpenses = (try? repo.expenses(from: monthStart, to: now)) ?? []

        if let lastStart = calendar.date(byAdding: .month, value: -1, to: monthStart),
           let lastSameDay = calendar.date(byAdding: .month, value: -1, to: now) {
            lastMonthToDate = ((try? repo.expenses(from: lastStart, to: lastSameDay)) ?? [])
                .reduce(0) { $0 + $1.amount }
        }

        let heatmapStart = calendar.date(byAdding: .day, value: -27, to: calendar.startOfDay(for: now)) ?? now
        allRecentExpenses = (try? repo.expenses(from: heatmapStart, to: now)) ?? []
    }
}
