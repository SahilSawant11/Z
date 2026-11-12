//
//  Note.swift
//  ExpenseCompanion
//
//  Free-form notes with an optional checklist. A note can stand alone or be
//  linked to the Germany plan, a university, a goal or an expense, in which
//  case it also shows up on that item's screen.
//

import Foundation
import SwiftData

enum NoteLinkKind: String, Codable, CaseIterable {
    case none = ""
    case plan
    case university
    case goal
    case expense

    var symbolName: String {
        switch self {
        case .none: return "link"
        case .plan: return "airplane"
        case .university: return "building.columns.fill"
        case .goal: return "target"
        case .expense: return "indianrupeesign.circle.fill"
        }
    }
}

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var isPinned: Bool = false
    var checklist: [ChecklistItem] = []
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var linkKindRaw: String = NoteLinkKind.none.rawValue
    var linkID: UUID?
    /// Cached display name of the linked item, so lists don't need to look it up.
    var linkTitle: String = ""

    var linkKind: NoteLinkKind {
        get { NoteLinkKind(rawValue: linkKindRaw) ?? .none }
        set { linkKindRaw = newValue.rawValue }
    }

    var isLinked: Bool { linkKind != .none && linkID != nil }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && checklist.isEmpty
    }

    /// Title, or the first line of the body when there's no title.
    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let firstLine = body.split(separator: "\n").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
        return firstLine.isEmpty ? "New note" : firstLine
    }

    /// Body text for previews, skipping the line already used as the title.
    var snippet: String {
        let lines = body.split(separator: "\n").map(String.init)
        let rest = title.trimmingCharacters(in: .whitespaces).isEmpty ? lines.dropFirst() : lines[...]
        return rest.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    init(title: String = "", body: String = "") {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = .now
        self.updatedAt = .now
    }

    func link(_ kind: NoteLinkKind, id: UUID?, title: String) {
        linkKind = kind
        linkID = kind == .none ? nil : id
        linkTitle = kind == .none ? "" : title
        touch()
    }

    func touch() { updatedAt = .now }
}
