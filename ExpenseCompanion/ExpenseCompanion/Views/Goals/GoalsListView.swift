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
                Color.appBackground.ignoresSafeArea()
                RadialGradient(
                    colors: [Color.heroPurple.opacity(0.22), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 340
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("GOALS")
                                    .font(.system(size: 10, weight: .semibold))
                                    .kerning(1.5)
                                    .foregroundStyle(Color.textTertiary)
                                Text("Savings")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)
                            }
                            Spacer()
                        }
                        .padding(.top, 4)

                        if goals.isEmpty {
                            VStack(spacing: 14) {
                                Image(systemName: "target")
                                    .font(.system(size: 52, weight: .ultraLight))
                                    .foregroundStyle(Color.textTertiary)
                                Text("No goals yet")
                                    .font(.headline)
                                    .foregroundStyle(Color.textPrimary)
                                Text("Set a savings goal to track your progress.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.textSecondary)
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
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showingAddGoal = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(LinearGradient(colors: [.heroPink, .heroPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: Color.heroPink.opacity(0.45), radius: 14, x: 0, y: 6)
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
        HStack(spacing: 16) {
            ZStack {
                ProgressRing(progress: goal.progress, lineWidth: 7, tint: Color.heroPink)
                    .frame(width: 54, height: 54)
                Image(systemName: goal.category.symbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.heroPink)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(goal.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("\(CurrencyFormatter.format(goal.savedAmount)) of \(CurrencyFormatter.format(goal.targetAmount))")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                Text("Save \(CurrencyFormatter.format(goal.suggestedDailySaving))/day")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(goal.progress * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.heroPink)
                Text("done")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .glassCard()
    }
}
