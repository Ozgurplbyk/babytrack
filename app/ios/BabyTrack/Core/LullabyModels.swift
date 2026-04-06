import Foundation

struct LullabyCatalog: Codable {
    let version: String
    let countries: [CountryLullabySet]
}

struct CountryLullabySet: Codable {
    let countryCode: String
    let displayName: String
    let topLullabies: [LullabyTrack]
}

struct LullabyTrack: Codable, Identifiable {
    let id: String
    let title: String
    let popularityRank: Int
    let audioAssetPath: String
    let sourceType: String
    let notes: String
    let isInstrumental: Bool?

    var normalizedTitle: String {
        title
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
