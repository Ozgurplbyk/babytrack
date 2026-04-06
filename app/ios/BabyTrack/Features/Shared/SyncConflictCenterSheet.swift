import SwiftUI

struct SyncConflictCenterSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var syncConflictStore: SyncConflictStore
    @Environment(\.dismiss) private var dismiss

    @State private var resolvingEventId: String?
    @State private var resolutionError = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        Button(L10n.tr("sync_conflict_keep_local_all")) {
                            Task { await resolveAllConflicts(strategy: .keepLocal) }
                        }
                        .buttonStyle(.borderedProminent)

                        Button(L10n.tr("sync_conflict_keep_remote_all")) {
                            Task { await resolveAllConflicts(strategy: .keepRemote) }
                        }
                        .buttonStyle(.bordered)

                        Button(L10n.tr("sync_conflict_merge_all")) {
                            Task { await resolveAllConflicts(strategy: .merge) }
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(role: .destructive) {
                        rollbackConflicts()
                    } label: {
                        Label(L10n.tr("sync_conflict_rollback"), systemImage: "arrow.uturn.backward")
                    }
                }

                ForEach(syncConflictStore.conflicts) { conflict in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(format: L10n.tr("sync_conflict_item_title_format"), shortEventId(conflict.eventId)))
                            .font(.subheadline.weight(.bold))

                        if let remote = conflict.remoteEvent {
                            Text(String(format: L10n.tr("sync_conflict_remote_summary_format"), remote.type.title))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(L10n.tr("sync_conflict_remote_missing"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        let diffs = SyncConflictEngine.diff(
                            local: store.event(withIdString: conflict.eventId),
                            remote: conflict.remoteEvent
                        )
                        if !diffs.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(diffs.prefix(6)) { line in
                                    Text(String(format: L10n.tr("sync_conflict_diff_line_format"), line.title, line.localValue, line.remoteValue))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            Button(L10n.tr("sync_conflict_keep_local")) {
                                Task { await resolveConflict(conflict, strategy: .keepLocal) }
                            }
                            .buttonStyle(.borderedProminent)

                            Button(L10n.tr("sync_conflict_keep_remote")) {
                                Task { await resolveConflict(conflict, strategy: .keepRemote) }
                            }
                            .buttonStyle(.bordered)

                            Button(L10n.tr("sync_conflict_merge")) {
                                Task { await resolveConflict(conflict, strategy: .merge) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .disabled(resolvingEventId == conflict.id)

                        if resolvingEventId == conflict.id {
                            ProgressView(L10n.tr("sync_conflict_resolving"))
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(L10n.tr("sync_conflict_title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common_done")) {
                        appState.showSyncConflictCenter = false
                        dismiss()
                    }
                }
            }
            .alert(L10n.tr("sync_conflict_error_title"), isPresented: Binding(
                get: { !resolutionError.isEmpty },
                set: { if !$0 { resolutionError = "" } }
            )) {
                Button(L10n.tr("common_ok"), role: .cancel) {}
            } message: {
                Text(resolutionError)
            }
        }
    }

    private func resolveConflict(_ conflict: SyncConflict, strategy: SyncConflictStrategy) async {
        guard resolvingEventId == nil else { return }
        resolvingEventId = conflict.eventId
        defer { resolvingEventId = nil }

        let local = store.event(withIdString: conflict.eventId)
        let remote = conflict.remoteEvent

        do {
            let resolved: ConflictResolveResult
            switch strategy {
            case .keepLocal:
                guard let local else {
                    throw BackendError.notFound
                }
                resolved = try await BackendClient.shared.resolveSyncConflict(
                    eventId: conflict.eventId,
                    strategy: .keepLocal,
                    localEvent: local,
                    countryCode: appState.countryCode
                )
            case .keepRemote:
                resolved = try await BackendClient.shared.resolveSyncConflict(
                    eventId: conflict.eventId,
                    strategy: .keepRemote,
                    countryCode: appState.countryCode
                )
            case .merge:
                guard let merged = SyncConflictEngine.merge(local: local, remote: remote, eventId: conflict.eventId) else {
                    throw BackendError.invalidResponse
                }
                resolved = try await BackendClient.shared.resolveSyncConflict(
                    eventId: conflict.eventId,
                    strategy: .merge,
                    mergedEvent: merged,
                    countryCode: appState.countryCode
                )
            }

            if let finalEvent = resolved.event ?? remote {
                store.upsert(finalEvent)
            }
            syncConflictStore.resolve(eventId: conflict.eventId)
            if !syncConflictStore.hasConflicts {
                appState.showSyncConflictCenter = false
                dismiss()
            }
            Haptics.success()
        } catch {
            resolutionError = L10n.tr("sync_conflict_error_message")
            Haptics.warning()
        }
    }

    private func resolveAllConflicts(strategy: SyncConflictStrategy) async {
        guard resolvingEventId == nil else { return }
        for conflict in Array(syncConflictStore.conflicts) {
            await resolveConflict(conflict, strategy: strategy)
        }
    }

    private func rollbackConflicts() {
        guard syncConflictStore.rollback(using: store) else { return }
        appState.showSyncConflictCenter = false
        Haptics.success()
        dismiss()
    }

    private func shortEventId(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return trimmed }
        return String(trimmed.prefix(8))
    }
}
