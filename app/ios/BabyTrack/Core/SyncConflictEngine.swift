import Foundation

struct SyncConflictDiffLine: Identifiable, Equatable {
    let id: String
    let title: String
    let localValue: String
    let remoteValue: String

    init(id: String, title: String, localValue: String, remoteValue: String) {
        self.id = id
        self.title = title
        self.localValue = localValue
        self.remoteValue = remoteValue
    }
}

enum SyncConflictEngine {
    static func merge(local: AppEvent?, remote: AppEvent?, eventId: String) -> AppEvent? {
        guard let base = local ?? remote else { return nil }
        let resolvedId = UUID(uuidString: eventId) ?? base.id

        var mergedPayload = remote?.payload ?? [:]
        for (key, value) in (local?.payload ?? [:]) {
            mergedPayload[key] = value
        }

        let localNote = normalized(local?.note ?? "")
        let remoteNote = normalized(remote?.note ?? "")
        let mergedNote: String
        if localNote.isEmpty {
            mergedNote = remoteNote
        } else if remoteNote.isEmpty || remoteNote == localNote {
            mergedNote = localNote
        } else {
            mergedNote = localNote + "\n" + remoteNote
        }

        return AppEvent(
            id: resolvedId,
            childId: local?.childId ?? remote?.childId ?? base.childId,
            type: local?.type ?? remote?.type ?? base.type,
            timestamp: max(local?.timestamp ?? .distantPast, remote?.timestamp ?? .distantPast),
            note: mergedNote,
            payload: mergedPayload,
            visibility: local?.visibility ?? remote?.visibility ?? base.visibility
        )
    }

    static func diff(local: AppEvent?, remote: AppEvent?) -> [SyncConflictDiffLine] {
        guard local != nil || remote != nil else { return [] }
        var lines: [SyncConflictDiffLine] = []

        let localType = local?.type.title ?? "-"
        let remoteType = remote?.type.title ?? "-"
        if localType != remoteType {
            lines.append(.init(id: "type", title: L10n.tr("sync_conflict_diff_type"), localValue: localType, remoteValue: remoteType))
        }

        let localTime = local?.timestamp.formatted(date: .abbreviated, time: .shortened) ?? "-"
        let remoteTime = remote?.timestamp.formatted(date: .abbreviated, time: .shortened) ?? "-"
        if localTime != remoteTime {
            lines.append(.init(id: "time", title: L10n.tr("sync_conflict_diff_time"), localValue: localTime, remoteValue: remoteTime))
        }

        let localNote = normalized(local?.note ?? "")
        let remoteNote = normalized(remote?.note ?? "")
        if localNote != remoteNote {
            lines.append(.init(id: "note", title: L10n.tr("sync_conflict_diff_note"), localValue: localNote.isEmpty ? "-" : localNote, remoteValue: remoteNote.isEmpty ? "-" : remoteNote))
        }

        let localPayload = local?.payload ?? [:]
        let remotePayload = remote?.payload ?? [:]
        let keys = Set(localPayload.keys).union(remotePayload.keys)
        for key in keys.sorted() {
            let left = normalized(localPayload[key] ?? "")
            let right = normalized(remotePayload[key] ?? "")
            if left != right {
                lines.append(
                    .init(
                        id: "payload_\(key)",
                        title: String(format: L10n.tr("sync_conflict_diff_payload_format"), key),
                        localValue: left.isEmpty ? "-" : left,
                        remoteValue: right.isEmpty ? "-" : right
                    )
                )
            }
        }

        return lines
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
