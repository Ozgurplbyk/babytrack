import XCTest
@testable import BabyTrack

final class BabyTrackTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "sync_conflicts.pending.v1")
        UserDefaults.standard.removeObject(forKey: "sync_conflicts.backup_events.v1")
        UserDefaults.standard.removeObject(forKey: VaccinePackageCache.storageKey(countryCode: "tr"))
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

    func testSchoolTravelModeTemplatesStayDistinctAndComplete() {
        let school = SchoolTravelMode.templateItems(for: .school)
        let travel = SchoolTravelMode.templateItems(for: .travel)

        XCTAssertEqual(school.count, 4)
        XCTAssertEqual(travel.count, 4)
        XCTAssertEqual(Set(school).count, 4)
        XCTAssertEqual(Set(travel).count, 4)
        XCTAssertTrue(Set(school).isDisjoint(with: Set(travel)))
    }

    func testSchoolTravelHistoryFilteringSupportsRecentDateAndBabyMonthModes() {
        let calendar = Calendar(identifier: .gregorian)
        let birthDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let plan0 = SchoolTravelPlan(
            childId: "child",
            mode: .school,
            title: "School Form",
            startDate: birthDate,
            endDate: birthDate,
            notes: "",
            checklist: [],
            createdAt: birthDate
        )
        let plan1Start = calendar.date(byAdding: .day, value: 36, to: birthDate)!
        let plan1 = SchoolTravelPlan(
            childId: "child",
            mode: .travel,
            title: "Travel Bag",
            startDate: plan1Start,
            endDate: calendar.date(byAdding: .day, value: 3, to: plan1Start)!,
            notes: "",
            checklist: [],
            createdAt: plan1Start
        )
        let plan2Start = calendar.date(byAdding: .day, value: 72, to: birthDate)!
        let plan2 = SchoolTravelPlan(
            childId: "child",
            mode: .school,
            title: "School Refill",
            startDate: plan2Start,
            endDate: plan2Start,
            notes: "",
            checklist: [],
            createdAt: plan2Start
        )
        let plans = [plan2, plan1, plan0]

        XCTAssertEqual(
            HealthHistoryLogic.filterSchoolTravelPlans(
                from: plans,
                mode: .recent,
                historyDate: plan2Start,
                historyBabyMonth: 0,
                birthDate: birthDate,
                calendar: calendar,
                recentLimit: 2
            ).map(\.id),
            [plan2.id, plan1.id]
        )

        XCTAssertEqual(
            HealthHistoryLogic.filterSchoolTravelPlans(
                from: plans,
                mode: .date,
                historyDate: plan1.endDate,
                historyBabyMonth: 0,
                birthDate: birthDate,
                calendar: calendar
            ).map(\.id),
            [plan1.id]
        )

        XCTAssertEqual(
            HealthHistoryLogic.filterSchoolTravelPlans(
                from: plans,
                mode: .babyMonth,
                historyDate: plan2Start,
                historyBabyMonth: 1,
                birthDate: birthDate,
                calendar: calendar
            ).map(\.id),
            [plan1.id]
        )
    }

    func testGrowthMetricUnitLabelsRespectUnitProfile() {
        let metricProfile = UnitProfile(length: .cm, weight: .kg, temperature: .celsius, volume: .ml)
        let imperialProfile = UnitProfile(length: .inch, weight: .lb, temperature: .fahrenheit, volume: .oz)

        XCTAssertEqual(GrowthMetric.weight.unitLabel(unitProfile: metricProfile), "kg")
        XCTAssertEqual(GrowthMetric.weight.unitLabel(unitProfile: imperialProfile), "lb")
        XCTAssertEqual(GrowthMetric.length.unitLabel(unitProfile: metricProfile), "cm")
        XCTAssertEqual(GrowthMetric.head.unitLabel(unitProfile: imperialProfile), "in")
    }

    func testHealthGrowthLogicConvertsReferenceRangesForImperialUnits() {
        let metricProfile = UnitProfile(length: .cm, weight: .kg, temperature: .celsius, volume: .ml)
        let imperialProfile = UnitProfile(length: .inch, weight: .lb, temperature: .fahrenheit, volume: .oz)

        let metricWeightRange = HealthGrowthLogic.referenceRange(metric: .weight, ageMonth: 2, unitProfile: metricProfile)
        let imperialWeightRange = HealthGrowthLogic.referenceRange(metric: .weight, ageMonth: 2, unitProfile: imperialProfile)
        let metricLengthRange = HealthGrowthLogic.referenceRange(metric: .length, ageMonth: 2, unitProfile: metricProfile)
        let imperialLengthRange = HealthGrowthLogic.referenceRange(metric: .length, ageMonth: 2, unitProfile: imperialProfile)

        XCTAssertEqual(imperialWeightRange.lowerBound, metricWeightRange.lowerBound * 2.20462, accuracy: 0.001)
        XCTAssertEqual(imperialWeightRange.upperBound, metricWeightRange.upperBound * 2.20462, accuracy: 0.001)
        XCTAssertEqual(imperialLengthRange.lowerBound, metricLengthRange.lowerBound / 2.54, accuracy: 0.001)
        XCTAssertEqual(imperialLengthRange.upperBound, metricLengthRange.upperBound / 2.54, accuracy: 0.001)
    }

    func testHealthGrowthLogicFlagsValuesOutsideReferenceRange() {
        let profile = UnitProfile(length: .cm, weight: .kg, temperature: .celsius, volume: .ml)

        XCTAssertFalse(HealthGrowthLogic.isOutsideReference(metric: .weight, value: 4.6, ageMonth: 2, unitProfile: profile))
        XCTAssertTrue(HealthGrowthLogic.isOutsideReference(metric: .weight, value: 7.5, ageMonth: 2, unitProfile: profile))
        XCTAssertTrue(HealthGrowthLogic.isOutsideReference(metric: .head, value: 50, ageMonth: 1, unitProfile: profile))
    }

    func testHealthEnumsExposeExpectedStableMetadata() {
        XCTAssertEqual(HealthTriageLevel.green.icon, "checkmark.shield.fill")
        XCTAssertEqual(HealthTriageLevel.yellow.titleKey, "health_triage_level_yellow")
        XCTAssertEqual(HealthTriageLevel.red.guidanceKey, "health_triage_guidance_red")
        XCTAssertEqual(HealthHistoryMode.recent.rawValue, "recent")
        XCTAssertEqual(HealthHistoryMode.date.rawValue, "date")
        XCTAssertEqual(HealthHistoryMode.babyMonth.rawValue, "babyMonth")
    }

    func testVaccinePackageCacheRoundTripsSavedPayload() {
        let record = VaccinePackageRecord(
            vaccineCode: "MMR",
            doseNo: 1,
            minAgeDays: 360,
            maxAgeDays: nil,
            minIntervalDays: 0,
            catchUpRule: "standard"
        )

        VaccinePackageCache.save(
            countryCode: "tr",
            authority: "Ministry of Health",
            version: "2026.04",
            records: [record],
            sourceURL: "https://example.gov.tr/vaccine.pdf",
            sourceUpdatedAt: "2026-04-06",
            publishedAt: "2026-04-06T10:00:00Z"
        )

        let cached = VaccinePackageCache.load(countryCode: "TR")
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.countryCode, "TR")
        XCTAssertEqual(cached?.authority, "Ministry of Health")
        XCTAssertEqual(cached?.records.first?.vaccineCode, "MMR")
        XCTAssertTrue(cached?.isFresh ?? false)
    }

    func testVaccineScheduleCatalogHasFallbackCoverageForSupportedCountries() {
        for country in LocaleCountryCatalog.supportedCountryCodes {
            let schedule = VaccineScheduleCatalog.schedule(for: country)
            XCTAssertFalse(schedule.isEmpty, "Expected fallback vaccine schedule for \(country)")
            XCTAssertFalse(schedule.contains(where: { $0.name.isEmpty }))
        }
    }

    func testDoctorShareSnapshotCountsRelevantEventTypes() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let events: [AppEvent] = [
            AppEvent(childId: "child", type: .breastfeeding, timestamp: now),
            AppEvent(childId: "child", type: .sleep, timestamp: now),
            AppEvent(childId: "child", type: .diaperChange, timestamp: now),
            AppEvent(childId: "child", type: .medication, timestamp: now),
            AppEvent(childId: "child", type: .fever, timestamp: now),
            AppEvent(childId: "child", type: .memory, timestamp: yesterday)
        ]

        let snapshot = DoctorShareComposer.snapshot(events: events, now: now, calendar: calendar)
        XCTAssertEqual(snapshot.todayCount, 5)
        XCTAssertEqual(snapshot.feedingCount, 1)
        XCTAssertEqual(snapshot.sleepCount, 1)
        XCTAssertEqual(snapshot.diaperCount, 1)
        XCTAssertEqual(snapshot.medicationCount, 1)
        XCTAssertEqual(snapshot.feverCount, 1)
    }

    func testDoctorShareFilteringSupportsRecentDateAndBabyMonthModes() {
        let calendar = Calendar(identifier: .gregorian)
        let birthDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let januaryEvent = AppEvent(childId: "child", type: .sleep, timestamp: birthDate)
        let februaryEvent = AppEvent(childId: "child", type: .bottle, timestamp: calendar.date(byAdding: .day, value: 35, to: birthDate)!)
        let marchEvent = AppEvent(childId: "child", type: .medication, timestamp: calendar.date(byAdding: .day, value: 70, to: birthDate)!)
        let events = [marchEvent, februaryEvent, januaryEvent]

        XCTAssertEqual(
            DoctorShareComposer.filteredEvents(
                from: events,
                mode: .recent,
                historyDate: marchEvent.timestamp,
                historyBabyMonth: 0,
                birthDate: birthDate,
                calendar: calendar
            ).map(\.id),
            events.map(\.id)
        )

        XCTAssertEqual(
            DoctorShareComposer.filteredEvents(
                from: events,
                mode: .date,
                historyDate: februaryEvent.timestamp,
                historyBabyMonth: 0,
                birthDate: birthDate,
                calendar: calendar
            ).map(\.id),
            [februaryEvent.id]
        )

        XCTAssertEqual(
            DoctorShareComposer.filteredEvents(
                from: events,
                mode: .babyMonth,
                historyDate: marchEvent.timestamp,
                historyBabyMonth: 1,
                birthDate: birthDate,
                calendar: calendar
            ).map(\.id),
            [februaryEvent.id]
        )
    }

    func testHealthHistoryLogicFiltersEventsAndComputesAvailableMonths() {
        let calendar = Calendar(identifier: .gregorian)
        let birthDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let currentDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 15))!
        let month0Event = AppEvent(childId: "child", type: .sleep, timestamp: birthDate)
        let month1Event = AppEvent(childId: "child", type: .bottle, timestamp: calendar.date(byAdding: .day, value: 36, to: birthDate)!)
        let month2Event = AppEvent(childId: "child", type: .medication, timestamp: calendar.date(byAdding: .day, value: 72, to: birthDate)!)
        let events = [month2Event, month1Event, month0Event]

        XCTAssertEqual(
            HealthHistoryLogic.filterEvents(
                from: events,
                mode: .recent,
                historyDate: currentDate,
                historyBabyMonth: 0,
                birthDate: birthDate,
                calendar: calendar,
                recentLimit: 2
            ).map(\.id),
            [month2Event.id, month1Event.id]
        )

        XCTAssertEqual(
            HealthHistoryLogic.filterEvents(
                from: events,
                mode: .date,
                historyDate: month1Event.timestamp,
                historyBabyMonth: 0,
                birthDate: birthDate,
                calendar: calendar
            ).map(\.id),
            [month1Event.id]
        )

        XCTAssertEqual(
            HealthHistoryLogic.filterEvents(
                from: events,
                mode: .babyMonth,
                historyDate: currentDate,
                historyBabyMonth: 2,
                birthDate: birthDate,
                calendar: calendar
            ).map(\.id),
            [month2Event.id]
        )

        XCTAssertEqual(
            HealthHistoryLogic.availableMonthCount(
                birthDate: birthDate,
                now: currentDate,
                calendar: calendar,
                fallback: 12
            ),
            3
        )
        XCTAssertEqual(
            HealthHistoryLogic.availableMonthCount(
                birthDate: nil,
                now: currentDate,
                calendar: calendar,
                fallback: 12
            ),
            12
        )
    }

    func testDoctorShareFullReportIncludesBirthMedicationAndRecentEvents() {
        let child = BabyProfile(
            name: "Ada",
            birthDate: Date(timeIntervalSince1970: 1_700_000_000),
            gestationalWeeks: 39,
            birthWeightKg: 3.4,
            birthLengthCm: 50,
            birthHeadCircumferenceCm: 35,
            birthPlace: "Istanbul",
            birthHospital: "City Hospital",
            apgar1Min: 8,
            apgar5Min: 9,
            nicuDays: 2,
            birthNotes: "Observation only"
        )
        let plan = MedicationPlan(
            childId: child.id.uuidString,
            name: "Vitamin D",
            dosage: "1 drop",
            reminderHour: 9,
            reminderMinute: 30
        )
        let event = AppEvent(
            childId: child.id.uuidString,
            type: .fever,
            timestamp: Date(timeIntervalSince1970: 1_700_100_000),
            note: "38.2C"
        )
        let report = DoctorShareComposer.buildFullReport(
            childName: child.name,
            ageMonths: 2,
            birthLines: DoctorShareComposer.birthMetaLines(for: child),
            snapshot: DoctorShareSnapshot(todayCount: 3, feedingCount: 1, sleepCount: 1, diaperCount: 0, medicationCount: 1, feverCount: 1),
            activeMedications: [plan],
            filteredEvents: [event],
            generatedAt: Date(timeIntervalSince1970: 1_700_200_000)
        )

        XCTAssertTrue(report.contains("Ada"))
        XCTAssertTrue(report.contains("Vitamin D"))
        XCTAssertTrue(report.contains("Observation only"))
        XCTAssertTrue(report.contains("City Hospital"))
        XCTAssertTrue(report.contains("38.2C"))
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
