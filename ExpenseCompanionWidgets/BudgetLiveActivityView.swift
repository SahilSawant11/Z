//
//  BudgetLiveActivityView.swift
//  ExpenseCompanionWidgets
//
//  Dark fintech Live Activity for the Dynamic Island + Lock Screen.
//
//  Dynamic Island layouts:
//    • compactLeading  — card icon (pink)
//    • compactTrailing — spent amount (white, monospaced)
//    • minimal         — arc ring showing % used
//    • expanded        — full card: header, big amount, progress bar, stats row
//
//  Lock Screen / StandBy:
//    • Full width banner with the same dark fintech card design
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct BudgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BudgetActivityAttributes.self) { context in
            // Lock Screen / StandBy / Notification banner
            BudgetBannerView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color(red: 0.051, green: 0.051, blue: 0.063))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (long-press)
                DynamicIslandExpandedRegion(.leading) {
                    BudgetExpandedLeading(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BudgetExpandedTrailing(attributes: context.attributes, state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    // spacing
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BudgetExpandedBottom(attributes: context.attributes, state: context.state)
                }
            } compactLeading: {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(islandPink)
            } compactTrailing: {
                Text(context.state.compactText(symbol: context.attributes.currencySymbol))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(context.state.isOverBudget ? islandRed : .white)
                    .contentTransition(.numericText())
            } minimal: {
                BudgetMinimalRing(fraction: context.state.usedFraction,
                                  isOver: context.state.isOverBudget)
            }
            .keylineTint(islandPink)
            .contentMargins(.horizontal, 14, for: .expanded)
            .contentMargins(.top, 10, for: .expanded)
            .contentMargins(.bottom, 12, for: .expanded)
        }
    }
}

// MARK: - Color tokens (widget can't import GlassComponents)

private let islandPink   = Color(red: 1.0,   green: 0.176, blue: 0.471)
private let islandPurple = Color(red: 0.753, green: 0.149, blue: 0.827)
private let islandRed    = Color(red: 1.0,   green: 0.25,  blue: 0.25)
private let islandBg     = Color(red: 0.051, green: 0.051, blue: 0.063)
private let islandCard   = Color(red: 0.10,  green: 0.10,  blue: 0.13)
private let textPrimary  = Color.white
private let textSecondary = Color.white.opacity(0.45)
private let textTertiary  = Color.white.opacity(0.28)

private var pinkPurple: LinearGradient {
    LinearGradient(colors: [islandPink, islandPurple], startPoint: .leading, endPoint: .trailing)
}

// MARK: - Minimal Ring

private struct BudgetMinimalRing: View {
    let fraction: Double
    let isOver: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(isOver ? islandRed : islandPink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 20, height: 20)
    }
}

// MARK: - Compact Expanded — Leading

private struct BudgetExpandedLeading: View {
    let state: BudgetActivityAttributes.BudgetState

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(islandPink)
            VStack(alignment: .leading, spacing: 1) {
                Text("BUDGET")
                    .font(.system(size: 8, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(textTertiary)
                Text("Today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(textPrimary)
            }
        }
    }
}

// MARK: - Compact Expanded — Trailing

private struct BudgetExpandedTrailing: View {
    let attributes: BudgetActivityAttributes
    let state: BudgetActivityAttributes.BudgetState

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("\(Int(state.usedFraction * 100))%")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(state.isOverBudget ? islandRed : textPrimary)
                .contentTransition(.numericText())
            Text("used")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(textTertiary)
        }
    }
}

// MARK: - Expanded Bottom

private struct BudgetExpandedBottom: View {
    let attributes: BudgetActivityAttributes
    let state: BudgetActivityAttributes.BudgetState

    var body: some View {
        VStack(spacing: 10) {
            // Big amount row
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(attributes.currencySymbol)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary)
                Text(formatAmount(state.spent))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(state.isOverBudget ? islandRed : textPrimary)
                    .contentTransition(.numericText())
                Text(" / \(attributes.currencySymbol)\(formatAmount(state.limit))")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary)
                Spacer()
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(state.isOverBudget
                              ? AnyShapeStyle(islandRed)
                              : AnyShapeStyle(pinkPurple))
                        .frame(width: max(geo.size.width * state.usedFraction, 8), height: 6)
                }
            }
            .frame(height: 6)

            // Stats row
            HStack {
                Label("\(state.transactionCount) txns", systemImage: "arrow.up.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(textSecondary)
                Spacer()
                Text(attributes.currencySymbol + formatAmount(state.remaining) + " left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(state.isOverBudget ? islandRed : islandPink)
                Circle()
                    .fill(textTertiary)
                    .frame(width: 2, height: 2)
                Text(state.relativeTime)
                    .font(.system(size: 10))
                    .foregroundStyle(textTertiary)
            }
        }
    }

    private func formatAmount(_ value: Double) -> String {
        if value >= 1_00_000 {
            return String(format: "%.1fL", value / 1_00_000)
        } else if value >= 1_000 {
            return String(format: "%.1fk", value / 1_000)
        }
        return String(format: "%.0f", value)
    }
}

// MARK: - Lock Screen / Banner

private struct BudgetBannerView: View {
    let attributes: BudgetActivityAttributes
    let state: BudgetActivityAttributes.BudgetState

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(islandPink.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(islandPink)
            }

            // Text info
            VStack(alignment: .leading, spacing: 3) {
                Text("Daily Budget")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.5)
                    .foregroundStyle(textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(attributes.currencySymbol + formatAmount(state.spent))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(state.isOverBudget ? islandRed : textPrimary)
                        .contentTransition(.numericText())
                    Text("/ \(attributes.currencySymbol + formatAmount(state.limit))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary)
                }
            }

            Spacer()

            // Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: state.usedFraction)
                    .stroke(state.isOverBudget ? islandRed : islandPink,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(state.usedFraction * 100))%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(textPrimary)
            }
            .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func formatAmount(_ value: Double) -> String {
        if value >= 1_00_000 { return String(format: "%.1fL", value / 1_00_000) }
        if value >= 1_000    { return String(format: "%.1fk", value / 1_000) }
        return String(format: "%.0f", value)
    }
}
