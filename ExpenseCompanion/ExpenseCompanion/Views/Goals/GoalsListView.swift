//
//  GoalsListView.swift
//  ExpenseCompanion
//

import SwiftUI
import SwiftData

struct GoalsListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var goals: [FinancialGoal] = []
    @State private var showingAddGoal = false

    var body: some View {
        NavigationStack {
            ZStack {
                DynamicGradientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ScreenHeader(caption: "Savings", light: "Your", bold: "goals") {
                            CircleIconButton(systemName: "plus", filled: true) { showingAddGoal = true }
                                .accessibilityLabel("Add goal")
                        }

                        NavigationLink {
                            GermanyPlanView()
                        } label: {
                            GermanyPlanEntryCard()
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("germany-plan-card")

                        if goals.isEmpty {
                            HStack(spacing: 12) {
                                CircleIconButton(systemName: "plus", size: 40) { showingAddGoal = true }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("No other goals yet")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.textPrimary)
                                    Text("Set one to track your progress.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard()
                        } else {
                            ForEach(goals) { goal in
                                GoalRowView(goal: goal)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: loadGoals)
            .sheet(isPresented: $showingAddGoal, onDismiss: loadGoals) {
                AddGoalView()
            }
        }
    }

    private func loadGoals() {
        let repo = GoalRepository(context: modelContext)
        goals = (try? repo.allGoals()) ?? []
    }
}

struct GoalRowView: View {
    let goal: FinancialGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Image(systemName: goal.category.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.cardSurfaceRaised))
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Text("\(goal.daysRemaining) days left · save \(CurrencyFormatter.format(goal.suggestedDailySaving.rounded()))/day")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                CornerRing(progress: goal.progress, tint: .heroPink, size: 42)
            }

            HStack(alignment: .lastTextBaseline) {
                BigAmount(amount: goal.savedAmount, size: 32)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("of \(CurrencyFormatter.format(goal.targetAmount))")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .glassCard()
    }
}

/// Pink hero card for the Germany MS plan, with its live funding status.
struct GermanyPlanEntryCard: View {
    @Query private var plans: [StudyAbroadPlan]
    @Query private var milestones: [PlanMilestone]

    var body: some View {
        let unpaid = milestones.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
        let paid = milestones.filter(\.isPaid).reduce(0) { $0 + $1.amount }
        let savings = plans.first?.currentSavings ?? 0
        let funded = paid + max(min(savings, unpaid), 0)
        let total = paid + unpaid
        let months = plans.first.map { Int(PlanProjector.months(from: .now, to: $0.intakeDate)) }

        HeroCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🇩🇪  MS in Germany")
                            .font(.system(size: 15, weight: .semibold))
                        Text(total > 0 ? "Pre-departure funded" : "Plan costs, universities and loan")
                            .font(.system(size: 12))
                            .opacity(0.6)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.onAccent.opacity(0.1)))
                }

                HStack(alignment: .bottom) {
                    if total > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            BigAmount(amount: funded, size: 44)
                            Text("of \(CurrencyFormatter.format(total))")
                                .font(.system(size: 12))
                                .opacity(0.6)
                        }
                    } else {
                        Text("Open the plan")
                            .font(.system(size: 28, weight: .light))
                    }
                    Spacer()
                    if let months {
                        VStack(alignment: .trailing, spacing: 6) {
                            DotMatrixText(text: "\(months)", dot: 4, gap: 2, color: .onAccent)
                            Text("months to go")
                                .font(.system(size: 11))
                                .opacity(0.6)
                        }
                    }
                }
            }
        }
    }
}
