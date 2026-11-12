//
//  DeadlineReminderScheduler.swift
//  ExpenseCompanion
//
//  Local notifications ahead of Germany MS deadlines: open university applications
//  and unpaid costs in the plan's timeline. Rebuilt from scratch on every call, so it
//  is safe to call whenever data changes or the app moves to the foreground/background.
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
enum DeadlineReminderScheduler {

    static let enabledKey = "deadlineRemindersEnabled"
    static let identifierPrefix = "deadline."

    /// Days before the deadline to remind.
    static let applicationOffsets = [14, 7, 1]
    static let costOffsets = [7, 1]
    static let reminderHour = 9

    /// iOS keeps at most 64 pending local notifications per app; leave room for others.
    static let maxPending = 50

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    struct Reminder {
        let id: String
        let fireDate: Date
        let title: String
        let body: String
    }

    // MARK: - Public

    static func reschedule(context: ModelContext) async {
        guard !AppEnvironment.isUITesting else { return }
        let center = UNUserNotificationCenter.current()
        await removeAll(center: center)
        guard isEnabled else { return }

        let reminders = buildReminders(context: context, now: .now)
        guard !reminders.isEmpty, await ensureAuthorized(center: center) else { return }

        for r in reminders {
            let content = UNMutableNotificationContent()
            content.title = r.title
            content.body = r.body
            content.sound = .default
            content.threadIdentifier = "germany-ms"
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: r.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: r.id, content: content, trigger: trigger))
        }
    }

    static func removeAll() async {
        await removeAll(center: UNUserNotificationCenter.current())
    }

    // MARK: - Building

    static func buildReminders(context: ModelContext, now: Date) -> [Reminder] {
        let apps = (try? context.fetch(FetchDescriptor<UniversityApplication>())) ?? []
        let milestones = (try? context.fetch(FetchDescriptor<PlanMilestone>())) ?? []
        let plan = try? context.fetch(FetchDescriptor<StudyAbroadPlan>()).first

        var reminders: [Reminder] = []

        for app in apps where app.status.isOpen {
            let done = app.checklist.filter(\.isDone).count
            let missing = app.checklist.count - done
            let name = app.university.isEmpty ? "Application" : app.university
            for days in applicationOffsets {
                guard let fire = fireDate(daysBefore: days, deadline: app.deadline), fire > now else { continue }
                var body = app.program.isEmpty ? "" : "\(app.program) · "
                if missing == 0 {
                    body += "All \(app.checklist.count) documents ready. Time to submit."
                } else if done == 0 {
                    body += "No documents ticked off yet (0/\(app.checklist.count))."
                } else {
                    body += "\(missing) of \(app.checklist.count) documents still to do."
                }
                reminders.append(Reminder(
                    id: "\(identifierPrefix)app.\(app.id.uuidString).\(days)",
                    fireDate: fire,
                    title: "\(name) deadline \(phrase(days))",
                    body: body
                ))
            }
        }

        let projections = plan.map { PlanProjector.project(plan: $0, milestones: milestones, now: now) } ?? []
        let byID = Dictionary(uniqueKeysWithValues: projections.map { ($0.id, $0) })

        for m in milestones where !m.isPaid {
            for days in costOffsets {
                guard let fire = fireDate(daysBefore: days, deadline: m.dueDate), fire > now else { continue }
                var body = CurrencyFormatter.format(m.amount)
                if let p = byID[m.id] {
                    body += p.isCovered
                        ? " · your savings cover it."
                        : " · projected short by \(CurrencyFormatter.format(p.shortfall.rounded()))."
                }
                reminders.append(Reminder(
                    id: "\(identifierPrefix)cost.\(m.id.uuidString).\(days)",
                    fireDate: fire,
                    title: "\(m.title) due \(phrase(days))",
                    body: body
                ))
            }
        }

        return Array(reminders.sorted { $0.fireDate < $1.fireDate }.prefix(maxPending))
    }

    static func fireDate(daysBefore days: Int, deadline: Date) -> Date? {
        let cal = Calendar.current
        guard let day = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: deadline)) else { return nil }
        return cal.date(bySettingHour: reminderHour, minute: 0, second: 0, of: day)
    }

    private static func phrase(_ days: Int) -> String {
        days == 1 ? "tomorrow" : "in \(days) days"
    }

    // MARK: - Notification center

    private static func removeAll(center: UNUserNotificationCenter) async {
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func ensureAuthorized(center: UNUserNotificationCenter) async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }
}
