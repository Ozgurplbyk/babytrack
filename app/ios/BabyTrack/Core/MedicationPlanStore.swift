import Foundation

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

    var reminderDateComponents: DateComponents {
        DateComponents(hour: reminderHour, minute: reminderMinute)
    }
}

@MainActor
final class MedicationPlanStore: ObservableObject {
    @Published private(set) var plans: [MedicationPlan] = []

    private let childId: String
    private let key: String

    init(childId: String) {
        self.childId = childId
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
