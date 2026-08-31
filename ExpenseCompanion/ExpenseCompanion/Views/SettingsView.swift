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
    @State private var selectedCurrency: String = "INR"
    @State private var placesWithLimits: [FrequentPlace] = []
    @State private var showingExportAlert = false
    @FocusState private var budgetFieldFocused: Bool
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled = true
    @AppStorage("appTheme") private var appTheme: AppTheme = .dark

    private let currencies = ["INR", "USD", "EUR", "GBP", "JPY", "AED", "SGD", "CAD", "AUD"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                RadialGradient(
                    colors: [Color.accentBlue.opacity(0.18), Color.clear],
                    center: .top, startRadius: 0, endRadius: 340
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SETTINGS")
                                    .font(.system(size: 10, weight: .semibold))
                                    .kerning(1.5)
                                    .foregroundStyle(Color.textTertiary)
                                Text("Preferences")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)
                            }
                            Spacer()
                        }
                        .padding(.top, 4)

                        // ── APPEARANCE ─────────────────────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            GlassSectionHeader(title: "Appearance", systemImage: "paintbrush")

                            HStack(spacing: 10) {
                                ForEach(AppTheme.allCases, id: \.self) { theme in
                                    let isSelected = appTheme == theme
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            appTheme = theme
                                        }
                                        Haptics.light()
                                    } label: {
                                        VStack(spacing: 7) {
                                            Image(systemName: theme.icon)
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(isSelected ? .white : Color.textSecondary)
                                            Text(theme.rawValue)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(isSelected ? .white : Color.textSecondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(isSelected
                                                      ? AnyShapeStyle(LinearGradient(colors: [.heroPink, .heroPurple], startPoint: .leading, endPoint: .trailing))
                                                      : AnyShapeStyle(Color.cardBorder))
                                                .shadow(color: isSelected ? Color.heroPink.opacity(0.35) : .clear, radius: 8, x: 0, y: 3)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                                }
                            }
                        }
                        .glassCard()

                        // ── BUDGET ─────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            GlassSectionHeader(title: "Daily Budget", systemImage: "dial.medium")

                            HStack(alignment: .center, spacing: 8) {
                                Text(CurrencyFormatter.symbol(for: selectedCurrency))
                                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.textTertiary)
                                TextField("500", text: $dailyLimitText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.textPrimary)
                                    .focused($budgetFieldFocused)
                                    .toolbar {
                                        ToolbarItemGroup(placement: .keyboard) {
                                            Spacer()
                                            Button("Done") {
                                                budgetFieldFocused = false
                                            }
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.heroPink)
                                        }
                                    }
                                Spacer()
                                // Visible Save button
                                Button {
                                    saveBudget()
                                    budgetFieldFocused = false
                                    Haptics.success()
                                } label: {
                                    Text("SAVE")
                                        .font(.system(size: 11, weight: .bold))
                                        .kerning(1.0)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(LinearGradient(colors: [.heroPink, .heroPurple], startPoint: .leading, endPoint: .trailing))
                                                .shadow(color: Color.heroPink.opacity(0.4), radius: 6, x: 0, y: 3)
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled((Double(dailyLimitText) ?? 0) <= 0)
                                .opacity((Double(dailyLimitText) ?? 0) <= 0 ? 0.4 : 1.0)
                            }

                            Divider().background(Color.white.opacity(0.07))

                            // Currency picker
                            HStack {
                                Text("Currency")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Picker("", selection: $selectedCurrency) {
                                    ForEach(currencies, id: \.self) { code in
                                        Text(code).tag(code)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.heroPink)
                                .onChange(of: selectedCurrency) { _, newVal in
                                    budgetSettings?.currencyCode = newVal
                                    try? modelContext.save()
                                }
                            }

                            Divider().background(Color.white.opacity(0.07))

                            darkToggle(isOn: Binding(
                                get: { budgetSettings?.rolloverEnabled ?? false },
                                set: { budgetSettings?.rolloverEnabled = $0; try? modelContext.save() }
                            ), label: "Roll over unused budget daily")
                        }
                        .glassCard()

                        // ── PRIVACY ────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            GlassSectionHeader(title: "Privacy & Location", systemImage: "lock.shield")

                            darkToggle(isOn: Binding(
                                get: { locationManager.isLocationTaggingEnabled },
                                set: { locationManager.isLocationTaggingEnabled = $0 }
                            ), label: "Tag expenses with location")

                            Divider().background(Color.white.opacity(0.07))

                            darkToggle(isOn: Binding(
                                get: { geofenceManager.isMonitoringEnabled },
                                set: { newValue in
                                    if newValue {
                                        geofenceManager.enableMonitoring(for: placesWithLimits)
                                    } else {
                                        geofenceManager.disableMonitoring()
                                    }
                                }
                            ), label: "Alert near high-spending places")

                            if geofenceManager.isMonitoringEnabled && placesWithLimits.isEmpty {
                                infoNote("No places with a spending limit yet. Set limits in the Map tab.")
                            } else {
                                infoNote("Location data is stored only on your device and private iCloud — never sent to any server.")
                            }
                        }
                        .glassCard()

                        // ── DYNAMIC ISLAND ────────────────────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            GlassSectionHeader(title: "Dynamic Island", systemImage: "dot.radiowaves.left.and.right")

                            darkToggle(isOn: $liveActivityEnabled, label: "Show budget in Dynamic Island")
                                .onChange(of: liveActivityEnabled) { _, enabled in
                                    if !enabled {
                                        BudgetActivityManager.shared.endImmediately()
                                    }
                                }

                            infoNote("Live budget tracker appears in the Dynamic Island and Lock Screen while the app is running.")
                        }
                        .glassCard()

                        // ── NOTIFICATIONS ──────────────────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            GlassSectionHeader(title: "Notifications", systemImage: "bell.badge")
                            infoNote("Daily budget reminders and upcoming payment alerts coming in the next update.")
                        }
                        .glassCard()

                        // ── DATA & EXPORT ──────────────────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            GlassSectionHeader(title: "Data & Export", systemImage: "tray.and.arrow.up")

                            Button {
                                showingExportAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.heroPink)
                                    Text("Export as CSV")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)
                            .alert("Export Coming Soon", isPresented: $showingExportAlert) {
                                Button("OK", role: .cancel) {}
                            } message: {
                                Text("CSV export will be available in the next update.")
                            }

                            Divider().background(Color.white.opacity(0.07))

                            infoNote("Your data syncs privately via iCloud. To delete all data, remove the app.")
                        }
                        .glassCard()

                        // ── ABOUT ──────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            GlassSectionHeader(title: "About", systemImage: "info.circle")
                            HStack {
                                Text("ExpenseCompanion")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Text("v1.0")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.textTertiary)
                            }
                            infoNote("Built with SwiftUI + SwiftData. iCloud sync enabled.")
                        }
                        .glassCard()
                    }
                    .padding(16)
                    .padding(.bottom, 90)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: loadSettings)
        }
        
    }

    // MARK: - Sub-components

    private func darkToggle(isOn: Binding<Bool>, label: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.heroPink)
        }
    }

    private func infoNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Color.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Data

    private func loadSettings() {
        let repo = GoalRepository(context: modelContext)
        budgetSettings = try? repo.fetchOrCreateBudgetSettings()
        dailyLimitText = budgetSettings.map { String(format: "%.0f", $0.dailyLimit) } ?? "500"
        selectedCurrency = budgetSettings?.currencyCode ?? "INR"

        let placeRepo = PlaceRepository(context: modelContext)
        placesWithLimits = ((try? placeRepo.allPlaces()) ?? []).filter { $0.spendingLimit != nil }
    }

    private func saveBudget() {
        guard let value = Double(dailyLimitText), value > 0 else { return }
        budgetSettings?.dailyLimit = value
        try? modelContext.save()
    }
}
