//
//  DashboardView.swift
//  ExpenseCompanion
//
//  Dark fintech dashboard. Hero gradient card shows total spending,
//  then budget/goal rings, then today's expense list.
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
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DynamicGradientBackground()

                ScrollView {
                    if let viewModel {
                        VStack(spacing: 16) {
                            heroCard(viewModel: viewModel)
                            heatmapCard(viewModel: viewModel)
                            metricsRow(viewModel: viewModel)
                            todayExpensesSection(viewModel: viewModel)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    } else {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 120)
                    }
                }
                .scrollContentBackground(.hidden)

                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        addExpenseButton
                    }
                }
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

    // MARK: - Hero Card

    private func heroCard(viewModel: DashboardViewModel) -> some View {
        HeroCard {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greetingText.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(1.2)
                            .foregroundStyle(.white.opacity(0.55))
                        Text("Total Spent")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()

                    // Period toggle pills
                    HStack(spacing: 4) {
                        ForEach(Period.allCases, id: \.self) { p in
                            PillBadge(title: p.rawValue, isSelected: selectedPeriod == p)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedPeriod = p
                                    }
                                    Haptics.light()
                                }
                        }
                    }
                }

                Spacer().frame(height: 20)

                // Giant amount
                let amount = periodAmount(viewModel: viewModel)
                let parts = formatAmountParts(amount, currencyCode: viewModel.budgetSettings?.currencyCode ?? "INR")
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(parts.symbol)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(parts.whole)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(parts.decimal)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer().frame(height: 6)

                HStack(spacing: 16) {
                    Label("\(viewModel.todayExpenses.count) transactions today", systemImage: "arrow.up.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                }
            }
        }
        .frame(height: 190)
    }

    // MARK: - Period helpers

    private var greetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    private func periodAmount(viewModel: DashboardViewModel) -> Double {
        switch selectedPeriod {
        case .today: return viewModel.todayTotal
        case .week: return viewModel.weekTotal
        case .month: return viewModel.monthTotal
        }
    }

    private struct AmountParts {
        let symbol: String
        let whole: String
        let decimal: String
    }

    private func formatAmountParts(_ amount: Double, currencyCode: String) -> AmountParts {
        let symbol = CurrencyFormatter.symbol(for: currencyCode)
        let whole = String(Int(amount))
        let frac = Int((amount - Double(Int(amount))) * 100)
        return AmountParts(symbol: symbol, whole: whole, decimal: String(format: ".%02d", frac))
    }

    // MARK: - Heatmap Card

    private func heatmapCard(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                GlassSectionHeader(title: "28-Day Activity", systemImage: "calendar.badge.clock")
                Spacer()
                Text(viewModel.recentExpenses.count == 0 ? "No data yet" : "\(viewModel.recentExpenses.count) transactions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
            SpendingHeatmapView(expenses: viewModel.recentExpenses, compact: true)
        }
        .glassCard()
    }

    // MARK: - Metrics Row

    private func metricsRow(viewModel: DashboardViewModel) -> some View {
        HStack(spacing: 12) {
            // Budget ring card
            budgetCard(viewModel: viewModel)
            // Goal card
            goalCard(viewModel: viewModel)
        }
    }

    private func budgetCard(viewModel: DashboardViewModel) -> some View {
        VStack(spacing: 10) {
            ZStack {
                ProgressRing(
                    progress: viewModel.budgetUsedFraction,
                    lineWidth: 8,
                    tint: viewModel.isApproachingBudgetLimit ? .orange : Color(red: 0.2, green: 0.9, blue: 0.7)
                )
                .frame(width: 76, height: 76)

                VStack(spacing: 1) {
                    Text("\(Int(viewModel.budgetUsedFraction * 100))%")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("used")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            VStack(spacing: 2) {
                Text("BUDGET")
                    .font(.system(size: 9, weight: .semibold))
                    .kerning(1.0)
                    .foregroundStyle(Color.textTertiary)
                Text(CurrencyFormatter.format(viewModel.budgetSettings?.dailyLimit ?? 0,
                                              currencyCode: viewModel.budgetSettings?.currencyCode ?? "INR"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private func goalCard(viewModel: DashboardViewModel) -> some View {
        Group {
            if let goal = viewModel.primaryGoal {
                VStack(spacing: 10) {
                    ZStack {
                        ProgressRing(progress: goal.progress, lineWidth: 8, tint: Color.heroPink)
                            .frame(width: 76, height: 76)
                        Image(systemName: goal.category.symbolName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.heroPink)
                    }
                    VStack(spacing: 2) {
                        Text("GOAL")
                            .font(.system(size: 9, weight: .semibold))
                            .kerning(1.0)
                            .foregroundStyle(Color.textTertiary)
                        Text(goal.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .glassCard()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 26, weight: .ultraLight))
                        .foregroundStyle(Color.textTertiary)
                    Text("No goal yet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                    Button("Set one") {
                        showingGoals = true
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.heroPink)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .glassCard()
            }
        }
    }

    // MARK: - Expense List

    private func todayExpensesSection(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassSectionHeader(title: "Today's Expenses", systemImage: "clock")

            if viewModel.todayExpenses.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.dashed")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.textTertiary)
                    Text("Nothing logged yet — tap + to add.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.vertical, 16)
            } else {
                List {
                    ForEach(viewModel.todayExpenses) { expense in
                        ExpenseRowView(expense: expense)
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color.white.opacity(0.07))
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
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

    // MARK: - FAB

    private var addExpenseButton: some View {
        Button {
            showingAddExpense = true
            Haptics.light()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.heroPink, .heroPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.heroPink.opacity(0.5), radius: 14, x: 0, y: 6)
                )
        }
        .padding(.trailing, 20)
        .padding(.bottom, 100)
    }
}
