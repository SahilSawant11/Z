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
                Color.appBackground.ignoresSafeArea()
                RadialGradient(
                    colors: [Color.heroPurple.opacity(0.22), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 320
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GOAL TITLE")
                                .font(.system(size: 10, weight: .semibold))
                                .kerning(1.2)
                                .foregroundStyle(Color.textTertiary)
                            TextField("e.g. Vacation to Goa", text: $title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("CATEGORY")
                                .font(.system(size: 10, weight: .semibold))
                                .kerning(1.2)
                                .foregroundStyle(Color.textTertiary)
                            LazyVGrid(columns: goalCategoryColumns, spacing: 12) {
                                ForEach(GoalCategory.allCases) { cat in
                                    goalCategoryCell(cat: cat)
                                }
                            }
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("TARGET AMOUNT")
                                .font(.system(size: 10, weight: .semibold))
                                .kerning(1.2)
                                .foregroundStyle(Color.textTertiary)
                            TextField("50000", text: $targetAmountText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Color.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()

                        HStack {
                            Text("DEADLINE")
                                .font(.system(size: 10, weight: .semibold))
                                .kerning(1.2)
                                .foregroundStyle(Color.textTertiary)
                            Spacer()
                            DatePicker("", selection: $deadline, displayedComponents: .date)
                                .labelsHidden()
                                .colorScheme(.dark)
                        }
                        .glassCard()

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button {
                            save()
                        } label: {
                            Text("Create Goal")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(isValid
                                              ? AnyShapeStyle(LinearGradient(colors: [.heroPink, .heroPurple], startPoint: .leading, endPoint: .trailing))
                                              : AnyShapeStyle(Color.white.opacity(0.08)))
                                        .shadow(color: isValid ? Color.heroPink.opacity(0.4) : .clear, radius: 12, x: 0, y: 4)
                                )
                                .foregroundStyle(.white)
                        }
                        .disabled(!isValid)
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
        .preferredColorScheme(.dark)
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
                        .fill(selected ? Color.heroPink.opacity(0.2) : Color.white.opacity(0.06))
                        .frame(width: 50, height: 50)
                        .shadow(color: selected ? Color.heroPink.opacity(0.4) : .clear, radius: 8, x: 0, y: 4)
                    Image(systemName: cat.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(selected ? Color.heroPink : Color.textTertiary)
                }
                Text(cat.rawValue)
                    .font(.system(size: 9, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.heroPink : Color.textTertiary)
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
