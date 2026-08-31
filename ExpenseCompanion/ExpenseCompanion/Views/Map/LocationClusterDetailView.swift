//
//  LocationClusterDetailView.swift
//  ExpenseCompanion
//
//  Dark fintech cluster detail sheet. Shows per-location stats, a mini map,
//  expense list, and lets the user save it as a labeled frequent place.
//

import SwiftUI
import MapKit
import SwiftData

struct LocationClusterDetailView: View {
    let cluster: LocationCluster

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var existingPlace: FrequentPlace?
    @State private var showingLabelSheet = false
    @State private var cameraPosition: MapCameraPosition

    init(cluster: LocationCluster) {
        self.cluster = cluster
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(center: cluster.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008))
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                // Per-cluster color radial glow
                RadialGradient(
                    colors: [cluster.dominantCategory.color.opacity(0.22), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        summaryCard
                        miniMap
                        expenseList
                        saveAsPlaceButton
                    }
                    .padding(16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(cluster.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .onAppear(perform: checkExistingPlace)
            .sheet(isPresented: $showingLabelSheet) {
                LabelPlaceView(cluster: cluster) {
                    checkExistingPlace()
                }
            }
        }
        
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 0) {
            statCell(value: "\(cluster.visitCount)", label: "Visits")
            Divider().frame(width: 1).background(Color.white.opacity(0.08)).padding(.vertical, 8)
            statCell(value: CurrencyFormatter.format(cluster.totalAmount), label: "Total Spent")
            Divider().frame(width: 1).background(Color.white.opacity(0.08)).padding(.vertical, 8)
            // Dominant category
            VStack(spacing: 6) {
                CategoryBadge(category: cluster.dominantCategory, size: 36)
                Text("MOSTLY")
                    .font(.system(size: 9, weight: .semibold))
                    .kerning(1.0)
                    .foregroundStyle(Color.textTertiary)
                Text(cluster.dominantCategory.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .glassCard()
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.textPrimary)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .kerning(1.0)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mini Map

    private var miniMap: some View {
        Map(position: $cameraPosition) {
            Marker(cluster.displayName, coordinate: cluster.coordinate)
                .tint(cluster.dominantCategory.color)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Expense List

    private var expenseList: some View {
        VStack(alignment: .leading, spacing: 0) {
            GlassSectionHeader(title: "Expenses Here", systemImage: "list.bullet")
                .padding(.bottom, 8)
            let sorted = cluster.expenses.sorted(by: { $0.date > $1.date })
            ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, expense in
                ExpenseRowView(expense: expense)
                if idx < sorted.count - 1 {
                    Divider().background(Color.white.opacity(0.07))
                }
            }
        }
        .glassCard()
    }

    // MARK: - Save as Place

    private var saveAsPlaceButton: some View {
        Group {
            if let existingPlace {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.green)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saved as Place")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                        Text(existingPlace.label)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                    }
                    Spacer()
                    Button("Edit") { showingLabelSheet = true }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.heroPink)
                }
                .glassCard()
            } else if cluster.visitCount >= LocationInsightsEngine.minVisitsForFrequentPlace {
                Button {
                    showingLabelSheet = true
                } label: {
                    Label("Save as Frequent Place", systemImage: "star.fill")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(LinearGradient(colors: [.heroPink, .heroPurple], startPoint: .leading, endPoint: .trailing))
                                .shadow(color: Color.heroPink.opacity(0.4), radius: 10, x: 0, y: 4)
                        )
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func checkExistingPlace() {
        let repo = PlaceRepository(context: modelContext)
        existingPlace = try? repo.existingPlace(near: cluster.coordinate)
    }
}

// MARK: - Label Place Sheet

private struct LabelPlaceView: View {
    let cluster: LocationCluster
    var onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let presetLabels = ["Home", "Work", "Gym", "Cafe", "Market"]
    @State private var customLabel: String = ""
    @State private var spendingLimitText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                RadialGradient(
                    colors: [Color.heroPurple.opacity(0.20), Color.clear],
                    center: .top, startRadius: 0, endRadius: 280
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    // Preset label chips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LABEL")
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(1.2)
                            .foregroundStyle(Color.textTertiary)
                        // Presets
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                            ForEach(presetLabels, id: \.self) { label in
                                let isSelected = customLabel == label
                                Button {
                                    customLabel = label
                                    Haptics.light()
                                } label: {
                                    Text(label)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(isSelected ? .white : Color.textSecondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(isSelected
                                                      ? AnyShapeStyle(LinearGradient(colors: [.heroPink, .heroPurple], startPoint: .leading, endPoint: .trailing))
                                                      : AnyShapeStyle(Color.white.opacity(0.07)))
                                        )
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                            }
                        }
                        TextField("Or type a custom name", text: $customLabel)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()

                    // Spending limit
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MONTHLY LIMIT (OPTIONAL)")
                            .font(.system(size: 10, weight: .semibold))
                            .kerning(1.2)
                            .foregroundStyle(Color.textTertiary)
                        TextField("e.g. 2000", text: $spendingLimitText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.textPrimary)
                        Text("Enables a location alert when you're near this spot and have exceeded this limit.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()

                    // Save button
                    Button { save() } label: {
                        Text("Save Place")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(customLabel.isEmpty
                                          ? AnyShapeStyle(Color.white.opacity(0.08))
                                          : AnyShapeStyle(LinearGradient(colors: [.heroPink, .heroPurple], startPoint: .leading, endPoint: .trailing)))
                                    .shadow(color: customLabel.isEmpty ? .clear : Color.heroPink.opacity(0.4), radius: 12, x: 0, y: 4)
                            )
                            .foregroundStyle(.white)
                    }
                    .disabled(customLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                    .animation(.easeInOut(duration: 0.2), value: customLabel.isEmpty)

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Label This Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.appBackground)
        
    }

    private func save() {
        let place = FrequentPlace(
            label: customLabel,
            latitude: cluster.coordinate.latitude,
            longitude: cluster.coordinate.longitude,
            spendingLimit: Double(spendingLimitText)
        )
        let repo = PlaceRepository(context: modelContext)
        try? repo.add(place)
        Haptics.success()
        onSaved()
        dismiss()
    }
}
