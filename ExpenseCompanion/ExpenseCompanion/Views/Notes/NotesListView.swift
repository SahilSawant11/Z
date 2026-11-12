//
//  NotesListView.swift
//  ExpenseCompanion
//
//  Notes tab: search, pinned first, optional filter to linked notes.
//

import SwiftUI
import SwiftData

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    @State private var search = ""
    @State private var filter: Filter = .all
    @State private var path: [Note] = []

    enum Filter: String, CaseIterable {
        case all = "All"
        case pinned = "Pinned"
        case linked = "Linked"
    }

    private var visible: [Note] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return notes
            .filter { !$0.isEmpty || path.contains($0) }
            .filter {
                switch filter {
                case .all: return true
                case .pinned: return $0.isPinned
                case .linked: return $0.isLinked
                }
            }
            .filter {
                q.isEmpty
                    || $0.title.lowercased().contains(q)
                    || $0.body.lowercased().contains(q)
                    || $0.linkTitle.lowercased().contains(q)
                    || $0.checklist.contains { $0.title.lowercased().contains(q) }
            }
            .sorted { ($0.isPinned ? 1 : 0, $0.updatedAt) > ($1.isPinned ? 1 : 0, $1.updatedAt) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                DynamicGradientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ScreenHeader(caption: "Notes", light: "Your", bold: "notes") {
                            CircleIconButton(systemName: "square.and.pencil", filled: true, action: newNote)
                                .accessibilityLabel("New note")
                        }

                        searchField

                        HStack(spacing: 8) {
                            ForEach(Filter.allCases, id: \.self) { f in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { filter = f }
                                } label: {
                                    PillBadge(title: f.rawValue, isSelected: filter == f)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if visible.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(visible) { note in
                                    NavigationLink(value: note) {
                                        NoteCard(note: note)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("note-\(note.displayTitle)")
                                    .contextMenu {
                                        Button(note.isPinned ? "Unpin" : "Pin",
                                               systemImage: note.isPinned ? "pin.slash" : "pin") {
                                            note.isPinned.toggle()
                                            try? modelContext.save()
                                        }
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            modelContext.delete(note)
                                            try? modelContext.save()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Note.self) { note in
                NoteEditorView(note: note)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textTertiary)
            TextField("Search notes", text: $search)
                .foregroundStyle(Color.textPrimary)
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 15))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.cardSurface))
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            CircleIconButton(systemName: "plus", size: 40, action: newNote)
            VStack(alignment: .leading, spacing: 2) {
                Text(search.isEmpty ? "No notes yet" : "No matches")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                Text(search.isEmpty ? "Write anything, add a checklist, or link it to a goal." : "Try a different word.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func newNote() {
        let note = Note()
        modelContext.insert(note)
        path.append(note)
        Haptics.light()
    }
}

// MARK: - Card

struct NoteCard: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(note.displayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Spacer()
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.heroPink)
                }
            }

            if !note.snippet.isEmpty {
                Text(note.snippet)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                if note.isLinked {
                    Label(note.linkTitle, systemImage: note.linkKind.symbolName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color.cardSurfaceRaised))
                }
                if !note.checklist.isEmpty {
                    Label("\(note.checklist.filter(\.isDone).count)/\(note.checklist.count)", systemImage: "checklist")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color.cardSurfaceRaised))
                }
                Spacer()
                Text(note.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 16)
    }
}
