import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var eventStore: EventStore
    @EnvironmentObject private var storeKit: StoreKitManager
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var syncConflictStore: SyncConflictStore
    @State private var showPermissions = false
    @State private var showProfileSetup = false

    var body: some View {
        Group {
            if authManager.isBootstrapping {
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    ProgressView()
                }
            } else if appState.needsOnboarding {
                OnboardingFlowView(
                    initialLanguageCode: appState.languageCode,
                    initialCountryCode: appState.countryCode
                ) { languageCode, countryCode in
                    appState.completeOnboarding(languageCode: languageCode, countryCode: countryCode)
                }
            } else if !authManager.isAuthenticated {
                AuthGateView()
            } else {
                MainTabView()
                    .sheet(isPresented: Binding(
                        get: { appState.showSyncConflictCenter && syncConflictStore.hasConflicts },
                        set: { if !$0 { appState.showSyncConflictCenter = false } }
                    )) {
                        SyncConflictCenterSheet()
                    }
                    .sheet(isPresented: $appState.showWhatsNew) {
                        WhatsNewView(release: appState.currentRelease) {
                            appState.dismissWhatsNew()
                        }
                    }
                    .fullScreenCover(isPresented: $showPermissions) {
                        PermissionsGateView {
                            appState.completePermissionsConsent()
                            showPermissions = false
                            showProfileSetup = appState.needsProfileSetup
                        }
                    }
                    .fullScreenCover(isPresented: $showProfileSetup) {
                        ProfileSetupView { result in
                            appState.addBabyProfile(
                                name: result.name,
                                birthDate: result.birthDate,
                                avatarAssetPath: result.avatarAssetPath,
                                photoData: result.photoData,
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
                            appState.needsProfileSetup = false
                            showProfileSetup = false
                        }
                    }
                    .fullScreenCover(isPresented: $appState.showPaywall) {
                        PaywallView(
                            offers: appState.paywallOffers,
                            onPurchasePlan: { planId in
                                if let product = storeKit.product(for: planId) {
                                    await storeKit.purchase(product)
                                    if storeKit.hasActiveSubscription {
                                        appState.dismissPaywall()
                                    }
                                } else {
                                    // Development fallback only when StoreKit products are unavailable.
                                    #if DEBUG
                                    UserDefaults.standard.set(true, forKey: "subscription.active")
                                    appState.dismissPaywall()
                                    #endif
                                }
                            },
                            onRestore: {
                                await storeKit.restore()
                                if storeKit.hasActiveSubscription {
                                    appState.dismissPaywall()
                                }
                            },
                            onClose: appState.dismissPaywall
                        )
                    }
            }
        }
        .animation(.easeInOut, value: appState.needsOnboarding)
        .id(appState.languageCode)
        .onAppear {
            syncSharedState()
            if appState.needsPermissionsConsent {
                showPermissions = true
            } else if appState.needsProfileSetup {
                showProfileSetup = true
            }
        }
        .onChange(of: appState.selectedBabyId) { _ in
            syncSharedState()
        }
        .onChange(of: appState.countryCode) { _ in
            syncSharedState()
        }
        .onChange(of: appState.needsProfileSetup) { needs in
            if !appState.needsOnboarding && !appState.needsPermissionsConsent && needs {
                showProfileSetup = true
            }
        }
        .onOpenURL { url in
            guard let scheme = url.scheme?.lowercased(), scheme == "babytrack" else { return }
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
            if url.host?.lowercased() == "family", url.path == "/join" {
                if let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                   !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    appState.pendingFamilyInviteCode = code.uppercased()
                    appState.selectedTab = .family
                }
            }
        }
        .onReceive(eventStore.$events) { _ in
            syncSharedState()
        }
    }

    private func syncSharedState() {
        _ = eventStore.importWatchQueuedEvents(defaultChildId: appState.selectedChildId())
        eventStore.publishSharedSnapshot(
            childId: appState.selectedChildId(),
            childName: appState.selectedBabyName(),
            countryCode: appState.countryCode
        )
    }
}

private struct AuthGateView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var mode: AuthMode = .login
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var loading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text(L10n.tr("auth_title"))
                        .font(.title2.weight(.bold))
                    Text(L10n.tr("auth_subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 36)

                Picker("", selection: $mode) {
                    Text(L10n.tr("auth_mode_login")).tag(AuthMode.login)
                    Text(L10n.tr("auth_mode_register")).tag(AuthMode.register)
                }
                .pickerStyle(.segmented)

                VStack(spacing: 10) {
                    if mode == .register {
                        TextField(L10n.tr("auth_display_name"), text: $displayName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField(L10n.tr("auth_email"), text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField(L10n.tr("auth_password"), text: $password)
                        .textFieldStyle(.roundedBorder)
                }

                if !authManager.lastErrorMessage.isEmpty {
                    Text(L10n.tr(authManager.lastErrorMessage))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    submit()
                } label: {
                    HStack(spacing: 8) {
                        if loading {
                            ProgressView().tint(.white)
                        }
                        Text(L10n.tr(mode == .login ? "auth_login_action" : "auth_register_action"))
                            .font(.headline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(loading || !canSubmit)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.accentColor.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
    }

    private var canSubmit: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPass = password.trimmingCharacters(in: .whitespacesAndNewlines)
        if mode == .register {
            return !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !trimmedEmail.isEmpty
                && trimmedPass.count >= 6
        }
        return !trimmedEmail.isEmpty && !trimmedPass.isEmpty
    }

    private func submit() {
        loading = true
        Task {
            defer { loading = false }
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPass = password.trimmingCharacters(in: .whitespacesAndNewlines)
            if mode == .register {
                _ = await authManager.register(
                    email: trimmedEmail,
                    password: trimmedPass,
                    displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } else {
                _ = await authManager.login(email: trimmedEmail, password: trimmedPass)
            }
        }
    }
}

private enum AuthMode {
    case login
    case register
}
