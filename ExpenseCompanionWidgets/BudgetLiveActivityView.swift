//
//  BudgetLiveActivityView.swift
//  ExpenseCompanionWidgets
//
//  Live Activity: Dynamic Island + Lock Screen banner.
//  No GeometryReader anywhere (it clipped in the expanded island); gauges
//  are built from fixed-size ticks instead.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct BudgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BudgetActivityAttributes.self) { context in
            BudgetBannerView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(W.bg)
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
                    .font(.system(size: 13, weight: .medium))
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

private let islandPink    = W.pink
private let islandRed     = W.red
private let textPrimary   = W.text1
private let textSecondary = W.text2
private let textTertiary  = W.text3

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
            Text("Today")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(textPrimary)
        }
    }
}

// MARK: - Expanded Trailing

private struct BudgetExpandedTrailing: View {
    let state: BudgetActivityAttributes.BudgetState
    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("\(Int(state.usedFraction * 100))%")
                .font(.system(size: 17, weight: .regular))
                .monospacedDigit()
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
                    Text("Spent")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(textTertiary)
                    WAmount(symbol: attributes.currencySymbol,
                            value: W.grouped(state.spent, currencyCode: state.currencyCode),
                            size: 30)
                        .foregroundStyle(state.isOverBudget ? islandRed : textPrimary)
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 8)

                // Remaining / Limit
                VStack(alignment: .trailing, spacing: 1) {
                    Text(state.isOverBudget ? "Over" : "Left")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(textTertiary)
                    Text(attributes.currencySymbol + fmt(state.isOverBudget ? state.spent - state.limit : state.remaining))
                        .font(.system(size: 17, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(state.isOverBudget ? islandRed : islandPink)
                        .contentTransition(.numericText())
                }
            }

            // Tick gauge (fixed-size ticks, no GeometryReader)
            WTickGauge(progress: state.usedFraction, ticks: 30, height: 16,
                       marker: state.isOverBudget ? islandRed : islandPink)

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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spent today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(textSecondary)
                    WAmount(symbol: attributes.currencySymbol,
                            value: W.grouped(state.spent, currencyCode: state.currencyCode),
                            size: 34)
                        .foregroundStyle(state.isOverBudget ? islandRed : textPrimary)
                        .contentTransition(.numericText())
                }
                Spacer()
                WRing(progress: state.usedFraction, tint: state.isOverBudget ? islandRed : islandPink, size: 42)
            }

            WTickGauge(progress: state.usedFraction, ticks: 40, height: 16,
                       marker: state.isOverBudget ? islandRed : islandPink)

            HStack {
                Text(state.isOverBudget
                     ? "\(attributes.currencySymbol)\(bannerFmt(state.spent - state.limit)) over"
                     : "\(attributes.currencySymbol)\(bannerFmt(state.remaining)) left")
                Spacer()
                Text("of \(attributes.currencySymbol)\(bannerFmt(state.limit))")
            }
            .font(.system(size: 11))
            .monospacedDigit()
            .foregroundStyle(textTertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func bannerFmt(_ v: Double) -> String {
        v >= 1_00_000 ? String(format: "%.1fL", v / 1_00_000)
        : v >= 1_000  ? String(format: "%.1fk", v / 1_000)
        : String(format: "%.0f", v)
    }
}
