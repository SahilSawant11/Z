//
//  AddGoalView.swift
//  ExpenseCompanion
//

import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var category: GoalCategory = .vacation
    @State private var targetAmountText = ""
    @State private var deadline = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    @State private var errorMessage: String?

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && (Double(targetAmountText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DynamicGradientBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Goal title")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                            TextField("e.g. Vacation to Goa", text: $title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                            LazyVGrid(columns: goalCategoryColumns, spacing: 12) {
                                ForEach(GoalCategory.allCases) { cat in
                                    goalCategoryCell(cat: cat)
                                }
                            }
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target amount")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                            TextField("50000", text: $targetAmountText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 40, weight: .light))
                                .monospacedDigit()
                                .foregroundStyle(Color.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()

                        HStack {
                            Text("Deadline")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                            Spacer()
                            DatePicker("", selection: $deadline, displayedComponents: .date)
                                .labelsHidden()
                        }
                        .glassCard()

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button("Create goal", action: save)
                            .buttonStyle(AccentButtonStyle())
                            .disabled(!isValid)
                            .padding(.top, 6)
                        .animation(.easeInOut(duration: 0.2), value: isValid)
                    }
                    .padding(16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.appBackground)
        
    }

    private var goalCategoryColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: 3)
    }

    private func goalCategoryCell(cat: GoalCategory) -> some View {
        let selected = category == cat
        return Button {
            category = cat
            Haptics.light()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(selected ? Color.heroPink : Color.cardSurfaceRaised)
                        .frame(width: 50, height: 50)
                    Image(systemName: cat.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(selected ? Color.onAccent : Color.textSecondary)
                }
                Text(cat.rawValue)
                    .font(.system(size: 9, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.textPrimary : Color.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard let amount = Double(targetAmountText), amount > 0 else {
            errorMessage = "Enter a valid target amount."
            return
        }
        let goal = FinancialGoal(title: title, category: category, targetAmount: amount, deadline: deadline)
        let repo = GoalRepository(context: modelContext)
        do {
            try repo.add(goal)
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = "Couldn't save the goal."
        }
    }
}
