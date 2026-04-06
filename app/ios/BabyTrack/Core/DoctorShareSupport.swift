import Foundation

struct DoctorShareSnapshot: Equatable {
    let todayCount: Int
    let feedingCount: Int
    let sleepCount: Int
    let diaperCount: Int
    let medicationCount: Int
    let feverCount: Int
}

enum DoctorShareComposer {
    static func snapshot(events: [AppEvent], now: Date = Date(), calendar: Calendar = .current) -> DoctorShareSnapshot {
        let dayStart = calendar.startOfDay(for: now)
        let todayEvents = events.filter { $0.timestamp >= dayStart }
        return DoctorShareSnapshot(
            todayCount: todayEvents.count,
            feedingCount: todayEvents.filter { $0.type.isFeedingRelated }.count,
            sleepCount: todayEvents.filter { $0.type == .sleep }.count,
            diaperCount: todayEvents.filter { $0.type.isDiaperRelated }.count,
            medicationCount: todayEvents.filter { $0.type == .medication }.count,
            feverCount: todayEvents.filter { $0.type == .fever }.count
        )
    }

    static func filteredEvents(
        from events: [AppEvent],
        mode: HealthHistoryMode,
        historyDate: Date,
        historyBabyMonth: Int,
        birthDate: Date?,
        calendar: Calendar = .current,
        recentLimit: Int = 10
    ) -> [AppEvent] {
        HealthHistoryLogic.filterEvents(
            from: events,
            mode: mode,
            historyDate: historyDate,
            historyBabyMonth: historyBabyMonth,
            birthDate: birthDate,
            calendar: calendar,
            recentLimit: recentLimit
        )
    }

    static func medicationSubtitle(_ plan: MedicationPlan, calendar: Calendar = .current) -> String {
        let time = DateComponents(calendar: calendar, hour: plan.reminderHour, minute: plan.reminderMinute)
            .date?
            .formatted(date: .omitted, time: .shortened)
        if plan.dosage.isEmpty, let time {
            return String(format: L10n.tr("doctor_share_medication_time_format"), time)
        }
        if let time {
            return "\(plan.dosage) • \(String(format: L10n.tr("doctor_share_medication_time_format"), time))"
        }
        return plan.dosage.isEmpty ? L10n.tr("medication_reminder_no_dose") : plan.dosage
    }

    static func medicationLine(_ plan: MedicationPlan, calendar: Calendar = .current) -> String {
        let subtitle = medicationSubtitle(plan, calendar: calendar)
        return subtitle.isEmpty
            ? String(format: L10n.tr("doctor_share_medication_line_name_only_format"), plan.name)
            : String(format: L10n.tr("doctor_share_medication_line_format"), plan.name, subtitle)
    }

    static func reportLine(_ event: AppEvent) -> String {
        let base = String(
            format: L10n.tr("doctor_share_report_event_line_format"),
            event.type.title,
            event.timestamp.formatted(date: .abbreviated, time: .shortened)
        )
        guard !event.note.isEmpty else { return base }
        return "\(base) • \(event.note)"
    }

    static func birthMetaLines(for profile: BabyProfile) -> [String] {
        var lines: [String] = []
        if let weeks = profile.gestationalWeeks {
            lines.append(String(format: L10n.tr("doctor_share_birth_weeks_format"), weeks))
        }
        if let weight = profile.birthWeightKg {
            lines.append(String(format: L10n.tr("doctor_share_birth_weight_format"), weight))
        }
        if let length = profile.birthLengthCm {
            lines.append(String(format: L10n.tr("doctor_share_birth_length_format"), length))
        }
        if let head = profile.birthHeadCircumferenceCm {
            lines.append(String(format: L10n.tr("doctor_share_birth_head_format"), head))
        }
        if let apgar1 = profile.apgar1Min, let apgar5 = profile.apgar5Min {
            lines.append(String(format: L10n.tr("doctor_share_birth_apgar_format"), apgar1, apgar5))
        }
        if let nicuDays = profile.nicuDays {
            lines.append(String(format: L10n.tr("doctor_share_birth_nicu_format"), nicuDays))
        }
        if !profile.birthPlace.isEmpty {
            lines.append(String(format: L10n.tr("doctor_share_birth_place_format"), profile.birthPlace))
        }
        if !profile.birthHospital.isEmpty {
            lines.append(String(format: L10n.tr("doctor_share_birth_hospital_format"), profile.birthHospital))
        }
        if !profile.birthNotes.isEmpty {
            lines.append(String(format: L10n.tr("doctor_share_birth_note_format"), profile.birthNotes))
        }
        return lines
    }

    static func buildCompactSummary(
        childName: String,
        ageMonths: Int?,
        snapshot: DoctorShareSnapshot,
        recentEvents: [AppEvent],
        generatedAt: Date = Date()
    ) -> String {
        var lines: [String] = []
        lines.append(L10n.tr("doctor_share_report_title"))
        lines.append(String(format: L10n.tr("doctor_share_report_generated_format"), generatedAt.formatted(date: .abbreviated, time: .shortened)))
        lines.append(String(format: L10n.tr("doctor_share_report_child_format"), childName))
        if let ageMonths {
            lines.append(String(format: L10n.tr("doctor_share_report_age_format"), ageMonths))
        }
        lines.append("")
        lines.append(L10n.tr("doctor_share_report_summary_title"))
        lines.append(summaryLine(snapshot))
        lines.append("")
        lines.append(L10n.tr("doctor_share_report_recent_title"))
        if recentEvents.isEmpty {
            lines.append(L10n.tr("doctor_share_report_no_events"))
        } else {
            lines.append(contentsOf: recentEvents.map(reportLine))
        }
        return lines.joined(separator: "\n")
    }

    static func buildFullReport(
        childName: String,
        ageMonths: Int?,
        birthLines: [String],
        snapshot: DoctorShareSnapshot,
        activeMedications: [MedicationPlan],
        filteredEvents: [AppEvent],
        generatedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        var lines: [String] = []
        lines.append(L10n.tr("doctor_share_report_title"))
        lines.append(String(format: L10n.tr("doctor_share_report_generated_format"), generatedAt.formatted(date: .abbreviated, time: .shortened)))
        lines.append(String(format: L10n.tr("doctor_share_report_child_format"), childName))
        if let ageMonths {
            lines.append(String(format: L10n.tr("doctor_share_report_age_format"), ageMonths))
        }
        lines.append(contentsOf: birthLines)
        lines.append("")
        lines.append(L10n.tr("doctor_share_report_summary_title"))
        lines.append(summaryLine(snapshot))
        lines.append("")
        lines.append(L10n.tr("doctor_share_active_medications_title"))
        if activeMedications.isEmpty {
            lines.append(L10n.tr("doctor_share_active_medications_empty"))
        } else {
            lines.append(contentsOf: activeMedications.map { medicationLine($0, calendar: calendar) })
        }
        lines.append("")
        lines.append(L10n.tr("doctor_share_report_recent_title"))
        if filteredEvents.isEmpty {
            lines.append(L10n.tr("doctor_share_report_no_events"))
        } else {
            lines.append(contentsOf: filteredEvents.prefix(10).map(reportLine))
        }
        return lines.joined(separator: "\n")
    }

    private static func summaryLine(_ snapshot: DoctorShareSnapshot) -> String {
        String(
            format: L10n.tr("doctor_share_report_summary_format"),
            snapshot.todayCount,
            snapshot.feedingCount,
            snapshot.sleepCount,
            snapshot.diaperCount,
            snapshot.medicationCount,
            snapshot.feverCount
        )
    }
}
