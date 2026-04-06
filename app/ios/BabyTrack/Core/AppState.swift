import Foundation
import SwiftUI

enum AppTab: Hashable {
    case today
    case timeline
    case quickAdd
    case health
    case family
}

struct LanguageRegionChange: Codable, Equatable, Identifiable {
    let id: String
    let fromLanguageCode: String
    let fromCountryCode: String
    let toLanguageCode: String
    let toCountryCode: String
    let changedAt: Date
}

@MainActor
final class AppState: ObservableObject {
    private static let countryKey = "app.country_code"
    private static let languageRegionHistoryKey = "app.language_region_history.v1"
    private static let languageRegionHistoryLimit = 20

    @Published var selectedTab: AppTab = .today
    @Published var needsOnboarding: Bool = false
    @Published var showWhatsNew: Bool = false
    @Published var showPaywall: Bool = false
    @Published var needsPermissionsConsent: Bool = false

    @Published var currentRelease: WhatsNewRelease = .placeholder
    @Published var paywallOffers: PaywallOffersResponse = PaywallOffersLoader.loadLocal()
    @Published var languageCode: String = "en"
    @Published var countryCode: String = "TR"
    @Published var theme: AppTheme = .system
    @Published var unitProfile: UnitProfile = UnitProfile.defaults(for: "TR")
    @Published var babyProfiles: [BabyProfile] = []
    @Published var selectedBabyId: UUID?
    @Published var needsProfileSetup: Bool = false
    @Published var pendingFamilyInviteCode: String?
    @Published var familyInviteMessage: String?
    @Published private(set) var languageRegionHistory: [LanguageRegionChange] = []

    private let versionTracker = VersionTracker()
    private let unitStore = UnitProfileStore()
    private let babyProfileStore = BabyProfileStore()

    func bootstrap(storeKit: StoreKitManager) async {
        languageCode = L10n.selectedLanguageCode()
        countryCode = resolveSavedCountryCode()
        languageRegionHistory = loadLanguageRegionHistory()
        theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "app.theme") ?? "system") ?? .system
        unitProfile = unitStore.load(defaultCountry: countryCode)
        needsOnboarding = !UserDefaults.standard.bool(forKey: "onboarding.completed")
        needsPermissionsConsent = !UserDefaults.standard.bool(forKey: "permissions.consent.completed")
        loadProfiles()

        currentRelease = WhatsNewReleaseLoader.loadLatestRelease()
        showWhatsNew = versionTracker.shouldShowWhatsNew(for: currentRelease.version)

        await loadRemotePaywallIfAvailable()
        await storeKit.configure(with: paywallOffers)

        AnalyticsTracker.shared.track(.appOpen, params: [
            "country": countryCode
        ])

        if !storeKit.hasActiveSubscription {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showPaywall = true
            }
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboarding.completed")
        needsOnboarding = false
        needsPermissionsConsent = true
        AnalyticsTracker.shared.track(.onboardingCompleted)
    }

    func completeOnboarding(languageCode: String, countryCode: String) {
        updateLanguageAndCountry(languageCode, countryCode, recordHistory: false)
        completeOnboarding()
    }

    func dismissWhatsNew() {
        versionTracker.markShown(version: currentRelease.version)
        showWhatsNew = false
    }

    func dismissPaywall() {
        showPaywall = false
    }

    func updateTheme(_ value: AppTheme) {
        theme = value
        UserDefaults.standard.set(value.rawValue, forKey: "app.theme")
    }

    func updateLanguageCode(_ code: String) {
        updateLanguageAndCountry(code, countryCode)
    }

    func updateCountryCode(_ code: String) {
        updateLanguageAndCountry(languageCode, code)
    }

    func updateLanguageAndCountry(_ languageCode: String, _ countryCode: String, recordHistory: Bool = true) {
        let fromLanguage = self.languageCode
        let fromCountry = self.countryCode

        L10n.setSelectedLanguageCode(languageCode)
        let normalizedLanguage = L10n.selectedLanguageCode()
        let normalizedCountry = normalizeCountryCode(countryCode)

        let languageChanged = fromLanguage != normalizedLanguage
        let countryChanged = fromCountry != normalizedCountry
        guard languageChanged || countryChanged else { return }

        self.languageCode = normalizedLanguage
        self.countryCode = normalizedCountry
        UserDefaults.standard.set(normalizedCountry, forKey: Self.countryKey)

        if countryChanged {
            resetUnitsForCountryDefault()
        }

        if recordHistory {
            appendLanguageRegionHistory(
                fromLanguage: fromLanguage,
                fromCountry: fromCountry,
                toLanguage: normalizedLanguage,
                toCountry: normalizedCountry
            )
        }
    }

    @discardableResult
    func undoLastLanguageRegionChange() -> Bool {
        guard let latest = languageRegionHistory.first else { return false }

        var history = languageRegionHistory
        history.removeFirst()
        languageRegionHistory = history
        persistLanguageRegionHistory()

        updateLanguageAndCountry(latest.fromLanguageCode, latest.fromCountryCode, recordHistory: false)
        return true
    }

    func resetUnitsForCountryDefault() {
        unitProfile = UnitProfile.defaults(for: countryCode)
        unitStore.save(unitProfile)
    }

    func updateUnitProfile(_ profile: UnitProfile) {
        unitProfile = profile
        unitStore.save(profile)
    }

    func selectBabyProfile(_ id: UUID) {
        selectedBabyId = id
        UserDefaults.standard.set(id.uuidString, forKey: "app.selected_baby_id")
    }

    func addBabyProfile(
        name: String,
        birthDate: Date,
        avatarAssetPath: String? = nil,
        photoData: Data? = nil,
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
        birthNotes: String = ""
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var profile = BabyProfile(
            name: trimmed,
            birthDate: birthDate,
            avatarAssetPath: avatarAssetPath,
            biologicalSex: biologicalSex,
            deliveryType: deliveryType,
            gestationalWeeks: gestationalWeeks,
            birthWeightKg: birthWeightKg,
            birthLengthCm: birthLengthCm,
            birthHeadCircumferenceCm: birthHeadCircumferenceCm,
            birthTime: birthTime,
            birthPlace: birthPlace,
            birthHospital: birthHospital,
            apgar1Min: apgar1Min,
            apgar5Min: apgar5Min,
            nicuDays: nicuDays,
            birthNotes: birthNotes
        )
        if let photoData,
           let fileName = BabyAvatarStorage.saveImageData(photoData, profileId: profile.id) {
            profile.photoFileName = fileName
        }
        babyProfiles.append(profile)
        persistProfiles()
        selectBabyProfile(profile.id)
        needsProfileSetup = babyProfiles.isEmpty
    }

    func updateBabyProfile(
        _ profile: BabyProfile,
        newPhotoData: Data? = nil,
        removeExistingPhoto: Bool = false
    ) {
        guard let idx = babyProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
        var updated = profile
        let oldPhoto = babyProfiles[idx].photoFileName

        if removeExistingPhoto {
            BabyAvatarStorage.delete(fileName: oldPhoto)
            updated.photoFileName = nil
        }

        if let newPhotoData,
           let fileName = BabyAvatarStorage.saveImageData(newPhotoData, profileId: profile.id) {
            if let oldPhoto, oldPhoto != fileName {
                BabyAvatarStorage.delete(fileName: oldPhoto)
            }
            updated.photoFileName = fileName
        }

        babyProfiles[idx] = updated
        persistProfiles()
    }

    @discardableResult
    func deleteBabyProfile(_ id: UUID) -> Bool {
        guard babyProfiles.count > 1 else { return false }
        if let profile = babyProfiles.first(where: { $0.id == id }) {
            BabyAvatarStorage.delete(fileName: profile.photoFileName)
        }
        babyProfiles.removeAll(where: { $0.id == id })
        if selectedBabyId == id {
            selectedBabyId = babyProfiles.first?.id
        }
        persistProfiles()
        needsProfileSetup = babyProfiles.isEmpty
        return true
    }

    func selectedChildId() -> String {
        selectedBabyId?.uuidString ?? "default-child"
    }

    func selectedBabyName() -> String {
        if let id = selectedBabyId, let profile = babyProfiles.first(where: { $0.id == id }) {
            return profile.name
        }
        return ""
    }

    func selectedBabyBirthDate() -> Date? {
        guard let id = selectedBabyId else { return nil }
        return babyProfiles.first(where: { $0.id == id })?.birthDate
    }

    private func loadRemotePaywallIfAvailable() async {
        do {
            let data = try await BackendClient.shared.fetchPaywallOffers()
            let decoded = try JSONDecoder().decode(PaywallOffersResponse.self, from: data)
            paywallOffers = decoded
        } catch {
            paywallOffers = PaywallOffersLoader.loadLocal()
        }
    }

    private func resolveSavedCountryCode() -> String {
        if let saved = UserDefaults.standard.string(forKey: Self.countryKey),
           !saved.isEmpty {
            return normalizeCountryCode(saved)
        }
        let resolved = CountryResolver.resolveCountryCode()
        UserDefaults.standard.set(resolved, forKey: Self.countryKey)
        return resolved
    }

    private func normalizeCountryCode(_ code: String) -> String {
        let upper = code.uppercased()
        if upper == "UK" { return "GB" }
        let supported = ["TR", "US", "GB", "DE", "FR", "ES", "IT", "BR", "SA"]
        return supported.contains(upper) ? upper : "TR"
    }

    private func loadProfiles() {
        let loaded = babyProfileStore.load()
        babyProfiles = loaded
        needsProfileSetup = babyProfiles.isEmpty

        if let savedId = UserDefaults.standard.string(forKey: "app.selected_baby_id"),
           let uuid = UUID(uuidString: savedId),
           loaded.contains(where: { $0.id == uuid }) {
            selectedBabyId = uuid
        }
    }

    private func persistProfiles() {
        babyProfileStore.save(babyProfiles)
        if let id = selectedBabyId {
            UserDefaults.standard.set(id.uuidString, forKey: "app.selected_baby_id")
        }
    }

    private func loadLanguageRegionHistory() -> [LanguageRegionChange] {
        guard let data = UserDefaults.standard.data(forKey: Self.languageRegionHistoryKey),
              let history = try? JSONDecoder().decode([LanguageRegionChange].self, from: data) else {
            return []
        }
        return history
    }

    private func persistLanguageRegionHistory() {
        guard let data = try? JSONEncoder().encode(languageRegionHistory) else { return }
        UserDefaults.standard.set(data, forKey: Self.languageRegionHistoryKey)
    }

    private func appendLanguageRegionHistory(
        fromLanguage: String,
        fromCountry: String,
        toLanguage: String,
        toCountry: String
    ) {
        let entry = LanguageRegionChange(
            id: UUID().uuidString,
            fromLanguageCode: fromLanguage,
            fromCountryCode: fromCountry,
            toLanguageCode: toLanguage,
            toCountryCode: toCountry,
            changedAt: Date()
        )
        var updated = languageRegionHistory
        updated.insert(entry, at: 0)
        if updated.count > Self.languageRegionHistoryLimit {
            updated = Array(updated.prefix(Self.languageRegionHistoryLimit))
        }
        languageRegionHistory = updated
        persistLanguageRegionHistory()
    }

    func completePermissionsConsent() {
        needsPermissionsConsent = false
        UserDefaults.standard.set(true, forKey: "permissions.consent.completed")
    }
}

struct AuthUser: Codable, Equatable {
    let id: String
    let email: String
    let displayName: String
    let createdAt: String
}

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var user: AuthUser?
    @Published private(set) var sessionToken: String?
    @Published private(set) var isBootstrapping = true
    @Published var lastErrorMessage = ""

    private static let tokenKey = "auth.session.token.v1"
    private static let userKey = "auth.session.user.v1"

    var isAuthenticated: Bool {
        user != nil && !(sessionToken ?? "").isEmpty
    }

    func bootstrap() async {
        defer { isBootstrapping = false }

        if let token = UserDefaults.standard.string(forKey: Self.tokenKey),
           !token.isEmpty {
            do {
                let me = try await BackendClient.shared.fetchCurrentUser(userToken: token)
                sessionToken = token
                user = AuthUser(
                    id: me.user.id,
                    email: me.user.email,
                    displayName: me.user.displayName,
                    createdAt: me.user.createdAt
                )
                persistSession()
                return
            } catch {
                clearSession()
            }
        }

        if let data = UserDefaults.standard.data(forKey: Self.userKey),
           let cached = try? JSONDecoder().decode(AuthUser.self, from: data) {
            user = cached
        } else {
            user = nil
        }
    }

    @discardableResult
    func register(email: String, password: String, displayName: String) async -> Bool {
        lastErrorMessage = ""
        do {
            let envelope = try await BackendClient.shared.registerUser(email: email, password: password, displayName: displayName)
            setSession(token: envelope.token, user: envelope.user)
            return true
        } catch BackendError.conflict {
            lastErrorMessage = "auth_error_email_in_use"
            return false
        } catch BackendError.unauthorized {
            lastErrorMessage = "auth_error_invalid_credentials"
            return false
        } catch {
            lastErrorMessage = "auth_error_generic"
            return false
        }
    }

    @discardableResult
    func login(email: String, password: String) async -> Bool {
        lastErrorMessage = ""
        do {
            let envelope = try await BackendClient.shared.loginUser(email: email, password: password)
            setSession(token: envelope.token, user: envelope.user)
            return true
        } catch BackendError.unauthorized {
            lastErrorMessage = "auth_error_invalid_credentials"
            return false
        } catch {
            lastErrorMessage = "auth_error_generic"
            return false
        }
    }

    func logout() async {
        if let token = sessionToken {
            try? await BackendClient.shared.logoutUser(userToken: token)
        }
        clearSession()
    }

    private func setSession(token: String, user payload: AuthUserPayload) {
        sessionToken = token
        user = AuthUser(
            id: payload.id,
            email: payload.email,
            displayName: payload.displayName,
            createdAt: payload.createdAt
        )
        persistSession()
    }

    private func persistSession() {
        if let token = sessionToken, !token.isEmpty {
            UserDefaults.standard.set(token, forKey: Self.tokenKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.tokenKey)
        }

        if let user, let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: Self.userKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.userKey)
        }
    }

    private func clearSession() {
        sessionToken = nil
        user = nil
        persistSession()
    }
}
