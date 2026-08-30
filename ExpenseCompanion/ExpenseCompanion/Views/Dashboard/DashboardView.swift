//
//  DashboardView.swift
//  ExpenseCompanion
//
//  The screen the user opens every day. Shows today/week totals, the
//  daily budget ring, the primary goal's progress, and today's expense list.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?
    @State private var showingAddExpense = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let viewModel {
                    VStack(spacing: 14) {
                        headerCard(viewModel: viewModel)
                        budgetAndGoalRow(viewModel: viewModel)
                        todayExpensesSection(viewModel: viewModel)
                    }
                    .padding(16)
                    .padding(.bottom, 90) // clears the floating tab bar
                } else {
                    ProgressView()
                        .padding(.top, 100)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                addExpenseButton
            }
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
        }
    }

    // MARK: - Header

    private func headerCard(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greetingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Expense Companion")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                }
                Spacer()
                Image(systemName: "wallet.bifold.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            Divider().opacity(0.3)

            HStack(spacing: 0) {
                statPair(label: "Today", value: viewModel.todayTotal, currencyCode: viewModel.budgetSettings?.currencyCode ?? "INR")
                Divider().frame(height: 36).opacity(0.3)
                statPair(label: "This Week", value: viewModel.weekTotal, currencyCode: viewModel.budgetSettings?.currencyCode ?? "INR")
                Divider().frame(height: 36).opacity(0.3)
                statPair(label: "This Month", value: viewModel.monthTotal, currencyCode: viewModel.budgetSettings?.currencyCode ?? "INR")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    private func statPair(label: String, value: Double, currencyCode: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .kerning(0.5)
            Text(CurrencyFormatter.format(value, currencyCode: currencyCode))
                .font(.system(.callout, design: .rounded).weight(.bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Budget ring + Goal ring

    private func budgetAndGoalRow(viewModel: DashboardViewModel) -> some View {
        HStack(spacing: 14) {
            // Daily budget ring
            VStack(spacing: 10) {
                ZStack {
                    ProgressRing(
                        progress: viewModel.budgetUsedFraction,
                        lineWidth: 11,
                        tint: viewModel.isApproachingBudgetLimit ? .orange : .teal
                    )
                    .frame(width: 84, height: 84)

                    VStack(spacing: 1) {
                        Text("\(Int(viewModel.budgetUsedFraction * 100))%")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .monospacedDigit()
                        Text("used")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                VStack(spacing: 2) {
                    Text("Daily Budget")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .kerning(0.4)
                    Text(CurrencyFormatter.format(viewModel.budgetSettings?.dailyLimit ?? 0, currencyCode: viewModel.budgetSettings?.currencyCode ?? "INR"))
                        .font(.caption.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .glassCard()

            // Primary goal ring
            if let goal = viewModel.primaryGoal {
                VStack(spacing: 10) {
                    ZStack {
                        ProgressRing(progress: goal.progress, lineWidth: 11, tint: .purple)
                            .frame(width: 84, height: 84)
                        Image(systemName: goal.category.symbolName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.purple)
                    }
                    VStack(spacing: 2) {
                        Text("Goal")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .kerning(0.4)
                        Text(goal.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .glassCard()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No goal yet")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    NavigationLink("Set a goal") {
                        GoalsListView()
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 130)
                .glassCard()
            }
        }
    }

    // MARK: - Today's expenses

    private func todayExpensesSection(viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassSectionHeader(title: "Today's Expenses", systemImage: "clock")

            if viewModel.todayExpenses.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.dashed")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("Nothing logged yet — tap + to add your first expense.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            } else {
                // List with plain style gives us real swipe-to-delete support.
                // We size it to its content with a fixed frame driven by row count.
                List {
                    ForEach(viewModel.todayExpenses) { expense in
                        ExpenseRowView(expense: expense)
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(.primary.opacity(0.1))
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        viewModel.deleteExpense(expense)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(viewModel.todayExpenses.count) * 62)
            }
        }
        .glassCard()
    }

    private var addExpenseButton: some View {
        Button {
            showingAddExpense = true
            Haptics.light()
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(
                    Circle()
                        .fill(Color.accentColor.gradient)
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
                )
        }
        .padding(.trailing, 20)
        .padding(.bottom, 100)
    }
}
