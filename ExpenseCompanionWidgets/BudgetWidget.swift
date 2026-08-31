//
//  BudgetWidget.swift
//  ExpenseCompanionWidgets
//
//  Widget configurations — one per family group.
//  All share the same BudgetWidgetProvider and BudgetWidgetEntryView.
//

import WidgetKit
import SwiftUI

// MARK: - Home Screen Widget (Small + Medium + Large)

struct BudgetHomeWidget: Widget {
    static let kind = "BudgetHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: BudgetWidgetProvider()) { entry in
            BudgetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Budget Tracker")
        .description("Track today's spending against your daily budget.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Lock Screen Widget (Circular + Rectangular + Inline)

struct BudgetLockScreenWidget: Widget {
    static let kind = "BudgetLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: BudgetWidgetProvider()) { entry in
            BudgetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Budget (Lock Screen)")
        .description("At-a-glance spending on your Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
