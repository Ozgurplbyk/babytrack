import SwiftUI

struct WhatsNewView: View {
    let release: WhatsNewRelease
    var onClose: () -> Void

    @State private var animateHero = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.95, blue: 1.0),
                        Color(red: 0.95, green: 0.98, blue: 1.0),
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        heroSection
                        highlightsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle(L10n.tr("whats_new_title"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                continueButton
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    animateHero = true
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                GeneratedImageView(relativePath: "whats_new/whats_new_hero_b.png", contentMode: .fill)
                    .frame(height: 250)
                    .scaleEffect(animateHero ? 1.03 : 0.97)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.42), Color.clear],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.5), lineWidth: 1.2)
                    )

                VStack {
                    Spacer()
                    Text(L10n.tr("whats_new_header"))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.22), in: Capsule())
                        .padding(.bottom, 18)
                }
                .frame(height: 250)
            }
            .shadow(color: .purple.opacity(0.24), radius: 18, x: 0, y: 12)

            Text(L10n.tr("whats_new_title"))
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary.opacity(0.88))
                .textCase(nil)
                .tracking(0.2)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.76), in: Capsule())

            Text(String(format: L10n.tr("whats_new_version_line_format"), release.version, release.releaseDate))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.86), in: Capsule())
        }
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(release.highlights.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        Image(systemName: icon(for: index))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Text(item)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.55), lineWidth: 1)
                )
            }
        }
    }

    private var continueButton: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.08)
            Button(action: onClose) {
                Text(L10n.tr("whats_new_continue"))
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: .purple.opacity(0.24), radius: 12, x: 0, y: 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }

    private func icon(for index: Int) -> String {
        switch index % 4 {
        case 0: return "sparkles"
        case 1: return "moon.stars.fill"
        case 2: return "waveform.path.ecg"
        default: return "heart.text.square.fill"
        }
    }
}
