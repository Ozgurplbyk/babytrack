import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: EventStore
    @State private var selectedType: EventType?
    @State private var historyMode: TimelineHistoryMode = .recent
    @State private var selectedDate = Date()
    @State private var selectedAgeMonth = 0
    @State private var editingEvent: AppEvent?
    @State private var pendingDeleteEvent: AppEvent?
    @State private var animateIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if appState.babyProfiles.count > 1 {
                            profileSwitcherSection
                                .staggerEntrance(show: animateIn, delay: 0.02)
                        }
                        chipsSection
                            .staggerEntrance(show: animateIn, delay: 0.08)

                        if filteredEvents.isEmpty {
                            emptyState
                                .staggerEntrance(show: animateIn, delay: 0.1)
                        } else {
                            eventsSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(L10n.tr("timeline_title"))
            .onAppear {
                if !animateIn { animateIn = true }
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
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.accentColor.opacity(0.055),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentColor.opacity(0.1))
                .frame(width: 220, height: 220)
                .blur(radius: 56)
                .offset(x: -130, y: -220)
        }
    }

    private var chipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.tr("today_quick_summary"))
                    .font(.headline.weight(.bold))
                Spacer()
                Text(String(format: L10n.tr("today_summary_format"), filteredEvents.count))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(title: L10n.tr("timeline_all"), type: nil)
                    ForEach(EventType.userFacingCases) { type in
                        chip(title: type.title, type: type)
                    }
                }
                .padding(.vertical, 4)
            }

            Picker("", selection: $historyMode) {
                ForEach(TimelineHistoryMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if historyMode == .date {
                DatePicker(
                    L10n.tr("timeline_history_date"),
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            } else if historyMode == .babyMonth {
                HStack {
                    Text(L10n.tr("timeline_history_baby_month"))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Stepper(
                        "\(selectedAgeMonth). \(L10n.tr("timeline_history_month_suffix"))",
                        value: $selectedAgeMonth,
                        in: 0...max(availableMonthCount, 0)
                    )
                    .labelsHidden()
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var profileSwitcherSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.tr("family_profiles_section_title"))
                    .font(.headline.weight(.bold))
                Spacer()
                Text(appState.selectedBabyName())
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
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func chip(title: String, type: EventType?) -> some View {
        let selected = selectedType == type
        Button {
            selectedType = type
            Haptics.light()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    selected
                    ? LinearGradient(colors: [Color.accentColor, Color.blue], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color(.secondarySystemBackground), Color(.secondarySystemBackground)], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(PressableScaleButtonStyle(scale: 0.98, opacity: 0.95))
    }

    private var eventsSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(filteredEvents.enumerated()), id: \.element.id) { index, event in
                timelineRow(
                    event: event,
                    isLast: index == filteredEvents.count - 1
                )
                    .staggerEntrance(show: animateIn, delay: 0.1 + Double(min(index, 10)) * 0.03)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: filteredEvents.count)
    }

    private func timelineRow(event: AppEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 14)

                Rectangle()
                    .fill(Color.accentColor.opacity(isLast ? 0 : 0.22))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 18)

            eventCard(event)
        }
    }

    private func eventCard(_ event: AppEvent) -> some View {
        Button {
            editingEvent = event
            Haptics.light()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.18))
                            .frame(width: 34, height: 34)
                        Image(systemName: event.type.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.type.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)

                        Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Menu {
                        Button {
                            editingEvent = event
                            Haptics.light()
                        } label: {
                            Label(L10n.tr("common_edit"), systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            pendingDeleteEvent = event
                            Haptics.warning()
                        } label: {
                            Label(L10n.tr("common_delete"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                if !event.note.isEmpty {
                    Text(event.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                EventPayloadSummaryView(event: event)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.26), lineWidth: 1)
            )
        }
        .buttonStyle(PressableScaleButtonStyle(scale: 0.992, opacity: 0.96))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            GeneratedImageView(relativePath: "search/empty_state.png", contentMode: .fit)
                .frame(height: 210)

            Text(String(format: L10n.tr("today_summary_format"), 0))
                .font(.headline.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                appState.selectedTab = .quickAdd
                Haptics.medium()
            } label: {
                Text(L10n.tr("app_add"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
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
            }
            .buttonStyle(PressableScaleButtonStyle())
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var filteredEvents: [AppEvent] {
        let scoped = store.filter(by: selectedType, childId: appState.selectedChildId())
        switch historyMode {
        case .recent:
            return Array(scoped.prefix(10))
        case .date:
            let calendar = Calendar.current
            return scoped.filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
        case .babyMonth:
            guard let birthDate = selectedProfile?.birthDate else { return Array(scoped.prefix(10)) }
            return scoped.filter {
                let month = max(Calendar.current.dateComponents([.month], from: birthDate, to: $0.timestamp).month ?? 0, 0)
                return month == selectedAgeMonth
            }
        }
    }

    private var selectedProfile: BabyProfile? {
        appState.babyProfiles.first(where: { $0.id == appState.selectedBabyId })
    }

    private var availableMonthCount: Int {
        guard let birthDate = selectedProfile?.birthDate else { return 36 }
        return max(Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0, 0)
    }
}

private enum TimelineHistoryMode: String, CaseIterable, Identifiable {
    case recent
    case date
    case babyMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent:
            return L10n.tr("timeline_history_recent")
        case .date:
            return L10n.tr("timeline_history_date_short")
        case .babyMonth:
            return L10n.tr("timeline_history_baby_month_short")
        }
    }
}
