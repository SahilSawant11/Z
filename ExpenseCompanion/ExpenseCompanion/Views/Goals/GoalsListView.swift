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
                    VStack(spacing: 12) {
                        if goals.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "target")
                                    .font(.system(size: 48, weight: .ultraLight))
                                    .foregroundStyle(.secondary)
                                Text("No goals yet")
                                    .font(.headline)
                                Text("Set a savings goal to see your daily target.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                        } else {
                            ForEach(goals) { goal in
                                GoalRowView(goal: goal)
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 90)
                }
            }
            .navigationTitle("Goals")
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showingAddGoal = true
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
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: goal.progress, lineWidth: 9, tint: .purple)
                    .frame(width: 56, height: 56)
                Image(systemName: goal.category.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.purple)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.subheadline.weight(.semibold))
                Text("\(CurrencyFormatter.format(goal.savedAmount)) of \(CurrencyFormatter.format(goal.targetAmount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Save \(CurrencyFormatter.format(goal.suggestedDailySaving))/day to hit it")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("\(Int(goal.progress * 100))%")
                .font(.system(.callout, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.purple)
        }
        .glassCard()
    }
}
