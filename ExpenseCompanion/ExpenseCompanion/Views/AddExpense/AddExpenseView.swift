//
//  AddExpenseView.swift
//  ExpenseCompanion
//
//  Custom half-sheet for logging a new expense. Location resolution kicks
//  off automatically on appear (if enabled) so it's usually ready by the
//  time the user has typed the amount.
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
                DynamicGradientBackground()

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
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
    }

    // MARK: - Sections

    private func amountField(viewModel: AddExpenseViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Amount")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .kerning(0.5)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(CurrencyFormatter.symbol(for: "INR"))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.secondary)
                TextField("0", text: Binding(
                    get: { viewModel.amountText },
                    set: { viewModel.amountText = $0 }
                ))
                .keyboardType(.decimalPad)
                .font(.system(.title, design: .rounded).weight(.bold))
                .monospacedDigit()
                .focused($amountFieldFocused)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func categoryPicker(viewModel: AddExpenseViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .kerning(0.5)

            LazyVGrid(columns: categoryGridColumns, spacing: 10) {
                ForEach(ExpenseCategory.allCases) { cat in
                    categoryCell(cat: cat, viewModel: viewModel)
                }
            }
        }
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
                Image(systemName: cat.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : cat.color)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(cat.color.gradient) : AnyShapeStyle(cat.color.opacity(0.12)))
                    )
                    .shadow(color: isSelected ? cat.color.opacity(0.35) : .clear, radius: 6, x: 0, y: 3)
                Text(cat.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func noteField(viewModel: AddExpenseViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .kerning(0.5)
            TextField("Add a note...", text: Binding(
                get: { viewModel.note },
                set: { viewModel.note = $0 }
            ))
            .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func locationChip(viewModel: AddExpenseViewModel) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            if viewModel.isResolvingLocation {
                Text("Finding your location…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView()
                    .scaleEffect(0.7)
            } else if let place = viewModel.resolvedPlaceName {
                VStack(alignment: .leading, spacing: 0) {
                    Text(place)
                        .font(.subheadline.weight(.medium))
                    if let locality = viewModel.resolvedLocality {
                        Text(locality)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(viewModel.locationTaggingEnabled ? "Location unavailable" : "Location off")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await viewModel.resolveLocationIfEnabled() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .disabled(!viewModel.locationTaggingEnabled)
        }
        .glassCard()
    }

    private func datePicker(viewModel: AddExpenseViewModel) -> some View {
        HStack {
            Text("Date")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .kerning(0.5)
            Spacer()
            DatePicker("", selection: Binding(
                get: { viewModel.date },
                set: { viewModel.date = $0 }
            ), displayedComponents: [.date, .hourAndMinute])
            .labelsHidden()
        }
        .glassCard()
    }

    private func saveButton(viewModel: AddExpenseViewModel) -> some View {
        Button {
            if viewModel.save() {
                dismiss()
            }
        } label: {
            Text("Save Expense")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(viewModel.isValid
                              ? AnyShapeStyle(Color.accentColor.gradient)
                              : AnyShapeStyle(Color.gray.opacity(0.3)))
                )
                .foregroundStyle(.white)
        }
        .disabled(!viewModel.isValid)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isValid)
    }
}
