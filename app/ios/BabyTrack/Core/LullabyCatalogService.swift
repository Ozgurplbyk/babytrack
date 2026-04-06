import Foundation

final class LullabyCatalogService {
    static let shared = LullabyCatalogService()
    private let vocalKeywords = ["vocal", "lyrics", "lyric", "song", "sing", "voice", "sozlu", "sözlü", "sarki", "şarkı"]

    private init() {}

    func loadCatalog() -> LullabyCatalog {
        guard let url = Bundle.main.url(forResource: "lullaby_catalog", withExtension: "json", subdirectory: "Config") else {
            return LullabyCatalog(version: "missing", countries: [])
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(LullabyCatalog.self, from: data)
        } catch {
            return LullabyCatalog(version: "decode_error", countries: [])
        }
    }

    func topTen(for countryCode: String) -> [LullabyTrack] {
        let catalog = loadCatalog()
        let normalized = normalizeCountryCode(countryCode)
        let fallbackLocale = normalizeCountryCode(Locale.current.regionCode ?? "TR")
        let candidates = [normalized, fallbackLocale, "TR"]
            .reduce(into: [String]()) { partial, code in
                if !partial.contains(code) {
                    partial.append(code)
                }
            }

        for code in candidates {
            if let set = catalog.countries.first(where: { normalizeCountryCode($0.countryCode) == code }) {
                let curated = curateTopTen(from: set.topLullabies)
                if !curated.isEmpty {
                    return curated
                }
            }
        }

        return curateTopTen(from: catalog.countries.first?.topLullabies ?? [])
    }

    private func normalizeCountryCode(_ code: String) -> String {
        let upper = code.uppercased()
        return upper == "UK" ? "GB" : upper
    }

    private func curateTopTen(from tracks: [LullabyTrack]) -> [LullabyTrack] {
        var seenTitles = Set<String>()
        var seenPaths = Set<String>()
        var seenIds = Set<String>()

        let curated = tracks
            .filter { isInstrumentalWordless($0) }
            .filter { track in
                let pathKey = track.audioAssetPath.lowercased()
                if seenIds.contains(track.id) || seenTitles.contains(track.normalizedTitle) || seenPaths.contains(pathKey) {
                    return false
                }
                seenIds.insert(track.id)
                seenTitles.insert(track.normalizedTitle)
                seenPaths.insert(pathKey)
                return true
            }
            .sorted {
                if $0.popularityRank == $1.popularityRank {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.popularityRank < $1.popularityRank
            }

        return Array(curated.prefix(10))
    }

    private func isInstrumentalWordless(_ track: LullabyTrack) -> Bool {
        let mergedText = [track.sourceType, track.notes, track.title]
            .joined(separator: " ")
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()

        let hasVocalHints = vocalKeywords.contains { mergedText.contains($0) }
        if hasVocalHints {
            return false
        }

        if let isInstrumental = track.isInstrumental {
            return isInstrumental
        }

        return mergedText.contains("instrumental") || mergedText.contains("wordless")
    }
}
