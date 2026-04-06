import Foundation

enum BackendError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case conflict
    case notFound
    case missingAPIKey
}

final class BackendClient {
    static let shared = BackendClient()

    private let baseURL = URL(string: "http://127.0.0.1:8787")
    private let apiToken = (Bundle.main.infoDictionary?["BABYTRACK_API_TOKEN"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    private let defaults = UserDefaults.standard
    private let syncDeviceIdKey = "backend_sync_device_id_v1"

    private init() {}

    private var geminiAPIKey: String {
        if let direct = (Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !direct.isEmpty {
            return direct
        }

        if let firebasePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let firebase = NSDictionary(contentsOfFile: firebasePath),
           let api = (firebase["API_KEY"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !api.isEmpty {
            return api
        }

        return ""
    }

    private func syncDeviceId() -> String {
        if let existing = defaults.string(forKey: syncDeviceIdKey),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }
        let newValue = UUID().uuidString.lowercased()
        defaults.set(newValue, forKey: syncDeviceIdKey)
        return newValue
    }

    private func syncNonce() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        if !apiToken.isEmpty {
            req.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func userAuthorizedRequest(url: URL, userToken: String, method: String = "GET") -> URLRequest {
        var req = authorizedRequest(url: url, method: method)
        req.setValue(userToken, forHTTPHeaderField: "X-BabyTrack-User-Token")
        return req
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw BackendError.invalidResponse }
        if http.statusCode == 401 { throw BackendError.unauthorized }
        if http.statusCode == 403 { throw BackendError.forbidden }
        if http.statusCode == 404 { throw BackendError.notFound }
        if http.statusCode == 409 { throw BackendError.conflict }
        guard http.statusCode == 200 else { throw BackendError.invalidResponse }
    }

    func fetchPaywallOffers() async throws -> Data {
        guard let url = baseURL?.appending(path: "/v1/config/paywall") else { throw BackendError.invalidURL }
        let req = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return data
    }

    func sync(events: [AppEvent], countryCode: String) async throws -> SyncResult {
        guard let url = baseURL?.appending(path: "/v1/events/sync") else { throw BackendError.invalidURL }

        let payload = SyncEnvelope(countryCode: countryCode, appVersion: appVersion(), events: events)

        var req = authorizedRequest(url: url, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(syncDeviceId(), forHTTPHeaderField: "X-BabyTrack-Device-Id")
        req.setValue(syncNonce(), forHTTPHeaderField: "X-BabyTrack-Nonce")
        req.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)

        return try JSONDecoder().decode(SyncResult.self, from: data)
    }

    func resolveSyncConflict(
        eventId: String,
        strategy: SyncConflictStrategy,
        localEvent: AppEvent? = nil,
        mergedEvent: AppEvent? = nil,
        countryCode: String
    ) async throws -> ConflictResolveResult {
        guard let url = baseURL?.appending(path: "/v1/events/conflicts/resolve") else { throw BackendError.invalidURL }

        let payload = ConflictResolvePayload(
            eventId: eventId,
            strategy: strategy.rawValue,
            countryCode: countryCode,
            appVersion: appVersion(),
            localEvent: localEvent,
            mergedEvent: mergedEvent
        )

        var req = authorizedRequest(url: url, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(syncDeviceId(), forHTTPHeaderField: "X-BabyTrack-Device-Id")
        req.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(ConflictResolveResult.self, from: data)
    }

    func fetchLatestVaccinePackage(countryCode: String) async throws -> VaccinePackagePayload {
        let cc = countryCode.uppercased()
        guard let url = baseURL?.appending(path: "/v1/vaccines/packages/\(cc)/latest") else {
            throw BackendError.invalidURL
        }
        let req = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        let envelope = try JSONDecoder().decode(VaccinePackageEnvelope.self, from: data)
        return envelope.payload
    }

    func fetchVaccinePackageIndex() async throws -> VaccinePackageIndexResponse {
        guard let url = baseURL?.appending(path: "/v1/vaccines/packages/index") else {
            throw BackendError.invalidURL
        }
        let req = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(VaccinePackageIndexResponse.self, from: data)
    }

    func registerUser(email: String, password: String, displayName: String) async throws -> AuthSessionEnvelope {
        guard let url = baseURL?.appending(path: "/v1/auth/register") else { throw BackendError.invalidURL }
        var req = authorizedRequest(url: url, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(AuthRequestPayload(email: email, password: password, displayName: displayName))
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(AuthSessionEnvelope.self, from: data)
    }

    func loginUser(email: String, password: String) async throws -> AuthSessionEnvelope {
        guard let url = baseURL?.appending(path: "/v1/auth/login") else { throw BackendError.invalidURL }
        var req = authorizedRequest(url: url, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(AuthRequestPayload(email: email, password: password, displayName: nil))
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(AuthSessionEnvelope.self, from: data)
    }

    func fetchCurrentUser(userToken: String) async throws -> AuthMeEnvelope {
        guard let url = baseURL?.appending(path: "/v1/auth/me") else { throw BackendError.invalidURL }
        let req = userAuthorizedRequest(url: url, userToken: userToken)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(AuthMeEnvelope.self, from: data)
    }

    func logoutUser(userToken: String) async throws {
        guard let url = baseURL?.appending(path: "/v1/auth/logout") else { throw BackendError.invalidURL }
        let req = userAuthorizedRequest(url: url, userToken: userToken, method: "POST")
        let (_, response) = try await URLSession.shared.data(for: req)
        try validate(response)
    }

    func fetchFamilyInvites(childId: String, userToken: String) async throws -> FamilyInvitesEnvelope {
        guard let url = baseURL?.appending(path: "/v1/family/\(childId)/invites") else { throw BackendError.invalidURL }
        let req = userAuthorizedRequest(url: url, userToken: userToken)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(FamilyInvitesEnvelope.self, from: data)
    }

    func createFamilyInvite(childId: String, role: String, displayName: String, userToken: String) async throws -> FamilyInviteEnvelope {
        guard let url = baseURL?.appending(path: "/v1/family/\(childId)/invites") else { throw BackendError.invalidURL }
        var req = userAuthorizedRequest(url: url, userToken: userToken, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(FamilyInviteCreatePayload(role: role, displayName: displayName))
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(FamilyInviteEnvelope.self, from: data)
    }

    func joinFamilyInvite(code: String, userToken: String) async throws -> FamilyInviteEnvelope {
        guard let url = baseURL?.appending(path: "/v1/family/invites/join") else { throw BackendError.invalidURL }
        var req = userAuthorizedRequest(url: url, userToken: userToken, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(FamilyInviteJoinPayload(code: code))
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(FamilyInviteEnvelope.self, from: data)
    }

    func updateFamilyInviteStatus(inviteId: String, status: String, userToken: String) async throws -> FamilyInviteEnvelope {
        guard let url = baseURL?.appending(path: "/v1/family/invites/\(inviteId)/status") else { throw BackendError.invalidURL }
        var req = userAuthorizedRequest(url: url, userToken: userToken, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(FamilyInviteStatusPayload(status: status))
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(FamilyInviteEnvelope.self, from: data)
    }

    func deleteFamilyInvite(inviteId: String, userToken: String) async throws {
        guard let url = baseURL?.appending(path: "/v1/family/invites/\(inviteId)") else { throw BackendError.invalidURL }
        let req = userAuthorizedRequest(url: url, userToken: userToken, method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: req)
        try validate(response)
    }

    func fetchForumPosts(countryCode: String, userToken: String, limit: Int = 30) async throws -> ForumPostsEnvelope {
        guard let url = baseURL?.appending(path: "/v1/forum/posts"),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw BackendError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "countryCode", value: countryCode.uppercased()),
            URLQueryItem(name: "limit", value: "\(max(1, min(limit, 100)))")
        ]
        guard let url = components.url else { throw BackendError.invalidURL }
        let req = userAuthorizedRequest(url: url, userToken: userToken)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(ForumPostsEnvelope.self, from: data)
    }

    func createForumPost(
        title: String,
        body: String,
        tags: [String],
        countryCode: String,
        childId: String,
        userToken: String
    ) async throws -> ForumPostEnvelope {
        guard let url = baseURL?.appending(path: "/v1/forum/posts") else { throw BackendError.invalidURL }
        var req = userAuthorizedRequest(url: url, userToken: userToken, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(
            ForumPostCreatePayload(
                title: title,
                body: body,
                tags: tags,
                countryCode: countryCode.uppercased(),
                childId: childId
            )
        )
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(ForumPostEnvelope.self, from: data)
    }

    func fetchForumComments(postId: String, userToken: String, limit: Int = 80) async throws -> ForumCommentsEnvelope {
        guard let url = baseURL?.appending(path: "/v1/forum/posts/\(postId)/comments"),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw BackendError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "limit", value: "\(max(1, min(limit, 300)))")]
        guard let url = components.url else { throw BackendError.invalidURL }
        let req = userAuthorizedRequest(url: url, userToken: userToken)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(ForumCommentsEnvelope.self, from: data)
    }

    func createForumComment(postId: String, body: String, userToken: String) async throws -> ForumCommentEnvelope {
        guard let url = baseURL?.appending(path: "/v1/forum/posts/\(postId)/comments") else { throw BackendError.invalidURL }
        var req = userAuthorizedRequest(url: url, userToken: userToken, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(ForumCommentCreatePayload(body: body))
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(ForumCommentEnvelope.self, from: data)
    }

    func setForumReaction(postId: String, reaction: String, active: Bool, userToken: String) async throws -> ForumReactionEnvelope {
        guard let url = baseURL?.appending(path: "/v1/forum/posts/\(postId)/reactions") else { throw BackendError.invalidURL }
        var req = userAuthorizedRequest(url: url, userToken: userToken, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(ForumReactionSetPayload(reaction: reaction, active: active))
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(ForumReactionEnvelope.self, from: data)
    }

    func reportForumPost(postId: String, reason: String, note: String, userToken: String) async throws -> ForumReportEnvelope {
        guard let url = baseURL?.appending(path: "/v1/forum/posts/\(postId)/report") else { throw BackendError.invalidURL }
        var req = userAuthorizedRequest(url: url, userToken: userToken, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(ForumReportCreatePayload(reason: reason, note: note))
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(ForumReportEnvelope.self, from: data)
    }

    func muteForumPost(postId: String, userToken: String) async throws {
        guard let url = baseURL?.appending(path: "/v1/forum/posts/\(postId)/mute") else { throw BackendError.invalidURL }
        let req = userAuthorizedRequest(url: url, userToken: userToken, method: "POST")
        let (_, response) = try await URLSession.shared.data(for: req)
        try validate(response)
    }

    func blockForumUser(targetUserId: String, userToken: String) async throws {
        guard let url = baseURL?.appending(path: "/v1/forum/users/\(targetUserId)/block") else { throw BackendError.invalidURL }
        let req = userAuthorizedRequest(url: url, userToken: userToken, method: "POST")
        let (_, response) = try await URLSession.shared.data(for: req)
        try validate(response)
    }

    func fetchForumAdminReports(status: String = "pending", limit: Int = 40, userToken: String) async throws -> ForumAdminReportsEnvelope {
        guard let url = baseURL?.appending(path: "/v1/forum/admin/reports"),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw BackendError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "status", value: status),
            URLQueryItem(name: "limit", value: "\(max(1, min(limit, 200)))")
        ]
        guard let scopedURL = components.url else { throw BackendError.invalidURL }
        let req = userAuthorizedRequest(url: scopedURL, userToken: userToken)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(ForumAdminReportsEnvelope.self, from: data)
    }

    func resolveForumAdminReport(reportId: String, status: String, userToken: String) async throws -> ForumReportEnvelope {
        guard let url = baseURL?.appending(path: "/v1/forum/admin/reports/\(reportId)/resolve") else { throw BackendError.invalidURL }
        var req = userAuthorizedRequest(url: url, userToken: userToken, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(ForumReportResolvePayload(status: status))
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(ForumReportEnvelope.self, from: data)
    }

    func askGemini(prompt: String, temperature: Double = 0.35, maxTokens: Int = 700) async throws -> String {
        let apiKey = geminiAPIKey
        guard !apiKey.isEmpty else { throw BackendError.missingAPIKey }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)") else {
            throw BackendError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(
            GeminiGenerateRequest(
                contents: [
                    .init(parts: [.init(text: prompt)])
                ],
                generationConfig: .init(
                    temperature: temperature,
                    maxOutputTokens: maxTokens
                )
            )
        )

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw BackendError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw BackendError.invalidResponse }

        let decoded = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
        let text = decoded.candidates
            .first?
            .content?
            .parts?
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !text.isEmpty else { throw BackendError.invalidResponse }
        return text
    }
}

struct VaccinePackageEnvelope: Decodable {
    let payload: VaccinePackagePayload
}

struct VaccinePackageIndexResponse: Decodable {
    let packages: [VaccinePackageIndexItem]
}

struct VaccinePackageIndexItem: Decodable {
    let country: String
    let authority: String
    let version: String
    let updatedAt: String
    let publishedAt: String?
    let sourceName: String?
    let sourceUrl: String?
    let sourceUpdatedAt: String?
}

struct VaccinePackagePayload: Decodable {
    let country: String
    let authority: String
    let version: String
    let source: VaccineSourceInfo?
    let records: [VaccinePackageRecord]
}

struct VaccineSourceInfo: Codable {
    let name: String
    let url: String
    let sourceUpdatedAt: String
    let retrievedAt: String

    private enum CodingKeys: String, CodingKey {
        case name
        case url
        case sourceUpdatedAt = "source_updated_at"
        case retrievedAt = "retrieved_at"
    }
}

struct VaccinePackageRecord: Codable {
    let vaccineCode: String
    let doseNo: Int
    let minAgeDays: Int
    let maxAgeDays: Int?
    let minIntervalDays: Int
    let catchUpRule: String

    private enum CodingKeys: String, CodingKey {
        case vaccineCode = "vaccine_code"
        case doseNo = "dose_no"
        case minAgeDays = "min_age_days"
        case maxAgeDays = "max_age_days"
        case minIntervalDays = "min_interval_days"
        case catchUpRule = "catch_up_rule"
    }
}

struct AuthUserPayload: Codable {
    let id: String
    let email: String
    let displayName: String
    let createdAt: String
}

struct AuthSessionEnvelope: Codable {
    let token: String
    let user: AuthUserPayload
}

struct AuthMeEnvelope: Codable {
    let user: AuthUserPayload
}

private struct AuthRequestPayload: Encodable {
    let email: String
    let password: String
    let displayName: String?
}

struct FamilyInvitePayload: Codable {
    let id: String
    let childId: String
    let role: String
    let displayName: String
    let status: String
    let inviteCode: String
    let createdByUserId: String
    let joinedByUserId: String?
    let createdAt: String
    let joinedAt: String?
}

struct FamilyInvitesEnvelope: Codable {
    let invites: [FamilyInvitePayload]
}

struct FamilyInviteEnvelope: Codable {
    let invite: FamilyInvitePayload
}

private struct FamilyInviteCreatePayload: Encodable {
    let role: String
    let displayName: String
}

private struct FamilyInviteJoinPayload: Encodable {
    let code: String
}

private struct FamilyInviteStatusPayload: Encodable {
    let status: String
}

struct ForumPostPayload: Codable, Identifiable {
    let id: String
    let authorUserId: String
    let authorName: String
    let title: String
    let body: String
    let tags: [String]
    let countryCode: String
    let childId: String
    let createdAt: String
    let updatedAt: String
    let commentCount: Int
    let reactionCount: Int
    let viewerReaction: String
}

struct ForumCommentPayload: Codable, Identifiable {
    let id: String
    let postId: String
    let authorUserId: String
    let authorName: String
    let body: String
    let createdAt: String
}

struct ForumReactionSummaryPayload: Codable {
    let postId: String
    let reactionCount: Int
    let viewerReaction: String
}

struct ForumPostsEnvelope: Codable {
    let posts: [ForumPostPayload]
}

struct ForumPostEnvelope: Codable {
    let post: ForumPostPayload
}

struct ForumCommentsEnvelope: Codable {
    let comments: [ForumCommentPayload]
}

struct ForumCommentEnvelope: Codable {
    let comment: ForumCommentPayload
}

struct ForumReactionEnvelope: Codable {
    let summary: ForumReactionSummaryPayload
}

struct ForumReportPayload: Codable, Identifiable {
    let id: String
    let postId: String
    let reporterUserId: String
    let reason: String
    let note: String
    let status: String
    let createdAt: String
    let resolvedAt: String?
    let resolvedByUserId: String?
}

struct ForumReportEnvelope: Codable {
    let report: ForumReportPayload
}

struct ForumAdminReportsEnvelope: Codable {
    let reports: [ForumReportPayload]
}

private struct ForumPostCreatePayload: Encodable {
    let title: String
    let body: String
    let tags: [String]
    let countryCode: String
    let childId: String
}

private struct ForumCommentCreatePayload: Encodable {
    let body: String
}

private struct ForumReactionSetPayload: Encodable {
    let reaction: String
    let active: Bool
}

private struct ForumReportCreatePayload: Encodable {
    let reason: String
    let note: String
}

private struct ForumReportResolvePayload: Encodable {
    let status: String
}

private struct GeminiGenerateRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

private struct GeminiContent: Encodable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Encodable, Decodable {
    let text: String?
}

private struct GeminiGenerationConfig: Encodable {
    let temperature: Double
    let maxOutputTokens: Int
}

private struct GeminiGenerateResponse: Decodable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Decodable {
    let content: GeminiCandidateContent?
}

private struct GeminiCandidateContent: Decodable {
    let parts: [GeminiPart]?
}
