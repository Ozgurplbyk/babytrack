import XCTest
@testable import BabyTrack

final class BabyTrackTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "sync_conflicts.pending.v1")
        UserDefaults.standard.removeObject(forKey: "sync_conflicts.backup_events.v1")
        super.tearDown()
    }

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

    @MainActor
    func testSyncConflictStorePersistsPendingConflicts() {
        let eventId = UUID().uuidString
        let conflict = SyncConflict(
            eventId: eventId,
            reason: "conflict_remote_update",
            remoteEvent: AppEvent(
                id: UUID(uuidString: eventId)!,
                childId: "child-1",
                type: .sleep,
                timestamp: Date(timeIntervalSince1970: 2000),
                note: "remote",
                payload: ["duration": "20"],
                visibility: .family
            )
        )
        let backup = AppEvent(
            id: UUID(),
            childId: "child-1",
            type: .memory,
            timestamp: Date(timeIntervalSince1970: 1000),
            note: "backup",
            payload: [:],
            visibility: .family
        )

        let store = SyncConflictStore()
        store.clear()
        store.setPendingConflicts([conflict], backupEvents: [backup])

        let restored = SyncConflictStore()
        XCTAssertEqual(restored.conflicts.map(\.eventId), [eventId])
        XCTAssertEqual(restored.backupEvents.count, 1)
    }

    @MainActor
    func testSyncConflictStoreResolveClearsBackupWhenLastConflictRemoved() {
        let eventId = UUID().uuidString
        let conflict = SyncConflict(
            eventId: eventId,
            reason: "conflict_remote_update",
            remoteEvent: nil
        )
        let backup = AppEvent(
            id: UUID(),
            childId: "child-1",
            type: .sleep,
            timestamp: Date(),
            note: "backup",
            payload: [:],
            visibility: .family
        )

        let store = SyncConflictStore()
        store.clear()
        store.setPendingConflicts([conflict], backupEvents: [backup])
        store.resolve(eventId: eventId)

        XCTAssertTrue(store.conflicts.isEmpty)
        XCTAssertTrue(store.backupEvents.isEmpty)
    }
}
