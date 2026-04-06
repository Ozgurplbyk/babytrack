import XCTest
@testable import BabyTrack

final class BabyTrackTests: XCTestCase {
    func testForumModerationRejectsBlockedTerms() {
        let result = ForumModeration.validatePost(
            title: "Question",
            body: "This looks like a scam message"
        )
        XCTAssertEqual(result, .reject(reasonKey: "forum_error_blocked_terms"))
    }

    func testForumTagParsingNormalizesAndLimits() {
        let tags = ForumModeration.parseTags(" Sleep , FEEDING,  , sleep, Pumping, diaper, growth, extra")
        XCTAssertEqual(tags, ["sleep", "feeding", "pumping", "diaper", "growth", "extra"])
    }

    func testSyncConflictMergeMergesPayloadAndNotes() {
        let id = UUID().uuidString
        let local = AppEvent(
            id: UUID(uuidString: id)!,
            childId: "child-1",
            type: .sleep,
            timestamp: Date(timeIntervalSince1970: 1000),
            note: "local-note",
            payload: ["duration": "45"],
            visibility: .family
        )
        let remote = AppEvent(
            id: UUID(uuidString: id)!,
            childId: "child-1",
            type: .sleep,
            timestamp: Date(timeIntervalSince1970: 1200),
            note: "remote-note",
            payload: ["quality": "good"],
            visibility: .family
        )

        let merged = SyncConflictEngine.merge(local: local, remote: remote, eventId: id)
        XCTAssertNotNil(merged)
        XCTAssertEqual(merged?.payload["duration"], "45")
        XCTAssertEqual(merged?.payload["quality"], "good")
        XCTAssertEqual(merged?.note, "local-note\nremote-note")
        XCTAssertEqual(merged?.timestamp, remote.timestamp)
    }

    func testLocaleCountryCatalogNormalizesCodes() {
        XCTAssertEqual(LocaleCountryCatalog.normalize(languageCode: "en-US"), "en")
        XCTAssertEqual(LocaleCountryCatalog.normalize(languageCode: "pt-PT"), "pt-BR")
        XCTAssertEqual(LocaleCountryCatalog.normalize(countryCode: "uk"), "GB")
        XCTAssertEqual(LocaleCountryCatalog.normalize(countryCode: "xx", fallback: "DE"), "DE")
    }

    func testLocaleCountryCatalogProvidesVaccineCoverageForEachLanguage() {
        let supportedCountries = Set(LocaleCountryCatalog.supportedCountryCodes)

        for language in LocaleCountryCatalog.supportedLanguageCodes {
            let defaultCountry = LocaleCountryCatalog.defaultCountryCode(for: language)
            let vaccineCountries = LocaleCountryCatalog.vaccineCountryCodes(for: language)

            XCTAssertFalse(vaccineCountries.isEmpty, "Expected vaccine coverage for \(language)")
            XCTAssertTrue(vaccineCountries.contains(defaultCountry), "Default country must be covered for \(language)")
            XCTAssertTrue(Set(vaccineCountries).isSubset(of: supportedCountries), "Unexpected country in \(language) coverage")
        }
    }
}
