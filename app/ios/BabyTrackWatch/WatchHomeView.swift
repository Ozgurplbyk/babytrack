import SwiftUI

struct WatchHomeView: View {
    @State private var quickStatus = NSLocalizedString("watch_quick_status_ready", comment: "")

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: Date(), by: 30)) { _ in
                let summary = loadSharedSummary()

                List {
                    Section(summary?.childName ?? NSLocalizedString("widget_placeholder_child_name", comment: "")) {
                        if let summary {
                            summaryRow(title: NSLocalizedString("app_today", comment: ""), value: "\(summary.logsToday)")
                            summaryRow(title: NSLocalizedString("quick_action_bottle", comment: ""), value: "\(summary.feedCount)")
                            summaryRow(title: NSLocalizedString("quick_action_sleep", comment: ""), value: "\(summary.sleepCount)")
                            summaryRow(title: NSLocalizedString("quick_action_diaper_poop", comment: ""), value: "\(summary.diaperCount)")
                        } else {
                            Text(NSLocalizedString("watch_quick_status_ready", comment: ""))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section(NSLocalizedString("watch_section_quick_log", comment: "")) {
                        Button(NSLocalizedString("watch_action_sleep_start", comment: "")) {
                            queueQuickEvent(typeRaw: "sleep", summary: summary)
                            quickStatus = NSLocalizedString("watch_status_sleep_logged", comment: "")
                        }
                        Button(NSLocalizedString("watch_action_diaper_change", comment: "")) {
                            queueQuickEvent(typeRaw: "diaperChange", summary: summary)
                            quickStatus = NSLocalizedString("watch_status_diaper_logged", comment: "")
                        }
                        Button(NSLocalizedString("watch_action_medication_given", comment: "")) {
                            queueQuickEvent(typeRaw: "medication", summary: summary)
                            quickStatus = NSLocalizedString("watch_status_medication_logged", comment: "")
                        }
                    }

                    Section(NSLocalizedString("watch_section_status", comment: "")) {
                        Text(quickStatus)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("watch_navigation_title", comment: ""))
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(.body.weight(.semibold))
        }
    }

    private func loadSharedSummary() -> WatchSharedDailySnapshot? {
        guard let defaults = UserDefaults(suiteName: "group.com.babytrack.shared"),
              let data = defaults.data(forKey: "shared.daily_summary.v1"),
              let summary = try? JSONDecoder().decode(WatchSharedDailySnapshot.self, from: data) else {
            return nil
        }
        return summary
    }

    private func queueQuickEvent(typeRaw: String, summary: WatchSharedDailySnapshot?) {
        guard let defaults = UserDefaults(suiteName: "group.com.babytrack.shared") else { return }

        let childId = summary?.childId ?? defaults.string(forKey: "shared.selected_child_id.v1") ?? "default-child"
        let newEvent = WatchQueuedEvent(
            id: UUID(),
            childId: childId,
            typeRaw: typeRaw,
            timestamp: Date(),
            note: "watch_quick_log"
        )

        var queue: [WatchQueuedEvent] = []
        if let data = defaults.data(forKey: "shared.watch.quick_queue.v1"),
           let decoded = try? JSONDecoder().decode([WatchQueuedEvent].self, from: data) {
            queue = decoded
        }
        queue.append(newEvent)

        if let encoded = try? JSONEncoder().encode(queue) {
            defaults.set(encoded, forKey: "shared.watch.quick_queue.v1")
        }
    }
}

private struct WatchSharedDailySnapshot: Codable {
    let childId: String
    let childName: String
    let countryCode: String
    let generatedAt: Date
    let logsToday: Int
    let feedCount: Int
    let sleepCount: Int
    let diaperCount: Int
    let medicationCount: Int
    let feverCount: Int
    let lastEventTypeRaw: String?
    let lastEventAt: Date?
}

private struct WatchQueuedEvent: Codable {
    let id: UUID
    let childId: String
    let typeRaw: String
    let timestamp: Date
    let note: String
}
