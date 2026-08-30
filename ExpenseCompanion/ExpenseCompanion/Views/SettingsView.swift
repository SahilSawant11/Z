//
//  SettingsView.swift
//  ExpenseCompanion
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var locationManager: LocationManager
    @StateObject private var geofenceManager = GeofenceManager.shared

    @State private var budgetSettings: DailyBudgetSettings?
    @State private var dailyLimitText: String = ""
    @State private var placesWithLimits: [FrequentPlace] = []

    var body: some View {
        NavigationStack {
            ZStack {
                DynamicGradientBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            GlassSectionHeader(title: "Daily Budget", systemImage: "dial.medium")
                            HStack {
                                Text(CurrencyFormatter.symbol(for: budgetSettings?.currencyCode ?? "INR"))
                                TextField("500", text: $dailyLimitText)
                                    .keyboardType(.decimalPad)
                                    .onSubmit(saveBudget)
                            }
                            Toggle("Rollover unused budget", isOn: Binding(
                                get: { budgetSettings?.rolloverEnabled ?? false },
                                set: { newValue in
                                    budgetSettings?.rolloverEnabled = newValue
                                    try? modelContext.save()
                                }
                            ))
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 10) {
                            GlassSectionHeader(title: "Privacy", systemImage: "lock.shield")
                            Toggle("Tag expenses with location", isOn: Binding(
                                get: { locationManager.isLocationTaggingEnabled },
                                set: { locationManager.isLocationTaggingEnabled = $0 }
                            ))
                            Text("Location is stored only on this device and in your private iCloud data — it's never sent to any server.")
                                .font(.caption)
                                .opacity(0.6)
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 10) {
                            GlassSectionHeader(title: "Location Alerts", systemImage: "bell.badge")
                            Toggle("Alert me near high-spending places", isOn: Binding(
                                get: { geofenceManager.isMonitoringEnabled },
                                set: { newValue in
                                    if newValue {
                                        geofenceManager.enableMonitoring(for: placesWithLimits)
                                    } else {
                                        geofenceManager.disableMonitoring()
                                    }
                                }
                            ))
                            Text("This needs \"Always\" location access — a bigger permission than expense tagging — because it has to work while the app is closed. Only places you've set a spending limit for (via the Map tab) are monitored, up to 20 at a time.")
                                .font(.caption)
                                .opacity(0.6)
                            if placesWithLimits.isEmpty {
                                Text("No places have a spending limit set yet.")
                                    .font(.caption2)
                                    .opacity(0.5)
                            }
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 10) {
                            GlassSectionHeader(title: "Data", systemImage: "tray.full")
                            Text("Export and iCloud sync controls go here (Phase 4).")
                                .font(.caption)
                                .opacity(0.6)
                        }
                        .glassCard()
                    }
                    .padding(16)
                    .padding(.bottom, 90)
                }
            }
            .navigationTitle("Settings")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: loadSettings)
        }
    }

    private func loadSettings() {
        let repo = GoalRepository(context: modelContext)
        budgetSettings = try? repo.fetchOrCreateBudgetSettings()
        dailyLimitText = budgetSettings.map { String(format: "%.0f", $0.dailyLimit) } ?? "500"

        let placeRepo = PlaceRepository(context: modelContext)
        placesWithLimits = ((try? placeRepo.allPlaces()) ?? []).filter { $0.spendingLimit != nil }
    }

    private func saveBudget() {
        guard let value = Double(dailyLimitText), value > 0 else { return }
        budgetSettings?.dailyLimit = value
        try? modelContext.save()
    }
}
