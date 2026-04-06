import Foundation

enum ForumModerationResult: Equatable {
    case allow
    case reject(reasonKey: String)
}

enum ForumModeration {
    // App-side guardrail; server-side validation is authoritative.
    private static let blockedTerms: [String] = [
        "hate", "violence", "kill", "spam", "scam", "abuse"
    ]

    static func validatePost(title: String, body: String) -> ForumModerationResult {
        let normalizedTitle = normalize(title)
        let normalizedBody = normalize(body)

        if normalizedBody.count < 3 {
            return .reject(reasonKey: "forum_error_body_short")
        }
        if normalizedBody.count > 1_200 {
            return .reject(reasonKey: "forum_error_body_long")
        }

        let combined = normalizedTitle + " " + normalizedBody
        if blockedTerms.contains(where: { combined.contains($0) }) {
            return .reject(reasonKey: "forum_error_blocked_terms")
        }

        return .allow
    }

    static func parseTags(_ raw: String) -> [String] {
        var seen = Set<String>()
        var tags: [String] = []
        for token in raw.split(separator: ",") {
            let normalized = normalize(String(token))
            guard !normalized.isEmpty else { continue }
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            tags.append(normalized)
            if tags.count >= 6 {
                break
            }
        }
        return tags
    }

    static func normalize(_ value: String) -> String {
        let locale = Locale(identifier: "en_US_POSIX")
        return value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: locale)
    }
}
