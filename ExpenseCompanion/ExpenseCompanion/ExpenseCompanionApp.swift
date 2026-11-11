//
//  ExpenseCompanionApp.swift
//  ExpenseCompanion
//
//  App entry point. Configures the SwiftData model container with
//  CloudKit sync enabled so expenses/goals sync across the user's devices.
//

import SwiftUI
import SwiftData

@main
struct ExpenseCompanionApp: App {

    /// Single shared container for the whole app.
    /// CloudKit sync is opt-in via ModelConfiguration; if the user is not
    /// signed into iCloud, SwiftData gracefully falls back to local-only storage.
    let modelContainer: ModelContainer = {
        let schema = Schema([
            Expense.self,
            FinancialGoal.self,
            DailyBudgetSettings.self,
            FrequentPlace.self,
            StudyAbroadPlan.self,
            PlanMilestone.self,
            UniversityApplication.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Falling back to an in-memory store keeps the app usable rather than crashing outright.
            // In production you'd want to surface this to the user / log to your crash reporter.
            assertionFailure("Failed to create persistent ModelContainer: \(error)")
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallbackConfig])
        }
    }()

    // Shared singletons injected as environment objects.
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var appearanceTimeProvider = TimeOfDayProvider()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(locationManager)
                .environmentObject(appearanceTimeProvider)
                
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, phase in
            // Refresh deadline reminders when the app opens and when the user leaves it,
            // so edits made in between are always reflected.
            guard phase == .active || phase == .background else { return }
            Task { await DeadlineReminderScheduler.reschedule(context: modelContainer.mainContext) }
        }
    }
}
