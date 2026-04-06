import SwiftUI

struct ProfileSetupResult {
    let name: String
    let birthDate: Date
    let avatarAssetPath: String?
    let photoData: Data?
    let biologicalSex: BabyBiologicalSex
    let deliveryType: BirthDeliveryType
    let gestationalWeeks: Int?
    let birthWeightKg: Double?
    let birthLengthCm: Double?
    let birthHeadCircumferenceCm: Double?
    let birthTime: Date?
    let birthPlace: String
    let birthHospital: String
    let apgar1Min: Int?
    let apgar5Min: Int?
    let nicuDays: Int?
    let birthNotes: String
}

struct ProfileSetupView: View {
    var onComplete: (ProfileSetupResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var birthDate: Date = Date()
    @State private var selectedAvatar: String = BabyAvatarCatalog.fallback
    @State private var biologicalSex: BabyBiologicalSex = .unspecified
    @State private var deliveryType: BirthDeliveryType = .unspecified
    @State private var gestationalWeeksText: String = ""
    @State private var birthWeightText: String = ""
    @State private var birthLengthText: String = ""
    @State private var birthHeadText: String = ""
    @State private var hasBirthTime = false
    @State private var birthTime = Date()
    @State private var birthPlace: String = ""
    @State private var birthHospital: String = ""
    @State private var apgar1Text: String = ""
    @State private var apgar5Text: String = ""
    @State private var nicuDaysText: String = ""
    @State private var birthNotes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(L10n.tr("profile_setup_title"))) {
                    TextField(L10n.tr("baby_profile_name_label"), text: $name)
                    DatePicker(L10n.tr("baby_profile_birth_date_label"), selection: $birthDate, displayedComponents: .date)
                }

                Section(header: Text(L10n.tr("profile_setup_birth_details_title"))) {
                    Picker(L10n.tr("baby_profile_gender_label"), selection: $biologicalSex) {
                        ForEach(BabyBiologicalSex.allCases, id: \.self) { option in
                            Text(L10n.tr(option.titleKey)).tag(option)
                        }
                    }
                    Picker(L10n.tr("baby_profile_delivery_type_label"), selection: $deliveryType) {
                        ForEach(BirthDeliveryType.allCases, id: \.self) { option in
                            Text(L10n.tr(option.titleKey)).tag(option)
                        }
                    }
                    TextField(L10n.tr("baby_profile_gestation_weeks_label"), text: $gestationalWeeksText)
                        .keyboardType(.numberPad)
                    TextField(L10n.tr("baby_profile_birth_weight_label"), text: $birthWeightText)
                        .keyboardType(.decimalPad)
                    TextField(L10n.tr("baby_profile_birth_length_label"), text: $birthLengthText)
                        .keyboardType(.decimalPad)
                    TextField(L10n.tr("baby_profile_birth_head_label"), text: $birthHeadText)
                        .keyboardType(.decimalPad)
                    Toggle(L10n.tr("baby_profile_birth_time_toggle"), isOn: $hasBirthTime)
                    if hasBirthTime {
                        DatePicker(
                            L10n.tr("baby_profile_birth_time_label"),
                            selection: $birthTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                    TextField(L10n.tr("baby_profile_birth_place_label"), text: $birthPlace)
                    TextField(L10n.tr("baby_profile_birth_hospital_label"), text: $birthHospital)
                    TextField(L10n.tr("baby_profile_apgar_1_label"), text: $apgar1Text)
                        .keyboardType(.numberPad)
                    TextField(L10n.tr("baby_profile_apgar_5_label"), text: $apgar5Text)
                        .keyboardType(.numberPad)
                    TextField(L10n.tr("baby_profile_nicu_days_label"), text: $nicuDaysText)
                        .keyboardType(.numberPad)
                    TextField(L10n.tr("baby_profile_birth_notes_label"), text: $birthNotes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section(header: Text(L10n.tr("profile_setup_avatar_title"))) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(BabyAvatarCatalog.generatedPaths, id: \.self) { path in
                                Button {
                                    selectedAvatar = path
                                } label: {
                                    GeneratedImageView(relativePath: path, contentMode: .fill)
                                        .frame(width: 64, height: 64)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .strokeBorder(selectedAvatar == path ? Color.accentColor : Color.clear, lineWidth: 3)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle(L10n.tr("profile_setup_nav_title"))
            .interactiveDismissDisabled(true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("common_continue")) {
                        let result = ProfileSetupResult(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            birthDate: birthDate,
                            avatarAssetPath: selectedAvatar,
                            photoData: nil,
                            biologicalSex: biologicalSex,
                            deliveryType: deliveryType,
                            gestationalWeeks: Self.parseInt(gestationalWeeksText),
                            birthWeightKg: Self.parseDouble(birthWeightText),
                            birthLengthCm: Self.parseDouble(birthLengthText),
                            birthHeadCircumferenceCm: Self.parseDouble(birthHeadText),
                            birthTime: hasBirthTime ? birthTime : nil,
                            birthPlace: birthPlace.trimmingCharacters(in: .whitespacesAndNewlines),
                            birthHospital: birthHospital.trimmingCharacters(in: .whitespacesAndNewlines),
                            apgar1Min: Self.parseInt(apgar1Text),
                            apgar5Min: Self.parseInt(apgar5Text),
                            nicuDays: Self.parseInt(nicuDaysText),
                            birthNotes: birthNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        onComplete(result)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private static func parseDouble(_ raw: String) -> Double? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private static func parseInt(_ raw: String) -> Int? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return Int(normalized)
    }
}
