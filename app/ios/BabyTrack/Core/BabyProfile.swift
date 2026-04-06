import Foundation

enum BabyBiologicalSex: String, Codable, CaseIterable {
    case unspecified
    case female
    case male
    case other

    var titleKey: String {
        switch self {
        case .unspecified:
            return "baby_profile_gender_unspecified"
        case .female:
            return "baby_profile_gender_female"
        case .male:
            return "baby_profile_gender_male"
        case .other:
            return "baby_profile_gender_other"
        }
    }
}

enum BirthDeliveryType: String, Codable, CaseIterable {
    case unspecified
    case vaginal
    case cesarean
    case other

    var titleKey: String {
        switch self {
        case .unspecified:
            return "baby_profile_delivery_unspecified"
        case .vaginal:
            return "baby_profile_delivery_vaginal"
        case .cesarean:
            return "baby_profile_delivery_cesarean"
        case .other:
            return "baby_profile_delivery_other"
        }
    }
}

struct BabyProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var birthDate: Date
    var avatarAssetPath: String
    var photoFileName: String?
    var biologicalSex: BabyBiologicalSex
    var deliveryType: BirthDeliveryType
    var gestationalWeeks: Int?
    var birthWeightKg: Double?
    var birthLengthCm: Double?
    var birthHeadCircumferenceCm: Double?
    var birthTime: Date?
    var birthPlace: String
    var birthHospital: String
    var apgar1Min: Int?
    var apgar5Min: Int?
    var nicuDays: Int?
    var birthNotes: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        birthDate: Date = Date(),
        avatarAssetPath: String? = nil,
        photoFileName: String? = nil,
        biologicalSex: BabyBiologicalSex = .unspecified,
        deliveryType: BirthDeliveryType = .unspecified,
        gestationalWeeks: Int? = nil,
        birthWeightKg: Double? = nil,
        birthLengthCm: Double? = nil,
        birthHeadCircumferenceCm: Double? = nil,
        birthTime: Date? = nil,
        birthPlace: String = "",
        birthHospital: String = "",
        apgar1Min: Int? = nil,
        apgar5Min: Int? = nil,
        nicuDays: Int? = nil,
        birthNotes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.avatarAssetPath = avatarAssetPath ?? BabyAvatarCatalog.defaultPath(for: id)
        self.photoFileName = photoFileName
        self.biologicalSex = biologicalSex
        self.deliveryType = deliveryType
        self.gestationalWeeks = gestationalWeeks
        self.birthWeightKg = birthWeightKg
        self.birthLengthCm = birthLengthCm
        self.birthHeadCircumferenceCm = birthHeadCircumferenceCm
        self.birthTime = birthTime
        self.birthPlace = birthPlace
        self.birthHospital = birthHospital
        self.apgar1Min = apgar1Min
        self.apgar5Min = apgar5Min
        self.nicuDays = nicuDays
        self.birthNotes = birthNotes
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case birthDate
        case avatarAssetPath
        case photoFileName
        case biologicalSex
        case deliveryType
        case gestationalWeeks
        case birthWeightKg
        case birthLengthCm
        case birthHeadCircumferenceCm
        case birthTime
        case birthPlace
        case birthHospital
        case apgar1Min
        case apgar5Min
        case nicuDays
        case birthNotes
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedId = try container.decode(UUID.self, forKey: .id)
        id = decodedId
        name = try container.decode(String.self, forKey: .name)
        birthDate = try container.decode(Date.self, forKey: .birthDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        avatarAssetPath = try container.decodeIfPresent(String.self, forKey: .avatarAssetPath) ?? BabyAvatarCatalog.defaultPath(for: decodedId)
        photoFileName = try container.decodeIfPresent(String.self, forKey: .photoFileName)
        biologicalSex = try container.decodeIfPresent(BabyBiologicalSex.self, forKey: .biologicalSex) ?? .unspecified
        deliveryType = try container.decodeIfPresent(BirthDeliveryType.self, forKey: .deliveryType) ?? .unspecified
        gestationalWeeks = try container.decodeIfPresent(Int.self, forKey: .gestationalWeeks)
        birthWeightKg = try container.decodeIfPresent(Double.self, forKey: .birthWeightKg)
        birthLengthCm = try container.decodeIfPresent(Double.self, forKey: .birthLengthCm)
        birthHeadCircumferenceCm = try container.decodeIfPresent(Double.self, forKey: .birthHeadCircumferenceCm)
        birthTime = try container.decodeIfPresent(Date.self, forKey: .birthTime)
        birthPlace = try container.decodeIfPresent(String.self, forKey: .birthPlace) ?? ""
        birthHospital = try container.decodeIfPresent(String.self, forKey: .birthHospital) ?? ""
        apgar1Min = try container.decodeIfPresent(Int.self, forKey: .apgar1Min)
        apgar5Min = try container.decodeIfPresent(Int.self, forKey: .apgar5Min)
        nicuDays = try container.decodeIfPresent(Int.self, forKey: .nicuDays)
        birthNotes = try container.decodeIfPresent(String.self, forKey: .birthNotes) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(birthDate, forKey: .birthDate)
        try container.encode(avatarAssetPath, forKey: .avatarAssetPath)
        try container.encodeIfPresent(photoFileName, forKey: .photoFileName)
        try container.encode(biologicalSex, forKey: .biologicalSex)
        try container.encode(deliveryType, forKey: .deliveryType)
        try container.encodeIfPresent(gestationalWeeks, forKey: .gestationalWeeks)
        try container.encodeIfPresent(birthWeightKg, forKey: .birthWeightKg)
        try container.encodeIfPresent(birthLengthCm, forKey: .birthLengthCm)
        try container.encodeIfPresent(birthHeadCircumferenceCm, forKey: .birthHeadCircumferenceCm)
        try container.encodeIfPresent(birthTime, forKey: .birthTime)
        try container.encode(birthPlace, forKey: .birthPlace)
        try container.encode(birthHospital, forKey: .birthHospital)
        try container.encodeIfPresent(apgar1Min, forKey: .apgar1Min)
        try container.encodeIfPresent(apgar5Min, forKey: .apgar5Min)
        try container.encodeIfPresent(nicuDays, forKey: .nicuDays)
        try container.encode(birthNotes, forKey: .birthNotes)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

final class BabyProfileStore {
    private let fileName = "baby_profiles_v1.json"

    func load() -> [BabyProfile] {
        let url = storeURL()
        guard let data = try? Data(contentsOf: url) else { return [] }
        guard let decoded = try? JSONDecoder().decode([BabyProfile].self, from: data) else { return [] }
        return decoded.sorted { $0.createdAt < $1.createdAt }
    }

    func save(_ profiles: [BabyProfile]) {
        let url = storeURL()
        do {
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: url, options: [.atomic])
        } catch {
            // non-fatal
        }
    }

    func defaultProfile() -> BabyProfile {
        BabyProfile(name: "Bebekim", birthDate: Date())
    }

    private func storeURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(fileName)
    }
}
