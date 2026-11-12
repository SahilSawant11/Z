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
                DynamicGradientBackground()

                if let viewModel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            amountField(viewModel: viewModel)
                            categoryPicker(viewModel: viewModel)
                            detailsCard(viewModel: viewModel)

                            if let error = viewModel.saveError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            Button("Save expense") {
                                if viewModel.save() {
                                    Haptics.success()
                                    dismiss()
                                }
                            }
                            .buttonStyle(AccentButtonStyle())
                            .disabled(!viewModel.isValid)
                            .padding(.top, 4)
                        }
                        .padding(16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("New expense")
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
    }

    // MARK: - Amount

    private func amountField(viewModel: AddExpenseViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Amount")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            HStack(alignment: .top, spacing: 4) {
                Text(CurrencyFormatter.symbol(for: "INR"))
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 10)
                TextField("0", text: Binding(
                    get: { viewModel.amountText },
                    set: { viewModel.amountText = $0 }
                ))
                .keyboardType(.decimalPad)
                .font(.system(size: 64, weight: .light))
                .kerning(-2)
                .monospacedDigit()
                .foregroundStyle(Color.textPrimary)
                .focused($amountFieldFocused)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Category

    private var categoryGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: 4)
    }

    private func categoryPicker(viewModel: AddExpenseViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Category")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)

            LazyVGrid(columns: categoryGridColumns, spacing: 14) {
                ForEach(ExpenseCategory.allCases) { cat in
                    categoryCell(cat: cat, viewModel: viewModel)
                }
            }
        }
        .glassCard()
    }

    private func categoryCell(cat: ExpenseCategory, viewModel: AddExpenseViewModel) -> some View {
        let isSelected = viewModel.category == cat
        return Button {
            viewModel.category = cat
            Haptics.light()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: cat.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.onAccent : cat.color)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(isSelected ? cat.color : Color.cardSurfaceRaised))
                Text(cat.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details (note, place, date)

    private func detailsCard(viewModel: AddExpenseViewModel) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                rowIcon("text.alignleft")
                TextField("Add a note", text: Binding(
                    get: { viewModel.note },
                    set: { viewModel.note = $0 }
                ))
                .font(.system(size: 15))
                .foregroundStyle(Color.textPrimary)
            }
            .padding(.vertical, 10)

            Divider().overlay(Color.cardBorder)

            HStack(spacing: 12) {
                rowIcon("mappin.and.ellipse")
                locationLabel(viewModel: viewModel)
                Spacer()
                Button {
                    Task { await viewModel.resolveLocationIfEnabled() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.cardSurfaceRaised))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.locationTaggingEnabled)
                .opacity(viewModel.locationTaggingEnabled ? 1 : 0.4)
            }
            .padding(.vertical, 10)

            Divider().overlay(Color.cardBorder)

            HStack(spacing: 12) {
                rowIcon("calendar")
                Text("When")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                DatePicker("", selection: Binding(
                    get: { viewModel.date },
                    set: { viewModel.date = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
            }
            .padding(.vertical, 10)
        }
        .glassCard(padding: 16)
    }

    @ViewBuilder
    private func locationLabel(viewModel: AddExpenseViewModel) -> some View {
        if viewModel.isResolvingLocation {
            HStack(spacing: 8) {
                Text("Finding location…")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                ProgressView().scaleEffect(0.7)
            }
        } else if let place = viewModel.resolvedPlaceName {
            VStack(alignment: .leading, spacing: 1) {
                Text(place)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                if let locality = viewModel.resolvedLocality {
                    Text(locality)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
            }
        } else {
            Text(viewModel.locationTaggingEnabled ? "Location unavailable" : "Location off")
                .font(.system(size: 15))
                .foregroundStyle(Color.textTertiary)
        }
    }

    private func rowIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.textSecondary)
            .frame(width: 32, height: 32)
            .background(Circle().fill(Color.cardSurfaceRaised))
    }
}
