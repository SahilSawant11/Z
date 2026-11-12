//
//  UniversityTrackerView.swift
//  ExpenseCompanion
//
//  Programs for the Germany MS plan: deadlines, status, documents checklist,
//  and application fees that sync into the plan's cost timeline.
//

import SwiftUI
import SwiftData

struct UniversityTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UniversityApplication.deadline) private var apps: [UniversityApplication]
    @Query private var plans: [StudyAbroadPlan]

    @State private var filter: ApplicationStatus?
    @State private var editing: UniversityApplication?
    @State private var showingAdd = false
    @State private var syncMessage: String?

    private var filtered: [UniversityApplication] {
        guard let filter else { return apps }
        return apps.filter { $0.status == filter }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    summaryCard
                    filterBar

                    if apps.isEmpty {
                        emptyState
                    } else if filtered.isEmpty {
                        Text("No programs with status \(filter?.rawValue ?? "")")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .padding(.top, 30)
                    } else {
                        ForEach(filtered) { app in
                            ApplicationRow(app: app)
                                .contentShape(Rectangle())
                                .onTapGesture { editing = app }
                                .contextMenu { statusMenu(for: app) }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 110)
            }
        }
        .navigationTitle("Universities")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .onDisappear {
            Task { await DeadlineReminderScheduler.reschedule(context: modelContext) }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editing) { app in ApplicationEditorView(app: app) }
        .sheet(isPresented: $showingAdd) { ApplicationEditorView(app: nil) }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let applied = apps.filter { !$0.status.isOpen }.count
        let admitted = apps.filter { $0.status == .admitted }.count
        let next = apps.filter { $0.status.isOpen && $0.daysToDeadline >= 0 }.min { $0.deadline < $1.deadline }
        let feesEUR = ApplicationFees.totalEUR(apps)
        let rate = plans.first?.eurToInr ?? 90

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 0) {
                summaryStat("\(apps.count)", "Programs")
                summaryStat("\(applied)", "Submitted")
                summaryStat("\(admitted)", "Admits")
            }

            Divider().overlay(Color.cardBorder)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next deadline").font(.system(size: 11)).foregroundStyle(Color.textTertiary)
                    if let next {
                        Text("\(next.university) · \(daysText(next.daysToDeadline))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(deadlineColor(next.daysToDeadline))
                            .lineLimit(1)
                    } else {
                        Text("None open").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.textSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Fees").font(.system(size: 11)).foregroundStyle(Color.textTertiary)
                    Text(CurrencyFormatter.format(feesEUR, currencyCode: "EUR"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                    Text("≈ \(CurrencyFormatter.format((feesEUR * rate).rounded()))")
                        .font(.system(size: 10)).foregroundStyle(Color.textTertiary)
                }
            }

            if !apps.isEmpty, plans.first != nil {
                Button(action: syncFees) {
                    Label(syncMessage ?? "Update fees in cost timeline", systemImage: syncMessage == nil ? "arrow.triangle.2.circlepath" : "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.heroPink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.heroPink.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .glassCard()
    }

    private func summaryStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 34, weight: .light))
                .monospacedDigit()
                .foregroundStyle(Color.textPrimary)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func syncFees() {
        guard let plan = plans.first else { return }
        do {
            try StudyPlanRepository(context: modelContext).syncApplicationFees(apps, plan: plan)
            syncMessage = "Cost timeline updated"
            Haptics.success()
        } catch {
            syncMessage = "Couldn't update the cost timeline"
            Haptics.warning()
        }
    }

    // MARK: - Filter

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { filter = nil } label: { PillBadge(title: "All \(apps.count)", isSelected: filter == nil) }
                ForEach(ApplicationStatus.allCases) { s in
                    let n = apps.filter { $0.status == s }.count
                    if n > 0 {
                        Button { filter = s } label: { PillBadge(title: "\(s.rawValue) \(n)", isSelected: filter == s) }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func statusMenu(for app: UniversityApplication) -> some View {
        ForEach(ApplicationStatus.allCases) { s in
            Button(s.rawValue, systemImage: s.symbolName) {
                app.status = s
                try? modelContext.save()
                Haptics.light()
            }
            .disabled(app.status == s)
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            modelContext.delete(app)
            try? modelContext.save()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.columns")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(Color.textTertiary)
            Text("No programs yet")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
            Text("Add the programs on your shortlist to track deadlines, documents and fees.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            Button("Add program") { showingAdd = true }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.heroPink)
                .padding(.top, 4)
        }
        .padding(.top, 40)
    }
}

// MARK: - Helpers

fileprivate func daysText(_ days: Int) -> String {
    switch days {
    case ..<0: return "\(-days)d ago"
    case 0: return "today"
    case 1: return "tomorrow"
    default: return "in \(days)d"
    }
}

fileprivate func deadlineColor(_ days: Int) -> Color {
    if days < 0 { return Color.textTertiary }
    if days <= 14 { return .red }
    if days <= 30 { return .orange }
    return Color.textPrimary
}

// MARK: - Row

private struct ApplicationRow: View {
    let app: UniversityApplication

    private var statusColor: Color {
        switch app.status {
        case .admitted: return .green
        case .rejected: return Color.textTertiary
        case .waitlisted: return .orange
        case .applied: return Color.accentBlue
        case .shortlisted, .preparing: return Color.heroPink
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: app.checklistProgress, lineWidth: 5, tint: statusColor)
                    .frame(width: 44, height: 44)
                Image(systemName: app.status.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(app.university.isEmpty ? "Untitled" : app.university)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text([app.program, app.city].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                Text("\(app.checklist.filter(\.isDone).count)/\(app.checklist.count) docs · \(app.route.rawValue)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(app.deadline.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                Text(app.status.isOpen ? daysText(app.daysToDeadline).uppercased() : app.status.rawValue.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(app.status.isOpen ? deadlineColor(app.daysToDeadline) : statusColor)
            }
        }
        .glassCard(padding: 14)
        .opacity(app.status == .rejected ? 0.6 : 1)
    }
}

// MARK: - Editor

struct ApplicationEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let app: UniversityApplication?

    @State private var university = ""
    @State private var program = "MSc Computer Science"
    @State private var city = ""
    @State private var deadline = StudyAbroadPlan.date(2027, 3, 15)
    @State private var status: ApplicationStatus = .shortlisted
    @State private var route: ApplicationRoute = .uniAssist
    @State private var directFeeEUR: Double = 0
    @State private var portalURL = ""
    @State private var notes = ""
    @State private var checklist = UniversityApplication.defaultChecklist()
    @State private var newItem = ""
    @State private var showingDeleteConfirm = false

    private var isValid: Bool { !university.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Program") {
                    TextField("University (e.g. TU Munich)", text: $university)
                    TextField("Program", text: $program)
                    TextField("City", text: $city)
                    DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                }

                Section {
                    Picker("Status", selection: $status) {
                        ForEach(ApplicationStatus.allCases) { Label($0.rawValue, systemImage: $0.symbolName).tag($0) }
                    }
                    Picker("Apply via", selection: $route) {
                        ForEach(ApplicationRoute.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if route == .direct {
                        HStack {
                            Text("Application fee")
                            Spacer()
                            Text("€").foregroundStyle(.secondary)
                            TextField("0", value: $directFeeEUR, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 90)
                        }
                    }
                } footer: {
                    Text(route == .uniAssist
                         ? "uni-assist charges €75 for the first application and €30 for each further one in the same semester."
                         : "Fee charged by the university for a direct application.")
                }

                Section {
                    ForEach($checklist) { $item in
                        Toggle(item.title, isOn: $item.isDone)
                    }
                    .onDelete { checklist.remove(atOffsets: $0) }
                    HStack {
                        TextField("Add document", text: $newItem)
                            .onSubmit(addItem)
                        Button("Add", action: addItem)
                            .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Documents \(checklist.filter(\.isDone).count)/\(checklist.count)")
                } footer: {
                    Text("Swipe left on a document to remove it.")
                }

                Section("Links & notes") {
                    TextField("Portal URL", text: $portalURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if let url = URL(string: portalURL), url.scheme?.hasPrefix("http") == true {
                        Link("Open portal", destination: url)
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                if app != nil {
                    Section {
                        Button("Delete program", role: .destructive) { showingDeleteConfirm = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(app == nil ? "New program" : "Edit program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!isValid)
                }
            }
            .confirmationDialog("Delete this program?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let app { modelContext.delete(app); try? modelContext.save() }
                    dismiss()
                }
            }
            .onAppear(perform: load)
        }
        .presentationBackground(Color.appBackground)
    }

    private func load() {
        guard let app else { return }
        university = app.university
        program = app.program
        city = app.city
        deadline = app.deadline
        status = app.status
        route = app.route
        directFeeEUR = app.directFeeEUR
        portalURL = app.portalURL
        notes = app.notes
        checklist = app.checklist
    }

    private func addItem() {
        let title = newItem.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        checklist.append(ChecklistItem(title: title))
        newItem = ""
    }

    private func save() {
        let target = app ?? {
            let new = UniversityApplication()
            modelContext.insert(new)
            return new
        }()
        target.university = university.trimmingCharacters(in: .whitespaces)
        target.program = program.trimmingCharacters(in: .whitespaces)
        target.city = city.trimmingCharacters(in: .whitespaces)
        target.deadline = deadline
        target.status = status
        target.route = route
        target.directFeeEUR = route == .direct ? directFeeEUR : 0
        target.portalURL = portalURL.trimmingCharacters(in: .whitespaces)
        target.notes = notes
        target.checklist = checklist
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}
