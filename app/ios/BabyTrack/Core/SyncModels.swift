import Foundation

struct SyncEnvelope: Codable {
    let countryCode: String
    let appVersion: String
    let events: [AppEvent]
}

struct SyncResult: Codable {
    let acceptedCount: Int
    let rejectedCount: Int
    let conflicts: [SyncConflict]

    private enum CodingKeys: String, CodingKey {
        case acceptedCount
        case rejectedCount
        case conflicts
    }

    init(acceptedCount: Int, rejectedCount: Int, conflicts: [SyncConflict] = []) {
        self.acceptedCount = acceptedCount
        self.rejectedCount = rejectedCount
        self.conflicts = conflicts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        acceptedCount = try container.decode(Int.self, forKey: .acceptedCount)
        rejectedCount = try container.decode(Int.self, forKey: .rejectedCount)
        conflicts = try container.decodeIfPresent([SyncConflict].self, forKey: .conflicts) ?? []
    }
}

struct SyncConflict: Codable, Identifiable {
    let eventId: String
    let reason: String
    let remoteEvent: AppEvent?

    private enum CodingKeys: String, CodingKey {
        case eventId
        case reason
        case remoteEvent
    }

    init(eventId: String, reason: String, remoteEvent: AppEvent? = nil) {
        self.eventId = eventId
        self.reason = reason
        self.remoteEvent = remoteEvent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventId = try container.decode(String.self, forKey: .eventId)
        reason = try container.decode(String.self, forKey: .reason)
        remoteEvent = try? container.decode(AppEvent.self, forKey: .remoteEvent)
    }

    var id: String { eventId }
}

struct ConflictResolvePayload: Encodable {
    let eventId: String
    let strategy: String
    let countryCode: String
    let appVersion: String
    let localEvent: AppEvent?
    let mergedEvent: AppEvent?
}

struct ConflictResolveResult: Codable {
    let ok: Bool
    let strategy: String
    let event: AppEvent?
}

enum SyncConflictStrategy: String, CaseIterable, Identifiable {
    case keepLocal = "keep_local"
    case keepRemote = "keep_remote"
    case merge

    var id: String { rawValue }
}
