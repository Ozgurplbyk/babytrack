import Foundation
import SwiftUI

@MainActor
final class SyncConflictStore: ObservableObject {
    @Published private(set) var conflicts: [SyncConflict] = []
    @Published private(set) var backupEvents: [AppEvent] = []

    private let defaults = UserDefaults.standard
    private let conflictsKey = "sync_conflicts.pending.v1"
    private let backupEventsKey = "sync_conflicts.backup_events.v1"

    init() {
        load()
    }

    var hasConflicts: Bool {
        !conflicts.isEmpty
    }

    func setPendingConflicts(_ newConflicts: [SyncConflict], backupEvents newBackupEvents: [AppEvent]) {
        var merged: [String: SyncConflict] = Dictionary(uniqueKeysWithValues: conflicts.map { ($0.eventId, $0) })
        for conflict in newConflicts {
            merged[conflict.eventId] = conflict
        }
        conflicts = merged.values.sorted { $0.eventId < $1.eventId }
        backupEvents = newBackupEvents.sorted { $0.timestamp > $1.timestamp }
        persist()
    }

    func resolve(eventId: String) {
        conflicts.removeAll { $0.eventId == eventId }
        if conflicts.isEmpty {
            backupEvents = []
        }
        persist()
    }

    @discardableResult
    func rollback(using store: EventStore) -> Bool {
        guard !backupEvents.isEmpty else { return false }
        store.replaceAll(with: backupEvents)
        clear()
        return true
    }

    func clear() {
        conflicts = []
        backupEvents = []
        persist()
    }

    private func load() {
        if let data = defaults.data(forKey: conflictsKey),
           let decoded = try? JSONDecoder().decode([SyncConflict].self, from: data) {
            conflicts = decoded
        }
        if let data = defaults.data(forKey: backupEventsKey),
           let decoded = try? JSONDecoder().decode([AppEvent].self, from: data) {
            backupEvents = decoded
        }
    }

    private func persist() {
        if conflicts.isEmpty {
            defaults.removeObject(forKey: conflictsKey)
        } else if let data = try? JSONEncoder().encode(conflicts) {
            defaults.set(data, forKey: conflictsKey)
        }

        if backupEvents.isEmpty {
            defaults.removeObject(forKey: backupEventsKey)
        } else if let data = try? JSONEncoder().encode(backupEvents) {
            defaults.set(data, forKey: backupEventsKey)
        }
    }
}
