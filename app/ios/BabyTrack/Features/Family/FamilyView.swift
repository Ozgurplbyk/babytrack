import SwiftUI

struct FamilyView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var storeKit: StoreKitManager
    @EnvironmentObject private var authManager: AuthManager
    @State private var showAddProfile = false
    @State private var editingProfile: BabyProfile?
    @State private var pendingDeleteProfile: BabyProfile?
    @State private var showLastProfileWarning = false
    @State private var showLanguageRegionSettings = false
    @State private var accountDetail: FamilyAccountDetail?
    @State private var animateIn = false
    @State private var heroFloat = false
    @State private var showCommunityForum = false

    private var selectedProfile: BabyProfile? {
        guard let id = appState.selectedBabyId else { return nil }
        return appState.babyProfiles.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        profilesSection
                            .staggerEntrance(show: animateIn, delay: 0.02)
                        accountSection
                            .staggerEntrance(show: animateIn, delay: 0.1)
                        communitySection
                            .staggerEntrance(show: animateIn, delay: 0.14)
                        themeSection
                            .staggerEntrance(show: animateIn, delay: 0.18)
                        unitsSection
                            .staggerEntrance(show: animateIn, delay: 0.24)
                        lullabySoundSection
                            .staggerEntrance(show: animateIn, delay: 0.3)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(L10n.tr("family_title"))
            .onAppear {
                if !animateIn { animateIn = true }
                withAnimation(.easeInOut(duration: 2.7).repeatForever(autoreverses: true)) {
                    heroFloat = true
                }
                consumePendingInviteIfNeeded()
            }
            .onChange(of: appState.pendingFamilyInviteCode) { _ in
                consumePendingInviteIfNeeded()
            }
            .sheet(isPresented: $showAddProfile) {
                BabyProfileEditorSheet(title: L10n.tr("family_add_baby_title")) { result in
                    appState.addBabyProfile(
                        name: result.name,
                        birthDate: result.birthDate,
                        avatarAssetPath: result.avatarAssetPath,
                        photoData: result.newPhotoData,
                        biologicalSex: result.biologicalSex,
                        deliveryType: result.deliveryType,
                        gestationalWeeks: result.gestationalWeeks,
                        birthWeightKg: result.birthWeightKg,
                        birthLengthCm: result.birthLengthCm,
                        birthHeadCircumferenceCm: result.birthHeadCircumferenceCm,
                        birthTime: result.birthTime,
                        birthPlace: result.birthPlace,
                        birthHospital: result.birthHospital,
                        apgar1Min: result.apgar1Min,
                        apgar5Min: result.apgar5Min,
                        nicuDays: result.nicuDays,
                        birthNotes: result.birthNotes
                    )
                }
            }
            .sheet(item: $editingProfile) { profile in
                BabyProfileEditorSheet(
                    title: L10n.tr("family_edit_baby_title"),
                    initialName: profile.name,
                    initialBirthDate: profile.birthDate,
                    initialAvatarAssetPath: profile.avatarAssetPath,
                    initialPhotoFileName: profile.photoFileName,
                    initialBiologicalSex: profile.biologicalSex,
                    initialDeliveryType: profile.deliveryType,
                    initialGestationalWeeks: profile.gestationalWeeks,
                    initialBirthWeightKg: profile.birthWeightKg,
                    initialBirthLengthCm: profile.birthLengthCm,
                    initialBirthHeadCircumferenceCm: profile.birthHeadCircumferenceCm,
                    initialBirthTime: profile.birthTime,
                    initialBirthPlace: profile.birthPlace,
                    initialBirthHospital: profile.birthHospital,
                    initialApgar1Min: profile.apgar1Min,
                    initialApgar5Min: profile.apgar5Min,
                    initialNicuDays: profile.nicuDays,
                    initialBirthNotes: profile.birthNotes
                ) { result in
                    var updated = profile
                    updated.name = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.birthDate = result.birthDate
                    updated.avatarAssetPath = result.avatarAssetPath
                    updated.biologicalSex = result.biologicalSex
                    updated.deliveryType = result.deliveryType
                    updated.gestationalWeeks = result.gestationalWeeks
                    updated.birthWeightKg = result.birthWeightKg
                    updated.birthLengthCm = result.birthLengthCm
                    updated.birthHeadCircumferenceCm = result.birthHeadCircumferenceCm
                    updated.birthTime = result.birthTime
                    updated.birthPlace = result.birthPlace
                    updated.birthHospital = result.birthHospital
                    updated.apgar1Min = result.apgar1Min
                    updated.apgar5Min = result.apgar5Min
                    updated.nicuDays = result.nicuDays
                    updated.birthNotes = result.birthNotes
                    appState.updateBabyProfile(
                        updated,
                        newPhotoData: result.newPhotoData,
                        removeExistingPhoto: result.removeCurrentPhoto
                    )
                }
            }
            .sheet(isPresented: $showLanguageRegionSettings) {
                FamilyLanguageRegionSettingsView(
                    initialLanguageCode: appState.languageCode,
                    initialCountryCode: appState.countryCode
                )
                .environmentObject(appState)
            }
            .sheet(item: $accountDetail) { detail in
                FamilyAccountDetailSheet(
                    detail: detail,
                    isPremium: storeKit.hasActiveSubscription,
                    profiles: appState.babyProfiles,
                    selectedBabyId: appState.selectedBabyId,
                    selectedProfile: selectedProfile,
                    selectedChildId: appState.selectedChildId(),
                    selectedCountryCode: appState.countryCode,
                    allEvents: store.recent(limit: 10_000),
                    onOpenPaywall: { appState.showPaywall = true }
                )
            }
            .sheet(isPresented: $showCommunityForum) {
                CommunityForumView(
                    countryCode: appState.countryCode,
                    childId: appState.selectedChildId()
                )
                .environmentObject(authManager)
            }
            .alert(L10n.tr("family_delete_profile_confirm_title"), isPresented: Binding(
                get: { pendingDeleteProfile != nil },
                set: { if !$0 { pendingDeleteProfile = nil } }
            )) {
                Button(L10n.tr("common_cancel"), role: .cancel) {}
                Button(L10n.tr("common_delete"), role: .destructive) {
                    if let profile = pendingDeleteProfile, appState.deleteBabyProfile(profile.id) {
                        store.deleteAll(for: profile.id.uuidString)
                        Haptics.warning()
                    }
                    pendingDeleteProfile = nil
                }
            } message: {
                Text(L10n.tr("family_delete_profile_irreversible_message"))
            }
            .alert(L10n.tr("family_last_profile_title"), isPresented: $showLastProfileWarning) {
                Button(L10n.tr("common_ok"), role: .cancel) {}
            } message: {
                Text(L10n.tr("family_last_profile_message"))
            }
            .alert(
                L10n.tr("family_role_join_title"),
                isPresented: Binding(
                    get: { appState.familyInviteMessage != nil },
                    set: { if !$0 { appState.familyInviteMessage = nil } }
                )
            ) {
                Button(L10n.tr("common_ok"), role: .cancel) {}
            } message: {
                Text(appState.familyInviteMessage ?? "")
            }
        }
    }

    private func consumePendingInviteIfNeeded() {
        guard let code = appState.pendingFamilyInviteCode,
              !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let token = authManager.sessionToken else {
            appState.familyInviteMessage = L10n.tr("family_role_join_not_found")
            appState.pendingFamilyInviteCode = nil
            return
        }

        Task {
            defer { appState.pendingFamilyInviteCode = nil }
            do {
                _ = try await BackendClient.shared.joinFamilyInvite(code: code, userToken: token)
                appState.familyInviteMessage = L10n.tr("family_role_join_success")
                Haptics.success()
            } catch {
                appState.familyInviteMessage = L10n.tr("family_role_join_not_found")
                Haptics.warning()
            }
        }
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.accentColor.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(0.09))
                .frame(width: 230, height: 230)
                .blur(radius: 52)
                .offset(x: 135, y: -220)
        }
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("family_profiles_section_title"))
                .font(.headline.weight(.bold))

            if appState.babyProfiles.count > 1 {
                BabyProfileQuickSwitcher(
                    profiles: appState.babyProfiles,
                    selectedId: appState.selectedBabyId,
                    compact: false
                ) { id in
                    appState.selectBabyProfile(id)
                    Haptics.light()
                }
            }

            GeneratedImageView(relativePath: "family/roles_hero.png", contentMode: .fill)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .scaleEffect(heroFloat ? 1.025 : 1.0)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.38), lineWidth: 1)
                )

            ForEach(Array(appState.babyProfiles.enumerated()), id: \.element.id) { index, profile in
                profileRow(profile)
                    .staggerEntrance(show: animateIn, delay: 0.08 + Double(index) * 0.03)
            }

        Button {
            let isAddingSecondProfile = appState.babyProfiles.count >= 1
            if isAddingSecondProfile && !storeKit.hasActiveSubscription {
                appState.showPaywall = true
                Haptics.warning()
            } else {
                showAddProfile = true
                Haptics.medium()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text(L10n.tr("family_add_baby_action"))
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(PressableScaleButtonStyle())

        if !storeKit.hasActiveSubscription {
            Label(L10n.tr("family_premium_second_baby_hint"), systemImage: "crown.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }

        if appState.babyProfiles.count > 0 {
            Button {
                accountDetail = .futureLook
                Haptics.light()
            } label: {
                Label(L10n.tr("family_item_future_look"), systemImage: "sparkles.rectangle.stack.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private func profileRow(_ profile: BabyProfile) -> some View {
        let selected = appState.selectedBabyId == profile.id
        return HStack(spacing: 12) {
            BabyAvatarView(profile: profile, size: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name)
                    .font(.headline.weight(.semibold))
                Text(profile.birthDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let detail = profileBirthSummary(profile) {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            }

            Button {
                editingProfile = profile
                Haptics.light()
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            Button {
                requestDelete(profile)
            } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            selected
            ? Color.accentColor.opacity(0.16)
            : Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectBabyProfile(profile.id)
            Haptics.light()
        }
    }

    private func profileBirthSummary(_ profile: BabyProfile) -> String? {
        var parts: [String] = []
        if let weeks = profile.gestationalWeeks {
            parts.append(String(format: L10n.tr("family_birth_detail_weeks_format"), weeks))
        }
        if let weight = profile.birthWeightKg {
            parts.append(String(format: L10n.tr("family_birth_detail_weight_format"), weight))
        }
        if let length = profile.birthLengthCm {
            parts.append(String(format: L10n.tr("family_birth_detail_length_format"), length))
        }
        if let head = profile.birthHeadCircumferenceCm {
            parts.append(String(format: L10n.tr("family_birth_detail_head_format"), head))
        }
        if parts.isEmpty, !profile.birthHospital.isEmpty {
            parts.append(profile.birthHospital)
        } else if parts.isEmpty, !profile.birthPlace.isEmpty {
            parts.append(profile.birthPlace)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("family_section_account"))
                .font(.headline.weight(.bold))

            accountActionRow(
                title: L10n.tr("family_item_language_region"),
                icon: "globe",
                action: {
                    showLanguageRegionSettings = true
                    Haptics.light()
                }
            )
            accountActionRow(title: L10n.tr("family_item_multi_profile"), icon: "person.2.fill") {
                accountDetail = .multiProfile
                Haptics.light()
            }
            accountActionRow(title: L10n.tr("family_item_roles"), icon: "person.3.fill") {
                accountDetail = .roles
                Haptics.light()
            }
            accountActionRow(title: L10n.tr("family_item_privacy"), icon: "lock.shield.fill") {
                accountDetail = .privacy
                Haptics.light()
            }
            accountActionRow(title: L10n.tr("family_item_sharing"), icon: "square.and.arrow.up.fill") {
                accountDetail = .sharing
                Haptics.light()
            }
            accountActionRow(title: L10n.tr("family_item_subscription"), icon: "crown.fill") {
                accountDetail = .subscription
                Haptics.light()
            }
            accountActionRow(title: L10n.tr("family_item_future_look"), icon: "sparkles.rectangle.stack.fill") {
                accountDetail = .futureLook
                Haptics.light()
            }
            Button {
                Task {
                    await authManager.logout()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.red)
                        .frame(width: 30, height: 30)
                        .background(Color.red.opacity(0.16), in: Circle())
                    Text(L10n.tr("auth_logout_action"))
                        .font(.body.weight(.semibold))
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PressableScaleButtonStyle(scale: 0.99, opacity: 0.96))
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.tr("family_item_community"))
                    .font(.headline.weight(.bold))
                Spacer()
                Label(L10n.tr("family_community_badge"), systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(L10n.tr("family_community_subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showCommunityForum = true
                Haptics.light()
            } label: {
                Label(L10n.tr("family_community_open_action"), systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var lullabySoundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.tr("family_audio_section_title"))
                    .font(.headline.weight(.bold))
                Spacer()
                Label(L10n.tr("family_audio_section_badge"), systemImage: "music.note")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            AudioHubCard(countryCode: appState.countryCode)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private func accountRow(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.16), in: Circle())

            Text(title)
                .font(.body.weight(.semibold))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func accountActionRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            accountRow(title: title, icon: icon)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableScaleButtonStyle(scale: 0.99, opacity: 0.96))
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("family_section_theme"))
                .font(.headline.weight(.bold))

            Picker(L10n.tr("family_section_theme"), selection: Binding(
                get: { appState.theme },
                set: { appState.updateTheme($0) }
            )) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("family_section_units"))
                .font(.headline.weight(.bold))

            unitPickerCard(
                title: L10n.tr("settings_units_length"),
                selection: Binding(
                    get: { appState.unitProfile.length },
                    set: { newValue in
                        var profile = appState.unitProfile
                        profile.length = newValue
                        appState.updateUnitProfile(profile)
                    }
                )
            ) {
                Text(L10n.tr("settings_unit_cm")).tag(LengthUnitPreference.cm)
                Text(L10n.tr("settings_unit_in")).tag(LengthUnitPreference.inch)
            }

            unitPickerCard(
                title: L10n.tr("settings_units_weight"),
                selection: Binding(
                    get: { appState.unitProfile.weight },
                    set: { newValue in
                        var profile = appState.unitProfile
                        profile.weight = newValue
                        appState.updateUnitProfile(profile)
                    }
                )
            ) {
                Text(L10n.tr("settings_unit_kg")).tag(WeightUnitPreference.kg)
                Text(L10n.tr("settings_unit_lb")).tag(WeightUnitPreference.lb)
            }

            unitPickerCard(
                title: L10n.tr("settings_units_temperature"),
                selection: Binding(
                    get: { appState.unitProfile.temperature },
                    set: { newValue in
                        var profile = appState.unitProfile
                        profile.temperature = newValue
                        appState.updateUnitProfile(profile)
                    }
                )
            ) {
                Text(L10n.tr("settings_unit_c")).tag(TemperatureUnitPreference.celsius)
                Text(L10n.tr("settings_unit_f")).tag(TemperatureUnitPreference.fahrenheit)
            }

            unitPickerCard(
                title: L10n.tr("settings_units_volume"),
                selection: Binding(
                    get: { appState.unitProfile.volume },
                    set: { newValue in
                        var profile = appState.unitProfile
                        profile.volume = newValue
                        appState.updateUnitProfile(profile)
                    }
                )
            ) {
                Text(L10n.tr("settings_unit_ml")).tag(VolumeUnitPreference.ml)
                Text(L10n.tr("settings_unit_oz")).tag(VolumeUnitPreference.oz)
            }

            Button(L10n.tr("settings_units_reset_default")) {
                appState.resetUnitsForCountryDefault()
                Haptics.light()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .buttonStyle(PressableScaleButtonStyle(scale: 0.99, opacity: 0.9))
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private func unitPickerCard<SelectionValue: Hashable, Content: View>(
        title: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Picker(title, selection: selection, content: content)
                .pickerStyle(.segmented)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func requestDelete(_ profile: BabyProfile) {
        if appState.babyProfiles.count <= 1 {
            showLastProfileWarning = true
            Haptics.warning()
        } else {
            pendingDeleteProfile = profile
            Haptics.warning()
        }
    }
}

private struct FamilyLanguageRegionSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLanguageCode: String
    @State private var selectedCountryCode: String

    private let languages: [FamilyLanguageOption] = [
        .init(code: "tr", titleKey: "language_tr"),
        .init(code: "en", titleKey: "language_en"),
        .init(code: "de", titleKey: "language_de"),
        .init(code: "es", titleKey: "language_es"),
        .init(code: "fr", titleKey: "language_fr"),
        .init(code: "it", titleKey: "language_it"),
        .init(code: "pt-BR", titleKey: "language_pt_br"),
        .init(code: "ar", titleKey: "language_ar")
    ]

    private let countries: [FamilyCountryOption] = [
        .init(code: "TR", titleKey: "country_tr"),
        .init(code: "US", titleKey: "country_us"),
        .init(code: "GB", titleKey: "country_gb"),
        .init(code: "DE", titleKey: "country_de"),
        .init(code: "FR", titleKey: "country_fr"),
        .init(code: "ES", titleKey: "country_es"),
        .init(code: "IT", titleKey: "country_it"),
        .init(code: "BR", titleKey: "country_br"),
        .init(code: "SA", titleKey: "country_sa")
    ]

    init(initialLanguageCode: String, initialCountryCode: String) {
        _selectedLanguageCode = State(initialValue: initialLanguageCode)
        _selectedCountryCode = State(initialValue: initialCountryCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("family_language_region_title")) {
                    Text(L10n.tr("family_language_region_subtitle"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(L10n.tr("onboarding_language_label")) {
                    Picker(L10n.tr("onboarding_language_label"), selection: $selectedLanguageCode) {
                        ForEach(languages) { option in
                            Text(L10n.tr(option.titleKey)).tag(option.code)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(L10n.tr("onboarding_country_label")) {
                    Picker(L10n.tr("onboarding_country_label"), selection: $selectedCountryCode) {
                        ForEach(countries) { option in
                            Text(L10n.tr(option.titleKey)).tag(option.code)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(L10n.tr("family_language_region_history_title")) {
                    if appState.languageRegionHistory.isEmpty {
                        Text(L10n.tr("family_language_region_history_empty"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(appState.languageRegionHistory.prefix(5))) { change in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    String(
                                        format: L10n.tr("family_language_region_history_item_format"),
                                        change.fromLanguageCode.uppercased(),
                                        change.fromCountryCode,
                                        change.toLanguageCode.uppercased(),
                                        change.toCountryCode
                                    )
                                )
                                .font(.subheadline.weight(.semibold))
                                Text(change.changedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        if appState.undoLastLanguageRegionChange() {
                            selectedLanguageCode = appState.languageCode
                            selectedCountryCode = appState.countryCode
                            Haptics.success()
                        } else {
                            Haptics.light()
                        }
                    } label: {
                        Label(L10n.tr("family_language_region_undo_last"), systemImage: "arrow.uturn.backward.circle")
                    }
                    .disabled(appState.languageRegionHistory.isEmpty)
                }
            }
            .navigationTitle(L10n.tr("family_language_region_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("family_language_region_apply")) {
                        appState.updateLanguageAndCountry(selectedLanguageCode, selectedCountryCode)
                        Haptics.success()
                        dismiss()
                    }
                }
            }
        }
    }
}

private enum FamilyAccountDetail: String, Identifiable {
    case multiProfile
    case roles
    case privacy
    case sharing
    case subscription
    case futureLook

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .multiProfile: return "family_item_multi_profile"
        case .roles: return "family_item_roles"
        case .privacy: return "family_item_privacy"
        case .sharing: return "family_item_sharing"
        case .subscription: return "family_item_subscription"
        case .futureLook: return "family_item_future_look"
        }
    }
}

private struct FamilyAccountDetailSheet: View {
    let detail: FamilyAccountDetail
    let isPremium: Bool
    let profiles: [BabyProfile]
    let selectedBabyId: UUID?
    let selectedProfile: BabyProfile?
    let selectedChildId: String
    let selectedCountryCode: String
    let allEvents: [AppEvent]
    let onOpenPaywall: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @AppStorage("family.roles.can_invite") private var canInviteFamily = true
    @AppStorage("family.roles.grandparent_read_only") private var grandparentReadOnly = true
    @AppStorage("family.sharing.auto_export") private var autoExportForDoctor = false
    @AppStorage("family.sharing.hide_sensitive_notes") private var hideSensitiveNotes = true
    @AppStorage("family.privacy.default_visibility") private var defaultVisibilityRaw = AppEvent.Visibility.family.rawValue
    @State private var futureLookResult = ""
    @State private var futureLookLoading = false
    @State private var invites: [FamilyInviteMember] = []
    @State private var inviteRole: FamilyInviteRole = .father
    @State private var inviteName = ""
    @State private var joinInviteCode = ""
    @State private var joinStatusMessage = ""
    @State private var joinStatusSuccess = false
    @State private var recentlySharedInviteId: String?
    @State private var inviteNetworkBusy = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    heroCard

                    switch detail {
                    case .multiProfile:
                        multiProfileContent
                    case .roles:
                        rolesContent
                    case .privacy:
                        privacyContent
                    case .sharing:
                        sharingContent
                    case .subscription:
                        subscriptionContent
                    case .futureLook:
                        futureLookContent
                    }
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.accentColor.opacity(0.045)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle(L10n.tr(detail.titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("common_done")) { dismiss() }
                }
            }
            .onAppear {
                if detail == .roles {
                    Task { await refreshInvites() }
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("family_account_detail_hero_title"))
                .font(.headline.weight(.bold))
            Text(L10n.tr("family_account_detail_hero_subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var multiProfileContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    isPremium ? L10n.tr("family_premium_status_active") : L10n.tr("family_premium_status_inactive"),
                    systemImage: isPremium ? "checkmark.seal.fill" : "crown.fill"
                )
                .font(.headline.weight(.bold))
                .foregroundStyle(isPremium ? .green : .orange)
                Spacer()
                Text(String(format: L10n.tr("family_profiles_count_format"), profiles.count))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if isPremium {
                Text(L10n.tr("family_multi_profile_premium_desc"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                profileCompareGrid
            } else {
                Text(L10n.tr("family_multi_profile_locked_desc"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    onOpenPaywall()
                    dismiss()
                } label: {
                    Label(L10n.tr("family_unlock_premium_action"), systemImage: "sparkles")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(
                                colors: [Color.accentColor, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .buttonStyle(PressableScaleButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var profileCompareGrid: some View {
        VStack(spacing: 10) {
            ForEach(compareProfiles, id: \.profile.id) { item in
                HStack(spacing: 10) {
                    BabyAvatarView(profile: item.profile, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.profile.name)
                            .font(.subheadline.weight(.semibold))
                        Text(
                            String(
                                format: L10n.tr("family_compare_metrics_format"),
                                item.feedingCount,
                                item.sleepCount
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if item.profile.id == selectedBabyId {
                        Text(L10n.tr("family_selected_profile_badge"))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.16), in: Capsule())
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Text(L10n.tr("family_compare_disclaimer"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var rolesContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(L10n.tr("family_role_can_invite"), isOn: $canInviteFamily)
            Toggle(L10n.tr("family_role_grandparent_read_only"), isOn: $grandparentReadOnly)
            Label(L10n.tr("family_role_hint"), systemImage: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 4)

            Text(L10n.tr("family_role_invite_title"))
                .font(.subheadline.weight(.bold))
            Text(L10n.tr("family_role_invite_subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(L10n.tr("family_role_invite_role_label"), selection: $inviteRole) {
                ForEach(FamilyInviteRole.allCases) { role in
                    Text(L10n.tr(role.titleKey)).tag(role)
                }
            }
            .pickerStyle(.menu)

            TextField(L10n.tr("family_role_invite_name_placeholder"), text: $inviteName)

            Button {
                Task { await addInvite() }
            } label: {
                Label(L10n.tr("family_role_invite_action"), systemImage: "person.crop.circle.badge.plus")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canInviteFamily || inviteNetworkBusy)

            Text(L10n.tr("family_role_join_title"))
                .font(.subheadline.weight(.bold))
                .padding(.top, 4)

            HStack(spacing: 8) {
                TextField(L10n.tr("family_role_join_placeholder"), text: $joinInviteCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button(L10n.tr("family_role_join_action")) {
                    Task { await joinByCode() }
                }
                .buttonStyle(.bordered)
                .disabled(inviteNetworkBusy)
            }

            if !joinStatusMessage.isEmpty {
                Label(joinStatusMessage, systemImage: joinStatusSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(joinStatusSuccess ? .green : .orange)
            }

            if invites.isEmpty {
                Text(L10n.tr("family_role_invite_empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(invites) { member in
                        inviteRow(member)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private func inviteRow(_ member: FamilyInviteMember) -> some View {
        let status = member.status
        return HStack(spacing: 10) {
            Image(systemName: status == .joined ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.clock")
                .foregroundStyle(status == .joined ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName.isEmpty ? L10n.tr(member.role.titleKey) : member.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(L10n.tr(member.role.titleKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: L10n.tr("family_role_invite_code_format"), member.inviteCode))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text((member.joinedAt ?? member.createdAt).formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(L10n.tr(status.titleKey))
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(status == .joined ? Color.green.opacity(0.16) : Color.orange.opacity(0.16), in: Capsule())
                .foregroundStyle(status == .joined ? Color.green : Color.orange)

            ShareLink(item: inviteShareMessage(member)) {
                Image(systemName: "square.and.arrow.up")
            }
            .simultaneousGesture(TapGesture().onEnded {
                recentlySharedInviteId = member.id
            })

            Menu {
                Button(member.status == .joined ? L10n.tr("family_role_invite_mark_pending") : L10n.tr("family_role_invite_mark_joined")) {
                    Task { await setInviteJoined(member.id, joined: member.status != .joined) }
                }
                Button(L10n.tr("common_delete"), role: .destructive) {
                    Task { await removeInvite(member.id) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if recentlySharedInviteId == member.id {
                Text(L10n.tr("family_role_invite_shared"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
                    .padding(.bottom, 6)
            }
        }
    }

    private func refreshInvites() async {
        guard detail == .roles else { return }
        guard let token = authManager.sessionToken else { return }
        inviteNetworkBusy = true
        defer { inviteNetworkBusy = false }
        do {
            let envelope = try await BackendClient.shared.fetchFamilyInvites(childId: selectedChildId, userToken: token)
            invites = envelope.invites.map(mapInvite).sorted(by: { $0.createdAt > $1.createdAt })
        } catch {
            // Keeps current in-memory list on transient errors.
        }
    }

    private func addInvite() async {
        guard canInviteFamily else { return }
        guard let token = authManager.sessionToken else { return }
        inviteNetworkBusy = true
        defer { inviteNetworkBusy = false }

        let trimmed = inviteName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let envelope = try await BackendClient.shared.createFamilyInvite(
                childId: selectedChildId,
                role: inviteRole.rawValue,
                displayName: trimmed,
                userToken: token
            )
            let member = mapInvite(envelope.invite)
            invites.removeAll(where: { $0.id == member.id })
            invites.insert(member, at: 0)
            inviteName = ""
            Haptics.success()
        } catch {
            joinStatusMessage = L10n.tr("family_role_join_not_found")
            joinStatusSuccess = false
        }
    }

    private func setInviteJoined(_ id: String, joined: Bool) async {
        guard let token = authManager.sessionToken else { return }
        inviteNetworkBusy = true
        defer { inviteNetworkBusy = false }

        do {
            let envelope = try await BackendClient.shared.updateFamilyInviteStatus(
                inviteId: id,
                status: joined ? "joined" : "pending",
                userToken: token
            )
            let member = mapInvite(envelope.invite)
            if let index = invites.firstIndex(where: { $0.id == id }) {
                invites[index] = member
            } else {
                invites.insert(member, at: 0)
            }
        } catch {
            // no-op
        }
    }

    private func removeInvite(_ id: String) async {
        guard let token = authManager.sessionToken else { return }
        inviteNetworkBusy = true
        defer { inviteNetworkBusy = false }

        do {
            try await BackendClient.shared.deleteFamilyInvite(inviteId: id, userToken: token)
            invites.removeAll(where: { $0.id == id })
            if recentlySharedInviteId == id {
                recentlySharedInviteId = nil
            }
        } catch {
            // no-op
        }
    }

    private func inviteShareMessage(_ member: FamilyInviteMember) -> String {
        let displayName = member.displayName.isEmpty ? L10n.tr(member.role.titleKey) : member.displayName
        let deepLink = "babytrack://family/join?child=\(selectedChildId)&code=\(member.inviteCode)"
        return String(format: L10n.tr("family_role_invite_share_format"), displayName, member.inviteCode) + "\n" + deepLink
    }

    private func joinByCode() async {
        let trimmed = joinInviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else {
            joinStatusMessage = L10n.tr("family_role_join_empty")
            joinStatusSuccess = false
            return
        }
        guard let token = authManager.sessionToken else {
            joinStatusMessage = L10n.tr("family_role_join_not_found")
            joinStatusSuccess = false
            return
        }
        inviteNetworkBusy = true
        defer { inviteNetworkBusy = false }
        do {
            let envelope = try await BackendClient.shared.joinFamilyInvite(code: trimmed, userToken: token)
            let member = mapInvite(envelope.invite)
            if let index = invites.firstIndex(where: { $0.id == member.id }) {
                invites[index] = member
            } else {
                invites.insert(member, at: 0)
            }
            joinStatusMessage = L10n.tr("family_role_join_success")
            joinStatusSuccess = true
            joinInviteCode = ""
            Haptics.success()
            await refreshInvites()
        } catch {
            joinStatusMessage = L10n.tr("family_role_join_not_found")
            joinStatusSuccess = false
        }
    }

    private func mapInvite(_ payload: FamilyInvitePayload) -> FamilyInviteMember {
        FamilyInviteMember(
            id: payload.id,
            role: FamilyInviteRole(rawValue: payload.role) ?? .caregiver,
            displayName: payload.displayName,
            status: FamilyInviteStatus(rawValue: payload.status) ?? .pending,
            createdAt: isoDate(payload.createdAt) ?? Date(),
            inviteCode: payload.inviteCode,
            joinedAt: isoDate(payload.joinedAt)
        )
    }

    private func isoDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("family_privacy_default_visibility"))
                .font(.subheadline.weight(.semibold))
            Picker("", selection: Binding(
                get: { defaultVisibility },
                set: { defaultVisibilityRaw = $0.rawValue }
            )) {
                Text(L10n.tr("event_editor_visibility_family")).tag(AppEvent.Visibility.family)
                Text(L10n.tr("event_editor_visibility_parents_only")).tag(AppEvent.Visibility.parentsOnly)
                Text(L10n.tr("event_editor_visibility_private")).tag(AppEvent.Visibility.`private`)
            }
            .pickerStyle(.segmented)

            Label(L10n.tr("family_privacy_hint"), systemImage: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var sharingContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(L10n.tr("family_sharing_auto_export"), isOn: $autoExportForDoctor)
            Toggle(L10n.tr("family_sharing_hide_sensitive"), isOn: $hideSensitiveNotes)

            ShareLink(item: sharingPreview) {
                Label(L10n.tr("family_sharing_preview_action"), systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var subscriptionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                isPremium ? L10n.tr("family_premium_status_active") : L10n.tr("family_premium_status_inactive"),
                systemImage: isPremium ? "checkmark.seal.fill" : "crown.fill"
            )
            .font(.headline.weight(.bold))
            .foregroundStyle(isPremium ? .green : .orange)

            Text(isPremium ? L10n.tr("family_subscription_active_desc") : L10n.tr("family_subscription_inactive_desc"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                onOpenPaywall()
                dismiss()
            } label: {
                Text(isPremium ? L10n.tr("family_manage_subscription_action") : L10n.tr("family_unlock_premium_action"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .buttonStyle(PressableScaleButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var compareProfiles: [ProfileCompareRow] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date().addingTimeInterval(-7 * 24 * 60 * 60)
        return profiles.map { profile in
            let childId = profile.id.uuidString
            let events = allEvents.filter { $0.childId == childId && $0.timestamp >= weekAgo }
            let feedingCount = events.filter { $0.type.isFeedingRelated }.count
            let sleepCount = events.filter { $0.type == .sleep }.count
            return ProfileCompareRow(profile: profile, feedingCount: feedingCount, sleepCount: sleepCount)
        }
    }

    private var sharingPreview: String {
        let events = allEvents.filter { $0.childId == selectedChildId }.prefix(10)
        let lines = events.map { event in
            let base = "\(event.type.title) • \(event.timestamp.formatted(date: .abbreviated, time: .shortened))"
            if hideSensitiveNotes { return base }
            return event.note.isEmpty ? base : "\(base) • \(event.note)"
        }
        return lines.joined(separator: "\n")
    }

    private var defaultVisibility: AppEvent.Visibility {
        AppEvent.Visibility(rawValue: defaultVisibilityRaw) ?? .family
    }

    private var futureLookStorageKey: String {
        "family.future_look.\(selectedProfile?.id.uuidString ?? selectedChildId)"
    }

    private var futureLookContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isPremium {
                Label(L10n.tr("family_premium_status_inactive"), systemImage: "crown.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.orange)

                Text(L10n.tr("family_future_locked_desc"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    onOpenPaywall()
                    dismiss()
                } label: {
                    Text(L10n.tr("family_unlock_premium_action"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(
                                colors: [Color.accentColor, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .buttonStyle(PressableScaleButtonStyle())
            } else {
                if let selectedProfile {
                    HStack(spacing: 10) {
                        BabyAvatarView(profile: selectedProfile, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedProfile.name)
                                .font(.subheadline.weight(.semibold))
                            Text(selectedProfile.birthDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                Button {
                    Task { await generateFutureLook() }
                } label: {
                    HStack {
                        if futureLookLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(L10n.tr("family_future_generate_action"))
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(PressableScaleButtonStyle())
                .disabled(futureLookLoading)

                if futureLookResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(L10n.tr("family_future_empty"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(futureLookResult)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ShareLink(item: futureLookResult) {
                        Label(L10n.tr("family_future_share_action"), systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text(L10n.tr("family_future_disclaimer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            futureLookResult = UserDefaults.standard.string(forKey: futureLookStorageKey) ?? ""
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private func generateFutureLook() async {
        futureLookLoading = true
        defer { futureLookLoading = false }

        let prompt = buildFutureLookPrompt()
        if let remote = try? await BackendClient.shared.askGemini(prompt: prompt, temperature: 0.6, maxTokens: 700),
           !remote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            futureLookResult = remote
        } else {
            futureLookResult = localFutureLookFallback()
        }
        UserDefaults.standard.set(futureLookResult, forKey: futureLookStorageKey)
    }

    private func buildFutureLookPrompt() -> String {
        let profileName = selectedProfile?.name ?? L10n.tr("family_baby_fallback_name")
        let ageText = selectedProfile?.birthDate.formatted(date: .abbreviated, time: .omitted) ?? "-"
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let recent = allEvents.filter { $0.childId == selectedChildId && $0.timestamp >= weekAgo }

        let feed = recent.filter { $0.type.isFeedingRelated }.count
        let sleep = recent.filter { $0.type == .sleep }.count
        let diaper = recent.filter { $0.type.isDiaperRelated }.count
        let meds = recent.filter { $0.type == .medication }.count
        let fever = recent.filter { $0.type == .fever }.count

        let lines: [String] = [
            L10n.tr("family_future_prompt_intro"),
            String(format: L10n.tr("family_future_prompt_language_format"), L10n.selectedLanguageCode()),
            L10n.tr("family_future_prompt_profile_title"),
            String(format: L10n.tr("family_future_prompt_name_format"), profileName),
            String(format: L10n.tr("family_future_prompt_birth_format"), ageText),
            String(format: L10n.tr("family_future_prompt_country_format"), selectedCountryCode),
            L10n.tr("family_future_prompt_weekly_title"),
            String(format: L10n.tr("family_future_prompt_feed_format"), feed),
            String(format: L10n.tr("family_future_prompt_sleep_format"), sleep),
            String(format: L10n.tr("family_future_prompt_diaper_format"), diaper),
            String(format: L10n.tr("family_future_prompt_med_format"), meds),
            String(format: L10n.tr("family_future_prompt_fever_format"), fever),
            "",
            L10n.tr("family_future_prompt_output_title"),
            L10n.tr("family_future_prompt_output_1"),
            L10n.tr("family_future_prompt_output_2"),
            L10n.tr("family_future_prompt_output_3"),
            L10n.tr("family_future_prompt_output_4"),
            "",
            L10n.tr("family_future_prompt_safety")
        ]
        return lines.joined(separator: "\n")
    }

    private func localFutureLookFallback() -> String {
        let name = selectedProfile?.name ?? L10n.tr("family_baby_fallback_name")
        let lines: [String] = [
            L10n.tr("family_future_section_growth_vibe"),
            String(format: L10n.tr("family_future_fallback_growth_line1_format"), name),
            L10n.tr("family_future_fallback_growth_line2"),
            "",
            L10n.tr("family_future_section_next_month"),
            L10n.tr("family_future_fallback_milestone1"),
            L10n.tr("family_future_fallback_milestone2"),
            L10n.tr("family_future_fallback_milestone3"),
            "",
            L10n.tr("family_future_section_portrait_prompt"),
            L10n.tr("family_future_fallback_portrait_prompt"),
            "",
            L10n.tr("family_future_section_caption"),
            L10n.tr("family_future_fallback_caption")
        ]
        return lines.joined(separator: "\n")
    }
}

private struct ProfileCompareRow {
    let profile: BabyProfile
    let feedingCount: Int
    let sleepCount: Int
}

private enum FamilyInviteRole: String, CaseIterable, Identifiable, Codable {
    case mother
    case father
    case caregiver
    case maternalGrandmother
    case maternalGrandfather
    case paternalGrandmother
    case paternalGrandfather

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .mother:
            return "family_role_mother"
        case .father:
            return "family_role_father"
        case .caregiver:
            return "family_role_caregiver"
        case .maternalGrandmother:
            return "family_role_maternal_grandmother"
        case .maternalGrandfather:
            return "family_role_maternal_grandfather"
        case .paternalGrandmother:
            return "family_role_paternal_grandmother"
        case .paternalGrandfather:
            return "family_role_paternal_grandfather"
        }
    }
}

private enum FamilyInviteStatus: String, Codable {
    case pending
    case joined

    var titleKey: String {
        switch self {
        case .pending:
            return "family_role_invite_pending"
        case .joined:
            return "family_role_invite_joined"
        }
    }
}

private struct FamilyInviteMember: Identifiable, Codable {
    let id: String
    let role: FamilyInviteRole
    let displayName: String
    var status: FamilyInviteStatus
    let createdAt: Date
    let inviteCode: String
    var joinedAt: Date?

    init(
        id: String = UUID().uuidString,
        role: FamilyInviteRole,
        displayName: String,
        status: FamilyInviteStatus,
        createdAt: Date,
        inviteCode: String,
        joinedAt: Date? = nil
    ) {
        self.id = id
        self.role = role
        self.displayName = displayName
        self.status = status
        self.createdAt = createdAt
        self.inviteCode = inviteCode
        self.joinedAt = joinedAt
    }
}

private struct FamilyLanguageOption: Identifiable {
    let code: String
    let titleKey: String
    var id: String { code }
}

private struct FamilyCountryOption: Identifiable {
    let code: String
    let titleKey: String
    var id: String { code }
}
