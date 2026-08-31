//
//  ExpenseCompanionWidgetsBundle.swift
//  ExpenseCompanionWidgets
//
//  Entry point for the Widget Extension — vends all widgets.
//

import WidgetKit
import SwiftUI

@main
struct ExpenseCompanionWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Live Activity (Dynamic Island)
        BudgetLiveActivity()
        // Home Screen widgets
        BudgetHomeWidget()
        // Lock Screen widgets
        BudgetLockScreenWidget()
    }
}
