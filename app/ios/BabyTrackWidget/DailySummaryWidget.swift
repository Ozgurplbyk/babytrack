import WidgetKit
import SwiftUI

struct DailySummaryEntry: TimelineEntry {
    let date: Date
    let childName: String
    let logsToday: Int
    let feedCount: Int
    let sleepCount: Int
    let diaperCount: Int
    let lastEventTypeRaw: String?
    let lastEventAt: Date?
}

struct DailySummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailySummaryEntry {
        DailySummaryEntry(
            date: Date(),
            childName: NSLocalizedString("widget_placeholder_child_name", comment: ""),
            logsToday: 3,
            feedCount: 1,
            sleepCount: 1,
            diaperCount: 1,
            lastEventTypeRaw: nil,
            lastEventAt: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DailySummaryEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailySummaryEntry>) -> Void) {
        let entry = currentEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> DailySummaryEntry {
        guard let defaults = UserDefaults(suiteName: "group.com.babytrack.shared"),
              let data = defaults.data(forKey: "shared.daily_summary.v1"),
              let shared = try? JSONDecoder().decode(WidgetSharedDailySnapshot.self, from: data) else {
            return DailySummaryEntry(
                date: Date(),
                childName: NSLocalizedString("widget_placeholder_child_name", comment: ""),
                logsToday: 0,
                feedCount: 0,
                sleepCount: 0,
                diaperCount: 0,
                lastEventTypeRaw: nil,
                lastEventAt: nil
            )
        }

        return DailySummaryEntry(
            date: Date(),
            childName: shared.childName,
            logsToday: shared.logsToday,
            feedCount: shared.feedCount,
            sleepCount: shared.sleepCount,
            diaperCount: shared.diaperCount,
            lastEventTypeRaw: shared.lastEventTypeRaw,
            lastEventAt: shared.lastEventAt
        )
    }
}

struct BabyTrackDailySummaryWidget: Widget {
    let kind = "BabyTrackDailySummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailySummaryProvider()) { entry in
            DailySummaryWidgetView(entry: entry)
        }
        .configurationDisplayName(NSLocalizedString("widget_display_name", comment: ""))
        .description(NSLocalizedString("widget_description", comment: ""))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct DailySummaryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailySummaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.childName)
                .font(.headline.weight(.bold))

            Text(String(format: NSLocalizedString("widget_logs_today_format", comment: ""), String(entry.logsToday)))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if family == .systemMedium {
                HStack(spacing: 8) {
                    metric("🍼", entry.feedCount)
                    metric("😴", entry.sleepCount)
                    metric("🧷", entry.diaperCount)
                }
            } else {
                Text("🍼 \(entry.feedCount)  😴 \(entry.sleepCount)  🧷 \(entry.diaperCount)")
                    .font(.caption2)
            }

            if let label = lastEventLabel {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func metric(_ icon: String, _ value: Int) -> some View {
        Text("\(icon) \(value)")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.14), in: Capsule())
    }

    private var lastEventLabel: String? {
        guard let typeRaw = entry.lastEventTypeRaw else { return nil }
        let title = eventTitle(for: typeRaw)
        guard let date = entry.lastEventAt else { return title }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relative = formatter.localizedString(for: date, relativeTo: Date())
        return "\(title) • \(relative)"
    }

    private func eventTitle(for raw: String) -> String {
        switch raw {
        case "breastfeeding": return NSLocalizedString("quick_action_breastfeeding", comment: "")
        case "breastfeedingLeft": return NSLocalizedString("quick_action_breast_left", comment: "")
        case "breastfeedingRight": return NSLocalizedString("quick_action_breast_right", comment: "")
        case "bottle": return NSLocalizedString("quick_action_bottle", comment: "")
        case "pumping": return NSLocalizedString("quick_action_pumping", comment: "")
        case "diaperChange": return NSLocalizedString("quick_action_diaper_change", comment: "")
        case "diaperPee": return NSLocalizedString("quick_action_diaper_pee", comment: "")
        case "diaperPoop": return NSLocalizedString("quick_action_diaper_poop", comment: "")
        case "sleep": return NSLocalizedString("quick_action_sleep", comment: "")
        case "fever": return NSLocalizedString("quick_action_fever", comment: "")
        case "symptom": return NSLocalizedString("quick_action_symptom", comment: "")
        case "medication": return NSLocalizedString("quick_action_medication", comment: "")
        case "memory": return NSLocalizedString("quick_action_memory", comment: "")
        default: return raw
        }
    }
}

private struct WidgetSharedDailySnapshot: Codable {
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
