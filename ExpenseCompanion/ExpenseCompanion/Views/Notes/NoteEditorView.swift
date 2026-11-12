//
//  NoteEditorView.swift
//  ExpenseCompanion
//
//  Edits a note in place (changes save as you type). Empty notes are
//  discarded when you leave. Also hosts the link picker.
//

import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var note: Note
    /// True when presented as a sheet (adds a Done button).
    var isSheet: Bool = false

    @State private var newItem = ""
    @FocusState private var focus: Field?

    enum Field { case title, body, newItem }

    var body: some View {
        ZStack {
            DynamicGradientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Title", text: $note.title, axis: .vertical)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .focused($focus, equals: .title)
                        .accessibilityIdentifier("note-title")

                    linkRow

                    TextField("Start writing…", text: $note.body, axis: .vertical)
                        .font(.system(size: 17))
                        .foregroundStyle(Color.textPrimary)
                        .lineSpacing(4)
                        .frame(minHeight: 120, alignment: .top)
                        .focused($focus, equals: .body)
                        .accessibilityIdentifier("note-body")

                    checklist
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    note.isPinned.toggle()
                    Haptics.light()
                } label: {
                    Image(systemName: note.isPinned ? "pin.fill" : "pin")
                }
                .accessibilityLabel(note.isPinned ? "Unpin" : "Pin")
                Button(role: .destructive) {
                    modelContext.delete(note)
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete note")
            }
        }
        .onAppear {
            if note.isEmpty { focus = .title }
        }
        .onChange(of: note.title) { _, _ in note.touch() }
        .onChange(of: note.body) { _, _ in note.touch() }
        .onDisappear {
            if note.modelContext != nil, note.isEmpty {
                modelContext.delete(note)
            }
            try? modelContext.save()
        }
    }

    // MARK: - Link

    private var linkRow: some View {
        NoteLinkMenu(note: note)
    }

    // MARK: - Checklist

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach($note.checklist) { $item in
                HStack(spacing: 12) {
                    Button {
                        item.isDone.toggle()
                        note.touch()
                        Haptics.light()
                    } label: {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(item.isDone ? Color.heroPink : Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                    TextField("Item", text: $item.title)
                        .font(.system(size: 16))
                        .foregroundStyle(item.isDone ? Color.textTertiary : Color.textPrimary)
                        .strikethrough(item.isDone, color: Color.textTertiary)
                    Button {
                        note.checklist.removeAll { $0.id == item.id }
                        note.touch()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove item")
                }
                .padding(.vertical, 8)
            }

            HStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.textTertiary)
                TextField("Add checklist item", text: $newItem)
                    .font(.system(size: 16))
                    .focused($focus, equals: .newItem)
                    .submitLabel(.next)
                    .onSubmit {
                        addItem()
                        focus = .newItem
                    }
                    .accessibilityIdentifier("note-new-item")
            }
            .padding(.vertical, 8)
        }
    }

    private func addItem() {
        let t = newItem.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        note.checklist.append(ChecklistItem(title: t))
        note.touch()
        newItem = ""
    }
}

// MARK: - Link menu

/// Chip showing what a note is linked to, with a menu to change it.
struct NoteLinkMenu: View {
    @Bindable var note: Note
    @Query(sort: \UniversityApplication.deadline) private var universities: [UniversityApplication]
    @Query(sort: \FinancialGoal.deadline) private var goals: [FinancialGoal]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var plans: [StudyAbroadPlan]

    var body: some View {
        Menu {
            Button("No link", systemImage: "link.badge.plus") { note.link(.none, id: nil, title: "") }
            if let plan = plans.first {
                Button("Germany plan", systemImage: NoteLinkKind.plan.symbolName) {
                    note.link(.plan, id: plan.id, title: "Germany plan")
                }
            }
            if !universities.isEmpty {
                Menu("University") {
                    ForEach(universities) { u in
                        Button(u.university) { note.link(.university, id: u.id, title: u.university) }
                    }
                }
            }
            if !goals.isEmpty {
                Menu("Goal") {
                    ForEach(goals) { g in
                        Button(g.title) { note.link(.goal, id: g.id, title: g.title) }
                    }
                }
            }
            if !expenses.isEmpty {
                Menu("Recent expense") {
                    ForEach(expenses.prefix(15)) { e in
                        let title = "\(e.category.rawValue) · \(CurrencyFormatter.format(e.amount)) · \(e.date.formatted(.dateTime.day().month(.abbreviated)))"
                        Button(title) { note.link(.expense, id: e.id, title: title) }
                    }
                }
            }
        } label: {
            Label(note.isLinked ? note.linkTitle : "Link to…", systemImage: note.linkKind.symbolName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(note.isLinked ? Color.textPrimary : Color.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(Color.cardSurfaceRaised))
        }
        .accessibilityIdentifier("note-link")
    }
}

// MARK: - Linked notes card

/// Shows notes linked to one item, with a button to add another. Drop into any screen.
struct LinkedNotesCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [Note]
    let kind: NoteLinkKind
    let itemID: UUID
    let itemTitle: String

    @State private var editing: Note?

    init(kind: NoteLinkKind, itemID: UUID, itemTitle: String) {
        self.kind = kind
        self.itemID = itemID
        self.itemTitle = itemTitle
        let target: UUID? = itemID
        _notes = Query(filter: #Predicate<Note> { $0.linkID == target },
                       sort: \Note.updatedAt, order: .reverse)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Notes")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Button {
                    let note = Note()
                    note.link(kind, id: itemID, title: itemTitle)
                    modelContext.insert(note)
                    editing = note
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.heroPink)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("linked-notes-add")
            }

            let visible = notes.filter { !$0.isEmpty }
            if visible.isEmpty {
                Text("Nothing yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
            } else {
                ForEach(visible) { note in
                    Button { editing = note } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: note.checklist.isEmpty ? "note.text" : "checklist")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.cardSurfaceRaised))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.displayTitle)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)
                                if !note.snippet.isEmpty {
                                    Text(note.snippet)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("linked-note-\(note.displayTitle)")
                }
            }
        }
        .glassCard()
        .sheet(item: $editing) { note in
            NavigationStack {
                NoteEditorView(note: note, isSheet: true)
            }
            .presentationBackground(Color.appBackground)
        }
    }
}
