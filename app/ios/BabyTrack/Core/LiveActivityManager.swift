import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

struct ActiveCareSession: Codable, Identifiable, Equatable {
    let id: UUID
    let childId: String
    let childName: String
    let type: EventType
    let startedAt: Date
}

@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    private var currentActivity: Any?

    private init() {}

    func start(session: ActiveCareSession) {
#if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            if let currentActivity = currentActivity as? Activity<CareSessionAttributes> {
                await currentActivity.end(nil, dismissalPolicy: .immediate)
            }
            for activity in Activity<CareSessionAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            let attributes = CareSessionAttributes(
                childName: session.childName,
                sessionType: session.type.rawValue,
                sessionId: session.id.uuidString
            )
            let state = CareSessionAttributes.ContentState(
                title: session.type.title,
                subtitle: L10n.tr("care_session_live_subtitle"),
                startedAt: session.startedAt
            )

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: state, staleDate: Date().addingTimeInterval(60 * 60 * 12)),
                    pushType: nil
                )
                currentActivity = activity
            } catch {
                currentActivity = nil
            }
        }
#endif
    }

    func update(subtitle: String) async {
#if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        guard let currentActivity = currentActivity as? Activity<CareSessionAttributes> else { return }
        let state = CareSessionAttributes.ContentState(
            title: currentActivity.content.state.title,
            subtitle: subtitle,
            startedAt: currentActivity.content.state.startedAt
        )
        await currentActivity.update(.init(state: state, staleDate: Date().addingTimeInterval(60 * 60 * 12)))
#endif
    }

    func end() async {
#if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        guard let currentActivity = currentActivity as? Activity<CareSessionAttributes> else { return }
        await currentActivity.end(nil, dismissalPolicy: .immediate)
        self.currentActivity = nil
#endif
    }
}

@MainActor
final class CareSessionManager: ObservableObject {
    static let shared = CareSessionManager()

    enum StartResult {
        case started
        case alreadyRunningSame
        case blockedByAnother
    }

    @Published private(set) var activeSession: ActiveCareSession?

    private let storageKey = "care_session.active.v1"
    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {
        loadSession()
        if let activeSession {
            LiveActivityManager.shared.start(session: activeSession)
        }
    }

    @discardableResult
    func startSession(type: EventType, childId: String, childName: String) -> StartResult {
        if let running = activeSession {
            if running.type == type && running.childId == childId {
                LiveActivityManager.shared.start(session: running)
                return .alreadyRunningSame
            }
            return .blockedByAnother
        }

        let session = ActiveCareSession(
            id: UUID(),
            childId: childId,
            childName: childName,
            type: type,
            startedAt: Date()
        )
        activeSession = session
        persistSession()
        LiveActivityManager.shared.start(session: session)
        return .started
    }

    func elapsedSeconds(for session: ActiveCareSession? = nil, now: Date = Date()) -> Int {
        guard let target = session ?? activeSession else { return 0 }
        return max(Int(now.timeIntervalSince(target.startedAt)), 0)
    }

    func elapsedMinutes(for session: ActiveCareSession? = nil, now: Date = Date()) -> Int {
        let seconds = elapsedSeconds(for: session, now: now)
        return max(Int(ceil(Double(seconds) / 60.0)), 1)
    }

    @discardableResult
    func stopSession() -> ActiveCareSession? {
        guard let session = activeSession else { return nil }
        activeSession = nil
        persistSession()
        Task {
            await LiveActivityManager.shared.end()
        }
        return session
    }

    func stopAndBuildEvent(
        note: String = "",
        visibility: AppEvent.Visibility = .family,
        endedAt: Date = Date()
    ) -> AppEvent? {
        guard let session = stopSession() else { return nil }
        return buildEvent(from: session, note: note, visibility: visibility, endedAt: endedAt)
    }

    func buildEvent(
        from session: ActiveCareSession,
        note: String = "",
        visibility: AppEvent.Visibility = .family,
        endedAt: Date = Date()
    ) -> AppEvent {
        var payload: [String: String] = [
            "source": "live_timer",
            "duration_min": "\(elapsedMinutes(for: session, now: endedAt))",
            "started_at": Self.iso8601.string(from: session.startedAt),
            "ended_at": Self.iso8601.string(from: endedAt)
        ]
        payload["session_type"] = session.type.rawValue

        return AppEvent(
            childId: session.childId,
            type: session.type,
            timestamp: endedAt,
            note: note,
            payload: payload,
            visibility: visibility
        )
    }

    private func loadSession() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(ActiveCareSession.self, from: data) else {
            activeSession = nil
            return
        }
        activeSession = decoded
    }

    private func persistSession() {
        guard let activeSession else {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }
        if let data = try? JSONEncoder().encode(activeSession) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
