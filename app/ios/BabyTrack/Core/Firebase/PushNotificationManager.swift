import Foundation
import UserNotifications
import UIKit
import Combine

@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    private override init() {
        super.init()
    }

    @discardableResult
    func requestAuthorizationAndRegister() async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            // ignored for now
            return false
        }
    }

    func scheduleMedicationReminder(plan: MedicationPlan) {
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("medication_reminder_title")
        content.body = String(
            format: L10n.tr("medication_reminder_body_format"),
            plan.name,
            plan.dosage.isEmpty ? L10n.tr("medication_reminder_no_dose") : plan.dosage
        )
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = plan.reminderHour
        dateComponents.minute = plan.reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: medicationReminderIdentifier(planId: plan.id),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelMedicationReminder(planId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [medicationReminderIdentifier(planId: planId)]
        )
    }

    private func medicationReminderIdentifier(planId: UUID) -> String {
        "medication.plan.reminder.\(planId.uuidString)"
    }

    func syncCareReminders(items: [CareReminderNotificationItem]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let existing = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("care.reminder.") }
            if !existing.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: existing)
            }

            let now = Date()
            let limited = items
                .filter { $0.fireDate > now }
                .sorted(by: { $0.fireDate < $1.fireDate })
                .prefix(20)

            for item in limited {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = item.body
                content.sound = .default

                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "care.reminder.\(item.id)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }
}

struct CareReminderNotificationItem: Equatable {
    let id: String
    let title: String
    let body: String
    let fireDate: Date
}

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
}

struct MedicationPlan: Identifiable, Codable, Equatable {
    let id: UUID
    let childId: String
    var name: String
    var dosage: String
    var note: String
    var reminderHour: Int
    var reminderMinute: Int
    var isActive: Bool
    let createdAt: Date
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        childId: String,
        name: String,
        dosage: String = "",
        note: String = "",
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        isActive: Bool = true,
        createdAt: Date = Date(),
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.childId = childId
        self.name = name
        self.dosage = dosage
        self.note = note
        self.reminderHour = max(0, min(reminderHour, 23))
        self.reminderMinute = max(0, min(reminderMinute, 59))
        self.isActive = isActive
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }
}

@MainActor
final class MedicationPlanStore: ObservableObject {
    @Published private(set) var plans: [MedicationPlan] = []

    private let key: String

    init(childId: String) {
        self.key = Self.storageKey(for: childId)
        load()
    }

    static func snapshot(childId: String) -> [MedicationPlan] {
        let key = storageKey(for: childId)
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MedicationPlan].self, from: data) else {
            return []
        }
        return decoded.sorted(by: Self.sorter(lhs:rhs:))
    }

    func upsert(_ plan: MedicationPlan) {
        guard !plan.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var normalized = plan
        normalized.archivedAt = normalized.isActive ? nil : (normalized.archivedAt ?? Date())

        if let idx = plans.firstIndex(where: { $0.id == normalized.id }) {
            plans[idx] = normalized
        } else {
            plans.append(normalized)
        }
        plans.sort(by: Self.sorter(lhs:rhs:))
        saveAndSyncReminders()
    }

    func setActive(_ id: UUID, isActive: Bool) {
        guard let idx = plans.firstIndex(where: { $0.id == id }) else { return }
        plans[idx].isActive = isActive
        plans[idx].archivedAt = isActive ? nil : Date()
        saveAndSyncReminders()
    }

    func delete(_ id: UUID) {
        guard let plan = plans.first(where: { $0.id == id }) else { return }
        plans.removeAll(where: { $0.id == id })
        PushNotificationManager.shared.cancelMedicationReminder(planId: plan.id)
        save()
    }

    var activePlans: [MedicationPlan] {
        plans.filter(\.isActive)
    }

    var archivedPlans: [MedicationPlan] {
        plans.filter { !$0.isActive }
            .sorted { ($0.archivedAt ?? $0.createdAt) > ($1.archivedAt ?? $1.createdAt) }
    }

    private func saveAndSyncReminders() {
        save()
        syncReminders()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MedicationPlan].self, from: data) else {
            plans = []
            return
        }
        plans = decoded.sorted(by: Self.sorter(lhs:rhs:))
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(plans) else { return }
        UserDefaults.standard.set(encoded, forKey: key)
    }

    private func syncReminders() {
        for plan in plans {
            if plan.isActive {
                PushNotificationManager.shared.scheduleMedicationReminder(plan: plan)
            } else {
                PushNotificationManager.shared.cancelMedicationReminder(planId: plan.id)
            }
        }
    }

    private static func sorter(lhs: MedicationPlan, rhs: MedicationPlan) -> Bool {
        if lhs.isActive != rhs.isActive {
            return lhs.isActive && !rhs.isActive
        }
        if lhs.isActive {
            if lhs.reminderHour != rhs.reminderHour {
                return lhs.reminderHour < rhs.reminderHour
            }
            if lhs.reminderMinute != rhs.reminderMinute {
                return lhs.reminderMinute < rhs.reminderMinute
            }
        }
        return lhs.createdAt > rhs.createdAt
    }

    private static func storageKey(for childId: String) -> String {
        "medication.plans.v1.\(childId)"
    }
}
