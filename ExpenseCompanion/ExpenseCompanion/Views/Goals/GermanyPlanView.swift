//
//  GermanyPlanView.swift
//  ExpenseCompanion
//
//  Germany MS plan: savings vs. dated pre-departure costs, plus the loan / EMI picture.
//

import SwiftUI
import SwiftData

struct GermanyPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [StudyAbroadPlan]
    @Query(sort: \PlanMilestone.dueDate) private var milestones: [PlanMilestone]
    @Query(sort: \UniversityApplication.deadline) private var applications: [UniversityApplication]

    @State private var editing: PlanMilestone?
    @State private var showingAdd = false
    @State private var showingLoanInputs = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if let plan = plans.first {
                content(plan: plan)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Germany MS")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .onDisappear {
            Task { await DeadlineReminderScheduler.reschedule(context: modelContext) }
        }
        .onAppear(perform: seedIfNeeded)
        .sheet(item: $editing) { m in
            if let plan = plans.first { MilestoneEditorView(milestone: m, plan: plan) }
        }
        .sheet(isPresented: $showingAdd) {
            if let plan = plans.first { MilestoneEditorView(milestone: nil, plan: plan) }
        }
    }

    private func seedIfNeeded() {
        _ = try? StudyPlanRepository(context: modelContext).fetchOrCreatePlan()
    }

    // MARK: - Content

    private func content(plan: StudyAbroadPlan) -> some View {
        let projections = PlanProjector.project(plan: plan, milestones: milestones)
        let byID = Dictionary(uniqueKeysWithValues: projections.map { ($0.id, $0) })

        return ScrollView {
            VStack(spacing: 14) {
                hero(plan: plan, projections: projections)
                savingsCard(plan: plan)
                NavigationLink { UniversityTrackerView() } label: { universitiesCard }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("universities-card")

                GlassSectionHeader(title: "Cost timeline", systemImage: "calendar")
                    .padding(.top, 6)
                VStack(spacing: 10) {
                    ForEach(milestones) { m in
                        MilestoneRow(milestone: m, projection: byID[m.id])
                            .contentShape(Rectangle())
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("cost-\(m.title)")
                            .onTapGesture { editing = m }
                            .contextMenu {
                                Button(m.isPaid ? "Mark unpaid" : "Mark paid",
                                       systemImage: m.isPaid ? "arrow.uturn.backward" : "checkmark.circle") {
                                    togglePaid(m, plan: plan)
                                }
                                Button("Edit", systemImage: "pencil") { editing = m }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    try? StudyPlanRepository(context: modelContext).delete(m, plan: plan)
                                }
                            }
                    }
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add cost", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.heroPink)
                            .frame(maxWidth: .infinity)
                    }
                    .glassCard(padding: 14)
                }
                Text("Tap a cost to edit it. Long-press to mark it paid; paying deducts from savings.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GlassSectionHeader(title: "Loan · after admission", systemImage: "building.columns")
                    .padding(.top, 6)
                loanCard(plan: plan)
            }
            .padding(16)
            .padding(.bottom, 110)
        }
    }

    private func togglePaid(_ m: PlanMilestone, plan: StudyAbroadPlan) {
        try? StudyPlanRepository(context: modelContext).setPaid(!m.isPaid, m, plan: plan)
        Haptics.success()
    }

    // MARK: - Hero

    private func hero(plan: StudyAbroadPlan, projections: [MilestoneProjection]) -> some View {
        let unpaidTotal = milestones.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
        let paidTotal = milestones.filter(\.isPaid).reduce(0) { $0 + $1.amount }
        let grandTotal = unpaidTotal + paidTotal
        let funded = paidTotal + max(min(plan.currentSavings, unpaidTotal), 0)
        let progress = grandTotal > 0 ? funded / grandTotal : 0
        let firstShort = projections.first { !$0.isCovered }
        let monthsToIntake = Int(PlanProjector.months(from: .now, to: plan.intakeDate))

        return HeroCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("🇩🇪  \(plan.title)")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        DotMatrixText(text: "\(monthsToIntake)", dot: 4, gap: 2, color: .onAccent)
                        Text("months to WS \(plan.intakeDate.formatted(.dateTime.year()))")
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.6)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    BigAmount(amount: funded, size: 44)
                    Text("funded of \(CurrencyFormatter.format(grandTotal)) pre-departure")
                        .font(.system(size: 12))
                        .opacity(0.8)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.onAccent.opacity(0.15))
                        Capsule().fill(Color.onAccent)
                            .frame(width: geo.size.width * min(max(progress, 0), 1))
                    }
                }
                .frame(height: 8)

                HStack(spacing: 6) {
                    Image(systemName: firstShort == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    if let s = firstShort {
                        Text("Short \(CurrencyFormatter.format(s.shortfall.rounded())) for \(s.milestone.title) on \(s.milestone.dueDate.formatted(.dateTime.day().month(.abbreviated)))")
                    } else if unpaidTotal == 0 {
                        Text("All pre-departure costs paid")
                    } else {
                        Text("On track: every cost covered by its due date")
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.onAccent.opacity(0.1)))
            }
        }
    }

    // MARK: - Universities

    private var universitiesCard: some View {
        let open = applications.filter { $0.status.isOpen && $0.daysToDeadline >= 0 }
        let next = open.min { $0.deadline < $1.deadline }
        let admits = applications.filter { $0.status == .admitted }.count
        let subtitle: String = {
            if applications.isEmpty { return "Add your shortlist to track deadlines and documents" }
            var parts = ["\(applications.count) programs"]
            if admits > 0 { parts.append("\(admits) admit\(admits == 1 ? "" : "s")") }
            if let next { parts.append("next: \(next.university), \(next.deadline.formatted(.dateTime.day().month(.abbreviated)))") }
            return parts.joined(separator: " · ")
        }()

        return HStack(spacing: 14) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentBlue)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.accentBlue.opacity(0.15)))
            VStack(alignment: .leading, spacing: 3) {
                Text("Universities")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
        }
        .glassCard(padding: 14)
    }

    // MARK: - Savings

    private func savingsCard(plan: StudyAbroadPlan) -> some View {
        @Bindable var plan = plan
        let fundedBy = PlanProjector.fullyFundedDate(plan: plan, milestones: milestones)

        return VStack(spacing: 12) {
            NumberRow(label: "Saved so far", value: $plan.currentSavings, prefix: "₹")
            Divider().overlay(Color.cardBorder)
            NumberRow(label: "Saving per month", value: $plan.monthlySavings, prefix: "₹")
            Divider().overlay(Color.cardBorder)
            HStack {
                Text("Everything funded by")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text(fundedBy.map { $0.formatted(.dateTime.day().month(.abbreviated).year()) } ?? "Never at ₹0/mo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .glassCard()
    }

    // MARK: - Loan

    private func loanCard(plan: StudyAbroadPlan) -> some View {
        @Bindable var plan = plan
        let overCap = plan.loanNeedINR > plan.loanCap
        let share = plan.emiShareOfIncome
        let shareColor: Color = share > 0.5 ? .red : share > 0.35 ? .orange : .green

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Needed")
                        .font(.system(size: 11)).foregroundStyle(Color.textTertiary)
                    BigAmount(amount: plan.loanNeedINR.rounded(), size: 34)
                        .foregroundStyle(Color.textPrimary)
                    Text(CurrencyFormatter.format(plan.loanNeedEUR.rounded(), currencyCode: "EUR") + " at ₹\(plan.eurToInr.formatted())/€")
                        .font(.system(size: 11)).foregroundStyle(Color.textSecondary)
                }
                Spacer()
                PillBadge(title: overCap ? "Over ₹\(Int(plan.loanCap / 100_000))L cap" : "Within ₹\(Int(plan.loanCap / 100_000))L cap")
                    .overlay(Capsule().strokeBorder(overCap ? Color.red : Color.green, lineWidth: 1))
            }

            Divider().overlay(Color.cardBorder)

            stat("EMI", CurrencyFormatter.format(plan.emi.rounded()) + "/mo",
                 detail: "\(plan.loanTenureMonths / 12) yr at \(plan.loanInterestRate.formatted())% after \(plan.moratoriumMonths) mo moratorium")
            stat("Principal when EMIs start", CurrencyFormatter.format(plan.principalAtRepayment.rounded()),
                 detail: "Interest accrues during moratorium")
            stat("Total repaid", CurrencyFormatter.format(plan.totalRepayment.rounded()), detail: nil)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("EMI vs \(CurrencyFormatter.format(plan.repaymentIncome))/mo income")
                        .font(.system(size: 12)).foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text("\(Int((share * 100).rounded()))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(shareColor)
                }
                TickGauge(progress: share, marker: shareColor, height: 28)
            }

            DisclosureGroup(isExpanded: $showingLoanInputs) {
                VStack(spacing: 10) {
                    NumberRow(label: "Blocked account", value: $plan.blockedAccountEUR, prefix: "€")
                    NumberRow(label: "Rent deposit", value: $plan.rentDepositEUR, prefix: "€")
                    NumberRow(label: "First-month cushion", value: $plan.firstMonthCushionEUR, prefix: "€")
                    NumberRow(label: "Setup & buffer", value: $plan.setupBufferEUR, prefix: "€")
                    NumberRow(label: "€ → ₹ rate", value: $plan.eurToInr, prefix: "₹")
                    Divider().overlay(Color.cardBorder)
                    NumberRow(label: "Loan cap", value: $plan.loanCap, prefix: "₹")
                    NumberRow(label: "Interest rate", value: $plan.loanInterestRate, prefix: "%")
                    Stepper("Moratorium: \(plan.moratoriumMonths) mo", value: $plan.moratoriumMonths, in: 0...60, step: 3)
                    Stepper("Tenure: \(plan.loanTenureMonths / 12) yr", value: $plan.loanTenureMonths, in: 12...180, step: 12)
                    NumberRow(label: "Repayment income", value: $plan.repaymentIncome, prefix: "₹")
                    Text("The blocked-account amount is revised every year. Check the current figure before you fix the loan amount.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.textPrimary)
                .padding(.top, 10)
            } label: {
                Text("Assumptions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }
            .tint(Color.heroPink)
        }
        .glassCard()
    }

    private func stat(_ title: String, _ value: String, detail: String?) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                if let detail {
                    Text(detail).font(.system(size: 10)).foregroundStyle(Color.textTertiary)
                }
            }
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.textPrimary)
                .accessibilityIdentifier("stat-\(title)")
        }
    }
}

// MARK: - Milestone Row

private struct MilestoneRow: View {
    let milestone: PlanMilestone
    let projection: MilestoneProjection?

    private var tint: Color {
        if milestone.isPaid { return .green }
        guard let projection else { return Color.textTertiary }
        return projection.isCovered ? Color.heroPink : .orange
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: milestone.isPaid ? "checkmark" : milestone.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(Circle().fill(tint.opacity(0.15)))

            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .strikethrough(milestone.isPaid, color: Color.textTertiary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(CurrencyFormatter.format(milestone.amount))
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.textPrimary)
                Text(statusText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .glassCard(padding: 14)
    }

    private var subtitle: String {
        let date = (milestone.isPaid ? milestone.paidDate : milestone.dueDate) ?? milestone.dueDate
        let prefix = milestone.isPaid ? "Paid" : "Due"
        let base = "\(prefix) \(date.formatted(.dateTime.day().month(.abbreviated).year()))"
        return milestone.note.isEmpty ? base : "\(base) · \(milestone.note)"
    }

    private var statusText: String {
        if milestone.isPaid { return "PAID" }
        guard let p = projection else { return "" }
        if milestone.dueDate < .now { return p.isCovered ? "OVERDUE" : "OVERDUE · SHORT" }
        return p.isCovered ? "COVERED" : "SHORT \(CurrencyFormatter.format(p.shortfall.rounded()))"
    }
}

// MARK: - Number Row

private struct NumberRow: View {
    let label: String
    @Binding var value: Double
    var prefix: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
            Spacer()
            HStack(spacing: 2) {
                Text(prefix).foregroundStyle(Color.textTertiary)
                TextField("0", value: $value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    .accessibilityIdentifier("field-\(label)")
                    .foregroundStyle(Color.textPrimary)
            }
            .font(.system(size: 15, weight: .semibold))
            .monospacedDigit()
        }
    }
}

// MARK: - Milestone Editor

struct MilestoneEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let milestone: PlanMilestone?
    let plan: StudyAbroadPlan

    @State private var title = ""
    @State private var amount: Double = 0
    @State private var dueDate = Date.now
    @State private var note = ""
    @State private var isPaid = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cost") {
                    TextField("Title", text: $title)
                    HStack {
                        Text("₹")
                        TextField("Amount", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    TextField("Note", text: $note)
                }
                Section {
                    Toggle("Paid", isOn: $isPaid)
                } footer: {
                    Text("Marking a cost paid deducts it from \"Saved so far\".")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(milestone == nil ? "New cost" : "Edit cost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!isValid)
                }
            }
            .onAppear {
                guard let m = milestone else { return }
                title = m.title
                amount = m.amount
                dueDate = m.dueDate
                note = m.note
                isPaid = m.isPaid
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.appBackground)
    }

    private func save() {
        let repo = StudyPlanRepository(context: modelContext)
        let target: PlanMilestone
        if let m = milestone {
            // Keep savings consistent if a paid cost's amount changes.
            if m.isPaid { plan.currentSavings -= amount - m.amount }
            target = m
        } else {
            target = PlanMilestone(title: title, amount: amount, dueDate: dueDate, symbolName: "tag.fill")
            try? repo.add(target)
        }
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.amount = amount
        target.dueDate = dueDate
        target.note = note
        try? repo.setPaid(isPaid, target, plan: plan)
        try? repo.save()
        Haptics.success()
        dismiss()
    }
}
