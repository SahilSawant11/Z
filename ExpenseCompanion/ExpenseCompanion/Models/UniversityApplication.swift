//
//  UniversityApplication.swift
//  ExpenseCompanion
//
//  One program applied to (or shortlisted) for the Germany MS plan:
//  deadline, route (uni-assist / direct), status and a documents checklist.
//

import Foundation
import SwiftData

enum ApplicationStatus: String, Codable, CaseIterable, Identifiable {
    case shortlisted = "Shortlisted"
    case preparing = "Preparing"
    case applied = "Applied"
    case admitted = "Admitted"
    case waitlisted = "Waitlisted"
    case rejected = "Rejected"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .shortlisted: return "star"
        case .preparing: return "pencil.and.list.clipboard"
        case .applied: return "paperplane.fill"
        case .admitted: return "checkmark.seal.fill"
        case .waitlisted: return "hourglass"
        case .rejected: return "xmark.circle.fill"
        }
    }

    /// Still needs work before the deadline.
    var isOpen: Bool { self == .shortlisted || self == .preparing }
}

enum ApplicationRoute: String, Codable, CaseIterable, Identifiable {
    case uniAssist = "uni-assist"
    case direct = "Direct"

    var id: String { rawValue }
}

struct ChecklistItem: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var isDone: Bool = false
}

@Model
final class UniversityApplication {
    var id: UUID = UUID()
    var university: String = ""
    var program: String = ""
    var city: String = ""
    var deadline: Date = Date.now
    var statusRaw: String = ApplicationStatus.shortlisted.rawValue
    var routeRaw: String = ApplicationRoute.uniAssist.rawValue
    /// Application fee for direct applications (€). uni-assist fees are computed across all uni-assist apps.
    var directFeeEUR: Double = 0
    var portalURL: String = ""
    var notes: String = ""
    var checklist: [ChecklistItem] = []
    var createdAt: Date = Date.now

    var status: ApplicationStatus {
        get { ApplicationStatus(rawValue: statusRaw) ?? .shortlisted }
        set { statusRaw = newValue.rawValue }
    }

    var route: ApplicationRoute {
        get { ApplicationRoute(rawValue: routeRaw) ?? .uniAssist }
        set { routeRaw = newValue.rawValue }
    }

    var checklistProgress: Double {
        guard !checklist.isEmpty else { return 0 }
        return Double(checklist.filter(\.isDone).count) / Double(checklist.count)
    }

    /// Whole days until the deadline; negative once it has passed.
    var daysToDeadline: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: deadline)).day ?? 0
    }

    init(university: String = "", program: String = "", deadline: Date = .now) {
        self.id = UUID()
        self.university = university
        self.program = program
        self.deadline = deadline
        self.checklist = Self.defaultChecklist()
        self.createdAt = .now
    }

    static func defaultChecklist() -> [ChecklistItem] {
        [
            "Bachelor's transcripts",
            "Degree certificate",
            "APS certificate",
            "IELTS score",
            "CV",
            "Motivation letter / SOP",
            "Letters of recommendation",
            "Passport copy",
        ].map { ChecklistItem(title: $0) }
    }
}

// MARK: - Fees

enum ApplicationFees {
    /// uni-assist: €75 for the first application in a semester, €30 for each further one.
    static let uniAssistFirstEUR = 75.0
    static let uniAssistAdditionalEUR = 30.0

    static func uniAssistEUR(count: Int) -> Double {
        guard count > 0 else { return 0 }
        return uniAssistFirstEUR + Double(count - 1) * uniAssistAdditionalEUR
    }

    /// Total fees across all applications (rejected ones were still paid for, so they count).
    static func totalEUR(_ apps: [UniversityApplication]) -> Double {
        let uniAssistCount = apps.filter { $0.route == .uniAssist }.count
        let direct = apps.filter { $0.route == .direct }.reduce(0) { $0 + $1.directFeeEUR }
        return uniAssistEUR(count: uniAssistCount) + direct
    }
}
