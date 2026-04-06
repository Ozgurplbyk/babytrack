import SwiftUI

struct OnboardingFlowView: View {
    let onFinish: (_ languageCode: String, _ countryCode: String) -> Void
    @State private var selectedLanguageCode: String
    @State private var selectedCountryCode: String
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        .init(title: L10n.tr("onboarding_title_1"), subtitle: L10n.tr("onboarding_subtitle_1"), imagePath: "onboarding/welcome_hero.png"),
        .init(title: L10n.tr("onboarding_title_2"), subtitle: L10n.tr("onboarding_subtitle_2"), imagePath: "onboarding/offline_sync_hero.png"),
        .init(title: L10n.tr("onboarding_title_3"), subtitle: L10n.tr("onboarding_subtitle_3"), imagePath: "onboarding/health_tracking_hero.png"),
        .init(title: L10n.tr("onboarding_title_4"), subtitle: L10n.tr("onboarding_subtitle_4"), imagePath: "onboarding/memory_journal_hero.png")
    ]

    private let languages = LocaleCountryCatalog.languages
    private let countries = LocaleCountryCatalog.countries

    init(
        initialLanguageCode: String,
        initialCountryCode: String,
        onFinish: @escaping (_ languageCode: String, _ countryCode: String) -> Void
    ) {
        self.onFinish = onFinish
        let normalizedLanguage = LocaleCountryCatalog.normalize(languageCode: initialLanguageCode)
        let fallbackCountry = LocaleCountryCatalog.defaultCountryCode(for: normalizedLanguage)
        _selectedLanguageCode = State(initialValue: normalizedLanguage)
        _selectedCountryCode = State(
            initialValue: LocaleCountryCatalog.normalize(countryCode: initialCountryCode, fallback: fallbackCountry)
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            TabView(selection: $page) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    if index < pages.count {
                        let item = pages[index]
                        VStack(spacing: 16) {
                            GeneratedImageView(relativePath: item.imagePath, contentMode: .fill)
                                .frame(height: 280)
                                .clipShape(RoundedRectangle(cornerRadius: 24))

                            Text(item.title)
                                .font(.title2.bold())
                            Text(item.subtitle)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .tag(index)
                        .padding(.horizontal)
                    } else {
                        setupStep
                            .tag(index)
                            .padding(.horizontal)
                    }
                }
            }
            .tabViewStyle(.page)

            Button(action: {
                if page < totalSteps - 1 {
                    page += 1
                } else {
                    onFinish(selectedLanguageCode, selectedCountryCode)
                }
            }) {
                Text(page < totalSteps - 1 ? L10n.tr("common_continue") : L10n.tr("common_start"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private var totalSteps: Int {
        pages.count + 1
    }

    private var setupStep: some View {
        VStack(spacing: 16) {
            GeneratedImageView(relativePath: "onboarding/welcome_hero.png", contentMode: .fill)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            Text(L10n.tr("onboarding_setup_title"))
                .font(.title2.bold())

            Text(L10n.tr("onboarding_setup_subtitle"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Picker(L10n.tr("onboarding_language_label"), selection: $selectedLanguageCode) {
                    ForEach(languages) { option in
                        Text(L10n.tr(option.titleKey)).tag(option.code)
                    }
                }
                .pickerStyle(.menu)

                Picker(L10n.tr("onboarding_country_label"), selection: $selectedCountryCode) {
                    ForEach(countries) { option in
                        Text(L10n.tr(option.titleKey)).tag(option.code)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let imagePath: String
}
