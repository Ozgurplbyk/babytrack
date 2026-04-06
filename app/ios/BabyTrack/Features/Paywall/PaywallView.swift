import SwiftUI

struct PaywallView: View {
    @Environment(\.colorScheme) private var colorScheme

    let offers: PaywallOffersResponse
    var onPurchasePlan: (String) async -> Void
    var onRestore: () async -> Void
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        heroSection
                        featuresSection
                        premiumHighlightsSection
                        comparisonSection
                        plansSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle(L10n.tr("paywall_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isDarkMode ? Color.white.opacity(0.88) : Color.primary.opacity(0.72))
                            .padding(8)
                            .background(
                                isDarkMode ? Color.white.opacity(0.12) : Color.white.opacity(0.84),
                                in: Circle()
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(isDarkMode ? Color.white.opacity(0.2) : Color.white.opacity(0.62), lineWidth: 1)
                            )
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                footerActions
            }
            .onAppear {
                AnalyticsTracker.shared.track(.paywallViewed)
            }
        }
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: isDarkMode
                ? [
                    Color(red: 0.04, green: 0.05, blue: 0.09),
                    Color(red: 0.08, green: 0.08, blue: 0.14),
                    Color(red: 0.03, green: 0.03, blue: 0.05)
                ]
                : [
                    Color(red: 0.95, green: 0.94, blue: 1.0),
                    Color(red: 0.93, green: 0.96, blue: 1.0),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.purple.opacity(isDarkMode ? 0.22 : 0.16))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: 140, y: -220)

            Circle()
                .fill(Color.blue.opacity(isDarkMode ? 0.2 : 0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: -140, y: -180)
        }
    }

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topLeading) {
                GeneratedImageView(relativePath: "premium/paywall_wow_hero_c.png", contentMode: .fill)
                    .frame(height: 244)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.5), lineWidth: 1.2)
                    )

                LinearGradient(
                    colors: [Color.black.opacity(0.26), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.bold())
                    Text(L10n.tr("paywall_title"))
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.black.opacity(isDarkMode ? 0.46 : 0.32), in: Capsule())
                .padding(14)
            }
            .shadow(color: .purple.opacity(0.24), radius: 18, x: 0, y: 12)

            Text(L10n.tr("paywall_feature_1"))
                .font(.headline.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(isDarkMode ? Color.white.opacity(0.95) : Color.primary)

            Text(L10n.tr("paywall_hero_subtitle"))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
        }
    }

    private var featuresSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            ForEach(featureRows) { item in
                FeatureCard(item: item, isDark: isDarkMode)
            }
        }
    }

    private var plansSection: some View {
        VStack(spacing: 10) {
            ForEach(effectivePlans) { plan in
                planButton(for: plan)
            }
        }
    }

    private var premiumHighlightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("paywall_highlights_title"))
                .font(.headline.weight(.bold))

            ForEach(highlightRows) { row in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: row.icon)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.subheadline.weight(.semibold))
                        Text(row.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(
            isDarkMode ? Color.white.opacity(0.1) : Color.white.opacity(0.82),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isDarkMode ? Color.white.opacity(0.2) : Color.white.opacity(0.6), lineWidth: 1)
        )
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("paywall_compare_title"))
                .font(.headline.weight(.bold))
            comparisonRow(title: L10n.tr("paywall_compare_ai"), free: L10n.tr("paywall_compare_limited"), premium: L10n.tr("paywall_compare_unlimited"))
            comparisonRow(title: L10n.tr("paywall_compare_share"), free: L10n.tr("paywall_compare_basic"), premium: L10n.tr("paywall_compare_advanced"))
            comparisonRow(title: L10n.tr("paywall_compare_history"), free: L10n.tr("paywall_compare_last10"), premium: L10n.tr("paywall_compare_full"))
            comparisonRow(title: L10n.tr("paywall_compare_family"), free: L10n.tr("paywall_compare_single"), premium: L10n.tr("paywall_compare_multi"))
        }
        .padding(14)
        .background(
            isDarkMode ? Color.white.opacity(0.1) : Color.white.opacity(0.82),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isDarkMode ? Color.white.opacity(0.2) : Color.white.opacity(0.6), lineWidth: 1)
        )
    }

    private func comparisonRow(title: String, free: String, premium: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(free)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.12), in: Capsule())
            Text(premium)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.16), in: Capsule())
        }
    }

    private func planButton(for plan: PaywallPlan) -> some View {
        Button {
            purchase(plan)
        } label: {
            PlanCard(
                title: plan.title,
                badge: plan.badge,
                price: planPrice(for: plan),
                isDefault: plan.id == offers.defaultPlan,
                isDark: isDarkMode
            )
        }
        .buttonStyle(.plain)
    }

    private var footerActions: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.08)
            HStack(spacing: 14) {
                footerButton(L10n.tr("paywall_restore")) {
                    Task { await onRestore() }
                }

                footerButton(L10n.tr("paywall_skip")) {
                    onClose()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(isDarkMode ? Color.black.opacity(0.45) : Color.white.opacity(0.32))
        }
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(footerButtonTextColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(footerButtonFill, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(footerButtonStroke, lineWidth: 1)
            )
    }

    private var featureRows: [FeatureRow] {
        [
            .init(icon: "sparkles", text: L10n.tr("paywall_feature_1")),
            .init(icon: "doc.text", text: L10n.tr("paywall_feature_2")),
            .init(icon: "chart.xyaxis.line", text: L10n.tr("paywall_feature_3")),
            .init(icon: "photo.on.rectangle", text: L10n.tr("paywall_feature_4")),
            .init(icon: "bell.badge.fill", text: L10n.tr("paywall_feature_5")),
            .init(icon: "person.3.fill", text: L10n.tr("paywall_feature_6")),
            .init(icon: "heart.text.square.fill", text: L10n.tr("paywall_feature_7")),
            .init(icon: "music.note.house.fill", text: L10n.tr("paywall_feature_8"))
        ]
    }

    private var highlightRows: [PaywallHighlight] {
        [
            .init(icon: "bolt.fill", title: L10n.tr("paywall_highlight_1_title"), subtitle: L10n.tr("paywall_highlight_1_subtitle")),
            .init(icon: "shield.checkered", title: L10n.tr("paywall_highlight_2_title"), subtitle: L10n.tr("paywall_highlight_2_subtitle")),
            .init(icon: "calendar.badge.clock", title: L10n.tr("paywall_highlight_3_title"), subtitle: L10n.tr("paywall_highlight_3_subtitle"))
        ]
    }

    private func planPrice(for plan: PaywallPlan) -> String {
        if plan.price.isEmpty || plan.currency.isEmpty {
            return L10n.tr("paywall_price_placeholder")
        }
        return String(format: L10n.tr("paywall_plan_price_format"), plan.price, plan.currency)
    }

    private func purchase(_ plan: PaywallPlan) {
        AnalyticsTracker.shared.track(.trialStarted, params: [
            "plan_id": plan.id
        ])
        Task {
            await onPurchasePlan(plan.id)
        }
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var footerButtonTextColor: Color {
        isDarkMode ? Color.white.opacity(0.9) : Color.primary.opacity(0.78)
    }

    private var footerButtonFill: Color {
        isDarkMode ? Color.white.opacity(0.12) : Color.white.opacity(0.86)
    }

    private var footerButtonStroke: Color {
        isDarkMode ? Color.white.opacity(0.2) : Color.white.opacity(0.72)
    }

    private var effectivePlans: [PaywallPlan] {
        if !offers.plans.isEmpty {
            return offers.plans
        }
        return [
            PaywallPlan(
                id: "monthly",
                title: L10n.tr("paywall_fallback_monthly_title"),
                appStoreProductId: "com.babytrack.premium.monthly",
                price: L10n.tr("paywall_fallback_monthly_price"),
                currency: "",
                trialDays: 7,
                badge: L10n.tr("paywall_fallback_badge")
            ),
            PaywallPlan(
                id: "annual",
                title: L10n.tr("paywall_fallback_annual_title"),
                appStoreProductId: "com.babytrack.premium.annual",
                price: L10n.tr("paywall_fallback_annual_price"),
                currency: "",
                trialDays: 14,
                badge: L10n.tr("paywall_fallback_badge")
            )
        ]
    }
}

private struct FeatureRow: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

private struct PaywallHighlight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

private struct FeatureCard: View {
    let item: FeatureRow
    let isDark: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)
                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(item.text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(
            isDark ? Color.white.opacity(0.1) : Color.white.opacity(0.78),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isDark ? Color.white.opacity(0.2) : Color.white.opacity(0.55), lineWidth: 1)
        )
    }
}

private struct PlanCard: View {
    let title: String
    let badge: String?
    let price: String
    let isDefault: Bool
    let isDark: Bool

    @ViewBuilder
    var body: some View {
        if isDefault {
            cardContent
                .background(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(isDark ? 0.34 : 0.18),
                            Color.blue.opacity(isDark ? 0.26 : 0.14),
                            isDark ? Color.black.opacity(0.34) : Color.white.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.purple.opacity(isDark ? 0.75 : 0.55), lineWidth: 1.4)
                )
        } else {
            cardContent
                .background(
                    isDark ? Color.white.opacity(0.1) : Color.white.opacity(0.8),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isDark ? Color.white.opacity(0.2) : Color.white.opacity(0.55), lineWidth: 1)
                )
        }
    }

    private var cardContent: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                titleRow

                Text(price)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: isDefault ? "star.circle.fill" : "chevron.right.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(isDefault ? Color.purple : Color.secondary.opacity(0.8))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            if let badge, !badge.isEmpty {
                Text(badge)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.95), Color.blue.opacity(0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
            }
        }
    }
}
