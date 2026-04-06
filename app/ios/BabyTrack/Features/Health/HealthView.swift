import SwiftUI
import Charts

struct HealthView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: EventStore
    @State private var heroFloat = false

    private var modules: [HealthModule] {
        [
            .init(kind: .vaccine, title: L10n.tr("health_item_vaccine"), icon: "syringe.fill", imagePath: "vaccine/overview_hero.png", tint: .indigo),
            .init(kind: .checkup, title: L10n.tr("health_item_checkup"), icon: "stethoscope", imagePath: "checkup/empty_state.png", tint: .mint),
            .init(kind: .growth, title: L10n.tr("health_item_growth"), icon: "chart.xyaxis.line", imagePath: "growth/chart_hero.png", tint: .teal),
            .init(kind: .labs, title: L10n.tr("health_item_labs"), icon: "waveform.path.ecg", imagePath: "labs/trend/ferritin.png", tint: .blue),
            .init(kind: .chronic, title: L10n.tr("health_item_chronic"), icon: "heart.text.square", imagePath: "chronic/attack_log_hero.png", tint: .orange),
            .init(kind: .triage, title: L10n.tr("health_item_triage"), icon: "cross.case.fill", imagePath: "triage/yellow_state.png", tint: .red),
            .init(kind: .doctorShare, title: L10n.tr("health_item_doctor_share"), icon: "doc.text.fill", imagePath: "doctor_share/hero.png", tint: .purple),
            .init(kind: .schoolTravel, title: L10n.tr("health_item_school_travel"), icon: "airplane", imagePath: "travel_school/travel_pack_hero.png", tint: .pink)
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        heroSection

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(modules) { module in
                                NavigationLink(value: module.kind) {
                                    moduleCard(module)
                                }
                                .buttonStyle(PressableScaleButtonStyle(scale: 0.985, opacity: 0.95))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(L10n.tr("health_title"))
            .navigationDestination(for: HealthModuleKind.self) { kind in
                switch kind {
                case .vaccine:
                    VaccineScheduleView(
                        countryCode: appState.countryCode,
                        childId: appState.selectedChildId(),
                        birthDate: appState.selectedBabyBirthDate()
                    )
                case .checkup:
                    CheckupRecordsView(
                        childId: appState.selectedChildId(),
                        unitProfile: appState.unitProfile,
                        birthDate: appState.selectedBabyBirthDate()
                    )
                case .growth:
                    GrowthRecordsView(
                        childId: appState.selectedChildId(),
                        unitProfile: appState.unitProfile,
                        birthDate: appState.selectedBabyBirthDate()
                    )
                case .labs:
                    LabRecordsView(
                        childId: appState.selectedChildId()
                    )
                case .chronic:
                    MedicationPlansView(childId: appState.selectedChildId())
                case .triage:
                    AITriageAssistantView(
                        childId: appState.selectedChildId()
                    )
                case .doctorShare:
                    DoctorShareReportView(
                        childId: appState.selectedChildId(),
                        birthDate: appState.selectedBabyBirthDate()
                    )
                case .schoolTravel:
                    SchoolTravelPlannerView(
                        childId: appState.selectedChildId(),
                        birthDate: appState.selectedBabyBirthDate()
                    )
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.7).repeatForever(autoreverses: true)) {
                    heroFloat = true
                }
            }
        }
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.accentColor.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(0.08))
                .frame(width: 250, height: 250)
                .blur(radius: 56)
                .offset(x: -140, y: -200)
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            GeneratedImageView(relativePath: "growth/chart_hero.png", contentMode: .fill)
                .frame(height: 190)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .scaleEffect(heroFloat ? 1.025 : 1.0)

            LinearGradient(
                colors: [Color.black.opacity(0.36), Color.clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            Text(L10n.tr("health_title"))
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
                .padding(16)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 10)
    }

    private func moduleCard(_ module: HealthModule) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                GeneratedImageView(relativePath: module.imagePath, contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Text(module.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private func module(for kind: HealthModuleKind) -> HealthModule {
        modules.first(where: { $0.kind == kind }) ?? modules[0]
    }
}

private struct HealthModuleWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: EventStore

    let module: HealthModule
    let preset: HealthModuleWorkspacePreset
    let childId: String

    @State private var capturingType: EventType?
    @State private var editingEvent: AppEvent?
    @State private var pendingDeleteEvent: AppEvent?
    @State private var checklistState: [String: Bool] = [:]
    @State private var triageLevel: HealthTriageLevel = .green
    @State private var historyMode: HealthHistoryMode = .recent
    @State private var historyDate = Date()
    @State private var historyBabyMonth = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                GeneratedImageView(relativePath: module.imagePath, contentMode: .fill)
                    .frame(height: 210)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(module.title)
                        .font(.title2.weight(.bold))
                    Text(L10n.tr(preset.subtitleKey))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                insightCard

                if preset.showsTriage {
                    triageCard
                }

                quickLogSection

                if preset.supportsShare {
                    shareSection
                }

                if !preset.checklistItemKeys.isEmpty {
                    checklistSection
                }

                playbookSection
                recentLogsSection

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.accentColor.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadPersistedState)
        .onChange(of: checklistState) { _ in
            saveChecklistState()
        }
        .onChange(of: triageLevel) { _ in
            saveTriageLevel()
        }
        .sheet(item: $capturingType) { type in
            QuickAddCaptureSheet(type: type, childId: childId) { event in
                store.add(event)
                Haptics.success()
            }
        }
        .sheet(item: $editingEvent) { event in
            EventEditorSheet(event: event) { updated in
                store.update(updated)
            }
        }
        .alert(L10n.tr("event_delete_confirm_title"), isPresented: Binding(
            get: { pendingDeleteEvent != nil },
            set: { if !$0 { pendingDeleteEvent = nil } }
        )) {
            Button(L10n.tr("common_cancel"), role: .cancel) {}
            Button(L10n.tr("common_delete"), role: .destructive) {
                if let event = pendingDeleteEvent {
                    store.delete(id: event.id)
                    Haptics.warning()
                }
                pendingDeleteEvent = nil
            }
        } message: {
            Text(L10n.tr("common_irreversible_action"))
        }
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("health_detail_insights_title"))
                .font(.headline.weight(.bold))

            HStack(spacing: 10) {
                metricPill(
                    title: L10n.tr("health_detail_today"),
                    value: "\(todayCount)"
                )
                metricPill(
                    title: L10n.tr("health_detail_last_7_days"),
                    value: "\(weekCount)"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.heavy))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var triageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("health_triage_title"))
                .font(.headline.weight(.bold))

            HStack(spacing: 8) {
                ForEach(HealthTriageLevel.allCases) { level in
                    Button {
                        triageLevel = level
                        Haptics.light()
                    } label: {
                        Text(L10n.tr(level.titleKey))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                triageLevel == level ? level.tint.opacity(0.26) : Color(.secondarySystemBackground),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(PressableScaleButtonStyle(scale: 0.98, opacity: 0.95))
                }
            }

            Label(L10n.tr(triageLevel.guidanceKey), systemImage: triageLevel.icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var quickLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("health_detail_quick_actions"))
                .font(.headline.weight(.bold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(preset.quickLogTypes, id: \.self) { type in
                    Button {
                        capturingType = type
                        Haptics.medium()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: type.icon)
                            Text(type.title)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "plus.circle.fill")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PressableScaleButtonStyle(scale: 0.98, opacity: 0.95))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("health_detail_share_title"))
                .font(.headline.weight(.bold))
            Text(L10n.tr("health_detail_share_subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ShareLink(item: doctorShareSummary) {
                Label(L10n.tr("health_detail_share_action"), systemImage: "square.and.arrow.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .buttonStyle(PressableScaleButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("health_detail_checklist_title"))
                .font(.headline.weight(.bold))
            ForEach(preset.checklistItemKeys, id: \.self) { key in
                Toggle(L10n.tr(key), isOn: checklistBinding(for: key))
                    .toggleStyle(.switch)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var playbookSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("health_detail_playbook_title"))
                .font(.headline.weight(.bold))

            ForEach(preset.playbookItemKeys, id: \.self) { key in
                Label(L10n.tr(key), systemImage: "checkmark.seal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.tr("health_detail_recent_logs"))
                    .font(.headline.weight(.bold))
                Spacer()
                Button {
                    appState.selectedTab = .timeline
                } label: {
                    Text(L10n.tr("health_detail_open_timeline"))
                        .font(.subheadline.weight(.semibold))
                }
            }

            Picker("", selection: $historyMode) {
                ForEach(HealthHistoryMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if historyMode == .date {
                DatePicker(L10n.tr("timeline_history_date"), selection: $historyDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            } else if historyMode == .babyMonth {
                HStack {
                    Text(L10n.tr("timeline_history_baby_month"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(
                        "\(historyBabyMonth). \(L10n.tr("timeline_history_month_suffix"))",
                        value: $historyBabyMonth,
                        in: 0...max(availableMonthCount, 0)
                    )
                    .labelsHidden()
                }
            }

            if visibleScopedEvents.isEmpty {
                healthEmptyState(
                    icon: "clock.arrow.circlepath",
                    title: L10n.tr("health_detail_no_logs")
                )
            } else {
                ForEach(Array(visibleScopedEvents.prefix(10).enumerated()), id: \.element.id) { _, event in
                    HStack(spacing: 10) {
                        Image(systemName: event.type.icon)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 26, height: 26)
                            .background(Color.accentColor.opacity(0.18), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.type.title)
                                .font(.subheadline.weight(.semibold))
                            Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        Menu {
                            Button {
                                editingEvent = event
                            } label: {
                                Label(L10n.tr("common_edit"), systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                pendingDeleteEvent = event
                            } label: {
                                Label(L10n.tr("common_delete"), systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var scopedEvents: [AppEvent] {
        store.recent(limit: 500, childId: childId)
            .filter { preset.relatedTypes.contains($0.type) }
    }

    private var visibleScopedEvents: [AppEvent] {
        HealthHistoryLogic.filterEvents(
            from: scopedEvents,
            mode: historyMode,
            historyDate: historyDate,
            historyBabyMonth: historyBabyMonth,
            birthDate: selectedProfile?.birthDate
        )
    }

    private var selectedProfile: BabyProfile? {
        appState.babyProfiles.first(where: { $0.id == appState.selectedBabyId })
    }

    private var availableMonthCount: Int {
        HealthHistoryLogic.availableMonthCount(birthDate: selectedProfile?.birthDate)
    }

    private var todayCount: Int {
        let calendar = Calendar.current
        return scopedEvents.filter { calendar.isDateInToday($0.timestamp) }.count
    }

    private var weekCount: Int {
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else {
            return scopedEvents.count
        }
        return scopedEvents.filter { $0.timestamp >= weekAgo }.count
    }

    private var checklistStorageKey: String {
        "health.checklist.\(preset.rawValue).\(childId)"
    }

    private var triageStorageKey: String {
        "health.triage.level.\(childId)"
    }

    private func checklistBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: { checklistState[key] ?? false },
            set: { checklistState[key] = $0 }
        )
    }

    private func loadPersistedState() {
        if !preset.checklistItemKeys.isEmpty {
            if let data = UserDefaults.standard.data(forKey: checklistStorageKey),
               let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
                checklistState = decoded
            } else {
                checklistState = Dictionary(uniqueKeysWithValues: preset.checklistItemKeys.map { ($0, false) })
            }
        }

        if preset.showsTriage,
           let raw = UserDefaults.standard.string(forKey: triageStorageKey),
           let level = HealthTriageLevel(rawValue: raw) {
            triageLevel = level
        }
    }

    private func saveChecklistState() {
        guard !preset.checklistItemKeys.isEmpty,
              let data = try? JSONEncoder().encode(checklistState) else { return }
        UserDefaults.standard.set(data, forKey: checklistStorageKey)
    }

    private func saveTriageLevel() {
        guard preset.showsTriage else { return }
        UserDefaults.standard.set(triageLevel.rawValue, forKey: triageStorageKey)
    }

    private var doctorShareSummary: String {
        let calendar = Calendar.current
        let now = Date()
        let snapshot = DoctorShareComposer.snapshot(events: scopedEvents, now: now, calendar: calendar)
        let recent = Array(scopedEvents.prefix(10))

        let baby = appState.babyProfiles.first(where: { $0.id.uuidString == childId })
        let babyName = baby?.name ?? L10n.tr("family_baby_fallback_name")
        let ageMonths = baby.map { max(calendar.dateComponents([.month], from: $0.birthDate, to: now).month ?? 0, 0) }

        return DoctorShareComposer.buildCompactSummary(
            childName: babyName,
            ageMonths: ageMonths,
            snapshot: snapshot,
            recentEvents: recent,
            generatedAt: now
        )
    }
}

private struct DoctorShareReportView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var eventStore: EventStore

    let childId: String
    let birthDate: Date?

    @StateObject private var medicationStore: MedicationPlanStore
    @State private var historyMode: HealthHistoryMode = .recent
    @State private var historyDate = Date()
    @State private var historyBabyMonth = 0

    init(childId: String, birthDate: Date?) {
        self.childId = childId
        self.birthDate = birthDate
        _medicationStore = StateObject(wrappedValue: MedicationPlanStore(childId: childId))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                headerCard
                snapshotCard
                activeMedicationCard
                historyFilterCard
                recentRecordsCard
                shareCard
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.accentColor.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(L10n.tr("health_item_doctor_share"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("doctor_share_report_title"))
                .font(.headline.weight(.bold))
            Text(String(format: L10n.tr("doctor_share_report_generated_format"), Date().formatted(date: .abbreviated, time: .shortened)))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: L10n.tr("doctor_share_report_child_format"), selectedBaby?.name ?? L10n.tr("family_baby_fallback_name")))
                .font(.subheadline.weight(.semibold))
            if let months = ageMonths {
                Text(String(format: L10n.tr("doctor_share_report_age_format"), months))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            if let selectedBaby {
                let details = birthMetaLines(for: selectedBaby)
                if !details.isEmpty {
                    Divider()
                    ForEach(details, id: \.self) { line in
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .healthCardStyle()
    }

    private var snapshotCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("doctor_share_report_summary_title"))
                .font(.headline.weight(.bold))

            HStack(spacing: 8) {
                snapshotPill(title: L10n.tr("health_detail_today"), value: "\(todayEvents.count)")
                snapshotPill(title: L10n.tr("health_detail_last_7_days"), value: "\(weekEvents.count)")
            }

            Text(
                String(
                    format: L10n.tr("doctor_share_report_summary_format"),
                    todayEvents.count,
                    todayEvents.filter { $0.type.isFeedingRelated }.count,
                    todayEvents.filter { $0.type == .sleep }.count,
                    todayEvents.filter { $0.type.isDiaperRelated }.count,
                    todayEvents.filter { $0.type == .medication }.count,
                    todayEvents.filter { $0.type == .fever }.count
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .healthCardStyle()
    }

    private func snapshotPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.heavy))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var activeMedicationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("doctor_share_active_medications_title"))
                .font(.headline.weight(.bold))

            let active = medicationStore.activePlans
            if active.isEmpty {
                Text(L10n.tr("doctor_share_active_medications_empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(active) { plan in
                    HStack(spacing: 8) {
                        Image(systemName: "pills.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.name)
                                .font(.subheadline.weight(.semibold))
                            Text(medicationSubtitle(plan))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .healthCardStyle()
    }

    private var historyFilterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("doctor_share_recent_filter_title"))
                .font(.headline.weight(.bold))

            Picker("", selection: $historyMode) {
                ForEach(HealthHistoryMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if historyMode == .date {
                DatePicker(L10n.tr("timeline_history_date"), selection: $historyDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            } else if historyMode == .babyMonth {
                HStack {
                    Text(L10n.tr("timeline_history_baby_month"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(
                        "\(historyBabyMonth). \(L10n.tr("timeline_history_month_suffix"))",
                        value: $historyBabyMonth,
                        in: 0...max(availableMonthCount, 0)
                    )
                    .labelsHidden()
                }
            }
        }
        .healthCardStyle()
    }

    private var recentRecordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("doctor_share_report_recent_title"))
                .font(.headline.weight(.bold))

            if filteredEvents.isEmpty {
                healthEmptyState(
                    icon: "doc.text.magnifyingglass",
                    title: L10n.tr("doctor_share_report_no_events")
                )
            } else {
                ForEach(Array(filteredEvents.prefix(10))) { event in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(Color.accentColor.opacity(0.8))
                                .frame(width: 8, height: 8)
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.26))
                                .frame(width: 1)
                        }
                        .frame(width: 10)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.type.title)
                                .font(.subheadline.weight(.semibold))
                            Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !event.note.isEmpty {
                                Text(event.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            EventPayloadSummaryView(event: event)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .healthCardStyle()
    }

    private var shareCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("doctor_share_share_card_title"))
                .font(.headline.weight(.bold))
            Text(L10n.tr("doctor_share_share_card_subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ShareLink(item: reportText) {
                Label(L10n.tr("health_detail_share_action"), systemImage: "square.and.arrow.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .buttonStyle(PressableScaleButtonStyle())
        }
        .healthCardStyle()
    }

    private var reportText: String {
        DoctorShareComposer.buildFullReport(
            childName: selectedBaby?.name ?? L10n.tr("family_baby_fallback_name"),
            ageMonths: ageMonths,
            birthLines: selectedBaby.map { DoctorShareComposer.birthMetaLines(for: $0) } ?? [],
            snapshot: DoctorShareComposer.snapshot(events: allEvents),
            activeMedications: medicationStore.activePlans,
            filteredEvents: filteredEvents,
            generatedAt: Date()
        )
    }

    private var selectedBaby: BabyProfile? {
        appState.babyProfiles.first(where: { $0.id.uuidString == childId })
    }

    private var ageMonths: Int? {
        guard let birthDate else { return nil }
        return max(Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0, 0)
    }

    private var allEvents: [AppEvent] {
        eventStore.recent(limit: 500, childId: childId)
    }

    private var filteredEvents: [AppEvent] {
        DoctorShareComposer.filteredEvents(
            from: allEvents,
            mode: historyMode,
            historyDate: historyDate,
            historyBabyMonth: historyBabyMonth,
            birthDate: birthDate
        )
    }

    private var todayEvents: [AppEvent] {
        let calendar = Calendar.current
        return allEvents.filter { calendar.isDateInToday($0.timestamp) }
    }

    private var weekEvents: [AppEvent] {
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else {
            return allEvents
        }
        return allEvents.filter { $0.timestamp >= weekAgo }
    }

    private var availableMonthCount: Int {
        guard let birthDate else { return 36 }
        return max(Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0, 0)
    }

    private func medicationSubtitle(_ plan: MedicationPlan) -> String {
        DoctorShareComposer.medicationSubtitle(plan)
    }

    private func medicationLine(_ plan: MedicationPlan) -> String {
        DoctorShareComposer.medicationLine(plan)
    }

    private func reportLine(_ event: AppEvent) -> String {
        DoctorShareComposer.reportLine(event)
    }

    private func birthMetaLines(for profile: BabyProfile) -> [String] {
        DoctorShareComposer.birthMetaLines(for: profile)
    }
}

private struct SchoolTravelPlannerView: View {
    @StateObject private var store: SchoolTravelPlanStore

    let childId: String
    let birthDate: Date?

    @State private var mode: SchoolTravelMode = .school
    @State private var planTitle = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var notes = ""
    @State private var draftChecklist: [SchoolTravelChecklistItem] = []
    @State private var newChecklistItem = ""
    @State private var historyMode: HealthHistoryMode = .recent
    @State private var historyDate = Date()
    @State private var historyBabyMonth = 0

    init(childId: String, birthDate: Date?) {
        self.childId = childId
        self.birthDate = birthDate
        _store = StateObject(wrappedValue: SchoolTravelPlanStore(childId: childId))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                headerCard
                plannerCard
                checklistCard
                saveCard
                historyCard
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.accentColor.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(L10n.tr("health_item_school_travel"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: mode) { _ in
            if draftChecklist.isEmpty {
                applyTemplate()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("school_travel_header_title"))
                .font(.headline.weight(.bold))
            Text(L10n.tr("school_travel_header_subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let months = ageMonths {
                Text(String(format: L10n.tr("school_travel_age_context_format"), months))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .healthCardStyle()
    }

    private var plannerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("school_travel_plan_builder_title"))
                .font(.headline.weight(.bold))

            Picker(L10n.tr("school_travel_mode_label"), selection: $mode) {
                ForEach(SchoolTravelMode.allCases) { mode in
                    Text(L10n.tr(mode.titleKey)).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            TextField(L10n.tr("school_travel_plan_title_placeholder"), text: $planTitle)

            DatePicker(L10n.tr("school_travel_start_date"), selection: $startDate, displayedComponents: .date)
            DatePicker(L10n.tr("school_travel_end_date"), selection: $endDate, in: startDate..., displayedComponents: .date)
            TextField(L10n.tr("school_travel_plan_note_label"), text: $notes, axis: .vertical)
                .lineLimit(2...4)
        }
        .healthCardStyle()
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.tr("school_travel_checklist_title"))
                    .font(.headline.weight(.bold))
                Spacer()
                Button(L10n.tr("school_travel_apply_template")) {
                    applyTemplate()
                }
                .font(.subheadline.weight(.semibold))
            }

            if draftChecklist.isEmpty {
                Text(L10n.tr("school_travel_checklist_empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach($draftChecklist) { $item in
                    Toggle(item.title, isOn: $item.isDone)
                        .toggleStyle(.switch)
                }
            }

            HStack(spacing: 8) {
                TextField(L10n.tr("school_travel_checklist_add_placeholder"), text: $newChecklistItem)
                Button {
                    addDraftChecklistItem()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .disabled(newChecklistItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .healthCardStyle()
    }

    private var saveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                saveDraftPlan()
            } label: {
                Label(L10n.tr("school_travel_save_plan_action"), systemImage: "checkmark.circle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .buttonStyle(PressableScaleButtonStyle())

            Text(L10n.tr("school_travel_save_plan_hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .healthCardStyle()
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("school_travel_history_title"))
                .font(.headline.weight(.bold))

            Picker("", selection: $historyMode) {
                ForEach(HealthHistoryMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if historyMode == .date {
                DatePicker(L10n.tr("timeline_history_date"), selection: $historyDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            } else if historyMode == .babyMonth {
                HStack {
                    Text(L10n.tr("timeline_history_baby_month"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(
                        "\(historyBabyMonth). \(L10n.tr("timeline_history_month_suffix"))",
                        value: $historyBabyMonth,
                        in: 0...max(availableMonthCount, 0)
                    )
                    .labelsHidden()
                }
            }

            if filteredPlans.isEmpty {
                healthEmptyState(
                    icon: "airplane.circle",
                    title: L10n.tr("school_travel_history_empty"),
                    subtitle: L10n.tr("health_empty_history_hint")
                )
            } else {
                ForEach(filteredPlans.prefix(10)) { plan in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(plan.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(L10n.tr(plan.mode.titleKey))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.14), in: Capsule())
                        }
                        Text(
                            String(
                                format: L10n.tr("school_travel_plan_range_format"),
                                plan.startDate.formatted(date: .abbreviated, time: .omitted),
                                plan.endDate.formatted(date: .abbreviated, time: .omitted)
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text(
                            String(
                                format: L10n.tr("school_travel_progress_format"),
                                plan.checklist.filter(\.isDone).count,
                                max(plan.checklist.count, 1)
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if !plan.notes.isEmpty {
                            Text(plan.notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        HStack {
                            Spacer()
                            Button(L10n.tr("common_delete"), role: .destructive) {
                                store.delete(plan.id)
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .healthCardStyle()
    }

    private var ageMonths: Int? {
        guard let birthDate else { return nil }
        return max(Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0, 0)
    }

    private var filteredPlans: [SchoolTravelPlan] {
        HealthHistoryLogic.filterSchoolTravelPlans(
            from: store.plans,
            mode: historyMode,
            historyDate: historyDate,
            historyBabyMonth: historyBabyMonth,
            birthDate: birthDate
        )
    }

    private var availableMonthCount: Int {
        HealthHistoryLogic.availableMonthCount(birthDate: birthDate)
    }

    private func applyTemplate() {
        draftChecklist = SchoolTravelMode.templateItems(for: mode).map {
            SchoolTravelChecklistItem(title: L10n.tr($0), isDone: false)
        }
    }

    private func addDraftChecklistItem() {
        let trimmed = newChecklistItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        draftChecklist.append(SchoolTravelChecklistItem(title: trimmed, isDone: false))
        newChecklistItem = ""
    }

    private func saveDraftPlan() {
        let fallbackTitle = String(format: L10n.tr("school_travel_plan_title_fallback_format"), L10n.tr(mode.titleKey))
        let plan = SchoolTravelPlan(
            childId: childId,
            mode: mode,
            title: planTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackTitle : planTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: endDate,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            checklist: draftChecklist,
            createdAt: Date()
        )
        store.upsert(plan)
        notes = ""
        planTitle = ""
        draftChecklist.removeAll()
        Haptics.success()
    }
}

@MainActor
private final class SchoolTravelPlanStore: ObservableObject {
    @Published private(set) var plans: [SchoolTravelPlan] = []
    private let key: String

    init(childId: String) {
        self.key = "school.travel.plans.\(childId)"
        load()
    }

    func upsert(_ plan: SchoolTravelPlan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }
        plans.sort { $0.startDate > $1.startDate }
        save()
    }

    func delete(_ id: UUID) {
        plans.removeAll(where: { $0.id == id })
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SchoolTravelPlan].self, from: data) else {
            plans = []
            return
        }
        plans = decoded.sorted(by: { $0.startDate > $1.startDate })
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(plans) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct VaccineScheduleView: View {
    let countryCode: String
    let childId: String
    let birthDate: Date?

    @StateObject private var manualStore: VaccineManualStore
    @StateObject private var completionStore: VaccineCompletionStore
    @State private var showAddManual = false
    @State private var editingManualEntry: ManualVaccineEntry?
    @State private var remoteSchedule: [RecommendedVaccine] = []
    @State private var remoteSourceLabel: String?
    @State private var remoteSourceURL: URL?
    @State private var remoteSourceRegistryUpdatedAt: String?
    @State private var remoteSourcePublishedAt: String?
    @State private var remoteSourceFetchedAt: Date?
    @State private var isLoadingRemote = false

    init(countryCode: String, childId: String, birthDate: Date?) {
        self.countryCode = countryCode
        self.childId = childId
        self.birthDate = birthDate
        _manualStore = StateObject(wrappedValue: VaccineManualStore(storageKey: childId))
        _completionStore = StateObject(wrappedValue: VaccineCompletionStore(storageKey: childId))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                headerCard
                sourceFreshnessCard
                sourceAlertCard

                if recommendedSchedule.isEmpty {
                    missingCountryCard
                } else {
                    recommendedSection
                }

                manualSection
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.accentColor.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(L10n.tr("health_item_vaccine"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddManual) {
            ManualVaccineEditorSheet { newEntry in
                manualStore.add(newEntry)
            }
        }
        .sheet(item: $editingManualEntry) { entry in
            ManualVaccineEditorSheet(existingEntry: entry) { updated in
                manualStore.update(updated)
            }
        }
        .task(id: countryCode) {
            await loadRemoteSchedule()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("vaccine_country_schedule_title"))
                        .font(.headline.weight(.bold))

                    Text(String(format: L10n.tr("vaccine_country_schedule_subtitle_format"), countryCode))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                sourceStatusBadge
            }

            if isLoadingRemote {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(L10n.tr("vaccine_loading_schedule"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(sourceStatus.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let remoteSourceLabel {
                Label(String(format: L10n.tr("vaccine_data_source_format"), remoteSourceLabel), systemImage: "checklist")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            } else {
                Label(L10n.tr("vaccine_data_source_offline"), systemImage: "tray")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            if let remoteSourceURL {
                Link(destination: remoteSourceURL) {
                    Label(L10n.tr("vaccine_data_source_open_link"), systemImage: "link")
                        .font(.caption.weight(.semibold))
                }
                .tint(Color.accentColor)
            }

            if let ageMonth = babyAgeMonths {
                Text(String(format: L10n.tr("vaccine_age_month_format"), ageMonth))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var sourceFreshnessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("vaccine_data_source_health_title"))
                .font(.subheadline.weight(.bold))

            Text(L10n.tr("vaccine_data_source_health_subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 10)], spacing: 10) {
                sourceMetricCard(
                    title: L10n.tr("vaccine_data_source_health_source_title"),
                    value: formattedSourceDate(remoteSourceRegistryUpdatedAt) ?? L10n.tr("vaccine_data_source_health_missing"),
                    relativeValue: relativeSourceDate(remoteSourceRegistryUpdatedAt),
                    systemImage: "calendar.badge.clock",
                    tint: sourceStatus.tint
                )
                sourceMetricCard(
                    title: L10n.tr("vaccine_data_source_health_package_title"),
                    value: formattedSourceDate(remoteSourcePublishedAt) ?? L10n.tr("vaccine_data_source_health_missing"),
                    relativeValue: relativeSourceDate(remoteSourcePublishedAt),
                    systemImage: "shippingbox.fill",
                    tint: Color.blue
                )
                sourceMetricCard(
                    title: L10n.tr("vaccine_data_source_health_sync_title"),
                    value: formattedDate(remoteSourceFetchedAt) ?? L10n.tr("vaccine_data_source_health_missing"),
                    relativeValue: relativeDate(remoteSourceFetchedAt),
                    systemImage: "arrow.trianglehead.clockwise",
                    tint: Color.green
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(sourceStatus.tint.opacity(0.16), lineWidth: 1)
        )
    }

    private func sourceMetricCard(title: String, value: String, relativeValue: String?, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if let relativeValue, !relativeValue.isEmpty {
                Text(relativeValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(" ")
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(12)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var sourceStatus: VaccineSourceStatus {
        guard remoteSourceLabel != nil else { return .offline }
        guard let referenceDate = parsedSourceDate(remoteSourceRegistryUpdatedAt)
            ?? parsedSourceDate(remoteSourcePublishedAt)
            ?? remoteSourceFetchedAt else {
            return .cached
        }

        let ageDays = max(Calendar.current.dateComponents([.day], from: referenceDate, to: Date()).day ?? 0, 0)
        if ageDays <= 14 {
            return .live
        }
        if ageDays <= 60 {
            return .cached
        }
        return .review
    }

    private var sourceStatusBadge: some View {
        let status = sourceStatus
        return Label(L10n.tr(status.badgeKey), systemImage: status.systemImage)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.tint.opacity(0.16), in: Capsule())
            .foregroundStyle(status.tint)
    }

    @ViewBuilder
    private var sourceAlertCard: some View {
        switch sourceStatus {
        case .review:
            sourceMessageCard(
                title: L10n.tr("vaccine_data_source_alert_review_title"),
                message: L10n.tr("vaccine_data_source_alert_review_body"),
                tint: .orange,
                systemImage: "exclamationmark.triangle.fill"
            )
        case .offline:
            sourceMessageCard(
                title: L10n.tr("vaccine_data_source_alert_offline_title"),
                message: L10n.tr("vaccine_data_source_alert_offline_body"),
                tint: .secondary,
                systemImage: "wifi.slash"
            )
        default:
            EmptyView()
        }
    }

    private func sourceMessageCard(title: String, message: String, tint: Color, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let remoteSourceURL {
                Link(destination: remoteSourceURL) {
                    Label(L10n.tr("vaccine_data_source_open_link"), systemImage: "safari")
                        .font(.caption.weight(.semibold))
                }
                .tint(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        )
    }

    private var missingCountryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("vaccine_no_country_schedule_title"))
                .font(.headline.weight(.bold))
            Text(L10n.tr("vaccine_no_country_schedule_subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(L10n.tr("vaccine_manual_add_action")) {
                showAddManual = true
            }
            .buttonStyle(PressableScaleButtonStyle())
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("vaccine_recommended_section"))
                .font(.headline.weight(.bold))

            ForEach(recommendedSchedule) { item in
                HStack(spacing: 10) {
                    let completed = completionStore.isCompleted(item.id)
                    let status = vaccineStatus(for: item, completed: completed)

                    Button {
                        completionStore.toggle(item.id)
                    } label: {
                        Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(completed ? .green : .secondary)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline.weight(.semibold))
                        Text(item.dueLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(status.title)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(status.tint.opacity(0.16), in: Capsule())
                        .foregroundStyle(status.tint)
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.tr("vaccine_manual_section"))
                    .font(.headline.weight(.bold))
                Spacer()
                Button {
                    showAddManual = true
                } label: {
                    Label(L10n.tr("vaccine_manual_add_action"), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }

            if manualStore.entries.isEmpty {
                Text(L10n.tr("vaccine_manual_empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(manualStore.entries) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: "syringe")
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .font(.subheadline.weight(.semibold))
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !entry.note.isEmpty {
                                Text(entry.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        Button {
                            editingManualEntry = entry
                        } label: {
                            Image(systemName: "pencil")
                        }
                        Button(role: .destructive) {
                            manualStore.delete(entry.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var recommendedSchedule: [RecommendedVaccine] {
        if !remoteSchedule.isEmpty {
            return remoteSchedule
        }
        return VaccineScheduleCatalog.schedule(for: countryCode)
    }

    private var babyAgeMonths: Int? {
        guard let birthDate else { return nil }
        return max(Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0, 0)
    }

    private func loadRemoteSchedule() async {
        isLoadingRemote = true
        defer { isLoadingRemote = false }
        let cc = countryCode.uppercased()
        var latestIndexItem: VaccinePackageIndexItem?

        do {
            let index = try await BackendClient.shared.fetchVaccinePackageIndex()
            latestIndexItem = index.packages.first(where: { $0.country.uppercased() == cc })
            if let latest = latestIndexItem,
               let cached = VaccinePackageCache.load(countryCode: cc),
               cached.version == latest.version,
               cached.isFresh {
                let mapped = mapRemoteRecords(cached.records)
                if !mapped.isEmpty {
                    remoteSchedule = mapped
                    applyRemoteSourceMetadata(
                        label: "\(cached.authority) v\(cached.version)",
                        sourceURLString: cached.sourceURL ?? latest.sourceUrl,
                        registryUpdatedAt: cached.sourceUpdatedAt ?? latest.sourceUpdatedAt,
                        publishedAt: cached.publishedAt ?? latest.publishedAt,
                        fetchedAt: cached.fetchedAt
                    )
                    return
                }
            }
        } catch {
            // index endpoint unavailable; continue with latest fetch fallback
        }

        do {
            let payload = try await BackendClient.shared.fetchLatestVaccinePackage(countryCode: cc)
            let mapped = mapRemoteRecords(payload.records)
            if !mapped.isEmpty {
                remoteSchedule = mapped
                applyRemoteSourceMetadata(
                    label: "\(payload.authority) v\(payload.version)",
                    sourceURLString: payload.source?.url ?? latestIndexItem?.sourceUrl,
                    registryUpdatedAt: payload.source?.sourceUpdatedAt ?? latestIndexItem?.sourceUpdatedAt,
                    publishedAt: latestIndexItem?.publishedAt,
                    fetchedAt: parsedSourceDate(payload.source?.retrievedAt) ?? Date()
                )
                VaccinePackageCache.save(
                    countryCode: cc,
                    authority: payload.authority,
                    version: payload.version,
                    records: payload.records,
                    sourceURL: payload.source?.url ?? latestIndexItem?.sourceUrl,
                    sourceUpdatedAt: payload.source?.sourceUpdatedAt ?? latestIndexItem?.sourceUpdatedAt,
                    publishedAt: latestIndexItem?.publishedAt
                )
                return
            }
        } catch {
            if let cached = VaccinePackageCache.load(countryCode: cc) {
                let mapped = mapRemoteRecords(cached.records)
                if !mapped.isEmpty {
                    remoteSchedule = mapped
                    applyRemoteSourceMetadata(
                        label: "\(cached.authority) v\(cached.version)",
                        sourceURLString: cached.sourceURL ?? latestIndexItem?.sourceUrl,
                        registryUpdatedAt: cached.sourceUpdatedAt ?? latestIndexItem?.sourceUpdatedAt,
                        publishedAt: cached.publishedAt ?? latestIndexItem?.publishedAt,
                        fetchedAt: cached.fetchedAt
                    )
                    return
                }
            }
        }

        remoteSchedule = []
        applyRemoteSourceMetadata(label: nil, sourceURLString: nil, registryUpdatedAt: nil, publishedAt: nil, fetchedAt: nil)
    }

    private func applyRemoteSourceMetadata(
        label: String?,
        sourceURLString: String?,
        registryUpdatedAt: String?,
        publishedAt: String?,
        fetchedAt: Date?
    ) {
        remoteSourceLabel = label
        if let sourceURLString,
           !sourceURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = URL(string: sourceURLString) {
            remoteSourceURL = url
        } else {
            remoteSourceURL = nil
        }
        remoteSourceRegistryUpdatedAt = registryUpdatedAt
        remoteSourcePublishedAt = publishedAt
        remoteSourceFetchedAt = fetchedAt
    }

    private func formattedSourceDate(_ raw: String?) -> String? {
        guard let date = parsedSourceDate(raw) else { return sanitizedSourceDateString(raw) }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func formattedDate(_ value: Date?) -> String? {
        guard let value else { return nil }
        return value.formatted(date: .abbreviated, time: .shortened)
    }

    private func relativeSourceDate(_ raw: String?) -> String? {
        guard let date = parsedSourceDate(raw) else { return nil }
        return relativeDate(date)
    }

    private func relativeDate(_ value: Date?) -> String? {
        guard let value else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: value, relativeTo: Date())
    }

    private func parsedSourceDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: trimmed) {
            return date
        }

        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.calendar = Calendar(identifier: .gregorian)
        day.dateFormat = "yyyy-MM-dd"
        if let date = day.date(from: trimmed) {
            return date
        }

        return nil
    }

    private func sanitizedSourceDateString(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func mapRemoteRecords(_ records: [VaccinePackageRecord]) -> [RecommendedVaccine] {
        let grouped = Dictionary(grouping: records, by: \.vaccineCode)
        let mapped: [(minAge: Int, item: RecommendedVaccine)] = grouped.compactMap { code, items in
            let sorted = items.sorted { $0.minAgeDays < $1.minAgeDays }
            guard let first = sorted.first else { return nil }
            let dueParts = sorted.map { record in
                ageLabel(minDays: record.minAgeDays, maxDays: record.maxAgeDays)
            }
            return (
                minAge: first.minAgeDays,
                item: RecommendedVaccine(
                    id: code,
                    name: code,
                    dueLabel: dueParts.joined(separator: ", "),
                    minAgeDays: first.minAgeDays
                )
            )
        }
        return mapped.sorted { $0.minAge < $1.minAge }.map(\.item)
    }

    private func ageLabel(minDays: Int, maxDays: Int?) -> String {
        if minDays <= 7 {
            return L10n.tr("vaccine_due_birth")
        }

        let minMonths = max(1, Int(round(Double(minDays) / 30.0)))
        guard let maxDays, maxDays > minDays + 20 else {
            return String(format: L10n.tr("vaccine_due_month_format"), minMonths)
        }

        let maxMonths = max(minMonths, Int(round(Double(maxDays) / 30.0)))
        return String(format: L10n.tr("vaccine_due_month_range_format"), minMonths, maxMonths)
    }

    private func vaccineStatus(for item: RecommendedVaccine, completed: Bool) -> VaccineStatus {
        if completed {
            return .done
        }
        guard let dueDays = item.minAgeDays,
              let birthDate else {
            return .upcoming
        }
        let ageDays = max(Calendar.current.dateComponents([.day], from: birthDate, to: Date()).day ?? 0, 0)
        if ageDays >= dueDays + 45 {
            return .overdue
        }
        if ageDays >= max(dueDays - 14, 0) {
            return .due
        }
        return .upcoming
    }
}

private struct ManualVaccineEditorSheet: View {
    var existingEntry: ManualVaccineEntry?
    var onSave: (ManualVaccineEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var date = Date()
    @State private var note = ""

    init(existingEntry: ManualVaccineEntry? = nil, onSave: @escaping (ManualVaccineEntry) -> Void) {
        self.existingEntry = existingEntry
        self.onSave = onSave
        _name = State(initialValue: existingEntry?.name ?? "")
        _date = State(initialValue: existingEntry?.date ?? Date())
        _note = State(initialValue: existingEntry?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(L10n.tr("vaccine_manual_name_label"), text: $name)
                DatePicker(L10n.tr("vaccine_manual_date_label"), selection: $date, displayedComponents: .date)
                TextField(L10n.tr("vaccine_manual_note_label"), text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
            .navigationTitle(L10n.tr(existingEntry == nil ? "vaccine_manual_add_action" : "vaccine_manual_edit_action"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("common_save")) {
                        onSave(
                            ManualVaccineEntry(
                                id: existingEntry?.id ?? UUID(),
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                date: date,
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct CheckupRecordsView: View {
    let childId: String
    let unitProfile: UnitProfile
    let birthDate: Date?

    @StateObject private var store: CheckupRecordStore
    @State private var addSheetPresented = false
    @State private var editing: CheckupRecord?

    init(childId: String, unitProfile: UnitProfile, birthDate: Date?) {
        self.childId = childId
        self.unitProfile = unitProfile
        self.birthDate = birthDate
        _store = StateObject(wrappedValue: CheckupRecordStore(childId: childId))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                if let latest = store.records.first {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.tr("health_trend_last"))
                            .font(.headline.weight(.bold))
                        Text(latest.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            metricChip(title: L10n.tr("health_field_weight"), value: formatWeight(latest.weightKg))
                            metricChip(title: L10n.tr("health_field_length"), value: formatLength(latest.lengthCm))
                            metricChip(title: L10n.tr("health_field_head"), value: formatLength(latest.headCircumferenceCm))
                        }
                    }
                    .healthCardStyle()
                }

                sectionHeader(title: L10n.tr("health_checkup_records_title")) {
                    addSheetPresented = true
                }

                if store.records.isEmpty {
                    Text(L10n.tr("health_empty_records"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                } else {
                    trendChart(records: store.records)

                    VStack(spacing: 10) {
                        ForEach(store.records) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Menu {
                                        Button(L10n.tr("common_edit"), systemImage: "pencil") {
                                            editing = item
                                        }
                                        Button(L10n.tr("common_delete"), systemImage: "trash", role: .destructive) {
                                            store.delete(id: item.id)
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                HStack(spacing: 8) {
                                    metricChip(title: L10n.tr("health_field_weight"), value: formatWeight(item.weightKg))
                                    metricChip(title: L10n.tr("health_field_length"), value: formatLength(item.lengthCm))
                                    metricChip(title: L10n.tr("health_field_head"), value: formatLength(item.headCircumferenceCm))
                                }

                                if !item.doctorName.isEmpty || !item.clinicName.isEmpty {
                                    Text([item.doctorName, item.clinicName]
                                        .filter { !$0.isEmpty }
                                        .joined(separator: " • "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                if !item.note.isEmpty {
                                    Text(item.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .healthCardStyle()
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(L10n.tr("health_item_checkup"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $addSheetPresented) {
            CheckupEditorSheet(unitProfile: unitProfile, birthDate: birthDate) { newRecord in
                store.upsert(newRecord)
            }
        }
        .sheet(item: $editing) { record in
            CheckupEditorSheet(existing: record, unitProfile: unitProfile, birthDate: birthDate) { updated in
                store.upsert(updated)
            }
        }
    }

    private func formatWeight(_ value: Double?) -> String {
        guard let value else { return "-" }
        switch unitProfile.weight {
        case .kg:
            return "\(value.formatted(.number.precision(.fractionLength(1)))) kg"
        case .lb:
            let lb = value * 2.20462
            return "\(lb.formatted(.number.precision(.fractionLength(1)))) lb"
        }
    }

    private func formatLength(_ value: Double?) -> String {
        guard let value else { return "-" }
        switch unitProfile.length {
        case .cm:
            return "\(value.formatted(.number.precision(.fractionLength(1)))) cm"
        case .inch:
            let inch = value / 2.54
            return "\(inch.formatted(.number.precision(.fractionLength(1)))) in"
        }
    }

    @ViewBuilder
    private func trendChart(records: [CheckupRecord]) -> some View {
        let points = records.sorted(by: { $0.date < $1.date }).suffix(8)
        if points.count >= 2 {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.tr("health_trend_chart_title"))
                    .font(.headline.weight(.bold))

                Chart {
                    ForEach(points, id: \.id) { item in
                        if let w = item.weightKg {
                            LineMark(
                                x: .value(L10n.tr("chart_axis_date"), item.date),
                                y: .value(L10n.tr("health_trend_weight"), convertWeight(w))
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)
                        }
                        if let l = item.lengthCm {
                            LineMark(
                                x: .value(L10n.tr("chart_axis_date"), item.date),
                                y: .value(L10n.tr("health_trend_length"), convertLength(l))
                            )
                            .foregroundStyle(.mint)
                            .interpolationMethod(.catmullRom)
                        }
                        if let h = item.headCircumferenceCm {
                            LineMark(
                                x: .value(L10n.tr("chart_axis_date"), item.date),
                                y: .value(L10n.tr("health_trend_head"), convertLength(h))
                            )
                            .foregroundStyle(.purple)
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .chartXAxis(.automatic)
                .frame(height: 180)
            }
            .healthCardStyle()
        }
    }

    private func convertWeight(_ kg: Double) -> Double {
        switch unitProfile.weight {
        case .kg: return kg
        case .lb: return kg * 2.20462
        }
    }

    private func convertLength(_ cm: Double) -> Double {
        switch unitProfile.length {
        case .cm: return cm
        case .inch: return cm / 2.54
        }
    }
}

private struct GrowthRecordsView: View {
    let childId: String
    let unitProfile: UnitProfile
    let birthDate: Date?

    @StateObject private var store: GrowthRecordStore
    @State private var addSheetPresented = false
    @State private var editing: GrowthRecord?
    @State private var selectedMetric: GrowthMetric = .weight

    init(childId: String, unitProfile: UnitProfile, birthDate: Date?) {
        self.childId = childId
        self.unitProfile = unitProfile
        self.birthDate = birthDate
        _store = StateObject(wrappedValue: GrowthRecordStore(childId: childId))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                sectionHeader(title: L10n.tr("health_growth_records_title")) {
                    addSheetPresented = true
                }

                if store.records.isEmpty {
                    Text(L10n.tr("health_empty_records"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                } else {
                    Picker("", selection: $selectedMetric) {
                        ForEach(GrowthMetric.allCases) { metric in
                            Text(metric.title).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)

                    trendChart(records: store.records)

                    if let warning = growthWarningText(records: store.records) {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    VStack(spacing: 10) {
                        ForEach(store.records) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Menu {
                                        Button(L10n.tr("common_edit"), systemImage: "pencil") {
                                            editing = item
                                        }
                                        Button(L10n.tr("common_delete"), systemImage: "trash", role: .destructive) {
                                            store.delete(id: item.id)
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                HStack(spacing: 8) {
                                    metricChip(title: L10n.tr("health_field_weight"), value: formatWeight(item.weightKg))
                                    metricChip(title: L10n.tr("health_field_length"), value: formatLength(item.lengthCm))
                                    metricChip(title: L10n.tr("health_field_head"), value: formatLength(item.headCircumferenceCm))
                                }

                                if !item.note.isEmpty {
                                    Text(item.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .healthCardStyle()
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(L10n.tr("health_item_growth"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $addSheetPresented) {
            GrowthEditorSheet(unitProfile: unitProfile) { newRecord in
                store.upsert(newRecord)
            }
        }
        .sheet(item: $editing) { record in
            GrowthEditorSheet(existing: record, unitProfile: unitProfile) { updated in
                store.upsert(updated)
            }
        }
    }

    private func formatWeight(_ value: Double?) -> String {
        guard let value else { return "-" }
        switch unitProfile.weight {
        case .kg:
            return "\(value.formatted(.number.precision(.fractionLength(1)))) kg"
        case .lb:
            let lb = value * 2.20462
            return "\(lb.formatted(.number.precision(.fractionLength(1)))) lb"
        }
    }

    private func formatLength(_ value: Double?) -> String {
        guard let value else { return "-" }
        switch unitProfile.length {
        case .cm:
            return "\(value.formatted(.number.precision(.fractionLength(1)))) cm"
        case .inch:
            let inch = value / 2.54
            return "\(inch.formatted(.number.precision(.fractionLength(1)))) in"
        }
    }

    @ViewBuilder
    private func trendChart(records: [GrowthRecord]) -> some View {
        let points = records.sorted(by: { $0.date < $1.date }).suffix(8)
        let dataPoints = chartDataPoints(from: points)
        let referencePoints = referenceDataPoints(from: points)
        if points.count >= 2, !dataPoints.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.tr("health_trend_chart_title"))
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text(selectedMetric.title + " • " + selectedMetric.unitLabel(unitProfile: unitProfile))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(L10n.tr("growth_percentile_reference_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Chart {
                    ForEach(Array(referencePoints.enumerated()), id: \.offset) { _, item in
                        LineMark(
                            x: .value(L10n.tr("chart_axis_date"), item.date),
                            y: .value(L10n.tr("chart_axis_reference_low"), item.lower)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.35))

                        LineMark(
                            x: .value(L10n.tr("chart_axis_date"), item.date),
                            y: .value(L10n.tr("chart_axis_reference_high"), item.upper)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                    }

                    ForEach(Array(dataPoints.enumerated()), id: \.offset) { _, item in
                        LineMark(
                            x: .value(L10n.tr("chart_axis_date"), item.date),
                            y: .value(selectedMetric.title, item.value)
                        )
                        .foregroundStyle(selectedMetric.color)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value(L10n.tr("chart_axis_date"), item.date),
                            y: .value(selectedMetric.title, item.value)
                        )
                        .foregroundStyle(selectedMetric.color)
                    }
                }
                .chartXAxis(.automatic)
                .frame(height: 190)
            }
            .healthCardStyle()
        }
    }

    private func chartDataPoints(from records: ArraySlice<GrowthRecord>) -> [GrowthDataPoint] {
        records.compactMap { record in
            guard let value = metricValue(for: record, metric: selectedMetric) else { return nil }
            return GrowthDataPoint(date: record.date, value: value)
        }
    }

    private func referenceDataPoints(from records: ArraySlice<GrowthRecord>) -> [GrowthReferencePoint] {
        guard let birthDate else { return [] }
        return records.compactMap { record in
            let month = max(Calendar.current.dateComponents([.month], from: birthDate, to: record.date).month ?? 0, 0)
            guard let range = referenceRange(metric: selectedMetric, ageMonth: month) else { return nil }
            return GrowthReferencePoint(date: record.date, lower: range.lowerBound, upper: range.upperBound)
        }
    }

    private func metricValue(for record: GrowthRecord, metric: GrowthMetric) -> Double? {
        switch metric {
        case .weight:
            guard let value = record.weightKg else { return nil }
            return convertWeight(value)
        case .length:
            guard let value = record.lengthCm else { return nil }
            return convertLength(value)
        case .head:
            guard let value = record.headCircumferenceCm else { return nil }
            return convertLength(value)
        }
    }

    private func referenceRange(metric: GrowthMetric, ageMonth: Int) -> ClosedRange<Double>? {
        HealthGrowthLogic.referenceRange(metric: metric, ageMonth: ageMonth, unitProfile: unitProfile)
    }

    private func growthWarningText(records: [GrowthRecord]) -> String? {
        guard let birthDate,
              let latest = records.sorted(by: { $0.date > $1.date }).first,
              let value = metricValue(for: latest, metric: selectedMetric) else {
            return nil
        }
        let month = max(Calendar.current.dateComponents([.month], from: birthDate, to: latest.date).month ?? 0, 0)
        guard let range = referenceRange(metric: selectedMetric, ageMonth: month) else { return nil }
        guard HealthGrowthLogic.isOutsideReference(metric: selectedMetric, value: value, ageMonth: month, unitProfile: unitProfile),
              !range.contains(value) else { return nil }
        return L10n.tr("growth_percentile_warning")
    }

    private func convertWeight(_ kg: Double) -> Double {
        switch unitProfile.weight {
        case .kg: return kg
        case .lb: return kg * 2.20462
        }
    }

    private func convertLength(_ cm: Double) -> Double {
        switch unitProfile.length {
        case .cm: return cm
        case .inch: return cm / 2.54
        }
    }
}

private struct GrowthDataPoint {
    let date: Date
    let value: Double
}

private struct GrowthReferencePoint {
    let date: Date
    let lower: Double
    let upper: Double
}

private struct LabRecordsView: View {
    let childId: String

    @StateObject private var store: LabRecordStore
    @State private var addSheetPresented = false
    @State private var editing: LabRecord?

    init(childId: String) {
        self.childId = childId
        _store = StateObject(wrappedValue: LabRecordStore(childId: childId))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                sectionHeader(title: L10n.tr("health_labs_records_title")) {
                    addSheetPresented = true
                }

                if store.records.isEmpty {
                    Text(L10n.tr("health_empty_records"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.records) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.testName)
                                        .font(.headline.weight(.bold))
                                    Spacer()
                                    Menu {
                                        Button(L10n.tr("common_edit"), systemImage: "pencil") {
                                            editing = item
                                        }
                                        Button(L10n.tr("common_delete"), systemImage: "trash", role: .destructive) {
                                            store.delete(id: item.id)
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("\(item.value) \(item.unit)")
                                    .font(.title3.weight(.heavy))

                                if !item.referenceRange.isEmpty {
                                    Text("\(L10n.tr("health_field_reference")): \(item.referenceRange)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if !item.note.isEmpty {
                                    Text(item.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .healthCardStyle()
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(L10n.tr("health_item_labs"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $addSheetPresented) {
            LabEditorSheet { newRecord in
                store.upsert(newRecord)
            }
        }
        .sheet(item: $editing) { record in
            LabEditorSheet(existing: record) { updated in
                store.upsert(updated)
            }
        }
    }
}

private struct AITriageAssistantView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var eventStore: EventStore
    @EnvironmentObject private var storeKit: StoreKitManager

    let childId: String

    @State private var question = ""
    @State private var answer = ""
    @State private var askedCount = 0
    @State private var isAsking = false

    private let freeDailyLimit = 1

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("health_ai_prompt_title"))
                        .font(.headline.weight(.bold))
                    TextEditor(text: $question)
                        .frame(minHeight: 110)
                        .padding(8)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                        )

                    HStack {
                        if !storeKit.hasActiveSubscription {
                            Text(String(format: L10n.tr("health_ai_free_remaining_format"), max(0, freeDailyLimit - askedCount)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(L10n.tr("family_subscription_active_desc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button(L10n.tr("health_ai_ask")) {
                            Task { await submitQuestion() }
                        }
                        .buttonStyle(PressableScaleButtonStyle())
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.accentColor, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                        .disabled(isAsking)
                    }
                }
                .healthCardStyle()

                if isAsking {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(L10n.tr("health_ai_generating"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }

                if !answer.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.tr("health_ai_answer_title"))
                            .font(.headline.weight(.bold))
                        Text(answer)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(L10n.tr("health_ai_disclaimer"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .healthCardStyle()
                }
            }
            .padding(20)
        }
        .navigationTitle(L10n.tr("health_item_triage"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            askedCount = askedTodayCount()
        }
    }

    private func submitQuestion() async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            answer = L10n.tr("health_ai_question_empty")
            return
        }

        if !storeKit.hasActiveSubscription && askedCount >= freeDailyLimit {
            answer = L10n.tr("health_ai_limit_reached")
            appState.showPaywall = true
            return
        }

        isAsking = true
        defer { isAsking = false }

        answer = await fetchAssistantAnswer(for: trimmed)
        question = ""

        if !storeKit.hasActiveSubscription {
            incrementAskedToday()
            askedCount = askedTodayCount()
        }
    }

    private func fetchAssistantAnswer(for question: String) async -> String {
        let prompt = buildGeminiPrompt(for: question)
        if let remote = try? await BackendClient.shared.askGemini(prompt: prompt, temperature: 0.35, maxTokens: 650),
           !remote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return remote
        }
        return buildFallbackAnswer(for: question)
    }

    private func buildFallbackAnswer(for question: String) -> String {
        let recent = eventStore.recent(limit: 400, childId: childId)
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: Date())
        let today = recent.filter { $0.timestamp >= dayStart }
        let feeds = today.filter { $0.type.isFeedingRelated }.count
        let sleeps = today.filter { $0.type == .sleep }.count
        let diapers = today.filter { $0.type.isDiaperRelated }.count
        let fever = today.filter { $0.type == .fever }.count
        let meds = today.filter { $0.type == .medication }.count

        var lines: [String] = []
        lines.append(
            String(
                format: L10n.tr("health_ai_fallback_summary_format"),
                today.count,
                feeds,
                sleeps,
                diapers,
                meds,
                fever
            )
        )

        if fever > 0 {
            lines.append(L10n.tr("health_ai_fallback_fever"))
        } else if feeds == 0 && diapers == 0 {
            lines.append(L10n.tr("health_ai_fallback_no_basic"))
        } else {
            lines.append(L10n.tr("health_ai_fallback_stable"))
        }

        if let latest = recent.first {
            lines.append(
                String(
                    format: L10n.tr("health_ai_fallback_latest_format"),
                    latest.type.title,
                    latest.timestamp.formatted(date: .omitted, time: .shortened)
                )
            )
        }

        lines.append(String(format: L10n.tr("health_ai_fallback_question_format"), question))
        lines.append(L10n.tr("health_ai_fallback_disclaimer"))
        return lines.joined(separator: "\n")
    }

    private func buildGeminiPrompt(for question: String) -> String {
        let recent = eventStore.recent(limit: 120, childId: childId)
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: Date())
        let today = recent.filter { $0.timestamp >= dayStart }

        let feeds = today.filter { $0.type.isFeedingRelated }.count
        let sleeps = today.filter { $0.type == .sleep }.count
        let diapers = today.filter { $0.type.isDiaperRelated }.count
        let fever = today.filter { $0.type == .fever }.count
        let meds = today.filter { $0.type == .medication }.count
        let symptoms = today.filter { $0.type == .symptom }.count

        let lastEvents = recent.prefix(6).map {
            "- \($0.type.rawValue) @ \($0.timestamp.ISO8601Format()) note=\($0.note)"
        }.joined(separator: "\n")
        let lines: [String] = [
            L10n.tr("health_ai_prompt_intro"),
            String(format: L10n.tr("health_ai_prompt_language_format"), L10n.selectedLanguageCode()),
            L10n.tr("health_ai_prompt_concise"),
            L10n.tr("health_ai_prompt_safety"),
            "",
            L10n.tr("health_ai_prompt_context_title"),
            String(format: L10n.tr("health_ai_prompt_child_id_format"), childId),
            String(format: L10n.tr("health_ai_prompt_today_total_format"), today.count),
            String(format: L10n.tr("health_ai_prompt_today_feed_format"), feeds),
            String(format: L10n.tr("health_ai_prompt_today_sleep_format"), sleeps),
            String(format: L10n.tr("health_ai_prompt_today_diaper_format"), diapers),
            String(format: L10n.tr("health_ai_prompt_today_fever_format"), fever),
            String(format: L10n.tr("health_ai_prompt_today_medication_format"), meds),
            String(format: L10n.tr("health_ai_prompt_today_symptom_format"), symptoms),
            L10n.tr("health_ai_prompt_latest_events_title"),
            lastEvents.isEmpty ? L10n.tr("health_ai_prompt_none") : lastEvents,
            "",
            L10n.tr("health_ai_prompt_user_question_title"),
            question,
            "",
            L10n.tr("health_ai_prompt_output_title"),
            L10n.tr("health_ai_prompt_output_1"),
            L10n.tr("health_ai_prompt_output_2"),
            L10n.tr("health_ai_prompt_output_3"),
            L10n.tr("health_ai_prompt_output_4")
        ]
        return lines.joined(separator: "\n")
    }

    private var aiUsageKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "ai.triage.free.questions.\(formatter.string(from: Date()))"
    }

    private func askedTodayCount() -> Int {
        UserDefaults.standard.integer(forKey: aiUsageKey)
    }

    private func incrementAskedToday() {
        let next = askedTodayCount() + 1
        UserDefaults.standard.set(next, forKey: aiUsageKey)
    }
}

private struct MedicationPlansView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var eventStore: EventStore

    let childId: String

    @StateObject private var planStore: MedicationPlanStore
    @State private var addSheetPresented = false
    @State private var editingPlan: MedicationPlan?
    @State private var pendingDeletePlan: MedicationPlan?
    @State private var historyMode: HealthHistoryMode = .recent
    @State private var historyDate = Date()
    @State private var historyBabyMonth = 0

    init(childId: String) {
        self.childId = childId
        _planStore = StateObject(wrappedValue: MedicationPlanStore(childId: childId))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("medication_plan_title"))
                        .font(.headline.weight(.bold))
                    Text(L10n.tr("medication_plan_subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .healthCardStyle()

                sectionHeader(title: L10n.tr("medication_plan_active")) {
                    addSheetPresented = true
                }

                if planStore.activePlans.isEmpty {
                    Text(L10n.tr("medication_plan_empty"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                } else {
                    VStack(spacing: 10) {
                        ForEach(planStore.activePlans) { plan in
                            planRow(plan, archived: false)
                        }
                    }
                }

                if !planStore.archivedPlans.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.tr("medication_plan_archived"))
                            .font(.headline.weight(.bold))
                        ForEach(planStore.archivedPlans) { plan in
                            planRow(plan, archived: true)
                        }
                    }
                    .healthCardStyle()
                }

                medicationHistorySection
            }
            .padding(20)
        }
        .navigationTitle(L10n.tr("health_item_chronic"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $addSheetPresented) {
            MedicationPlanEditorSheet(childId: childId) { plan in
                planStore.upsert(plan)
            }
        }
        .sheet(item: $editingPlan) { plan in
            MedicationPlanEditorSheet(existing: plan, childId: childId) { updated in
                planStore.upsert(updated)
            }
        }
        .alert(L10n.tr("medication_plan_delete_confirm"), isPresented: Binding(
            get: { pendingDeletePlan != nil },
            set: { if !$0 { pendingDeletePlan = nil } }
        )) {
            Button(L10n.tr("common_cancel"), role: .cancel) {}
            Button(L10n.tr("common_delete"), role: .destructive) {
                if let pendingDeletePlan {
                    planStore.delete(pendingDeletePlan.id)
                }
                pendingDeletePlan = nil
            }
        } message: {
            Text(L10n.tr("common_irreversible_action"))
        }
    }

    private func planRow(_ plan: MedicationPlan, archived: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: archived ? "archivebox.fill" : "pills.fill")
                .foregroundStyle(archived ? .secondary : Color.accentColor)
                .frame(width: 28, height: 28)
                .background(
                    (archived ? Color.secondary.opacity(0.15) : Color.accentColor.opacity(0.16)),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.name)
                    .font(.subheadline.weight(.semibold))
                if !plan.dosage.isEmpty {
                    Text(plan.dosage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(reminderText(for: plan))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                if archived {
                    Button(L10n.tr("medication_plan_restore"), systemImage: "arrow.uturn.backward.circle") {
                        planStore.setActive(plan.id, isActive: true)
                    }
                } else {
                    Button(L10n.tr("common_edit"), systemImage: "pencil") {
                        editingPlan = plan
                    }
                    Button(L10n.tr("medication_plan_archive"), systemImage: "archivebox") {
                        planStore.setActive(plan.id, isActive: false)
                    }
                }
                Button(L10n.tr("common_delete"), systemImage: "trash", role: .destructive) {
                    pendingDeletePlan = plan
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var medicationHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.tr("medication_history_title"))
                    .font(.headline.weight(.bold))
                Spacer()
                Button {
                    appState.selectedTab = .quickAdd
                } label: {
                    Label(L10n.tr("medication_history_add_log"), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }

            Picker("", selection: $historyMode) {
                ForEach(HealthHistoryMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if historyMode == .date {
                DatePicker(
                    L10n.tr("timeline_history_date"),
                    selection: $historyDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            } else if historyMode == .babyMonth {
                HStack {
                    Text(L10n.tr("timeline_history_baby_month"))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Stepper(
                        "\(historyBabyMonth). \(L10n.tr("timeline_history_month_suffix"))",
                        value: $historyBabyMonth,
                        in: 0...max(availableMonthCount, 0)
                    )
                    .labelsHidden()
                }
            }

            if historyEvents.isEmpty {
                healthEmptyState(
                    icon: "pills.circle",
                    title: L10n.tr("health_detail_no_logs")
                )
            } else {
                ForEach(historyEvents) { event in
                    HStack(spacing: 10) {
                        Image(systemName: "pills.fill")
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 28, height: 28)
                            .background(Color.accentColor.opacity(0.16), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.payload["medication_plan_name"] ?? L10n.tr("quick_action_medication"))
                                .font(.subheadline.weight(.semibold))
                            Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !event.note.isEmpty {
                                Text(event.note)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .healthCardStyle()
    }

    private var historyEvents: [AppEvent] {
        let scoped = eventStore.recent(limit: 2_000, childId: childId).filter { $0.type == .medication }
        HealthHistoryLogic.filterEvents(
            from: scoped,
            mode: historyMode,
            historyDate: historyDate,
            historyBabyMonth: historyBabyMonth,
            birthDate: selectedProfile?.birthDate
        )
    }

    private var selectedProfile: BabyProfile? {
        appState.babyProfiles.first(where: { $0.id == appState.selectedBabyId })
    }

    private var availableMonthCount: Int {
        HealthHistoryLogic.availableMonthCount(birthDate: selectedProfile?.birthDate)
    }

    private func reminderText(for plan: MedicationPlan) -> String {
        var components = DateComponents()
        components.hour = plan.reminderHour
        components.minute = plan.reminderMinute
        let date = Calendar.current.date(from: components) ?? Date()
        return String(
            format: L10n.tr("quick_add_medication_reminder_time_format"),
            date.formatted(date: .omitted, time: .shortened)
        )
    }
}

private struct MedicationPlanEditorSheet: View {
    var existing: MedicationPlan?
    let childId: String
    let onSave: (MedicationPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var dosage = ""
    @State private var note = ""
    @State private var reminderTime = Date()
    @State private var isActive = true

    init(existing: MedicationPlan? = nil, childId: String, onSave: @escaping (MedicationPlan) -> Void) {
        self.existing = existing
        self.childId = childId
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _dosage = State(initialValue: existing?.dosage ?? "")
        _note = State(initialValue: existing?.note ?? "")
        _isActive = State(initialValue: existing?.isActive ?? true)

        var components = DateComponents()
        components.hour = existing?.reminderHour ?? 9
        components.minute = existing?.reminderMinute ?? 0
        _reminderTime = State(initialValue: Calendar.current.date(from: components) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(L10n.tr("medication_plan_name"), text: $name)
                TextField(L10n.tr("medication_plan_dose"), text: $dosage)
                DatePicker(L10n.tr("medication_plan_time"), selection: $reminderTime, displayedComponents: .hourAndMinute)
                Toggle(L10n.tr("medication_plan_active_toggle"), isOn: $isActive)
                TextField(L10n.tr("health_field_note"), text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
            .navigationTitle(L10n.tr(existing == nil ? "medication_plan_add" : "medication_plan_edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("common_save")) {
                        let dateParts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                        let plan = MedicationPlan(
                            id: existing?.id ?? UUID(),
                            childId: childId,
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines),
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            reminderHour: dateParts.hour ?? 9,
                            reminderMinute: dateParts.minute ?? 0,
                            isActive: isActive,
                            createdAt: existing?.createdAt ?? Date(),
                            archivedAt: isActive ? nil : (existing?.archivedAt ?? Date())
                        )
                        onSave(plan)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private enum CheckupTemplate: String, CaseIterable, Identifiable {
    case month1
    case month2
    case month4
    case month6
    case month9
    case month12
    case custom

    var id: String { rawValue }

    var monthOffset: Int {
        switch self {
        case .month1: return 1
        case .month2: return 2
        case .month4: return 4
        case .month6: return 6
        case .month9: return 9
        case .month12: return 12
        case .custom: return 0
        }
    }

    var title: String {
        switch self {
        case .month1: return L10n.tr("checkup_template_1m")
        case .month2: return L10n.tr("checkup_template_2m")
        case .month4: return L10n.tr("checkup_template_4m")
        case .month6: return L10n.tr("checkup_template_6m")
        case .month9: return L10n.tr("checkup_template_9m")
        case .month12: return L10n.tr("checkup_template_12m")
        case .custom: return L10n.tr("checkup_template_custom")
        }
    }
}

private struct CheckupEditorSheet: View {
    var existing: CheckupRecord?
    let unitProfile: UnitProfile
    let birthDate: Date?
    let onSave: (CheckupRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var template: CheckupTemplate = .custom
    @State private var doctorName = ""
    @State private var clinicName = ""
    @State private var weightText = ""
    @State private var lengthText = ""
    @State private var headText = ""
    @State private var note = ""

    init(existing: CheckupRecord? = nil, unitProfile: UnitProfile, birthDate: Date?, onSave: @escaping (CheckupRecord) -> Void) {
        self.existing = existing
        self.unitProfile = unitProfile
        self.birthDate = birthDate
        self.onSave = onSave
        _date = State(initialValue: existing?.date ?? Date())
        _template = State(initialValue: .custom)
        _doctorName = State(initialValue: existing?.doctorName ?? "")
        _clinicName = State(initialValue: existing?.clinicName ?? "")
        _weightText = State(initialValue: existing?.weightKg?.formatted(.number.precision(.fractionLength(1))) ?? "")
        _lengthText = State(initialValue: existing?.lengthCm?.formatted(.number.precision(.fractionLength(1))) ?? "")
        _headText = State(initialValue: existing?.headCircumferenceCm?.formatted(.number.precision(.fractionLength(1))) ?? "")
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if existing == nil {
                    Section(L10n.tr("checkup_template_label")) {
                        Picker("", selection: $template) {
                            ForEach(CheckupTemplate.allCases) { template in
                                Text(template.title).tag(template)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                DatePicker(L10n.tr("health_field_date"), selection: $date, displayedComponents: .date)
                TextField(L10n.tr("health_field_doctor"), text: $doctorName)
                TextField(L10n.tr("health_field_clinic"), text: $clinicName)
                TextField(L10n.tr("health_field_weight"), text: $weightText)
                    .keyboardType(.decimalPad)
                TextField(L10n.tr("health_field_length"), text: $lengthText)
                    .keyboardType(.decimalPad)
                TextField(L10n.tr("health_field_head"), text: $headText)
                    .keyboardType(.decimalPad)
                TextField(L10n.tr("health_field_note"), text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
            .onChange(of: template) { newValue in
                applyTemplate(newValue)
            }
            .navigationTitle(L10n.tr("health_item_checkup"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("common_save")) {
                        onSave(
                            CheckupRecord(
                                id: existing?.id ?? UUID(),
                                date: date,
                                doctorName: doctorName.trimmingCharacters(in: .whitespacesAndNewlines),
                                clinicName: clinicName.trimmingCharacters(in: .whitespacesAndNewlines),
                                weightKg: parseWeight(weightText),
                                lengthCm: parseLength(lengthText),
                                headCircumferenceCm: parseLength(headText),
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(!hasAnyInput)
                }
            }
        }
    }

    private var hasAnyInput: Bool {
        !doctorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !clinicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            parseWeight(weightText) != nil ||
            parseLength(lengthText) != nil ||
            parseLength(headText) != nil ||
            !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func parseWeight(_ text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")) else { return nil }
        switch unitProfile.weight {
        case .kg: return value
        case .lb: return value / 2.20462
        }
    }

    private func parseLength(_ text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")) else { return nil }
        switch unitProfile.length {
        case .cm: return value
        case .inch: return value * 2.54
        }
    }

    private func applyTemplate(_ template: CheckupTemplate) {
        guard existing == nil else { return }
        guard template != .custom else { return }
        if let birthDate,
           let target = Calendar.current.date(byAdding: .month, value: template.monthOffset, to: birthDate) {
            date = target
        }
        if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            note = template.title
        }
    }
}

private struct GrowthEditorSheet: View {
    var existing: GrowthRecord?
    let unitProfile: UnitProfile
    let onSave: (GrowthRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var weightText = ""
    @State private var lengthText = ""
    @State private var headText = ""
    @State private var note = ""

    init(existing: GrowthRecord? = nil, unitProfile: UnitProfile, onSave: @escaping (GrowthRecord) -> Void) {
        self.existing = existing
        self.unitProfile = unitProfile
        self.onSave = onSave
        _date = State(initialValue: existing?.date ?? Date())
        _weightText = State(initialValue: existing?.weightKg?.formatted(.number.precision(.fractionLength(1))) ?? "")
        _lengthText = State(initialValue: existing?.lengthCm?.formatted(.number.precision(.fractionLength(1))) ?? "")
        _headText = State(initialValue: existing?.headCircumferenceCm?.formatted(.number.precision(.fractionLength(1))) ?? "")
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(L10n.tr("health_field_date"), selection: $date, displayedComponents: .date)
                TextField(L10n.tr("health_field_weight"), text: $weightText)
                    .keyboardType(.decimalPad)
                TextField(L10n.tr("health_field_length"), text: $lengthText)
                    .keyboardType(.decimalPad)
                TextField(L10n.tr("health_field_head"), text: $headText)
                    .keyboardType(.decimalPad)
                TextField(L10n.tr("health_field_note"), text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
            .navigationTitle(L10n.tr("health_item_growth"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("common_save")) {
                        onSave(
                            GrowthRecord(
                                id: existing?.id ?? UUID(),
                                date: date,
                                weightKg: parseWeight(weightText),
                                lengthCm: parseLength(lengthText),
                                headCircumferenceCm: parseLength(headText),
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(parseWeight(weightText) == nil && parseLength(lengthText) == nil && parseLength(headText) == nil)
                }
            }
        }
    }

    private func parseWeight(_ text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")) else { return nil }
        switch unitProfile.weight {
        case .kg: return value
        case .lb: return value / 2.20462
        }
    }

    private func parseLength(_ text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")) else { return nil }
        switch unitProfile.length {
        case .cm: return value
        case .inch: return value * 2.54
        }
    }
}

private struct LabEditorSheet: View {
    var existing: LabRecord?
    let onSave: (LabRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var testName = ""
    @State private var value = ""
    @State private var unit = ""
    @State private var referenceRange = ""
    @State private var note = ""

    init(existing: LabRecord? = nil, onSave: @escaping (LabRecord) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _date = State(initialValue: existing?.date ?? Date())
        _testName = State(initialValue: existing?.testName ?? "")
        _value = State(initialValue: existing?.value ?? "")
        _unit = State(initialValue: existing?.unit ?? "")
        _referenceRange = State(initialValue: existing?.referenceRange ?? "")
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(L10n.tr("health_field_date"), selection: $date, displayedComponents: .date)
                TextField(L10n.tr("health_field_test_name"), text: $testName)
                TextField(L10n.tr("health_field_value"), text: $value)
                TextField(L10n.tr("health_field_unit"), text: $unit)
                TextField(L10n.tr("health_field_reference"), text: $referenceRange)
                TextField(L10n.tr("health_field_note"), text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
            .navigationTitle(L10n.tr("health_item_labs"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("common_save")) {
                        onSave(
                            LabRecord(
                                id: existing?.id ?? UUID(),
                                date: date,
                                testName: testName.trimmingCharacters(in: .whitespacesAndNewlines),
                                value: value.trimmingCharacters(in: .whitespacesAndNewlines),
                                unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
                                referenceRange: referenceRange.trimmingCharacters(in: .whitespacesAndNewlines),
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(testName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct CheckupRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let doctorName: String
    let clinicName: String
    let weightKg: Double?
    let lengthCm: Double?
    let headCircumferenceCm: Double?
    let note: String
}

private struct GrowthRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let weightKg: Double?
    let lengthCm: Double?
    let headCircumferenceCm: Double?
    let note: String
}

private struct LabRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let testName: String
    let value: String
    let unit: String
    let referenceRange: String
    let note: String
}

@MainActor
private final class CheckupRecordStore: ObservableObject {
    @Published private(set) var records: [CheckupRecord] = []
    private let key: String

    init(childId: String) {
        key = "health.checkup.records.\(childId)"
        load()
    }

    func upsert(_ record: CheckupRecord) {
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            records[idx] = record
        } else {
            records.append(record)
        }
        records.sort(by: { $0.date > $1.date })
        save()
    }

    func delete(id: UUID) {
        records.removeAll(where: { $0.id == id })
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CheckupRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded.sorted(by: { $0.date > $1.date })
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

@MainActor
private final class GrowthRecordStore: ObservableObject {
    @Published private(set) var records: [GrowthRecord] = []
    private let key: String

    init(childId: String) {
        key = "health.growth.records.\(childId)"
        load()
    }

    func upsert(_ record: GrowthRecord) {
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            records[idx] = record
        } else {
            records.append(record)
        }
        records.sort(by: { $0.date > $1.date })
        save()
    }

    func delete(id: UUID) {
        records.removeAll(where: { $0.id == id })
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([GrowthRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded.sorted(by: { $0.date > $1.date })
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

@MainActor
private final class LabRecordStore: ObservableObject {
    @Published private(set) var records: [LabRecord] = []
    private let key: String

    init(childId: String) {
        key = "health.labs.records.\(childId)"
        load()
    }

    func upsert(_ record: LabRecord) {
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            records[idx] = record
        } else {
            records.append(record)
        }
        records.sort(by: { $0.date > $1.date })
        save()
    }

    func delete(id: UUID) {
        records.removeAll(where: { $0.id == id })
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([LabRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded.sorted(by: { $0.date > $1.date })
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private func sectionHeader(title: String, addAction: @escaping () -> Void) -> some View {
    HStack {
        Text(title)
            .font(.headline.weight(.bold))
        Spacer()
        Button {
            addAction()
        } label: {
            Label(L10n.tr("health_add_record"), systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
        }
    }
}

private func metricChip(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        Text(value)
            .font(.caption.weight(.bold))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 8)
    .padding(.horizontal, 10)
    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
}

@ViewBuilder
private func healthEmptyState(icon: String, title: String, subtitle: String = L10n.tr("health_empty_history_hint")) -> some View {
    VStack(spacing: 8) {
        Image(systemName: icon)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.accentColor)
        Text(title)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
        Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 14)
    .padding(.horizontal, 12)
    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
}

private extension View {
    func healthCardStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.28), lineWidth: 1)
            )
    }
}

private struct HealthModule: Identifiable {
    let id = UUID()
    let kind: HealthModuleKind
    let title: String
    let icon: String
    let imagePath: String
    let tint: Color
}

private enum HealthModuleKind: String, Hashable {
    case vaccine
    case checkup
    case growth
    case labs
    case chronic
    case triage
    case doctorShare
    case schoolTravel
}

private enum HealthModuleWorkspacePreset: String {
    case checkup
    case growth
    case labs
    case chronic
    case triage
    case doctorShare
    case schoolTravel

    var subtitleKey: String {
        switch self {
        case .checkup: return "health_detail_checkup_subtitle"
        case .growth: return "health_detail_growth_subtitle"
        case .labs: return "health_detail_labs_subtitle"
        case .chronic: return "health_detail_chronic_subtitle"
        case .triage: return "health_detail_triage_subtitle"
        case .doctorShare: return "health_detail_doctor_share_subtitle"
        case .schoolTravel: return "health_detail_school_travel_subtitle"
        }
    }

    var relatedTypes: [EventType] {
        switch self {
        case .checkup:
            return [.fever, .symptom, .medication]
        case .growth:
            return [.bottle, .breastfeeding, .breastfeedingLeft, .breastfeedingRight, .pumping, .sleep]
        case .labs:
            return [.medication, .symptom, .fever]
        case .chronic:
            return [.symptom, .medication, .fever]
        case .triage:
            return [.fever, .symptom]
        case .doctorShare:
            return [.fever, .symptom, .medication, .sleep, .bottle, .breastfeeding, .diaperChange]
        case .schoolTravel:
            return [.medication, .symptom, .fever]
        }
    }

    var quickLogTypes: [EventType] {
        switch self {
        case .checkup:
            return [.symptom, .fever, .medication]
        case .growth:
            return [.bottle, .sleep, .pumping, .breastfeeding]
        case .labs:
            return [.medication, .fever]
        case .chronic:
            return [.symptom, .medication]
        case .triage:
            return [.fever, .symptom]
        case .doctorShare:
            return [.medication, .symptom]
        case .schoolTravel:
            return [.medication, .symptom, .fever]
        }
    }

    var playbookItemKeys: [String] {
        switch self {
        case .checkup:
            return ["health_playbook_checkup_1", "health_playbook_checkup_2"]
        case .growth:
            return ["health_playbook_growth_1", "health_playbook_growth_2"]
        case .labs:
            return ["health_playbook_labs_1", "health_playbook_labs_2"]
        case .chronic:
            return ["health_playbook_chronic_1", "health_playbook_chronic_2"]
        case .triage:
            return ["health_playbook_triage_1", "health_playbook_triage_2"]
        case .doctorShare:
            return ["health_playbook_doctor_share_1", "health_playbook_doctor_share_2"]
        case .schoolTravel:
            return ["health_playbook_school_travel_1", "health_playbook_school_travel_2"]
        }
    }

    var checklistItemKeys: [String] {
        switch self {
        case .schoolTravel:
            return [
                "health_checklist_school_1",
                "health_checklist_school_2",
                "health_checklist_school_3",
                "health_checklist_school_4"
            ]
        default:
            return []
        }
    }

    var showsTriage: Bool {
        self == .triage
    }

    var supportsShare: Bool {
        self == .doctorShare
    }
}

private enum VaccineStatus {
    case done
    case due
    case overdue
    case upcoming

    var title: String {
        switch self {
        case .done:
            return L10n.tr("vaccine_status_done")
        case .due:
            return L10n.tr("vaccine_status_due")
        case .overdue:
            return L10n.tr("vaccine_status_overdue")
        case .upcoming:
            return L10n.tr("vaccine_status_upcoming")
        }
    }

    var tint: Color {
        switch self {
        case .done:
            return .green
        case .due:
            return .orange
        case .overdue:
            return .red
        case .upcoming:
            return .blue
        }
    }
}

private struct ManualVaccineEntry: Identifiable, Codable {
    let id: UUID
    let name: String
    let date: Date
    let note: String

    init(id: UUID = UUID(), name: String, date: Date, note: String) {
        self.id = id
        self.name = name
        self.date = date
        self.note = note
    }
}

@MainActor
private final class VaccineManualStore: ObservableObject {
    @Published private(set) var entries: [ManualVaccineEntry] = []
    private let key: String

    init(storageKey: String) {
        self.key = "vaccine_manual_entries_\(storageKey)"
        load()
    }

    func add(_ entry: ManualVaccineEntry) {
        entries.append(entry)
        entries.sort(by: { $0.date < $1.date })
        save()
    }

    func delete(_ id: UUID) {
        entries.removeAll(where: { $0.id == id })
        save()
    }

    func update(_ entry: ManualVaccineEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
        entries.sort(by: { $0.date < $1.date })
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ManualVaccineEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded.sorted(by: { $0.date < $1.date })
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

@MainActor
private final class VaccineCompletionStore: ObservableObject {
    @Published private(set) var completedIds: Set<String> = []
    private let key: String

    init(storageKey: String) {
        self.key = "vaccine_completed_ids_\(storageKey)"
        load()
    }

    func toggle(_ id: String) {
        if completedIds.contains(id) {
            completedIds.remove(id)
        } else {
            completedIds.insert(id)
        }
        save()
    }

    func isCompleted(_ id: String) -> Bool {
        completedIds.contains(id)
    }

    private func load() {
        let saved = UserDefaults.standard.stringArray(forKey: key) ?? []
        completedIds = Set(saved)
    }

    private func save() {
        UserDefaults.standard.set(Array(completedIds), forKey: key)
    }
}

private enum VaccineSourceStatus {
    case live
    case cached
    case review
    case offline

    var badgeKey: String {
        switch self {
        case .live:
            return "vaccine_data_source_badge_live"
        case .cached:
            return "vaccine_data_source_badge_cached"
        case .review:
            return "vaccine_data_source_badge_review"
        case .offline:
            return "vaccine_data_source_badge_offline"
        }
    }

    var description: String {
        switch self {
        case .live:
            return L10n.tr("vaccine_data_source_status_live")
        case .cached:
            return L10n.tr("vaccine_data_source_status_cached")
        case .review:
            return L10n.tr("vaccine_data_source_status_review")
        case .offline:
            return L10n.tr("vaccine_data_source_status_offline")
        }
    }

    var systemImage: String {
        switch self {
        case .live:
            return "waveform.path.ecg"
        case .cached:
            return "clock.badge.checkmark"
        case .review:
            return "exclamationmark.triangle"
        case .offline:
            return "wifi.slash"
        }
    }

    var tint: Color {
        switch self {
        case .live:
            return .green
        case .cached:
            return .blue
        case .review:
            return .orange
        case .offline:
            return .secondary
        }
    }
}
