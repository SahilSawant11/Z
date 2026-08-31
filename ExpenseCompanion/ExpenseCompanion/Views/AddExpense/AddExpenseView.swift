//
//  AddExpenseView.swift
//  ExpenseCompanion
//

import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFieldFocused: Bool

    @State private var viewModel: AddExpenseViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                // Subtle top glow
                RadialGradient(
                    colors: [Color.heroPurple.opacity(0.25), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()

                if let viewModel {
                    ScrollView {
                        VStack(spacing: 14) {
                            amountField(viewModel: viewModel)
                            categoryPicker(viewModel: viewModel)
                            noteField(viewModel: viewModel)
                            locationChip(viewModel: viewModel)
                            datePicker(viewModel: viewModel)

                            if let error = viewModel.saveError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            saveButton(viewModel: viewModel)
                        }
                        .padding(16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .onAppear {
                if viewModel == nil {
                    let repo = ExpenseRepository(context: modelContext)
                    viewModel = AddExpenseViewModel(repository: repo)
                    amountFieldFocused = true
                }
                Task { await viewModel?.resolveLocationIfEnabled() }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
        .preferredColorScheme(.dark)
    }

    private func amountField(viewModel: AddExpenseViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AMOUNT")
                .font(.system(size: 10, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Color.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(CurrencyFormatter.symbol(for: "INR"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
                TextField("0", text: Binding(
                    get: { viewModel.amountText },
                    set: { viewModel.amountText = $0 }
                ))
                .keyboardType(.decimalPad)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.textPrimary)
                .focused($amountFieldFocused)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var categoryGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: 4)
    }

    private func categoryCell(cat: ExpenseCategory, viewModel: AddExpenseViewModel) -> some View {
        let isSelected = viewModel.category == cat
        return Button {
            viewModel.category = cat
            Haptics.light()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? cat.color.opacity(0.25) : Color.white.opacity(0.06))
                        .frame(width: 46, height: 46)
                        .shadow(color: isSelected ? cat.color.opacity(0.4) : .clear, radius: 8, x: 0, y: 4)
                    Image(systemName: cat.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? cat.color : Color.textTertiary)
                }
                Text(cat.rawValue)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? cat.color : Color.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func categoryPicker(viewModel: AddExpenseViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CATEGORY")
                .font(.system(size: 10, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Color.textTertiary)

            LazyVGrid(columns: categoryGridColumns, spacing: 12) {
                ForEach(ExpenseCategory.allCases) { cat in
                    categoryCell(cat: cat, viewModel: viewModel)
                }
            }
        }
        .glassCard()
    }

    private func noteField(viewModel: AddExpenseViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTE")
                .font(.system(size: 10, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Color.textTertiary)
            TextField("Add a note...", text: Binding(
                get: { viewModel.note },
                set: { viewModel.note = $0 }
            ))
            .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func locationChip(viewModel: AddExpenseViewModel) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 34, height: 34)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }

            if viewModel.isResolvingLocation {
                Text("Finding location…")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.white)
            } else if let place = viewModel.resolvedPlaceName {
                VStack(alignment: .leading, spacing: 1) {
                    Text(place)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                    if let locality = viewModel.resolvedLocality {
                        Text(locality)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            } else {
                Text(viewModel.locationTaggingEnabled ? "Location unavailable" : "Location off")
                    .font(.subheadline)
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            Button {
                Task { await viewModel.resolveLocationIfEnabled() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
            .disabled(!viewModel.locationTaggingEnabled)
        }
        .glassCard()
    }

    private func datePicker(viewModel: AddExpenseViewModel) -> some View {
        HStack {
            Text("DATE")
                .font(.system(size: 10, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Color.textTertiary)
            Spacer()
            DatePicker("", selection: Binding(
                get: { viewModel.date },
                set: { viewModel.date = $0 }
            ), displayedComponents: [.date, .hourAndMinute])
            .labelsHidden()
            .colorScheme(.dark)
        }
        .glassCard()
    }

    private func saveButton(viewModel: AddExpenseViewModel) -> some View {
        Button {
            if viewModel.save() { dismiss() }
        } label: {
            Text("Save Expense")
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(viewModel.isValid
                              ? AnyShapeStyle(LinearGradient(colors: [.heroPink, .heroPurple], startPoint: .leading, endPoint: .trailing))
                              : AnyShapeStyle(Color.white.opacity(0.08)))
                        .shadow(color: viewModel.isValid ? Color.heroPink.opacity(0.4) : .clear, radius: 12, x: 0, y: 4)
                )
                .foregroundStyle(.white)
        }
        .disabled(!viewModel.isValid)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isValid)
    }
}
