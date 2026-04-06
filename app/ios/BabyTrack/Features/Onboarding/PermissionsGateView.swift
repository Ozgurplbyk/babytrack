import SwiftUI

struct PermissionsGateView: View {
    var onContinue: () -> Void
    @State private var notificationsGranted: Bool?

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text(L10n.tr("permissions_title"))
                        .font(.title2.weight(.bold))
                    Text(L10n.tr("permissions_subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                permissionRow(
                    icon: "bell.fill",
                    title: L10n.tr("permissions_notifications_title"),
                    subtitle: L10n.tr("permissions_notifications_subtitle"),
                    granted: notificationsGranted
                ) {
                    Task {
                        let granted = await PushNotificationManager.shared.requestAuthorizationAndRegister()
                        notificationsGranted = granted
                    }
                }

                Spacer()

                Button {
                    onContinue()
                } label: {
                    Text(L10n.tr("permissions_continue"))
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.accentColor.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
    }

    private func permissionRow(icon: String, title: String, subtitle: String, granted: Bool?, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                action()
            } label: {
                if let granted {
                    Image(systemName: granted ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .foregroundStyle(granted ? .green : .red)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
