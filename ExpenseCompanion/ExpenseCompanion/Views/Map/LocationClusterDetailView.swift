//
//  LocationClusterDetailView.swift
//  ExpenseCompanion
//
//  Shown when tapping a cluster pin on the map. Lists every expense at that
//  spot and lets the user save it as a labeled "frequent place" (Home, Work,
//  Gym, Cafe, or custom) — the first step toward location-based budgeting.
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
                    VStack(spacing: 16) {
                        summaryCard
                        miniMap
                        expenseList
                        saveAsPlaceButton
                    }
                    .padding(16)
                }
            }
            .navigationTitle(cluster.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
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

    private var summaryCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Visits")
                    .font(.caption).opacity(0.6)
                Text("\(cluster.visitCount)")
                    .font(.system(.title2, design: .rounded).bold())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Total Spent")
                    .font(.caption).opacity(0.6)
                Text(CurrencyFormatter.format(cluster.totalAmount))
                    .font(.system(.title2, design: .rounded).bold())
                    .monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Mostly")
                    .font(.caption).opacity(0.6)
                Text("\(cluster.dominantCategory.emoji) \(cluster.dominantCategory.rawValue)")
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
        }
        .glassCard()
    }

    private var miniMap: some View {
        Map(position: $cameraPosition) {
            Marker(cluster.displayName, coordinate: cluster.coordinate)
                .tint(cluster.dominantCategory.color)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .glassCard()
    }

    private var expenseList: some View {
        VStack(alignment: .leading, spacing: 10) {
            GlassSectionHeader(title: "Expenses Here", systemImage: "list.bullet")
            ForEach(cluster.expenses.sorted(by: { $0.date > $1.date })) { expense in
                ExpenseRowView(expense: expense)
                Divider().opacity(0.2)
            }
        }
        .glassCard()
    }

    private var saveAsPlaceButton: some View {
        Group {
            if let existingPlace {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text("Saved as \"\(existingPlace.label)\"")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Button("Edit") { showingLabelSheet = true }
                }
                .glassCard()
            } else if cluster.visitCount >= LocationInsightsEngine.minVisitsForFrequentPlace {
                Button {
                    showingLabelSheet = true
                } label: {
                    Label("Save as a Frequent Place", systemImage: "star.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.accentColor))
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

    private let presetLabels = ["Home", "Work", "Gym", "Cafe"]
    @State private var customLabel: String = ""
    @State private var spendingLimitText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                DynamicGradientBackground()
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Label").font(.caption).opacity(0.6)
                        HStack {
                            ForEach(presetLabels, id: \.self) { label in
                                Button(label) { customLabel = label }
                                    .buttonStyle(.bordered)
                            }
                        }
                        TextField("Or type a custom name", text: $customLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Monthly Spending Limit (optional)").font(.caption).opacity(0.6)
                        TextField("e.g. 2000", text: $spendingLimitText)
                            .keyboardType(.decimalPad)
                        Text("Set this if you'd like a location-based alert when you're near this spot — you'll need to enable that separately in Settings.")
                            .font(.caption2)
                            .opacity(0.5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()

                    Button {
                        save()
                    } label: {
                        Text("Save Place")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 16).fill(customLabel.isEmpty ? Color.gray.opacity(0.4) : Color.accentColor))
                            .foregroundStyle(.white)
                    }
                    .disabled(customLabel.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Label This Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
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
