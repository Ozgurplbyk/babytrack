import SwiftUI

struct AudioHubCard: View {
    let countryCode: String

    @StateObject private var audio = AudioEngine()
    @AppStorage("audio.favorite.ids") private var favoriteIdsRaw = ""
    @State private var category: AudioCategory = .lullabies

    private let noiseItems: [NoiseItem] = [
        .init(id: "noise_white", label: "audio_noise_white", path: "Audio/noise/white_noise"),
        .init(id: "noise_brown", label: "audio_noise_brown", path: "Audio/noise/brown_noise"),
        .init(id: "noise_hair_dryer", label: "audio_noise_hair_dryer", path: "Audio/noise/hair_dryer")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("audio_hub_title"))
                        .font(.headline)
                    Text(L10n.tr("audio_hub_subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    audio.stop()
                } label: {
                    Label(L10n.tr("audio_stop_all"), systemImage: "stop.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }

            Picker("", selection: $category) {
                ForEach(AudioCategory.allCases) { item in
                    Text(L10n.tr(item.titleKey)).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if !favoriteItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("audio_favorites_title"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(favoriteItems) { item in
                        audioRow(
                            id: item.id,
                            title: item.title,
                            subtitle: item.subtitle,
                            path: item.path,
                            analyticsType: item.analyticsType
                        )
                    }
                }
                Divider().padding(.vertical, 2)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(categoryTitle)
                    .font(.subheadline.bold())

                ForEach(visibleItems) { item in
                    audioRow(
                        id: item.id,
                        title: item.title,
                        subtitle: item.subtitle,
                        path: item.path,
                        analyticsType: item.analyticsType
                    )
                }
            }
        }
    }

    private func audioRow(id: String, title: String, subtitle: String, path: String, analyticsType: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                toggleFavorite(id)
            } label: {
                Image(systemName: isFavorite(id) ? "star.fill" : "star")
                    .foregroundStyle(isFavorite(id) ? .yellow : .secondary)
            }
            .buttonStyle(.plain)

            Button(audio.currentlyPlaying == path ? L10n.tr("audio_stop") : L10n.tr("audio_play")) {
                if audio.currentlyPlaying == path {
                    audio.stop()
                } else {
                    audio.play(assetPath: path)
                    AnalyticsTracker.shared.track(.audioPlayed, params: [
                        "audio_type": analyticsType,
                        "audio_id": id,
                        "country": countryCode
                    ])
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var categoryTitle: String {
        switch category {
        case .lullabies:
            return String(format: L10n.tr("audio_top_10_lullabies_format"), countryCode)
        case .comfortSounds:
            return L10n.tr("audio_comfort_sounds_title")
        }
    }

    private var visibleItems: [AudioItem] {
        switch category {
        case .lullabies:
            return LullabyCatalogService.shared.topTen(for: countryCode).map {
                AudioItem(
                    id: $0.id,
                    title: String(format: L10n.tr("audio_lullaby_rank_title_format"), String($0.popularityRank), $0.title),
                    subtitle: $0.sourceType,
                    path: $0.audioAssetPath,
                    analyticsType: "lullaby"
                )
            }
        case .comfortSounds:
            return noiseItems.map { item in
                AudioItem(
                    id: item.id,
                    title: L10n.tr(item.label),
                    subtitle: L10n.tr("audio_comfort_sound_subtitle"),
                    path: item.path,
                    analyticsType: "noise"
                )
            }
        }
    }

    private var favoriteItems: [AudioItem] {
        visibleItems.filter { isFavorite($0.id) }
    }

    private var favoriteIds: Set<String> {
        Set(
            favoriteIdsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    private func isFavorite(_ id: String) -> Bool {
        favoriteIds.contains(id)
    }

    private func toggleFavorite(_ id: String) {
        var current = favoriteIds
        if current.contains(id) {
            current.remove(id)
        } else {
            current.insert(id)
        }
        favoriteIdsRaw = current.sorted().joined(separator: ",")
    }
}

private enum AudioCategory: String, CaseIterable, Identifiable {
    case lullabies
    case comfortSounds

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .lullabies:
            return "audio_category_lullabies"
        case .comfortSounds:
            return "audio_category_comfort_sounds"
        }
    }
}

private struct NoiseItem {
    let id: String
    let label: String
    let path: String
}

private struct AudioItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let path: String
    let analyticsType: String
}
