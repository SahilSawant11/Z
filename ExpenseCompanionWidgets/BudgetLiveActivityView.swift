//
//  BudgetLiveActivityView.swift
//  ExpenseCompanionWidgets
//
//  Dark fintech Live Activity — Dynamic Island + Lock Screen.
//  Fixed: expanded bottom uses scaleEffect (no GeometryReader), smaller
//  fonts and tighter margins so nothing gets cropped.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct BudgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BudgetActivityAttributes.self) { context in
            BudgetBannerView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color(red: 0.051, green: 0.051, blue: 0.063))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BudgetExpandedLeading(state: context.state)
                        .padding(.leading, 16)
                        .padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BudgetExpandedTrailing(state: context.state)
                        .padding(.trailing, 16)
                        .padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BudgetExpandedBottom(attributes: context.attributes, state: context.state)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 14)
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
        }
    }
}

// MARK: - Color tokens

private let islandPink   = Color(red: 1.0,   green: 0.176, blue: 0.471)
private let islandPurple = Color(red: 0.753, green: 0.149, blue: 0.827)
private let islandRed    = Color(red: 1.0,   green: 0.25,  blue: 0.25)
private let textPrimary   = Color.white
private let textSecondary = Color.white.opacity(0.45)
private let textTertiary  = Color.white.opacity(0.28)

private var pinkPurpleGrad: LinearGradient {
    LinearGradient(colors: [islandPink, islandPurple], startPoint: .leading, endPoint: .trailing)
}

// MARK: - Minimal Ring

private struct BudgetMinimalRing: View {
    let fraction: Double
    let isOver: Bool
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(isOver ? islandRed : islandPink,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 20, height: 20)
    }
}

// MARK: - Expanded Leading

private struct BudgetExpandedLeading: View {
    let state: BudgetActivityAttributes.BudgetState
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(islandPink)
            VStack(alignment: .leading, spacing: 1) {
                Text("BUDGET")
                    .font(.system(size: 8, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(textTertiary)
                Text("Today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(textPrimary)
            }
        }
    }
}

// MARK: - Expanded Trailing

private struct BudgetExpandedTrailing: View {
    let state: BudgetActivityAttributes.BudgetState
    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("\(Int(state.usedFraction * 100))%")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(state.isOverBudget ? islandRed : textPrimary)
                .contentTransition(.numericText())
            Text("used")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(textTertiary)
        }
    }
}

// MARK: - Expanded Bottom (fixed — no GeometryReader, scaleEffect for bar)

private struct BudgetExpandedBottom: View {
    let attributes: BudgetActivityAttributes
    let state: BudgetActivityAttributes.BudgetState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Two-column amounts
            HStack(alignment: .bottom, spacing: 0) {
                // Spent
                VStack(alignment: .leading, spacing: 1) {
                    Text("SPENT")
                        .font(.system(size: 8, weight: .semibold))
                        .kerning(0.8)
                        .foregroundStyle(textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(attributes.currencySymbol)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(textSecondary)
                        Text(fmt(state.spent))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(state.isOverBudget ? islandRed : textPrimary)
                            .contentTransition(.numericText())
                    }
                }

                Spacer(minLength: 8)

                // Remaining / Limit
                VStack(alignment: .trailing, spacing: 1) {
                    Text(state.isOverBudget ? "OVER" : "LEFT")
                        .font(.system(size: 8, weight: .semibold))
                        .kerning(0.8)
                        .foregroundStyle(textTertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(attributes.currencySymbol)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(textSecondary)
                        Text(fmt(state.isOverBudget ? state.spent - state.limit : state.remaining))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(state.isOverBudget ? islandRed : islandPink)
                            .contentTransition(.numericText())
                    }
                }
            }

            // Progress bar — scaleEffect avoids GeometryReader which caused clipping
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.09))
                    .frame(height: 5)
                Capsule()
                    .fill(state.isOverBudget
                          ? AnyShapeStyle(islandRed)
                          : AnyShapeStyle(pinkPurpleGrad))
                    .frame(height: 5)
                    .scaleEffect(x: max(state.usedFraction, 0.02), y: 1, anchor: .leading)
            }

            // Footer row
            HStack(spacing: 0) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundStyle(textSecondary)
                Text(" \(state.transactionCount) transactions")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(textSecondary)
                Spacer()
                Text(state.relativeTime)
                    .font(.system(size: 10))
                    .foregroundStyle(textTertiary)
            }
        }
    }

    private func fmt(_ v: Double) -> String {
        v >= 1_00_000 ? String(format: "%.1fL", v / 1_00_000)
        : v >= 1_000  ? String(format: "%.1fk", v / 1_000)
        : String(format: "%.0f", v)
    }
}

// MARK: - Lock Screen / StandBy Banner

private struct BudgetBannerView: View {
    let attributes: BudgetActivityAttributes
    let state: BudgetActivityAttributes.BudgetState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(islandPink.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(islandPink)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Daily Budget")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(attributes.currencySymbol + bannerFmt(state.spent))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(state.isOverBudget ? islandRed : textPrimary)
                        .contentTransition(.numericText())
                    Text("/ " + attributes.currencySymbol + bannerFmt(state.limit))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary)
                }
            }

            Spacer()

            ZStack {
                Circle().stroke(Color.white.opacity(0.10), lineWidth: 4)
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

    private func bannerFmt(_ v: Double) -> String {
        v >= 1_00_000 ? String(format: "%.1fL", v / 1_00_000)
        : v >= 1_000  ? String(format: "%.1fk", v / 1_000)
        : String(format: "%.0f", v)
    }
}
