//
//  BudgetActivityManager.swift
//  ExpenseCompanion
//
//  Singleton that manages the budget Live Activity lifecycle.
//  Call startOrUpdate() whenever spending data changes.
//  Handles: first launch, updates, device not supporting activities.
//

import ActivityKit
import Foundation

@MainActor
final class BudgetActivityManager {

    static let shared = BudgetActivityManager()
    private init() {}

    private var currentActivity: Activity<BudgetActivityAttributes>?

    // MARK: - Public API

    /// Start a new activity or update the existing one.
    func startOrUpdate(spent: Double, limit: Double, txCount: Int,
                       currencyCode: String, currencySymbol: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              limit > 0 else { return }

        let state = BudgetActivityAttributes.BudgetState(
            spent: spent,
            limit: limit,
            transactionCount: txCount,
            currencyCode: currencyCode,
            lastUpdated: .now
        )

        if let activity = currentActivity {
            // Activity exists — update it
            Task {
                let content = ActivityContent(state: state, staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: .now))
                await activity.update(content)
            }
        } else {
            // Start fresh
            let attributes = BudgetActivityAttributes(currencySymbol: currencySymbol)
            let content = ActivityContent(state: state, staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: .now))
            do {
                currentActivity = try Activity<BudgetActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                // Silently ignore — device may not support Live Activities
                print("[BudgetActivityManager] Could not start Live Activity: \(error.localizedDescription)")
            }
        }
    }

    /// End the live activity. Call when the app goes to background or budget isn't configured.
    func end(dismissAfter seconds: Double = 4) {
        guard let activity = currentActivity else { return }
        Task {
            let finalPolicy: ActivityUIDismissalPolicy = seconds <= 0
                ? .immediate
                : .after(.now.addingTimeInterval(seconds))
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil),
                               dismissalPolicy: finalPolicy)
            self.currentActivity = nil
        }
    }

    /// Dismiss immediately — e.g. when the user hasn't set a budget.
    func endImmediately() {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil),
                               dismissalPolicy: .immediate)
            self.currentActivity = nil
        }
    }
}
