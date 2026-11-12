//
//  DashboardView.swift
//  ExpenseCompanion
//
//  Home. One loud pink card answers "how much have I spent?"; everything
//  else is flat charcoal and one tap away from detail.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?
    @State private var showingAddExpense = false
    @State private var showingGoals = false
    @State private var selectedPeriod: Period = .today

    enum Period: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case month = "Month"

        var heroLabel: String {
            switch self {
            case .today: return "Spent today"
            case .week: return "Spent this week"
            case .month: return "Spent this month"
            }
        }

        /// Days of history drawn in the hero sparkline.
        var sparklineDays: Int {
            switch self {
            case .today: return 14
            case .week: return 7
            case .month: return 28
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                DynamicGradientBackground()

                ScrollView {
                    if let viewModel {
                        VStack(alignment: .leading, spacing: 14) {
                            header
                            periodPicker
                            heroCard(viewModel: viewModel)
                            budgetCard(viewModel: viewModel)
                            HStack(alignment: .top, spacing: 14) {
                                averageCard(viewModel: viewModel)
                                goalCard(viewModel: viewModel)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            heatmapCard(viewModel: viewModel)
                            todayExpensesSection(viewModel: viewModel)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 110)
                    } else {
                        ProgressView()
                            .padding(.top, 120)
                            .frame(maxWidth: .infinity)
                    }
                }
                .scrollContentBackground(.hidden)

                addExpenseButton
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if viewModel == nil {
                    let expenseRepo = ExpenseRepository(context: modelContext)
                    let goalRepo = GoalRepository(context: modelContext)
                    viewModel = DashboardViewModel(expenseRepository: expenseRepo, goalRepository: goalRepo)
                }
                viewModel?.refresh()
            }
            .sheet(isPresented: $showingAddExpense, onDismiss: { viewModel?.refresh() }) {
                AddExpenseView()
            }
            .sheet(isPresented: $showingGoals, onDismiss: { viewModel?.refresh() }) {
                GoalsListView()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                SplitTitle(light: greeting.first, bold: greeting.second)
            }
            Spacer()
            CircleIconButton(systemName: "target") { showingGoals = true }
        }
        .padding(.top, 8)
    }

    private var greeting: (first: String, second: String) {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return ("Good", "morning")
        case 12..<17: return ("Good", "afternoon")
        case 17..<21: return ("Good", "evening")
        default: return ("Good", "night")
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(Period.allCases, id: \.self) { p in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selectedPeriod = p }
                    Haptics.light()
                } label: {
                    PillBadge(title: p.rawValue, isSelected: selectedPeriod == p)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Hero

    private func heroCard(viewModel: DashboardViewModel) -> some View {
        let code = viewModel.budgetSettings?.currencyCode ?? "INR"
        let hasBudget = (viewModel.budgetSettings?.dailyLimit ?? 0) > 0

        return HeroCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedPeriod.heroLabel)
                            .font(.system(size: 15, weight: .medium))
                        Text("\(transactionCount(viewModel)) transactions")
                            .font(.system(size: 12))
                            .opacity(0.6)
                    }
                    Spacer()
                    if selectedPeriod == .today, hasBudget {
                        CornerRing(progress: viewModel.budgetUsedFraction, tint: .onAccent)
                    }
                }

                AreaSparkline(values: dailySeries(viewModel), lineWidth: 2, fillOpacity: 0.14)
                    .frame(height: 64)

                HStack(alignment: .lastTextBaseline) {
                    BigAmount(amount: periodAmount(viewModel), currencyCode: code, size: 56)
                    Spacer()
                    Text("last \(selectedPeriod.sparklineDays)d")
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.55)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedPeriod)
    }

    private func periodAmount(_ viewModel: DashboardViewModel) -> Double {
        switch selectedPeriod {
        case .today: return viewModel.todayTotal
        case .week: return viewModel.weekTotal
        case .month: return viewModel.monthTotal
        }
    }

    private func transactionCount(_ viewModel: DashboardViewModel) -> Int {
        let cal = Calendar.current
        let now = Date.now
        let start: Date
        switch selectedPeriod {
        case .today: return viewModel.todayExpenses.count
        case .week: start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        case .month: start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        }
        return viewModel.recentExpenses.filter { $0.date >= start }.count
    }

    /// Daily totals, oldest first, for the selected period's sparkline window.
    private func dailySeries(_ viewModel: DashboardViewModel) -> [Double] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var totals: [Date: Double] = [:]
        for e in viewModel.recentExpenses {
            totals[cal.startOfDay(for: e.date), default: 0] += e.amount
        }
        return (0..<selectedPeriod.sparklineDays).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            return totals[day] ?? 0
        }
    }

    // MARK: - Budget

    private func budgetCard(viewModel: DashboardViewModel) -> some View {
        let code = viewModel.budgetSettings?.currencyCode ?? "INR"
        let limit = viewModel.budgetSettings?.dailyLimit ?? 0
        let over = viewModel.todayTotal > limit && limit > 0
        let marker: Color = over ? .red : viewModel.isApproachingBudgetLimit ? .orange : .heroPink

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily budget")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        BigAmount(amount: over ? viewModel.todayTotal - limit : viewModel.remainingBudgetToday,
                                  currencyCode: code, size: 34)
                            .foregroundStyle(over ? Color.red : Color.textPrimary)
                        Text(over ? "over" : "left")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                Spacer()
                Text("\(Int((viewModel.budgetUsedFraction * 100).rounded()))%")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(marker)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(marker.opacity(0.14)))
            }

            TickGauge(progress: viewModel.budgetUsedFraction, marker: marker)

            HStack {
                Text("\(CurrencyFormatter.format(viewModel.todayTotal, currencyCode: code)) spent")
                Spacer()
                Text("of \(CurrencyFormatter.format(limit, currencyCode: code))")
            }
            .font(.system(size: 12))
            .monospacedDigit()
            .foregroundStyle(Color.textTertiary)
        }
        .glassCard()
    }

    // MARK: - Average

    private func averageCard(viewModel: DashboardViewModel) -> some View {
        let code = viewModel.budgetSettings?.currencyCode ?? "INR"
        let text = BigAmount.grouped(viewModel.dailyAverageThisMonth.rounded(), currencyCode: code)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Daily average")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Spacer(minLength: 0)
            ViewThatFits(in: .horizontal) {
                DotMatrixText(text: text, dot: 4, gap: 2)
                DotMatrixText(text: text, dot: 3, gap: 1.5)
                DotMatrixText(text: text, dot: 2, gap: 1)
            }
            Text("\(CurrencyFormatter.symbol(for: code)) / day this month")
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Goal

    private func goalCard(viewModel: DashboardViewModel) -> some View {
        Group {
            if let goal = viewModel.primaryGoal {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Text("Goal")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        CornerRing(progress: goal.progress, tint: .heroPink, size: 40)
                    }
                    Spacer(minLength: 0)
                    Text(goal.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    BigAmount(amount: goal.savedAmount, size: 24, weight: .light)
                        .foregroundStyle(Color.textPrimary)
                    Text("of \(CurrencyFormatter.format(goal.targetAmount))")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Goal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                    Spacer(minLength: 0)
                    Text("No goal yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Button {
                        showingGoals = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("Set one")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.heroPink)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Heatmap

    private func heatmapCard(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activity")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text(viewModel.recentExpenses.isEmpty ? "No data yet" : "\(viewModel.recentExpenses.count) in 28 days")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            SpendingHeatmapView(expenses: viewModel.recentExpenses, compact: true)
        }
        .glassCard()
    }

    // MARK: - Today's expenses

    private func todayExpensesSection(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                if !viewModel.todayExpenses.isEmpty {
                    Text("\(viewModel.todayExpenses.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.textSecondary)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(Circle().fill(Color.cardSurfaceRaised))
                }
            }

            if viewModel.todayExpenses.isEmpty {
                HStack(spacing: 12) {
                    CircleIconButton(systemName: "plus", size: 40) { showingAddExpense = true }
                    Text("Nothing logged yet today.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.vertical, 6)
            } else {
                List {
                    ForEach(viewModel.todayExpenses) { expense in
                        ExpenseRowView(expense: expense)
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color.cardBorder)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation { viewModel.deleteExpense(expense) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(viewModel.todayExpenses.count) * 64)
            }
        }
        .glassCard()
    }

    // MARK: - Add button

    private var addExpenseButton: some View {
        Button {
            showingAddExpense = true
            Haptics.light()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.onAccent)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.heroPink))
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .accessibilityLabel("Add expense")
        .padding(.trailing, 20)
        .padding(.bottom, 100)
    }
}
