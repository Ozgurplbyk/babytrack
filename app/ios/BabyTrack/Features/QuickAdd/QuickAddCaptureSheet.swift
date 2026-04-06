import SwiftUI
import PhotosUI
import UIKit

struct QuickAddCaptureSheet: View {
    let type: EventType
    let childId: String
    var onSave: (AppEvent) -> Void

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var sessionManager: CareSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var timestamp = Date()
    @State private var note = ""
    @State private var visibility: AppEvent.Visibility = .family
    @State private var durationMinutes = 10
    @State private var durationMode: DurationMode = .manual
    @State private var bottleAmount = ""
    @State private var bottleSource: BottleSource = .formula
    @State private var breastfeedingSide: BreastfeedingSide = .left
    @State private var diaperContent: DiaperContent = .pee
    @State private var temperature = ""
    @State private var selectedMedicationPlanIdRaw = MedicationPlanSelection.manualTag
    @State private var showTimerConflictAlert = false
    @State private var timerConflictMessage = ""
    @State private var memoryPhotoItem: PhotosPickerItem?
    @State private var memoryPhotoData: Data?
    @State private var memoryPhotoLoadError = false
    @State private var showMemoryCamera = false
    @State private var memoryCameraUnavailable = false

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                detailSection
                breastSideSection
                diaperContentSection
                durationSection
                bottleSection
                medicationSection
                memoryPhotoSection
                feverSection
            }
            .onAppear {
                configureDefaults()
            }
            .onChange(of: durationMode) { newValue in
                guard newValue == .manual, let matchingSession else { return }
                durationMinutes = sessionManager.elapsedMinutes(for: matchingSession)
                _ = sessionManager.stopSession()
            }
            .onChange(of: memoryPhotoItem) { _ in
                Task {
                    await loadMemoryPhotoData()
                }
            }
            .navigationTitle(String(format: L10n.tr("quick_add_detail_title_format"), type.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common_cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("quick_add_save_action")) {
                        save()
                    }
                }
            }
            .alert(L10n.tr("quick_add_timer_conflict_title"), isPresented: $showTimerConflictAlert) {
                Button(L10n.tr("common_ok"), role: .cancel) {}
            } message: {
                Text(timerConflictMessage)
            }
            .alert(L10n.tr("quick_add_memory_photo_error"), isPresented: $memoryPhotoLoadError) {
                Button(L10n.tr("common_ok"), role: .cancel) {}
            }
            .alert(L10n.tr("quick_add_memory_camera_unavailable"), isPresented: $memoryCameraUnavailable) {
                Button(L10n.tr("common_ok"), role: .cancel) {}
            }
            .sheet(isPresented: $showMemoryCamera) {
                CameraCapturePicker { data in
                    if let data {
                        memoryPhotoData = data
                        memoryPhotoItem = nil
                    }
                    showMemoryCamera = false
                }
            }
        }
    }

    private var headerSection: some View {
        Section {
            Label(type.title, systemImage: type.icon)
                .font(.headline)
        }
    }

    private var detailSection: some View {
        Section(L10n.tr("event_editor_section_detail")) {
            DatePicker(L10n.tr("event_editor_date_time_label"), selection: $timestamp)
            TextField(L10n.tr("event_editor_note_label"), text: $note, axis: .vertical)
                .lineLimit(2...4)
            Picker(L10n.tr("event_editor_visibility_label"), selection: $visibility) {
                Text(L10n.tr("event_editor_visibility_family")).tag(AppEvent.Visibility.family)
                Text(L10n.tr("event_editor_visibility_parents_only")).tag(AppEvent.Visibility.parentsOnly)
                Text(L10n.tr("event_editor_visibility_private")).tag(AppEvent.Visibility.`private`)
            }
        }
    }

    @ViewBuilder
    private var breastSideSection: some View {
        if type == .breastfeeding {
            Section(L10n.tr("quick_add_breast_side_label")) {
                Picker("", selection: $breastfeedingSide) {
                    ForEach(BreastfeedingSide.allCases) { side in
                        Text(side.title).tag(side)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder
    private var diaperContentSection: some View {
        if type == .diaperChange {
            Section(L10n.tr("quick_add_diaper_content_label")) {
                Picker("", selection: $diaperContent) {
                    ForEach(DiaperContent.allCases) { content in
                        Text(content.title).tag(content)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder
    private var durationSection: some View {
        if typeSupportsDuration {
            Section(L10n.tr("quick_add_duration_label")) {
                Picker(L10n.tr("quick_add_duration_mode_label"), selection: $durationMode) {
                    Text(L10n.tr("quick_add_duration_mode_manual")).tag(DurationMode.manual)
                    Text(L10n.tr("quick_add_duration_mode_timer")).tag(DurationMode.timer)
                }
                .pickerStyle(.segmented)

                if durationMode == .manual {
                    Stepper(value: $durationMinutes, in: 1...300) {
                        Text(String(format: L10n.tr("quick_add_duration_value_format"), durationMinutes))
                    }
                } else {
                    timerModeView
                }
            }
        }
    }

    @ViewBuilder
    private var bottleSection: some View {
        if type == .bottle {
            Section(L10n.tr("quick_add_bottle_detail_title")) {
                Picker(L10n.tr("quick_add_bottle_source_label"), selection: $bottleSource) {
                    ForEach(BottleSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.segmented)

                TextField(volumePlaceholder, text: $bottleAmount)
                    .keyboardType(.decimalPad)

                Text(String(format: L10n.tr("quick_add_amount_unit_hint_format"), volumeUnitLabel))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var medicationSection: some View {
        if type == .medication {
            Section(L10n.tr("quick_add_medication_plan_label")) {
                Picker("", selection: $selectedMedicationPlanIdRaw) {
                    Text(L10n.tr("quick_add_medication_manual")).tag(MedicationPlanSelection.manualTag)
                    ForEach(activeMedicationPlans) { plan in
                        Text(plan.name).tag(plan.id.uuidString)
                    }
                }
                .pickerStyle(.menu)

                if let selectedMedicationPlan {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedMedicationPlan.dosage.isEmpty ? L10n.tr("medication_reminder_no_dose") : selectedMedicationPlan.dosage)
                            .font(.subheadline.weight(.semibold))
                        Text(reminderText(for: selectedMedicationPlan))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                } else {
                    Text(L10n.tr("quick_add_medication_manual_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var memoryPhotoSection: some View {
        if type == .memory {
            Section(L10n.tr("quick_add_memory_photo_label")) {
                HStack(spacing: 10) {
                    PhotosPicker(
                        selection: $memoryPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(L10n.tr("quick_add_memory_photo_pick"), systemImage: "photo.on.rectangle")
                            .font(.subheadline.weight(.semibold))
                    }

                    Button {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            showMemoryCamera = true
                        } else {
                            memoryCameraUnavailable = true
                        }
                    } label: {
                        Label(L10n.tr("quick_add_memory_photo_take"), systemImage: "camera.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }

                if let data = memoryPhotoData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        )

                    Button(role: .destructive) {
                        memoryPhotoItem = nil
                        memoryPhotoData = nil
                    } label: {
                        Label(L10n.tr("quick_add_memory_photo_remove"), systemImage: "trash")
                    }
                } else {
                    Text(L10n.tr("quick_add_memory_photo_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var feverSection: some View {
        if type == .fever {
            Section(L10n.tr("quick_add_temperature_label")) {
                TextField(L10n.tr("quick_add_temperature_placeholder"), text: $temperature)
                    .keyboardType(.decimalPad)
            }
        }
    }

    @ViewBuilder
    private var timerModeView: some View {
        if let matchingSession {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(format: L10n.tr("quick_add_timer_running_format"), sessionManager.elapsedMinutes(for: matchingSession)))
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .foregroundStyle(Color.accentColor)
                    Text(matchingSession.startedAt, style: .timer)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }

                timerActionButton(
                    title: L10n.tr("quick_add_timer_stop"),
                    icon: "stop.fill",
                    colors: [Color.red, Color.orange]
                ) {
                    durationMinutes = sessionManager.elapsedMinutes(for: matchingSession)
                    _ = sessionManager.stopSession()
                    Haptics.light()
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if let activeSession = sessionManager.activeSession {
                    Text(
                        String(
                            format: L10n.tr("quick_add_timer_conflict_running_format"),
                            activeSession.type.title
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text(L10n.tr("quick_add_timer_idle_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                timerActionButton(
                    title: L10n.tr("quick_add_timer_start"),
                    icon: "play.fill",
                    colors: [Color.accentColor, Color.blue]
                ) {
                    startTimer()
                }
            }
        }
    }

    private func timerActionButton(
        title: String,
        icon: String,
        colors: [Color],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(PressableScaleButtonStyle(scale: 0.985, opacity: 0.95))
    }

    private var volumeUnit: VolumeUnitPreference {
        appState.unitProfile.volume
    }

    private var volumeUnitLabel: String {
        switch volumeUnit {
        case .ml:
            return L10n.tr("settings_unit_ml")
        case .oz:
            return L10n.tr("settings_unit_oz")
        }
    }

    private var volumePlaceholder: String {
        switch volumeUnit {
        case .ml:
            return "90"
        case .oz:
            return "3.0"
        }
    }

    private var activeMedicationPlans: [MedicationPlan] {
        MedicationPlanStore.snapshot(childId: childId).filter(\.isActive)
    }

    private var selectedMedicationPlan: MedicationPlan? {
        guard selectedMedicationPlanIdRaw != MedicationPlanSelection.manualTag,
              let id = UUID(uuidString: selectedMedicationPlanIdRaw) else {
            return nil
        }
        return activeMedicationPlans.first(where: { $0.id == id })
    }

    private var typeSupportsDuration: Bool {
        switch type {
        case .breastfeeding, .breastfeedingLeft, .breastfeedingRight, .pumping, .sleep:
            return true
        default:
            return false
        }
    }

    private var matchingSession: ActiveCareSession? {
        guard let session = sessionManager.activeSession,
              session.childId == childId else {
            return nil
        }

        if type == .breastfeeding {
            let compatibleTypes: Set<EventType> = [.breastfeeding, .breastfeedingLeft, .breastfeedingRight]
            return compatibleTypes.contains(session.type) ? session : nil
        }

        return session.type == type ? session : nil
    }

    private var timerSessionType: EventType {
        type == .breastfeedingLeft || type == .breastfeedingRight ? .breastfeeding : type
    }

    private func configureDefaults() {
        guard type == .medication else { return }
        if let first = activeMedicationPlans.first {
            selectedMedicationPlanIdRaw = first.id.uuidString
        } else {
            selectedMedicationPlanIdRaw = MedicationPlanSelection.manualTag
        }
    }

    private func startTimer() {
        let result = sessionManager.startSession(
            type: timerSessionType,
            childId: childId,
            childName: appState.selectedBabyName()
        )
        switch result {
        case .started, .alreadyRunningSame:
            Haptics.medium()
        case .blockedByAnother:
            if let activeSession = sessionManager.activeSession {
                timerConflictMessage = String(
                    format: L10n.tr("quick_add_timer_conflict_running_format"),
                    activeSession.type.title
                )
            } else {
                timerConflictMessage = L10n.tr("quick_add_timer_conflict_generic")
            }
            showTimerConflictAlert = true
            Haptics.warning()
        }
    }

    private func save() {
        var payload: [String: String] = ["source": "quick_add"]
        var eventTimestamp = timestamp
        let eventType = normalizedEventType()
        let eventId = UUID()

        if typeSupportsDuration {
            if durationMode == .timer, let session = matchingSession {
                let endedAt = Date()
                payload["duration_min"] = "\(sessionManager.elapsedMinutes(for: session, now: endedAt))"
                payload["started_at"] = Self.iso8601.string(from: session.startedAt)
                payload["ended_at"] = Self.iso8601.string(from: endedAt)
                payload["duration_mode"] = "timer"
                eventTimestamp = endedAt
                _ = sessionManager.stopSession()
            } else {
                payload["duration_min"] = "\(durationMinutes)"
                payload["duration_mode"] = durationMode.rawValue
            }
        }

        if eventType == .breastfeeding {
            payload["breast_side"] = breastfeedingSide.rawValue
        }

        if eventType == .diaperChange {
            payload["diaper_content"] = diaperContent.rawValue
        }

        if eventType == .bottle {
            payload["bottle_source"] = bottleSource.rawValue
            let normalized = bottleAmount.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
            if let value = Double(normalized), value > 0 {
                let amountML = volumeUnit == .ml ? value : value * 29.5735
                payload["amount_ml"] = amountML.formatted(.number.precision(.fractionLength(1)))
                payload["amount_display"] = value.formatted(.number.precision(.fractionLength(1)))
                payload["amount_unit"] = volumeUnit.rawValue
            }
        }

        if eventType == .medication, let selectedMedicationPlan {
            payload["medication_plan_id"] = selectedMedicationPlan.id.uuidString
            payload["medication_plan_name"] = selectedMedicationPlan.name
            if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                note = selectedMedicationPlan.dosage
            }
        }

        if eventType == .memory,
           let memoryPhotoData,
           let fileName = EventAttachmentStorage.saveImageData(memoryPhotoData, eventId: eventId) {
            payload["photo_file"] = fileName
        }

        if eventType == .fever, !temperature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["temperature"] = temperature.trimmingCharacters(in: .whitespacesAndNewlines)
            payload["temperature_unit"] = appState.unitProfile.temperature.rawValue
        }

        let event = AppEvent(
            id: eventId,
            childId: childId,
            type: eventType,
            timestamp: eventTimestamp,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            payload: payload,
            visibility: visibility
        )
        onSave(event)
        dismiss()
    }

    private func normalizedEventType() -> EventType {
        switch type {
        case .breastfeedingLeft, .breastfeedingRight:
            return .breastfeeding
        case .diaperPee, .diaperPoop:
            return .diaperChange
        default:
            return type
        }
    }

    private func loadMemoryPhotoData() async {
        guard let memoryPhotoItem else {
            memoryPhotoData = nil
            return
        }
        memoryPhotoLoadError = false
        do {
            memoryPhotoData = try await memoryPhotoItem.loadTransferable(type: Data.self)
            if memoryPhotoData == nil {
                memoryPhotoLoadError = true
            }
        } catch {
            memoryPhotoLoadError = true
        }
    }

    private func reminderText(for plan: MedicationPlan) -> String {
        var components = DateComponents()
        components.hour = plan.reminderHour
        components.minute = plan.reminderMinute
        guard let date = Calendar.current.date(from: components) else {
            return L10n.tr("quick_add_medication_manual_hint")
        }
        return String(
            format: L10n.tr("quick_add_medication_reminder_time_format"),
            date.formatted(date: .omitted, time: .shortened)
        )
    }
}

private enum DurationMode: String, Identifiable {
    case manual
    case timer

    var id: String { rawValue }
}

private enum BreastfeedingSide: String, CaseIterable, Identifiable {
    case left
    case right
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: return L10n.tr("quick_add_breast_side_left")
        case .right: return L10n.tr("quick_add_breast_side_right")
        case .both: return L10n.tr("quick_add_breast_side_both")
        }
    }
}

private enum DiaperContent: String, CaseIterable, Identifiable {
    case pee
    case poop
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pee: return L10n.tr("quick_add_diaper_content_pee")
        case .poop: return L10n.tr("quick_add_diaper_content_poop")
        case .both: return L10n.tr("quick_add_diaper_content_both")
        }
    }
}

private enum BottleSource: String, CaseIterable, Identifiable {
    case formula
    case breastMilk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .formula: return L10n.tr("quick_add_bottle_source_formula")
        case .breastMilk: return L10n.tr("quick_add_bottle_source_breastmilk")
        }
    }
}

private enum MedicationPlanSelection {
    static let manualTag = "__manual__"
}
