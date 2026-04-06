import SwiftUI

struct CommunityForumView: View {
    let countryCode: String
    let childId: String

    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var posts: [ForumPostPayload] = []
    @State private var loading = false
    @State private var titleText = ""
    @State private var bodyText = ""
    @State private var tagsText = ""
    @State private var errorText = ""
    @State private var selectedPost: ForumPostPayload?
    @State private var editingPost: ForumPostPayload?
    @State private var pendingDeletePost: ForumPostPayload?
    @State private var busyActionPostId: String?
    @State private var searchText = ""
    @State private var selectedTag = ""
    @State private var scope: ForumFeedScope = .all
    @State private var adminChecked = false
    @State private var isForumAdmin = false
    @State private var showAdminPanel = false
    @State private var reportTargetPost: ForumPostPayload?
    @State private var reportReason: ForumReportReason = .safety
    @State private var reportNote = ""

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    composeCard
                    filterCard

                    if loading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 14)
                    }

                    if filteredPosts.isEmpty, !loading {
                        emptyStateCard
                    }

                    ForEach(filteredPosts) { post in
                        postCard(post)
                    }
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.accentColor.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle(L10n.tr("forum_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common_done")) { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isForumAdmin {
                        Button {
                            showAdminPanel = true
                        } label: {
                            Image(systemName: "shield.checkered")
                        }
                    }
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(loading)
                }
            }
            .onAppear {
                Task { await refresh() }
            }
            .sheet(item: $selectedPost) { post in
                ForumCommentsSheet(post: post)
                    .environmentObject(authManager)
            } onDismiss: {
                Task { await refresh() }
            }
            .sheet(isPresented: $showAdminPanel) {
                if let token = authManager.sessionToken {
                    ForumAdminModerationSheet(userToken: token)
                }
            }
            .sheet(item: $reportTargetPost) { post in
                ForumReportComposerSheet(
                    post: post,
                    initialReason: reportReason,
                    initialNote: reportNote
                ) { reason, note in
                    reportReason = reason
                    reportNote = note
                    Task { await submitReport(post, reason: reason, note: note) }
                }
            }
            .alert(L10n.tr("forum_error_title"), isPresented: Binding(
                get: { !errorText.isEmpty },
                set: { if !$0 { errorText = "" } }
            )) {
                Button(L10n.tr("common_ok"), role: .cancel) {}
            } message: {
                Text(errorText)
            }
            .alert(L10n.tr("forum_delete_confirm_title"), isPresented: Binding(
                get: { pendingDeletePost != nil },
                set: { if !$0 { pendingDeletePost = nil } }
            )) {
                Button(L10n.tr("common_cancel"), role: .cancel) {}
                Button(L10n.tr("common_delete"), role: .destructive) {
                    if let post = pendingDeletePost {
                        Task { await delete(post) }
                    }
                    pendingDeletePost = nil
                }
            } message: {
                Text(L10n.tr("common_irreversible_action"))
            }
        }
    }

    private var composeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(editingPost == nil ? L10n.tr("forum_compose_title") : L10n.tr("forum_edit_title"))
                    .font(.headline.weight(.bold))
                Spacer()
                if editingPost != nil {
                    Button(L10n.tr("common_cancel")) {
                        resetComposer()
                    }
                    .font(.caption.weight(.semibold))
                }
                Text("\(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).count)/1200")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            TextField(L10n.tr("forum_compose_title_placeholder"), text: $titleText)
                .textFieldStyle(.roundedBorder)

            TextField(L10n.tr("forum_compose_body_placeholder"), text: $bodyText, axis: .vertical)
                .lineLimit(3...8)
                .textFieldStyle(.roundedBorder)

            TextField(L10n.tr("forum_compose_tags_placeholder"), text: $tagsText)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await submitComposer() }
            } label: {
                Label(editingPost == nil ? L10n.tr("forum_publish_action") : L10n.tr("forum_edit_apply"), systemImage: editingPost == nil ? "paperplane.fill" : "square.and.pencil")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canPublish || loading)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("forum_filter_title"))
                .font(.headline.weight(.bold))

            Picker("", selection: $scope) {
                ForEach(ForumFeedScope.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: scope) { _ in
                Task { await refresh() }
            }

            HStack(spacing: 8) {
                TextField(L10n.tr("forum_search_placeholder"), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await refresh() }
                    }

                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline.weight(.bold))
                }
                .buttonStyle(.bordered)
            }

            if !availableTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableTags, id: \.self) { tag in
                            Button {
                                selectedTag = selectedTag == tag ? "" : tag
                            } label: {
                                Text("#\(tag)")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background((selectedTag == tag ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12)), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onChange(of: selectedTag) { _ in
                    Task { await refresh() }
                }
            }

            if hasActiveFilters {
                Button {
                    searchText = ""
                    selectedTag = ""
                    scope = .all
                    Task { await refresh() }
                } label: {
                    Label(L10n.tr("forum_filter_clear"), systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private func postCard(_ post: ForumPostPayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.title)
                        .font(.subheadline.weight(.bold))
                    Text(post.authorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if authManager.user?.id == post.authorUserId {
                    Text(L10n.tr("forum_scope_mine"))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
                VStack(alignment: .trailing, spacing: 3) {
                    Text(formatIsoDate(post.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if post.updatedAt != post.createdAt {
                        Text(L10n.tr("forum_post_edited"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text(post.body)
                .font(.subheadline)
                .lineLimit(6)

            if !post.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(post.tags, id: \.self) { tag in
                            Button {
                                selectedTag = tag
                            } label: {
                                Text("#\(tag)")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background((selectedTag == tag ? Color.accentColor.opacity(0.18) : Color.accentColor.opacity(0.1)), in: Capsule())
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    Task { await toggleSupport(post) }
                } label: {
                    Label(
                        "\(post.reactionCount)",
                        systemImage: post.viewerReaction == "support" ? "heart.fill" : "heart"
                    )
                }
                .buttonStyle(.bordered)

                Button {
                    selectedPost = post
                } label: {
                    Label("\(post.commentCount)", systemImage: "text.bubble")
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await toggleBookmark(post) }
                } label: {
                    Image(systemName: post.viewerBookmarked ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.bordered)

                Spacer()

                Menu {
                    if authManager.user?.id == post.authorUserId {
                        Button {
                            beginEditing(post)
                        } label: {
                            Label(L10n.tr("common_edit"), systemImage: "square.and.pencil")
                        }

                        Button(role: .destructive) {
                            pendingDeletePost = post
                        } label: {
                            Label(L10n.tr("common_delete"), systemImage: "trash")
                        }
                    } else {
                        Button {
                            reportTargetPost = post
                        } label: {
                            Label(L10n.tr("forum_action_report"), systemImage: "flag.fill")
                        }

                        Button {
                            Task { await mute(post) }
                        } label: {
                            Label(L10n.tr("forum_action_mute_post"), systemImage: "speaker.slash.fill")
                        }

                        Button(role: .destructive) {
                            Task { await block(post) }
                        } label: {
                            Label(L10n.tr("forum_action_block_user"), systemImage: "person.fill.xmark")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body.weight(.bold))
                }
                .disabled(busyActionPostId == post.id)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            if busyActionPostId == post.id {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var canPublish: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredPosts: [ForumPostPayload] {
        posts
    }

    private var emptyStateMessage: String {
        if hasActiveFilters {
            return L10n.tr("forum_empty_filtered")
        }
        switch scope {
        case .all:
            return L10n.tr("forum_empty")
        case .mine:
            return L10n.tr("forum_empty_mine")
        case .saved:
            return L10n.tr("forum_empty_saved")
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: scope == .saved ? "bookmark" : "text.bubble")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if hasActiveFilters {
                Text(filterSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var availableTags: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for tag in posts.flatMap(\.tags) {
            if seen.insert(tag).inserted {
                ordered.append(tag)
            }
        }
        return ordered
    }

    private var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedTag.isEmpty || scope != .all
    }

    private var filterSummaryText: String {
        var parts: [String] = []
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            parts.append(String(format: L10n.tr("forum_filter_summary_search"), trimmedSearch))
        }
        if !selectedTag.isEmpty {
            parts.append(String(format: L10n.tr("forum_filter_summary_tag"), selectedTag))
        }
        if scope != .all {
            parts.append(String(format: L10n.tr("forum_filter_summary_scope"), scope.title))
        }
        return parts.joined(separator: " • ")
    }

    private func refresh() async {
        guard let token = authManager.sessionToken else { return }
        loading = true
        defer { loading = false }

        do {
            let envelope = try await BackendClient.shared.fetchForumPosts(
                countryCode: countryCode,
                userToken: token,
                query: searchText,
                tag: selectedTag,
                scope: scope.rawValue
            )
            posts = envelope.posts
        } catch {
            errorText = L10n.tr("forum_error_fetch")
        }

        await checkAdminAccessIfNeeded(token: token)
    }

    private func checkAdminAccessIfNeeded(token: String) async {
        guard !adminChecked else { return }
        adminChecked = true
        do {
            _ = try await BackendClient.shared.fetchForumAdminReports(status: "pending", limit: 1, userToken: token)
            isForumAdmin = true
        } catch BackendError.forbidden {
            isForumAdmin = false
        } catch {
            isForumAdmin = false
        }
    }

    private func publishPost() async {
        guard let token = authManager.sessionToken else { return }
        let normalizedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBody.isEmpty else { return }

        switch ForumModeration.validatePost(title: titleText, body: normalizedBody) {
        case .allow:
            break
        case let .reject(reasonKey):
            errorText = L10n.tr(reasonKey)
            Haptics.warning()
            return
        }

        loading = true
        defer { loading = false }

        let tags = ForumModeration.parseTags(tagsText)

        do {
            _ = try await BackendClient.shared.createForumPost(
                title: titleText,
                body: normalizedBody,
                tags: tags,
                countryCode: countryCode,
                childId: childId,
                userToken: token
            )
            titleText = ""
            bodyText = ""
            tagsText = ""
            await refresh()
            Haptics.success()
        } catch {
            errorText = L10n.tr("forum_error_publish")
            Haptics.warning()
        }
    }

    private func submitComposer() async {
        if editingPost == nil {
            await publishPost()
        } else {
            await savePostEdits()
        }
    }

    private func beginEditing(_ post: ForumPostPayload) {
        editingPost = post
        titleText = post.title
        bodyText = post.body
        tagsText = post.tags.joined(separator: ", ")
    }

    private func resetComposer() {
        editingPost = nil
        titleText = ""
        bodyText = ""
        tagsText = ""
    }

    private func savePostEdits() async {
        guard let token = authManager.sessionToken, let editingPost else { return }
        let normalizedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBody.isEmpty else { return }

        switch ForumModeration.validatePost(title: titleText, body: normalizedBody) {
        case .allow:
            break
        case let .reject(reasonKey):
            errorText = L10n.tr(reasonKey)
            Haptics.warning()
            return
        }

        loading = true
        defer { loading = false }

        do {
            _ = try await BackendClient.shared.updateForumPost(
                postId: editingPost.id,
                title: titleText,
                body: normalizedBody,
                tags: ForumModeration.parseTags(tagsText),
                userToken: token
            )
            resetComposer()
            await refresh()
            Haptics.success()
        } catch {
            errorText = L10n.tr("forum_error_update")
            Haptics.warning()
        }
    }

    private func delete(_ post: ForumPostPayload) async {
        guard let token = authManager.sessionToken else { return }
        busyActionPostId = post.id
        defer { busyActionPostId = nil }

        do {
            try await BackendClient.shared.deleteForumPost(postId: post.id, userToken: token)
            if editingPost?.id == post.id {
                resetComposer()
            }
            posts.removeAll(where: { $0.id == post.id })
            Haptics.success()
        } catch {
            errorText = L10n.tr("forum_error_delete")
            Haptics.warning()
        }
    }

    private func toggleSupport(_ post: ForumPostPayload) async {
        guard let token = authManager.sessionToken else { return }
        let active = post.viewerReaction != "support"

        do {
            let envelope = try await BackendClient.shared.setForumReaction(
                postId: post.id,
                reaction: "support",
                active: active,
                userToken: token
            )
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                var updated = posts[index]
                    updated = ForumPostPayload(
                        id: updated.id,
                        authorUserId: updated.authorUserId,
                        authorName: updated.authorName,
                    title: updated.title,
                    body: updated.body,
                    tags: updated.tags,
                    countryCode: updated.countryCode,
                    childId: updated.childId,
                    createdAt: updated.createdAt,
                        updatedAt: updated.updatedAt,
                        commentCount: updated.commentCount,
                        reactionCount: envelope.summary.reactionCount,
                        viewerReaction: envelope.summary.viewerReaction,
                        viewerBookmarked: updated.viewerBookmarked
                    )
                posts[index] = updated
            }
        } catch {
            errorText = L10n.tr("forum_error_react")
        }
    }

    private func toggleBookmark(_ post: ForumPostPayload) async {
        guard let token = authManager.sessionToken else { return }
        busyActionPostId = post.id
        defer { busyActionPostId = nil }

        do {
            let envelope = try await BackendClient.shared.setForumBookmark(
                postId: post.id,
                active: !post.viewerBookmarked,
                userToken: token
            )
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index] = envelope.post
            } else if scope == .saved, envelope.post.viewerBookmarked {
                posts.append(envelope.post)
            }
            if scope == .saved && !envelope.post.viewerBookmarked {
                posts.removeAll(where: { $0.id == post.id })
            }
            Haptics.success()
        } catch {
            errorText = L10n.tr("forum_error_bookmark")
            Haptics.warning()
        }
    }

    private func submitReport(_ post: ForumPostPayload, reason: ForumReportReason, note: String) async {
        guard let token = authManager.sessionToken else { return }
        busyActionPostId = post.id
        defer { busyActionPostId = nil }

        do {
            _ = try await BackendClient.shared.reportForumPost(
                postId: post.id,
                reason: reason.rawValue,
                note: note,
                userToken: token
            )
            reportTargetPost = nil
            reportNote = ""
            reportReason = .safety
            Haptics.success()
        } catch {
            errorText = L10n.tr("forum_error_report")
            Haptics.warning()
        }
    }

    private func mute(_ post: ForumPostPayload) async {
        guard let token = authManager.sessionToken else { return }
        busyActionPostId = post.id
        defer { busyActionPostId = nil }

        do {
            try await BackendClient.shared.muteForumPost(postId: post.id, userToken: token)
            posts.removeAll(where: { $0.id == post.id })
            Haptics.success()
        } catch {
            errorText = L10n.tr("forum_error_mute")
            Haptics.warning()
        }
    }

    private func block(_ post: ForumPostPayload) async {
        guard let token = authManager.sessionToken else { return }
        guard authManager.user?.id != post.authorUserId else {
            errorText = L10n.tr("forum_error_block_self")
            Haptics.warning()
            return
        }
        busyActionPostId = post.id
        defer { busyActionPostId = nil }

        do {
            try await BackendClient.shared.blockForumUser(targetUserId: post.authorUserId, userToken: token)
            posts.removeAll(where: { $0.authorUserId == post.authorUserId })
            Haptics.success()
        } catch {
            errorText = L10n.tr("forum_error_block")
            Haptics.warning()
        }
    }

    private func formatIsoDate(_ value: String) -> String {
        guard let parsed = ForumDateParser.parse(value) else { return value }
        return parsed.formatted(date: .abbreviated, time: .shortened)
    }
}

private enum ForumFeedScope: String, CaseIterable, Identifiable {
    case all
    case mine
    case saved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return L10n.tr("forum_scope_all")
        case .mine:
            return L10n.tr("forum_scope_mine")
        case .saved:
            return L10n.tr("forum_scope_saved")
        }
    }
}

private enum ForumReportReason: String, CaseIterable, Identifiable {
    case safety
    case misinformation
    case harassment
    case spam

    var id: String { rawValue }

    var title: String {
        switch self {
        case .safety:
            return L10n.tr("forum_report_reason_safety")
        case .misinformation:
            return L10n.tr("forum_report_reason_misinformation")
        case .harassment:
            return L10n.tr("forum_report_reason_harassment")
        case .spam:
            return L10n.tr("forum_report_reason_spam")
        }
    }
}

private struct ForumReportComposerSheet: View {
    let post: ForumPostPayload
    let initialReason: ForumReportReason
    let initialNote: String
    let onSubmit: (ForumReportReason, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var reason: ForumReportReason
    @State private var note: String

    init(
        post: ForumPostPayload,
        initialReason: ForumReportReason,
        initialNote: String,
        onSubmit: @escaping (ForumReportReason, String) -> Void
    ) {
        self.post = post
        self.initialReason = initialReason
        self.initialNote = initialNote
        self.onSubmit = onSubmit
        _reason = State(initialValue: initialReason)
        _note = State(initialValue: initialNote)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("forum_report_title")) {
                    Text(post.title)
                        .font(.subheadline.weight(.bold))
                    Text(post.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(5)
                }

                Section(L10n.tr("forum_report_reason_title")) {
                    Picker("", selection: $reason) {
                        ForEach(ForumReportReason.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section(L10n.tr("forum_report_note_title")) {
                    TextField(L10n.tr("forum_report_note_placeholder"), text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(L10n.tr("forum_action_report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("forum_report_submit")) {
                        onSubmit(reason, note.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
        }
    }
}

private struct ForumAdminModerationSheet: View {
    let userToken: String

    @Environment(\.dismiss) private var dismiss

    @State private var statusFilter = "pending"
    @State private var reports: [ForumReportPayload] = []
    @State private var loading = false
    @State private var errorText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("", selection: $statusFilter) {
                    Text(L10n.tr("forum_admin_filter_pending")).tag("pending")
                    Text(L10n.tr("forum_admin_filter_all")).tag("all")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                if loading {
                    ProgressView()
                        .padding(.top, 12)
                }

                if reports.isEmpty, !loading {
                    Text(L10n.tr("forum_admin_empty"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                } else {
                    List(reports) { report in
                        reportRow(report)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(L10n.tr("forum_admin_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common_done")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(loading)
                }
            }
            .onChange(of: statusFilter) { _ in
                Task { await refresh() }
            }
            .onAppear {
                Task { await refresh() }
            }
            .alert(L10n.tr("forum_error_title"), isPresented: Binding(
                get: { !errorText.isEmpty },
                set: { if !$0 { errorText = "" } }
            )) {
                Button(L10n.tr("common_ok"), role: .cancel) {}
            } message: {
                Text(errorText)
            }
        }
    }

    @ViewBuilder
    private func reportRow(_ report: ForumReportPayload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(String(format: L10n.tr("forum_admin_report_post"), report.postId))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(adminStatusTitle(report.status))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(adminStatusColor(report.status).opacity(0.15), in: Capsule())
                    .foregroundStyle(adminStatusColor(report.status))
            }

            Text(String(format: L10n.tr("forum_admin_report_reason"), report.reason))
                .font(.subheadline.weight(.semibold))

            if let title = report.postTitle, !title.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("forum_admin_post_snapshot_title"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.subheadline.weight(.bold))
                    if let authorName = report.postAuthorName, !authorName.isEmpty {
                        Text(String(format: L10n.tr("forum_admin_post_author"), authorName))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let body = report.postBody, !body.isEmpty {
                        Text(body)
                            .font(.subheadline)
                            .lineLimit(4)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !report.note.isEmpty {
                Text(String(format: L10n.tr("forum_admin_report_note"), report.note))
                    .font(.subheadline)
            }

            Text(String(format: L10n.tr("forum_admin_report_reporter"), report.reporterUserId))
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: L10n.tr("forum_admin_report_created"), formatIsoDate(report.createdAt)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let resolvedAt = report.resolvedAt, !resolvedAt.isEmpty {
                    Text(String(format: L10n.tr("forum_admin_report_resolved"), formatIsoDate(resolvedAt)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let resolvedBy = report.resolvedByUserId, !resolvedBy.isEmpty {
                    Text(String(format: L10n.tr("forum_admin_report_resolved_by"), resolvedBy))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if report.status == "pending" {
                HStack(spacing: 8) {
                    Button {
                        Task { await resolve(report, as: "resolved") }
                    } label: {
                        Label(L10n.tr("forum_admin_action_resolve"), systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(loading)

                    Button(role: .destructive) {
                        Task { await resolve(report, as: "rejected") }
                    } label: {
                        Label(L10n.tr("forum_admin_action_reject"), systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(loading)
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 6)
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        do {
            let status = statusFilter == "all" ? "" : statusFilter
            let envelope = try await BackendClient.shared.fetchForumAdminReports(
                status: status,
                limit: 80,
                userToken: userToken
            )
            reports = envelope.reports
        } catch {
            errorText = L10n.tr("forum_admin_error_fetch")
        }
    }

    private func resolve(_ report: ForumReportPayload, as status: String) async {
        loading = true
        defer { loading = false }
        do {
            _ = try await BackendClient.shared.resolveForumAdminReport(
                reportId: report.id,
                status: status,
                userToken: userToken
            )
            Haptics.success()
            await refresh()
        } catch {
            errorText = L10n.tr("forum_admin_error_resolve")
            Haptics.warning()
        }
    }

    private func formatIsoDate(_ value: String) -> String {
        guard let parsed = ForumDateParser.parse(value) else { return value }
        return parsed.formatted(date: .abbreviated, time: .shortened)
    }

    private func adminStatusTitle(_ status: String) -> String {
        switch status {
        case "pending":
            return L10n.tr("forum_admin_status_pending")
        case "resolved":
            return L10n.tr("forum_admin_status_resolved")
        case "rejected":
            return L10n.tr("forum_admin_status_rejected")
        default:
            return status.uppercased()
        }
    }

    private func adminStatusColor(_ status: String) -> Color {
        switch status {
        case "resolved":
            return .green
        case "rejected":
            return .red
        default:
            return .accentColor
        }
    }
}

private struct ForumCommentsSheet: View {
    let post: ForumPostPayload

    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [ForumCommentPayload] = []
    @State private var newComment = ""
    @State private var loading = false
    @State private var errorText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                if loading {
                    ProgressView()
                        .padding(.vertical, 10)
                }

                if comments.isEmpty, !loading {
                    Text(L10n.tr("forum_comment_empty"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                List(comments) { comment in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(comment.authorName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(comment.body)
                            .font(.subheadline)
                        Text(formatIsoDate(comment.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)

                HStack(spacing: 8) {
                    TextField(L10n.tr("forum_comment_placeholder"), text: $newComment)
                        .textFieldStyle(.roundedBorder)
                    Button(L10n.tr("forum_comment_send")) {
                        Task { await sendComment() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .navigationTitle(L10n.tr("forum_comment_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common_done")) { dismiss() }
                }
            }
            .onAppear {
                Task { await refresh() }
            }
            .alert(L10n.tr("forum_error_title"), isPresented: Binding(
                get: { !errorText.isEmpty },
                set: { if !$0 { errorText = "" } }
            )) {
                Button(L10n.tr("common_ok"), role: .cancel) {}
            } message: {
                Text(errorText)
            }
        }
    }

    private func refresh() async {
        guard let token = authManager.sessionToken else { return }
        loading = true
        defer { loading = false }
        do {
            let envelope = try await BackendClient.shared.fetchForumComments(postId: post.id, userToken: token)
            comments = envelope.comments
        } catch {
            errorText = L10n.tr("forum_error_fetch_comments")
        }
    }

    private func sendComment() async {
        guard let token = authManager.sessionToken else { return }
        let text = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        do {
            let envelope = try await BackendClient.shared.createForumComment(postId: post.id, body: text, userToken: token)
            comments.append(envelope.comment)
            newComment = ""
            Haptics.success()
        } catch {
            errorText = L10n.tr("forum_error_publish_comment")
            Haptics.warning()
        }
    }

    private func formatIsoDate(_ value: String) -> String {
        guard let parsed = ForumDateParser.parse(value) else { return value }
        return parsed.formatted(date: .abbreviated, time: .shortened)
    }
}

private enum ForumDateParser {
    private static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        withFractional.date(from: value) ?? plain.date(from: value)
    }
}
