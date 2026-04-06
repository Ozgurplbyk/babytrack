import Foundation
import SwiftUI

enum SchoolTravelMode: String, CaseIterable, Codable, Identifiable {
    case school
    case travel

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .school:
            return "school_travel_mode_school"
        case .travel:
            return "school_travel_mode_travel"
        }
    }

    static func templateItems(for mode: SchoolTravelMode) -> [String] {
        switch mode {
        case .school:
            return [
                "school_travel_template_school_1",
                "school_travel_template_school_2",
                "school_travel_template_school_3",
                "school_travel_template_school_4"
            ]
        case .travel:
            return [
                "school_travel_template_travel_1",
                "school_travel_template_travel_2",
                "school_travel_template_travel_3",
                "school_travel_template_travel_4"
            ]
        }
    }
}

enum GrowthMetric: String, CaseIterable, Identifiable {
    case weight
    case length
    case head

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: return L10n.tr("health_field_weight")
        case .length: return L10n.tr("health_field_length")
        case .head: return L10n.tr("health_field_head")
        }
    }

    var color: Color {
        switch self {
        case .weight: return .blue
        case .length: return .mint
        case .head: return .purple
        }
    }

    func unitLabel(unitProfile: UnitProfile) -> String {
        switch self {
        case .weight:
            return unitProfile.weight == .kg ? "kg" : "lb"
        case .length, .head:
            return unitProfile.length == .cm ? "cm" : "in"
        }
    }
}

enum HealthGrowthLogic {
    static func referenceRange(metric: GrowthMetric, ageMonth: Int, unitProfile: UnitProfile) -> ClosedRange<Double> {
        switch metric {
        case .weight:
            let month = max(ageMonth, 0)
            let medianKg = month <= 6 ? (3.3 + Double(month) * 0.65) : (7.2 + Double(month - 6) * 0.25)
            return convertWeight(medianKg * 0.8, unitProfile: unitProfile)...convertWeight(medianKg * 1.2, unitProfile: unitProfile)
        case .length:
            let month = max(ageMonth, 0)
            let medianCm = month <= 6 ? (50.0 + Double(month) * 2.5) : (65.0 + Double(month - 6) * 1.2)
            return convertLength(medianCm * 0.92, unitProfile: unitProfile)...convertLength(medianCm * 1.08, unitProfile: unitProfile)
        case .head:
            let month = max(ageMonth, 0)
            let medianCm = month <= 6 ? (35.0 + Double(month) * 1.2) : (42.2 + Double(month - 6) * 0.5)
            return convertLength(medianCm * 0.94, unitProfile: unitProfile)...convertLength(medianCm * 1.06, unitProfile: unitProfile)
        }
    }

    static func isOutsideReference(metric: GrowthMetric, value: Double, ageMonth: Int, unitProfile: UnitProfile) -> Bool {
        !referenceRange(metric: metric, ageMonth: ageMonth, unitProfile: unitProfile).contains(value)
    }

    private static func convertWeight(_ kg: Double, unitProfile: UnitProfile) -> Double {
        switch unitProfile.weight {
        case .kg:
            return kg
        case .lb:
            return kg * 2.20462
        }
    }

    private static func convertLength(_ cm: Double, unitProfile: UnitProfile) -> Double {
        switch unitProfile.length {
        case .cm:
            return cm
        case .inch:
            return cm / 2.54
        }
    }
}

enum HealthTriageLevel: String, CaseIterable, Identifiable {
    case green
    case yellow
    case red

    var id: String { rawValue }

    var titleKey: String {
        "health_triage_level_\(rawValue)"
    }

    var guidanceKey: String {
        "health_triage_guidance_\(rawValue)"
    }

    var icon: String {
        switch self {
        case .green: return "checkmark.shield.fill"
        case .yellow: return "exclamationmark.triangle.fill"
        case .red: return "cross.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }
}

enum HealthHistoryMode: String, CaseIterable, Identifiable {
    case recent
    case date
    case babyMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent:
            return L10n.tr("timeline_history_recent")
        case .date:
            return L10n.tr("timeline_history_date_short")
        case .babyMonth:
            return L10n.tr("timeline_history_baby_month_short")
        }
    }
}

enum HealthHistoryLogic {
    static func filterEvents(
        from events: [AppEvent],
        mode: HealthHistoryMode,
        historyDate: Date,
        historyBabyMonth: Int,
        birthDate: Date?,
        calendar: Calendar = .current,
        recentLimit: Int = 10
    ) -> [AppEvent] {
        switch mode {
        case .recent:
            return Array(events.prefix(recentLimit))
        case .date:
            return events.filter { calendar.isDate($0.timestamp, inSameDayAs: historyDate) }
        case .babyMonth:
            guard let birthDate else { return Array(events.prefix(recentLimit)) }
            return events.filter {
                let month = max(calendar.dateComponents([.month], from: birthDate, to: $0.timestamp).month ?? 0, 0)
                return month == historyBabyMonth
            }
        }
    }

    static func availableMonthCount(
        birthDate: Date?,
        now: Date = Date(),
        calendar: Calendar = .current,
        fallback: Int = 36
    ) -> Int {
        guard let birthDate else { return fallback }
        return max(calendar.dateComponents([.month], from: birthDate, to: now).month ?? 0, 0)
    }
}

struct RecommendedVaccine: Identifiable {
    let id: String
    let name: String
    let dueLabel: String
    let minAgeDays: Int?

    init(id: String? = nil, name: String, dueLabel: String, minAgeDays: Int? = nil) {
        self.id = id ?? name
        self.name = name
        self.dueLabel = dueLabel
        self.minAgeDays = minAgeDays
    }
}

struct CachedVaccinePackage: Codable {
    let countryCode: String
    let authority: String
    let version: String
    let fetchedAt: Date
    let sourceURL: String?
    let sourceUpdatedAt: String?
    let publishedAt: String?
    let records: [VaccinePackageRecord]

    var isFresh: Bool {
        let age = Date().timeIntervalSince(fetchedAt)
        return age <= (24 * 60 * 60)
    }
}

enum VaccinePackageCache {
    static func load(countryCode: String) -> CachedVaccinePackage? {
        let key = storageKey(countryCode: countryCode)
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(CachedVaccinePackage.self, from: data) else {
            return nil
        }
        return decoded
    }

    static func save(
        countryCode: String,
        authority: String,
        version: String,
        records: [VaccinePackageRecord],
        sourceURL: String?,
        sourceUpdatedAt: String?,
        publishedAt: String?
    ) {
        let key = storageKey(countryCode: countryCode)
        let payload = CachedVaccinePackage(
            countryCode: countryCode.uppercased(),
            authority: authority,
            version: version,
            fetchedAt: Date(),
            sourceURL: sourceURL,
            sourceUpdatedAt: sourceUpdatedAt,
            publishedAt: publishedAt,
            records: records
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func storageKey(countryCode: String) -> String {
        "vaccine.remote.cache.\(countryCode.uppercased())"
    }
}

enum VaccineScheduleCatalog {
    static func schedule(for countryCode: String) -> [RecommendedVaccine] {
        switch countryCode.uppercased() {
        case "TR":
            return [
                .init(name: "HepB", dueLabel: L10n.tr("vaccine_due_catalog_birth"), minAgeDays: 0),
                .init(name: "BCG", dueLabel: L10n.tr("vaccine_due_catalog_2_months"), minAgeDays: 60),
                .init(name: "DaBT-IPA-Hib", dueLabel: L10n.tr("vaccine_due_catalog_2_4_6_18_months"), minAgeDays: 60),
                .init(name: "KPA", dueLabel: L10n.tr("vaccine_due_catalog_2_4_12_months"), minAgeDays: 60),
                .init(name: "MMR", dueLabel: L10n.tr("vaccine_due_catalog_12_months"), minAgeDays: 360)
            ]
        case "US":
            return [
                .init(name: "HepB", dueLabel: L10n.tr("vaccine_due_catalog_birth_1_2_6_months"), minAgeDays: 0),
                .init(name: "DTaP", dueLabel: L10n.tr("vaccine_due_catalog_2_4_6_15_18_months"), minAgeDays: 60),
                .init(name: "Hib", dueLabel: L10n.tr("vaccine_due_catalog_2_4_6_12_15_months"), minAgeDays: 60),
                .init(name: "PCV", dueLabel: L10n.tr("vaccine_due_catalog_2_4_6_12_15_months"), minAgeDays: 60),
                .init(name: "MMR", dueLabel: L10n.tr("vaccine_due_catalog_12_15_months"), minAgeDays: 360)
            ]
        case "GB":
            return [
                .init(name: "6-in-1", dueLabel: L10n.tr("vaccine_due_catalog_8_12_16_weeks"), minAgeDays: 56),
                .init(name: "MenB", dueLabel: L10n.tr("vaccine_due_catalog_8_16_weeks_1_year"), minAgeDays: 56),
                .init(name: "PCV", dueLabel: L10n.tr("vaccine_due_catalog_12_weeks_1_year"), minAgeDays: 84),
                .init(name: "MMR", dueLabel: L10n.tr("vaccine_due_catalog_1_year"), minAgeDays: 360),
                .init(name: "Hib/MenC", dueLabel: L10n.tr("vaccine_due_catalog_1_year"), minAgeDays: 360)
            ]
        case "DE":
            return [
                .init(name: "6-fach", dueLabel: L10n.tr("vaccine_due_catalog_2_4_11_months"), minAgeDays: 60),
                .init(name: "Rotavirus", dueLabel: L10n.tr("vaccine_due_catalog_2_3_4_months"), minAgeDays: 60),
                .init(name: "Pneumokokken", dueLabel: L10n.tr("vaccine_due_catalog_2_4_11_months"), minAgeDays: 60),
                .init(name: "MMR", dueLabel: L10n.tr("vaccine_due_catalog_11_15_months"), minAgeDays: 330),
                .init(name: "Varizellen", dueLabel: L10n.tr("vaccine_due_catalog_11_15_months"), minAgeDays: 330)
            ]
        case "FR":
            return [
                .init(name: "Hexavalent", dueLabel: L10n.tr("vaccine_due_catalog_2_4_11_months"), minAgeDays: 60),
                .init(name: "PCV", dueLabel: L10n.tr("vaccine_due_catalog_2_4_11_months"), minAgeDays: 60),
                .init(name: "MMR", dueLabel: L10n.tr("vaccine_due_catalog_12_months"), minAgeDays: 360)
            ]
        case "ES":
            return [
                .init(name: "Hexavalente", dueLabel: L10n.tr("vaccine_due_catalog_2_4_11_months"), minAgeDays: 60),
                .init(name: "Neumococo", dueLabel: L10n.tr("vaccine_due_catalog_2_4_11_months"), minAgeDays: 60),
                .init(name: "MMR", dueLabel: L10n.tr("vaccine_due_catalog_12_months"), minAgeDays: 360)
            ]
        case "IT":
            return [
                .init(name: "Esavalente", dueLabel: L10n.tr("vaccine_due_catalog_2_4_11_months"), minAgeDays: 60),
                .init(name: "Pneumococco", dueLabel: L10n.tr("vaccine_due_catalog_2_4_11_months"), minAgeDays: 60),
                .init(name: "MPR", dueLabel: L10n.tr("vaccine_due_catalog_12_months"), minAgeDays: 360)
            ]
        case "BR":
            return [
                .init(name: "Hepatite B", dueLabel: L10n.tr("vaccine_due_catalog_birth"), minAgeDays: 0),
                .init(name: "Pentavalente", dueLabel: L10n.tr("vaccine_due_catalog_2_4_6_18_months"), minAgeDays: 60),
                .init(name: "Tríplice viral", dueLabel: L10n.tr("vaccine_due_catalog_12_months"), minAgeDays: 360)
            ]
        case "SA":
            return [
                .init(name: "HepB", dueLabel: L10n.tr("vaccine_due_catalog_birth"), minAgeDays: 0),
                .init(name: "Hexavalent", dueLabel: L10n.tr("vaccine_due_catalog_2_4_6_18_months"), minAgeDays: 60),
                .init(name: "MMR", dueLabel: L10n.tr("vaccine_due_catalog_12_months"), minAgeDays: 360)
            ]
        default:
            return []
        }
    }
}
