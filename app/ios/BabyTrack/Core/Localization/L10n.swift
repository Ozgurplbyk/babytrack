import Foundation

enum L10n {
    private static let languageKey = "app.language_code"
    private static let supportedLanguages = Set(LocaleCountryCatalog.supportedLanguageCodes)

    static func selectedLanguageCode() -> String {
        if let saved = UserDefaults.standard.string(forKey: languageKey),
           supportedLanguages.contains(saved) {
            return saved
        }

        let preferred = Locale.preferredLanguages.first ?? "en"
        let normalized = LocaleCountryCatalog.normalize(languageCode: preferred)
        return supportedLanguages.contains(normalized) ? normalized : "en"
    }

    static func setSelectedLanguageCode(_ code: String) {
        let normalized = LocaleCountryCatalog.normalize(languageCode: code)
        guard supportedLanguages.contains(normalized) else { return }
        UserDefaults.standard.set(normalized, forKey: languageKey)
    }

    static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = localizedString(for: key)
        guard !args.isEmpty else { return format }
        return String(format: format, locale: Locale.current, arguments: args)
    }

    private static func localizedString(for key: String) -> String {
        let code = selectedLanguageCode()
        if let bundle = bundle(for: code) {
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }
        return NSLocalizedString(key, comment: "")
    }

    private static func bundle(for code: String) -> Bundle? {
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return nil
    }
}
