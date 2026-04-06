import Foundation

enum LocaleCountryCatalog {
    struct LanguageOption: Identifiable, Hashable {
        let code: String
        let titleKey: String
        let defaultCountryCode: String
        let vaccineCountryCodes: [String]

        var id: String { code }
    }

    struct CountryOption: Identifiable, Hashable {
        let code: String
        let titleKey: String

        var id: String { code }
    }

    static let languages: [LanguageOption] = [
        .init(code: "tr", titleKey: "language_tr", defaultCountryCode: "TR", vaccineCountryCodes: ["TR"]),
        .init(code: "en", titleKey: "language_en", defaultCountryCode: "US", vaccineCountryCodes: ["US", "GB"]),
        .init(code: "de", titleKey: "language_de", defaultCountryCode: "DE", vaccineCountryCodes: ["DE"]),
        .init(code: "es", titleKey: "language_es", defaultCountryCode: "ES", vaccineCountryCodes: ["ES"]),
        .init(code: "fr", titleKey: "language_fr", defaultCountryCode: "FR", vaccineCountryCodes: ["FR"]),
        .init(code: "it", titleKey: "language_it", defaultCountryCode: "IT", vaccineCountryCodes: ["IT"]),
        .init(code: "pt-BR", titleKey: "language_pt_br", defaultCountryCode: "BR", vaccineCountryCodes: ["BR"]),
        .init(code: "ar", titleKey: "language_ar", defaultCountryCode: "SA", vaccineCountryCodes: ["SA"])
    ]

    static let countries: [CountryOption] = [
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

    static let supportedLanguageCodes = languages.map(\.code)
    static let supportedCountryCodes = countries.map(\.code)

    private static let supportedLanguageSet = Set(supportedLanguageCodes)
    private static let supportedCountrySet = Set(supportedCountryCodes)
    private static let languageByCode = Dictionary(uniqueKeysWithValues: languages.map { ($0.code, $0) })

    static func isSupportedLanguage(_ code: String) -> Bool {
        supportedLanguageSet.contains(code)
    }

    static func isSupportedCountry(_ code: String) -> Bool {
        supportedCountrySet.contains(code)
    }

    static func normalize(languageCode: String) -> String {
        let lower = languageCode.lowercased()
        if lower.hasPrefix("pt-br") || lower.hasPrefix("pt") { return "pt-BR" }
        if lower.hasPrefix("tr") { return "tr" }
        if lower.hasPrefix("de") { return "de" }
        if lower.hasPrefix("es") { return "es" }
        if lower.hasPrefix("fr") { return "fr" }
        if lower.hasPrefix("it") { return "it" }
        if lower.hasPrefix("ar") { return "ar" }
        return "en"
    }

    static func normalize(countryCode: String, fallback: String = "TR") -> String {
        let normalized = countryCode.uppercased() == "UK" ? "GB" : countryCode.uppercased()
        if supportedCountrySet.contains(normalized) {
            return normalized
        }
        return supportedCountrySet.contains(fallback) ? fallback : "TR"
    }

    static func defaultCountryCode(for languageCode: String) -> String {
        let normalizedLanguage = normalize(languageCode: languageCode)
        return languageByCode[normalizedLanguage]?.defaultCountryCode ?? "TR"
    }

    static func vaccineCountryCodes(for languageCode: String) -> [String] {
        let normalizedLanguage = normalize(languageCode: languageCode)
        return languageByCode[normalizedLanguage]?.vaccineCountryCodes ?? ["TR"]
    }
}
