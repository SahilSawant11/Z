//
//  LocationClusterDetailView.swift
//  ExpenseCompanion
//
//  Place detail sheet. Shows per-location stats, a mini map,
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
                DynamicGradientBackground()

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
        HeroCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spent here")
                            .font(.system(size: 15, weight: .medium))
                        Text("\(cluster.visitCount) visit\(cluster.visitCount == 1 ? "" : "s") · mostly \(cluster.dominantCategory.rawValue.lowercased())")
                            .font(.system(size: 12))
                            .opacity(0.6)
                    }
                    Spacer()
                    Image(systemName: cluster.dominantCategory.symbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.onAccent.opacity(0.1)))
                }
                HStack(alignment: .lastTextBaseline) {
                    BigAmount(amount: cluster.totalAmount, size: 52)
                    Spacer()
                    if cluster.visitCount > 1 {
                        Text("\(CurrencyFormatter.format((cluster.totalAmount / Double(cluster.visitCount)).rounded())) / visit")
                            .font(.system(size: 12, weight: .medium))
                            .opacity(0.6)
                    }
                }
            }
        }
    }

    // MARK: - Mini Map

    private var miniMap: some View {
        Map(position: $cameraPosition) {
            Marker(cluster.displayName, coordinate: cluster.coordinate)
                .tint(cluster.dominantCategory.color)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Expense List

    private var expenseList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Expenses here")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .padding(.bottom, 8)
            let sorted = cluster.expenses.sorted(by: { $0.date > $1.date })
            ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, expense in
                ExpenseRowView(expense: expense)
                if idx < sorted.count - 1 {
                    Divider().overlay(Color.cardBorder).padding(.vertical, 6)
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
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.green)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.cardSurfaceRaised))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saved as place")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                        Text(existingPlace.label)
                            .font(.system(size: 15, weight: .semibold))
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
                    Label("Save as frequent place", systemImage: "star.fill")
                }
                .buttonStyle(AccentButtonStyle())
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
                DynamicGradientBackground()

                VStack(spacing: 14) {
                    // Preset label chips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Label")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
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
                                        .foregroundStyle(isSelected ? Color.appBackground : Color.textSecondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 9)
                                        .frame(maxWidth: .infinity)
                                        .background(Capsule().fill(isSelected ? Color.textPrimary : Color.cardSurfaceRaised))
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
                        Text("Monthly limit (optional)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                        TextField("e.g. 2000", text: $spendingLimitText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 32, weight: .light))
                            .monospacedDigit()
                            .foregroundStyle(Color.textPrimary)
                        Text("Enables a location alert when you're near this spot and have exceeded this limit.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()

                    // Save button
                    Button("Save place", action: save)
                        .buttonStyle(AccentButtonStyle())
                        .disabled(customLabel.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Label this place")
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
