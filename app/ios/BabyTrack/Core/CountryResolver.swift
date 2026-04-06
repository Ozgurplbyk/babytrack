import Foundation

struct CountryResolver {
    static func resolveCountryCode() -> String {
        let fallback = LocaleCountryCatalog.defaultCountryCode(for: L10n.selectedLanguageCode())
        let preferred = Locale.current.regionCode ?? fallback
        return LocaleCountryCatalog.normalize(countryCode: preferred, fallback: fallback)
    }
}
