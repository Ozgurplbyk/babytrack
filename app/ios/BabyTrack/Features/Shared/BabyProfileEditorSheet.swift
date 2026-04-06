import PhotosUI
import SwiftUI

struct BabyProfileEditorResult {
    let name: String
    let birthDate: Date
    let avatarAssetPath: String
    let newPhotoData: Data?
    let removeCurrentPhoto: Bool
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

struct BabyProfileEditorSheet: View {
    let title: String
    var initialName: String
    var initialBirthDate: Date
    var initialAvatarAssetPath: String
    var initialPhotoFileName: String?
    var initialBiologicalSex: BabyBiologicalSex
    var initialDeliveryType: BirthDeliveryType
    var initialGestationalWeeks: Int?
    var initialBirthWeightKg: Double?
    var initialBirthLengthCm: Double?
    var initialBirthHeadCircumferenceCm: Double?
    var initialBirthTime: Date?
    var initialBirthPlace: String
    var initialBirthHospital: String
    var initialApgar1Min: Int?
    var initialApgar5Min: Int?
    var initialNicuDays: Int?
    var initialBirthNotes: String
    var onSave: (BabyProfileEditorResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var birthDate: Date
    @State private var biologicalSex: BabyBiologicalSex
    @State private var deliveryType: BirthDeliveryType
    @State private var gestationalWeeksText: String
    @State private var birthWeightText: String
    @State private var birthLengthText: String
    @State private var birthHeadText: String
    @State private var hasBirthTime: Bool
    @State private var birthTime: Date
    @State private var birthPlace: String
    @State private var birthHospital: String
    @State private var apgar1Text: String
    @State private var apgar5Text: String
    @State private var nicuDaysText: String
    @State private var birthNotes: String
    @State private var selectedAvatarPath: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var removeCurrentPhoto = false

    init(
        title: String,
        initialName: String = "",
        initialBirthDate: Date = Date(),
        initialAvatarAssetPath: String = BabyAvatarCatalog.fallback,
        initialPhotoFileName: String? = nil,
        initialBiologicalSex: BabyBiologicalSex = .unspecified,
        initialDeliveryType: BirthDeliveryType = .unspecified,
        initialGestationalWeeks: Int? = nil,
        initialBirthWeightKg: Double? = nil,
        initialBirthLengthCm: Double? = nil,
        initialBirthHeadCircumferenceCm: Double? = nil,
        initialBirthTime: Date? = nil,
        initialBirthPlace: String = "",
        initialBirthHospital: String = "",
        initialApgar1Min: Int? = nil,
        initialApgar5Min: Int? = nil,
        initialNicuDays: Int? = nil,
        initialBirthNotes: String = "",
        onSave: @escaping (BabyProfileEditorResult) -> Void
    ) {
        self.title = title
        self.initialName = initialName
        self.initialBirthDate = initialBirthDate
        self.initialAvatarAssetPath = initialAvatarAssetPath
        self.initialPhotoFileName = initialPhotoFileName
        self.initialBiologicalSex = initialBiologicalSex
        self.initialDeliveryType = initialDeliveryType
        self.initialGestationalWeeks = initialGestationalWeeks
        self.initialBirthWeightKg = initialBirthWeightKg
        self.initialBirthLengthCm = initialBirthLengthCm
        self.initialBirthHeadCircumferenceCm = initialBirthHeadCircumferenceCm
        self.initialBirthTime = initialBirthTime
        self.initialBirthPlace = initialBirthPlace
        self.initialBirthHospital = initialBirthHospital
        self.initialApgar1Min = initialApgar1Min
        self.initialApgar5Min = initialApgar5Min
        self.initialNicuDays = initialNicuDays
        self.initialBirthNotes = initialBirthNotes
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _birthDate = State(initialValue: initialBirthDate)
        _biologicalSex = State(initialValue: initialBiologicalSex)
        _deliveryType = State(initialValue: initialDeliveryType)
        _gestationalWeeksText = State(initialValue: initialGestationalWeeks.map(String.init) ?? "")
        _birthWeightText = State(initialValue: Self.formatMetric(initialBirthWeightKg))
        _birthLengthText = State(initialValue: Self.formatMetric(initialBirthLengthCm))
        _birthHeadText = State(initialValue: Self.formatMetric(initialBirthHeadCircumferenceCm))
        _hasBirthTime = State(initialValue: initialBirthTime != nil)
        _birthTime = State(initialValue: initialBirthTime ?? Date())
        _birthPlace = State(initialValue: initialBirthPlace)
        _birthHospital = State(initialValue: initialBirthHospital)
        _apgar1Text = State(initialValue: initialApgar1Min.map(String.init) ?? "")
        _apgar5Text = State(initialValue: initialApgar5Min.map(String.init) ?? "")
        _nicuDaysText = State(initialValue: initialNicuDays.map(String.init) ?? "")
        _birthNotes = State(initialValue: initialBirthNotes)
        _selectedAvatarPath = State(initialValue: initialAvatarAssetPath)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("family_avatar_section")) {
                    avatarPreview

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(L10n.tr("family_avatar_pick_photo"), systemImage: "photo.on.rectangle")
                    }

                    if hasVisiblePhoto {
                        Button(role: .destructive) {
                            selectedPhotoData = nil
                            selectedPhotoItem = nil
                            removeCurrentPhoto = true
                            Haptics.warning()
                        } label: {
                            Label(L10n.tr("family_avatar_remove_photo"), systemImage: "trash")
                        }
                    }
                }

                Section(L10n.tr("family_avatar_choose_ready")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(BabyAvatarCatalog.generatedPaths, id: \.self) { path in
                                Button {
                                    selectedAvatarPath = path
                                    selectedPhotoData = nil
                                    selectedPhotoItem = nil
                                    removeCurrentPhoto = true
                                    Haptics.light()
                                } label: {
                                    ZStack(alignment: .bottomTrailing) {
                                        GeneratedImageView(relativePath: path, contentMode: .fill)
                                            .frame(width: 64, height: 64)
                                            .clipShape(Circle())

                                        if selectedAvatarPath == path && !hasVisiblePhoto {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                                .background(.white, in: Circle())
                                        }
                                    }
                                    .overlay(
                                        Circle()
                                            .strokeBorder(selectedAvatarPath == path && !hasVisiblePhoto ? Color.accentColor : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section {
                    TextField(L10n.tr("baby_profile_name_label"), text: $name)
                    DatePicker(L10n.tr("baby_profile_birth_date_label"), selection: $birthDate, displayedComponents: .date)
                }

                Section(L10n.tr("baby_profile_birth_details_section")) {
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

                    Text(L10n.tr("baby_profile_birth_details_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("common_save")) {
                        onSave(
                            BabyProfileEditorResult(
                                name: name,
                                birthDate: birthDate,
                                avatarAssetPath: selectedAvatarPath,
                                newPhotoData: selectedPhotoData,
                                removeCurrentPhoto: removeCurrentPhoto,
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
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task(id: selectedPhotoItem) {
                guard let item = selectedPhotoItem else { return }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    selectedPhotoData = data
                    removeCurrentPhoto = false
                    Haptics.light()
                }
            }
        }
    }

    private var hasVisiblePhoto: Bool {
        if selectedPhotoData != nil {
            return true
        }
        guard let initialPhotoFileName else {
            return false
        }
        return !removeCurrentPhoto && BabyAvatarStorage.loadImage(fileName: initialPhotoFileName) != nil
    }

    private var avatarPreview: some View {
        HStack(spacing: 14) {
            Group {
                if let selectedPhotoData,
                   let image = UIImage(data: selectedPhotoData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let initialPhotoFileName,
                          !removeCurrentPhoto,
                          let image = BabyAvatarStorage.loadImage(fileName: initialPhotoFileName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    GeneratedImageView(relativePath: selectedAvatarPath, contentMode: .fill)
                }
            }
            .frame(width: 74, height: 74)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.75), lineWidth: 2)
            )

            Text(L10n.tr("family_avatar_preview_help"))
                .font(.footnote)
                .foregroundStyle(.secondary)
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

    private static func formatMetric(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(1)))
    }
}
