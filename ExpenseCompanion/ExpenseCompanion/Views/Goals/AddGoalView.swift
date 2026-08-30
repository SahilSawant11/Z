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
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Goal Title")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                                .kerning(0.5)
                            TextField("e.g. Vacation to Goa", text: $title)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                                .kerning(0.5)
                            LazyVGrid(columns: goalCategoryColumns, spacing: 10) {
                                ForEach(GoalCategory.allCases) { cat in
                                    goalCategoryCell(cat: cat)
                                }
                            }
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Target Amount")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                                .kerning(0.5)
                            TextField("50000", text: $targetAmountText)
                                .keyboardType(.decimalPad)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()

                        HStack {
                            Text("Deadline")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                                .kerning(0.5)
                            Spacer()
                            DatePicker("", selection: $deadline, displayedComponents: .date)
                                .labelsHidden()
                        }
                        .glassCard()

                        if let errorMessage {
                            Text(errorMessage).font(.caption).foregroundStyle(.red)
                        }

                        Button {
                            save()
                        } label: {
                            Text("Create Goal")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(isValid
                                              ? AnyShapeStyle(Color.accentColor.gradient)
                                              : AnyShapeStyle(Color.gray.opacity(0.3)))
                                )
                                .foregroundStyle(.white)
                        }
                        .disabled(!isValid)
                        .animation(.easeInOut(duration: 0.2), value: isValid)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
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
                Image(systemName: cat.symbolName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selected ? .white : Color.purple)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selected ? AnyShapeStyle(Color.purple.gradient) : AnyShapeStyle(Color.purple.opacity(0.12)))
                    )
                    .shadow(color: selected ? Color.purple.opacity(0.35) : .clear, radius: 6, x: 0, y: 3)
                Text(cat.rawValue)
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
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
