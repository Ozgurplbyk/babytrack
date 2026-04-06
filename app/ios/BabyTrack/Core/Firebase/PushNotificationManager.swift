import Foundation
@preconcurrency import UserNotifications
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

struct CareReminderNotificationItem: Equatable, Sendable {
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
