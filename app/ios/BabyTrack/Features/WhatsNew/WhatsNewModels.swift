import Foundation

struct WhatsNewRelease: Codable {
    let version: String
    let releaseDate: String
    let highlights: [String]

    static let placeholder = WhatsNewRelease(
        version: "1.0.0",
        releaseDate: "2026-02-26",
        highlights: [
            "Yeni hizli kayit merkezi",
            "Ulkeye gore ninni listesi",
            "Beyaz/Kahverengi/Fon gurultusu"
        ]
    )
}

struct WhatsNewReleaseLoader {
    static func loadLatestRelease() -> WhatsNewRelease {
        guard let url = Bundle.main.url(forResource: "changelog_latest", withExtension: "json", subdirectory: "Config") else {
            return .placeholder
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(WhatsNewRelease.self, from: data)
        } catch {
            return .placeholder
        }
    }
}
