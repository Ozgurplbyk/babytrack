import SwiftUI

struct QuickAddView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: EventStore
    @State private var editingEvent: AppEvent?
    @State private var pendingDeleteEvent: AppEvent?
    @State private var capturingType: EventType?
    @State private var animateIn = false
    @State private var heroFloat = false

    private let quickActions: [QuickActionItem] = [
        .init(type: .breastfeeding, imagePath: "quick_add/breast_left.png"),
        .init(type: .bottle, imagePath: "quick_add/bottle.png"),
        .init(type: .pumping, imagePath: "quick_add/pumping.png"),
        .init(type: .diaperChange, imagePath: "quick_add/diaper.png"),
        .init(type: .sleep, imagePath: "quick_add/sleep.png"),
        .init(type: .fever, imagePath: "quick_add/fever.png"),
        .init(type: .symptom, imagePath: "quick_add/symptom.png"),
        .init(type: .medication, imagePath: "medication/reminder_card.png"),
        .init(type: .memory, imagePath: "quick_add/memory.png")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        heroSection
                            .staggerEntrance(show: animateIn, delay: 0.02)
                        quickActionsSection
                            .staggerEntrance(show: animateIn, delay: 0.09)
                        recentLogsSection
                            .staggerEntrance(show: animateIn, delay: 0.16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(L10n.tr("quick_add_title"))
            .onAppear {
                if !animateIn { animateIn = true }
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                    heroFloat = true
                }
            }
            .sheet(item: $editingEvent) { event in
                EventEditorSheet(event: event) { updated in
                    store.update(updated)
                }
            }
            .sheet(item: $capturingType) { type in
                QuickAddCaptureSheet(type: type, childId: appState.selectedChildId()) { event in
                    store.add(event)
                    Haptics.success()
                    AnalyticsTracker.shared.track(.quickLogAdded, params: [
                        "event_type": event.type.rawValue
                    ])
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
                .blur(radius: 52)
                .offset(x: 140, y: -220)
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            GeneratedImageView(relativePath: "quick_add/memory.png", contentMode: .fill)
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .scaleEffect(heroFloat ? 1.03 : 1.0)

            LinearGradient(
                colors: [Color.black.opacity(0.34), Color.clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("quick_add_section"))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                Text(L10n.tr("quick_add_recent"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 10)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("quick_add_section"))
                .font(.headline.weight(.bold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(quickActions.enumerated()), id: \.element.type) { index, action in
                    Button {
                        capturingType = action.type
                        Haptics.medium()
                    } label: {
                        quickActionCard(action)
                            .staggerEntrance(show: animateIn, delay: 0.11 + Double(index) * 0.025)
                    }
                    .buttonStyle(PressableScaleButtonStyle(scale: 0.98, opacity: 0.95))
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

    private func quickActionCard(_ action: QuickActionItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                GeneratedImageView(relativePath: action.imagePath, contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.accentColor.opacity(0.9))
            }

            Text(action.type.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("quick_add_recent"))
                .font(.headline.weight(.bold))

            if recentEvents.isEmpty {
                VStack(spacing: 12) {
                    GeneratedImageView(relativePath: "memory/empty_state.png", contentMode: .fit)
                        .frame(height: 140)
                    Text(String(format: L10n.tr("today_summary_format"), 0))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                ForEach(Array(recentEvents.enumerated()), id: \.element.id) { index, event in
                    recentCard(event)
                        .staggerEntrance(show: animateIn, delay: 0.2 + Double(min(index, 8)) * 0.03)
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

    private func recentCard(_ event: AppEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: event.type.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.type.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            EventPayloadSummaryView(event: event)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            editingEvent = event
            Haptics.light()
        }
    }

    private var recentEvents: [AppEvent] {
        store.recent(limit: 10, childId: appState.selectedChildId())
    }
}

private struct QuickActionItem: Identifiable {
    let id = UUID()
    let type: EventType
    let imagePath: String
}
