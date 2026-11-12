//
//  BudgetWidgetViews.swift
//  ExpenseCompanionWidgets
//
//  All widget view bodies:
//
//  HOME SCREEN
//    • Small  (2×2) — Solid pink: spent today, % ring, amount left
//    • Medium (4×2) — Pink spent panel + today's top categories
//    • Large  (4×4) — Pink spent panel, tick gauge, 7-day bars, categories
//
//  LOCK SCREEN
//    • Accessory Circular   — Arc ring with % center
//    • Accessory Rectangular — Bar + spent text
//    • Accessory Inline     — Short text: "💳 ₹2.3k • 46%"
//

import SwiftUI
import WidgetKit

// MARK: - Root dispatcher (picks view based on family)

struct BudgetWidgetEntryView: View {
    var entry: BudgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:       SmallBudgetWidget(data: entry.data)
        case .systemMedium:      MediumBudgetWidget(data: entry.data)
        case .systemLarge:       LargeBudgetWidget(data: entry.data)
        case .accessoryCircular: AccessoryCircularWidget(data: entry.data)
        case .accessoryRectangular: AccessoryRectangularWidget(data: entry.data)
        case .accessoryInline:   AccessoryInlineWidget(data: entry.data)
        default:                 SmallBudgetWidget(data: entry.data)
        }
    }
}

// MARK: - Shared pieces

private extension WidgetSpendingData {
    var spentGrouped: String { W.grouped(todaySpent, currencyCode: currencyCode) }

    /// "₹200 left" or "₹40 over".
    var leftOrOverText: String {
        isOverBudget
            ? "\(currencySymbol)\(W.grouped(todaySpent - dailyLimit, currencyCode: currencyCode)) over"
            : "\(currencySymbol)\(W.grouped(remaining, currencyCode: currencyCode)) left"
    }

    var markerColor: Color {
        isOverBudget ? W.red : (usedFraction >= 0.8 ? .orange : W.pink)
    }
}

/// The pink "spent today" block used by every home-screen size.
private struct SpentPanel: View {
    let data: WidgetSpendingData
    var amountSize: CGFloat = 40
    var showsLeft: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("Today")
                    .font(.system(size: 13, weight: .medium))
                Spacer(minLength: 4)
                if data.dailyLimit > 0 {
                    WRing(progress: data.usedFraction, tint: W.ink, size: 34)
                }
            }
            Spacer(minLength: 6)
            WAmount(symbol: data.currencySymbol, value: data.spentGrouped, size: amountSize)
            if showsLeft {
                Text(data.dailyLimit > 0 ? data.leftOrOverText : "\(data.transactionCount) transactions")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.6)
                    .padding(.top, 2)
            }
        }
        .foregroundStyle(W.ink)
    }
}

// MARK: ─── HOME SCREEN — SMALL ────────────────────────────────────────────

/// Whole widget is the pink accent.
struct SmallBudgetWidget: View {
    let data: WidgetSpendingData

    var body: some View {
        SpentPanel(data: data, amountSize: 40)
            .widgetBackground(W.pink)
    }
}

// MARK: ─── HOME SCREEN — MEDIUM ──────────────────────────────────────────

/// Pink spent panel on the left, today's categories on charcoal to the right.
struct MediumBudgetWidget: View {
    let data: WidgetSpendingData

    var body: some View {
        HStack(spacing: 14) {
            SpentPanel(data: data, amountSize: 34)
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(W.pink))

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("By category")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(W.text2)
                    Spacer()
                    Text("\(data.transactionCount)")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(W.text2)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(W.raised))
                }
                .padding(.bottom, 6)

                if data.categoryBreakdown.isEmpty {
                    Spacer()
                    Text("Nothing logged yet")
                        .font(.system(size: 12))
                        .foregroundStyle(W.text3)
                    Spacer()
                } else {
                    ForEach(data.categoryBreakdown.prefix(3)) { cat in
                        CategoryRow(cat: cat, data: data)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .widgetBackground(W.bg)
    }
}

private struct CategoryRow: View {
    let cat: WidgetCategoryItem
    let data: WidgetSpendingData

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: cat.symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(cat.name.categoryWidgetColor)
                .frame(width: 24, height: 24)
                .background(Circle().fill(W.raised))
            Text(cat.name)
                .font(.system(size: 12))
                .foregroundStyle(W.text1)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(data.currencySymbol + data.fmt(cat.amount))
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(W.text1)
        }
        .padding(.vertical, 3)
    }
}

// MARK: ─── HOME SCREEN — LARGE ───────────────────────────────────────────

struct LargeBudgetWidget: View {
    let data: WidgetSpendingData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SpentPanel(data: data, amountSize: 44, showsLeft: false)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 112)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(W.pink))

            // Budget gauge
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(data.dailyLimit > 0 ? data.leftOrOverText : "No daily budget set")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(data.isOverBudget ? W.red : W.text1)
                    Spacer()
                    if data.dailyLimit > 0 {
                        Text("of \(data.currencySymbol)\(W.grouped(data.dailyLimit, currencyCode: data.currencyCode))")
                            .font(.system(size: 11))
                            .foregroundStyle(W.text3)
                    }
                }
                WTickGauge(progress: data.usedFraction, ticks: 36, height: 20, marker: data.markerColor)
            }

            // Last 7 days
            VStack(alignment: .leading, spacing: 6) {
                Text("Last 7 days")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(W.text2)
                let labels = ["6d", "5d", "4d", "3d", "2d", "1d", "Today"]
                let maxSpend = max(data.weeklySpending.max() ?? 1, 1)
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(data.weeklySpending.enumerated()), id: \.offset) { idx, amount in
                        let isToday = idx == data.weeklySpending.count - 1
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isToday ? W.pink : W.raised)
                                .frame(height: max(CGFloat(amount / maxSpend) * 44, 4))
                            Text(idx < labels.count ? labels[idx] : "")
                                .font(.system(size: 8, weight: isToday ? .semibold : .regular))
                                .foregroundStyle(isToday ? W.text1 : W.text3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 58, alignment: .bottom)
            }

            // Top categories
            if !data.categoryBreakdown.isEmpty {
                VStack(spacing: 6) {
                    ForEach(data.categoryBreakdown.prefix(3)) { cat in
                        LargeCategoryBar(cat: cat)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetBackground(W.bg)
    }
}

private struct LargeCategoryBar: View {
    let cat: WidgetCategoryItem
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: cat.symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(cat.name.categoryWidgetColor)
                .frame(width: 20, height: 20)
                .background(Circle().fill(W.raised))
            Text(cat.name)
                .font(.system(size: 11))
                .foregroundStyle(W.text1)
                .frame(width: 84, alignment: .leading)
            ZStack(alignment: .leading) {
                Capsule().fill(W.raised).frame(height: 4)
                Capsule()
                    .fill(cat.name.categoryWidgetColor)
                    .frame(height: 4)
                    .scaleEffect(x: max(cat.fraction, 0.02), y: 1, anchor: .leading)
            }
            Text(String(format: "%.0f%%", cat.fraction * 100))
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(W.text3)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: ─── LOCK SCREEN — CIRCULAR ────────────────────────────────────────

struct AccessoryCircularWidget: View {
    let data: WidgetSpendingData
    var body: some View {
        ZStack {
            Gauge(value: data.usedFraction) { EmptyView() }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(data.isOverBudget ? W.red : W.pink)
            Text(data.percentText)
                .font(.system(size: 12, weight: .medium))
        }
        .widgetAccentable()
    }
}

// MARK: ─── LOCK SCREEN — RECTANGULAR ─────────────────────────────────────

struct AccessoryRectangularWidget: View {
    let data: WidgetSpendingData
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Budget today")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.6))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(data.spentText)
                    .font(.system(size: 17, weight: .regular))
                    .monospacedDigit()
                Text("/ \(data.limitText)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Gauge(value: data.usedFraction) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(data.isOverBudget ? W.red : W.pink)
        }
        .widgetAccentable()
    }
}

// MARK: ─── LOCK SCREEN — INLINE ──────────────────────────────────────────

struct AccessoryInlineWidget: View {
    let data: WidgetSpendingData
    var body: some View {
        Label {
            Text("\(data.spentText) · \(data.percentText) used")
        } icon: {
            Image(systemName: "creditcard.fill")
        }
        .widgetAccentable()
    }
}

// MARK: - widgetBackground helper (iOS 17+ API shim)

extension View {
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            background(color)
        }
    }
}
