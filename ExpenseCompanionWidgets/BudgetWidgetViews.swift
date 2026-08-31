//
//  BudgetWidgetViews.swift
//  ExpenseCompanionWidgets
//
//  All widget view bodies:
//
//  HOME SCREEN
//    • Small  (2×2) — Progress ring + spent / limit
//    • Medium (4×2) — Ring + top categories list
//    • Large  (4×4) — Ring, weekly bar chart, category breakdown
//
//  LOCK SCREEN
//    • Accessory Circular   — Arc ring with % center
//    • Accessory Rectangular — Bar + spent text
//    • Accessory Inline     — Short text: "💳 ₹2.3k • 46%"
//

import SwiftUI
import WidgetKit

// MARK: - Design tokens (widget-safe, no UIKit)

private let wPink   = Color(red: 1.0,  green: 0.176, blue: 0.471)
private let wPurple = Color(red: 0.75, green: 0.149, blue: 0.827)
private let wBg     = Color(red: 0.051, green: 0.051, blue: 0.063)
private let wCard   = Color(red: 0.10,  green: 0.10,  blue: 0.13)
private var wGrad: LinearGradient {
    LinearGradient(colors: [wPink, wPurple], startPoint: .leading, endPoint: .trailing)
}

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

// MARK: ─── HOME SCREEN — SMALL ────────────────────────────────────────────

struct SmallBudgetWidget: View {
    let data: WidgetSpendingData

    var body: some View {
        ZStack {
            // Background
            wBg
            RadialGradient(colors: [wPink.opacity(0.22), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 160)

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(wPink)
                    Text("BUDGET")
                        .font(.system(size: 9, weight: .bold))
                        .kerning(0.8)
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }

                Spacer()

                // Ring
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: data.usedFraction)
                        .stroke(data.isOverBudget ? AnyShapeStyle(Color.red) : AnyShapeStyle(wGrad),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text(data.percentText)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("used")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .frame(width: 80, height: 80)
                .frame(maxWidth: .infinity)

                Spacer()

                // Amount
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(data.currencySymbol)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(data.fmt(data.todaySpent))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(data.isOverBudget ? .red : .white)
                    }
                    Text("of \(data.limitText)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.40))
                }
            }
            .padding(14)
        }
        .widgetBackground(wBg)
    }
}

// MARK: ─── HOME SCREEN — MEDIUM ──────────────────────────────────────────

struct MediumBudgetWidget: View {
    let data: WidgetSpendingData

    var body: some View {
        ZStack {
            wBg
            RadialGradient(colors: [wPurple.opacity(0.20), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 200)

            HStack(spacing: 16) {
                // Left — ring
                VStack(spacing: 6) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.08), lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: data.usedFraction)
                            .stroke(data.isOverBudget ? AnyShapeStyle(Color.red) : AnyShapeStyle(wGrad),
                                    style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text(data.percentText)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("used")
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .frame(width: 70, height: 70)

                    Text(data.spentText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(data.isOverBudget ? .red : .white)
                    Text("of \(data.limitText)")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.38))
                }

                // Divider
                Rectangle()
                    .fill(.white.opacity(0.07))
                    .frame(width: 1)

                // Right — categories or transactions
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("TODAY")
                            .font(.system(size: 9, weight: .bold))
                            .kerning(0.8)
                            .foregroundStyle(.white.opacity(0.35))
                        Spacer()
                        Text("\(data.transactionCount) txns")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(wPink.opacity(0.8))
                    }
                    .padding(.bottom, 6)

                    if data.categoryBreakdown.isEmpty {
                        Spacer()
                        Text("No expenses today")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.3))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        Spacer()
                    } else {
                        ForEach(data.categoryBreakdown.prefix(4)) { cat in
                            MediumCategoryRow(cat: cat, currencySymbol: data.currencySymbol)
                            if cat.id != data.categoryBreakdown.prefix(4).last?.id {
                                Divider().background(.white.opacity(0.05)).padding(.vertical, 3)
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
        .widgetBackground(wBg)
    }
}

private struct MediumCategoryRow: View {
    let cat: WidgetCategoryItem
    let currencySymbol: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: cat.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(cat.name.categoryWidgetColor)
                .frame(width: 18)
            Text(cat.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
            Spacer()
            Text(currencySymbol + String(format: cat.amount >= 1000 ? "%.1fk" : "%.0f",
                                         cat.amount >= 1000 ? cat.amount / 1000 : cat.amount))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.vertical, 2)
    }
}

// MARK: ─── HOME SCREEN — LARGE ───────────────────────────────────────────

struct LargeBudgetWidget: View {
    let data: WidgetSpendingData

    var body: some View {
        ZStack {
            wBg
            // Dual glow
            VStack {
                HStack {
                    RadialGradient(colors: [wPink.opacity(0.18), .clear],
                                   center: .center, startRadius: 0, endRadius: 120)
                        .frame(width: 160, height: 160)
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    RadialGradient(colors: [wPurple.opacity(0.18), .clear],
                                   center: .center, startRadius: 0, endRadius: 120)
                        .frame(width: 140, height: 140)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                // ── Header
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("EXPENSE COMPANION")
                            .font(.system(size: 9, weight: .bold))
                            .kerning(0.8)
                            .foregroundStyle(.white.opacity(0.30))
                        Text("Daily Budget")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text(Date.now, style: .date)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }

                // ── Ring + Stats
                HStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.08), lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: data.usedFraction)
                            .stroke(data.isOverBudget ? AnyShapeStyle(Color.red) : AnyShapeStyle(wGrad),
                                    style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text(data.percentText)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("used")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .frame(width: 80, height: 80)

                    VStack(alignment: .leading, spacing: 6) {
                        LargeStat(label: "Spent", value: data.spentText, color: data.isOverBudget ? .red : .white)
                        LargeStat(label: "Remaining", value: data.remainingText, color: wPink)
                        LargeStat(label: "Transactions", value: "\(data.transactionCount)", color: .white.opacity(0.7))
                    }
                }

                // ── Weekly Bar Chart
                VStack(alignment: .leading, spacing: 6) {
                    Text("THIS WEEK")
                        .font(.system(size: 9, weight: .bold))
                        .kerning(0.8)
                        .foregroundStyle(.white.opacity(0.30))

                    let labels = ["6d", "5d", "4d", "3d", "2d", "1d", "Now"]
                    let maxSpend = data.weeklySpending.max() ?? 1

                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(data.weeklySpending.enumerated()), id: \.offset) { idx, amount in
                            let fraction = maxSpend > 0 ? amount / maxSpend : 0
                            let isToday  = idx == 6
                            VStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(isToday
                                          ? AnyShapeStyle(wGrad)
                                          : AnyShapeStyle(.white.opacity(0.18)))
                                    .frame(height: max(CGFloat(fraction) * 50, 4))
                                Text(labels[idx])
                                    .font(.system(size: 8, weight: isToday ? .bold : .regular))
                                    .foregroundStyle(isToday ? wPink : .white.opacity(0.3))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                // ── Category breakdown
                VStack(alignment: .leading, spacing: 5) {
                    Text("TOP CATEGORIES")
                        .font(.system(size: 9, weight: .bold))
                        .kerning(0.8)
                        .foregroundStyle(.white.opacity(0.30))

                    if data.categoryBreakdown.isEmpty {
                        Text("No data")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.25))
                    } else {
                        ForEach(data.categoryBreakdown.prefix(3)) { cat in
                            LargeCategoryBar(cat: cat)
                        }
                    }
                }
            }
            .padding(16)
        }
        .widgetBackground(wBg)
    }
}

private struct LargeStat: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}

private struct LargeCategoryBar: View {
    let cat: WidgetCategoryItem
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: cat.symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(cat.name.categoryWidgetColor)
                .frame(width: 14)
            Text(cat.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.07)).frame(height: 4)
                    Capsule()
                        .fill(cat.name.categoryWidgetColor)
                        .frame(width: geo.size.width * cat.fraction, height: 4)
                }
            }
            .frame(height: 4)
            Text(String(format: "%.0f%%", cat.fraction * 100))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 28, alignment: .trailing)
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
                .tint(data.isOverBudget ? .red : wPink)
            Text(data.percentText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
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
                Text("BUDGET TODAY")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(0.5)
            }
            .foregroundStyle(.white.opacity(0.6))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(data.spentText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("/ \(data.limitText)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Gauge(value: data.usedFraction) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(data.isOverBudget ? .red : wPink)
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
