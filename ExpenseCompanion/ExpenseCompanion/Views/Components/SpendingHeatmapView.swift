//
//  SpendingHeatmapView.swift
//  ExpenseCompanion
//
//  Month-wise spending calendar. Full mode shows the complete calendar month
//  (like a real calendar) with dot indicators per day. Compact mode shows
//  just the current week's 7 dots for the Dashboard card.
//

import SwiftUI

// MARK: - Helpers

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
    func daysInMonth(for date: Date) -> Int {
        range(of: .day, in: .month, for: date)?.count ?? 30
    }
}

// MARK: - Main View

struct SpendingHeatmapView: View {
    let expenses: [Expense]
    var compact: Bool = false

    @State private var monthOffset: Int = 0      // 0 = current month, -1 = last month…
    @State private var selectedDate: Date? = nil

    private let calendar = Calendar.current

    // MARK: - Month being displayed

    private var displayMonth: Date {
        let now = calendar.startOfMonth(for: .now)
        return calendar.date(byAdding: .month, value: monthOffset, to: now) ?? now
    }

    // MARK: - Day-total map

    private var dailyTotals: [Date: Double] {
        var map: [Date: Double] = [:]
        for e in expenses {
            let day = calendar.startOfDay(for: e.date)
            map[day, default: 0] += e.amount
        }
        return map
    }

    private var maxDayAmount: Double {
        dailyTotals.values.max() ?? 1
    }

    // MARK: - Calendar grid  [[Date?]]

    private var weeks: [[Date?]] {
        let firstDay = displayMonth
        let firstWeekday = calendar.firstWeekday              // 1=Sun or 2=Mon per locale
        let weekdayOfFirst = calendar.component(.weekday, from: firstDay)
        let leadingBlanks = (weekdayOfFirst - firstWeekday + 7) % 7
        let days = calendar.daysInMonth(for: firstDay)

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for d in 0..<days {
            cells.append(calendar.date(byAdding: .day, value: d, to: firstDay))
        }
        while cells.count % 7 != 0 { cells.append(nil) }

        var result: [[Date?]] = []
        var i = 0
        while i < cells.count {
            result.append(Array(cells[i..<i+7]))
            i += 7
        }
        return result
    }

    // Locale-ordered single-letter weekday labels
    private var weekdayLabels: [String] {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEEE"
        let first = calendar.firstWeekday
        return (0..<7).map { offset -> String in
            let wd = (first - 1 + offset) % 7 + 1
            var comps = DateComponents(); comps.weekday = wd
            let date = calendar.nextDate(after: .distantPast, matching: comps, matchingPolicy: .nextTime) ?? .now
            return fmt.string(from: date)
        }
    }

    private var monthLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = monthOffset == 0 ? "MMMM yyyy" : "MMM yyyy"
        return fmt.string(from: displayMonth)
    }

    // MARK: - Body

    var body: some View {
        if compact {
            compactWeekView
        } else {
            fullMonthView
        }
    }

    // MARK: - Full Month Calendar

    private var fullMonthView: some View {
        VStack(spacing: 12) {
            // Header: month name + nav arrows
            HStack {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        monthOffset -= 1
                        selectedDate = nil
                    }
                    Haptics.light()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }

                Spacer()

                Text(monthLabel.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Button {
                    guard monthOffset < 0 else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        monthOffset += 1
                        selectedDate = nil
                    }
                    Haptics.light()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(monthOffset < 0 ? Color.textSecondary : Color.textTertiary.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(monthOffset < 0 ? 0.06 : 0.02)))
                }
                .disabled(monthOffset >= 0)
            }

            // Weekday header row
            HStack(spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            VStack(spacing: 6) {
                ForEach(0..<weeks.count, id: \.self) { weekIdx in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { dayIdx in
                            let date = weekIdx < weeks.count && dayIdx < weeks[weekIdx].count ? weeks[weekIdx][dayIdx] : nil
                            CalendarDayCell(
                                date: date,
                                amount: date.flatMap { dailyTotals[$0] } ?? 0,
                                maxAmount: maxDayAmount,
                                isToday: date.map { calendar.isDateInToday($0) } ?? false,
                                isSelected: date.map { calendar.isDate($0, inSameDayAs: selectedDate ?? .distantPast) } ?? false,
                                isFuture: date.map { $0 > calendar.startOfDay(for: .now) } ?? false
                            )
                            .onTapGesture {
                                guard let d = date, !d.after(.now) else { return }
                                let total = dailyTotals[d] ?? 0
                                guard total > 0 else { return }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedDate = (selectedDate.map { calendar.isDate($0, inSameDayAs: d) } == true) ? nil : d
                                }
                                Haptics.light()
                            }
                        }
                    }
                }
            }

            // Selected day tooltip
            if let date = selectedDate, let amount = dailyTotals[date] {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.heroPink)
                    Text(date.formatted(.dateTime.day().month(.wide)))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(CurrencyFormatter.format(amount))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.heroPink)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.heroPink.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.heroPink.opacity(0.25), lineWidth: 1))
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
    }

    // MARK: - Compact week strip (Dashboard)

    private var compactWeekView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { offset in
                    let date = calendar.date(byAdding: .day, value: offset - 6, to: calendar.startOfDay(for: .now))
                    let amount = date.flatMap { dailyTotals[$0] } ?? 0
                    let isToday = offset == 6

                    VStack(spacing: 4) {
                        // Dot
                        Circle()
                            .fill(amount > 0
                                  ? AnyShapeStyle(LinearGradient(colors: [.heroPink, .heroPurple], startPoint: .top, endPoint: .bottom))
                                  : AnyShapeStyle(Color.white.opacity(0.12)))
                            .frame(width: 10, height: 10)
                            .shadow(color: amount > 0 ? Color.heroPink.opacity(0.5) : .clear, radius: 4, x: 0, y: 0)
                        // Day label
                        if let d = date {
                            Text(d.formatted(.dateTime.day()))
                                .font(.system(size: 9, weight: isToday ? .bold : .regular))
                                .foregroundStyle(isToday ? Color.heroPink : Color.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Calendar Day Cell

private struct CalendarDayCell: View {
    let date: Date?
    let amount: Double
    let maxAmount: Double
    let isToday: Bool
    let isSelected: Bool
    let isFuture: Bool

    private var fillFraction: Double {
        guard amount > 0, maxAmount > 0 else { return 0 }
        return min(amount / maxAmount, 1.0)
    }

    private var dotSize: CGFloat {
        amount > 0 ? CGFloat(5 + fillFraction * 4) : 5
    }

    var body: some View {
        VStack(spacing: 3) {
            // Day number
            if let date {
                let day = Calendar.current.component(.day, from: date)
                ZStack {
                    if isToday {
                        Circle().fill(Color.heroPink.opacity(0.18))
                    } else if isSelected {
                        Circle().fill(Color.white.opacity(0.10))
                    }
                    Text("\(day)")
                        .font(.system(size: 11, weight: isToday ? .bold : (isSelected ? .semibold : .regular)))
                        .foregroundStyle(isToday ? Color.heroPink : (isFuture ? Color.textTertiary.opacity(0.4) : Color.textSecondary))
                }
                .frame(width: 24, height: 18)
            } else {
                Color.clear.frame(height: 18)
            }

            // Dot indicator
            if date != nil {
                ZStack {
                    if amount > 0 && !isFuture {
                        Circle()
                            .fill(isSelected ? Color.heroPink : Color.heroPink.opacity(0.6))
                            .frame(width: dotSize, height: dotSize)
                            .shadow(color: Color.heroPink.opacity(isSelected ? 0.7 : 0.35), radius: isSelected ? 5 : 3, x: 0, y: 0)
                    } else {
                        Circle()
                            .fill(isFuture ? Color.white.opacity(0.04) : Color.white.opacity(0.10))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

private extension Date {
    func after(_ other: Date) -> Bool { self > other }
}
