//
//  SalaryPlanView.swift
//  ExpenseCompanion
//
//  Where each salary goes: buckets come off the top, the rest is savings
//  for the Germany plan. Log each payday with the amount actually received.
//

import SwiftUI
import SwiftData

struct SalaryPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [StudyAbroadPlan]
    @Query(sort: \SalaryBucket.sortOrder) private var buckets: [SalaryBucket]
    @Query(sort: \PaydayEntry.date, order: .reverse) private var paydays: [PaydayEntry]

    @State private var editingBucket: SalaryBucket?
    @State private var showingAddBucket = false
    @State private var showingPayday = false

    var body: some View {
        ZStack {
            DynamicGradientBackground()
            if let plan = plans.first {
                content(plan: plan)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Salary")
        .hidesTabBar()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .onAppear {
            let repo = StudyPlanRepository(context: modelContext)
            if let plan = try? repo.fetchOrCreatePlan() { try? repo.ensureSalaryPlan(plan) }
        }
        .sheet(item: $editingBucket) { b in
            if let plan = plans.first { BucketEditorView(bucket: b, plan: plan) }
        }
        .sheet(isPresented: $showingAddBucket) {
            if let plan = plans.first { BucketEditorView(bucket: nil, plan: plan) }
        }
        .sheet(isPresented: $showingPayday) {
            if let plan = plans.first { PaydaySheet(plan: plan, buckets: buckets) }
        }
    }

    private func content(plan: StudyAbroadPlan) -> some View {
        @Bindable var plan = plan
        let total = SalaryMath.bucketsTotal(buckets)
        let savings = plan.expectedSalary - total

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Hero: what each salary saves
                HeroCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Saves every month")
                                    .font(.system(size: 15, weight: .medium))
                                Text("toward Germany, from a \(CurrencyFormatter.format(plan.expectedSalary)) salary")
                                    .font(.system(size: 12))
                                    .opacity(0.6)
                            }
                            Spacer()
                            Text("🇩🇪").font(.system(size: 22))
                        }
                        BigAmount(amount: savings, size: 52)
                            .accessibilityIdentifier("salary-monthly-savings")
                        if savings < 0 {
                            Text("Buckets are more than your salary.")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Button {
                            showingPayday = true
                        } label: {
                            Label("Log payday", systemImage: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.heroPink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(Color.onAccent))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("log-payday")
                    }
                }

                splitCard(plan: plan, total: total, savings: savings)
                historyCard(plan: plan)

                Text("Each payday, whatever is left after your buckets is added to \"Saved so far\" in the Germany plan. The daily spending bucket also sets your daily budget.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(16)
            .padding(.bottom, 110)
        }
        .onChange(of: plan.expectedSalary) { _, _ in
            try? StudyPlanRepository(context: modelContext).syncFromSalary(plan)
        }
    }

    // MARK: - Split

    private func splitCard(plan: StudyAbroadPlan, total: Double, savings: Double) -> some View {
        @Bindable var plan = plan
        let salary = max(plan.expectedSalary, 1)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Expected salary")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                HStack(spacing: 2) {
                    Text("₹").foregroundStyle(Color.textTertiary)
                    TextField("0", value: $plan.expectedSalary, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityIdentifier("field-expected-salary")
                }
                .font(.system(size: 17, weight: .regular))
                .monospacedDigit()
            }

            // Segmented bar: buckets in greys, savings in pink
            GeometryReader { geo in
                let spacing: CGFloat = 3
                let n = buckets.count + (savings > 0 ? 1 : 0)
                let usable = geo.size.width - spacing * CGFloat(max(n - 1, 0))
                HStack(spacing: spacing) {
                    ForEach(Array(buckets.enumerated()), id: \.element.id) { i, b in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.textPrimary.opacity(0.85 - Double(i) * 0.15))
                            .frame(width: max(usable * b.monthlyTotal / max(salary, total), 3))
                    }
                    if savings > 0 {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.heroPink)
                            .frame(width: max(usable * savings / salary, 3))
                    }
                }
            }
            .frame(height: 28)

            VStack(spacing: 0) {
                ForEach(Array(buckets.enumerated()), id: \.element.id) { i, b in
                    bucketRow(b, shade: 0.85 - Double(i) * 0.15)
                        .contentShape(Rectangle())
                        .onTapGesture { editingBucket = b }
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") { editingBucket = b }
                            if !b.isDailySpending {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    try? StudyPlanRepository(context: modelContext).deleteBucket(b, plan: plan)
                                }
                            }
                        }
                    Divider().overlay(Color.cardBorder)
                }

                HStack(spacing: 12) {
                    Circle().fill(Color.heroPink).frame(width: 10, height: 10).padding(.horizontal, 11)
                    Text("Germany savings")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(CurrencyFormatter.format(savings))
                        .font(.system(size: 15))
                        .monospacedDigit()
                        .foregroundStyle(savings >= 0 ? Color.heroPink : .red)
                }
                .padding(.vertical, 12)

                Button {
                    showingAddBucket = true
                } label: {
                    Label("Add bucket", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .glassCard()
    }

    private func bucketRow(_ b: SalaryBucket, shade: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: b.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary.opacity(max(shade, 0.35)))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.cardSurfaceRaised))
            VStack(alignment: .leading, spacing: 2) {
                Text(b.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                Text(b.isPerDay
                     ? "\(CurrencyFormatter.format(b.perDayAmount))/day × \(Int(SalaryBucket.daysPerMonth))\(b.isDailySpending ? " · daily budget" : "")"
                     : "per month")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Text(CurrencyFormatter.format(b.monthlyTotal))
                .font(.system(size: 15))
                .monospacedDigit()
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("bucket-\(b.name)")
    }

    // MARK: - History

    private func historyCard(plan: StudyAbroadPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Paydays")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                if !paydays.isEmpty {
                    Text("\(CurrencyFormatter.format(paydays.reduce(0) { $0 + $1.savedAmount })) saved")
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(Color.textTertiary)
                }
            }

            if paydays.isEmpty {
                Text("No paydays logged yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(paydays) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.date.formatted(.dateTime.day().month(.wide).year()))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Text("Received \(CurrencyFormatter.format(p.amount))\(p.note.isEmpty ? "" : " · \(p.note)")")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text((p.savedAmount >= 0 ? "+" : "") + CurrencyFormatter.format(p.savedAmount))
                            .font(.system(size: 15))
                            .monospacedDigit()
                            .foregroundStyle(p.savedAmount >= 0 ? Color.heroPink : .red)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("payday-row")
                    .contextMenu {
                        Button("Delete payday", systemImage: "trash", role: .destructive) {
                            try? StudyPlanRepository(context: modelContext).deletePayday(p, plan: plan)
                        }
                    }
                    if p.id != paydays.last?.id { Divider().overlay(Color.cardBorder) }
                }
            }
        }
        .glassCard()
    }
}

// MARK: - Payday sheet

struct PaydaySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let plan: StudyAbroadPlan
    let buckets: [SalaryBucket]

    @State private var amountText = ""
    @State private var date = Date.now
    @State private var note = ""

    private var amount: Double { Double(amountText) ?? 0 }
    private var bucketsTotal: Double { SalaryMath.bucketsTotal(buckets) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Salary received") {
                    HStack {
                        Text("₹")
                        TextField("Amount", text: $amountText)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("payday-amount")
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note (e.g. includes variable pay)", text: $note)
                }
                Section("Split") {
                    ForEach(buckets) { b in
                        HStack {
                            Text(b.name)
                            Spacer()
                            Text(CurrencyFormatter.format(b.monthlyTotal)).monospacedDigit()
                        }
                        .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("To Germany savings").fontWeight(.semibold)
                        Spacer()
                        Text(CurrencyFormatter.format(amount - bucketsTotal))
                            .monospacedDigit()
                            .fontWeight(.semibold)
                            .foregroundStyle(amount - bucketsTotal >= 0 ? Color.heroPink : .red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Log payday")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        try? StudyPlanRepository(context: modelContext)
                            .logPayday(amount: amount, date: date, note: note.trimmingCharacters(in: .whitespaces), plan: plan)
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
            .onAppear { amountText = String(Int(plan.expectedSalary)) }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.appBackground)
    }
}

// MARK: - Bucket editor

struct BucketEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let bucket: SalaryBucket?
    let plan: StudyAbroadPlan

    @State private var name = ""
    @State private var perDay = false
    @State private var amountText = ""
    @State private var symbol = "tag.fill"

    private let symbols = ["tag.fill", "house.fill", "wifi", "fuelpump.fill", "fork.knife", "cart.fill",
                           "bus.fill", "bolt.fill", "dumbbell.fill", "heart.fill", "gift.fill", "creditcard.fill"]

    private var amount: Double { Double(amountText) ?? 0 }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Gym)", text: $name)
                    if !(bucket?.isDailySpending ?? false) {
                        Picker("Amount is", selection: $perDay) {
                            Text("Per month").tag(false)
                            Text("Per day").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                    HStack {
                        Text("₹")
                        TextField(perDay ? "Per day" : "Per month", text: $amountText)
                            .keyboardType(.numberPad)
                        if perDay {
                            Text("× \(Int(SalaryBucket.daysPerMonth)) = \(CurrencyFormatter.format(amount * SalaryBucket.daysPerMonth))")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text("Bucket")
                } footer: {
                    if bucket?.isDailySpending == true {
                        Text("This amount is also your daily budget.")
                    }
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(symbols, id: \.self) { s in
                            Image(systemName: s)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(symbol == s ? Color.onAccent : Color.textSecondary)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(symbol == s ? Color.heroPink : Color.cardSurfaceRaised))
                                .onTapGesture { symbol = s }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(bucket == nil ? "New bucket" : "Edit bucket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!isValid)
                }
            }
            .onAppear {
                guard let b = bucket else { return }
                name = b.name
                perDay = b.isPerDay
                amountText = String(Int(b.isPerDay ? b.perDayAmount : b.monthlyAmount))
                symbol = b.symbolName
            }
        }
        .presentationBackground(Color.appBackground)
    }

    private func save() {
        let repo = StudyPlanRepository(context: modelContext)
        let target = bucket ?? SalaryBucket(name: "", symbolName: symbol)
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.symbolName = symbol
        target.perDayAmount = perDay ? amount : 0
        target.monthlyAmount = perDay ? 0 : amount
        if bucket == nil {
            try? repo.addBucket(target, plan: plan)
        } else {
            try? repo.syncFromSalary(plan)
        }
        Haptics.success()
        dismiss()
    }
}
