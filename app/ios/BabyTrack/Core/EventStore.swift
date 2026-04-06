import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class EventStore: ObservableObject {
    @Published private(set) var events: [AppEvent] = []

    private let fileName = BabyTrackSharedStoreKeys.eventStoreFileName

    init() {
        load()
    }

    func add(_ event: AppEvent) {
        events.insert(event, at: 0)
        persist()
    }

    func upsert(_ event: AppEvent) {
        if events.contains(where: { $0.id == event.id }) {
            update(event)
        } else {
            add(event)
        }
    }

    func replaceAll(with newEvents: [AppEvent]) {
        let existingPhotoFiles = Set(events.compactMap { $0.payload["photo_file"] })
        let incomingPhotoFiles = Set(newEvents.compactMap { $0.payload["photo_file"] })
        let filesToDelete = existingPhotoFiles.subtracting(incomingPhotoFiles)
        for file in filesToDelete {
            EventAttachmentStorage.delete(fileName: file)
        }

        events = newEvents.sorted { $0.timestamp > $1.timestamp }
        persist()
    }

    func event(withIdString raw: String) -> AppEvent? {
        guard let id = UUID(uuidString: raw) else { return nil }
        return events.first(where: { $0.id == id })
    }

    func update(_ event: AppEvent) {
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return }
        let previous = events[idx]
        if previous.payload["photo_file"] != event.payload["photo_file"] {
            EventAttachmentStorage.delete(fileName: previous.payload["photo_file"])
        }
        events[idx] = event
        events.sort { $0.timestamp > $1.timestamp }
        persist()
    }

    func delete(id: UUID) {
        if let item = events.first(where: { $0.id == id }) {
            EventAttachmentStorage.delete(fileName: item.payload["photo_file"])
        }
        events.removeAll(where: { $0.id == id })
        persist()
    }

    func deleteAll(for childId: String) {
        let removing = events.filter { $0.childId == childId }
        for item in removing {
            EventAttachmentStorage.delete(fileName: item.payload["photo_file"])
        }
        events.removeAll(where: { $0.childId == childId })
        persist()
    }

    func recent(limit: Int = 50, childId: String? = nil) -> [AppEvent] {
        let sorted = events.sorted { $0.timestamp > $1.timestamp }
        let scoped = childId.map { id in sorted.filter { $0.childId == id } } ?? sorted
        return Array(scoped.prefix(limit))
    }

    func filter(by type: EventType?, childId: String? = nil) -> [AppEvent] {
        let base = recent(limit: 10_000, childId: childId)
        guard let type else { return base }
        return base.filter { $0.type == type }
    }

    @discardableResult
    func importWatchQueuedEvents(defaultChildId: String) -> Int {
        guard let defaults = sharedDefaults(),
              let data = defaults.data(forKey: BabyTrackSharedStoreKeys.watchQueueKey),
              let queued = try? JSONDecoder().decode([WatchQueuedEvent].self, from: data),
              !queued.isEmpty else {
            return 0
        }

        var importedCount = 0
        for item in queued {
            guard let mappedType = EventType(rawValue: item.typeRaw) else { continue }
            if events.contains(where: { $0.id == item.id }) { continue }

            let childId = item.childId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? defaultChildId
                : item.childId

            events.append(
                AppEvent(
                    id: item.id,
                    childId: childId,
                    type: mappedType,
                    timestamp: item.timestamp,
                    note: item.note,
                    payload: ["source": "watch"],
                    visibility: .family
                )
            )
            importedCount += 1
        }

        defaults.removeObject(forKey: BabyTrackSharedStoreKeys.watchQueueKey)

        if importedCount > 0 {
            events.sort { $0.timestamp > $1.timestamp }
            persist()
        }

        return importedCount
    }

    func publishSharedSnapshot(childId: String, childName: String, countryCode: String) {
        guard let defaults = sharedDefaults() else { return }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: Date())
        let scoped = events.filter { $0.childId == childId }
        let today = scoped.filter { $0.timestamp >= dayStart }

        let latest = scoped.sorted(by: { $0.timestamp > $1.timestamp }).first

        let snapshot = SharedDailySnapshot(
            childId: childId,
            childName: childName,
            countryCode: countryCode,
            generatedAt: Date(),
            logsToday: today.count,
            feedCount: today.filter { $0.type.isFeedingRelated }.count,
            sleepCount: today.filter { $0.type == .sleep }.count,
            diaperCount: today.filter { $0.type.isDiaperRelated }.count,
            medicationCount: today.filter { $0.type == .medication }.count,
            feverCount: today.filter { $0.type == .fever }.count,
            lastEventTypeRaw: latest?.type.rawValue,
            lastEventAt: latest?.timestamp
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: BabyTrackSharedStoreKeys.dailySummaryKey)
        defaults.set(childId, forKey: BabyTrackSharedStoreKeys.selectedChildIdKey)
        defaults.set(countryCode, forKey: BabyTrackSharedStoreKeys.countryCodeKey)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func load() {
        let url = storeURL()
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([AppEvent].self, from: data) {
            events = decoded.sorted { $0.timestamp > $1.timestamp }
            return
        }

        if let legacyData = try? Data(contentsOf: legacyStoreURL()),
           let decoded = try? JSONDecoder().decode([AppEvent].self, from: legacyData) {
            events = decoded.sorted { $0.timestamp > $1.timestamp }
            persist() // migrate legacy file into app-group container
            return
        }

        events = []
    }

    private func persist() {
        let url = storeURL()
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: url, options: [.atomic])
        } catch {
            // non-fatal for local persistence
        }
    }

    private func storeURL() -> URL {
        let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: BabyTrackSharedStoreKeys.appGroupId)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(fileName)
    }

    private func legacyStoreURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(fileName)
    }

    private func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: BabyTrackSharedStoreKeys.appGroupId)
    }
}

private enum BabyTrackSharedStoreKeys {
    static let appGroupId = "group.com.babytrack.shared"
    static let eventStoreFileName = "events_store_v1.json"
    static let dailySummaryKey = "shared.daily_summary.v1"
    static let selectedChildIdKey = "shared.selected_child_id.v1"
    static let countryCodeKey = "shared.country_code.v1"
    static let watchQueueKey = "shared.watch.quick_queue.v1"
}

private struct SharedDailySnapshot: Codable {
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
