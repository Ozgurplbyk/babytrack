import Foundation

enum LengthUnitPreference: String, CaseIterable, Codable {
    case cm
    case inch
}

enum WeightUnitPreference: String, CaseIterable, Codable {
    case kg
    case lb
}

enum TemperatureUnitPreference: String, CaseIterable, Codable {
    case celsius
    case fahrenheit
}

enum VolumeUnitPreference: String, CaseIterable, Codable {
    case ml
    case oz
}

struct UnitProfile: Codable, Equatable {
    var length: LengthUnitPreference
    var weight: WeightUnitPreference
    var temperature: TemperatureUnitPreference
    var volume: VolumeUnitPreference

    static func defaults(for countryCode: String) -> UnitProfile {
        switch countryCode.uppercased() {
        case "US":
            return UnitProfile(length: .inch, weight: .lb, temperature: .fahrenheit, volume: .oz)
        case "GB":
            return UnitProfile(length: .cm, weight: .kg, temperature: .celsius, volume: .ml)
        case "DE", "TR":
            return UnitProfile(length: .cm, weight: .kg, temperature: .celsius, volume: .ml)
        default:
            return UnitProfile(length: .cm, weight: .kg, temperature: .celsius, volume: .ml)
        }
    }
}

final class UnitProfileStore {
    private let key = "units.profile.v1"

    func load(defaultCountry: String) -> UnitProfile {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(UnitProfile.self, from: data) else {
            return UnitProfile.defaults(for: defaultCountry)
        }
        return decoded
    }

    func save(_ profile: UnitProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
