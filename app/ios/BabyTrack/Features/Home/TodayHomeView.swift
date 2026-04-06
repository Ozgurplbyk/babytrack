import SwiftUI

struct TodayHomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var sessionManager: CareSessionManager
    @EnvironmentObject private var syncConflictStore: SyncConflictStore
    @State private var syncStatus: String = L10n.tr("today_sync_ready")
    @State private var syncing = false
    @State private var animateIn = false
    @State private var heroFloat = false
    @State private var hasShownConflictStatus = false
    private let freeDailyLimit = 1

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        heroSection
                            .staggerEntrance(show: animateIn, delay: 0.02)
                        if appState.babyProfiles.count > 1 {
                            profileSwitcherSection
                                .staggerEntrance(show: animateIn, delay: 0.08)
                        }
                        if let activeSession = sessionManager.activeSession {
                            activeSessionSection(activeSession)
                                .staggerEntrance(show: animateIn, delay: 0.11)
                        }
                        summarySection
                            .staggerEntrance(show: animateIn, delay: 0.16)
                        developmentSection
                            .staggerEntrance(show: animateIn, delay: 0.17)
                        upcomingRemindersSection
                            .staggerEntrance(show: animateIn, delay: 0.18)
                        aiCard
                            .staggerEntrance(show: animateIn, delay: 0.2)
                        syncSection
                            .staggerEntrance(show: animateIn, delay: 0.24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(L10n.tr("today_title"))
            .onAppear {
                if !animateIn { animateIn = true }
                withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                    heroFloat = true
                }
                if syncConflictStore.hasConflicts {
                    hasShownConflictStatus = true
                    syncStatus = String(format: L10n.tr("today_sync_conflict_format"), syncConflictStore.conflicts.count)
                }
                syncUpcomingReminderNotifications()
            }
            .onChange(of: appState.selectedBabyId) { _ in syncUpcomingReminderNotifications() }
            .onReceive(store.$events) { _ in syncUpcomingReminderNotifications() }
            .onReceive(syncConflictStore.$conflicts) { conflicts in
                guard hasShownConflictStatus || !conflicts.isEmpty else { return }
                hasShownConflictStatus = true
                if conflicts.isEmpty {
                    syncStatus = L10n.tr("today_sync_conflicts_resolved")
                } else {
                    syncStatus = String(format: L10n.tr("today_sync_conflict_format"), conflicts.count)
                }
            }
        }
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.accentColor.opacity(0.06),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 54)
                .offset(x: 130, y: -240)
        }
    }

    private var heroSection: some View {
        HStack(spacing: 14) {
            if let selectedProfile {
                BabyAvatarView(profile: selectedProfile, size: 82)
            } else {
                GeneratedImageView(relativePath: "quick_add/memory.png", contentMode: .fill)
                    .frame(width: 82, height: 82)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.75), lineWidth: 2)
                    )
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(selectedBabyName)
                    .font(.title3.weight(.heavy))
                    .lineLimit(1)

                Text(selectedBabyBirthDateLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(selectedBabyAgeLine)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                    .opacity(selectedBabyAgeLine.isEmpty ? 0 : 1)
            }

            Spacer()

            Image(systemName: "sparkles")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .padding(10)
                .background(Color.accentColor.opacity(0.16), in: Circle())
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.14),
                    Color.blue.opacity(0.1),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.42), lineWidth: 1)
        )
        .scaleEffect(heroFloat ? 1.015 : 1.0)
        .shadow(color: .black.opacity(0.1), radius: 14, x: 0, y: 8)
    }

    private var summarySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L10n.tr("today_quick_summary"))
                    .font(.headline.weight(.bold))
                Spacer()
                Text(String(format: L10n.tr("today_summary_format"), todayEvents.count))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricCard(
                    title: L10n.tr("quick_action_sleep"),
                    count: eventCount(for: [.sleep]),
                    imagePath: "home/cards/daily_sleep.png",
                    tint: .indigo
                )
                metricCard(
                    title: L10n.tr("quick_action_bottle"),
                    count: eventCount(for: [.breastfeeding, .breastfeedingLeft, .breastfeedingRight, .bottle, .pumping]),
                    imagePath: "home/cards/daily_feeding.png",
                    tint: .mint
                )
                metricCard(
                    title: L10n.tr("quick_action_diaper_change"),
                    count: eventCount(for: [.diaperChange, .diaperPee, .diaperPoop]),
                    imagePath: "home/cards/daily_diaper.png",
                    tint: .teal
                )
                metricCard(
                    title: L10n.tr("quick_action_medication"),
                    count: eventCount(for: [.medication]),
                    imagePath: "home/cards/daily_medication.png",
                    tint: .orange
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var developmentSection: some View {
        if let age = developmentAgeContext {
            let leap = leapWeekStatus(currentWeeks: age.weeks)
            let currentMilestone = monthlyMilestone(for: age.months)
            let nextMilestone = monthlyMilestone(for: min(age.months + 1, 12))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.tr("development_title"))
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text(String(format: L10n.tr("development_subtitle_format"), age.weeks, age.months))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("development_leap_title"))
                        .font(.subheadline.weight(.semibold))
                    Text(leap.title)
                        .font(.subheadline)
                        .foregroundStyle(leap.tint)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(leap.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("development_monthly_title"))
                        .font(.subheadline.weight(.semibold))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(format: L10n.tr("development_month_current_format"), currentMilestone.month))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                        Text(currentMilestone.detail)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }

                    Divider().opacity(0.45)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(format: L10n.tr("development_month_next_format"), nextMilestone.month))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(nextMilestone.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func activeSessionSection(_ session: ActiveCareSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor.opacity(0.18), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("care_session_live_subtitle"))
                        .font(.subheadline.weight(.semibold))
                    Text("\(session.childName) • \(session.type.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(session.startedAt, style: .timer)
                    .font(.title3.weight(.heavy))
                    .monospacedDigit()
            }

            HStack(spacing: 10) {
                Button {
                    if let event = sessionManager.stopAndBuildEvent(
                        note: L10n.tr("care_session_auto_note"),
                        visibility: .family
                    ) {
                        store.add(event)
                        syncStatus = String(format: L10n.tr("care_session_saved_format"), event.type.title)
                        Haptics.success()
                    }
                } label: {
                    Label(L10n.tr("quick_add_timer_stop"), systemImage: "stop.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PressableScaleButtonStyle(scale: 0.98, opacity: 0.95))
                .background(
                    LinearGradient(colors: [Color.red, Color.orange], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .foregroundStyle(.white)

                Button {
                    appState.selectedTab = .quickAdd
                    Haptics.light()
                } label: {
                    Label(L10n.tr("app_add"), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PressableScaleButtonStyle(scale: 0.98, opacity: 0.95))
                .background(
                    Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var profileSwitcherSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.tr("family_profiles_section_title"))
                    .font(.headline.weight(.bold))
                Spacer()
                Text(selectedBabyName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            BabyProfileQuickSwitcher(
                profiles: appState.babyProfiles,
                selectedId: appState.selectedBabyId,
                compact: true
            ) { id in
                appState.selectBabyProfile(id)
                Haptics.light()
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var aiCard: some View {
        let remaining = freeRemainingToday()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("health_ai_card_title"))
                        .font(.headline.weight(.bold))
                    Text(String(format: L10n.tr("health_ai_card_remaining_format"), max(0, remaining)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if remaining <= 0 {
                    Text(L10n.tr("health_ai_card_go_premium"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                appState.selectedTab = .health
            } label: {
                Label(L10n.tr("health_ai_card_cta"), systemImage: "sparkles")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var upcomingRemindersSection: some View {
        let items = upcomingReminderItems()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.tr("upcoming_reminders_title"))
                    .font(.headline.weight(.bold))
                Spacer()
                Text(String(format: L10n.tr("upcoming_reminders_count_format"), items.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(L10n.tr("upcoming_reminders_empty"))
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text(L10n.tr("upcoming_reminders_empty_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ForEach(Array(items.prefix(6))) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.iconName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(item.tint)
                            .frame(width: 28, height: 28)
                            .background(item.tint.opacity(0.16), in: Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(item.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private func freeRemainingToday() -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "ai.triage.free.questions.\(formatter.string(from: Date()))"
        let used = UserDefaults.standard.integer(forKey: key)
        return max(0, freeDailyLimit - used)
    }

    private func metricCard(title: String, count: Int, imagePath: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                GeneratedImageView(relativePath: imagePath, contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                Text("\(count)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                GeneratedImageView(relativePath: "sync/sync_success_hero.png", contentMode: .fill)
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.tr("today_daily_program"))
                        .font(.headline.weight(.semibold))
                    Text(syncStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                if syncing {
                    ProgressView()
                }
            }

            Button(syncing ? L10n.tr("today_syncing") : L10n.tr("today_sync_action")) {
                Haptics.medium()
                Task { await syncNow() }
            }
            .disabled(syncing)
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .foregroundStyle(.white)
            .buttonStyle(PressableScaleButtonStyle())

            if syncConflictStore.hasConflicts {
                Button {
                    appState.showSyncConflictCenter = true
                    Haptics.light()
                } label: {
                    HStack {
                        Label(L10n.tr("sync_conflict_title"), systemImage: "arrow.triangle.branch")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(syncConflictStore.conflicts.count)")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.orange)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var selectedProfile: BabyProfile? {
        appState.babyProfiles.first(where: { $0.id == appState.selectedBabyId })
    }

    private var selectedBabyName: String {
        selectedProfile?.name ?? appState.selectedBabyName()
    }

    private var selectedBabyBirthDateLine: String {
        selectedProfile?.birthDate.formatted(date: .abbreviated, time: .omitted) ?? ""
    }

    private var selectedBabyAgeLine: String {
        guard let birthDate = selectedProfile?.birthDate else { return "" }
        let components = Calendar.current.dateComponents([.month, .day], from: birthDate, to: Date())
        let month = max(components.month ?? 0, 0)
        let day = max(components.day ?? 0, 0)
        return String(format: L10n.tr("today_baby_age_format"), month, day)
    }

    private var developmentAgeContext: DevelopmentAgeContext? {
        guard let birthDate = selectedProfile?.birthDate else { return nil }
        let days = max(Calendar.current.dateComponents([.day], from: birthDate, to: Date()).day ?? 0, 0)
        let weeks = days / 7
        let months = max(Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0, 0)
        return DevelopmentAgeContext(weeks: weeks, months: months)
    }

    private var todayEvents: [AppEvent] {
        let calendar = Calendar.current
        return store.recent(limit: 500, childId: appState.selectedChildId())
            .filter { calendar.isDateInToday($0.timestamp) }
    }

    private func eventCount(for types: [EventType]) -> Int {
        todayEvents.filter { types.contains($0.type) }.count
    }

    private func syncNow() async {
        syncing = true
        defer { syncing = false }

        do {
            let result = try await BackendClient.shared.sync(events: store.recent(limit: 500), countryCode: appState.countryCode)
            if result.conflicts.isEmpty {
                syncStatus = String(format: L10n.tr("today_sync_ok_format"), result.acceptedCount)
                Haptics.success()
            } else {
                syncConflictStore.setPendingConflicts(result.conflicts, backupEvents: store.recent(limit: 10_000))
                appState.showSyncConflictCenter = true
                hasShownConflictStatus = true
                syncStatus = String(format: L10n.tr("today_sync_conflict_format"), result.conflicts.count)
                Haptics.warning()
            }
            AnalyticsTracker.shared.track(.syncCompleted, params: [
                "accepted": result.acceptedCount,
                "rejected": result.rejectedCount,
                "conflicts": result.conflicts.count
            ])
        } catch {
            syncStatus = L10n.tr("today_sync_offline")
            Haptics.warning()
        }
    }

    private func upcomingReminderItems() -> [UpcomingReminderItem] {
        let childId = appState.selectedChildId()
        let now = Date()
        let calendar = Calendar.current
        let endWindow = calendar.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(30 * 24 * 60 * 60)
        var items: [UpcomingReminderItem] = []

        let plans = MedicationPlanStore.snapshot(childId: childId).filter(\.isActive)
        for plan in plans {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = plan.reminderHour
            components.minute = plan.reminderMinute
            let todayCandidate = calendar.date(from: components) ?? now
            let next = todayCandidate > now ? todayCandidate : (calendar.date(byAdding: .day, value: 1, to: todayCandidate) ?? todayCandidate)
            guard next <= endWindow else { continue }
            let subtitle = plan.dosage.isEmpty
                ? L10n.tr("medication_reminder_no_dose")
                : plan.dosage
            items.append(
                UpcomingReminderItem(
                    id: "med-\(plan.id.uuidString)",
                    date: next,
                    title: plan.name,
                    subtitle: subtitle,
                    iconName: "pills.fill",
                    tint: .orange
                )
            )
        }

        if let nextCheckup = nextCheckupDate(childId: childId), nextCheckup <= endWindow {
            items.append(
                UpcomingReminderItem(
                    id: "checkup-\(Int(nextCheckup.timeIntervalSince1970))",
                    date: nextCheckup,
                    title: L10n.tr("health_item_checkup"),
                    subtitle: L10n.tr("upcoming_reminders_checkup_subtitle"),
                    iconName: "stethoscope",
                    tint: .mint
                )
            )
        }

        if let birthDate = appState.selectedBabyBirthDate() {
            let completed = completedVaccineIds(childId: childId)
            for vaccine in fallbackVaccines(for: appState.countryCode) {
                guard !completed.contains(vaccine.id), let minAgeDays = vaccine.minAgeDays else { continue }
                guard let dueDate = calendar.date(byAdding: .day, value: minAgeDays, to: birthDate) else { continue }
                guard dueDate >= now.addingTimeInterval(-7 * 24 * 60 * 60), dueDate <= endWindow else { continue }
                items.append(
                    UpcomingReminderItem(
                        id: "vac-\(vaccine.id)",
                        date: dueDate,
                        title: vaccine.name,
                        subtitle: L10n.tr("upcoming_reminders_vaccine_subtitle"),
                        iconName: "syringe.fill",
                        tint: .indigo
                    )
                )
            }
        }

        return items.sorted(by: { $0.date < $1.date })
    }

    private func syncUpcomingReminderNotifications() {
        let notifications = upcomingReminderItems().map {
            CareReminderNotificationItem(
                id: $0.id,
                title: $0.title,
                body: $0.subtitle,
                fireDate: $0.date
            )
        }
        PushNotificationManager.shared.syncCareReminders(items: notifications)
    }

    private func nextCheckupDate(childId: String) -> Date? {
        let key = "health.checkup.records.\(childId)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([HomeCheckupRecord].self, from: data) else {
            return nil
        }
        let now = Date()
        return records.map(\.date).filter { $0 >= now }.sorted().first
    }

    private func completedVaccineIds(childId: String) -> Set<String> {
        let key = "vaccine_completed_ids_\(childId)"
        return Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    private func fallbackVaccines(for countryCode: String) -> [HomeVaccineItem] {
        switch countryCode.uppercased() {
        case "TR":
            return [
                .init(id: "HB", name: "HepB", minAgeDays: 0),
                .init(id: "DTaP-IPV-Hib-HepB", name: "DaBT-IPA-Hib", minAgeDays: 60),
                .init(id: "MMR", name: "MMR", minAgeDays: 365)
            ]
        case "US":
            return [
                .init(id: "HepB", name: "HepB", minAgeDays: 0),
                .init(id: "DTaP", name: "DTaP", minAgeDays: 42),
                .init(id: "MMR", name: "MMR", minAgeDays: 365)
            ]
        case "GB":
            return [
                .init(id: "6in1", name: "6-in-1", minAgeDays: 56),
                .init(id: "MenB", name: "MenB", minAgeDays: 56),
                .init(id: "MMR", name: "MMR", minAgeDays: 365)
            ]
        case "DE":
            return [
                .init(id: "6-fach", name: "6-fach", minAgeDays: 56),
                .init(id: "Pneumokokken", name: "Pneumokokken", minAgeDays: 56),
                .init(id: "MMR", name: "MMR", minAgeDays: 335)
            ]
        case "FR":
            return [
                .init(id: "Hexavalent", name: "Hexavalent", minAgeDays: 60),
                .init(id: "PCV", name: "PCV", minAgeDays: 60),
                .init(id: "MMR", name: "MMR", minAgeDays: 365)
            ]
        case "ES":
            return [
                .init(id: "Hexavalente", name: "Hexavalente", minAgeDays: 60),
                .init(id: "Neumococo", name: "Neumococo", minAgeDays: 60),
                .init(id: "MMR", name: "MMR", minAgeDays: 365)
            ]
        case "IT":
            return [
                .init(id: "Esavalente", name: "Esavalente", minAgeDays: 60),
                .init(id: "Pneumococco", name: "Pneumococco", minAgeDays: 60),
                .init(id: "MPR", name: "MPR", minAgeDays: 365)
            ]
        case "BR":
            return [
                .init(id: "Hepatite B", name: "Hepatite B", minAgeDays: 0),
                .init(id: "Pentavalente", name: "Pentavalente", minAgeDays: 60),
                .init(id: "Tríplice viral", name: "Tríplice viral", minAgeDays: 365)
            ]
        case "SA":
            return [
                .init(id: "HepB", name: "HepB", minAgeDays: 0),
                .init(id: "Hexavalent", name: "Hexavalent", minAgeDays: 60),
                .init(id: "MMR", name: "MMR", minAgeDays: 365)
            ]
        default:
            return []
        }
    }

    private func leapWeekStatus(currentWeeks: Int) -> LeapWeekStatus {
        let leapWeeks = [5, 8, 12, 19, 26, 37, 46, 55, 64, 75]

        if let active = leapWeeks.first(where: { abs($0 - currentWeeks) <= 1 }) {
            return LeapWeekStatus(
                title: String(format: L10n.tr("development_leap_active_format"), active),
                tint: .orange
            )
        }

        if let next = leapWeeks.first(where: { $0 > currentWeeks }) {
            return LeapWeekStatus(
                title: String(
                    format: L10n.tr("development_leap_next_format"),
                    next,
                    max(next - currentWeeks, 0)
                ),
                tint: .indigo
            )
        }

        return LeapWeekStatus(
            title: L10n.tr("development_leap_done"),
            tint: .green
        )
    }

    private func monthlyMilestone(for month: Int) -> MonthlyDevelopmentMilestone {
        let clamped = max(0, min(month, 12))
        let key = "development_month_\(clamped)_detail"
        return MonthlyDevelopmentMilestone(
            month: clamped,
            detail: L10n.tr(key)
        )
    }
}

private struct UpcomingReminderItem: Identifiable {
    let id: String
    let date: Date
    let title: String
    let subtitle: String
    let iconName: String
    let tint: Color
}

private struct HomeCheckupRecord: Decodable {
    let date: Date
}

private struct HomeVaccineItem {
    let id: String
    let name: String
    let minAgeDays: Int?
}

private struct DevelopmentAgeContext {
    let weeks: Int
    let months: Int
}

private struct LeapWeekStatus {
    let title: String
    let tint: Color
}

private struct MonthlyDevelopmentMilestone {
    let month: Int
    let detail: String
}
