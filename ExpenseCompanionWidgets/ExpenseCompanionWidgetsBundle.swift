//
//  ExpenseCompanionWidgetsBundle.swift
//  ExpenseCompanionWidgets
//
//  Entry point for the Widget Extension.
//  Only vends BudgetLiveActivity — our Dynamic Island tracker.
//

import WidgetKit
import SwiftUI

@main
struct ExpenseCompanionWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BudgetLiveActivity()
    }
}
